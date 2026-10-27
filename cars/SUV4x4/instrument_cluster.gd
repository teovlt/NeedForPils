class_name InstrumentCluster
extends Node3D
## Combiné d'instruments derrière le volant : un écran (quad) qui affiche un dessin 2D
## (ClusterDisplay) rendu dans un SubViewport. Le noeud est le centre de l'écran,
## son axe +Z pointe vers le conducteur.
## Le rétro-éclairage de l'écran éclaire légèrement le volant, les mains et le haut du
## tableau de bord (surtout visible la nuit) : lumière bleutée, teintée de rouge quand
## des voyants rouges sont allumés, éteinte contact coupé, faiblit au démarreur.

@export var screen_size := Vector2(0.345, 0.13)
@export var resolution := Vector2i(640, 240)
## Luminosité de l'écran (rétro-éclairage).
@export var brightness := 1.0
## Lumière émise vers le conducteur (énergie à pleine luminosité).
@export var glow_energy := 0.42
@export var glow_range := 0.68
@export var glow_color := Color(0.78, 0.87, 1.0)

var display: ClusterDisplay
var _glow: SpotLight3D
var _glow_level := 0.0


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
	# rétro-éclairage : projecteur large et doux tourné vers le conducteur (+Z du noeud)
	_glow = SpotLight3D.new()
	_glow.name = "Glow"
	_glow.position = Vector3(0.0, 0.0, 0.02)
	_glow.rotation = Vector3(0.0, PI, 0.0)
	_glow.spot_range = glow_range
	_glow.spot_angle = 68.0
	_glow.spot_attenuation = 1.6
	_glow.spot_angle_attenuation = 0.6
	_glow.light_specular = 0.08
	_glow.shadow_enabled = false
	_glow.light_energy = 0.0
	_glow.visible = false
	add_child(_glow)


func _process(delta: float) -> void:
	var car := display.car if display else null
	if _glow == null or car == null:
		return
	var level: int = car.get_ignition_level() if car.has_method("get_ignition_level") else 2
	var target := 0.0
	if level >= 2:
		target = 1.0
		if car.get("engine_state") == 1:
			target = 0.55 + 0.1 * sin(Time.get_ticks_msec() * 0.05)   # tension qui chute au démarreur
	_glow_level = move_toward(_glow_level, target, delta * (6.0 if target > _glow_level else 3.0))
	_glow.visible = _glow_level > 0.01
	if not _glow.visible:
		return
	# teinte : voyants rouges allumés (batterie, ceinture, frein à main) -> plus rouge
	var reds := 0.0
	if car.has_method("is_engine_running") and not car.is_engine_running():
		reds += 1.0
	if car.has_method("get_belt_warning") and car.get_belt_warning() > 0:
		reds += 1.0
	if car.has_method("get_handbrake_amount") and car.get_handbrake_amount() > 0.3:
		reds += 1.0
	var c := glow_color.lerp(Color(1.0, 0.35, 0.3), clampf(reds * 0.12, 0.0, 0.35))
	_glow.light_color = c
	_glow.light_energy = glow_energy * brightness * _glow_level


func _find_car() -> Node:
	var n := get_parent()
	while n and not (n is VehicleBody3D):
		n = n.get_parent()
	return n
