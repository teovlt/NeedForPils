class_name RoadGenerator
extends Node3D
## Route infinie générée au fur et à mesure qu'on avance.
##
## - Tracé aléatoire : lignes droites, virages (rayon mini), côtes et descentes.
## - Tronçons de `chunk_length` m créés devant la cible et supprimés derrière.
##   Le calcul des maillages se fait dans un thread (pas d'à-coups en VR).
## - Défauts : nids-de-poule creusés dans la géométrie (la voiture tressaute),
##   dos-d'âne, rustines, fissures, flaques dans les trous quand il pleut.
## - Décor : accotements, fossés, collines, arbres, camions en panne, bornes.
## - Recentrage de l'origine du monde tous les `origin_shift_distance` m
##   (évite les tremblements dus à la précision des flottants loin de l'origine).
## Les autres scripts peuvent appeler sample_road(position) pour connaître la route.

signal chunk_created(index: int)
signal origin_shifted(offset: Vector3)

@export var target_path: NodePath
@export var random_seed := 0   ## 0 = aléatoire à chaque partie

@export_group("Tracé")
@export var chunk_length := 40.0
@export var row_step := 0.25
@export var lateral_step := 0.25
@export var road_half_width := 4.0
@export var lane_width := 3.5
@export var generate_ahead := 480.0
@export var keep_behind := 90.0
## Longueur de ligne droite au départ.
@export var straight_start := 90.0
## Rayon de virage mini (m). Doit rester plus grand que la largeur du terrain
## (TERRAIN_COLS[-1] = 115 m), sinon le terrain se replie à l'intérieur des virages.
@export var min_curve_radius := 130.0
@export var max_grade := 0.06
## Pente maxi en montagne.
@export var max_grade_mountain := 0.09

@export_group("Relief")
## Amplitude du relief général (m) hors montagne : la route monte et descend avec lui.
@export var relief_height := 45.0
## Altitude et amplitude ajoutées en montagne (m).
@export var mountain_relief := 130.0
## Altitude (m, repère du monde) au-dessus de laquelle la neige tient en montagne.
@export var snow_altitude := 150.0

@export_group("Défauts de la route")
## Nombre moyen de nids-de-poule par tronçon quand la route est très abîmée.
@export var potholes_per_chunk := 4.0
## La route s'abîme un peu plus tous les X mètres parcourus.
@export var degradation_distance := 4000.0
@export_range(0.0, 1.0) var speed_bump_chance := 0.12

@export_group("Décor")
@export var terrain_height := 7.0
@export var tree_scene: PackedScene = preload("res://props/tree.glb")
@export var truck_scene: PackedScene = preload("res://props/truck.glb")
@export var trees_per_chunk := Vector2i(3, 9)   ## (ancien réglage, remplacé par les biomes ci-dessous)
## Densité globale de la végétation et des rochers (1 = normal).
@export_range(0.0, 3.0) var nature_density := 1.0
## Taille des zones de végétation (forêt de sapins / bois mixte / prairie fleurie), en m.
@export var biome_size := 700.0
@export_range(0.0, 1.0) var broken_truck_chance := 0.05
@export var post_spacing := 50.0

@export_group("Monde")
@export var origin_shift_distance := 1500.0
## Affiche les temps de création dans la console.
@export var debug_timings := false

## Distance totale parcourue par la route générée (m).
var generated_distance := 0.0
var world_offset := Vector3.ZERO

# Bords du terrain (distance à l'axe, m) et décalage de hauteur.
const TERRAIN_COLS := [4.0, 4.6, 5.5, 7.0, 9.5, 13.0, 18.0, 25.0, 34.0, 45.0, 56.0, 68.0, 80.0, 96.0, 115.0]
## Au-delà de quelques mètres, le terrain rejoint le relief général (`relief()`) : la
## route peut longer un versant, passer en tranchée ou dominer une vallée. Au-delà de
## 45 m, un rebord (la vallée) remonte encore si la route n'est pas déjà en hauteur.
## Rayon de virage mini 130 m > 115 m : pas de repli à l'intérieur des virages.
const VALLEY_START := 45.0
const COARSE_FROM := 56.0   # au-delà, facettes du terrain 4 fois plus longues
const TERRAIN_DROP := [0.0, -0.05, -0.32, -0.15]

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _noise_small := FastNoiseLite.new()
var _road_mat: ShaderMaterial
var _terrain_mat: StandardMaterial3D
var _post_mesh: BoxMesh
var _biome_noise := FastNoiseLite.new()
var _mountain_noise := FastNoiseLite.new()
## Taille des régions de montagne (m) et part de la carte en montagne (0 = jamais, 1 = beaucoup).
@export var mountain_size := 1800.0
@export_range(0.0, 1.0) var mountain_amount := 0.45
var _tint_noise := FastNoiseLite.new()
var _valley_noise := FastNoiseLite.new()
var _relief_noise := FastNoiseLite.new()
var _relief0 := 0.0   # altitude du relief au départ : la route part toujours de y = 0
## Hauteur moyenne des collines qui bordent la vallée (m, à 80 m de l'axe).
@export var valley_hill_height := 24.0
## Anneau de collines et de montagnes lointaines autour du joueur.
@export var horizon_mountains := true   # taches de couleur du décor (~80 m)
const NATURE_TINT_SHADER := preload("res://world/road/nature_tint.gdshader")
## Force de la variation de couleur du décor (0 = couleurs d'origine).
@export_range(0.0, 2.0) var nature_color_variation := 1.0
var _nature: Array[Dictionary] = []   # espèces de décor (voir _setup_nature)
var _mesh_cache := {}                 # nom de modèle -> {mesh, xf}
var _field_plans := {}                # Vector2i(n° de champ, côté) -> plan du champ (voir _plan_fields)
## Fréquence des champs cultivés (0 = aucun, 1 = normal, 2 = beaucoup).
@export_range(0.0, 2.0) var field_chance := 1.0

# État du tracé
var _pos := Vector3.ZERO
var _heading := 0.0          # 0 = vers +Z
var _k := 0.0                # courbure (1/m), + = vers la gauche
var _k_target := 0.0
var _k_left := 0.0
var _grade := 0.0
var _grade_target := 0.0
var _grade_left := 0.0
var _wander := 0.0           # direction générale, évite que la route boucle
var _s := 0.0
var _quality := 0.2          # 0 = neuve, 1 = défoncée
var _quality_target := 0.2
var _first_row := true

var _chunks: Array[Dictionary] = []
var _pending: Array[Dictionary] = []
var _chunk_index := 0
var _wetness := 0.0
var _target: Node3D
var _collision_queue: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("road_generator")
	if random_seed != 0:
		_rng.seed = random_seed
	else:
		_rng.randomize()
	_noise.seed = _rng.randi()
	_noise.frequency = 0.006
	_noise.fractal_octaves = 3
	_noise_small.seed = _rng.randi()
	_noise_small.frequency = 0.08
	_relief_noise.seed = _rng.randi()
	_relief_noise.frequency = 1.0 / 850.0
	_relief_noise.fractal_octaves = 3
	_valley_noise.seed = _rng.randi()
	_valley_noise.frequency = 1.0 / 260.0
	_valley_noise.fractal_octaves = 2
	if horizon_mountains:
		var hm: Node3D = preload("res://world/road/horizon_mountains.gd").new()
		hm.name = "HorizonMountains"
		hm.set("random_seed", _rng.randi())
		add_child(hm)

	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	var tn := FastNoiseLite.new()
	tn.seed = _rng.randi()
	tn.frequency = 0.03
	tn.fractal_octaves = 3
	tex.noise = tn
	_road_mat = ShaderMaterial.new()
	_road_mat.shader = preload("res://world/road/road.gdshader")
	_road_mat.set_shader_parameter("noise_tex", tex)
	_road_mat.set_shader_parameter("edge_line", lane_width + 0.1)

	_terrain_mat = StandardMaterial3D.new()
	_terrain_mat.vertex_color_use_as_albedo = true
	_terrain_mat.roughness = 1.0

	_post_mesh = BoxMesh.new()
	_post_mesh.size = Vector3(0.12, 1.0, 0.12)
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.92, 0.92, 0.9)
	_post_mesh.material = post_mat

	_setup_nature()
	_relief0 = 0.0
	_relief0 = relief(_pos + world_offset)

	_target = get_node_or_null(target_path) as Node3D
	# Premiers tronçons tout de suite (synchrone) pour que la voiture ait un sol :
	# jusqu'à 80 m devant la voiture (la route peut commencer loin derrière elle).
	var t0 := _target.global_position if _target else global_position
	var n := 0
	while n < 3 or ((to_global(_pos) - global_position).length() < (t0 - global_position).length() + 80.0 and n < 40):
		_finalize(_queue_chunk(false))
		n += 1
	# Collisions des premiers tronçons tout de suite.
	while not _collision_queue.is_empty():
		var item: Dictionary = _collision_queue.pop_front()
		_add_collision(item["chunk"], item["faces"])


func _physics_process(delta: float) -> void:
	if _target == null:
		_target = get_node_or_null(target_path) as Node3D
	var tpos := _target.global_position if _target else Vector3.ZERO

	_update_wetness(delta)
	if _shift_origin_if_needed(tpos):
		tpos = _target.global_position

	# Collisions en attente : un morceau par image (évite les à-coups).
	var t_col := Time.get_ticks_usec()
	while not _collision_queue.is_empty():
		var item: Dictionary = _collision_queue.pop_front()
		if is_instance_valid(item["chunk"]):
			_add_collision(item["chunk"], item["faces"])
			break
	t_col = Time.get_ticks_usec() - t_col

	# Tronçons terminés par les threads -> scène.
	if not _pending.is_empty() and WorkerThreadPool.is_task_completed(_pending[0]["task"]):
		var job: Dictionary = _pending.pop_front()
		WorkerThreadPool.wait_for_task_completion(job["task"])
		_finalize(job)

	# Nouveaux tronçons devant.
	if _pending.size() < 2:
		if (to_global(_pos) - tpos).length() < generate_ahead:
			_queue_chunk(true)

	# Suppression des tronçons derrière.
	var t_del := Time.get_ticks_usec()
	while _chunks.size() > 2:
		var c: Dictionary = _chunks[0]
		var node: Node3D = c["node"]
		var end_pos: Vector3 = node.to_global(c["end"])
		if (tpos - end_pos).dot(c["end_dir"]) > keep_behind:
			node.queue_free()
			_chunks.pop_front()
		else:
			break
	t_del = Time.get_ticks_usec() - t_del
	if debug_timings and (t_col > 4000 or t_del > 4000):
		print("Route : collision %.1f ms, suppression %.1f ms" % [t_col / 1000.0, t_del / 1000.0])


