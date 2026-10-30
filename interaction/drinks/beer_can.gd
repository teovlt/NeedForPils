class_name BeerCan
extends VRPickable
## Canette de bière 33 cl (props/cooler/beer_can.glb : Can, Tab, Hole), sortie de la
## glacière (Cooler).
##
## - A/X (VR) ou F (bureau) en la tenant, ou l'autre main qui soulève la languette (VR) :
##   ouvre la canette (« pschitt », un peu de mousse). Ouverte, F la fait boire d'une
##   traite (sans casque) ; en VR, on la porte à la bouche.
## - Boire : ouverte et tenue, l'ouverture portée à la bouche (même bouche que les
##   pilules, les cigarettes et le café) et la canette un peu penchée : gorgées. Chaque
##   gorgée rend bourré, calme le manque et fatigue (PillAddiction.drink_beer,
##   Fatigue.drink_beer). Une canette entière se boit en une dizaine de secondes.
## - Penchée ailleurs qu'à la bouche, elle se renverse. Vide, elle sonne creux.
## - Fermée et lâchée au-dessus de la glacière ouverte, elle y retourne.
## Partie à deux : seul celui qui boit en ressent les effets ; on peut faire boire
## l'autre joueur en portant la canette à sa bouche.

const HEIGHT := 0.122
const MOUTH_RADIUS := 0.09
const RATE := 22050

## Bière restante (1 = pleine).
@export_range(0.0, 1.0) var fill := 1.0
## Canettes bues par seconde, bien penchée à la bouche.
@export var drink_rate := 0.1

var opened := false
var drunk_amount := 0.0          # total bu (tests)

var _tab: Node3D
var _hole: Node3D
var _gulp: AudioStreamPlayer3D
var _fizz: AudioStreamPlayer3D
var _foam: CPUParticles3D
var _gulp_t := 0.0
var _auto_drink := false
var _auto_remote := false


func _ready() -> void:
	super._ready()
	add_to_group("beer_cans")
	rest_up_axis = 1
	friction = 0.5
	_setup.call_deferred()


func _setup() -> void:
	var model := item.get_node_or_null("Model")
	if model:
		_tab = model.find_child("Tab", true, false) as Node3D
		_hole = model.find_child("Hole", true, false) as Node3D
		for side in [1.0, -1.0]:
			var l := Label3D.new()
			l.text = "PILS\nDU BITUME"
			l.font_size = 48
			l.pixel_size = 0.00016
			l.modulate = Color(0.98, 0.92, 0.7)
			l.outline_size = 0
			l.double_sided = false
			l.position = Vector3(0, 0.062, 0.0336 * side)
			l.rotation = Vector3(0, 0.0 if side > 0.0 else PI, 0)
			l.set_meta("_vr_outline", true)
			model.add_child(l)
	_gulp = AudioStreamPlayer3D.new()
	_gulp.stream = Thermos.make_gulp_sound()
	_gulp.unit_size = 1.5
	item.add_child(_gulp)
	_fizz = AudioStreamPlayer3D.new()
	_fizz.stream = _make_fizz()
	_fizz.unit_size = 1.5
	_fizz.volume_db = -2.0
	item.add_child(_fizz)
	_foam = CPUParticles3D.new()
	_foam.amount = 14
	_foam.lifetime = 0.6
	_foam.one_shot = true
	_foam.emitting = false
	_foam.explosiveness = 0.8
	_foam.local_coords = false
	_foam.direction = Vector3.UP
	_foam.spread = 30.0
	_foam.initial_velocity_min = 0.05
	_foam.initial_velocity_max = 0.15
	_foam.gravity = Vector3(0, -0.6, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.006, 0.006)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(1, 0.98, 0.9, 0.85)
	mat.albedo_texture = Smokable._puff_texture()
	q.material = mat
	_foam.mesh = q
	_foam.position = Vector3(0, HEIGHT, 0.012)
	item.add_child(_foam)
	if _tab:
		# VR : l'autre main pince la languette et la soulève -> ouverte
		var th := VRGestureHandle.new()
		th.name = "TabHandle"
		th.owner_grab = self
		th.mesh_root = _tab
		th.segment = VRGestureHandle.part_segment(_tab, "centre")
		th.radius = 0.01
		th.pull_distance = 0.015
		th.available = func() -> bool: return not opened
		th.action = toggle
		item.add_child(th)
	_apply_open(true)
	refresh_meshes()


## Ouverture de la canette (monde).
func mouth_point() -> Vector3:
	return item.global_transform * Vector3(0, HEIGHT, 0.012)


## A/X en VR : ouvre seulement (on boit en la portant à la bouche).
func vr_button() -> void:
	if not opened:
		toggle()


func toggle() -> void:
	if not opened:
		opened = true
		_apply_open(false)
		return
	if fill > 0.01:
		_auto_drink = true
		_auto_remote = Net.applying_remote


func _apply_open(instant: bool) -> void:
	if _hole:
		_hole.visible = opened
	if _tab:
		var a := deg_to_rad(70.0) if opened else 0.0
		if instant:
			_tab.rotation.x = a
		else:
			create_tween().tween_property(_tab, "rotation:x", a, 0.12)
			_fizz.play()
			_foam.restart()


func _process(delta: float) -> void:
	if item == null or not opened or fill <= 0.0:
		return
	var up := item.global_basis.y.normalized().dot(Vector3.UP)
	var rate := 0.0
	var remote := Net.is_online() and Net.held_by_remote(self)
	if _auto_drink:
		rate = drink_rate * 1.5
		remote = remote or _auto_remote
	elif is_grabbed():
		var m := EdiblePickable.mouth_near(get_tree(), mouth_point(), MOUTH_RADIUS)
		if not m.is_empty() and up < 0.97:
			rate = drink_rate * lerpf(0.4, 1.0, clampf((0.95 - up) / 0.6, 0.0, 1.0))
			remote = not m[2]   # à la bouche de l'autre joueur : c'est lui qui boit
	if rate > 0.0:
		var q := minf(rate * delta, fill)
		fill -= q
		drunk_amount += q
		if not remote:
			var add := get_tree().get_first_node_in_group(PillAddiction.GROUP)
			if add and add.has_method("drink_beer"):
				add.drink_beer(q)
			var f := get_tree().get_first_node_in_group(Fatigue.GROUP)
			if f and f.has_method("drink_beer"):
				f.drink_beer(q)
		_gulp_t -= delta
		if _gulp_t <= 0.0:
			_gulp_t = 0.8
			_gulp.pitch_scale = randf_range(0.85, 1.05)
			_gulp.play()
			for h in _grab_hands:
				if h.has_method("pulse"):
					h.pulse(0.15, 0.05)
	else:
		_gulp_t = 0.0
		# penchée sans boire : la bière se renverse
		var thresh := lerpf(-0.2, 0.4, fill)
		if up < thresh:
			fill = maxf(fill - 1.2 * delta, 0.0)
	if fill <= 0.001:
		fill = 0.0
		_auto_drink = false


## « Pschitt » de l'ouverture : bruit blanc filtré qui retombe.
static func _make_fizz() -> AudioStreamWAV:
	var n := int(RATE * 0.45)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		var hp := noise - prev    # aigu
		prev = noise
		var pop := sin(TAU * 900.0 * t) * exp(-t * 120.0)
		var v := (hp * 0.55 * exp(-t * 6.0) + pop * 0.6) * clampf(t / 0.004, 0.0, 1.0)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 28000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w
