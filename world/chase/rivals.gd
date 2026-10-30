class_name Rivals
extends Node3D
## Les concurrents : un vieux camping-car beige et brun (labo roulant) dont les
## occupants veulent ta came. Événement aléatoire pendant qu'on roule (créé et lancé
## par ChaseDirector) :
## - il surgit loin derrière et remonte vite ;
## - à moins de `shoot_range` m, le passager tire par sa fenêtre (éclairs, coups de feu) ;
##   une balle sur trois environ touche le 4x4 (impact, vibration, vitre étoilée) ;
## - collé à nous, il se met à notre hauteur sur l'autre voie et donne des coups de
##   flanc (le 4x4 est poussé de côté) ;
## - `max_hits` impacts : ils t'ont eu (fin de partie) ;
## - pour le semer, comme la police : creuser l'écart au-delà de `lose_gap` m pendant
##   `lose_time` s (il roule moins vite que le 4x4 pied au plancher, mais il ne lâche
##   pas si on freine ou si on ralentit).
## - on peut l'abattre au pistolet (Gun) : `health` balles et il explose, puis brûle en
##   se rangeant sur le bas-côté pendant qu'on s'éloigne (« eliminated ») ; il revient
##   plus tard comme s'il avait été semé.
## Poursuite « virtuelle » comme Pursuer : on suit l'écart le long de la route et le
## camping-car visible est posé sur la route à cet écart.

signal started
signal lost
signal hit(count: int)
signal killed
## Abattu au pistolet.
signal eliminated
## Partie à deux : coup de feu (« shot »), balle reçue (« hit », [position, rotation]
## de l'impact sur la vitre) ou coup de flanc (« ram »), à rejouer chez le copilote.
signal net_event(kind: String, data: Array)

const RATE := 22050
const GROUP := "rivals"
const BEIGE := Color(0.86, 0.8, 0.64)
const BROWN := Color(0.42, 0.27, 0.15)

enum State { IDLE, FREE, CHASE, DONE, WRECK }

@export var road_path: NodePath
@export var car_path: NodePath
@export var auto_encounters := true
## Distance parcourue (m) avant la première apparition, puis entre deux apparitions.
@export var first_encounter := Vector2(1600.0, 3200.0)
@export var next_encounter := Vector2(2500.0, 5000.0)
## Vitesse de croisière (km/h) : le 4x4 plafonne à ~154 km/h en D.
@export var cruise_kmh := 128.0
## Apparition : écart (m), puis il remonte (+`approach_bonus` km/h sur nous) jusqu'à
## `approach_gap` m.
@export var spawn_gap := 230.0
@export var approach_gap := 25.0
@export var approach_bonus := 35.0
@export var shoot_range := 35.0
@export var shot_interval := Vector2(0.9, 2.2)
@export_range(0.0, 1.0) var hit_chance := 0.33
@export var max_hits := 6
@export var lose_gap := 280.0
@export var lose_time := 5.0
## Balles de pistolet pour l'abattre.
@export var health := 10

var state := State.IDLE
var gap := 999.0
var hits := 0
var encounters := 0

var _road: RoadGenerator
var _car: RigidBody3D
var _s := 0.0
var _speed := 0.0
var _approach := false
var _far_t := 0.0
var _next_s := INF
var _shot_t := 1.0
var _ram_t := 3.0
var _lateral := 1.75
var _t := 0.0
var _visual: Node3D
var _flash: MeshInstance3D
var _flash_light: OmniLight3D
var _flash_t := 0.0
var _wheels: Array[Node3D] = []
var _engine: AudioStreamPlayer3D
var _gun: AudioStreamPlayer3D
var _impact: AudioStreamPlayer
var _cracks: Array[Node3D] = []
var _hp := 10
var wrecked := false
var _wreck_fire: Node3D
var _wreck_t := 0.0
var _wreck_yaw := 0.0
var _wreck_lat := 5.5


