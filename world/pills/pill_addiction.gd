class_name PillAddiction
extends Node
## Dépendance du conducteur aux pilules : le cœur de « Need for Pills ».
##
## - Le MANQUE monte en continu. Plus il est haut, plus l'image se décolore et
##   s'assombrit sur les bords, plus les mains tremblent (direction) et plus le moteur
##   perd de la puissance. À 100 % : black-out de quelques secondes, la voiture roule
##   toujours.
## - Une PILULE remet le manque à zéro, donne un BOOST (vitesse max et couple) et un
##   effet « bourré » : couleurs qui ondulent, direction en retard qui dérive.
## - Chaque pilule fait monter l'ASSIMILATION (0 à 1, ne redescend jamais) :
##   tolérance (boost et plaisir plus faibles, manque qui revient plus vite), puis
##   inversion : sobre, tout devient flou et bancal ; sous pilule, la vue redevient
##   nette. Le décor se teinte aux couleurs des pilules (paramètre global de shader
##   `pill_assimilation`, lu par nature_tint.gdshader).
##
## Aucun effet ne bouge la caméra (confort VR) : un filtre est posé devant les yeux
## et la conduite est perturbée via SUV4x4.drug_*.

signal pill_taken(count: int)
signal blackout_started

const GROUP := "pill_addiction"
const OVERLAY_SHADER := preload("res://world/pills/pill_overlay.gdshader")
const RATE := 22050
## Couche de rendu du filtre : seule la caméra du joueur la voit (pas les rétros).
const OVERLAY_LAYER := 1 << 19

@export var car_path: NodePath

@export_group("Manque")
## Manque au départ (0-1) : on a vite envie de la première pilule.
@export_range(0.0, 1.0) var start_craving := 0.25
## Secondes pour passer de 0 à 100 % de manque, sans assimilation / assimilation max.
@export var craving_time := Vector2(60.0, 26.0)
## Manque au réveil après un black-out.
@export_range(0.0, 1.0) var craving_after_blackout := 0.8
@export var blackout_duration := 3.5
## Perte de puissance et de vitesse max à 100 % de manque.
@export_range(0.0, 1.0) var craving_power_loss := 0.4
@export_range(0.0, 1.0) var craving_speed_loss := 0.25
## Tremblement des mains à 100 % de manque (degrés de braquage).
@export var craving_shake_deg := 2.5

@export_group("Pilule")
## Gain d'assimilation par pilule.
@export var assimilation_per_pill := 0.08
## Durée du boost (s) et gain de vitesse max / couple, sans et avec assimilation max.
@export var boost_duration := 7.0
@export var boost_speed := Vector2(0.45, 0.15)
@export var boost_torque := Vector2(0.9, 0.3)
## Durée de l'effet « bourré » (s), sans et avec assimilation max.
@export var high_duration := Vector2(13.0, 7.0)
## Dérive de la direction quand on est bourré (degrés) et retard de la direction (0-1).
@export var drunk_drift_deg := 3.0
@export_range(0.0, 1.0) var drunk_steer_lag := 1.0
## Assimilation à partir de laquelle la sobriété devient floue (inversion).
@export var inversion_range := Vector2(0.45, 0.9)

var craving := 0.0
var assimilation := 0.0
var pills_taken := 0
var blackouts := 0

var _car: Node
var _boost := 0.0       # secondes de boost restantes
var _high := 0.0        # secondes d'effet restantes
var _high_total := 1.0
var _blackout := 0.0    # secondes de black-out restantes
var _flash := 0.0       # éclair coloré à la prise
var _shown_assimilation := 0.0
var _t := 0.0
var _overlay: MeshInstance3D
var _overlay_mat: ShaderMaterial
var _env: Environment
var _heart: AudioStreamPlayer
var _gulp: AudioStreamPlayer


func _ready() -> void:
	add_to_group(GROUP)
	craving = start_craving
	_car = get_node_or_null(car_path)
	_heart = AudioStreamPlayer.new()
	_heart.name = "Heartbeat"
	_heart.stream = _make_heartbeat()
	_heart.volume_db = -80.0
	add_child(_heart)
	_gulp = AudioStreamPlayer.new()
	_gulp.name = "PillSound"
	_gulp.stream = _make_pill_sound()
	_gulp.volume_db = -4.0
	add_child(_gulp)
	RenderingServer.global_shader_parameter_set("pill_assimilation", 0.0)


