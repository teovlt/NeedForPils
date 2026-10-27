class_name RoadPost
extends Node3D
## Balise de bord de route en plastique souple (comme les balises blanches à bande noire
## et catadioptre orange des routes françaises).
##
## Quand une voiture la touche, elle se couche sous la voiture dans le sens où celle-ci
## roule (elle plie surtout près du pied), freine un peu la voiture (petit choc au contact
## puis frottement tant qu'elle est dessous), fait un bruit de plastique et vibrer les
## manettes. Une fois la voiture passée, elle se redresse en oscillant comme un ressort.
## Repère : +Z = sens de la route, +Y = haut ; le pied est à l'origine.

const HEIGHT := 1.1          # dont 0,1 m enterré
const SEGMENTS := 4
## Part de la courbure portée par chaque segment, du pied vers le haut.
const BEND_SHARE := [0.42, 0.3, 0.18, 0.1]
const MAX_BEND := deg_to_rad(84.0)
## Ressort de redressement : fréquence (Hz) et amortissement relatif.
const SPRING_HZ := 1.5
const SPRING_DAMPING := 0.2

## Freinage : choc au premier contact (fraction de la vitesse + m/s fixes) et frottement
## pendant que la balise frotte sous la voiture (N + N par m/s).
@export var hit_speed_loss := 0.035
@export var hit_speed_loss_fixed := 0.35
@export var drag_force := 1200.0
@export var drag_per_ms := 140.0

static var _seg_mesh: BoxMesh
static var _band_mesh: BoxMesh
static var _refl_mesh: BoxMesh
static var _hit_sound: AudioStreamWAV

var hits := 0                # nombre de fois où la balise a été percutée (tests)
var _segs: Array[Node3D] = []
var _tilt := Vector2.ZERO    # direction du haut de la balise (repère local XZ) × angle (rad)
var _tilt_vel := Vector2.ZERO
var _cars: Array[RigidBody3D] = []
var _player: AudioStreamPlayer3D


const GROUP := "road_posts"


func _ready() -> void:
	add_to_group(GROUP)
	_init_shared()
	var parent: Node3D = self
	var seg_h := HEIGHT / SEGMENTS
	for i in SEGMENTS:
		var pivot := Node3D.new()
		pivot.position.y = 0.0 if i == 0 else seg_h
		parent.add_child(pivot)
		var mi := MeshInstance3D.new()
		mi.mesh = _seg_mesh
		mi.position.y = seg_h * 0.5
		pivot.add_child(mi)
		_segs.append(pivot)
		parent = pivot
	# bande noire et catadioptres orange (côté circulation, dans les deux sens)
	var top := _segs[SEGMENTS - 1]
	var band := MeshInstance3D.new()
	band.mesh = _band_mesh
	band.position.y = 0.13
	top.add_child(band)
	for zs in [-1.0, 1.0]:
		var r := MeshInstance3D.new()
		r.mesh = _refl_mesh
		r.position = Vector3(0.0, 0.13, 0.064 * zs)
		top.add_child(r)
	# détection de la voiture (ne tourne pas avec la balise)
	var area := Area3D.new()
	area.monitorable = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.22, 0.9, 0.22)
	cs.shape = box
	cs.position.y = 0.55
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	set_physics_process(false)   # dort tant que personne ne la touche


static func _init_shared() -> void:
	if _seg_mesh:
		return
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.92, 0.92, 0.9)
	white.roughness = 0.6
	_seg_mesh = BoxMesh.new()
	_seg_mesh.size = Vector3(0.12, HEIGHT / SEGMENTS + 0.004, 0.12)
	_seg_mesh.material = white
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.05, 0.05, 0.05)
	_band_mesh = BoxMesh.new()
	_band_mesh.size = Vector3(0.124, 0.1, 0.124)
	_band_mesh.material = black
	var amber := StandardMaterial3D.new()
	amber.albedo_color = Color(1.0, 0.55, 0.05)
	amber.emission_enabled = true
	amber.emission = Color(1.0, 0.45, 0.0)
	amber.emission_energy_multiplier = 0.25   # rappel du catadioptre dans les phares
	amber.metallic = 0.3
	amber.roughness = 0.2
	_refl_mesh = BoxMesh.new()
	_refl_mesh.size = Vector3(0.05, 0.07, 0.006)
	_refl_mesh.material = amber
	_hit_sound = _make_hit_sound()


