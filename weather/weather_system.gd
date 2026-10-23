@icon("res://addons/godot-xr-tools/editor/icons/node.svg")
class_name WeatherSystem
extends Node3D
## Météo dynamique + cycle jour/nuit.
##
## - Le soleil, la lune, le ciel, la lumière ambiante et le brouillard suivent l'heure.
## - Des événements météo aléatoires s'enchaînent avec des transitions douces :
##   ciel dégagé, éclaircies, nuageux, couvert, brouillard, pluie légère,
##   pluie forte, orage (avec éclairs).
## - Pluie (particules autour de la caméra), éclairs et tonnerre (son généré par code).
## Les autres scripts lisent : rain, get_darkness(), get_weather_name(), get_time_string().
## Clavier (test) : F1 menu météo/heure, F5 événement aléatoire, F6 +2 h, F7 météo suivante,
## F8 temps accéléré.

signal weather_changed(id: String, display_name: String)
signal lightning_strike(distance_m: float)

const GROUP := "weather_system"

## Paramètres de chaque météo.
## clouds = couverture, dark = noirceur des nuages, rain = intensité de pluie,
## fog = densité du brouillard, wind = vitesse des nuages, storm = probabilité d'éclairs.
const PRESETS := {
	"degage":     {"name": "Ciel dégagé", "clouds": 0.0,  "dark": 0.0,  "rain": 0.0, "fog": 0.0006, "wind": 0.15, "storm": 0.0},
	"eclaircies": {"name": "Éclaircies",  "clouds": 0.35, "dark": 0.1,  "rain": 0.0, "fog": 0.0009, "wind": 0.35, "storm": 0.0},
	"nuageux":    {"name": "Nuageux",     "clouds": 0.62, "dark": 0.3,  "rain": 0.0, "fog": 0.0014, "wind": 0.55, "storm": 0.0},
	"couvert":    {"name": "Couvert",     "clouds": 0.92, "dark": 0.55, "rain": 0.0, "fog": 0.0028, "wind": 0.7,  "storm": 0.0},
	"brouillard": {"name": "Brouillard",  "clouds": 0.8,  "dark": 0.3,  "rain": 0.0, "fog": 0.035,  "wind": 0.1,  "storm": 0.0},
	"pluie_legere": {"name": "Pluie légère", "clouds": 0.85, "dark": 0.45, "rain": 0.3, "fog": 0.004, "wind": 0.5, "storm": 0.0},
	"pluie":      {"name": "Pluie forte", "clouds": 0.95, "dark": 0.65, "rain": 0.7, "fog": 0.007,  "wind": 0.8,  "storm": 0.0},
	"orage":      {"name": "Orage",       "clouds": 1.0,  "dark": 0.92, "rain": 1.0, "fog": 0.011,  "wind": 1.2,  "storm": 1.0},
}
## Probabilités (poids) de passer d'une météo à une autre.
const TRANSITIONS := {
	"degage":     {"eclaircies": 3.0, "nuageux": 1.0, "brouillard": 0.5},
	"eclaircies": {"degage": 2.0, "nuageux": 2.0, "pluie_legere": 0.6},
	"nuageux":    {"eclaircies": 2.0, "couvert": 2.0, "pluie_legere": 1.0},
	"couvert":    {"nuageux": 1.5, "pluie_legere": 1.5, "pluie": 1.0, "orage": 0.5, "brouillard": 0.5},
	"brouillard": {"degage": 1.0, "nuageux": 1.0, "couvert": 1.0},
	"pluie_legere": {"nuageux": 1.5, "couvert": 1.0, "pluie": 1.5},
	"pluie":      {"pluie_legere": 1.5, "couvert": 1.0, "orage": 1.0},
	"orage":      {"pluie": 2.0, "couvert": 0.5},
}
const ORDER := ["degage", "eclaircies", "nuageux", "couvert", "brouillard", "pluie_legere", "pluie", "orage"]
## Seuils d'intensité des 3 niveaux de pluie (voir get_rain_level).
const RAIN_LIGHT := 0.05
const RAIN_HEAVY := 0.5
const RAIN_STORM := 0.85

@export_group("Jour / nuit")
@export_range(0.0, 24.0) var hour := 10.0
## Durée réelle (minutes) d'une journée complète de 24 h.
@export var day_length_minutes := 24.0
@export var time_scale := 1.0
## Orientation de la course du soleil (degrés).
@export var sun_yaw_deg := 35.0
@export var sun_shadows := false

