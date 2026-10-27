class_name Pursuer
extends Node3D
## La voiture de l'Essaim qui nous poursuit.
##
## Poursuite « virtuelle » : on suit seulement l'écart (m, le long de la route) entre
## elle et le joueur. Tant qu'on roule pied au plancher sans freiner, elle s'aligne sur
## notre vitesse (sans dépasser sa vitesse de croisière) : en montée, elle ralentit
## avec nous et l'écart tient. Lâcher l'accélérateur, freiner, percuter un arbre ou le
## manque (qui bride le moteur) la rapprochent ; le boost d'une pilule nous en éloigne. Très
## loin derrière, elle remonte plus vite (elle ne lâche jamais). La voiture visible est posée sur la route à
## l'écart voulu (visible dans les rétros), gyrophares roses et bleus, sirène.
## Pas de collision : rattrapé = écart < `catch_gap`.

signal caught

const GROUP := "pursuer"
const BODY := preload("res://cars/Models/Doge/doge-body.glb")
const RATE := 22050

enum State { IDLE, ESCORT, CHASE, STOPPED }

@export var road_path: NodePath
@export var car_path: NodePath
@export_group("Poursuite")
## Vitesse de croisière (km/h) au début de la poursuite et au bout de `ramp_time` s.
## Le 4x4 tient ~105-110 km/h pied au plancher sans manque, sur le plat.
@export var speed_start := 100.0
@export var speed_end := 110.0
@export var ramp_time := 600.0
## Au-delà de cet écart (m), elle remonte plus vite (+`catch_up_bonus` km/h).
@export var far_gap := 260.0
@export var catch_up_bonus := 45.0
## Écart (m) auquel on est rattrapé.
@export var catch_gap := 6.0
## Écart (m) au début de la poursuite.
@export var start_gap := 60.0
## Secondes de grâce à la prise en main : elle suit notre vitesse quoi qu'on fasse.
@export var grace_time := 4.0
## Après un choc contre un arbre, elle roule à sa vitesse de croisière pendant ce temps.
@export var hit_penalty_time := 4.0

var state := State.IDLE
var gap := 999.0
var chase_time := 0.0

var _road: RoadGenerator
var _car: Node3D
var _s := 0.0              # position le long de la route (m)
var _t := 0.0
var _escort_gap := 40.0
var _speed := 100.0          # vitesse actuelle (km/h, hors rattrapage de loin)
var _penalty := 0.0
var _last_hits := 0
var _visual: Node3D
var _bar_mats: Array[StandardMaterial3D] = []
var _bar_lights: Array[OmniLight3D] = []
var _siren: AudioStreamPlayer3D
var _lateral := 1.75


func _ready() -> void:
	add_to_group(GROUP)
	_road = get_node_or_null(road_path) as RoadGenerator
	_car = get_node_or_null(car_path) as Node3D
	_build_visual()
	_siren = AudioStreamPlayer3D.new()
	_siren.name = "Siren"
	_siren.stream = _make_siren()
	_siren.unit_size = 18.0
	_siren.max_distance = 400.0
	_siren.volume_db = -6.0
	_visual.add_child(_siren)
	_visual.visible = false


# --- Pilotage (ChaseDirector) ------------------------------------------------

## Intro : colle derrière le joueur à `escort_gap` m (plan aérien).
func start_escort(escort_gap: float) -> void:
	_escort_gap = escort_gap
	state = State.ESCORT
	_siren.play()


func set_escort_gap(escort_gap: float) -> void:
	_escort_gap = escort_gap


func start_chase() -> void:
	if state == State.STOPPED:
		return
	state = State.CHASE
	chase_time = 0.0
	_s = _car_s() - start_gap
	_speed = _player_kmh()
	if not _siren.playing:
		_siren.play()


func stop() -> void:
	state = State.STOPPED


## Position de la voiture visible (monde).
func get_car_position() -> Vector3:
	return _visual.global_position


## Vitesse actuelle de la poursuivante (km/h).
func get_speed_kmh() -> float:
	return _speed + (catch_up_bonus if gap > far_gap else 0.0)


func _player_kmh() -> float:
	var body := _car as RigidBody3D
	return maxf(body.linear_velocity.dot(body.global_basis.z) * 3.6, 0.0) if body else 0.0


## Vitesse visée : sa croisière, ou la nôtre si on fait de notre mieux.
func _update_speed(delta: float) -> void:
	var cruise := lerpf(speed_start, speed_end, clampf(chase_time / ramp_time, 0.0, 1.0))
	var trees := get_tree().get_first_node_in_group(FallingTreeManager.GROUP) as FallingTreeManager
	if trees and trees.tree_hits > _last_hits:
		_last_hits = trees.tree_hits
		_penalty = hit_penalty_time
	_penalty = maxf(_penalty - delta, 0.0)
	var pushing := false
	if "throttle_input" in _car:
		pushing = _car.throttle_input > 0.8 and _car.brake_input < 0.1 and _car.get_handbrake_amount() < 0.3
	var target := cruise
	if (pushing or chase_time < grace_time) and _penalty == 0.0:
		# Le moteur bridé par le manque n'est pas une excuse : on retire ce bridage.
		var bridle: float = minf(_car.get("drug_speed_mult") if "drug_speed_mult" in _car else 1.0, 1.0)
		target = minf(cruise, _player_kmh() / maxf(bridle, 0.5) + 1.0)
	_speed = move_toward(_speed, target, 30.0 * delta)


