class_name Pursuer
extends Node3D
## La police. Pendant qu'on roule (start_patrols), elle surgit au hasard, de trois façons :
## - « bord » : une voiture garée sur le bas-côté, tous feux éteints ; elle allume ses
##   gyrophares et démarre quand on vient de la dépasser ;
## - « barrage » : deux voitures en chicane en travers de la route, gyrophares allumés
##   (une voie libre à chaque fois, il faut ralentir pour passer) ; une des deux démarre
##   une fois le barrage passé ;
## - « derriere » : elle apparaît loin derrière nous et remonte jusqu'à ~80 m.
##
## Poursuite « virtuelle » : on suit seulement l'écart (m, le long de la route) entre
## elle et le joueur. Tant qu'on roule pied au plancher sans freiner, elle s'aligne sur
## notre vitesse sans dépasser sa vitesse de croisière : pour la semer, il faut rouler
## plus vite qu'elle (lignes droites, boost des Pils). Lâcher l'accélérateur, freiner,
## percuter un arbre ou le manque la rapprochent. Rester à plus de `lose_gap` m pendant
## `lose_time` s la sème : la rencontre suivante arrive plus loin, un peu plus rapide.
## La voiture visible est posée sur la route à l'écart voulu (visible dans les rétros),
## gyrophares bleus, sirène. Pas de collision en poursuite : rattrapé = écart < `catch_gap`.
## À l'arrêt (bas-côté, barrage), les voitures ont une collision.

signal caught
signal chase_started(kind: String)
signal lost

const GROUP := "pursuer"
## Voiture low poly (props/police_car/police_car_build.py) : nœud Body et 4 roues Wheel_*.
const BODY := preload("res://props/police_car/police_car.glb")
const WHEEL_RADIUS := 0.34
## Centre du toit (z) pour la rampe de gyrophares.
const ROOF_Z := -0.1
const RATE := 22050
const KINDS := ["bord", "barrage", "derriere"]
const BLUE := Color(0.15, 0.35, 1.0)
## Angle des voitures du barrage par rapport à la route (degrés).
const BLOCK_ANGLE := 60.0
## Distance (m) entre les deux voitures du barrage, et leur écart à l'axe de la route
## (chacune barre une voie ; ~3,6 m restent libres à côté).
const BLOCK_SPACING := 30.0
const BLOCK_LAT := 2.2

enum State { IDLE, ESCORT, CHASE, STOPPED, FREE, WAIT, BLOCK }

@export var road_path: NodePath
@export var car_path: NodePath
@export_group("Rencontres")
## Rencontres tirées au hasard (désactivé dans certains tests : force_encounter()).
@export var auto_encounters := true
## Distance parcourue (m) avant la première rencontre, puis entre deux rencontres.
@export var first_encounter := Vector2(450.0, 1100.0)
@export var next_encounter := Vector2(900.0, 2200.0)
## Poids de chaque type : bord, barrage, derrière.
@export var kind_weights := Vector3(0.35, 0.3, 0.35)
## Distance (m) devant le joueur où l'on pose la voiture garée ou le barrage.
@export var spawn_ahead := 260.0
## « derrière » : écart d'apparition (m), puis elle remonte (+`approach_bonus` km/h sur
## nous) jusqu'à `approach_gap` m.
@export var behind_gap := 190.0
@export var approach_gap := 80.0
@export var approach_bonus := 30.0
@export_group("Poursuite")
## Vitesse de croisière (km/h) au début de la partie et au bout de `ramp_time` s de jeu,
## plus `encounter_bonus` km/h par rencontre déjà faite. Le 4x4 plafonne à ~154 km/h en D.
@export var speed_start := 115.0
@export var speed_end := 135.0
@export var ramp_time := 900.0
@export var encounter_bonus := 3.0
## Accélération (km/h par s) quand elle démarre arrêtée (bas-côté, barrage).
@export var launch_accel := 14.0
## Écart (m) auquel on est rattrapé.
@export var catch_gap := 6.0
## Écart (m) au début d'une poursuite lancée directement (start_chase).
@export var start_gap := 60.0
## Secondes de grâce au début d'une poursuite : elle suit notre vitesse quoi qu'on fasse.
@export var grace_time := 4.0
## Après un choc contre un arbre, elle roule à sa vitesse de croisière pendant ce temps.
@export var hit_penalty_time := 4.0
## Semée : écart (m) au-delà duquel elle nous perd, tenu pendant `lose_time` s.
@export var lose_gap := 300.0
@export var lose_time := 5.0

