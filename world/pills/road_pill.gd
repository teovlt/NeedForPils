class_name RoadPill
extends Node3D
## Pilule géante posée sur la route : tourne, flotte, brille, et un faisceau de
## lumière la signale de loin. Ramassée quand la voiture passe dessus (PillSpawner).

const MODEL := preload("res://props/pill_capsule.glb")
const SCALE := 70.0   # le modèle fait 1 cm de long

var collected := false
var _t := randf() * TAU
var _body: Node3D


func _ready() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	var model := MODEL.instantiate() as Node3D
	model.scale = Vector3.ONE * SCALE
	model.position = Vector3(-0.005 * SCALE, 0.0, 0.0)   # modèle centré sur son milieu
	_body.add_child(model)
	_body.rotation.z = deg_to_rad(25.0)

	# Halo autour de la pilule.
	var halo := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.75
	sphere.height = 1.5
	sphere.radial_segments = 16
	sphere.rings = 8
	halo.mesh = sphere
	halo.material_override = _glow_material(Color(1.0, 0.3, 0.8, 0.22))
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)

	# Faisceau vertical visible de loin.
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.2
	cyl.height = 9.0
	cyl.radial_segments = 8
	cyl.cap_top = false
	cyl.cap_bottom = false
	beam.mesh = cyl
	beam.position.y = 4.5
	beam.material_override = _glow_material(Color(1.0, 0.45, 0.85, 0.18))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.4, 0.85)
	light.light_energy = 1.6
	light.omni_range = 5.0
	light.shadow_enabled = false
	add_child(light)


func _glow_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = c
	return m


func _process(delta: float) -> void:
	_t += delta
	_body.rotation.y += delta * 2.2
	_body.position.y = sin(_t * 2.5) * 0.15


## Ramassée : grossit et disparaît.
func collect() -> void:
	collected = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 1.8, 0.08)
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.12)
	tw.tween_callback(queue_free)