func _ready() -> void:
	add_to_group(GROUP)
	_ready_links()
	_build_visual()
	_visual.visible = false
	_engine = AudioStreamPlayer3D.new()
	_engine.stream = _make_engine()
	_engine.unit_size = 14.0
	_engine.max_distance = 300.0
	_engine.volume_db = -4.0
	_visual.add_child(_engine)
	_gun = AudioStreamPlayer3D.new()
	_gun.stream = _make_shot()
	_gun.unit_size = 30.0
	_gun.max_distance = 400.0
	_gun.position = Vector3(-1.25, 2.0, 2.4)
	_visual.add_child(_gun)
	_impact = AudioStreamPlayer.new()
	_impact.stream = _make_impact()
	_impact.volume_db = -2.0
	add_child(_impact)


## Résout road_path / car_path (rappelé si les chemins sont donnés après add_child).
func _ready_links() -> void:
	_road = get_node_or_null(road_path) as RoadGenerator
	_car = get_node_or_null(car_path) as RigidBody3D


## Début de partie : ils roderont et surgiront au hasard.
func start() -> void:
	if state == State.DONE:
		return
	state = State.FREE
	_next_s = _car_s() + randf_range(first_encounter.x, first_encounter.y)


func stop() -> void:
	state = State.DONE
	_visual.visible = false
	_engine.stop()


## Les fait surgir tout de suite (tests, ou appelé par le hasard).
func force_encounter() -> void:
	if state == State.DONE:
		return
	state = State.CHASE
	_s = _car_s() - spawn_gap
	_speed = _player_kmh()
	_approach = true
	_far_t = 0.0
	_shot_t = 1.0
	encounters += 1
	_hp = health
	_end_wreck_fx()
	_visual.visible = true
	_engine.play()
	print("Concurrents : camping-car à %d m derrière" % roundi(spawn_gap))
	started.emit()


func get_car_position() -> Vector3:
	return _visual.global_position


func get_speed_kmh() -> float:
	return _speed


func _car_s() -> float:
	var s := _road.sample_road(_car.global_position)
	return s["s"] if s["found"] else _s


func _player_kmh() -> float:
	return maxf(_car.linear_velocity.dot(_car.global_basis.z) * 3.6, 0.0)


func _physics_process(delta: float) -> void:
	if _road == null or _car == null:
		return
	_t += delta
	_flash_t = maxf(_flash_t - delta, 0.0)
	if _flash:
		_flash.visible = _flash_t > 0.0
		_flash_light.visible = _flash_t > 0.0
	var car_s := _car_s()
	match state:
		State.IDLE, State.DONE:
			return
		State.WRECK:
			_update_wreck(delta, car_s)
			return
		State.FREE:
			if auto_encounters and car_s >= _next_s:
				# pas en même temps que la police
				var pol := get_tree().get_first_node_in_group(Pursuer.GROUP) as Pursuer
				if pol and pol.state in [Pursuer.State.CHASE, Pursuer.State.WAIT, Pursuer.State.BLOCK]:
					_next_s = car_s + 300.0
				else:
					force_encounter()
			return
	# vitesse : sa croisière, ou la nôtre si on roule pied au plancher (il colle)
	var pushing: bool = _car.get("throttle_input") > 0.8 and _car.get("brake_input") < 0.1
	var target := cruise_kmh
	if pushing:
		target = minf(cruise_kmh, _player_kmh() + 1.0)
	if _approach:
		if gap > approach_gap:
			target = maxf(cruise_kmh, _player_kmh() + approach_bonus)
		else:
			_approach = false
	if gap < 3.5:
		target = minf(target, _player_kmh())   # à notre hauteur : il ne nous dépasse pas
	_speed = move_toward(_speed, target, 25.0 * delta)
	_s += _speed / 3.6 * delta
	gap = car_s - _s
	if gap < 2.5:
		_s = car_s - 2.5
		gap = 2.5
	# semé ?
	if gap > lose_gap and not _approach:
		_far_t += delta
		if _far_t >= lose_time:
			_on_lost()
			return
	else:
		_far_t = 0.0
	_place(delta)
	_attack(delta)


