@tool
extends Node3D

# Décor du menu, dans le style de la route du jeu (world/road/road_generator.gd) :
# même bitume (road.gdshader), mêmes balises, même terrain à facettes avec fossés,
# mêmes modèles de végétation (props/nature) teintés de la même façon, un champ de
# colza et de blé à droite, de la lavande à gauche, une prairie fleurie au bord de la
# route, des collines boisées, un chalet, des bottes de foin, et l'anneau de montagnes
# enneigées à l'horizon (HorizonMountains). La route part en virage et passe une
# crête au loin, pour qu'on n'en voie pas le bout.
# Le joueur est à l'origine et regarde vers -Z, le long de la route.
# Visible aussi dans l'éditeur ; changer la graine régénère le décor.

@export var seed_value: int = 1337: set = _set_seed
## Densité de la végétation (1 = normal ; baisser si le casque rame).
@export_range(0.1, 2.0) var density: float = 1.0
@export var horizon_mountains := true

const ROAD_HALF_WIDTH := 4.0
const EDGE_LINE := 3.6
## Distances à l'axe des colonnes du terrain (m), comme TERRAIN_COLS du jeu, en plus loin.
const COLS := [4.0, 4.6, 5.5, 7.0, 9.5, 13.0, 18.0, 25.0, 34.0, 45.0, 56.0, 68.0, 80.0, 96.0, 115.0, 135.0, 160.0]
## Fossé : (distance à l'axe, décalage de hauteur).
const DITCH := [Vector2(4.0, 0.0), Vector2(4.6, -0.05), Vector2(5.5, -0.32), Vector2(7.0, -0.15), Vector2(9.5, 0.0)]
const Z_RANGE := Vector2(-270.0, 150.0)
## Taille des cases de regroupement des instances (m) : le moteur ne dessine que les
## cases dans le champ de vision.
const CELL := 70.0
## Champs : côté (+1 droite, -1 gauche), z début/fin, culture proche (13-25 m) et lointaine (25-45 m).
const FIELDS := [
	{"side": 1, "z": Vector2(-95.0, -18.0), "near": "crop_colza", "far": "crop_wheat", "row": Vector2(0.85, 0.8), "wx": Vector2(1.6, 1.9), "seg": 2.0, "fence": true},
	{"side": -1, "z": Vector2(-70.0, -14.0), "near": "crop_lavender", "far": "crop_lavender", "row": Vector2(1.5, 1.5), "wx": Vector2(1.0, 1.0), "seg": 1.8, "fence": false},
	{"side": -1, "z": Vector2(-150.0, -84.0), "near": "crop_sunflower", "far": "stubble", "row": Vector2(1.0, 0.7), "wx": Vector2(1.0, 1.0), "seg": 1.5, "fence": true},
]
## Couleur du sol sous chaque culture.
const SOIL := {
	"crop_colza": Color(0.16, 0.30, 0.08), "crop_wheat": Color(0.42, 0.33, 0.13),
	"crop_lavender": Color(0.30, 0.24, 0.17), "crop_sunflower": Color(0.27, 0.19, 0.11),
	"stubble": Color(0.52, 0.44, 0.22),
}

var _built := false
var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _noise_small := FastNoiseLite.new()
var _meshes := {}      # nom de modèle -> {mesh, xf}
var _buckets := {}     # "nom|case" -> {name, xf: Array[Transform3D], col: Array[Color]}
var _road_mat: ShaderMaterial
var _wetness := 0.0


func _ready() -> void:
	_rebuild()


func _set_seed(v: int) -> void:
	seed_value = v
	if _built:
		_rebuild()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _road_mat == null:
		return
	# bitume mouillé sous la pluie, comme en jeu (vite mouillé ici, pour qu'on le voie)
	var weather := get_tree().get_first_node_in_group("weather_system")
	var rain: float = weather.get("rain") if weather else 0.0
	_wetness = move_toward(_wetness, 1.0 if rain > 0.05 else 0.0, delta / (8.0 if rain > 0.05 else 60.0))
	_road_mat.set_shader_parameter("wetness", _wetness)