# --- Informations sur la route -----------------------------------------------

## Point de route le plus proche : {point, dir, right, lateral, s, found}.
## lateral > 0 = à droite de l'axe.
func sample_road(world_pos: Vector3) -> Dictionary:
	var best := {"found": false}
	var best_d := INF
	for ch in _chunks:
		var ch_node: Node3D = ch["node"]
		var ch_local := ch_node.to_local(world_pos)
		var ch_rows: PackedVector3Array = ch["rows_p"]
		# Recherche grossière puis fine.
		for i in range(0, ch_rows.size(), 8):
			var d := ch_rows[i].distance_squared_to(ch_local)
			if d < best_d:
				best_d = d
				best = {"found": true, "chunk": ch, "i": i}
	if not best["found"]:
		return best
	var c: Dictionary = best["chunk"]
	var node: Node3D = c["node"]
	var local := node.to_local(world_pos)
	var rp: PackedVector3Array = c["rows_p"]
	var rr: PackedVector3Array = c["rows_r"]
	var rs: PackedFloat32Array = c["rows_s"]
	var i0: int = best["i"]
	var bi := i0
	best_d = INF
	for i in range(maxi(0, i0 - 8), mini(rp.size(), i0 + 9)):
		var d := rp[i].distance_squared_to(local)
		if d < best_d:
			best_d = d
			bi = i
	var right: Vector3 = rr[bi]
	var dir := Vector3.UP.cross(right).normalized()
	return {
		"found": true,
		"point": node.to_global(rp[bi]),
		"right": right,
		"dir": dir,
		"lateral": (local - rp[bi]).dot(right),
		"s": rs[bi],
	}


## Point de route situé `distance` m plus loin (le long de la route) que world_pos
## (distance négative = en arrière).
## Renvoie {found, chunk, i, point, right, dir, s} (vecteurs en coordonnées monde).
func sample_ahead(world_pos: Vector3, distance: float) -> Dictionary:
	var ci := -1
	var bi := 0
	var best_d := INF
	for k in _chunks.size():
		var node: Node3D = _chunks[k]["node"]
		var local := node.to_local(world_pos)
		var rows: PackedVector3Array = _chunks[k]["rows_p"]
		for i in range(0, rows.size(), 4):
			var d := rows[i].distance_squared_to(local)
			if d < best_d:
				best_d = d
				ci = k
				bi = i
	if ci < 0:
		return {"found": false}
	var steps := int(round(distance / row_step))
	var i := bi
	while steps > 0:
		var n: int = (_chunks[ci]["rows_p"] as PackedVector3Array).size()
		var can := n - 1 - i
		if steps <= can:
			i += steps
			steps = 0
		else:
			steps -= can
			ci += 1
			i = 0
			if ci >= _chunks.size():
				return {"found": false}
	# Distance négative : on remonte la route (vers l'arrière).
	while steps < 0:
		if -steps <= i:
			i += steps
			steps = 0
		else:
			steps += i
			ci -= 1
			if ci < 0:
				return {"found": false}
			i = (_chunks[ci]["rows_p"] as PackedVector3Array).size() - 1
	var c: Dictionary = _chunks[ci]
	var node2: Node3D = c["node"]
	var right: Vector3 = (c["rows_r"] as PackedVector3Array)[i]
	return {
		"found": true, "chunk": node2, "i": i,
		"point": node2.to_global((c["rows_p"] as PackedVector3Array)[i]),
		"right": right, "dir": Vector3.UP.cross(right).normalized(),
		"s": (c["rows_s"] as PackedFloat32Array)[i],
	}


## Position monde du sol à `lateral` m de l'axe, au point renvoyé par sample_road/sample_ahead.
func ground_position(sample: Dictionary, lateral: float) -> Vector3:
	var p: Vector3 = sample["point"] + (sample["right"] as Vector3) * lateral
	var ax := absf(lateral)
	if ax <= road_half_width:
		p.y += -0.04 * (lateral / road_half_width) * (lateral / road_half_width)
	else:
		p.y += -0.04 + _terrain_height(p + world_offset, ax)
	return p


## Positions (monde) des nids-de-poule actuellement chargés : [{position, radius, depth}].
func get_potholes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in _chunks:
		var node: Node3D = c["node"]
		var rp: PackedVector3Array = c["rows_p"]
		var rr: PackedVector3Array = c["rows_r"]
		var rs: PackedFloat32Array = c["rows_s"]
		var ph: PackedFloat32Array = c["potholes"]
		for p in range(0, ph.size(), 6):
			var i := clampi(int(round((ph[p] - rs[0]) / row_step)), 0, rp.size() - 1)
			out.append({"position": node.to_global(rp[i] + rr[i] * ph[p + 1]), "radius": ph[p + 2], "depth": ph[p + 3]})
	return out


# --- Tracé --------------------------------------------------------------------

func _advance(ds: float) -> void:
	_k_left -= ds
	if _k_left <= 0.0:
		_k_left = _rng.randf_range(40.0, 150.0)
		if _s < straight_start or _rng.randf() < 0.3:
			_k_target = 0.0
		else:
			_k_target = _rng.randf_range(0.25, 1.0) / min_curve_radius * (1.0 if _rng.randf() < 0.5 else -1.0)
			# Ramener la route vers sa direction générale (pas de boucles).
			var err := wrapf(_wander - _heading, -PI, PI)
			if absf(err) > 0.7:
				_k_target = absf(_k_target) * signf(err)
	_k = move_toward(_k, _k_target, ds * 0.0004)
	_wander += _rng.randf_range(-1.0, 1.0) * 0.0004 * ds

	_grade_left -= ds
	if _grade_left <= 0.0:
		_grade_left = _rng.randf_range(60.0, 220.0)
		_grade_target = _rng.randf_range(-1.0, 1.0)   # petite variation propre à la route
	# La route suit le relief général : elle vise l'altitude du terrain 90 m plus loin,
	# avec une pente limitée (plus forte en montagne). Là où le relief est trop raide,
	# elle passe en tranchée ou en remblai, ou longe le versant.
	var g := 0.0
	if _s >= straight_start:
		var ahead := _pos + Vector3(sin(_heading), 0.0, cos(_heading)) * 90.0 + world_offset
		var mt := mountain_weight(_pos + world_offset)
		var gmax := lerpf(max_grade, max_grade_mountain, mt)
		# en montagne, la route s'élève par endroits au-dessus du fond de vallée et
		# longe les versants (corniches), au lieu de rester toujours tout en bas
		var perch := mt * 35.0 * (0.35 + _relief_noise.get_noise_2d(ahead.x * 2.7 + 91.0, ahead.z * 2.7))
		var follow := (relief(ahead) + perch - _pos.y) / 90.0
		g = clampf(follow + _grade_target * gmax * 0.3, -gmax, gmax)
		# rampe douce à la sortie de la ligne droite de départ
		g *= clampf((_s - straight_start) / 150.0, 0.0, 1.0)
	_grade = move_toward(_grade, g, ds * 0.0008)

	_heading += _k * ds
	_pos += Vector3(sin(_heading), _grade, cos(_heading)) * ds
	_s += ds


func _right() -> Vector3:
	return Vector3(-cos(_heading), 0.0, sin(_heading))


# --- Création d'un tronçon -----------------------------------------------------

func _queue_chunk(threaded: bool) -> Dictionary:
	var n := int(round(chunk_length / row_step))
	var rows_p := PackedVector3Array()
	var rows_r := PackedVector3Array()
	var rows_s := PackedFloat32Array()
	for i in n + 1:
		if i > 0:
			_advance(row_step)
		rows_p.append(_pos)
		rows_r.append(_right())
		rows_s.append(_s)
	_first_row = false
	# Le prochain tronçon repartira de la dernière rangée (pas de trou entre tronçons).

	# État de la route : alterne entre portions neuves et défoncées.
	if _rng.randf() < 0.25:
		_quality_target = clampf(_rng.randf() * (0.6 + generated_distance / degradation_distance), 0.0, 1.0)
	_quality = move_toward(_quality, _quality_target, 0.25)

	var feats := _make_features(rows_s[0], rows_s[n])
	var fields := _plan_fields(rows_s[0], rows_s[n], rows_p[n >> 1] + world_offset)
	var job := {
		"index": _chunk_index,
		"rows_p": rows_p, "rows_r": rows_r, "rows_s": rows_s,
		"potholes": feats["potholes"], "patches": feats["patches"], "bumps": feats["bumps"],
		"wear": _quality,
		"fields": fields,
		"offset": world_offset,
		"result": {},
	}
	_chunk_index += 1
	generated_distance += chunk_length
	if threaded:
		job["task"] = WorkerThreadPool.add_task(_build_chunk.bind(job), false, "Route")
		_pending.append(job)
	else:
		_build_chunk(job)
	return job