func _place(delta: float) -> void:
	var sample := _road.sample_ahead(_car.global_position, -gap)
	if not sample["found"] or gap > 320.0:
		_visual.visible = false
		return
	_visual.visible = true
	# de loin dans notre voie ; de près, il déboîte sur l'autre voie pour nous longer
	var own := _road.sample_road(_car.global_position)
	var player_lat: float = own["lateral"] if own["found"] else 1.75
	var other := -1.9 if player_lat > -0.5 else 1.9
	var target_lat := lerpf(player_lat, other, clampf((30.0 - gap) / 18.0, 0.0, 1.0))
	_lateral = lerpf(_lateral, target_lat, clampf(delta * 1.5, 0.0, 1.0))
	var pos := _road.ground_position(sample, _lateral)
	var dir: Vector3 = sample["dir"]
	_visual.global_transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), pos)
	var spin := _speed / 3.6 / 0.48 * delta
	for w in _wheels:
		w.rotate_object_local(Vector3.RIGHT, spin)


func _attack(delta: float) -> void:
	if gap > shoot_range or not _visual.visible:
		return
	_shot_t -= delta
	if _shot_t <= 0.0:
		_shot_t = randf_range(shot_interval.x, shot_interval.y)
		_fire()
	# collé à notre hauteur : coups de flanc
	_ram_t -= delta
	if gap < 4.0 and _ram_t <= 0.0:
		_ram_t = randf_range(3.0, 6.0)
		var side := signf(_lateral - float(_road.sample_road(_car.global_position)["lateral"]))
		var right: Vector3 = _road.sample_road(_car.global_position)["right"]
		_car.apply_central_impulse(-right * side * _car.mass * 1.4)
		_car.linear_velocity *= 0.96
		_impact.pitch_scale = 0.6
		_impact.play()
		_rumble(0.9, 0.35)
		net_event.emit("ram", [])
		print("Concurrents : coup de flanc")


func _fire() -> void:
	_flash_t = 0.07
	_gun.pitch_scale = randf_range(0.92, 1.08)
	_gun.play()
	net_event.emit("shot", [])
	# de près, on vise mieux
	var chance := hit_chance * (1.6 if gap < 10.0 else 1.0)
	if randf() < chance:
		hits += 1
		_impact.pitch_scale = randf_range(0.9, 1.2)
		_impact.play()
		_rumble(0.7, 0.15)
		var star := _add_crack()
		net_event.emit("hit", [star.position, star.rotation.z])
		print("Concurrents : touché (%d/%d)" % [hits, max_hits])
		hit.emit(hits)
		if hits >= max_hits:
			state = State.DONE
			killed.emit()


func _rumble(strength: float, duration: float) -> void:
	for h in get_tree().get_nodes_in_group(VRHandInteractor.GROUP):
		(h as VRHandInteractor).pulse(strength, duration)


## Impact de balle : étoile blanche sur une vitre du 4x4 (pare-brise ou lunette).
func _add_crack() -> Node3D:
	var star := Node3D.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.95, 0.95, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in 6:
		var ray := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.002, randf_range(0.04, 0.09), 0.002)
		ray.mesh = bm
		ray.material_override = m
		ray.rotation.z = TAU * k / 6.0 + randf_range(-0.2, 0.2)
		ray.position = Vector3(0, 0, 0).rotated(Vector3.FORWARD, 0.0)
		ray.translate_object_local(Vector3(0, bm.size.y * 0.5, 0))
		star.add_child(ray)
	var hole := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.006
	sm.height = 0.012
	hole.mesh = sm
	hole.material_override = m
	star.add_child(hole)
	_car.add_child(star)
	# lunette arrière (z ≈ -2,3) ou pare-brise (z ≈ 1,0) selon qu'il est derrière / à côté
	if gap > 6.0:
		star.position = Vector3(randf_range(-0.6, 0.6), randf_range(1.3, 1.7), -2.32)
	else:
		star.position = Vector3(randf_range(-0.6, 0.6), randf_range(1.25, 1.6), 1.02)
	star.rotation.z = randf() * TAU
	_cracks.append(star)
	return star


# --- Abattu au pistolet --------------------------------------------------------------

## Boîte touchable par les balles : [centre (monde), demi-tailles], ou [] si rien à viser.
func get_hit_box() -> Array:
	if wrecked or not _visual.visible or not (state == State.CHASE or Net.is_copilot()):
		return []
	return [_visual.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 1.85, 0.07)), Vector3(1.2, 1.45, 4.0)]