var state := State.IDLE
var gap := 999.0
var chase_time := 0.0
## Type de la rencontre en cours (« bord », « barrage », « derriere »).
var kind := ""
## Nombre de poursuites lancées depuis le début de la partie.
var encounters := 0

var _road: RoadGenerator
var _car: Node3D
var _s := 0.0              # position le long de la route (m)
var _t := 0.0
var _game_time := 0.0
var _escort_gap := 40.0
var _speed := 100.0          # vitesse actuelle (km/h)
var _penalty := 0.0
var _last_hits := 0
var _next_s := INF
var _far_t := 0.0
var _approach := false
var _launching := false
var _yaw_off := 0.0
var _anchor: Node3D          # tronçon de route qui porte la voiture arrêtée
var _anchor_xf := Transform3D()
var _block_s2 := 0.0
var _block_lat := [0.0, 0.0]
var _props: Array[Node3D] = []     # 2e voiture du barrage, plots
var _prop_mats: Array[StandardMaterial3D] = []
var _prop_lights: Array[OmniLight3D] = []
var _visual: Node3D
var _bar_mats: Array[StandardMaterial3D] = []
var _bar_lights: Array[OmniLight3D] = []
var _head: Array[Node3D] = []      # phares (lumières et halos)
var _wheels: Array[Node3D] = []
var _shape: CollisionShape3D
var _lights_on := true
var _siren: AudioStreamPlayer3D
var _lateral := 1.75


func _ready() -> void:
	add_to_group(GROUP)
	_road = get_node_or_null(road_path) as RoadGenerator
	_car = get_node_or_null(car_path) as Node3D
	_visual = Node3D.new()
	_visual.name = "PoliceCar"
	add_child(_visual)
	var parts := _make_car(_visual, true, true)
	_bar_mats = parts["mats"]
	_bar_lights = parts["lights"]
	_head = parts["head"]
	_wheels = parts["wheels"]
	_shape = parts["shape"]
	_shape.disabled = true
	_siren = AudioStreamPlayer3D.new()
	_siren.name = "Siren"
	_siren.stream = _make_siren()
	_siren.unit_size = 18.0
	_siren.max_distance = 400.0
	_siren.volume_db = -6.0
	_visual.add_child(_siren)
	_visual.visible = false


# --- Pilotage (ChaseDirector) ------------------------------------------------

## Début de partie : la police patrouille, les rencontres arrivent au hasard.
func start_patrols() -> void:
	if state == State.STOPPED:
		return
	_clear_encounter()
	state = State.FREE
	_siren.stop()
	_visual.visible = false
	_next_s = _car_s() + randf_range(first_encounter.x, first_encounter.y)


## Intro : colle derrière le joueur à `escort_gap` m (plan aérien).
func start_escort(escort_gap: float) -> void:
	_escort_gap = escort_gap
	state = State.ESCORT
	_set_lights(true)
	_visual.visible = true
	_siren.play()


func set_escort_gap(escort_gap: float) -> void:
	_escort_gap = escort_gap


## Poursuite immédiate, `start_gap` m derrière nous.
func start_chase() -> void:
	if state == State.STOPPED:
		return
	_clear_encounter()
	_begin_chase(_car_s() - start_gap, _player_kmh(), "derriere")


