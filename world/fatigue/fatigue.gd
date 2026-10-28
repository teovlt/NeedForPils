class_name Fatigue
extends Node
## Fatigue du conducteur.
##
## - Monte en roulant (au-dessus de 10 km/h) : pleine fatigue après `time_to_tired`
##   secondes de conduite en plein jour, `night_speed` fois plus vite la nuit (lu dans
##   WeatherSystem.day). À l'arrêt, elle ne monte plus.
## - Effets à partir de `effects_from` : vue qui s'assombrit par les bords, clignements
##   de plus en plus fréquents et lents, bâillements (voix enregistrée + yeux plissés et
##   larmes), puis micro-sommeils (yeux fermés une à deux secondes) quand on est épuisé.
## - Le café du thermos (ThermosCup) la fait baisser : drink_coffee().
## Créée automatiquement par la voiture (SUV4x4) si la scène n'en a pas.

const GROUP := "fatigue"
const OVERLAY_SHADER := preload("res://world/fatigue/fatigue_overlay.gdshader")
const OVERLAY_LAYER := 1 << 19     # même couche que le filtre des pilules (cachée aux rétros)

@export var car_path: NodePath
@export_range(0.0, 1.0) var fatigue := 0.0
## Secondes de conduite (de jour) pour passer de reposé à épuisé.
@export var time_to_tired := 1080.0
## La nuit, la fatigue monte ce nombre de fois plus vite.
@export var night_speed := 2.2
## Niveau à partir duquel les effets apparaissent.
@export_range(0.0, 1.0) var effects_from := 0.3
## Fatigue retirée par tasse de café entière.
@export var coffee_relief := 0.3
## Bâillement (voix à enregistrer, cf. audio/voice/A_ENREGISTRER.md).
@export_file("*.wav", "*.ogg", "*.mp3") var yawn_voice_path := "res://audio/voice/baillement.wav"
@export var yawn_voice_db := 0.0
## Intervalle entre deux bâillements (s) : peu fatigué -> épuisé.
@export var yawn_interval := Vector2(75.0, 22.0)
## Intervalle entre deux clignements (s) : peu fatigué -> épuisé.
@export var blink_interval := Vector2(9.0, 2.2)

var effect := 0.0          # 0 -> 1, fatigue au-delà du seuil des effets
var lids := 0.0            # paupières (0 ouvertes, 1 fermées), lu par les tests
var yawns := 0
var microsleeps := 0

var _car: Node
var _weather: Node
var _t := 0.0
var _blink_next := 4.0
var _blink: Dictionary = {}       # clignement en cours : t, close, hold, open
var _yawn_next := 20.0
var _yawn_t := -1.0               # temps écoulé dans le bâillement en cours
var _tears := 0.0
var _voice: AudioStreamPlayer
var _overlay: MeshInstance3D
var _overlay_mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(GROUP)
	_car = get_node_or_null(car_path)
	_voice = AudioStreamPlayer.new()
	_voice.name = "YawnVoice"
	if ResourceLoader.exists(yawn_voice_path):
		_voice.stream = load(yawn_voice_path) as AudioStream
	_voice.volume_db = yawn_voice_db
	add_child(_voice)
	_yawn_next = _rng.randf_range(15.0, 30.0)


## Fatigue de la scène (0 sans système de fatigue).
static func level(tree: SceneTree) -> float:
	var f := tree.get_first_node_in_group(GROUP)
	return f.fatigue if f else 0.0


## Une tasse de café bue (amount = fraction de tasse).
func drink_coffee(amount: float) -> void:
	fatigue = maxf(fatigue - coffee_relief * amount, 0.0)


## Bâillement immédiat (tests, ou appelé par d'autres scripts).
func yawn() -> void:
	_yawn_t = 0.0
	yawns += 1
	if _voice.stream:
		_voice.play()


func night_factor() -> float:
	if _weather == null or not is_instance_valid(_weather):
		_weather = get_tree().get_first_node_in_group(WeatherSystem.GROUP)
	if _weather == null:
		return 1.0
	return lerpf(night_speed, 1.0, clampf(_weather.day, 0.0, 1.0))


func _physics_process(delta: float) -> void:
	if _car == null or not is_instance_valid(_car):
		return
	var speed := absf(float(_car.get("forward_speed")))
	if speed > 2.8:
		fatigue = minf(fatigue + delta / maxf(time_to_tired, 1.0) * night_factor(), 1.0)


