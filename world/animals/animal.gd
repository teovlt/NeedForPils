class_name Animal
extends Node3D
## Un animal du décor (lapin, sanglier, biche, mouton), créé par AnimalManager.
##
## - Modèle props/animals/<espèce>.glb, animé par code : pattes qui balancent (pas,
##   trot ou galop selon la vitesse ; bonds pour le lapin), corps qui oscille, tête qui
##   se baisse pour brouter et se relève quand la voiture approche, oreilles qui bougent.
## - États : BROUTE (sur place), MARCHE (vers un point proche), TRAVERSE (traverse la
##   route en ligne droite, parfois s'arrête net au milieu, figé), FUIT (s'éloigne de la
##   voiture en courant), CHOC (projeté par la voiture, retombe, se relève et s'enfuit).
## - Suit le sol par un rayon vers le bas (terrain et route).
## - Choc : la voiture perd de la vitesse selon la masse de l'animal (quantité de
##   mouvement), vibration des manettes, bruit sourd et cri.
## Repère : l'animal regarde vers +Z.

enum State { GRAZE, WALK, CROSS, FLEE, HIT }

signal hit_car(animal: Animal, strength: float)

var species := "sheep"
var cfg: Dictionary = {}          # réglages de l'espèce (AnimalManager.SPECIES)
var car: RigidBody3D
var manager: Node
var state := State.GRAZE
var speed := 0.0                  # vitesse actuelle (m/s)
var heading := 0.0                # cap (rad, autour de Y ; 0 = +Z)
var target := Vector3.ZERO        # point visé (MARCHE / TRAVERSE / FUIT)
var crossing := false             # fait partie d'une traversée déclenchée
var _cross_called := false
var crossed := false              # a fini de traverser
var was_hit := false
var size_scale := 1.0

var _model: Node3D
var _legs: Array[Node3D] = []     # FL, FR, BL, BR
var _leg_rest: Array[Basis] = []
var _head: Node3D
var _head_rest: Basis
var _neck: Node3D
var _neck_rest: Basis
var _ears: Array[Node3D] = []
var _ear_rest: Array[Basis] = []
var _tail: Node3D
var _tail_rest: Basis
var _body: Node3D
var _body_rest: Vector3
var _phase := randf() * TAU
var _graze := 0.0                 # 0 tête haute, 1 tête au sol
var _state_t := 0.0
var _next_sound := randf_range(2.0, 10.0)
var _freeze := 0.0                # temps restant figé au milieu de la route
var _vel := Vector3.ZERO          # vol après un choc
var _spin := Vector3.ZERO
var _down_t := 0.0
var _player: AudioStreamPlayer3D
var _ray_t := 0.0
var _ground_y := 0.0
var _zig := 0.0


func setup(sp: String, c: Dictionary, the_car: RigidBody3D, mgr: Node, scale_mult := 1.0) -> void:
	species = sp
	cfg = c
	car = the_car
	manager = mgr
	size_scale = scale_mult


func _ready() -> void:
	_model = (load(cfg["scene"]) as PackedScene).instantiate() as Node3D
	_model.scale = Vector3.ONE * size_scale
	add_child(_model)
	for n in ["Leg_FL", "Leg_FR", "Leg_BL", "Leg_BR"]:
		var l := _model.find_child(n, true, false) as Node3D
		if l:
			_legs.append(l)
			_leg_rest.append(l.basis)
	_head = _model.find_child("Head", true, false) as Node3D
	_neck = _model.find_child("Neck", true, false) as Node3D
	_body = _model.find_child("Body", true, false) as Node3D
	_tail = _model.find_child("Tail", true, false) as Node3D
	for n in ["Ear_L", "Ear_R"]:
		var e := _model.find_child(n, true, false) as Node3D
		if e:
			_ears.append(e)
			_ear_rest.append(e.basis)
	if _head: _head_rest = _head.basis
	if _neck: _neck_rest = _neck.basis
	if _tail: _tail_rest = _tail.basis
	if _body: _body_rest = _body.position
	_ground_y = global_position.y
	_snap_ground(true)


# --- Comportement -------------------------------------------------------------

func set_state(s: State) -> void:
	state = s
	_state_t = 0.0


## Lance la traversée de la route vers `to` (point au-delà de l'autre bord).
func start_crossing(to: Vector3, delay := 0.0) -> void:
	_snap_ground(true)   # (déplacé par le manager après sa création)
	crossing = true
	target = to
	_state_t = -delay
	state = State.CROSS
	if randf() < float(cfg.get("freeze_chance", 0.0)):
		_freeze = -1.0      # se figera au milieu de la route (déclenché plus tard)