## Route mouillée tout de suite (le menu s'ouvre sous la pluie).
func set_wet(wet: bool) -> void:
	_wetness = 1.0 if wet else 0.0


func _rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_buckets.clear()
	_rng.seed = seed_value
	_noise.seed = seed_value
	_noise.frequency = 0.012
	_noise.fractal_octaves = 3
	_noise_small.seed = seed_value + 1
	_noise_small.frequency = 0.08
	_build_road()
	_build_terrain()
	_build_fields()
	_build_meadow()
	_build_woods()
	_build_props()
	_flush_buckets()
	_build_posts()
	if horizon_mountains and not Engine.is_editor_hint():
		var hm: Node3D = preload("res://world/road/horizon_mountains.gd").new()
		hm.name = "HorizonMountains"
		hm.set("random_seed", seed_value)
		# plus proches qu'en jeu (le brouillard les estompe beaucoup à 1 700 m) : on voit les
		# sommets enneigés au-dessus des collines boisées du menu
		hm.set("mountains_radius", 1000.0)
		hm.set("hills_radius", 560.0)
		hm.set("base_offset", -15.0)
		add_child(hm)
	_built = true


# ------------------------------------------------------------------ Tracé

## Abscisse de l'axe de la route à la profondeur z : droite devant le joueur, puis
## un virage à gauche au loin et un à droite derrière (rayons ≥ 200 m).
func road_x(z: float) -> float:
	if z < -35.0:
		return -0.0025 * (z + 35.0) * (z + 35.0)
	if z > 30.0:
		return 0.002 * (z - 30.0) * (z - 30.0)
	return 0.0


## Hauteur de la route : plate autour du joueur, monte vers une crête à ~170 m
## puis redescend derrière (on ne voit pas le bout).
func road_y(z: float) -> float:
	var d := -z
	return 7.0 * smoothstep(55.0, 170.0, d) - 16.0 * smoothstep(175.0, 265.0, d) + 2.0 * smoothstep(40.0, 150.0, z)


func road_slope(z: float) -> float:
	return (road_x(z + 0.5) - road_x(z - 0.5))


## Point du sol à la profondeur z et à la distance signée `lat` de l'axe (+ = droite).
func ground_point(z: float, lat: float) -> Vector3:
	var t := Vector2(road_slope(z), 1.0).normalized()
	# droite du joueur qui regarde vers -Z = +X ; perpendiculaire à l'axe
	var right := Vector3(t.y, 0.0, -t.x)
	var p := Vector3(road_x(z), road_y(z), z) + right * lat
	p.y += _relief(z, lat, p)
	return p


func _relief(z: float, lat: float, p: Vector3) -> float:
	var a := absf(lat)
	if a <= 4.0:
		return 0.0
	var h := 0.0
	for i in DITCH.size() - 1:
		var d0: Vector2 = DITCH[i]
		var d1: Vector2 = DITCH[i + 1]
		if a >= d0.x and a <= d1.x:
			h = lerpf(d0.y, d1.y, (a - d0.x) / (d1.x - d0.x))
	var n := 0.5 + 0.5 * _noise.get_noise_2d(p.x, p.z)
	# douces ondulations près de la route, collines boisées plus loin
	h += (n - 0.4) * 2.5 * smoothstep(9.5, 30.0, a)
	# (pas trop hautes : on doit voir les montagnes enneigées de l'horizon au-dessus)
	h += n * 14.0 * smoothstep(40.0, 120.0, a)
	h += 9.0 * smoothstep(100.0, 160.0, a) * (0.6 + 0.4 * n)
	# vallon derrière le joueur
	h += 6.0 * smoothstep(60.0, 140.0, z) * smoothstep(9.5, 40.0, a)
	return h


func _field_at(z: float, lat: float) -> String:
	var a := absf(lat)
	if a < 13.0 or a > 45.0:
		return ""
	for f in FIELDS:
		if signf(lat) == f["side"] and z >= f["z"].x and z <= f["z"].y:
			return f["near"] if a < 25.0 else f["far"]
	return ""


# ------------------------------------------------------------------ Route