func _process(delta: float) -> void:
	_t += delta
	effect = smoothstep(effects_from, 1.0, fatigue)
	_update_yawn(delta)
	_update_blink(delta)
	# paupières : lourdes quand on est épuisé, + clignement, + yeux plissés du bâillement
	var droop := 0.12 * effect * (0.6 + 0.4 * sin(_t * 0.5))
	lids = clampf(maxf(maxf(droop, _blink_value()), _yawn_squint()), 0.0, 1.0)
	_tears = move_toward(_tears, 0.0, delta / 7.0)
	_ensure_overlay()
	_hide_from_other_cameras()
	if _overlay_mat:
		_overlay_mat.set_shader_parameter("dim", effect * 0.85)
		_overlay_mat.set_shader_parameter("lids", lids)
		_overlay_mat.set_shader_parameter("tears", _tears)
	if _overlay:
		_overlay.visible = effect > 0.001 or lids > 0.001 or _tears > 0.001


func _update_yawn(delta: float) -> void:
	if _yawn_t >= 0.0:
		_yawn_t += delta
		if _yawn_t > 2.0:
			_tears = maxf(_tears, smoothstep(2.0, 3.5, _yawn_t))
		if _yawn_t > 4.5:
			_yawn_t = -1.0
			_blink_next = minf(_blink_next, 0.6)   # on cligne pour chasser les larmes
	if effect <= 0.0:
		return
	_yawn_next -= delta
	if _yawn_next <= 0.0 and _yawn_t < 0.0:
		yawn()
		_yawn_next = lerpf(yawn_interval.x, yawn_interval.y, effect) * _rng.randf_range(0.7, 1.3)


## Yeux plissés pendant le bâillement (pic au milieu).
func _yawn_squint() -> float:
	if _yawn_t < 0.0:
		return 0.0
	return 0.6 * smoothstep(0.6, 1.8, _yawn_t) * (1.0 - smoothstep(3.2, 4.4, _yawn_t))


func _update_blink(delta: float) -> void:
	if not _blink.is_empty():
		_blink.t += delta
		if _blink.t > _blink.close + _blink.hold + _blink.open:
			_blink = {}
	if effect <= 0.0:
		return
	_blink_next -= delta
	if _blink_next <= 0.0 and _blink.is_empty():
		_blink_next = lerpf(blink_interval.x, blink_interval.y, effect) * _rng.randf_range(0.6, 1.4)
		var sleep_chance := clampf((effect - 0.55) * 0.8, 0.0, 0.35)
		if _rng.randf() < sleep_chance:
			# micro-sommeil : les paupières tombent lentement et restent fermées
			microsleeps += 1
			_blink = {"t": 0.0, "close": 0.45, "hold": _rng.randf_range(0.5, 0.8 + 1.2 * effect), "open": 0.35}
		else:
			var slow := lerpf(1.0, 2.2, effect)
			_blink = {"t": 0.0, "close": 0.07 * slow, "hold": 0.05 * slow, "open": 0.11 * slow}


func _blink_value() -> float:
	if _blink.is_empty():
		return 0.0
	var t: float = _blink.t
	if t < _blink.close:
		return smoothstep(0.0, 1.0, t / _blink.close)
	t -= _blink.close
	if t < _blink.hold:
		return 1.0
	t -= _blink.hold
	return 1.0 - smoothstep(0.0, 1.0, t / _blink.open)


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
	_overlay.name = "FatigueOverlay"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	_overlay.mesh = quad
	_overlay.position = Vector3(0.0, 0.0, -maxf(cam.near * 1.6, 0.08))
	_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_overlay.extra_cull_margin = 16384.0
	_overlay.layers = OVERLAY_LAYER
	_overlay_mat = ShaderMaterial.new()
	_overlay_mat.shader = OVERLAY_SHADER
	_overlay_mat.render_priority = 101   # par-dessus le filtre des pilules (100)
	_overlay.material_override = _overlay_mat
	cam.add_child(_overlay)
	cam.cull_mask |= OVERLAY_LAYER


func _hide_from_other_cameras() -> void:
	if Engine.get_process_frames() % 30 != 0 or _overlay == null:
		return
	for c in get_tree().root.find_children("*", "Camera3D", true, false):
		if c != _overlay.get_parent():
			(c as Camera3D).cull_mask &= ~OVERLAY_LAYER