func _on_body_entered(body: Node3D) -> void:
	var car := body as RigidBody3D
	if car == null or car.mass < 100.0 or car.freeze or _cars.has(car):
		return   # (sol, arbres : corps statiques ignorés)
	_cars.append(car)
	hits += 1
	var v := car.linear_velocity
	var flat := Vector3(v.x, 0.0, v.z)
	var sp := flat.length()
	if sp > 0.8:
		# choc : la voiture perd un peu de vitesse (appliqué près du centre pour ne pas
		# la faire pivoter)
		var dv := minf(sp * hit_speed_loss + hit_speed_loss_fixed, sp * 0.5)
		car.apply_impulse(-flat / sp * car.mass * dv, _push_offset(car))
		# la balise part tout de suite dans le sens de la voiture
		var lv := global_basis.inverse() * flat
		_tilt_vel = Vector2(lv.x, lv.z).normalized() * clampf(sp * 1.2, 2.0, 20.0)
	_play_hit(sp)
	set_physics_process(true)


func _on_body_exited(body: Node3D) -> void:
	_cars.erase(body)


## Point d'application de la poussée sur la voiture : au niveau de la balise, mais
## ramené vers l'axe de la voiture (sinon elle tournerait trop sur elle-même).
func _push_offset(car: RigidBody3D) -> Vector3:
	var off := global_position + Vector3(0, 0.6, 0) - car.global_position
	var side := car.global_basis.x
	return off - side * off.dot(side) * 0.7


func _physics_process(delta: float) -> void:
	var target := Vector2.ZERO
	var pushed := false
	for car: RigidBody3D in _cars.duplicate():
		if not is_instance_valid(car):
			_cars.erase(car)
			continue
		pushed = true
		var v := car.linear_velocity
		var flat := Vector3(v.x, 0.0, v.z)
		var sp := flat.length()
		var lv := global_basis.inverse() * flat
		var dir := Vector2(lv.x, lv.z)
		if sp < 0.4:
			# voiture arrêtée dessus : la balise reste couchée de son côté
			var away := global_basis.inverse() * (global_position - car.global_position)
			dir = Vector2(away.x, away.z) if _tilt.length() < 0.2 else _tilt
		target = dir.normalized() * MAX_BEND
		if sp > 0.5:
			# frottement de la balise sous la voiture
			car.apply_force(-flat / sp * (drag_force + drag_per_ms * sp), _push_offset(car))
	if pushed:
		var prev := _tilt
		_tilt = _tilt.lerp(target, clampf(delta * 16.0, 0.0, 1.0))
		_tilt_vel = (_tilt - prev) / maxf(delta, 0.0001)
	else:
		var w := TAU * SPRING_HZ
		var acc := -w * w * _tilt - 2.0 * SPRING_DAMPING * w * _tilt_vel
		_tilt_vel += acc * delta
		_tilt += _tilt_vel * delta
		if _tilt.length() > MAX_BEND:
			_tilt = _tilt.normalized() * MAX_BEND
			_tilt_vel *= 0.3
		if _tilt.length() < 0.003 and _tilt_vel.length() < 0.02:
			_tilt = Vector2.ZERO
			_tilt_vel = Vector2.ZERO
			_apply_bend()
			set_physics_process(false)
			return
	_apply_bend()


func get_bend_deg() -> float:
	return rad_to_deg(_tilt.length())


func _apply_bend() -> void:
	var a := _tilt.length()
	if a < 0.0001:
		for s in _segs:
			s.basis = Basis.IDENTITY
		return
	var axis := Vector3.UP.cross(Vector3(_tilt.x, 0.0, _tilt.y) / a).normalized()
	for i in SEGMENTS:
		_segs[i].basis = Basis(axis, a * float(BEND_SHARE[i]))


func _play_hit(speed: float) -> void:
	if _player == null:
		_player = AudioStreamPlayer3D.new()
		_player.stream = _hit_sound
		_player.unit_size = 4.0
		_player.max_distance = 60.0
		_player.position.y = 0.5
		add_child(_player)
	_player.volume_db = linear_to_db(clampf(0.35 + speed / 20.0, 0.35, 1.0))
	_player.pitch_scale = randf_range(0.9, 1.1)
	_player.play()
	var strength := clampf(0.2 + speed / 40.0, 0.2, 0.7)
	for h in get_tree().get_nodes_in_group(VRHandInteractor.GROUP):
		(h as VRHandInteractor).pulse(strength, 0.12)


## Bruit de plastique creux : claquement sourd + frottement qui s'éteint (généré par code).
static func _make_hit_sound() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.45)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	var bp := 0.0
	for i in n:
		var t := float(i) / rate
		var noise := randf() * 2.0 - 1.0
		lp += (noise - lp) * 0.25
		bp += (lp - bp) * 0.5
		var thock := sin(TAU * 210.0 * t + 3.0 * exp(-t * 60.0)) * exp(-t * 28.0)
		var hollow := sin(TAU * 640.0 * t) * exp(-t * 45.0) * 0.35
		var scrape := (lp - bp) * exp(-t * 6.0) * 0.9 * clampf(t * 30.0, 0.0, 1.0)
		var s := clampf((thock * 0.8 + hollow + scrape) * 0.8, -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w