func _physics_process(delta: float) -> void:
	_state_t += delta
	if state == State.HIT:
		_update_hit(delta)
		_animate(delta)
		return
	var car_d := 999.0
	var car_v := 0.0
	if car:
		car_d = global_position.distance_to(car.global_position)
		car_v = car.linear_velocity.length()
	var want_speed := 0.0
	var walk: float = cfg["walk"]
	var run: float = cfg["run"]
	match state:
		State.GRAZE:
			_graze = move_toward(_graze, 1.0, delta * 0.8)
			if _state_t > randf_range(4.0, 12.0) and randf() < delta * 0.5:
				_pick_wander_target()
				set_state(State.WALK)
		State.WALK:
			_graze = move_toward(_graze, 0.0, delta * 1.5)
			want_speed = walk
			if _flat_dist(target) < 0.6 or _state_t > 20.0:
				set_state(State.GRAZE)
		State.CROSS:
			_graze = move_toward(_graze, 0.0, delta * 3.0)
			if _state_t < 0.0:
				want_speed = 0.0        # attend son tour (troupeau en file)
			else:
				want_speed = float(cfg["cross_speed"])
				if not _cross_called:
					_cross_called = true   # cri d'alerte en s'élançant : on l'entend arriver
					if car_d < 140.0:
						_play(cfg.get("alarm", []), true)
				if _freeze == -1.0 and manager and absf(float(manager.call("lateral_of", global_position))) < 2.0:
					_freeze = randf_range(0.8, 1.8)   # figé dans la voie, face aux phares
					_play(cfg.get("alarm", []))
				if _freeze > 0.0:
					_freeze -= delta
					want_speed = 0.0
					if _freeze <= 0.0:
						_freeze = -2.0
						want_speed = run
				if _flat_dist(target) < 1.0:
					crossed = true
					crossing = false
					_flee_from_road()
		State.FLEE:
			_graze = move_toward(_graze, 0.0, delta * 3.0)
			want_speed = run
			if _flat_dist(target) < 1.0 or _state_t > 8.0:
				set_state(State.GRAZE)
	# la voiture approche vite : alerte puis fuite (sauf pendant une traversée)
	if state in [State.GRAZE, State.WALK] and car_d < float(cfg.get("shy", 22.0)) and car_v > 4.0:
		_play(cfg.get("alarm", []))
		_flee_from(car.global_position)
	# ne pas entrer dans une voiture à l'arrêt
	if car and car_v < 1.0 and _inside_car(global_position + _fwd() * 0.8, 0.4):
		want_speed = 0.0
		if state != State.CROSS:
			heading += PI * 0.5
	# accélération / cap
	speed = move_toward(speed, want_speed, delta * (6.0 if want_speed > speed else 4.0))
	if state != State.GRAZE and state != State.HIT and _state_t >= 0.0:
		var to := target - global_position
		to.y = 0.0
		if to.length() > 0.05:
			var want_h := atan2(to.x, to.z)
			if species == "rabbit" and speed > 2.0:
				_zig += delta
				want_h += sin(_zig * 5.0) * 0.5       # zigzags du lapin
			heading = lerp_angle(heading, want_h, clampf(delta * (3.0 if speed < 2.0 else 6.0), 0.0, 1.0))
	global_position += _fwd() * speed * delta
	rotation = Vector3(0.0, heading, 0.0)
	_snap_ground(false)
	_check_car_hit()
	# sons d'ambiance
	_next_sound -= delta
	if _next_sound <= 0.0:
		var gap: Vector2 = cfg.get("idle_gap", Vector2(8, 20))
		_next_sound = randf_range(gap.x, gap.y)
		if car_d < 90.0:
			_play(cfg.get("idle", []))
	_animate(delta)


func _fwd() -> Vector3:
	return Vector3(sin(heading), 0.0, cos(heading))


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _pick_wander_target() -> void:
	var a := randf() * TAU
	var r := randf_range(2.0, 8.0)
	target = global_position + Vector3(sin(a), 0, cos(a)) * r
	# reste loin de la route
	if manager:
		var lat: float = manager.call("lateral_of", target)
		if absf(lat) < 8.0:
			target += (manager.call("away_from_road", target) as Vector3) * (8.5 - absf(lat))


func _flee_from(p: Vector3) -> void:
	var away := global_position - p
	away.y = 0.0
	if away.length() < 0.1:
		away = -_fwd()
	away = away.normalized()
	if manager:   # s'éloigne aussi de la route
		away = (away + (manager.call("away_from_road", global_position) as Vector3) * 0.8).normalized()
	target = global_position + away * randf_range(14.0, 22.0)
	set_state(State.FLEE)


func _flee_from_road() -> void:
	var away := _fwd()
	if manager:
		away = manager.call("away_from_road", global_position)
	target = global_position + away * randf_range(10.0, 18.0)
	set_state(State.FLEE)