## Lance tout de suite une rencontre d'un type donné (tests). `ahead` < 0 : spawn_ahead.
func force_encounter(k: String, ahead := -1.0) -> bool:
	if state == State.STOPPED:
		return false
	_clear_encounter()
	var a := spawn_ahead if ahead < 0.0 else ahead
	match k:
		"bord":
			return _setup_roadside(a)
		"barrage":
			return _setup_roadblock(a)
		_:
			_begin_chase(_car_s() - behind_gap, _player_kmh(), "derriere")
			_approach = true
			return true


func stop() -> void:
	state = State.STOPPED


## Position de la voiture visible (monde).
func get_car_position() -> Vector3:
	return _visual.global_position


## Vitesse actuelle de la police (km/h).
func get_speed_kmh() -> float:
	return _speed


## Barrage en cours : [s 1re voiture, latéral, s 2e voiture, latéral] (tests, IA).
func get_block_info() -> Array:
	return [_s, _block_lat[0], _block_s2, _block_lat[1]] if state == State.BLOCK else []


## Position le long de la route (m) de la voiture de police.
func get_s() -> float:
	return _s


func cruise_kmh() -> float:
	return lerpf(speed_start, speed_end, clampf(_game_time / ramp_time, 0.0, 1.0)) \
		+ encounter_bonus * maxf(encounters - 1, 0)


func _player_kmh() -> float:
	var body := _car as RigidBody3D
	return maxf(body.linear_velocity.dot(body.global_basis.z) * 3.6, 0.0) if body else 0.0


## Vitesse visée : sa croisière, ou la nôtre si on fait de notre mieux.
func _update_speed(delta: float) -> void:
	var cruise := cruise_kmh()
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
	if _approach:
		if gap > approach_gap:
			target = maxf(cruise, _player_kmh() + approach_bonus)
		else:
			_approach = false
	var rate := 30.0
	if _launching:
		rate = launch_accel
		if _speed >= target - 1.0:
			_launching = false
	_speed = move_toward(_speed, target, rate * delta)


func _car_s() -> float:
	var s := _road.sample_road(_car.global_position)
	return s["s"] if s["found"] else _s


# --- Rencontres ---------------------------------------------------------------------

func _spawn_random() -> void:
	var w := kind_weights
	var r := randf() * (w.x + w.y + w.z)
	var k := "bord" if r < w.x else ("barrage" if r < w.x + w.y else "derriere")
	if not force_encounter(k):
		_next_s = _car_s() + 60.0   # route pas encore générée : on réessaie un peu plus loin


func _schedule_next() -> void:
	_next_s = _car_s() + randf_range(next_encounter.x, next_encounter.y)


## Pose la voiture arrêtée à `lat` m de l'axe, tournée de `yaw` (rad), sur le tronçon.
func _anchor_at(sample: Dictionary, lat: float, yaw: float) -> void:
	var dir: Vector3 = sample["dir"]
	var basis := Basis(Vector3.UP, yaw) * Basis.looking_at(-dir, Vector3.UP)
	_anchor = sample["chunk"]
	_anchor_xf = _anchor.global_transform.affine_inverse() * Transform3D(basis, _road.ground_position(sample, lat))
	_visual.global_transform = _anchor.global_transform * _anchor_xf
	_lateral = lat
	_yaw_off = yaw


func _setup_roadside(ahead: float) -> bool:
	var sample := _road.sample_ahead(_car.global_position, ahead)
	if not sample["found"]:
		return false
	kind = "bord"
	_s = sample["s"]
	# sur l'accotement, bien dégagée de la voie de droite (~0,7 m entre les deux voitures)
	_anchor_at(sample, _road.road_half_width + 0.45, deg_to_rad(randf_range(-2.0, 2.0)))
	state = State.WAIT
	gap = _car_s() - _s
	_set_lights(false)
	_set_collision(true)
	_visual.visible = true
	_siren.stop()
	print("Police : voiture garée sur le bas-côté à %d m" % roundi(ahead))
	return true