@export_group("Météo")
@export_enum("degage", "eclaircies", "nuageux", "couvert", "brouillard", "pluie_legere", "pluie", "orage") var start_weather := "eclaircies"
@export var random_events := true
## Intervalle (s) entre deux changements de météo.
@export var event_interval_min := 90.0
@export var event_interval_max := 240.0
## Durée (s) des transitions.
@export var transition_time := 25.0
@export var keyboard_debug := true
## Menu de test ouvrable avec F1 (météo, heure, vitesse du temps).
@export var debug_menu := true

@export_group("Son")
@export_range(0.0, 1.0) var rain_volume := 0.35
@export_range(0.0, 1.0) var thunder_volume := 0.9

## Valeurs courantes (interpolées).
var clouds := 0.0
var cloud_dark := 0.0
var rain := 0.0
var fog := 0.001
var wind := 0.3
var storm := 0.0
var weather_id := ""

var day := 1.0      # 0 nuit -> 1 jour
var sunset := 0.0

@onready var _env: Environment = $WorldEnvironment.environment
@onready var _sky_mat: ShaderMaterial = _env.sky.sky_material
@onready var _sun: DirectionalLight3D = $Sun
@onready var _moon: DirectionalLight3D = $Moon
@onready var _lightning: DirectionalLight3D = $Lightning
@onready var _rain_fx: GPUParticles3D = $Rain
@onready var _audio: AudioStreamPlayer = $Audio

var _target := {}
var _from := {}
var _blend := 1.0
var _next_event := 0.0
var _cloud_offset := Vector2.ZERO
var _flash := 0.0
var _flash_t := -1.0
var _next_strike := 5.0
var _pending_thunder: Array = []   # [délai restant, force]
var _last_cam_pos := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _rain_mat: ShaderMaterial
var _shelter_frame := -10

# Son procédural
var _playback: AudioStreamGeneratorPlayback
var _lp := 0.0
var _brown := 0.0
var _thunder_env := 0.0
var _thunder_gain := 0.0
var _rumble_lp := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	_rng.randomize()
	_rain_fx.top_level = true
	# Gouttes : shader qui les coupe dans le volume de la voiture (toit, capot).
	_rain_mat = ShaderMaterial.new()
	_rain_mat.shader = preload("res://weather/rain_drop.gdshader")
	(_rain_fx.draw_pass_1 as PrimitiveMesh).material = _rain_mat
	# Les gouttes peuvent maintenant tomber tout près de la caméra (autour de la voiture).
	(_rain_fx.process_material as ParticleProcessMaterial).emission_ring_inner_radius = 0.4
	if debug_menu:
		var menu: CanvasLayer = preload("res://weather/weather_menu.gd").new()
		menu.name = "WeatherMenu"
		menu.set("weather", self)
		add_child(menu)
	_apply_preset_now(start_weather)
	_schedule_next_event()
	_audio.play()
	_playback = _audio.get_stream_playback()


# --- API --------------------------------------------------------------------

func get_weather_name() -> String:
	return PRESETS[weather_id]["name"] if PRESETS.has(weather_id) else ""


func get_time_string() -> String:
	return "%02d:%02d" % [int(hour), int(fmod(hour, 1.0) * 60.0)]


## Niveau de pluie : 0 = pas de pluie, 1 = pluie légère, 2 = pluie forte, 3 = orage.
func get_rain_level() -> int:
	if rain >= RAIN_STORM:
		return 3
	if rain >= RAIN_HEAVY:
		return 2
	return 1 if rain >= RAIN_LIGHT else 0


## Abri contre la pluie (la voiture) : à appeler à chaque image avec sa transformation
## globale. Les gouttes qui entrent dans son volume ne sont pas dessinées.
func set_rain_shelter(xf: Transform3D) -> void:
	_shelter_frame = Engine.get_process_frames()
	if _rain_mat:
		_rain_mat.set_shader_parameter("shelter_on", 1.0)
		_rain_mat.set_shader_parameter("shelter_inv", Projection(xf.affine_inverse()))


## 0 = plein jour ensoleillé, 1 = nuit noire (sert à allumer les phares).
func get_darkness() -> float:
	return clampf(1.0 - day * (1.0 - 0.6 * clouds * cloud_dark) + fog * 8.0, 0.0, 1.0)


## Change de météo (transition douce, ou immédiate si instant).
func set_weather(id: String, instant := false) -> void:
	if not PRESETS.has(id):
		return
	weather_id = id
	_from = {"clouds": clouds, "dark": cloud_dark, "rain": rain, "fog": fog, "wind": wind, "storm": storm}
	_target = PRESETS[id]
	_blend = 1.0 if instant else 0.0
	if instant:
		_apply_blend(1.0)
	weather_changed.emit(id, PRESETS[id]["name"])
	print("Météo : ", PRESETS[id]["name"])


