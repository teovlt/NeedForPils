class_name Lighter
extends VRPickable
## Briquet jetable (props/lighter.glb) : on l'attrape, et en le tenant on l'allume / on
## l'éteint (F sans casque, A / X en VR). Flamme qui vacille avec une petite lumière
## orange, clic de la molette. Il s'éteint quand on le lâche.

const LIGHT_RANGE := 1.6

var lit := false

var _flame: Node3D
var _light: OmniLight3D
var _click: AudioStreamPlayer3D
var _t := 0.0
var _grow := 1.0


func _ready() -> void:
	super._ready()
	rest_up_axis = -1
	friction = 0.55
	add_to_group("lighters")
	# tout de suite : la flamme est exclue du contour de surbrillance (construit plus tard)
	for mi in _flame_meshes():
		mi.set_meta("_vr_outline", true)
	_setup.call_deferred()


func _flame_meshes() -> Array:
	var f := item.find_child("Flame", true, false)
	if f == null:
		return []
	var out: Array = f.find_children("*", "MeshInstance3D", true, false)
	if f is MeshInstance3D:
		out.append(f)   # le nœud Flame du glb est lui-même le maillage
	return out


func _setup() -> void:
	_flame = item.find_child("Flame", true, false) as Node3D
	if _flame:
		for mi in _flame_meshes():
			var src := (mi as MeshInstance3D).get_active_material(0) as StandardMaterial3D
			var m := StandardMaterial3D.new()
			var c := src.albedo_color if src else Color(1.0, 0.55, 0.12)
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(c.r, c.g, c.b, 0.85)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			(mi as MeshInstance3D).material_override = m
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flame.visible = false
		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.62, 0.25)
		_light.omni_range = LIGHT_RANGE
		_light.light_energy = 0.0
		_light.position = Vector3(0, 0.012, 0)
		_flame.add_child(_light)
	_click = AudioStreamPlayer3D.new()
	_click.stream = _make_click()
	_click.unit_size = 1.5
	_click.volume_db = -6.0
	item.add_child(_click)


## Boîte du corps seul (la flamme, cachée, ne compte pas pour le rangement).
func get_local_aabb() -> AABB:
	return AABB(Vector3(-0.0135, -0.0005, -0.0078), Vector3(0.027, 0.0775, 0.0156))


## Position monde de la flamme (pour allumer une cigarette ou un joint).
func flame_position() -> Vector3:
	if _flame:
		return _flame.global_position + Vector3(0, 0.012, 0)
	return item.global_transform * Vector3(0, 0.085, 0)


func play_click() -> void:
	if _click:
		_click.pitch_scale = randf_range(0.9, 1.15)
		_click.play()


## F / A / X : allume ou éteint, seulement quand on le tient.
func toggle() -> void:
	if not is_grabbed():
		return
	set_lit(not lit)


func set_lit(on: bool) -> void:
	if on == lit:
		return
	lit = on
	if _click:
		_click.pitch_scale = randf_range(0.9, 1.15) if on else 0.7
		_click.play()
	if _flame:
		_flame.visible = on
		_grow = 0.4   # la flamme « prend »


## A/X en VR.
func vr_button() -> void:
	toggle()


func _on_grab_end(hand: Node3D) -> void:
	super._on_grab_end(hand)
	if not is_grabbed():
		set_lit(false)


func _process(delta: float) -> void:
	if not lit or _flame == null:
		return
	_t += delta
	# flamme qui vacille (et monte d'un coup à l'allumage)
	_grow = move_toward(_grow, 1.0, delta * 6.0)
	var wob := 1.0 + 0.12 * sin(_t * 23.0) * sin(_t * 7.3) + randf() * 0.05
	# la flamme monte toujours vers le ciel, quelle que soit l'inclinaison du briquet
	var sc := Vector3(1.0 - (wob - 1.0) * 0.5, _grow * wob, 1.0 - (wob - 1.0) * 0.5)
	_flame.global_basis = Basis.IDENTITY.scaled(sc * item.global_basis.get_scale())
	if _light:
		_light.light_energy = 0.6 * wob


## Clic de la molette (frottement métallique bref).
static func _make_click() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.09)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in n:
		var t := float(i) / rate
		var env := exp(-t * 70.0) + 0.25 * exp(-maxf(t - 0.035, 0.0) * 90.0) * (1.0 if t > 0.035 else 0.0)
		var v := (rng.randf_range(-1.0, 1.0) * 0.7 + sin(TAU * 3200.0 * t) * 0.3) * env
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 26000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w