## Une balle du joueur l'a touché (compté chez le conducteur).
func take_shot(_point: Vector3) -> void:
	if wrecked or state != State.CHASE:
		return
	_hp -= 1
	print("Concurrents : touchés au pistolet (%d/%d)" % [health - _hp, health])
	if _hp <= 0:
		_wreck()


func _wreck() -> void:
	state = State.WRECK
	wrecked = true
	_wreck_t = 0.0
	_wreck_yaw = 0.0
	_wreck_lat = 5.5 * (1.0 if _lateral >= 0.0 else -1.0)
	_engine.stop()
	_start_wreck_fx()
	print("Concurrents : camping-car abattu")
	eliminated.emit()


func _start_wreck_fx() -> void:
	CombatFx.explosion(_visual, Vector3(0, 1.8, 0.5))
	if _wreck_fire == null:
		_wreck_fire = CombatFx.burning(_visual, Vector3(0, 1.6, 2.6))


func _end_wreck_fx() -> void:
	if _wreck_fire and is_instance_valid(_wreck_fire):
		_wreck_fire.queue_free()
	_wreck_fire = null


## Abattu : il freine en zigzaguant, part en travers sur le bas-côté et brûle ; on le
## laisse derrière nous. Il reviendra plus loin, comme s'il avait été semé.
func _update_wreck(delta: float, car_s: float) -> void:
	_wreck_t += delta
	_speed = move_toward(_speed, 0.0, 40.0 * delta)
	_s += _speed / 3.6 * delta
	gap = car_s - _s
	_lateral = lerpf(_lateral, _wreck_lat, clampf(delta * 0.9, 0.0, 1.0))
	if _speed > 1.0:
		_wreck_yaw = move_toward(_wreck_yaw, 0.75 * signf(_wreck_lat), delta * 0.5)
	var sample := _road.sample_ahead(_car.global_position, -gap)
	if not sample["found"] or gap > 300.0 or _wreck_t > 30.0:
		_visual.visible = false
		_end_wreck_fx()
		wrecked = false
		state = State.FREE
		_next_s = car_s + randf_range(next_encounter.x, next_encounter.y)
		return
	var pos := _road.ground_position(sample, _lateral)
	var dir: Vector3 = sample["dir"]
	_visual.global_transform = Transform3D(Basis(Vector3.UP, _wreck_yaw) * Basis.looking_at(-dir, Vector3.UP), pos)
	var spin := _speed / 3.6 / 0.48 * delta
	for w in _wheels:
		w.rotate_object_local(Vector3.RIGHT, spin)


# --- Partie à deux (chez le copilote, les concurrents recopient ceux du conducteur) ---

## [visible, transformation, km/h, moteur audible, abattu]
func net_state() -> Array:
	return [_visual.visible, _visual.global_transform, _speed, _engine.playing, wrecked]


func net_apply(st: Array, xf: Transform3D) -> void:
	_visual.visible = st[0]
	if st[0]:
		_visual.global_transform = xf
	_speed = st[2]
	var spin := _speed / 3.6 / 0.48 * get_physics_process_delta_time()
	for w in _wheels:
		w.rotate_object_local(Vector3.RIGHT, spin)
	if st[3] != _engine.playing:
		if st[3]:
			_engine.play()
		else:
			_engine.stop()
	var w: bool = st[4] if st.size() > 4 else false
	if w and not wrecked:
		wrecked = true
		_start_wreck_fx()
	elif not w and wrecked:
		wrecked = false
		_end_wreck_fx()


func net_fx(kind: String, data: Array) -> void:
	match kind:
		"shot":
			_flash_t = 0.07
			_gun.play()
		"hit":
			_impact.pitch_scale = 1.0
			_impact.play()
			_rumble(0.7, 0.15)
			var star := _add_crack()
			star.position = data[0]
			star.rotation.z = data[1]
		"ram":
			_impact.pitch_scale = 0.6
			_impact.play()
			_rumble(0.9, 0.35)


func _on_lost() -> void:
	print("Concurrents : semés après %d impacts" % hits)
	state = State.FREE
	_visual.visible = false
	_engine.stop()
	_next_s = _car_s() + randf_range(next_encounter.x, next_encounter.y)
	lost.emit()


# --- Modèle : camping-car des années 80, beige à bandes brunes -----------------