func _build_road() -> void:
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	var tn := FastNoiseLite.new()
	tn.seed = seed_value
	tn.frequency = 0.03
	tn.fractal_octaves = 3
	tex.noise = tn
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://world/road/road.gdshader")
	mat.set_shader_parameter("noise_tex", tex)
	mat.set_shader_parameter("edge_line", EDGE_LINE)
	_road_mat = mat

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lats := [-ROAD_HALF_WIDTH, -2.0, 0.0, 2.0, ROAD_HALF_WIDTH]
	var z := Z_RANGE.x
	var prev: Array = []
	var dist := 0.0
	while z <= Z_RANGE.y:
		var row := []
		for l in lats:
			var p := ground_point(z, l)
			p.y = road_y(z) + 0.02 - 0.02 * absf(l) / ROAD_HALF_WIDTH   # léger bombé
			row.append(p)
		if not prev.is_empty():
			var seg_len: float = (row[2] as Vector3).distance_to(prev[2])
			for i in lats.size() - 1:
				var a: Vector3 = prev[i]
				var b: Vector3 = prev[i + 1]
				var c: Vector3 = row[i]
				var d: Vector3 = row[i + 1]
				# usure de la route : un peu plus abîmée loin du joueur
				var wear := clampf(0.25 + 0.4 * _noise_small.get_noise_2d(z * 0.1, 3.0), 0.0, 0.8)
				var uv := [Vector2(lats[i], dist), Vector2(lats[i + 1], dist), Vector2(lats[i], dist + seg_len), Vector2(lats[i + 1], dist + seg_len)]
				for tri in [[0, 1, 2], [1, 3, 2]]:   # ordre horaire vu d'en haut (face avant)
					for k in tri:
						st.set_color(Color(0, 0, 0, wear))
						st.set_uv(uv[k])
						st.set_normal(Vector3.UP)
						st.add_vertex([a, b, c, d][k])
			dist += seg_len
		prev = row
		z += 2.0
	st.set_material(mat)
	var mi := MeshInstance3D.new()
	mi.name = "Road"
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_posts() -> void:
	# Balises blanches à bande noire, tous les 50 m de chaque côté (comme en jeu)
	var root := Node3D.new()
	root.name = "Posts"
	add_child(root)
	var z := Z_RANGE.y - 20.0
	while z > -190.0:
		for side in [-1.0, 1.0]:
			var post: Node3D = preload("res://world/road/road_post.gd").new()
			var p := ground_point(z, side * (ROAD_HALF_WIDTH + 0.6))
			post.position = p
			post.rotation.y = atan2(road_slope(z), 1.0)
			root.add_child(post)
		z -= 50.0


# ------------------------------------------------------------------ Terrain

func _build_terrain() -> void:
	var lats: Array[float] = []
	for i in range(COLS.size() - 1, -1, -1):
		lats.append(-COLS[i])
	for c in COLS:
		lats.append(c)
	var zs: Array[float] = []
	var z := Z_RANGE.x
	while z <= Z_RANGE.y:
		zs.append(z)
		z += 3.0 if absf(z) < 60.0 else (6.0 if absf(z) < 160.0 else 10.0)
	var grid: Array = []
	for zz in zs:
		var row := PackedVector3Array()
		for l in lats:
			row.append(ground_point(zz, l))
		grid.append(row)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var half := COLS.size()
	for gi in zs.size() - 1:
		for k in lats.size() - 1:
			if k == half - 1:
				continue   # emplacement de la route
			var lat_c := (lats[k] + lats[k + 1]) * 0.5
			var z_c := (zs[gi] + zs[gi + 1]) * 0.5
			var a: Vector3 = grid[gi][k]
			var b: Vector3 = grid[gi][k + 1]
			var c: Vector3 = grid[gi + 1][k]
			var d: Vector3 = grid[gi + 1][k + 1]
			for tri in [[a, b, c], [b, d, c]]:
				var v0: Vector3 = tri[0]
				var v1: Vector3 = tri[1]
				var v2: Vector3 = tri[2]
				# face avant = ordre horaire vu d'en haut : (v1 - v0) × (v2 - v0) vers le bas
				var nrm := (v2 - v0).cross(v1 - v0).normalized()
				if nrm.y < 0.0:
					nrm = -nrm
					var t := v1
					v1 = v2
					v2 = t
				var centre := (v0 + v1 + v2) / 3.0
				var col := _ground_color(centre, z_c, lat_c, nrm)
				for v in [v0, v1, v2]:
					verts.append(v)
					normals.append(nrm)
					colors.append(col)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	add_child(mi)


