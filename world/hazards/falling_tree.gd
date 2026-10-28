class_name FallingTree
extends Node3D
## Arbre de bord de route qui tremble, craque puis s'abat en travers de la chaussée.
## Le tronc et la couronne sont des corps physiques animés : ils bloquent la voiture
## (et la bousculent s'ils lui tombent dessus). Créé par FallingTreeManager.

signal hit_car(tree: FallingTree, strength: float)
signal landed(tree: FallingTree)

enum State { SHAKING, FALLING, FALLEN }

## Hauteur totale de l'arbre (m) : décide jusqu'où il barre la route.
var height := 6.0
## Rotation du modèle autour de son tronc (NAN = au hasard). Partie à deux : la même
## que chez le conducteur.
var visual_yaw := NAN
## Durée du tremblement avant la chute (s).
var shake_time := 1.3
var tree_scene: PackedScene
## Couleur des feuilles projetées (dépend de l'espèce).
var leaf_color := Color(0.3, 0.55, 0.18)
var creak_sound: AudioStream
var crash_sound: AudioStream

## Portion de route bloquée une fois au sol (coordonnée latérale, m) et point de route.
var blocked_lateral := Vector2.ZERO
var road_point := Vector3.ZERO
var road_dir := Vector3.FORWARD

var state := State.SHAKING
var angle := 0.0

var BASE_HEIGHT := 5.4   # hauteur du modèle à l'échelle 1 (mesurée dans _ready)
var _crown_y := 3.8      # centre de la couronne (modèle à l'échelle 1)
const END_ANGLE := deg_to_rad(86.0)
const START_LEAN := 0.12   # inclinaison atteinte à la fin du tremblement (rad)

var _pivot: Node3D
var _visual: Node3D
var _area: Area3D
var _audio: AudioStreamPlayer3D
var _t := 0.0
var _omega := 0.0
var _bounces := 0
var _hit_bodies := {}


func _ready() -> void:
	var sc := height / BASE_HEIGHT
	_pivot = Node3D.new()
	add_child(_pivot)
	_visual = tree_scene.instantiate()
	# Dimensions du modèle (n'importe quelle espèce) : hauteur et largeur de la couronne.
	var box := AABB()
	var first := true
	for c in _visual.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != _visual and n is Node3D:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b := xf * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if not first and box.end.y > 1.0:
		BASE_HEIGHT = box.end.y
	var width := clampf(maxf(box.size.x, box.size.z), 0.8, 5.0) if not first else 2.6
	_crown_y = BASE_HEIGHT * 0.7
	sc = height / BASE_HEIGHT
	_visual.scale = Vector3.ONE * sc
	if is_nan(visual_yaw):
		visual_yaw = randf() * TAU
	_visual.rotation.y = visual_yaw
	_pivot.add_child(_visual)

	# Corps physique animé (tronc + couronne).
	# (sync_to_physics désactivé : le corps doit suivre la rotation de son parent.)
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	_pivot.add_child(body)
	_area = Area3D.new()
	_area.monitoring = false
	_pivot.add_child(_area)
	var trunk_w := clampf(width * 0.15, 0.3, 0.6)
	var crown_w := width * 0.75
	for spec in [[Vector3(0, BASE_HEIGHT * 0.24, 0), Vector3(trunk_w, BASE_HEIGHT * 0.48, trunk_w)],
			[Vector3(0, _crown_y, 0), Vector3(crown_w, BASE_HEIGHT * 0.55, crown_w)]]:
		var shape := BoxShape3D.new()
		shape.size = spec[1] * sc
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = spec[0] * sc
		body.add_child(cs)
		var detect := BoxShape3D.new()
		detect.size = spec[1] * sc + Vector3.ONE * 0.4
		var cs2 := CollisionShape3D.new()
		cs2.shape = detect
		cs2.position = spec[0] * sc
		_area.add_child(cs2)
	_area.body_entered.connect(_on_body_entered)

	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 12.0
	_audio.max_distance = 250.0
	_audio.position = Vector3(0, 2.0 * sc, 0)
	_pivot.add_child(_audio)
	if creak_sound:
		_audio.stream = creak_sound
		_audio.play()
	_spawn_particles(Vector3(0, _crown_y * sc, 0), 25, leaf_color.darkened(0.15), 1.6, false)


func _physics_process(delta: float) -> void:
	_t += delta
	match state:
		State.SHAKING:
			# Tremble de plus en plus et commence à pencher vers la route.
			var k := _t / shake_time
			angle = START_LEAN * k * k + sin(_t * 23.0) * 0.02 * k
			if _t >= shake_time:
				state = State.FALLING
				angle = START_LEAN
				_omega = 2.0 * START_LEAN / shake_time
				_area.monitoring = true
		State.FALLING:
			# Tige qui bascule : accélération angulaire = 3g/(2H) * sin(angle).
			_omega += 1.5 * 9.81 / height * sin(angle) * delta
			angle += _omega * delta
			if angle >= END_ANGLE:
				angle = END_ANGLE
				_bounces += 1
				if _bounces == 1:
					_on_impact()
				_omega = -_omega * 0.18
				if absf(_omega) < 0.15 or _bounces > 3:
					_omega = 0.0
					state = State.FALLEN
		State.FALLEN:
			pass
	_pivot.basis = Basis(Vector3.RIGHT, angle)


func _on_impact() -> void:
	var sc := height / BASE_HEIGHT
	if crash_sound:
		_audio.stream = crash_sound
		_audio.play()
	_spawn_particles(Vector3(0, _crown_y * sc, 0), 70, leaf_color, 3.0, true)
	_spawn_particles(Vector3(0, 0.3, 0) + Vector3(0, 1.0, 0) * height * 0.5, 40, Color(0.45, 0.4, 0.32), 2.0, true)
	landed.emit(self)


func _on_body_entered(body: Node) -> void:
	if body is VehicleBody3D and not _hit_bodies.has(body):
		_hit_bodies[body] = true
		var rb := body as RigidBody3D
		var strength := clampf(rb.linear_velocity.length() / 15.0, 0.4, 1.0)
		if state == State.FALLING:
			strength = 1.0   # l'arbre tombe sur la voiture
		hit_car.emit(self, strength)


func _spawn_particles(local_pos: Vector3, amount: int, color: Color, speed: float, burst: bool) -> void:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 2.5 if burst else 1.8
	p.one_shot = true
	p.explosiveness = 0.9 if burst else 0.2
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	p.mesh = quad
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.2 * height / BASE_HEIGHT
	p.direction = Vector3.UP
	p.spread = 180.0 if burst else 60.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -3.0, 0)
	p.damping_min = 0.5
	p.damping_max = 1.5
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	_pivot.add_child(p)
	p.position = local_pos
	p.top_level = true   # les particules ne suivent plus l'arbre une fois émises
	p.global_position = _pivot.to_global(local_pos)
	p.emitting = true
	get_tree().create_timer(4.0).timeout.connect(func(): if is_instance_valid(p): p.queue_free())