func _setup_roadblock(ahead: float) -> bool:
	var s1 := _road.sample_ahead(_car.global_position, ahead)
	var s2 := _road.sample_ahead(_car.global_position, ahead + BLOCK_SPACING)
	if not s1["found"] or not s2["found"]:
		return false
	kind = "barrage"
	var side := 1.0 if randf() < 0.5 else -1.0   # voie barrée par la 1re voiture
	_s = s1["s"]
	_block_s2 = s2["s"]
	_block_lat = [BLOCK_LAT * side, -BLOCK_LAT * side]
	_anchor_at(s1, BLOCK_LAT * side, deg_to_rad(BLOCK_ANGLE) * side)
	# 2e voiture, en travers de l'autre voie, posée sur son tronçon
	var b := Node3D.new()
	b.name = "Roadblock2"
	(s2["chunk"] as Node3D).add_child(b)
	var dir2: Vector3 = s2["dir"]
	b.global_transform = Transform3D(Basis(Vector3.UP, -deg_to_rad(BLOCK_ANGLE) * side) * Basis.looking_at(-dir2, Vector3.UP),
		_road.ground_position(s2, -BLOCK_LAT * side))
	var parts := _make_car(b, false, true)
	_prop_mats = parts["mats"]
	_prop_lights = parts["lights"]
	_props.append(b)
	# plots orange devant chaque voiture, côté bas-côté
	for k in 2:
		var lat: float = _block_lat[k]
		for i in 3:
			var cs := _road.sample_ahead(_car.global_position, ahead + k * BLOCK_SPACING - 7.0 + i * 1.6)
			if cs["found"]:
				_props.append(_cone(cs["chunk"], _road.ground_position(cs, signf(lat) * (3.6 - i * 0.55))))
	state = State.BLOCK
	gap = _car_s() - _s
	_set_lights(true)
	_set_collision(true)
	_visual.visible = true
	_siren.stop()
	print("Police : barrage à %d m (1re voiture sur la voie %s)" % [roundi(ahead), "de droite" if side > 0 else "de gauche"])
	return true


func _cone(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	n.global_position = pos
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.16
	cm.height = 0.55
	cm.radial_segments = 8
	cm.rings = 1
	cone.mesh = cm
	cone.position.y = 0.28
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.4, 0.05)
	cone.material_override = m
	n.add_child(cone)
	var band := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.09
	bm.bottom_radius = 0.11
	bm.height = 0.08
	bm.radial_segments = 8
	bm.rings = 1
	band.mesh = bm
	band.position.y = 0.3
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.95, 0.95, 0.95)
	band.material_override = wm
	n.add_child(band)
	var base := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.38, 0.04, 0.38)
	base.mesh = box
	base.position.y = 0.02
	base.material_override = m
	n.add_child(base)
	return n


func _clear_encounter() -> void:
	for p in _props:
		if is_instance_valid(p):
			p.queue_free()
	_props.clear()
	_prop_mats.clear()
	_prop_lights.clear()
	_anchor = null
	_approach = false
	_launching = false
	_set_collision(false)


func _begin_chase(s: float, speed: float, k: String) -> void:
	state = State.CHASE
	kind = k
	chase_time = 0.0
	_s = s
	_speed = speed
	_far_t = 0.0
	encounters += 1
	_anchor = null
	_set_lights(true)
	_set_collision(false)
	_visual.visible = true
	if not _siren.playing:
		_siren.play()
	print("Police : poursuite (%s), croisière %d km/h" % [k, roundi(cruise_kmh())])
	chase_started.emit(k)


func _on_lost() -> void:
	print("Police : semée après %d s de poursuite" % roundi(chase_time))
	state = State.FREE
	_siren.stop()
	_visual.visible = false
	_clear_encounter()
	_schedule_next()
	lost.emit()


