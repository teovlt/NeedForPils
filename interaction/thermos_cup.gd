class_name ThermosCup
extends VRPickable
## Bouchon du thermos dévissé, qui sert de tasse (créé par Thermos.unscrew).
##
## - Se remplit sous le filet de café du thermos (add_coffee) ; trop pleine, elle déborde.
## - Boire : tenue, le bord porté à la bouche (même bouche que les pilules et les
##   cigarettes) et un peu penchée : gorgées, la fatigue baisse (Fatigue.drink_coffee).
##   Sans casque : F en la tenant, on boit toute la tasse. En partie à deux, portée à
##   la bouche de l'autre joueur, c'est lui qui boit (et se réveille).
## - Penchée ailleurs qu'à la bouche, le café se renverse.
## - Lâchée retournée (ou vide) sur le goulot du thermos ouvert : elle s'y revisse.
## Repère : tasse à l'endroit, fond à y = 0, bord à y = HEIGHT (props/thermos_cup.glb).

const CUP_GROUP := "thermos_cups"
const HEIGHT := 0.078
const BOTTOM := 0.004           # fond intérieur
const R_BOTTOM := 0.034         # rayons intérieurs (fond, bord)
const R_TOP := 0.0385
const MOUTH_RADIUS := 0.1
const SCREW_RADIUS := 0.08

## Remplissage (0 vide, 1 pleine).
@export_range(0.0, 1.0) var fill := 0.0
## Tasses bues par seconde, bien penchée à la bouche.
@export var drink_rate := 0.4

var drunk := 0.0                # total bu (tests)
var spilled := 0.0              # total renversé (tests)

var _liquid: MeshInstance3D
var _liquid_mesh: CylinderMesh
var _shown_fill := -1.0
var _steam: CPUParticles3D
var _drips: CPUParticles3D
var _gulp: AudioStreamPlayer3D
var _gulp_t := 0.0
var _auto_drink := false
var _auto_remote := false       # ... demandée par l'autre joueur (partie à deux)
var _net_drink_t := 0.0         # partie à deux : l'autre joueur nous fait boire (s restantes)


func _ready() -> void:
	super._ready()
	add_to_group(CUP_GROUP)
	rest_up_axis = 1
	friction = 0.6
	_liquid = MeshInstance3D.new()
	_liquid.name = "Coffee"
	_liquid.set_meta("_vr_outline", true)
	_liquid_mesh = CylinderMesh.new()
	_liquid_mesh.radial_segments = 14
	_liquid_mesh.rings = 1
	_liquid.mesh = _liquid_mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = Thermos.COFFEE
	m.roughness = 0.12
	_liquid.material_override = m
	_liquid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	item.add_child.call_deferred(_liquid)
	_steam = _particles(Color(1, 1, 1, 0.25), 0.01, 0.035, Vector3(0, 0.06, 0), 1.6, 8)
	_drips = _particles(Thermos.COFFEE, 0.006, 0.004, Vector3(0, -9.8, 0), 0.5, 16)
	_gulp = AudioStreamPlayer3D.new()
	_gulp.stream = Thermos.make_gulp_sound()
	_gulp.unit_size = 1.5
	item.add_child.call_deferred(_gulp)
	_update_liquid()


func _particles(c: Color, size0: float, size1: float, gravity: Vector3, life: float, amount: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.emitting = false
	p.local_coords = false
	p.gravity = gravity
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.03
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.012
	var q := QuadMesh.new()
	q.size = Vector2(size0, size0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = c
	mat.albedo_texture = Smokable._puff_texture()
	q.material = mat
	p.mesh = q
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, size1 / size0))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = grad
	item.add_child.call_deferred(p)
	return p


## Point du bord au centre de l'ouverture (monde).
func rim_center() -> Vector3:
	return item.global_transform * Vector3(0, HEIGHT, 0)


func _level_y() -> float:
	return BOTTOM + fill * (HEIGHT - 0.008 - BOTTOM)


## Surface du café (monde), là où arrive le filet du thermos.
func liquid_surface() -> Vector3:
	return item.global_transform * Vector3(0, _level_y(), 0)


## Le filet qui tombe de `lip` arrive-t-il dans la tasse ?
func can_receive_from(lip: Vector3) -> bool:
	if item.global_basis.y.normalized().dot(Vector3.UP) < 0.5:
		return false
	var rim := rim_center()
	var dy := lip.y - rim.y
	return Vector2(lip.x - rim.x, lip.z - rim.z).length() < R_TOP + 0.004 and dy > -0.02 and dy < 0.6


## Ajoute du café ; ce qui dépasse déborde. Renvoie ce qui est resté dans la tasse.
func add_coffee(amount: float) -> float:
	var kept := minf(amount, 1.0 - fill)
	fill += kept
	if amount - kept > 0.0:
		_spill(amount - kept)
	_update_liquid()
	return kept


func _spill(amount: float) -> void:
	spilled += amount
	_drips.global_position = _lowest_rim_point()
	_drips.emitting = true