func _make_features(s0: float, s1: float) -> Dictionary:
	var potholes := PackedFloat32Array()   # s, x, rayon, profondeur, étirement, graine
	var patches := PackedFloat32Array()    # s0, s1, x0, x1
	var bumps := PackedFloat32Array()      # s, longueur, hauteur
	if s0 < maxf(straight_start * 0.5, straight_start - 60.0):   # départ sans défauts
		return {"potholes": potholes, "patches": patches, "bumps": bumps}
	var count := 0
	var expected := potholes_per_chunk * _quality
	while _rng.randf() < expected / (expected + 1.0) and count < 10:
		count += 1
		expected -= 1.0
		var s := _rng.randf_range(s0 + 1.5, s1 - 1.5)
		var side := 1.0 if _rng.randf() < 0.6 else -1.0
		var x := side * _rng.randf_range(0.5, lane_width - 0.4)
		var r := _rng.randf_range(0.3, 0.8)
		var depth := _rng.randf_range(0.06, 0.14) * (0.7 + 0.5 * _quality)
		potholes.append_array([s, x, r, depth, _rng.randf_range(0.7, 1.5), _rng.randf() * TAU])
		# Groupe de petits trous autour du premier.
		if _rng.randf() < 0.35:
			for k in _rng.randi_range(1, 3):
				potholes.append_array([s + _rng.randf_range(-1.5, 1.5), x + _rng.randf_range(-0.8, 0.8),
					r * _rng.randf_range(0.4, 0.7), depth * 0.8, _rng.randf_range(0.7, 1.4), _rng.randf() * TAU])
		# Rustine autour (réparation partielle).
		if _rng.randf() < 0.4:
			var pr := r + _rng.randf_range(0.4, 1.4)
			patches.append_array([s - pr * 1.4, s + pr * 1.4, x - pr, x + pr])
	# Rustines isolées.
	for k in int(_quality * 3.0 * _rng.randf()):
		var s := _rng.randf_range(s0 + 1.0, s1 - 4.0)
		var x := _rng.randf_range(-lane_width, lane_width - 1.0)
		patches.append_array([s, s + _rng.randf_range(1.0, 4.0), x, x + _rng.randf_range(0.6, 2.0)])
	# Dos-d'âne (pas trop près d'un nid-de-poule).
	if _rng.randf() < speed_bump_chance * (1.0 - 0.5 * _quality):
		bumps.append_array([(s0 + s1) * 0.5, 0.9, 0.075])
	return {"potholes": potholes, "patches": patches, "bumps": bumps}


## Altitude du relief général (m, même repère vertical que la route) à une position de
## l'espace du bruit. Collines douces en plaine ; en montagne, altitude plus haute,
## grandes pentes et arêtes.
func relief(world_pos: Vector3) -> float:
	var mt := mountain_weight(world_pos)
	var base := _relief_noise.get_noise_2d(world_pos.x, world_pos.z) * lerpf(relief_height, mountain_relief * 0.85, mt) - _relief0
	if mt <= 0.0:
		return base
	var ridge := 1.0 - absf(_relief_noise.get_noise_2d(world_pos.x * 2.3 + 517.0, world_pos.z * 2.3 - 211.0))
	return base + mt * mountain_relief * (0.45 + 0.55 * ridge * ridge)


## Hauteur du terrain hors de la route, relative au bord de la route.
## `world_xz.y` doit être l'altitude de la route à cette rangée (les appelants passent
## un point de la rangée décalé latéralement, donc à l'altitude de la route).
func _terrain_height(world_xz: Vector3, ax: float) -> float:
	if ax <= TERRAIN_COLS[3]:
		for k in range(1, 4):
			if ax <= TERRAIN_COLS[k]:
				var t: float = (ax - TERRAIN_COLS[k - 1]) / (TERRAIN_COLS[k] - TERRAIN_COLS[k - 1])
				return lerpf(TERRAIN_DROP[k - 1], TERRAIN_DROP[k], t)
	var hills := _noise.get_noise_2d(world_xz.x, world_xz.z) * terrain_height
	var small := _noise_small.get_noise_2d(world_xz.x, world_xz.z) * 0.35
	var blend := smoothstep(7.0, 28.0, ax)
	var h := TERRAIN_DROP[3] + (hills + small) * blend
	var mt := 0.0
	if ax > 9.0:
		mt = mountain_weight(world_xz)
		# rejoint le relief général : écart avec l'altitude de la route, borné pour
		# éviter des falaises de plus de 40 m sous la route
		var diff := clampf(relief(world_xz) - world_xz.y, -40.0, 90.0)
		h += diff * smoothstep(9.0, 50.0, ax)
		if ax > VALLEY_START:
			# rebord de vallée, sauf si la route domine déjà le terrain (vue dégagée)
			var rim := clampf(1.0 + diff / 15.0, 0.0, 1.0)
			var t := clampf((ax - VALLEY_START) / (TERRAIN_COLS[-1] - VALLEY_START), 0.0, 1.0)
			var vh := valley_hill_height * (0.45 + 1.1 * (0.5 + 0.5 * _valley_noise.get_noise_2d(world_xz.x, world_xz.z)))
			vh *= (1.0 - 0.4 * mt) * rim   # en montagne le relief fait déjà les versants
			h += vh * t * t * (1.6 - 0.6 * t)   # pente douce au pied, plus raide en haut
			# arêtes rocheuses en montagne
			h += mt * t * 9.0 * absf(_valley_noise.get_noise_2d(world_xz.x * 4.0, world_xz.z * 4.0))
	# montagne : terrain plus bosselé entre 20 et 45 m
	h += mt * smoothstep(20.0, 40.0, ax) * 2.2 * _noise_small.get_noise_2d(world_xz.x * 0.6, world_xz.z * 0.6)
	return h


