class_name HorizonMountains
extends Node3D
## Décor lointain qui entoure toujours le joueur : un anneau de collines boisées
## (~900 m) et un anneau de montagnes enneigées (~1 700 m), en facettes low poly.
## Il suit la caméra à l'horizontale (comme un ciel), donc on ne l'atteint jamais,
## et il descend très bas pour cacher le vide sous l'horizon au-delà du terrain.
## Le brouillard de la météo l'estompe (perspective aérienne).

@export var hills_radius := 900.0
@export var mountains_radius := 1700.0
@export var segments := 120
@export var random_seed := 0
## Décalage vertical par rapport à la caméra (m) : le pied des reliefs.
@export var base_offset := -40.0

var _noise := FastNoiseLite.new()
var _mat: StandardMaterial3D
## Éclairage cuit dans les couleurs (direction fixe), assombri la nuit par la météo.
const LIGHT_DIR := Vector3(0.45, 0.75, 0.48)


func _ready() -> void:
	top_level = true
	_noise.seed = random_seed if random_seed != 0 else randi()
	_noise.frequency = 1.0
	_noise.fractal_octaves = 3
	# Sans éclairage (seulement les couleurs et le brouillard) : le relief est dessiné
	# en premier (son centre est sur la caméra) puis recouvert par tout le reste ;
	# éclairé, ce dessin pour rien coûtait cher dans le casque.
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	_mat = mat
	for ring in [
		{"r": mountains_radius, "h": Vector2(170.0, 470.0), "freq": 2.2, "snow": 360.0, "seed": 0.0},
		{"r": hills_radius, "h": Vector2(45.0, 150.0), "freq": 3.5, "snow": 99999.0, "seed": 37.0},
	]:
		var mi := MeshInstance3D.new()
		mi.mesh = _build_ring(ring)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 16384.0   # toujours dessiné
		add_child(mi)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		global_position = cam.global_position + Vector3(0, base_offset, 0)
	# plus de lumière du soleil (matériau sans éclairage) : on assombrit à la main
	var weather := get_tree().get_first_node_in_group("weather_system")
	if weather and weather.has_method("get_darkness"):
		var light := 1.0 - 0.85 * float(weather.get_darkness())
		_mat.albedo_color = Color(light, light, light)


func _h(angle: float, freq: float, seed_off: float) -> float:
	# bruit périodique sur le cercle (pas de raccord visible)
	var v := _noise.get_noise_3d(cos(angle) * freq, sin(angle) * freq, seed_off)
	return clampf(0.5 + 0.75 * v, 0.0, 1.0)


func _build_ring(cfg: Dictionary) -> ArrayMesh:
	var r: float = cfg["r"]
	var hr: Vector2 = cfg["h"]
	var freq: float = cfg["freq"]
	var so: float = cfg["seed"]
	var snow: float = cfg["snow"]
	# rangées : pied enterré, bas, milieu, crête
	var rows: Array[PackedVector3Array] = []
	for k in 4:
		rows.append(PackedVector3Array())
	for i in segments:
		var a := TAU * i / segments
		var h := lerpf(hr.x, hr.y, pow(_h(a, freq, so), 1.4))
		var jit := _noise.get_noise_3d(cos(a) * 9.0, sin(a) * 9.0, so + 11.0)
		var dir := Vector3(cos(a), 0, sin(a))
		rows[0].append(dir * r * 0.97 + Vector3(0, -420.0, 0))
		rows[1].append(dir * r * (0.96 + 0.02 * jit) + Vector3(0, h * (0.12 + 0.05 * jit), 0))
		rows[2].append(dir * r * (1.0 + 0.03 * jit) + Vector3(0, h * (0.55 + 0.1 * jit), 0))
		rows[3].append(dir * r * 1.05 + Vector3(0, h, 0))
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for k in 3:
		for i in segments:
			var j := (i + 1) % segments
			var a0 := rows[k][i]
			var a1 := rows[k][j]
			var b0 := rows[k + 1][i]
			var b1 := rows[k + 1][j]
			for tri in [[a0, b0, a1], [a1, b0, b1]]:
				var v0: Vector3 = tri[0]
				var v1: Vector3 = tri[1]
				var v2: Vector3 = tri[2]
				var nrm := (v1 - v0).cross(v2 - v0).normalized()
				if nrm.dot(-(v0 + v1 + v2)) < 0.0:   # face tournée vers le centre
					nrm = -nrm
					var t := v1
					v1 = v2
					v2 = t
				var cy := (v0.y + v1.y + v2.y) / 3.0
				var top := maxf(v0.y, maxf(v1.y, v2.y))
				var g := 0.5 + 0.5 * _noise.get_noise_3d(v0.x * 0.01, v0.z * 0.01, so + 5.0)
				var col: Color
				if k == 2 and top > snow:
					col = Color(0.88, 0.9, 0.93).lerp(Color(0.75, 0.78, 0.84), g)          # neige
				elif k == 2 or (k == 1 and cy > hr.y * 0.45):
					col = Color(0.36, 0.38, 0.4).lerp(Color(0.42, 0.4, 0.36), g)           # roche
					if snow > 9999.0:
						col = Color(0.2, 0.33, 0.15).lerp(Color(0.28, 0.38, 0.17), g)      # collines : herbe
				else:
					col = Color(0.12, 0.24, 0.12).lerp(Color(0.18, 0.3, 0.13), g)          # forêt
				# ordre horaire vu du centre (face avant dans Godot) : dans l'autre sens,
				# les reliefs étaient éliminés au rendu et restaient invisibles
				# facettes : lumière cuite (direction fixe), le matériau est sans éclairage
				col = col * (0.62 + 0.45 * maxf(nrm.dot(LIGHT_DIR.normalized()), 0.0))
				col.a = 1.0
				for v in [v0, v2, v1]:
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
	return mesh