func _ground_color(centre: Vector3, z: float, lat: float, nrm: Vector3) -> Color:
	var a := absf(lat)
	var g := 0.5 + 0.5 * _noise_small.get_noise_2d(centre.x * 0.5, centre.z * 0.5)
	var col: Color
	var crop := _field_at(z, lat)
	if crop != "":
		var soil: Color = SOIL[crop]
		col = soil.lerp(soil * 1.18, g)
	elif a < 4.7:
		col = Color(0.4, 0.38, 0.35) * (0.9 + 0.2 * g)   # accotement en gravier
	else:
		# herbe de prairie (mêmes teintes que le biome « prairie » / « mixte » du jeu)
		var meadow := Color(0.30, 0.50, 0.16).lerp(Color(0.48, 0.52, 0.20), g)
		var mixed := Color(0.17, 0.36, 0.11).lerp(Color(0.32, 0.42, 0.15), g)
		col = meadow.lerp(mixed, smoothstep(30.0, 90.0, a))
		if a < 6.5:
			col = col.darkened(0.12)   # fossé humide
		else:
			col = col.darkened(0.12 * smoothstep(0.95, 0.8, nrm.y))
			col = col.lerp(Color(0.35, 0.32, 0.27), 0.55 * smoothstep(0.8, 0.6, nrm.y))
	var jp := centre if a <= 9.5 else (centre / 6.0).floor()
	return col * (0.92 + 0.16 * fposmod(jp.x * 12.9898 + jp.z * 78.233, 1.0))


# ------------------------------------------------------------------ Végétation

func _build_fields() -> void:
	for f in FIELDS:
		var side: float = f["side"]
		for band in 2:
			var crop: String = f["near"] if band == 0 else f["far"]
			var x0 := 13.5 if band == 0 else 25.4
			var x1 := 24.6 if band == 0 else 44.0
			var spacing: float = f["row"][band]
			var seg: float = f["seg"]
			var rows := int((x1 - x0) / spacing)
			for j in rows:
				var lat := (x0 + spacing * (j + 0.5)) * side
				var zz: float = f["z"].x + seg * 0.5 + (j % 2) * seg * 0.5
				while zz < f["z"].y - seg * 0.5:
					if _rng.randf() < density + 0.15:
						var sc := Vector3(_rng.randf_range(0.92, 1.08) * f["wx"][band], _rng.randf_range(0.88, 1.1), 1.0)
						_place(crop, zz, lat + _rng.randf_range(-0.06, 0.06), _rng.randf_range(-0.03, 0.03), sc, true)
						# coquelicots dans le blé
						if crop == "crop_wheat" and _rng.randf() < 0.03:
							_place("flower_poppy", zz + _rng.randf_range(-1.0, 1.0), lat, _rng.randf() * TAU, Vector3.ONE * _rng.randf_range(1.0, 1.4))
					zz += seg
			if crop == "stubble":
				for b in 6:
					_place("hay_bale", _rng.randf_range(f["z"].x + 3.0, f["z"].y - 3.0), _rng.randf_range(x0 + 1.0, x1 - 1.0) * side,
						_rng.randf() * TAU, Vector3.ONE * _rng.randf_range(0.9, 1.1))
		if f["fence"]:
			var zz: float = f["z"].x + 1.5
			while zz < f["z"].y - 1.5:
				_place("fence_wood", zz, 12.7 * side, 0.0, Vector3.ONE)
				zz += 3.0