# --- Boucle -----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _road == null or _car == null:
		return
	_t += delta
	var car_s := _car_s()
	match state:
		State.IDLE:
			return
		State.FREE:
			_game_time += delta
			if auto_encounters and car_s >= _next_s:
				_spawn_random()
			_flash()
			return
		State.WAIT, State.BLOCK:
			_game_time += delta
			if not is_instance_valid(_anchor):
				# tronçon libéré (on est passé loin ailleurs) : rencontre annulée
				state = State.FREE
				_visual.visible = false
				_clear_encounter()
				_schedule_next()
				return
			_visual.global_transform = _anchor.global_transform * _anchor_xf
			gap = car_s - _s
			# démarre quand on l'a dépassée (bas-côté) ou qu'on a passé le barrage
			var pass_s := _s + 10.0 if state == State.WAIT else _block_s2 + 6.0
			if car_s > pass_s:
				_launching = true
				_begin_chase(_s, 0.0, kind)
			_flash()
			return
		State.ESCORT:
			_s = car_s - _escort_gap
		State.CHASE:
			_game_time += delta
			chase_time += delta
			_update_speed(delta)
			_s += _speed / 3.6 * delta
			gap = car_s - _s
			if gap < catch_gap:
				state = State.STOPPED
				_siren.stop()
				caught.emit()
			elif gap > lose_gap and not _approach:   # pas semée pendant qu'elle remonte
				_far_t += delta
				if _far_t >= lose_time:
					_on_lost()
					return
			else:
				_far_t = 0.0
		State.STOPPED:
			pass   # reste sur place
	gap = car_s - _s
	_place(delta)
	_flash()


## Pose la voiture visible sur la route, à `gap` m derrière le joueur.
func _place(delta: float) -> void:
	var sample := _road.sample_ahead(_car.global_position, -gap)
	if not sample["found"] or gap > maxf(lose_gap, 300.0):
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
	_yaw_off = move_toward(_yaw_off, 0.0, delta * 1.4)   # elle se remet dans l'axe en démarrant
	var pos := _road.ground_position(sample, _lateral)
	var dir: Vector3 = sample["dir"]
	var basis := Basis(Vector3.UP, _yaw_off) * Basis.looking_at(-dir, Vector3.UP)   # +Z du modèle = avant
	_visual.global_transform = Transform3D(basis, pos)
	# roues qui tournent avec la vitesse
	var spin := _speed / 3.6 / WHEEL_RADIUS * delta
	for w in _wheels:
		w.rotate_object_local(Vector3.RIGHT, spin)


## Gyrophares bleus alternés (voiture de police et 2e voiture du barrage).
func _flash() -> void:
	var phase := fmod(_t * 3.0, 1.0) < 0.5
	for i in _bar_mats.size():
		var on := _lights_on and ((i % 2 == 0) == phase)
		_bar_mats[i].emission_energy_multiplier = 6.0 if on else 0.15
		_bar_lights[i].light_energy = 5.0 if on else 0.0
	for i in _prop_mats.size():
		var on := (i % 2 == 0) == phase
		_prop_mats[i].emission_energy_multiplier = 6.0 if on else 0.15
		if i < _prop_lights.size() and is_instance_valid(_prop_lights[i]):
			_prop_lights[i].light_energy = 5.0 if on else 0.0


func _set_lights(on: bool) -> void:
	_lights_on = on
	for h in _head:
		h.visible = on
	_flash()


func _set_collision(on: bool) -> void:
	if _shape:
		_shape.set_deferred("disabled", not on)


# --- Modèle -------------------------------------------------------------------------