# --- État lisible par d'autres scripts ------------------------------------

func is_boosting() -> bool:
	return _boost > 0.0


func is_blackout() -> bool:
	return _blackout > 0.0


## Effet de la dernière pilule (0-1), qui retombe avec le temps.
func get_high() -> float:
	return clampf(_high / _high_total, 0.0, 1.0)


## Intensité de l'effet « bourré » (0-1). Avec l'inversion, c'est la sobriété qui
## rend bourré et la pilule qui rend la vue nette.
func get_drunk() -> float:
	var high := get_high()
	var tolerance := 1.0 - 0.65 * assimilation
	var inversion := smoothstep(inversion_range.x, inversion_range.y, assimilation)
	return maxf(high * tolerance * (1.0 - inversion), inversion * (1.0 - high))


# --- Prise d'une pilule ------------------------------------------------------

func take_pill() -> void:
	pills_taken += 1
	# Reprendre une pilule alors qu'on plane encore : on s'assimile plus vite.
	var greedy := 1.5 if _high > 0.5 * _high_total else 1.0
	assimilation = clampf(assimilation + assimilation_per_pill * greedy, 0.0, 1.0)
	craving = 0.0
	_blackout = 0.0
	_boost = boost_duration
	_high_total = lerpf(high_duration.x, high_duration.y, assimilation)
	_high = _high_total
	_flash = 1.0
	_gulp.pitch_scale = randf_range(0.95, 1.08)
	_gulp.play()
	pill_taken.emit(pills_taken)


# --- Boucle ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	if _car == null:
		_car = get_node_or_null(car_path)
	_boost = maxf(_boost - delta, 0.0)
	_high = maxf(_high - delta, 0.0)
	_flash = maxf(_flash - delta * 1.5, 0.0)
	if _blackout > 0.0:
		_blackout = maxf(_blackout - delta, 0.0)
		if _blackout == 0.0:
			craving = craving_after_blackout
	else:
		craving = minf(craving + delta / lerpf(craving_time.x, craving_time.y, assimilation), 1.0)
		if craving >= 1.0:
			_blackout = blackout_duration
			blackouts += 1
			blackout_started.emit()
	_apply_to_car()


func _apply_to_car() -> void:
	if _car == null or not ("drug_speed_mult" in _car):
		return
	var tol := 1.0 - assimilation
	# Boost : plein pendant la durée, puis s'éteint sur la dernière seconde et demie.
	var b := clampf(_boost / 1.5, 0.0, 1.0)
	var speed := 1.0 + b * lerpf(boost_speed.y, boost_speed.x, tol)
	var torque := 1.0 + b * lerpf(boost_torque.y, boost_torque.x, tol)
	# Manque : le moteur s'essouffle au-delà d'un tiers de manque (seulement hors boost).
	var c := smoothstep(0.35, 1.0, craving) * (1.0 - b)
	speed *= 1.0 - craving_speed_loss * c
	torque *= 1.0 - craving_power_loss * c
	_car.drug_speed_mult = speed
	_car.drug_torque_mult = torque
	# Direction : mains qui tremblent (manque) + dérive lente et retard (bourré).
	var drunk := get_drunk()
	var shake := deg_to_rad(craving_shake_deg) * c * (sin(_t * 23.0) * 0.6 + sin(_t * 37.0) * 0.4)
	var drift := deg_to_rad(drunk_drift_deg) * drunk * (sin(_t * 0.7) * 0.7 + sin(_t * 1.9 + 1.3) * 0.3)
	_car.drug_steer_offset = shake + drift
	_car.drug_steer_lag = drunk * drunk_steer_lag