## Prairie fleurie au bord de la route et autour du joueur.
func _build_meadow() -> void:
	var flowers := ["flower_daisy", "flower_daisy", "flower_poppy", "flower_poppy", "flower_cornflower",
		"flower_dandelion", "flower_dandelion", "flower_lupin"]
	var ground := ["grass_tuft", "grass_tuft", "grass_tuft", "grass_dry", "rock_pebbles"]
	var bushes := ["bush_flowers", "bush_flowers", "bush_round", "bush_yellow", "bush_berries", "fern"]
	# fleurs : en touffes, surtout près du joueur (au loin elles ne se voient plus)
	var n_flowers := int(900 * density)
	for i in n_flowers:
		var z := _near_z(60.0)
		var lat := _verge_lat(30.0)
		if _field_at(z, lat) != "":
			continue
		# taches : chaque espèce pousse en groupes
		var patch := _noise_small.get_noise_2d(z * 0.6, lat * 0.6)
		var sp: String = flowers[int((patch * 0.5 + 0.5) * flowers.size() + _rng.randf_range(-1.0, 1.0)) % flowers.size()]
		_place(sp, z, lat, _rng.randf() * TAU, Vector3.ONE * _rng.randf_range(0.8, 1.4))
	for i in int(1100 * density):
		var z := _near_z(110.0)
		var lat := _verge_lat(45.0)
		if _field_at(z, lat) != "":
			continue
		_place(ground[_rng.randi() % ground.size()], z, lat, _rng.randf() * TAU, Vector3.ONE * _rng.randf_range(0.8, 1.6))
	for i in int(140 * density):
		var z := _rng.randf_range(-170.0, 120.0)
		var lat := _verge_lat(55.0, 7.5)
		if _field_at(z, lat) != "" or absf(absf(lat) - 12.7) < 1.5:
			continue
		_place(bushes[_rng.randi() % bushes.size()], z, lat, _rng.randf() * TAU, Vector3.ONE * _rng.randf_range(0.7, 1.4))


## Collines boisées : bois mixte près des champs, sapins plus loin et en hauteur.
func _build_woods() -> void:
	var mixed := ["tree_oak", "tree_oak", "tree", "birch", "birch", "tree_autumn", "poplar", "pine_small"]
	var pines := ["pine_tall", "pine_tall", "pine_small", "spruce", "spruce", "larch", "birch"]
	var rocks := ["rock_boulder", "rock_mossy", "rock_cluster", "rock_flat", "stump"]
	var count := int(950 * density)
	var tries := 0
	var placed := 0
	while placed < count and tries < count * 6:
		tries += 1
		var z := _rng.randf_range(Z_RANGE.x + 10.0, Z_RANGE.y - 5.0)
		var lat := _rng.randf_range(-158.0, 158.0)
		var a := absf(lat)
		if a < 9.0 or _field_at(z, lat) != "" or absf(a - 12.7) < 1.0:
			continue
		# la forêt s'éclaircit vers la route et dans la prairie autour du joueur
		var dens := smoothstep(14.0, 60.0, a) * (0.35 + 0.65 * smoothstep(-0.2, 0.4, _noise.get_noise_2d(z * 1.5, lat * 1.5)))
		if absf(z) < 40.0 and a < 45.0:
			dens *= 0.25
		# bois serré dans l'intérieur du virage au loin : cache la suite de la route
		if z < -150.0 and lat < -12.0:
			dens = maxf(dens, 0.9)
		if _rng.randf() > dens:
			continue
		var list: Array = pines if a > 70.0 or z < -150.0 else mixed
		_place(list[_rng.randi() % list.size()], z, lat, _rng.randf() * TAU, Vector3.ONE * _rng.randf_range(0.8, 1.35))
		placed += 1
	# quelques arbres isolés dans la prairie, pour la profondeur
	for i in 18:
		var z := _rng.randf_range(-120.0, 90.0)
		var lat := _verge_lat(45.0, 9.0)
		if _field_at(z, lat) == "" and absf(absf(lat) - 12.7) > 1.5:
			_place(["tree_oak", "poplar", "birch", "tree"][i % 4], z, lat, _rng.randf() * TAU, Vector3.ONE * _rng.randf_range(0.9, 1.3))
	for i in int(70 * density):
		var z := _rng.randf_range(-200.0, 140.0)
		var lat := _verge_lat(120.0, 8.0)
		if _field_at(z, lat) == "":
			_place(rocks[_rng.randi() % rocks.size()], z, lat, _rng.randf() * TAU, Vector3.ONE * _rng.randf_range(0.6, 1.5))