func _car_s() -> float:
	var s := _road.sample_road(_car.global_position)
	return s["s"] if s["found"] else _s


# --- Boucle -----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _road == null or _car == null:
		return
	_t += delta
	var car_s := _car_s()
	match state:
		State.IDLE:
			return
		State.ESCORT:
			_s = car_s - _escort_gap
		State.CHASE:
			chase_time += delta
			_update_speed(delta)
			_s += get_speed_kmh() / 3.6 * delta
		State.STOPPED:
			pass   # reste sur place
	gap = car_s - _s
	if state == State.CHASE and gap < catch_gap:
		state = State.STOPPED
		caught.emit()
	_place()


## Pose la voiture visible sur la route, à `gap` m derrière le joueur.
func _place() -> void:
	var sample := _road.sample_ahead(_car.global_position, -gap)
	if not sample["found"] or gap > 300.0:
		_visual.visible = false
		return
	_visual.visible = true
	# Sur sa voie ; de près, elle se colle derrière le joueur.
	var own := _road.sample_road(_car.global_position)
	var target_lat := 1.75
	if own["found"]:
		target_lat = signf(own["lateral"]) * 1.75 if absf(own["lateral"]) > 0.4 else 1.75
		if gap < 40.0:
			target_lat = lerpf(target_lat, own["lateral"], clampf((40.0 - gap) / 30.0, 0.0, 1.0))
	_lateral = lerpf(_lateral, target_lat, 0.05)
	var pos := _road.ground_position(sample, _lateral)
	var dir: Vector3 = sample["dir"]
	var basis := Basis.looking_at(-dir, Vector3.UP)   # +Z du modèle = avant
	_visual.global_transform = Transform3D(basis, pos)
	# Gyrophares alternés rose / bleu.
	var phase := fmod(_t * 3.0, 1.0) < 0.5
	for i in _bar_mats.size():
		var on := (i % 2 == 0) == phase
		_bar_mats[i].emission_energy_multiplier = 6.0 if on else 0.3
		_bar_lights[i].light_energy = 5.0 if on else 0.0


# --- Modèle -------------------------------------------------------------------------

func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "PursuerCar"
	add_child(_visual)
	var body := BODY.instantiate() as Node3D
	_visual.add_child(body)
	# Rampe de gyrophares sur le toit.
	var colors := [Color(1.0, 0.2, 0.75), Color(0.2, 0.4, 1.0)]
	for i in 2:
		var x := -0.35 if i == 0 else 0.35
		var lamp := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.55, 0.14, 0.25)
		lamp.mesh = box
		var m := StandardMaterial3D.new()
		m.albedo_color = colors[i]
		m.emission_enabled = true
		m.emission = colors[i]
		lamp.material_override = m
		lamp.position = Vector3(x, 1.42, -0.2)
		_visual.add_child(lamp)
		_bar_mats.append(m)
		var l := OmniLight3D.new()
		l.light_color = colors[i]
		l.omni_range = 14.0
		l.position = Vector3(x, 1.7, -0.2)
		_visual.add_child(l)
		_bar_lights.append(l)
	# Phares blancs aveuglants.
	for x in [-0.7, 0.7]:
		var spot := SpotLight3D.new()
		spot.light_color = Color(0.95, 0.95, 1.0)
		spot.light_energy = 6.0
		spot.spot_range = 60.0
		spot.spot_angle = 28.0
		spot.position = Vector3(x, 0.75, 2.3)
		spot.rotation = Vector3(deg_to_rad(-4.0), PI, 0.0)   # éclaire vers +Z (l'avant)
		_visual.add_child(spot)
		var glow := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.13
		sphere.height = 0.26
		glow.mesh = sphere
		var gm := StandardMaterial3D.new()
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.albedo_color = Color(1.0, 1.0, 0.95)
		glow.material_override = gm
		glow.position = Vector3(x, 0.72, 2.32)
		_visual.add_child(glow)


## Sirène à deux tons (son en boucle).
func _make_siren() -> AudioStreamWAV:
	var n := int(RATE * 1.2)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 660.0 if t < 0.6 else 880.0
		ph = fmod(ph + f / RATE, 1.0)
		var tri := 1.0 - 4.0 * absf(ph - 0.5)
		var sq := 1.0 if ph < 0.5 else -1.0
		var edge := clampf(minf(fmod(t, 0.6), 0.6 - fmod(t, 0.6)) / 0.01, 0.0, 1.0)
		s[i] = (tri * 0.6 + sq * 0.15) * 0.45 * edge
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	return w
