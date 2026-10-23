class_name InstrumentCluster
extends Node3D
## Combiné d'instruments derrière le volant : un écran (quad) qui affiche un dessin 2D
## (ClusterDisplay) rendu dans un SubViewport. Le noeud est le centre de l'écran,
## son axe +Z pointe vers le conducteur.

@export var screen_size := Vector2(0.345, 0.13)
@export var resolution := Vector2i(640, 240)
## Luminosité de l'écran (rétro-éclairage).
@export var brightness := 1.0

var display: ClusterDisplay


func _ready() -> void:
	var vp := SubViewport.new()
	vp.name = "ClusterView"
	vp.size = resolution
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	display = ClusterDisplay.new()
	display.size = Vector2(resolution)
	display.car = _find_car()
	vp.add_child(display)

	var screen := MeshInstance3D.new()
	screen.name = "Screen"
	var quad := QuadMesh.new()
	quad.size = screen_size
	screen.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = vp.get_texture()
	mat.albedo_color = Color(brightness, brightness, brightness)
	screen.material_override = mat
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(screen)


func _find_car() -> Node:
	var n := get_parent()
	while n and not (n is VehicleBody3D):
		n = n.get_parent()
	return n