# --- Sol ----------------------------------------------------------------------

func _snap_ground(force: bool) -> void:
	_ray_t -= get_physics_process_delta_time()
	if _ray_t <= 0.0 or force or speed > 1.5:
		_ray_t = 0.1
		var y := ground_at(global_position, 80.0 if force else 4.0)
		if is_nan(y) or (not force and y < global_position.y - 3.0):
			y = ground_at(global_position, 80.0)   # rattrapage : sol cherché de haut
		if not is_nan(y):
			_ground_y = y
	var hop := 0.0
	if species == "rabbit" and speed > 0.3:
		hop = absf(sin(_phase)) * minf(speed * 0.06, 0.35)
	var p := global_position
	p.y = lerpf(p.y, _ground_y + hop, 1.0 if force else 0.5)
	global_position = p


# --- Voiture ------------------------------------------------------------------

## Hauteur du sol (terrain ou route) sous p, NAN si rien. Le rayon part de `up` m
## au-dessus (assez haut pour remonter sur une route en remblai) ; s'il touche une
## couronne d'arbre (NatureCollision), il repart juste en dessous.
func ground_at(p: Vector3, up: float) -> float:
	var space := get_world_3d().direct_space_state
	var from := p + Vector3(0, up, 0)
	var ex: Array[RID] = []
	if car:
		ex.append(car.get_rid())
	for k in 4:
		var q := PhysicsRayQueryParameters3D.create(from, p - Vector3(0, 30.0, 0))
		q.exclude = ex
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return NAN
		var col: Object = hit["collider"]
		if col is Node and (col as Node).name == "NatureCollision":
			from = (hit["position"] as Vector3) - Vector3(0, 0.05, 0)
			ex.append(hit["rid"])   # (tout le corps du tronçon : couronnes et troncs)
			continue
		return (hit["position"] as Vector3).y
	return NAN


func _inside_car(p: Vector3, margin: float) -> bool:
	if car == null:
		return false
	var l := car.to_local(p)
	return absf(l.x) < 1.0 + margin and l.z > -2.6 - margin and l.z < 2.5 + margin and l.y < 2.0 and l.y > -1.5


func _check_car_hit() -> void:
	if car == null or was_hit:
		return
	var r: float = cfg["radius"] * size_scale
	# centre du corps et tête
	for p in [global_position + Vector3(0, cfg["height"] * 0.5 * size_scale, 0),
			global_position + _fwd() * cfg["length"] * 0.45 * size_scale + Vector3(0, cfg["height"] * 0.6 * size_scale, 0)]:
		if _inside_car(p, r):
			var rel := car.linear_velocity - _fwd() * speed
			rel.y = 0.0
			if rel.length() < 1.5:
				return   # voiture presque arrêtée : l'animal la contourne
			_on_hit(rel)
			return


func _on_hit(rel: Vector3) -> void:
	was_hit = true
	crossing = false
	var m: float = float(cfg["mass"]) * pow(size_scale, 3.0)
	var mc := car.mass
	var v := rel.length()
	# choc presque mou : la voiture cède la quantité de mouvement donnée à l'animal
	var dv := v * m / (mc + m) * 1.3
	var dir := rel / v
	var contact := global_position + Vector3(0, cfg["height"] * 0.5 * size_scale, 0) - car.global_position
	var side := car.global_basis.x
	contact -= side * contact.dot(side) * 0.6       # limite la rotation de la voiture
	car.apply_impulse(-dir * mc * dv, contact)
	var strength := clampf(m / 90.0 * v / 15.0, 0.08, 1.0)
	hit_car.emit(self, strength)
	# l'animal est projeté : un peu plus vite que la voiture, vers le haut, en tournoyant
	_vel = car.linear_velocity * 1.05 + Vector3(0, clampf(2.0 + v * 0.18 * 60.0 / maxf(m, 20.0), 2.0, 7.0), 0)
	_vel += side * signf((global_position - car.global_position).dot(side)) * v * 0.25
	_spin = Vector3(randf_range(-8, 8), randf_range(-6, 6), randf_range(-10, 10)) * clampf(v / 15.0, 0.3, 1.2)
	speed = 0.0
	set_state(State.HIT)
	_play(cfg.get("hit", []), true)
	if manager:
		manager.call("play_impact", global_position, strength)