func _build_props() -> void:
	# chalet sur la colline à gauche, au-dessus des champs
	_place("chalet", -55.0, -62.0, deg_to_rad(70.0), Vector3.ONE, false)
	# bottes de foin oubliées au bord du champ de colza
	_place("hay_bale", -12.0, 15.5, 0.4, Vector3.ONE)
	_place("hay_bale", -10.5, 17.0, 1.3, Vector3.ONE * 0.95)


func _near_z(spread: float) -> float:
	# plus dense près du joueur (z = 0) et devant lui
	var u := _rng.randf()
	return clampf(-spread * u * u * signf(_rng.randf() - 0.25) + _rng.randf_range(-6.0, 6.0), Z_RANGE.x + 5.0, Z_RANGE.y - 5.0)


func _verge_lat(spread: float, min_d := 5.0) -> float:
	var u := _rng.randf()
	var d := min_d + spread * u * u
	return d if _rng.randf() < 0.5 else -d


# ------------------------------------------------------------------ Instances

func _place(mname: String, z: float, lat: float, yaw: float, sc: Vector3, random_tint := true) -> void:
	var m := _model(mname)
	if m.is_empty():
		return
	var p := ground_point(z, lat)
	if absf(lat) < 9.5:
		p.y -= 0.05   # pied dans l'herbe du fossé
	var heading := atan2(road_slope(z), 1.0)   # +Z du modèle le long de la route
	var b := Basis(Vector3.UP, heading + yaw).scaled(sc)
	var xf := Transform3D(b, p) * (m["xf"] as Transform3D)
	var tint := Color(0.5, 0.5, 0.5, 0.0)
	if random_tint:
		var n := _noise.get_noise_2d(p.x * 6.0, p.z * 6.0)
		tint = Color(clampf(0.5 + n * 0.45 + _rng.randf_range(-0.3, 0.3), 0.0, 1.0),
			clampf(0.5 + _rng.randf_range(-0.35, 0.35), 0.0, 1.0),
			clampf(0.5 + _rng.randf_range(-0.5, 0.5), 0.0, 1.0),
			clampf(0.2 + 0.3 * maxf(n, 0.0) + _rng.randf_range(-0.15, 0.2), 0.0, 1.0))
	var cell := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
	var key := "%s|%d|%d" % [mname, cell.x, cell.y]
	if not _buckets.has(key):
		_buckets[key] = {"name": mname, "xf": [], "col": []}
	_buckets[key]["xf"].append(xf)
	_buckets[key]["col"].append(tint)


func _model(mname: String) -> Dictionary:
	if _meshes.has(mname):
		return _meshes[mname]
	var res := {}
	var path := "res://props/tree.glb" if mname == "tree" else "res://props/nature/%s.glb" % mname
	var scene := load(path) as PackedScene
	if scene:
		var inst := scene.instantiate()
		for c in inst.find_children("*", "MeshInstance3D", true, false):
			res = {"mesh": RoadGenerator.tinted_mesh(c as MeshInstance3D, 1.0), "xf": (c as MeshInstance3D).transform}
			break
		inst.free()
	_meshes[mname] = res
	return res


func _flush_buckets() -> void:
	var root := Node3D.new()
	root.name = "Nature"
	add_child(root)
	var small := ["flower", "grass", "rock_pebbles", "fern", "crop", "stubble"]
	for key in _buckets:
		var bk: Dictionary = _buckets[key]
		var mname: String = bk["name"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = _meshes[mname]["mesh"]
		mm.instance_count = bk["xf"].size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, bk["xf"][i])
			mm.set_instance_custom_data(i, bk["col"][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var is_small := false
		for s in small:
			if mname.begins_with(s):
				is_small = true
		if is_small:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