func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "RivalRV"
	add_child(_visual)
	var beige := _mat(BEIGE)
	var brown := _mat(BROWN)
	var dark := _mat(Color(0.08, 0.09, 0.1), 0.2)
	var black := _mat(Color(0.05, 0.05, 0.05))
	var chrome := _mat(Color(0.7, 0.7, 0.68), 0.3, 0.8)
	var rust := _mat(Color(0.45, 0.25, 0.12))
	var white := _mat(Color(0.93, 0.92, 0.88))
	var lamp := _mat(Color(1.0, 0.95, 0.8))
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.9, 0.7)
	lamp.emission_energy_multiplier = 1.5
	# caisse (carrée, coins arrondis par des chanfreins), cabine basse à l'avant
	_box(Vector3(2.4, 2.5, 5.6), Vector3(0, 1.85, -1.1), beige)          # cellule
	_box(Vector3(2.3, 0.35, 5.5), Vector3(0, 3.15, -1.1), white)          # toit
	_box(Vector3(2.4, 0.8, 1.0), Vector3(0, 2.6, 2.1), beige)             # capucine au-dessus de la cabine
	_box(Vector3(2.3, 1.45, 2.0), Vector3(0, 1.32, 2.5), beige)          # cabine
	_box(Vector3(2.25, 0.7, 0.8), Vector3(0, 0.95, 3.65), beige)          # capot
	_box(Vector3(2.0, 0.65, 0.06), Vector3(0, 1.75, 3.53), dark, Vector3(-18, 0, 0))   # pare-brise
	_box(Vector3(2.3, 0.25, 0.12), Vector3(0, 0.65, 4.08), chrome)        # pare-chocs avant
	_box(Vector3(1.3, 0.4, 0.05), Vector3(0, 1.0, 4.06), black)           # calandre
	for x in [-0.82, 0.82]:
		_box(Vector3(0.28, 0.22, 0.05), Vector3(x, 1.0, 4.07), lamp)      # phares
	_box(Vector3(2.4, 0.25, 0.12), Vector3(0, 0.65, -3.95), chrome)       # pare-chocs arrière
	# bandes brunes sur les flancs et l'arrière
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.02, 0.22, 7.6), Vector3(sx * 1.211, 1.55, 0.1), brown)
		_box(Vector3(0.02, 0.1, 7.6), Vector3(sx * 1.211, 1.32, 0.1), brown)
		# fenêtres de la cellule, vitres de cabine, porte
		_box(Vector3(0.02, 0.55, 1.1), Vector3(sx * 1.212, 2.25, -0.6), dark)
		_box(Vector3(0.02, 0.5, 0.8), Vector3(sx * 1.212, 2.25, -2.6), dark)
		_box(Vector3(0.02, 0.55, 0.9), Vector3(sx * 1.17, 1.8, 2.6), dark)
		# rouille et traces
		_box(Vector3(0.025, 0.25, 0.5), Vector3(sx * 1.213, 0.85, -3.2), rust)
		_box(Vector3(0.025, 0.18, 0.35), Vector3(sx * 1.213, 0.9, 1.2), rust)
	_box(Vector3(0.025, 1.7, 0.7), Vector3(1.212, 1.5, 0.6), beige.duplicate())   # porte (côté droit)
	_box(Vector3(0.03, 1.6, 0.04), Vector3(1.214, 1.5, 0.25), brown)
	_box(Vector3(2.42, 0.22, 0.02), Vector3(0, 1.55, -3.91), brown)       # bandes arrière
	_box(Vector3(1.0, 0.6, 0.02), Vector3(0, 2.3, -3.91), dark)           # vitre arrière
	for x in [-1.0, 1.0]:
		_box(Vector3(0.2, 0.35, 0.04), Vector3(x, 1.0, -3.92), _mat(Color(0.7, 0.05, 0.05)))   # feux
	_box(Vector3(0.8, 0.3, 0.7), Vector3(0, 3.45, -0.4), white)           # clim sur le toit
	_box(Vector3(0.06, 0.06, 1.2), Vector3(-0.9, 3.35, -2.4), chrome)     # échelle / galerie
	_box(Vector3(0.12, 0.7, 0.12), Vector3(0.95, 3.0, -3.0), chrome, Vector3(0, 0, 0))   # cheminée du labo
	_box(Vector3(2.3, 0.35, 7.6), Vector3(0, 0.55, 0.1), black)           # bas de caisse
	# roues
	for z in [3.1, -2.6]:
		for sx in [-1.0, 1.0]:
			var w := Node3D.new()
			w.position = Vector3(sx * 1.05, 0.48, z)
			_visual.add_child(w)
			var tire := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.48
			cm.bottom_radius = 0.48
			cm.height = 0.3
			cm.radial_segments = 12
			tire.mesh = cm
			tire.material_override = black
			tire.rotation.z = PI * 0.5
			w.add_child(tire)
			var hub := MeshInstance3D.new()
			var hm := CylinderMesh.new()
			hm.top_radius = 0.25
			hm.bottom_radius = 0.25
			hm.height = 0.32
			hm.radial_segments = 8
			hub.mesh = hm
			hub.material_override = white
			hub.rotation.z = PI * 0.5
			w.add_child(hub)
			_wheels.append(w)
	# tireur à la fenêtre passager (côté gauche, vers notre voie) : bras et pistolet
	_box(Vector3(0.4, 0.1, 0.1), Vector3(-1.3, 1.95, 2.45), _mat(Color(0.75, 0.6, 0.48)))
	_box(Vector3(0.12, 0.08, 0.2), Vector3(-1.52, 1.98, 2.5), black)
	_flash = _box(Vector3(0.2, 0.2, 0.3), Vector3(-1.55, 1.98, 2.7), _flash_mat())
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.8, 0.4)
	_flash_light.light_energy = 6.0
	_flash_light.omni_range = 6.0
	_flash_light.position = Vector3(-1.6, 2.0, 2.7)
	_visual.add_child(_flash_light)
	_flash.visible = false
	_flash_light.visible = false
	# phares allumés
	for x in [-0.82, 0.82]:
		var spot := SpotLight3D.new()
		spot.light_color = Color(1.0, 0.93, 0.75)
		spot.light_energy = 4.0
		spot.spot_range = 50.0
		spot.spot_angle = 30.0
		spot.position = Vector3(x, 1.0, 4.1)
		spot.rotation = Vector3(deg_to_rad(-5.0), PI, 0.0)
		_visual.add_child(spot)