## Voiture de police : caisse low poly, rampe de gyrophares bleus et « POLICE » sur les
## flancs et le coffre ; phares si `head`, collision (boîte) si `solid`.
func _make_car(parent: Node3D, head: bool, solid: bool) -> Dictionary:
	var body := BODY.instantiate() as Node3D
	parent.add_child(body)
	var aabb := _local_aabb(body)
	if aabb.size == Vector3.ZERO:
		aabb = AABB(Vector3(-0.95, 0.0, -2.4), Vector3(1.9, 1.4, 4.8))
	var wheels: Array[Node3D] = []
	for n in ["Wheel_FL", "Wheel_FR", "Wheel_BL", "Wheel_BR"]:
		var w := body.find_child(n, true, false) as Node3D
		if w:
			wheels.append(w)
	var top := aabb.end.y
	var cz := ROOF_Z + 0.2
	var mats: Array[StandardMaterial3D] = []
	var lights: Array[OmniLight3D] = []
	var heads: Array[Node3D] = []
	for i in 2:
		var x := -0.35 if i == 0 else 0.35
		var lamp := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.55, 0.14, 0.25)
		lamp.mesh = box
		var m := StandardMaterial3D.new()
		m.albedo_color = BLUE
		m.emission_enabled = true
		m.emission = BLUE
		lamp.material_override = m
		lamp.position = Vector3(x, top + 0.02, cz - 0.2)
		parent.add_child(lamp)
		mats.append(m)
		var l := OmniLight3D.new()
		l.light_color = BLUE
		l.omni_range = 14.0
		l.position = Vector3(x, top + 0.3, cz - 0.2)
		parent.add_child(l)
		lights.append(l)
	var base := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(1.2, 0.06, 0.3)
	base.mesh = bb
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.12, 0.14)
	base.material_override = dark
	base.position = Vector3(0, top - 0.03, cz - 0.2)
	parent.add_child(base)
	# inscriptions (la bande bleue est dans le modèle) : portières et coffre
	for sx in [-1.0, 1.0]:
		parent.add_child(_police_label(Vector3(sx * 0.912, 0.89, -0.15), 90.0 * sx))
	var rear := _police_label(Vector3(0.0, 0.74, -2.33), 180.0)
	rear.pixel_size = 0.0032
	parent.add_child(rear)
	if head:
		for x in [-0.6, 0.6]:
			var spot := SpotLight3D.new()
			spot.light_color = Color(0.95, 0.95, 1.0)
			spot.light_energy = 6.0
			spot.spot_range = 60.0
			spot.spot_angle = 28.0
			spot.position = Vector3(x, 0.66, 2.32)
			spot.rotation = Vector3(deg_to_rad(-4.0), PI, 0.0)   # éclaire vers +Z (l'avant)
			parent.add_child(spot)
			heads.append(spot)
			var glow := MeshInstance3D.new()   # phare allumé (plaque lumineuse sur le phare du modèle)
			var plate := BoxMesh.new()
			plate.size = Vector3(0.34, 0.12, 0.02)
			glow.mesh = plate
			var gm := StandardMaterial3D.new()
			gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			gm.albedo_color = Color(1.0, 1.0, 0.95)
			glow.material_override = gm
			glow.position = Vector3(x, 0.66, 2.285)
			parent.add_child(glow)
			heads.append(glow)
	var shape: CollisionShape3D = null
	if solid:
		var sbody := StaticBody3D.new()
		sbody.name = "PoliceCollision"
		parent.add_child(sbody)
		shape = CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = aabb.size
		shape.shape = bs
		shape.position = aabb.get_center()
		sbody.add_child(shape)
	return {"mats": mats, "lights": lights, "head": heads, "shape": shape, "wheels": wheels}


func _police_label(pos: Vector3, yaw_deg: float) -> Label3D:
	var l := Label3D.new()
	l.text = "POLICE"
	l.font_size = 64
	l.pixel_size = 0.0045
	l.modulate = Color(0.06, 0.16, 0.55)
	l.outline_modulate = Color(0.97, 0.97, 1.0)
	l.outline_size = 10
	l.position = pos
	l.rotation_degrees.y = yaw_deg
	l.double_sided = false
	return l


## Boîte englobante des maillages de `root`, dans le repère de `root`.
func _local_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf := Transform3D()
		var n: Node = m
		while n != root and n is Node3D:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var a := xf * m.mesh.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


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