## Calcul (thread) : maillage de la route + du terrain + faces de collision.
func _build_chunk(job: Dictionary) -> void:
	var rp: PackedVector3Array = job["rows_p"]
	var rr: PackedVector3Array = job["rows_r"]
	var rs: PackedFloat32Array = job["rows_s"]
	var potholes: PackedFloat32Array = job["potholes"]
	var patches: PackedFloat32Array = job["patches"]
	var bumps: PackedFloat32Array = job["bumps"]
	var wear: float = job["wear"]
	var offset: Vector3 = job["offset"]
	var n_rows := rp.size()
	var n_cols := int(round(road_half_width * 2.0 / lateral_step)) + 1

	# --- Route ------------------------------------------------------------------
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(n_rows * n_cols)
	colors.resize(n_rows * n_cols)
	uvs.resize(n_rows * n_cols)
	for i in n_rows:
		var s := rs[i]
		for j in n_cols:
			var x := -road_half_width + j * lateral_step
			var h := -0.04 * (x / road_half_width) * (x / road_half_width)   # bombement
			var hole := 0.0
			var patch := 0.0
			var bump := 0.0
			for p in range(0, potholes.size(), 6):
				var ds := s - potholes[p]
				var dx := x - potholes[p + 1]
				var r := potholes[p + 2]
				if absf(dx) > r * 1.3 or absf(ds) > r * potholes[p + 4] * 1.3:
					continue
				var a := atan2(dx, ds)
				var jag := 1.0 + 0.18 * sin(a * 5.0 + potholes[p + 5]) + 0.1 * sin(a * 9.0 + potholes[p + 5] * 2.0)
				var d := sqrt((ds / potholes[p + 4]) * (ds / potholes[p + 4]) + dx * dx) / (r * jag)
				if d < 1.0:
					h -= potholes[p + 3] * (1.0 - smoothstep(0.7, 1.0, d))   # bords francs
				hole = maxf(hole, 1.0 - smoothstep(0.85, 1.12, d))
			for p in range(0, patches.size(), 4):
				if s >= patches[p] and s <= patches[p + 1] and x >= patches[p + 2] and x <= patches[p + 3]:
					patch = 1.0
					h += 0.004
			for p in range(0, bumps.size(), 3):
				var db := s - bumps[p]
				if absf(db) < bumps[p + 1] * 0.5:
					var cb := cos(PI * db / bumps[p + 1])
					h += bumps[p + 2] * cb * cb
					bump = 1.0
			var idx := i * n_cols + j
			verts[idx] = rp[i] + rr[i] * x + Vector3(0.0, h, 0.0)
			colors[idx] = Color(hole, patch, bump, wear)
			uvs[idx] = Vector2(x, s)
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for i in n_rows:
		for j in n_cols:
			var l := verts[i * n_cols + maxi(j - 1, 0)]
			var r2 := verts[i * n_cols + mini(j + 1, n_cols - 1)]
			var b := verts[maxi(i - 1, 0) * n_cols + j]
			var f := verts[mini(i + 1, n_rows - 1) * n_cols + j]
			var nrm := (f - b).cross(r2 - l).normalized()
			if nrm.y < 0.0:
				nrm = -nrm
			normals[i * n_cols + j] = nrm
	var indices := PackedInt32Array()
	for i in n_rows - 1:
		for j in n_cols - 1:
			var a := i * n_cols + j
			var b := a + 1
			var c := a + n_cols
			var d := c + 1
			indices.append_array([a, c, b, b, c, d])
	# Collision de la route (même résolution que l'affichage), en 8 morceaux.
	var face_parts: Array[PackedVector3Array] = []
	var parts := 8
	var rows_per_part := int(ceil(float(n_rows - 1) / parts))
	for part in parts:
		var pf := PackedVector3Array()
		for i in range(part * rows_per_part, mini((part + 1) * rows_per_part, n_rows - 1)):
			for j in range(0, n_cols - 1):
				var j2 := j + 1
				var a := i * n_cols + j
				var b := i * n_cols + j2
				var c := a + n_cols
				var d := b + n_cols
				pf.append_array([verts[a], verts[c], verts[b], verts[b], verts[c], verts[d]])
		face_parts.append(pf)
	var faces := PackedVector3Array()
	var road_arrays := []
	road_arrays.resize(Mesh.ARRAY_MAX)
	road_arrays[Mesh.ARRAY_VERTEX] = verts
	road_arrays[Mesh.ARRAY_NORMAL] = normals
	road_arrays[Mesh.ARRAY_COLOR] = colors
	road_arrays[Mesh.ARRAY_TEX_UV] = uvs
	road_arrays[Mesh.ARRAY_INDEX] = indices

	# --- Terrain (facettes plates, couleurs par triangle) ---------------------
	var tcols: Array[float] = []
	for k in range(TERRAIN_COLS.size() - 1, -1, -1):
		tcols.append(-TERRAIN_COLS[k])
	for k in TERRAIN_COLS.size():
		tcols.append(TERRAIN_COLS[k])
	var row_ids: Array[int] = []
	for i in range(0, n_rows, 4):
		row_ids.append(i)
	if row_ids[-1] != n_rows - 1:
		row_ids.append(n_rows - 1)
	var grid: Array[PackedVector3Array] = []
	for i in row_ids:
		var line := PackedVector3Array()
		var edge_h := -0.04
		for x in tcols:
			var ax := absf(x)
			var p := rp[i] + rr[i] * x
			p.y += edge_h + _terrain_height(p + offset, ax)
			line.append(p)
		grid.append(line)
	var tverts := PackedVector3Array()
	var tnormals := PackedVector3Array()
	var tcolors := PackedColorArray()
	var half := TERRAIN_COLS.size()
	for gi in grid.size() - 1:
		for k in tcols.size() - 1:
			if k == half - 1:
				continue   # emplacement de la route
			var ax := absf((tcols[k] + tcols[k + 1]) * 0.5)
			# Haut des versants (> 56 m) : une rangée sur quatre. Des facettes de 1 m sur
			# 12 m donnaient des rayures ; 4 m × 12 m, c'est plus propre et moins lourd.
			var g1 := gi + 1
			if ax > COARSE_FROM:
				if gi % 4 != 0:
					continue
				g1 = mini(gi + 4, grid.size() - 1)
			var a := grid[gi][k]
			var b := grid[gi][k + 1]
			var c := grid[g1][k]
			var d := grid[g1][k + 1]
			for tri in [[a, c, b], [b, c, d]]:
				var v0: Vector3 = tri[0]
				var v1: Vector3 = tri[1]
				var v2: Vector3 = tri[2]
				var nrm := (v1 - v0).cross(v2 - v0).normalized()
				if nrm.y < 0.0:
					nrm = -nrm
				var centre := (v0 + v1 + v2) / 3.0 + offset
				var col: Color
				var field := _field_at(job["fields"], (rs[row_ids[gi]] + rs[row_ids[gi + 1]]) * 0.5, (tcols[k] + tcols[k + 1]) * 0.5)
				if field >= 0:
					var fg := 0.5 + 0.5 * _noise_small.get_noise_2d(centre.x * 0.7, centre.z * 0.7)
					col = (FIELD_SOIL[field] as Color).lerp(FIELD_SOIL[field] * 1.18, fg)
				elif ax < 4.7:
					col = Color(0.4, 0.38, 0.35) * (0.9 + 0.2 * _noise_small.get_noise_2d(centre.x * 3.0, centre.z * 3.0))
				else:
					# Même herbe partout (fossé compris) : couleur du biome, avec des taches.
					var bw := biome_weights(centre)
					col = _grass_color(centre, bw)
					if ax < 6.5:
						col = col.darkened(0.12)   # fossé : un peu plus sombre (humide), même teinte
					else:
						# pentes : herbe plus sombre puis terre/roche, en fondu (pas de seuil net,
						# qui faisait des rayures sur les versants)
						col = col.darkened(0.12 * smoothstep(0.95, 0.8, nrm.y))
						col = col.lerp(Color(0.35, 0.32, 0.27).lerp(Color(0.42, 0.41, 0.39), bw[3]), 0.55 * smoothstep(0.8, 0.6, nrm.y))
					# neige au-dessus d'une altitude (absolue) en montagne : sommets, et parfois
					# les abords de la route quand elle passe un col
					if bw[3] > 0.25 and ax > 6.5:
						var rel := (v0.y + v1.y + v2.y) / 3.0
						var line := snow_altitude + (1.0 - bw[3]) * 60.0 + 12.0 * _noise_small.get_noise_2d(centre.x * 0.05, centre.z * 0.05)
						if rel > line:
							# neige sur les pentes qui la retiennent, roche nue sur les parois
							col = Color(0.86, 0.88, 0.92) if nrm.y > 0.3 else Color(0.46, 0.46, 0.48)
						elif rel > line - 10.0 and nrm.y > 0.45:
							col = col.lerp(Color(0.8, 0.82, 0.86), 0.5)   # névés épars sous la limite
				# légère variation par facette ; sur les versants (facettes longues et fines),
				# par zones de 6 m pour éviter des rayures
				var jp := centre if ax <= 9.5 else (centre / 6.0).floor()
				col = col * (0.92 + 0.16 * fposmod(jp.x * 12.9898 + jp.z * 78.233, 1.0))
				for v in tri:
					tverts.append(v)
					tnormals.append(nrm)
					tcolors.append(col)
				if ax <= VALLEY_START:
					faces.append_array([v0, v1, v2])   # collisions des collines : grille grossière plus bas
	var terrain_arrays := []
	terrain_arrays.resize(Mesh.ARRAY_MAX)
	terrain_arrays[Mesh.ARRAY_VERTEX] = tverts
	terrain_arrays[Mesh.ARRAY_NORMAL] = tnormals
	terrain_arrays[Mesh.ARRAY_COLOR] = tcolors

	# Collision des collines (au-delà de 45 m) : une rangée sur quatre, assez précis pour
	# un véhicule qui s'y aventure et bien moins coûteux à créer.
	var coarse: Array[int] = []
	for gi in range(0, grid.size(), 4):
		coarse.append(gi)
	if coarse[-1] != grid.size() - 1:
		coarse.append(grid.size() - 1)
	for ci in coarse.size() - 1:
		var g0 := coarse[ci]
		var g1 := coarse[ci + 1]
		for k in tcols.size() - 1:
			if absf((tcols[k] + tcols[k + 1]) * 0.5) <= VALLEY_START:
				continue
			faces.append_array([grid[g0][k], grid[g1][k], grid[g0][k + 1], grid[g0][k + 1], grid[g1][k], grid[g1][k + 1]])
	face_parts.append(faces)   # terrain
	job["tgrid"] = grid
	job["trows"] = row_ids
	job["tcols"] = tcols
	_compute_fields(job)
	job["result"] = {"road": road_arrays, "terrain": terrain_arrays, "face_parts": face_parts}


## Thread principal : crée les noeuds du tronçon.
func _finalize(job: Dictionary) -> void:
	var res: Dictionary = job["result"]
	var t0 := Time.get_ticks_usec()
	var chunk := Node3D.new()
	chunk.name = "Chunk%d" % job["index"]
	add_child(chunk)
	# Si l'origine a été recentrée pendant le calcul, on compense.
	chunk.position = job["offset"] - world_offset

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, res["road"])
	mesh.surface_set_material(0, _road_mat)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, res["terrain"])
	mesh.surface_set_material(1, _terrain_mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	chunk.add_child(mi)
	var t1 := Time.get_ticks_usec()

	for pf in res["face_parts"]:
		_collision_queue.append({"chunk": chunk, "faces": pf})
	var t2 := Time.get_ticks_usec()

	var rp: PackedVector3Array = job["rows_p"]
	var rr: PackedVector3Array = job["rows_r"]
	var n := rp.size() - 1
	var end_dir := Vector3.UP.cross(rr[n])
	_spawn_props(chunk, job)
	_chunks.append({
		"node": chunk, "end": rp[n], "end_dir": end_dir.normalized(),
		"rows_p": rp, "rows_r": rr, "rows_s": job["rows_s"],
		"potholes": job["potholes"], "bumps": job["bumps"],
	})
	job["result"] = {}
	chunk_created.emit(job["index"])
	if debug_timings:
		print("Route : tronçon %d créé en %.1f ms (maillage %.1f, collision %.1f, décor %.1f)" % [job["index"], (Time.get_ticks_usec() - t0) / 1000.0, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (Time.get_ticks_usec() - t2) / 1000.0])


func _add_collision(chunk: Node3D, faces: PackedVector3Array) -> void:
	if faces.is_empty():
		return
	var body := StaticBody3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	chunk.add_child(body)


func _spawn_props(chunk: Node3D, job: Dictionary) -> void:
	var rp: PackedVector3Array = job["rows_p"]
	var rr: PackedVector3Array = job["rows_r"]
	var rs: PackedFloat32Array = job["rows_s"]
	var offset: Vector3 = job["offset"]
	var n := rp.size() - 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(job["index"]) ^ _noise.seed

	# Chalet (montagne, parfois prairie) : choisi avant la végétation pour qu'elle l'évite
	_plan_chalet(job, rng)

	# Végétation et rochers (arbres, buissons, herbes, rochers) selon le biome
	_spawn_nature(chunk, job, rng)
	_spawn_chalet(chunk, job)

	# Champs cultivés (blé, colza, tournesols, lavande, labours, chaume + bottes de foin)
	_spawn_fields(chunk, job)

	# Camion en panne sur l'accotement
	if truck_scene and job["index"] > 3 and rng.randf() < broken_truck_chance:
		var i := rng.randi_range(n >> 2, (3 * n) >> 2)
		var right := rr[i]
		var fwd := Vector3.UP.cross(right)
		var truck := truck_scene.instantiate() as Node3D
		truck.transform = Transform3D(Basis(-right, Vector3.UP, fwd.normalized()), rp[i] + right * 5.4 + Vector3(0, -0.06, 0))
		var tb := StaticBody3D.new()
		var tcs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.5, 3.3, 8.2)
		tcs.shape = box
		tcs.position.y = 1.75
		tb.add_child(tcs)
		truck.add_child(tb)
		chunk.add_child(truck)

	# Bornes réfléchissantes
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _post_mesh
	var xforms: Array[Transform3D] = []
	for i in n + 1:
		var s := rs[i]
		if i > 0 and floor(s / post_spacing) != floor(rs[i - 1] / post_spacing):
			for side in [-1.0, 1.0]:
				var p: Vector3 = rp[i] + rr[i] * (5.0 * side)
				p.y += -0.04 + _terrain_height(p + offset, 5.0) + 0.5
				xforms.append(Transform3D(Basis.IDENTITY, p))
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
	if xforms.size() > 0:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		chunk.add_child(mmi)