func _lowest_rim_point() -> Vector3:
	var xf := item.global_transform
	var axis := xf.basis.y.normalized()
	var down := Vector3.DOWN - axis * Vector3.DOWN.dot(axis)
	var c := rim_center()
	return c + (down.normalized() * R_TOP if down.length() > 0.01 else Vector3.ZERO)


func _update_liquid() -> void:
	if _liquid == null or absf(_shown_fill - fill) < 0.004:
		return
	_shown_fill = fill
	_liquid.visible = fill > 0.01
	var top := _level_y()
	var h := maxf(top - BOTTOM, 0.001)
	_liquid_mesh.height = h
	_liquid_mesh.bottom_radius = R_BOTTOM - 0.001
	_liquid_mesh.top_radius = lerpf(R_BOTTOM, R_TOP, top / HEIGHT) - 0.001
	_liquid.position = Vector3(0, BOTTOM + h * 0.5, 0)


## F en la tenant (sans casque) : boit toute la tasse.
func toggle() -> void:
	if fill > 0.01:
		_auto_drink = true
		_auto_remote = Net.applying_remote


func _process(delta: float) -> void:
	if item == null:
		return
	var up := item.global_basis.y.normalized().dot(Vector3.UP)
	var drinking := _net_drink_t > 0.0   # l'autre joueur nous fait boire (net_feed)
	_net_drink_t = maxf(_net_drink_t - delta, 0.0)
	# tenue par l'autre joueur : c'est sa machine qui cherche une bouche
	var remote_held := Net.is_online() and Net.held_by_remote(self)
	if fill > 0.001:
		var rate := 0.0
		var remote := false   # bu par l'autre joueur : l'effet est chez lui
		var feed_other := false
		if _auto_drink:
			rate = drink_rate * 1.2
			remote = _auto_remote
		elif is_grabbed() and not remote_held:
			var m := EdiblePickable.mouth_near(get_tree(), rim_center(), MOUTH_RADIUS)
			if not m.is_empty() and up < 0.97:
				rate = drink_rate * lerpf(0.4, 1.0, clampf((0.95 - up) / 0.5, 0.0, 1.0))
				remote = not m[2]
				feed_other = remote
		if rate > 0.0:
			drinking = true
			var q := minf(rate * delta, fill)
			fill -= q
			drunk += q
			var f := get_tree().get_first_node_in_group(Fatigue.GROUP)
			if f and not remote:
				f.drink_coffee(q)
			if feed_other:
				Net.feed(self, q)
			_gulp_t -= delta
			if _gulp_t <= 0.0:
				_gulp_t = 0.7
				_gulp.pitch_scale = randf_range(0.9, 1.1)
				_gulp.play()
				for h in _grab_hands:
					if h.has_method("pulse"):
						h.pulse(0.15, 0.06)
		elif not drinking:
			# penchée sans boire : le café se renverse
			var thresh := lerpf(0.05, 0.75, fill)
			if up < thresh:
				var q := minf(1.6 * clampf((thresh - up) / 0.35, 0.1, 1.0) * delta, fill)
				fill -= q
				_spill(q)
	if fill <= 0.001:
		fill = 0.0
		_auto_drink = false
	if not drinking:
		_gulp_t = 0.0
	if _drips.emitting and Engine.get_process_frames() % 20 == 0 and not _is_spilling(up):
		_drips.emitting = false
	_steam.emitting = fill > 0.05 and up > 0.6
	if _steam.emitting:
		_steam.global_position = liquid_surface() + Vector3.UP * 0.01
	_update_liquid()


## Partie à deux : l'autre joueur nous fait boire une gorgée `q` de la tasse.
func net_feed(q: float) -> void:
	q = minf(q, fill)
	if q <= 0.0:
		return
	fill -= q
	drunk += q
	var f := get_tree().get_first_node_in_group(Fatigue.GROUP)
	if f:
		f.drink_coffee(q)
	if _net_drink_t <= 0.0 and _gulp:
		_gulp.pitch_scale = randf_range(0.9, 1.1)
		_gulp.play()
	_net_drink_t = 0.3


func _is_spilling(up: float) -> bool:
	return fill > 0.001 and up < lerpf(0.05, 0.75, fill)


func _on_grab_end(hand: Node3D) -> void:
	if hand == _active_hand and _grab_hands.is_empty():
		# lâchée retournée (ou vide) sur le goulot du thermos ouvert : revissée
		for t in get_tree().get_nodes_in_group(Thermos.THERMOS_GROUP):
			var th := t as Thermos
			if th.capped or th.get_cup() != self:
				continue
			var inverted := item.global_basis.y.dot(th.item.global_basis.y) < -0.3
			var c := item.global_transform * Vector3(0, HEIGHT * 0.5, 0)
			if (inverted or fill < 0.02) and c.distance_to(th.neck_position()) < SCREW_RADIUS:
				_active_hand = null
				th.screw_on(self)
				return
	super._on_grab_end(hand)
