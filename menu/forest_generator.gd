@tool
extends Node3D

# Génère procéduralement le décor du menu : une route posée au sol
# et une forêt de sapins low-poly (MultiMesh, léger pour le Quest).
# Visible aussi dans l'éditeur ; changer un paramètre régénère le décor.

@export var seed_value: int = 1337: set = _set_and_rebuild_int
@export var tree_count: int = 700: set = _set_and_rebuild_tree_count
@export var rock_count: int = 80
@export var area_size: Vector2 = Vector2(180, 200)
## Distance libre de chaque côté de l'axe de la route
@export var road_clearance: float = 6.0
@export var road_width: float = 7.0
@export var road_length: float = 200.0

var _built := false


func _ready() -> void:
	_rebuild()


func _set_and_rebuild_int(v: int) -> void:
	seed_value = v
	if _built:
		_rebuild()


func _set_and_rebuild_tree_count(v: int) -> void:
	tree_count = v
	if _built:
		_rebuild()


func _rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_build_road()
	_build_forest()
	_built = true


# ------------------------------------------------------------------ Route

func _build_road() -> void:
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color(0.17, 0.17, 0.18)
	asphalt.roughness = 0.85

	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.92, 0.92, 0.9)

	var yellow := StandardMaterial3D.new()
	yellow.albedo_color = Color(1, 0.75, 0.1)
	yellow.emission_enabled = true
	yellow.emission = Color(1, 0.72, 0.1)
	yellow.emission_energy_multiplier = 0.4

	var shoulder := StandardMaterial3D.new()
	shoulder.albedo_color = Color(0.33, 0.29, 0.22)
	shoulder.roughness = 1.0

	# Accotements en terre, puis asphalte, puis marquages : tous à plat au sol,
	# avec un très léger décalage en hauteur pour éviter le z-fighting.
	_add_plane("Shoulder", Vector2(road_width + 2.0, road_length), 0.003, 0.0, shoulder)
	_add_plane("Asphalt", Vector2(road_width, road_length), 0.006, 0.0, asphalt)
	_add_plane("EdgeLineLeft", Vector2(0.15, road_length), 0.009, -road_width / 2 + 0.3, white)
	_add_plane("EdgeLineRight", Vector2(0.15, road_length), 0.009, road_width / 2 - 0.3, white)

	# Pointillés centraux
	var dash := PlaneMesh.new()
	dash.size = Vector2(0.15, 3.0)
	dash.material = yellow
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = dash
	var spacing := 6.0
	mm.instance_count = int(road_length / spacing)
	for i in mm.instance_count:
		var z := -road_length / 2 + i * spacing
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, 0.009, z)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "CenterDashes"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _add_plane(node_name: String, size: Vector2, y: float, x: float, mat: Material) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = Vector3(x, y, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ------------------------------------------------------------------ Forêt

func _build_forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95

	# Sapins
	var trees := MultiMesh.new()
	trees.transform_format = MultiMesh.TRANSFORM_3D
	trees.use_colors = true
	trees.mesh = _make_pine_mesh(mat)
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var tries := 0
	while transforms.size() < tree_count and tries < tree_count * 10:
		tries += 1
		var p := _random_spot(rng)
		if p == Vector3.INF:
			continue
		var s := rng.randf_range(0.7, 1.6)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.25), s))
		transforms.append(Transform3D(b, p))
		var tint := rng.randf_range(0.8, 1.15)
		colors.append(Color(tint, tint * rng.randf_range(0.95, 1.05), tint))
	trees.instance_count = transforms.size()
	for i in transforms.size():
		trees.set_instance_transform(i, transforms[i])
		trees.set_instance_color(i, colors[i])
	var trees_node := MultiMeshInstance3D.new()
	trees_node.name = "Pines"
	trees_node.multimesh = trees
	add_child(trees_node)

	# Rochers
	var rocks := MultiMesh.new()
	rocks.transform_format = MultiMesh.TRANSFORM_3D
	rocks.mesh = _make_rock_mesh(mat)
	var rock_transforms: Array[Transform3D] = []
	tries = 0
	while rock_transforms.size() < rock_count and tries < rock_count * 10:
		tries += 1
		var p := _random_spot(rng, 4.5)
		if p == Vector3.INF:
			continue
		var s := rng.randf_range(0.3, 1.2)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * rng.randf_range(0.8, 1.5), s * 0.6, s))
		rock_transforms.append(Transform3D(b, p))
	rocks.instance_count = rock_transforms.size()
	for i in rock_transforms.size():
		rocks.set_instance_transform(i, rock_transforms[i])
	var rocks_node := MultiMeshInstance3D.new()
	rocks_node.name = "Rocks"
	rocks_node.multimesh = rocks
	add_child(rocks_node)


# Retourne une position libre dans la zone, ou Vector3.INF si trop proche de la route / du joueur
func _random_spot(rng: RandomNumberGenerator, clearance: float = road_clearance) -> Vector3:
	var x := rng.randf_range(-area_size.x / 2, area_size.x / 2)
	var z := rng.randf_range(-area_size.y / 2, area_size.y / 2)
	if absf(x) < clearance:
		return Vector3.INF
	if Vector2(x, z).length() < 8.0:
		return Vector3.INF
	return Vector3(x, 0, z)


func _make_pine_mesh(mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Tronc
	_add_cone(st, 0.0, 1.2, 0.22, 0.16, 6, Color(0.36, 0.24, 0.14))
	# Trois étages de feuillage
	_add_cone(st, 1.0, 3.6, 1.8, 0.0, 8, Color(0.07, 0.22, 0.10))
	_add_cone(st, 2.4, 4.8, 1.4, 0.0, 8, Color(0.09, 0.27, 0.12))
	_add_cone(st, 3.7, 6.0, 1.0, 0.0, 8, Color(0.11, 0.32, 0.14))
	st.set_material(mat)
	return st.commit()


func _make_rock_mesh(mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col := Color(0.42, 0.42, 0.44)
	# Petit dôme facetté
	_add_cone(st, -0.2, 0.5, 1.0, 0.55, 7, col)
	_add_cone(st, 0.5, 0.9, 0.55, 0.0, 7, col)
	st.set_material(mat)
	return st.commit()


# Tronc de cône (rayon bottom_r -> top_r) avec normales plates pour un rendu low-poly
func _add_cone(st: SurfaceTool, y0: float, y1: float, bottom_r: float, top_r: float, sides: int, color: Color) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var b0 := Vector3(cos(a0) * bottom_r, y0, sin(a0) * bottom_r)
		var b1 := Vector3(cos(a1) * bottom_r, y0, sin(a1) * bottom_r)
		var t0 := Vector3(cos(a0) * top_r, y1, sin(a0) * top_r)
		var t1 := Vector3(cos(a1) * top_r, y1, sin(a1) * top_r)
		var shade := color.darkened(0.12 * (0.5 + 0.5 * sin(a0)))
		_tri(st, b0, b1, t0, shade)
		if top_r > 0.0:
			_tri(st, b1, t1, t0, shade)


# Triangle en ordre horaire (face avant dans Godot)
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var n := (c - a).cross(b - a).normalized()
	for v in [a, b, c]:
		st.set_color(color)
		st.set_normal(n)
		st.add_vertex(v)