func _process(delta: float) -> void:
	_ensure_overlay()
	_hide_from_other_cameras()
	var drunk := get_drunk()
	var high := get_high()
	# Battement de cœur : de plus en plus fort et rapide avec le manque.
	var hb := maxf(smoothstep(0.35, 1.0, craving) * (1.0 - high), 1.0 if _blackout > 0.0 else 0.0)
	_heart.pitch_scale = lerpf(0.85, 1.7, craving)
	_heart.volume_db = linear_to_db(maxf(hb, 0.0001)) - 2.0
	if hb > 0.01 and not _heart.playing:
		_heart.play()
	elif hb <= 0.01 and _heart.playing:
		_heart.stop()
	var pulse := pow(0.5 + 0.5 * sin(_t * TAU * 1.2 * _heart.pitch_scale), 6.0)
	var blackout := 0.0
	if _blackout > 0.0:
		# fondu au noir rapide, retour progressif sur la dernière seconde
		blackout = clampf((blackout_duration - _blackout) / 0.4, 0.0, 1.0) * clampf(_blackout / 1.0, 0.0, 1.0)
	if _overlay_mat:
		_overlay_mat.set_shader_parameter("craving", craving * (1.0 - high))
		_overlay_mat.set_shader_parameter("drunk", drunk)
		_overlay_mat.set_shader_parameter("blackout", blackout)
		_overlay_mat.set_shader_parameter("flash", _flash)
		_overlay_mat.set_shader_parameter("pulse", pulse)
		_overlay_mat.set_shader_parameter("assimilation", assimilation)
	if _env:
		# Couleurs : délavées en manque, saturées sous pilule.
		_env.adjustment_enabled = true
		var sat := lerpf(1.0, 0.2, craving * (1.0 - high)) + 0.8 * high * (1.0 - assimilation) + 0.6 * drunk
		_env.adjustment_saturation = sat
		_env.adjustment_contrast = 1.0 + 0.15 * drunk
	# Le décor se teinte doucement (paramètre global lu par nature_tint.gdshader).
	_shown_assimilation = move_toward(_shown_assimilation, assimilation, delta * 0.1)
	RenderingServer.global_shader_parameter_set("pill_assimilation", _shown_assimilation)


## Filtre plein écran collé devant la caméra active (VR ou bureau).
func _ensure_overlay() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if _overlay and is_instance_valid(_overlay) and _overlay.get_parent() == cam:
		return
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = MeshInstance3D.new()
	_overlay.name = "PillOverlay"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	_overlay.mesh = quad
	_overlay.position = Vector3(0.0, 0.0, -maxf(cam.near * 1.6, 0.08))
	_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_overlay.extra_cull_margin = 16384.0
	_overlay.layers = OVERLAY_LAYER
	_overlay_mat = ShaderMaterial.new()
	_overlay_mat.shader = OVERLAY_SHADER
	_overlay_mat.render_priority = Material.RENDER_PRIORITY_MAX
	_overlay.material_override = _overlay_mat
	cam.add_child(_overlay)
	cam.cull_mask |= OVERLAY_LAYER
	var world := cam.get_world_3d()
	_env = world.environment if world else null


## Les rétroviseurs ont leurs propres caméras, qui regardent vers le conducteur :
## elles ne doivent pas voir le filtre collé devant ses yeux.
func _hide_from_other_cameras() -> void:
	if Engine.get_process_frames() % 30 != 0 or _overlay == null:
		return
	for c in get_tree().root.find_children("*", "Camera3D", true, false):
		if c != _overlay.get_parent():
			(c as Camera3D).cull_mask &= ~OVERLAY_LAYER


# --- Sons générés par code ------------------------------------------------------

func _wav(s: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = s.size()
	return w


## Battement de cœur « poum-poum » en boucle (1 s à hauteur normale).
func _make_heartbeat() -> AudioStreamWAV:
	var n := RATE
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for beat in [[0.0, 1.0], [0.26, 0.7]]:
			var dt: float = t - beat[0]
			if dt >= 0.0:
				v += sin(TAU * (48.0 + 30.0 * exp(-dt * 30.0)) * dt) * exp(-dt * 18.0) * beat[1]
		s[i] = v * 0.9
	return _wav(s, true)


## Prise d'une pilule : « glup » grave puis scintillement montant.
func _make_pill_sound() -> AudioStreamWAV:
	var n := int(RATE * 0.9)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	var ph2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var gulp := sin(TAU * (220.0 - 140.0 * t / 0.12) * t) * exp(-t * 30.0) if t < 0.12 else 0.0
		var f := 300.0 + 1500.0 * pow(t / 0.9, 1.6)
		ph = fmod(ph + f / RATE, 1.0)
		ph2 = fmod(ph2 + f * 1.5 / RATE, 1.0)
		var env := clampf((t - 0.08) / 0.1, 0.0, 1.0) * clampf((0.9 - t) / 0.4, 0.0, 1.0)
		var sparkle := (sin(TAU * ph) * 0.6 + sin(TAU * ph2) * 0.3) * (0.7 + 0.3 * sin(t * 90.0))
		s[i] = gulp * 0.8 + sparkle * env * 0.35
	return _wav(s)