# --- Végétation ------------------------------------------------------------------
# Chaque espèce : modèle low poly (props/nature/*.glb), catégorie, poids dans chaque
# biome [forêt de sapins, bois mixte, prairie], échelle, collision (rayon, hauteur).
# Le rendu passe par un MultiMesh par espèce et par tronçon ; les collisions des
# arbres et des gros rochers sont regroupées dans un seul StaticBody3D par tronçon.

const NATURE_SPECIES := [
	# nom,           catégorie, poids [sapins, mixte, prairie, montagne], échelle, rayon, hauteur collision
	["pine_tall",    "tree",   [5.0, 1.5, 0.2, 2.0], Vector2(0.8, 1.3), 0.22, 4.0],
	["pine_small",   "tree",   [4.0, 1.5, 0.5, 2.0], Vector2(0.7, 1.3), 0.14, 3.0],
	["tree_oak",     "tree",   [0.4, 3.0, 1.0, 0.0], Vector2(0.75, 1.3), 0.30, 4.0],
	["tree",         "tree",   [0.3, 2.5, 1.0, 0.0], Vector2(0.7, 1.3), 0.28, 3.0],
	["tree_autumn",  "tree",   [0.2, 2.0, 1.0, 0.0], Vector2(0.8, 1.25), 0.22, 3.0],
	["birch",        "tree",   [1.0, 2.5, 0.8, 0.3], Vector2(0.8, 1.3), 0.14, 3.0],
	["poplar",       "tree",   [0.0, 1.0, 1.5, 0.0], Vector2(0.85, 1.3), 0.16, 3.0],
	["tree_dead",    "tree",   [0.6, 0.5, 0.4, 0.6], Vector2(0.8, 1.3), 0.18, 3.0],
	["bush_round",   "bush",   [1.0, 3.0, 3.0, 0.3], Vector2(0.7, 1.4), 0.0, 0.0],
	["bush_flowers", "bush",   [0.0, 1.0, 4.0, 0.0], Vector2(0.7, 1.3), 0.0, 0.0],
	["bush_yellow",  "bush",   [0.3, 1.0, 3.0, 0.0], Vector2(0.7, 1.3), 0.0, 0.0],
	["bush_berries", "bush",   [1.0, 2.0, 1.0, 0.6], Vector2(0.7, 1.3), 0.0, 0.0],
	["fern",         "bush",   [5.0, 2.0, 0.3, 1.0], Vector2(0.8, 1.5), 0.0, 0.0],
	["grass_tuft",   "ground", [1.0, 3.0, 6.0, 0.5], Vector2(0.8, 1.6), 0.0, 0.0],
	["grass_dry",    "ground", [0.5, 2.0, 4.0, 1.0], Vector2(0.8, 1.5), 0.0, 0.0],
	["rock_pebbles", "ground", [1.0, 1.0, 1.0, 2.0], Vector2(0.8, 1.6), 0.0, 0.0],
	["rock_boulder", "rock",   [2.0, 1.0, 0.6, 2.0], Vector2(0.6, 1.8), 0.6, 1.2],
	["rock_flat",    "rock",   [1.0, 1.0, 1.0, 1.0], Vector2(0.7, 1.6), 0.7, 0.5],
	["rock_cluster", "rock",   [1.5, 1.0, 0.4, 1.5], Vector2(0.7, 1.5), 0.6, 0.9],
	["rock_mossy",   "rock",   [2.5, 1.0, 0.4, 1.0], Vector2(0.6, 1.6), 0.75, 1.2],
	["stump",        "rock",   [1.5, 0.8, 0.3, 0.5], Vector2(0.8, 1.3), 0.3, 0.5],
	["flower_daisy",      "flower", [0.3, 2.0, 4.0, 0.2], Vector2(0.8, 1.4), 0.0, 0.0],
	["flower_poppy",      "flower", [0.1, 1.2, 3.0, 0.0], Vector2(0.8, 1.3), 0.0, 0.0],
	["flower_cornflower", "flower", [0.1, 1.0, 2.5, 0.0], Vector2(0.8, 1.3), 0.0, 0.0],
	["flower_lupin",      "flower", [0.6, 1.5, 2.0, 0.6], Vector2(0.8, 1.4), 0.0, 0.0],
	["flower_dandelion",  "flower", [0.3, 2.0, 3.0, 0.5], Vector2(0.8, 1.4), 0.0, 0.0],
	# montagne
	["spruce",        "tree",   [1.0, 0.2, 0.0, 6.0], Vector2(0.75, 1.3), 0.2, 4.0],
	["larch",         "tree",   [0.3, 0.3, 0.0, 3.0], Vector2(0.75, 1.25), 0.18, 4.0],
	["grass_alpine",  "ground", [0.0, 0.0, 0.0, 6.0], Vector2(0.8, 1.6), 0.0, 0.0],
	["rock_cliff",    "rock",   [0.0, 0.0, 0.0, 3.0], Vector2(0.6, 1.4), 1.5, 3.2],
	["rock_snowy",    "rock",   [0.0, 0.0, 0.0, 2.0], Vector2(0.6, 1.3), 1.0, 1.8],
	["scree",         "rock",   [0.2, 0.0, 0.0, 3.0], Vector2(0.7, 1.5), 0.0, 0.0],
	["flower_alpine", "flower", [0.0, 0.0, 0.0, 6.0], Vector2(0.8, 1.5), 0.0, 0.0],
]
## Nombre d'éléments par tronçon de 40 m et par biome [sapins, mixte, prairie, montagne].
const NATURE_COUNTS := {
	"tree":   [Vector2i(14, 24), Vector2i(7, 14), Vector2i(1, 4), Vector2i(6, 12)],
	"bush":   [Vector2i(8, 14), Vector2i(10, 18), Vector2i(10, 20), Vector2i(2, 5)],
	"ground": [Vector2i(20, 35), Vector2i(30, 50), Vector2i(50, 80), Vector2i(25, 40)],
	"rock":   [Vector2i(4, 8), Vector2i(2, 5), Vector2i(1, 3), Vector2i(6, 12)],
	"flower": [Vector2i(1, 3), Vector2i(4, 8), Vector2i(8, 14), Vector2i(5, 10)],   # massifs de 3 à 7 fleurs
}
## Distance à l'axe de la route (m) : [min, max] par catégorie.
const NATURE_RANGE := {"tree": Vector2(9.0, 43.0), "bush": Vector2(7.0, 43.0), "ground": Vector2(6.0, 43.0), "rock": Vector2(7.5, 43.0), "flower": Vector2(5.5, 43.0)}


func _setup_nature() -> void:
	_biome_noise.seed = _rng.randi()
	_tint_noise.seed = _rng.randi()
	_tint_noise.frequency = 1.0 / 80.0
	_biome_noise.frequency = 1.0 / maxf(biome_size, 50.0)
	_mountain_noise.seed = _rng.randi()
	_mountain_noise.frequency = 1.0 / maxf(mountain_size, 100.0)
	_mountain_noise.fractal_octaves = 2
	_nature.clear()
	for sp in NATURE_SPECIES:
		var m := _nature_mesh(sp[0])
		if m.is_empty():
			continue
		_nature.append({"name": sp[0], "cat": sp[1], "w": sp[2], "scale": sp[3], "radius": sp[4], "height": sp[5], "mesh": m["mesh"], "mesh_xf": m["xf"]})
	for ft in FIELD_CROPS:
		_nature_mesh(ft["mesh"])
	for extra in ["hay_bale", "fence_wood", "chalet"]:
		_nature_mesh(extra)


# --- Champs cultivés ---------------------------------------------------------------
# Le bord de la route est découpé en parcelles de FIELD_LEN m de chaque côté (décalées
# d'une demi-parcelle entre la gauche et la droite). Chaque parcelle peut devenir un
# champ, surtout en prairie. Un champ couvre de FIELD_X.x à FIELD_X.y m de l'axe, en
# deux bandes (avant/arrière de FIELD_SPLIT) qui peuvent porter deux cultures.
# Les limites tombent sur des colonnes du terrain (13, 25, 45 m), ce qui permet de
# colorer exactement le sol sous chaque culture.
const FIELD_LEN := 120.0
const FIELD_X := Vector2(13.0, 45.0)
const FIELD_SPLIT := 25.0
const FIELD_GAP := 6.0   # bande d'herbe entre deux champs (m, le long de la route)
## Cultures : modèle, espacement des rangs (m), longueur d'un morceau de rang (m),
## élargissement du modèle (wx, pour que les rangs se touchent), poids, ombre.
const FIELD_CROPS := [
	{"name": "blé",        "mesh": "crop_wheat",     "row": 0.8, "seg": 2.0, "wx": 1.9, "w": 3.0, "shadow": true},
	{"name": "colza",      "mesh": "crop_colza",     "row": 0.85, "seg": 2.0, "wx": 1.6, "w": 2.0, "shadow": true},
	{"name": "tournesols", "mesh": "crop_sunflower", "row": 1.0, "seg": 1.5, "w": 1.5, "shadow": true},
	{"name": "lavande",    "mesh": "crop_lavender",  "row": 1.5, "seg": 1.8, "w": 1.0, "shadow": true},
	{"name": "labour",     "mesh": "furrow",         "row": 0.7, "seg": 4.0, "w": 1.5, "shadow": false},
	{"name": "chaume",     "mesh": "stubble",        "row": 0.7, "seg": 4.0, "w": 1.5, "shadow": false},
]
## Couleur du sol sous chaque culture (même ordre que FIELD_CROPS).
const FIELD_SOIL := [
	Color(0.42, 0.33, 0.13), Color(0.16, 0.30, 0.08), Color(0.27, 0.19, 0.11),
	Color(0.30, 0.24, 0.17), Color(0.22, 0.14, 0.08), Color(0.52, 0.44, 0.22),
]