func _update_hit(delta: float) -> void:
	if _down_t <= 0.0:
		_vel.y -= 9.8 * delta
		global_position += _vel * delta
		_model.rotation += _spin * delta
		_ray_t -= delta
		if _ray_t <= 0.0:
			_ray_t = 0.05
			var gy := ground_at(global_position, 2.0)
			if not is_nan(gy):
				_ground_y = gy
		if global_position.y <= _ground_y and _vel.y < 0.0:
			global_position.y = _ground_y
			if _vel.length() > 3.0:
				_vel = Vector3(_vel.x * 0.4, -_vel.y * 0.25, _vel.z * 0.4)   # rebond
				_spin *= 0.4
			else:
				_down_t = randf_range(1.2, 2.2)   # reste au sol un instant
				_model.rotation = Vector3(0, 0, PI * 0.5 * signf(randf() - 0.5))
	else:
		_down_t -= delta
		if _down_t <= 0.0:
			_down_t = 0.0
			_model.rotation = Vector3.ZERO
			_vel = Vector3.ZERO
			was_hit = false
			_flee_from(car.global_position)
			_play(cfg.get("alarm", []))
			set_state(State.FLEE)
			# il boite un peu : moins vite
			cfg = cfg.duplicate()
			cfg["run"] = float(cfg["run"]) * 0.6


# --- Animation ----------------------------------------------------------------

func _animate(delta: float) -> void:
	var gait_freq: float = cfg.get("step_freq", 1.6)
	var stride: float = cfg.get("stride", 0.5)
	var moving := speed > 0.05
	_phase += delta * TAU * (gait_freq * (0.4 + speed / maxf(stride * 2.0, 0.1)) if moving else 0.0)
	var amp := clampf(speed / maxf(float(cfg["walk"]), 0.1) * 0.35, 0.0, 0.9) if moving else 0.0
	var gallop := speed > float(cfg["run"]) * 0.55
	if species == "rabbit":
		# bonds : pattes arrière qui poussent, avant tendues
		var s := sin(_phase)
		for i in _legs.size():
			var a := (-0.9 * maxf(s, 0.0) if i >= 2 else 0.6 * s) * clampf(speed, 0.0, 1.0)
			_legs[i].basis = _leg_rest[i] * Basis(Vector3.RIGHT, a)
		if _body:
			_body.rotation.x = -0.25 * s * clampf(speed, 0.0, 1.0)
	else:
		for i in _legs.size():
			var off := 0.0
			if gallop:
				off = 0.0 if i < 2 else PI * 0.6    # galop : paires avant / arrière décalées
				off += 0.3 if i % 2 else 0.0
			else:
				off = 0.0 if i in [0, 3] else PI     # trot / pas : diagonales
			_legs[i].basis = _leg_rest[i] * Basis(Vector3.RIGHT, sin(_phase + off) * amp)
		if _body:
			_body.position = _body_rest + Vector3(0, absf(sin(_phase)) * amp * 0.04, 0)
	# tête : broute (baissée) / normale / alerte
	var g := _graze
	if state == State.CROSS and _freeze > 0.0:
		g = -0.3   # tête haute, figé
	var head_down: float = cfg.get("graze_angle", 0.8)
	if _neck:
		_neck.basis = _neck_rest * Basis(Vector3.RIGHT, g * head_down * 0.75)
		if _head:
			_head.basis = _head_rest * Basis(Vector3.RIGHT, g * head_down * 0.35 + sin(_phase * 0.5) * 0.05 * amp)
	elif _head:
		var chew := sin(Time.get_ticks_msec() * 0.008) * 0.06 * g
		_head.basis = _head_rest * Basis(Vector3.RIGHT, g * head_down + chew + sin(_phase) * 0.06 * amp)
	for i in _ears.size():
		var tw := sin(Time.get_ticks_msec() * 0.003 + i * 2.0) * 0.15
		var alert := -0.3 if (state == State.FLEE or _freeze > 0.0) else 0.0
		_ears[i].basis = _ear_rest[i] * Basis(Vector3.RIGHT, tw + alert)
	if _tail:
		_tail.basis = _tail_rest * Basis(Vector3.FORWARD, sin(Time.get_ticks_msec() * 0.006) * 0.25)


# --- Sons ---------------------------------------------------------------------

func _play(list: Array, loud := false) -> void:
	if list.is_empty():
		return
	if _player == null:
		_player = AudioStreamPlayer3D.new()
		_player.unit_size = float(cfg.get("sound_unit", 4.0))
		_player.max_distance = 110.0
		_player.position.y = float(cfg["height"]) * 0.7
		if AudioServer.get_bus_index("Ambiance") >= 0:
			_player.bus = "Ambiance"   # étouffé vitres fermées, comme l'ambiance
		add_child(_player)
	if _player.playing and not loud:
		return
	var path: String = list[randi() % list.size()]
	_player.stream = manager.call("sound", path) if manager else load(path)
	_player.pitch_scale = randf_range(0.92, 1.08) / sqrt(size_scale)
	_player.volume_db = 4.0 if loud else 0.0
	if loud:
		_player.bus = "Master"
	_player.play()