func _box(size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	_visual.add_child(mi)
	return mi


func _mat(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _flash_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.35)
	return m


# --- Sons -----------------------------------------------------------------------

func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w


## Vieux moteur essoufflé (ronronnement grave en boucle).
func _make_engine() -> AudioStreamWAV:
	var n := RATE
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var base := sin(TAU * 46.0 * t) * 0.5 + sin(TAU * 92.0 * t) * 0.25 + sin(TAU * 138.0 * t) * 0.1
		lp += (rng.randf_range(-1, 1) - lp) * 0.08
		s[i] = (base * (0.8 + 0.2 * sin(TAU * 4.0 * t)) + lp * 0.4) * 0.6
	return _wav(s, true)


## Coup de feu : claquement bref et écho.
func _make_shot() -> AudioStreamWAV:
	var n := int(RATE * 0.6)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var crack := rng.randf_range(-1, 1) * exp(-t * 60.0)
		lp += (rng.randf_range(-1, 1) - lp) * 0.05
		var boom := lp * exp(-t * 9.0) * 2.0 + sin(TAU * 70.0 * t) * exp(-t * 18.0) * 0.6
		var echo := rng.randf_range(-1, 1) * exp(-maxf(t - 0.18, 0.0) * 25.0) * 0.18 * (1.0 if t > 0.18 else 0.0)
		s[i] = crack + boom + echo
	return _wav(s)


## Balle qui frappe la carrosserie : « tchac » métallique.
func _make_impact() -> AudioStreamWAV:
	var n := int(RATE * 0.35)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in n:
		var t := float(i) / RATE
		var ping := sin(TAU * 1700.0 * t) * exp(-t * 22.0) * 0.4 + sin(TAU * 2900.0 * t) * exp(-t * 35.0) * 0.25
		var thud := rng.randf_range(-1, 1) * exp(-t * 45.0) * 0.8
		s[i] = ping + thud
	return _wav(s)