## Plans des champs touchant [s0, s1] (créés au besoin, dans le thread principal).
## `noise_pos` : position (espace du bruit) servant à choisir selon le biome.
func _plan_fields(s0: float, s1: float, noise_pos: Vector3) -> Array:
	var out := []
	var bw := biome_weights(noise_pos)
	for side in [-1, 1]:
		var shift := FIELD_LEN * 0.5 if side > 0 else 0.0
		for fid in range(int(floor((s0 + shift) / FIELD_LEN)), int(floor((s1 + shift) / FIELD_LEN)) + 1):
			var key := Vector2i(fid, side)
			if not _field_plans.has(key):
				var r := RandomNumberGenerator.new()
				r.seed = hash(Vector3i(fid, side, _noise.seed))
				var start := fid * FIELD_LEN - shift
				var chance := clampf(bw[2] * 0.85 + bw[1] * 0.3, 0.0, 0.85) * field_chance * (1.0 - bw[3])
				var plan := {"side": side, "s0": start + FIELD_GAP * 0.5, "s1": start + FIELD_LEN - FIELD_GAP * 0.5,
					"near": -1, "far": -1, "fence": false}
				if start > straight_start * 0.6 and r.randf() < chance:
					plan["near"] = _pick_crop(r)
					var x := r.randf()
					plan["far"] = plan["near"] if x < 0.5 else (-1 if x < 0.62 else _pick_crop(r))
					plan["fence"] = r.randf() < 0.5
				_field_plans[key] = plan
			var pl: Dictionary = _field_plans[key]
			if pl["near"] >= 0 or pl["far"] >= 0:
				out.append(pl)
	# oubli des vieux plans
	if _field_plans.size() > 64:
		for key in _field_plans.keys():
			if _field_plans[key]["s1"] < s0 - 2000.0:
				_field_plans.erase(key)
	return out


func _pick_crop(r: RandomNumberGenerator) -> int:
	var total := 0.0
	for c in FIELD_CROPS:
		total += c["w"]
	var pick := r.randf() * total
	for k in FIELD_CROPS.size():
		pick -= FIELD_CROPS[k]["w"]
		if pick <= 0.0:
			return k
	return 0


## Culture à l'abscisse curviligne s et à la distance signée x de l'axe (-1 = pas de champ).
## Fonction pure (utilisable dans le thread de calcul).
static func _field_at(fields: Array, s: float, x: float) -> int:
	var ax := absf(x)
	if ax < FIELD_X.x or ax > FIELD_X.y:
		return -1
	var side := 1 if x > 0.0 else -1
	for f in fields:
		if f["side"] == side and s >= f["s0"] and s <= f["s1"]:
			return f["near"] if ax < FIELD_SPLIT else f["far"]
	return -1


## Hauteur exacte du terrain à facettes à la rangée i, distance signée x (repère du tronçon).
func _ground_y(job: Dictionary, i: int, x: float) -> float:
	var grid: Array = job["tgrid"]
	var trows: Array = job["trows"]
	var tcols: Array = job["tcols"]
	var gi := 0
	while gi < trows.size() - 2 and i > trows[gi + 1]:
		gi += 1
	var v := clampf(float(i - trows[gi]) / float(trows[gi + 1] - trows[gi]), 0.0, 1.0)
	var k := 0
	while k < tcols.size() - 2 and x > tcols[k + 1]:
		k += 1
	var u := clampf((x - tcols[k]) / (tcols[k + 1] - tcols[k]), 0.0, 1.0)
	var a: float = grid[gi][k].y
	var b: float = grid[gi][k + 1].y
	var c: float = grid[gi + 1][k].y
	var d: float = grid[gi + 1][k + 1].y
	if u + v <= 1.0:
		return a + u * (b - a) + v * (c - a)
	return d + (1.0 - u) * (c - d) + (1.0 - v) * (b - d)


## Calcul des cultures (dans le thread du tronçon, après le terrain) : prépare pour chaque
## modèle le tampon brut du MultiMesh (12 flottants de transformation + 4 de couleur
## par instance) et la liste des bottes de foin. Le thread principal n'a plus qu'à
## créer les nœuds (_spawn_fields), ce qui évitait des à-coups de 10 à 20 ms.
func _compute_fields(job: Dictionary) -> void:
	var fields: Array = job["fields"]
	var out := {"buffers": {}, "bales": []}
	job["field_result"] = out
	if fields.is_empty() or not job.has("tgrid"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(job["index"] * 7919) ^ _noise.seed
	var rp: PackedVector3Array = job["rows_p"]
	var rr: PackedVector3Array = job["rows_r"]
	var rs: PackedFloat32Array = job["rows_s"]
	var offset: Vector3 = job["offset"]
	var n := rp.size() - 1
	var bw := biome_weights(rp[n >> 1] + offset)
	var acc := {}   # nom de modèle -> Array [Transform3D, Color, Transform3D, Color, ...]
	var add := func(mname: String, i: int, x: float, yaw: float, sc: Vector3, tint: Color) -> void:
		var m: Dictionary = _mesh_cache.get(mname, {})
		if m.is_empty():
			return
		var right := rr[i]
		var fwd := Vector3.UP.cross(right).normalized()
		var p := rp[i] + right * x
		p.y = _ground_y(job, i, x)   # hauteur exacte du sol à facettes
		var b := Basis(right, Vector3.UP, fwd).rotated(Vector3.UP, yaw) * Basis.from_scale(sc)
		var t := Transform3D(b, p) * (m["xf"] as Transform3D)
		if not acc.has(mname):
			acc[mname] = []
		acc[mname].append(t)
		acc[mname].append(tint)
	for f in fields:
		var side: int = f["side"]
		for band in 2:
			var crop: int = f["near"] if band == 0 else f["far"]
			if crop < 0:
				continue
			var cd: Dictionary = FIELD_CROPS[crop]
			var x0 := FIELD_X.x + 0.5 if band == 0 else FIELD_SPLIT + 0.4
			var x1 := FIELD_SPLIT - 0.4 if band == 0 else FIELD_X.y - 1.0
			var spacing: float = cd["row"]
			var stride := maxi(1, int(round(cd["seg"] / row_step)))
			var half_seg: float = cd["seg"] * 0.5
			var rows := int((x1 - x0) / spacing)
			for j in rows:
				var ax := x0 + spacing * (j + 0.5)
				var x := ax * side
				# rangs décalés d'un demi-morceau un sur deux, phase calée sur s (continuité entre tronçons)
				var phase := (j % 2) * (stride >> 1)
				for i in n + 1:
					if (int(round(rs[i] / row_step)) + phase) % stride != 0:
						continue
					if rs[i] < f["s0"] + half_seg or rs[i] > f["s1"] - half_seg:
						continue
					var tint := _nature_tint(rp[i] + rr[i] * x + offset, bw, rng)
					var sc := Vector3(rng.randf_range(0.92, 1.08) * cd.get("wx", 1.0), rng.randf_range(0.88, 1.1), 1.0)
					add.call(cd["mesh"], i, x + rng.randf_range(-0.06, 0.06), rng.randf_range(-0.03, 0.03), sc, tint)
					# coquelicots dans le blé
					if crop == 0 and rng.randf() < 0.025:
						add.call("flower_poppy", mini(i + rng.randi_range(-2, 2), n), x + rng.randf_range(-0.4, 0.4) * side,
							rng.randf() * TAU, Vector3.ONE * rng.randf_range(1.0, 1.4), Color(0.5, 0.5, 0.5, 0.0))
			# bottes de foin sur le chaume
			if crop == 5:
				for b in rng.randi_range(1, 4):
					var i := rng.randi_range(0, n)
					if rs[i] < f["s0"] + 2.0 or rs[i] > f["s1"] - 2.0:
						continue
					var x := rng.randf_range(x0 + 1.0, x1 - 1.0) * side
					var yaw := rng.randf() * TAU
					add.call("hay_bale", i, x, yaw, Vector3.ONE * rng.randf_range(0.9, 1.1), _nature_tint(rp[i] + offset, bw, rng))
					var right := rr[i]
					var fwd := Vector3.UP.cross(right).normalized()
					out["bales"].append(Transform3D(Basis(right, Vector3.UP, fwd).rotated(Vector3.UP, yaw),
						Vector3(rp[i].x, 0.0, rp[i].z) + right * x + Vector3(0, _ground_y(job, i, x) + 0.6, 0)))
		# clôture côté route, et fleurs le long du champ
		if f["near"] >= 0:
			var fstride := int(round(3.0 / row_step))
			for i in n + 1:
				var si := int(round(rs[i] / row_step))
				if rs[i] < f["s0"] + 1.5 or rs[i] > f["s1"] - 1.5:
					continue
				if f["fence"] and si % fstride == 0:
					add.call("fence_wood", i, (FIELD_X.x - 0.3) * side, 0.0, Vector3.ONE, _nature_tint(rp[i] + offset, bw, rng))
				if f["near"] != 4 and si % 6 == 0 and rng.randf() < 0.35:
					var fl: String = ["flower_poppy", "flower_daisy", "flower_cornflower"][rng.randi_range(0, 2)]
					add.call(fl, i, rng.randf_range(FIELD_X.x - 0.9, FIELD_X.x + 0.2) * side, rng.randf() * TAU,
						Vector3.ONE * rng.randf_range(0.9, 1.3), _nature_tint(rp[i] + offset, bw, rng))

	# tampons bruts des MultiMesh (format TRANSFORM_3D + custom data : 16 flottants)
	for mname in acc:
		var items: Array = acc[mname]
		var cnt := items.size() >> 1
		var buf := PackedFloat32Array()
		buf.resize(cnt * 16)
		for j in cnt:
			var t: Transform3D = items[2 * j]
			var c: Color = items[2 * j + 1]
			var o := j * 16
			buf[o] = t.basis.x.x; buf[o + 1] = t.basis.y.x; buf[o + 2] = t.basis.z.x; buf[o + 3] = t.origin.x
			buf[o + 4] = t.basis.x.y; buf[o + 5] = t.basis.y.y; buf[o + 6] = t.basis.z.y; buf[o + 7] = t.origin.y
			buf[o + 8] = t.basis.x.z; buf[o + 9] = t.basis.y.z; buf[o + 10] = t.basis.z.z; buf[o + 11] = t.origin.z
			buf[o + 12] = c.r; buf[o + 13] = c.g; buf[o + 14] = c.b; buf[o + 15] = c.a
		out["buffers"][mname] = buf


## Création des nœuds des champs (thread principal) à partir de _compute_fields.
func _spawn_fields(chunk: Node3D, job: Dictionary) -> void:
	if not job.has("field_result"):
		return
	var res: Dictionary = job["field_result"]
	for t in res["bales"]:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.15, 1.2, 1.2)
		cs.shape = box
		cs.transform = t
		_nature_body(chunk).add_child(cs)
	var acc: Dictionary = res["buffers"]
	for mname in acc:
		var buf: PackedFloat32Array = acc[mname]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = _nature_mesh(mname)["mesh"]
		mm.instance_count = buf.size() >> 4
		mm.buffer = buf
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Field_" + mname
		mmi.multimesh = mm
		mmi.visibility_range_end = 340.0
		if mname in ["furrow", "stubble"] or mname.begins_with("flower"):
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mname.begins_with("flower"):
			mmi.visibility_range_end = 140.0
		chunk.add_child(mmi)