func random_event() -> void:
	var choices: Dictionary = TRANSITIONS.get(weather_id, {"degage": 1.0})
	var total := 0.0
	for k in choices:
		total += choices[k]
	var r := _rng.randf() * total
	for k in choices:
		r -= choices[k]
		if r <= 0.0:
			set_weather(k)
			return


# --- Boucle -----------------------------------------------------------------

func _process(delta: float) -> void:
	hour = fmod(hour + delta * time_scale * 24.0 / (day_length_minutes * 60.0), 24.0)

	if random_events:
		_next_event -= delta
		if _next_event <= 0.0:
			random_event()
			_schedule_next_event()

	if _blend < 1.0:
		_blend = minf(_blend + delta / transition_time, 1.0)
		_apply_blend(smoothstep(0.0, 1.0, _blend))

	_update_sun_and_sky(delta)
	_update_rain(delta)
	_update_lightning(delta)
	_fill_audio()


func _apply_preset_now(id: String) -> void:
	weather_id = id
	var p: Dictionary = PRESETS[id]
	clouds = p["clouds"]; cloud_dark = p["dark"]; rain = p["rain"]
	fog = p["fog"]; wind = p["wind"]; storm = p["storm"]
	_target = p
	_blend = 1.0


func _apply_blend(t: float) -> void:
	clouds = lerpf(_from["clouds"], _target["clouds"], t)
	cloud_dark = lerpf(_from["dark"], _target["dark"], t)
	# La pluie arrive après les nuages et s'arrête avant qu'ils partent.
	var rain_t := clampf(t * 1.6 - 0.6, 0.0, 1.0) if _target["rain"] > _from["rain"] else clampf(t * 1.6, 0.0, 1.0)
	rain = lerpf(_from["rain"], _target["rain"], rain_t)
	fog = lerpf(_from["fog"], _target["fog"], t)
	wind = lerpf(_from["wind"], _target["wind"], t)
	storm = lerpf(_from["storm"], _target["storm"], rain_t)


func _schedule_next_event() -> void:
	_next_event = _rng.randf_range(event_interval_min, event_interval_max)


func _update_sun_and_sky(delta: float) -> void:
	var a := (hour / 24.0) * TAU - PI * 0.5        # 6 h = lever, 12 h = zénith
	_sun.rotation = Vector3(-a, deg_to_rad(sun_yaw_deg), 0.0)
	_moon.rotation = Vector3(-a - PI, deg_to_rad(sun_yaw_deg + 10.0), 0.0)
	var sun_dir := _sun.global_basis.z
	var moon_dir := _moon.global_basis.z
	var elev := sun_dir.y

	day = smoothstep(-0.12, 0.18, elev)
	sunset = clampf(1.0 - absf(elev) / 0.3, 0.0, 1.0) * smoothstep(-0.2, 0.0, elev)
	var overcast := clampf(clouds * 1.1 - 0.15, 0.0, 1.0)

	_sun.visible = elev > -0.05
	_sun.light_energy = smoothstep(-0.05, 0.12, elev) * 1.25 * (1.0 - 0.85 * overcast)
	_sun.light_color = Color(1.0, 0.62, 0.38).lerp(Color(1.0, 0.97, 0.92), smoothstep(0.0, 0.35, elev))
	_sun.shadow_enabled = sun_shadows
	_moon.visible = moon_dir.y > 0.0 and day < 0.9
	_moon.light_energy = 0.18 * (1.0 - day) * (1.0 - 0.7 * overcast)

	var night_amb := Color(0.05, 0.06, 0.1)
	var day_amb := Color(0.5, 0.56, 0.68)
	var amb := night_amb.lerp(day_amb, day).lerp(Color(0.8, 0.5, 0.35), sunset * 0.25)
	amb = amb.lerp(amb * Color(0.75, 0.76, 0.8), cloud_dark * 0.6)
	_env.ambient_light_color = amb
	_env.ambient_light_energy = 1.0 + _flash * 2.0

	var horizon := Color(0.035, 0.045, 0.08).lerp(Color(0.62, 0.76, 0.92), day).lerp(Color(0.98, 0.5, 0.25), sunset * 0.5)
	var grey := Color(0.03, 0.035, 0.05).lerp(Color(0.55, 0.57, 0.6), day) * (1.0 - 0.5 * cloud_dark)
	_env.fog_light_color = horizon.lerp(grey, clouds * 0.8)
	_env.fog_density = fog

	_cloud_offset += Vector2(0.004, 0.0015) * wind * delta
	_sky_mat.set_shader_parameter("sun_dir", sun_dir)
	_sky_mat.set_shader_parameter("moon_dir", moon_dir)
	_sky_mat.set_shader_parameter("day", day)
	_sky_mat.set_shader_parameter("sunset", sunset)
	_sky_mat.set_shader_parameter("clouds", clouds)
	_sky_mat.set_shader_parameter("cloud_dark", cloud_dark)
	_sky_mat.set_shader_parameter("flash", _flash)
	_sky_mat.set_shader_parameter("cloud_offset", _cloud_offset)