## Modèle de décor (props/nature/<nom>.glb, ou tree_scene pour "tree") avec le shader
## de variation de couleur. Résultat mis en cache : {mesh, xf}, vide si introuvable.
func _nature_mesh(mname: String) -> Dictionary:
	if _mesh_cache.has(mname):
		return _mesh_cache[mname]
	var res := {}
	var scene: PackedScene = tree_scene if mname == "tree" else load("res://props/nature/%s.glb" % mname)
	if scene == null:
		push_warning("Route : modèle introuvable pour %s" % mname)
	else:
		var inst := scene.instantiate()
		for c in inst.find_children("*", "MeshInstance3D", true, false):
			res = {"mesh": _tinted_mesh(c as MeshInstance3D), "xf": (c as MeshInstance3D).transform}
			break
		inst.free()
	_mesh_cache[mname] = res
	return res


## Copie du maillage où chaque surface reçoit le shader de variation de couleur,
## réglé selon le type de matériau (feuillage, herbe, écorce, roche, fleur).
func _tinted_mesh(mi: MeshInstance3D) -> Mesh:
	var src := mi.mesh
	if not (src is ArrayMesh) or nature_color_variation <= 0.0:
		return src
	var mesh: ArrayMesh = src.duplicate()
	var v := nature_color_variation
	for si in mesh.get_surface_count():
		var orig := mi.get_active_material(si)
		var std := orig as BaseMaterial3D
		if std == null:
			continue
		var col := std.albedo_color
		var mname := orig.resource_name.to_lower()
		# hue, sat, val, dry, face
		var t := [0.03, 0.15, 0.15, 0.0, 0.07]
		if mname.begins_with("crop"):
			t = [0.025, 0.15, 0.08, 0.0, 0.06]   # cultures : un champ reste homogène
		elif mname.contains("soil") or mname.contains("straw"):
			t = [0.015, 0.15, 0.1, 0.0, 0.06]
		elif mname.contains("grass"):
			t = [0.045, 0.25, 0.2, 0.75, 0.1]
		elif mname.contains("leaves") or mname.contains("needles") or mname.contains("bush") \
				or mname.contains("fern") or mname.contains("moss"):
			t = [0.04, 0.22, 0.18, 0.45, 0.09]
			if mname.contains("orange") or mname.contains("red") or mname.contains("yellow"):
				t = [0.035, 0.2, 0.18, 0.15, 0.09]   # feuillage d'automne : déjà « sec »
			elif mname.contains("needles"):
				t[3] = 0.25   # les sapins jaunissent moins
		elif mname.contains("bark") or mname.contains("wood") or mname.contains("birch_mark"):
			t = [0.015, 0.2, 0.2, 0.0, 0.06]
		elif mname.contains("rock"):
			t = [0.04, 0.4, 0.15, 0.0, 0.08]
		elif mname.contains("flower") or mname.contains("berry"):
			t = [0.06, 0.15, 0.12, 0.0, 0.05]
		elif col.g > col.r and col.g > col.b:
			t = [0.04, 0.22, 0.18, 0.45, 0.09]   # matériau vert inconnu → feuillage
		var mat := ShaderMaterial.new()
		mat.shader = NATURE_TINT_SHADER
		mat.set_shader_parameter("base_color", col)
		mat.set_shader_parameter("roughness_value", std.roughness)
		mat.set_shader_parameter("hue_amount", t[0] * v)
		mat.set_shader_parameter("sat_amount", t[1] * v)
		mat.set_shader_parameter("val_amount", t[2] * v)
		mat.set_shader_parameter("dry_amount", t[3] * v)
		mat.set_shader_parameter("face_amount", t[4] * v)
		mesh.surface_set_material(si, mat)
	return mesh


## Couleur aléatoire d'une instance (encodée 0..1 pour INSTANCE_CUSTOM) :
## un tirage propre à l'instance mélangé à des taches d'environ 80 m, pour que
## les voisins se ressemblent un peu (bosquets plus jaunes, rochers plus chauds...).
func _nature_tint(world_pos: Vector3, bw: Array, rng: RandomNumberGenerator) -> Color:
	var n1 := _tint_noise.get_noise_2d(world_pos.x, world_pos.z)
	var n2 := _tint_noise.get_noise_2d(world_pos.x + 913.0, world_pos.z - 377.0)
	var hue := clampf(0.5 + n1 * 0.45 + rng.randf_range(-0.3, 0.3), 0.0, 1.0)
	var sat := clampf(0.5 + n2 * 0.3 + rng.randf_range(-0.35, 0.35), 0.0, 1.0)
	var val := clampf(0.5 + rng.randf_range(-0.5, 0.5), 0.0, 1.0)
	var dry := clampf(0.1 + 0.4 * float(bw[2]) - 0.1 * float(bw[0]) + 0.55 * maxf(n2, 0.0) \
			+ rng.randf_range(-0.15, 0.25), 0.0, 1.0)
	return Color(hue, sat, val, dry)


## Décide s'il y a un chalet sur ce tronçon (surtout en montagne) et où.
func _plan_chalet(job: Dictionary, rng: RandomNumberGenerator) -> void:
	if (_mesh_cache.get("chalet", {}) as Dictionary).is_empty() or job["index"] < 6:
		return
	var rp: PackedVector3Array = job["rows_p"]
	var rs: PackedFloat32Array = job["rows_s"]
	var n := rp.size() - 1
	var bw := biome_weights(rp[n >> 1] + job["offset"])
	if rng.randf() > 0.14 * bw[3] + 0.03 * bw[2]:
		return
	var i := rng.randi_range(int(n * 0.2), int(n * 0.8))
	var x := rng.randf_range(20.0, 36.0) * (1.0 if rng.randf() < 0.5 else -1.0)
	if _field_at(job["fields"], rs[i], x) >= 0:
		return
	job["chalet"] = {"i": i, "x": x}


func _spawn_chalet(chunk: Node3D, job: Dictionary) -> void:
	if not job.has("chalet"):
		return
	var ch: Dictionary = job["chalet"]
	var m: Dictionary = _nature_mesh("chalet")
	var rp: PackedVector3Array = job["rows_p"]
	var rr: PackedVector3Array = job["rows_r"]
	var i: int = ch["i"]
	var x: float = ch["x"]
	var side := 1.0 if x > 0.0 else -1.0
	var right := rr[i]
	var toward := -right * side                       # du chalet vers la route
	# point le plus bas sous l'emprise (le soubassement enterré rattrape la pente)
	var y := INF
	for di in [-12, 0, 12]:
		for dx in [-3.0, 0.0, 3.0]:
			y = minf(y, _ground_y(job, clampi(i + di, 0, rp.size() - 1), x + dx))
	var pos := rp[i] + right * x
	pos.y = y + 0.05
	# façade (+Y dans Blender = -Z dans Godot) tournée vers la route
	var z_axis := -toward
	var basis_c := Basis(Vector3.UP.cross(z_axis).normalized(), Vector3.UP, z_axis)
	var mi := MeshInstance3D.new()
	mi.name = "Chalet"
	mi.mesh = m["mesh"]
	mi.transform = Transform3D(basis_c, pos) * (m["xf"] as Transform3D)
	chunk.add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.4, 5.0, 5.4)
	cs.shape = box
	cs.transform = Transform3D(basis_c, pos + Vector3(0, 2.0, 0))
	_nature_body(chunk).add_child(cs)


## Couleur de l'herbe du terrain à cet endroit (espace du bruit), selon le biome.
## Utilisée pour toute l'herbe (fossés, abords, champs non cultivés, collines) afin que
## la teinte reste cohérente de la route jusqu'aux versants.
func _grass_color(centre: Vector3, bw: Array) -> Color:
	var g := 0.5 + 0.5 * _noise_small.get_noise_2d(centre.x * 0.5, centre.z * 0.5)
	var big := 0.5 + 0.5 * _tint_noise.get_noise_2d(centre.x * 0.5, centre.z * 0.5)   # grandes taches (~160 m)
	var mixed := Color(0.17, 0.36, 0.11).lerp(Color(0.32, 0.42, 0.15), g)
	var forest := Color(0.13, 0.25, 0.10).lerp(Color(0.24, 0.22, 0.13), g * 0.6)
	var meadow := Color(0.30, 0.50, 0.16).lerp(Color(0.48, 0.52, 0.20), g)
	var alpine := Color(0.25, 0.36, 0.15).lerp(Color(0.42, 0.42, 0.24), g)
	# montagne : plaques de rocaille grise dans l'herbe rase
	var rocky := smoothstep(0.55, 0.75, 0.5 + 0.5 * _noise_small.get_noise_2d(centre.x * 0.9 + 37.0, centre.z * 0.9))
	alpine = alpine.lerp(Color(0.42, 0.41, 0.38), rocky * 0.8)
	var col := mixed * float(bw[1]) + forest * float(bw[0]) + meadow * float(bw[2]) + alpine * float(bw[3])
	return col.lerp(col * Color(1.08, 1.04, 0.85), big * 0.35)   # variation lente, légèrement plus jaune