func _update_rain(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var pos := cam.global_position
	var vel := (pos - _last_cam_pos) / maxf(delta, 0.001)
	if vel.length() > 80.0:   # téléportation / premier frame
		vel = Vector3.ZERO
	_last_cam_pos = pos
	_rain_fx.global_position = pos + Vector3.UP * 9.0
	_rain_fx.emitting = rain > 0.01
	_rain_fx.amount_ratio = clampf(rain, 0.0, 1.0)
	if _rain_mat and Engine.get_process_frames() - _shelter_frame > 2:
		_rain_mat.set_shader_parameter("shelter_on", 0.0)   # plus d'abri (voiture supprimée)
	# Les gouttes suivent la caméra : on penche leur chute pour simuler le vent relatif.
	var pm := _rain_fx.process_material as ParticleProcessMaterial
	pm.gravity = Vector3(-vel.x * 0.8 + wind * 1.5, -9.8, -vel.z * 0.8)


func _update_lightning(delta: float) -> void:
	if storm > 0.2:
		_next_strike -= delta * storm
		if _next_strike <= 0.0:
			_strike()
			_next_strike = _rng.randf_range(4.0, 14.0)
	# Flash : double impulsion qui décroît.
	if _flash_t >= 0.0:
		_flash_t += delta
		var f := exp(-_flash_t * 9.0) + 0.7 * exp(-absf(_flash_t - 0.18) * 14.0) * float(_flash_t > 0.12)
		_flash = clampf(f, 0.0, 1.0)
		if _flash_t > 1.0:
			_flash_t = -1.0
			_flash = 0.0
	_lightning.light_energy = _flash * 3.0
	_lightning.visible = _flash > 0.01
	for i in range(_pending_thunder.size() - 1, -1, -1):
		_pending_thunder[i][0] -= delta
		if _pending_thunder[i][0] <= 0.0:
			_thunder_gain = maxf(_thunder_gain, _pending_thunder[i][1])
			_thunder_env = 1.0
			_pending_thunder.remove_at(i)


func _strike() -> void:
	var distance := _rng.randf_range(300.0, 3000.0)
	_flash_t = 0.0
	_lightning.rotation = Vector3(deg_to_rad(_rng.randf_range(-70.0, -30.0)), _rng.randf() * TAU, 0.0)
	_pending_thunder.append([distance / 340.0, clampf(600.0 / distance, 0.2, 1.0)])
	lightning_strike.emit(distance)


## Pluie = bruit blanc filtré ; tonnerre = bruit brun avec enveloppe.
func _fill_audio() -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	var rate := (_audio.stream as AudioStreamGenerator).mix_rate
	var env_decay := exp(-1.0 / (rate * 2.2))
	var rain_gain := rain * rain_volume
	for i in frames:
		var white := randf() * 2.0 - 1.0
		_lp += (white - _lp) * 0.35
		var s := _lp * rain_gain
		if _thunder_env > 0.0005:
			_brown = clampf(_brown + white * 0.06, -1.0, 1.0) * 0.995
			_rumble_lp += (_brown - _rumble_lp) * 0.08
			var crackle := 1.0 + 0.6 * sin(float(i) * 0.0007 + _thunder_env * 40.0)
			s += _rumble_lp * _thunder_env * _thunder_gain * thunder_volume * 3.0 * crackle
			_thunder_env *= env_decay
		_playback.push_frame(Vector2(s, s))


func _unhandled_key_input(event: InputEvent) -> void:
	if not keyboard_debug or not event.is_pressed() or event.is_echo():
		return
	match (event as InputEventKey).keycode:
		KEY_F5:
			random_event()
			_schedule_next_event()
		KEY_F6:
			hour = fmod(hour + 2.0, 24.0)
		KEY_F7:
			set_weather(ORDER[(ORDER.find(weather_id) + 1) % ORDER.size()])
		KEY_F8:
			time_scale = 60.0 if time_scale < 2.0 else 1.0