## Espèce d'arbre (nom de modèle) tirée selon le biome à cette position globale,
## avec les mêmes poids que les arbres du décor. Sert aux arbres qui tombent.
func pick_tree_species(global_pos: Vector3) -> String:
	var bw := get_biome_at(global_pos)
	var names: Array[String] = []
	var weights: Array[float] = []
	var total := 0.0
	for sp in _nature:
		if sp["cat"] != "tree":
			continue
		var w := 0.0
		for b in 4:
			w += bw[b] * float(sp["w"][b])
		if w > 0.0:
			names.append(sp["name"])
			weights.append(w)
			total += w
	if names.is_empty():
		return "tree"
	var pick := randf() * total
	for i in names.size():
		pick -= weights[i]
		if pick <= 0.0:
			return names[i]
	return names[-1]


## Biome à une position globale de la scène : [forêt de sapins, bois mixte, prairie].
func get_biome_at(global_pos: Vector3) -> Array[float]:
	return biome_weights(to_local(global_pos) + world_offset)


## Poids des 4 biomes (somme = 1) : [forêt de sapins, bois mixte, prairie, montagne].
## La montagne vient d'un second bruit, plus lent (`mountain_size`) : de grandes régions
## montagneuses qui recouvrent les trois autres biomes.
## `world_pos` est dans l'espace du bruit du terrain (position locale du générateur + world_offset).
func biome_weights(world_pos: Vector3) -> Array[float]:
	var v := _biome_noise.get_noise_2d(world_pos.x, world_pos.z)
	var forest := smoothstep(0.0, 0.3, -v)
	var meadow := smoothstep(0.0, 0.3, v)
	var mixed := clampf(1.0 - forest - meadow, 0.0, 1.0)
	var sum := forest + mixed + meadow
	var mt := mountain_weight(world_pos)
	var k := (1.0 - mt) / sum
	return [forest * k, mixed * k, meadow * k, mt]


## Poids du biome montagne seul (0..1), même espace que biome_weights.
func mountain_weight(world_pos: Vector3) -> float:
	if mountain_amount <= 0.0:
		return 0.0
	var m := _mountain_noise.get_noise_2d(world_pos.x, world_pos.z)
	var a := clampf(mountain_amount, 0.0, 1.0)
	# 0,45 (défaut) : environ un cinquième de la carte ; 1 : presque partout
	var th := lerpf(0.45, 0.225, a / 0.45) if a < 0.45 else lerpf(0.225, -0.8, (a - 0.45) / 0.55)
	return smoothstep(th, th + 0.15, m)


func _spawn_nature(chunk: Node3D, job: Dictionary, rng: RandomNumberGenerator) -> void:
	if _nature.is_empty():
		return
	var rp: PackedVector3Array = job["rows_p"]
	var offset: Vector3 = job["offset"]
	var n := rp.size() - 1
	var bw := biome_weights(rp[n >> 1] + offset)
	var per_species := {}   # index d'espèce -> Array[[Transform3D, Color]]
	for cat in NATURE_COUNTS:
		var counts: Array = NATURE_COUNTS[cat]
		var lo := 0.0
		var hi := 0.0
		for b in 4:
			lo += bw[b] * counts[b].x
			hi += bw[b] * counts[b].y
		var count := int(round(rng.randf_range(lo, hi) * nature_density))
		# espèces de cette catégorie et leur poids dans ce biome
		var idx: Array[int] = []
		var weights: Array[float] = []
		var total := 0.0
		for k in _nature.size():
			if _nature[k]["cat"] != cat:
				continue
			var w := 0.0
			for b in 4:
				w += bw[b] * float(_nature[k]["w"][b])
			if w > 0.0:
				idx.append(k)
				weights.append(w)
				total += w
		if idx.is_empty() or total <= 0.0:
			continue
		var rng_x: Vector2 = NATURE_RANGE[cat]
		for c in count:
			# tirage pondéré de l'espèce
			var pick := rng.randf() * total
			var k := idx[0]
			for j in idx.size():
				pick -= weights[j]
				if pick <= 0.0:
					k = idx[j]
					break
			var sp: Dictionary = _nature[k]
			var i0 := rng.randi_range(0, n)
			var x0 := rng.randf_range(rng_x.x, rng_x.y) * (1.0 if rng.randf() < 0.5 else -1.0)
			# les fleurs poussent en massifs, le reste un par un
			var spots: Array[Vector2] = [Vector2(i0, x0)]
			if cat == "flower":
				for f in rng.randi_range(2, 6):
					var a := rng.randf() * TAU
					var r := rng.randf_range(0.3, 1.6)
					spots.append(Vector2(clampi(i0 + int(round(cos(a) * r / row_step)), 0, n), x0 + sin(a) * r))
			for spot in spots:
				_place_nature(spot, k, sp, cat, job, rng, per_species, chunk, bw)
		# arbres sur les collines de la vallée (sans collision, hors d'atteinte)
		if cat == "tree":
			var hill_count := int(round(rng.randf_range(lo, hi) * 1.3 * nature_density)) + 4
			for c in hill_count:
				var pick := rng.randf() * total
				var k := idx[0]
				for j in idx.size():
					pick -= weights[j]
					if pick <= 0.0:
						k = idx[j]
						break
				var x := rng.randf_range(VALLEY_START + 3.0, TERRAIN_COLS[-1] - 2.0) * (1.0 if rng.randf() < 0.5 else -1.0)
				_place_nature(Vector2(rng.randi_range(0, n), x), k, _nature[k], cat, job, rng, per_species, chunk, bw, false)
	_flush_nature(chunk, per_species)


## Place un élément de décor (rangée i = spot.x, distance signée à l'axe = spot.y).
func _place_nature(spot: Vector2, k: int, sp: Dictionary, cat: String, job: Dictionary,
		rng: RandomNumberGenerator, per_species: Dictionary, chunk: Node3D, bw: Array, collide := true) -> void:
	var rp: PackedVector3Array = job["rows_p"]
	var rr: PackedVector3Array = job["rows_r"]
	var rs: PackedFloat32Array = job["rows_s"]
	var offset: Vector3 = job["offset"]
	var i := int(spot.x)
	var x := spot.y
	var ax := absf(x)
	if ax < 5.2 or _field_at(job["fields"], rs[i], x) >= 0:
		return   # pas sur l'accotement ni dans un champ
	if job.has("chalet"):
		var ch: Dictionary = job["chalet"]
		if absf((rs[i] - rs[ch["i"]])) < 7.5 and absf(x - ch["x"]) < 7.0:
			return   # place du chalet
	var p := rp[i] + rr[i] * x
	p.y += -0.04 + _terrain_height(p + offset, ax)
	var sv: Vector2 = sp["scale"]
	var sc := rng.randf_range(sv.x, sv.y)
	var sink := 0.08 * sc if cat == "rock" else 0.0
	var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.9, 1.15), sc))
	var mxf: Transform3D = sp["mesh_xf"]
	var xf := Transform3D(basis, p - Vector3(0, sink, 0)) * mxf
	if not per_species.has(k):
		per_species[k] = []
	per_species[k].append([xf, _nature_tint(p + offset, bw, rng)])
	# collision des arbres et des gros rochers
	if sp["radius"] > 0.0 and collide:
		var body := _nature_body(chunk)
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = sp["radius"] * sc
		shape.height = sp["height"] * sc
		cs.shape = shape
		cs.position = p + Vector3(0, shape.height * 0.5 - sink, 0)
		body.add_child(cs)


func _nature_body(chunk: Node3D) -> StaticBody3D:
	var body := chunk.get_node_or_null("NatureCollision") as StaticBody3D
	if body == null:
		body = StaticBody3D.new()
		body.name = "NatureCollision"
		chunk.add_child(body)
	return body


func _flush_nature(chunk: Node3D, per_species: Dictionary) -> void:
	for k in per_species:
		var xfs: Array = per_species[k]
		var sp: Dictionary = _nature[k]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = sp["mesh"]
		mm.instance_count = xfs.size()
		for j in xfs.size():
			mm.set_instance_transform(j, xfs[j][0])
			mm.set_instance_custom_data(j, xfs[j][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Nature_" + sp["name"]
		mmi.multimesh = mm
		match sp["cat"]:
			"ground", "flower":
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mmi.visibility_range_end = 140.0
			"bush":
				mmi.visibility_range_end = 260.0
		chunk.add_child(mmi)


# --- Pluie et recentrage --------------------------------------------------------

func _update_wetness(delta: float) -> void:
	var weather := get_tree().get_first_node_in_group("weather_system")
	var rain: float = weather.get("rain") if weather else 0.0
	if rain > 0.05:
		_wetness = move_toward(_wetness, 1.0, delta / 20.0)    # se mouille en 20 s
	else:
		_wetness = move_toward(_wetness, 0.0, delta / 120.0)   # sèche en 2 min
	_road_mat.set_shader_parameter("wetness", _wetness)


func _shift_origin_if_needed(tpos: Vector3) -> bool:
	if _target == null or origin_shift_distance <= 0.0:
		return false
	var flat := Vector3(tpos.x, 0.0, tpos.z)
	if flat.length() < origin_shift_distance:
		return false
	var shift := flat
	world_offset += shift
	_pos -= shift
	for c in _chunks:
		(c["node"] as Node3D).position -= shift
	# Déplace la cible (voiture) en gardant sa vitesse.
	var xf := _target.global_transform
	xf.origin -= shift
	_target.global_transform = xf
	if _target is RigidBody3D:
		PhysicsServer3D.body_set_state((_target as RigidBody3D).get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
	origin_shifted.emit(shift)
	if debug_timings:
		print("Route : origine recentrée de ", shift)
	return true
