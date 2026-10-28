class_name FallingTreeManager
extends Node
## Déclenche des chutes d'arbres aléatoires devant la voiture.
##
## - Un arbre apparaît au bord de la route, à une distance qui dépend de la vitesse
##   (le joueur a ~4-6 s pour réagir), tremble, craque puis tombe en travers.
## - Il bloque une voie (ou un peu plus) mais laisse toujours un passage >= 3 m
##   (accotement compris) : il faut freiner ou changer de voie.
## - Les chutes deviennent plus fréquentes avec la distance ; au-delà de
##   `slalom_distance`, un deuxième arbre peut tomber de l'autre côté un peu plus loin.
## - Compte les arbres évités et les chocs (affichés au tableau de bord du 4x4).

signal tree_falling(tree: FallingTree)
signal tree_hit(strength: float)
signal tree_avoided

@export var road_path: NodePath
@export var car_path: NodePath
@export var enabled := true
## Modèle utilisé si la route ne fournit pas d'espèce (sinon l'espèce dépend du biome).
@export var tree_scene: PackedScene = preload("res://props/tree.glb")
## Couleur des feuilles projetées selon l'espèce.
const LEAF_COLORS := {
	"pine_tall": Color(0.12, 0.32, 0.16), "pine_small": Color(0.12, 0.32, 0.16),
	"tree_autumn": Color(0.85, 0.45, 0.1), "tree_dead": Color(0.4, 0.3, 0.2),
	"birch": Color(0.45, 0.65, 0.2), "poplar": Color(0.3, 0.55, 0.18),
	"spruce": Color(0.08, 0.25, 0.14), "larch": Color(0.5, 0.6, 0.18),
}
var _scene_cache := {}
## Pas d'arbre avant cette distance parcourue (m).
@export var safe_start_distance := 300.0
## Intervalle entre deux chutes (s) au début / au plus difficile.
@export var interval_start := Vector2(25.0, 55.0)
@export var interval_hard := Vector2(10.0, 22.0)
## Distance parcourue (m) pour atteindre la difficulté maximale.
@export var hard_distance := 15000.0
## Temps de réaction laissé au joueur (s, mini/maxi).
@export var reaction_time := Vector2(4.0, 6.0)
@export var slalom_distance := 3000.0
@export_range(0.0, 1.0) var slalom_chance := 0.3
## Largeur minimale laissée libre par un arbre tombé (m, accotement compris).
@export var min_gap := 3.5

var trees_avoided := 0
var tree_hits := 0
var travelled := 0.0

var _road: RoadGenerator
var _car: Node3D
var _next := 20.0
var _active: Array[FallingTree] = []
var _last_pos := Vector3.ZERO
var _creak: AudioStreamWAV
var _crash: AudioStreamWAV


const GROUP := "falling_trees"


func _ready() -> void:
	add_to_group(GROUP)
	_road = get_node_or_null(road_path) as RoadGenerator
	_car = get_node_or_null(car_path) as Node3D
	_creak = _make_creak()
	_crash = _make_crash()
	if _road:
		_road.origin_shifted.connect(func(off: Vector3): _last_pos -= off)


func _physics_process(delta: float) -> void:
	if _road == null or _car == null:
		return
	var pos := _car.global_position
	if _last_pos != Vector3.ZERO:
		travelled += Vector3(pos.x - _last_pos.x, 0, pos.z - _last_pos.z).length()
	_last_pos = pos
	_check_avoided()
	if not enabled or travelled < safe_start_distance:
		return
	_next -= delta
	if _next <= 0.0:
		_schedule()
		spawn_ahead()


## Fait tomber un arbre devant la voiture (distance auto si distance <= 0).
func spawn_ahead(distance := -1.0, side := 0) -> FallingTree:
	var speed := maxf((_car as RigidBody3D).linear_velocity.length() if _car is RigidBody3D else 0.0, 8.0)
	if distance <= 0.0:
		distance = clampf(speed * randf_range(reaction_time.x, reaction_time.y) + 20.0, 55.0, 220.0)
	if side == 0:
		side = 1 if randf() < 0.5 else -1
	var tree := _spawn(distance, side)
	if tree and travelled > slalom_distance and randf() < slalom_chance:
		_spawn(distance + randf_range(18.0, 30.0), -side)   # slalom
	return tree


func _spawn(distance: float, side: int) -> FallingTree:
	var sample := _road.sample_ahead(_car.global_position, distance)
	if not sample["found"]:
		return null
	var chunk: Node3D = sample["chunk"]
	var right: Vector3 = sample["right"]
	var base_lat := side * randf_range(5.8, 6.6)
	var base := _road.ground_position(sample, base_lat)
	# Hauteur : barre au moins la voie du côté de l'arbre, laisse un passage libre
	# d'au moins `min_gap` m (accotement compris) de l'autre côté.
	var far_edge := -5.5 * side            # bord extérieur de l'accotement opposé
	var max_reach := absf(base_lat - far_edge) - min_gap
	var height := randf_range(absf(base_lat) + 0.2, minf(absf(base_lat) + 2.2, max_reach))

	var tree := FallingTree.new()
	# Espèce tirée selon le biome, comme les arbres du décor à cet endroit.
	var species := _road.pick_tree_species(base) if _road.has_method("pick_tree_species") else "tree"
	tree.tree_scene = _species_scene(species)
	tree.leaf_color = LEAF_COLORS.get(species, Color(0.3, 0.55, 0.18))
	tree.set_meta("species", species)
	tree.height = height
	tree.creak_sound = _creak
	tree.crash_sound = _crash
	tree.road_point = sample["point"]
	tree.road_dir = sample["dir"]
	var tip_lat := base_lat - side * height
	tree.blocked_lateral = Vector2(minf(base_lat, tip_lat), maxf(base_lat, tip_lat))
	# Orientation : l'arbre bascule autour de l'axe X vers son +Z = vers l'axe de la route.
	var toward := -right * side
	var x_axis := Vector3.UP.cross(toward).normalized()
	chunk.add_child(tree)
	tree.global_transform = Transform3D(Basis(x_axis, Vector3.UP, toward), base)
	tree.hit_car.connect(_on_hit)
	tree.landed.connect(func(t: FallingTree): _on_landed(t))
	_active.append(tree)
	tree_falling.emit(tree)
	return tree


## Partie à deux, chez le copilote : arbre tombé chez le conducteur (voir
## NetSession._tree_params), posé au même endroit et qui tombe de la même façon.
func spawn_remote(p: Dictionary) -> FallingTree:
	var base: Vector3 = p["base"]
	var chunk := _road.chunk_at(base) if _road else null
	if chunk == null:
		return null
	var tree := FallingTree.new()
	var species: String = p["species"]
	tree.tree_scene = _species_scene(species)
	tree.leaf_color = LEAF_COLORS.get(species, Color(0.3, 0.55, 0.18))
	tree.height = p["height"]
	tree.visual_yaw = p["yaw"]
	tree.creak_sound = _creak
	tree.crash_sound = _crash
	tree.road_point = p["road_point"]
	tree.road_dir = p["road_dir"]
	tree.blocked_lateral = p["blocked"]
	tree.set_meta("species", species)
	chunk.add_child(tree)
	tree.global_transform = Transform3D(p["basis"], base)
	tree.hit_car.connect(_on_hit)
	tree.landed.connect(func(t: FallingTree): _on_landed(t))
	_active.append(tree)
	tree_falling.emit(tree)
	return tree


func get_active_trees() -> Array[FallingTree]:
	_active = _active.filter(func(t): return is_instance_valid(t))
	return _active


func _schedule() -> void:
	var k := clampf(travelled / hard_distance, 0.0, 1.0)
	var lo := lerpf(interval_start.x, interval_hard.x, k)
	var hi := lerpf(interval_start.y, interval_hard.y, k)
	_next = randf_range(lo, hi)


func _check_avoided() -> void:
	for t in get_active_trees():
		if t.has_meta("counted"):
			continue
		if t.state == FallingTree.State.SHAKING:
			continue
		var ahead := (_car.global_position - t.road_point).dot(t.road_dir)
		if ahead > 6.0:
			t.set_meta("counted", true)
			if not t.has_meta("hit"):
				trees_avoided += 1
				tree_avoided.emit()
		elif ahead < -400.0:
			t.set_meta("counted", true)


func _on_hit(tree: FallingTree, strength: float) -> void:
	tree.set_meta("hit", true)
	tree_hits += 1
	tree_hit.emit(strength)
	for h in get_tree().get_nodes_in_group(VRHandInteractor.GROUP):
		(h as VRHandInteractor).pulse(strength, 0.35)


func _on_landed(tree: FallingTree) -> void:
	# Vibration selon la distance (on « sent » l'arbre s'écraser au sol).
	var d := tree.global_position.distance_to(_car.global_position)
	var strength := clampf(1.0 - d / 45.0, 0.0, 0.7)
	if strength > 0.05:
		for h in get_tree().get_nodes_in_group(VRHandInteractor.GROUP):
			(h as VRHandInteractor).pulse(strength, 0.25)


# --- Sons générés par code (pas de fichier audio) -----------------------------

const RATE := 22050


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## Craquement : bois qui grince (dents de scie irrégulières) + claquements.
func _make_creak() -> AudioStreamWAV:
	var n := int(RATE * 2.2)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	var lp := 0.0
	var click := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 70.0 + 45.0 * sin(t * 2.3) + 25.0 * sin(t * 7.1) + randf() * 30.0
		phase = fmod(phase + f / RATE, 1.0)
		var saw := phase * 2.0 - 1.0
		var env := clampf(t / 0.4, 0.0, 1.0) * clampf((2.2 - t) / 0.3, 0.0, 1.0)
		var grind := saw * (0.25 + 0.2 * sin(t * 13.0)) * env
		if randf() < 0.0004 + t * 0.0012:
			click = 1.0
		click *= 0.993
		var noise := randf() * 2.0 - 1.0
		lp += (noise - lp) * 0.3
		s[i] = grind * 0.6 + lp * click * 0.9
	return _wav(s)


## Fracas : choc sourd + feuillage et branches qui se brisent.
func _make_crash() -> AudioStreamWAV:
	var n := int(RATE * 2.0)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	var click := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := randf() * 2.0 - 1.0
		lp += (noise - lp) * 0.08
		lp2 += (noise - lp2) * 0.45
		var thump := sin(TAU * 48.0 * t) * exp(-t * 7.0)
		var rumble := lp * exp(-t * 2.2) * 2.5
		var leaves := lp2 * exp(-t * 1.6) * 0.35
		if randf() < 0.004 * exp(-t * 1.5):
			click = 1.0
		click *= 0.985
		s[i] = thump * 0.9 + rumble + leaves + (randf() * 2.0 - 1.0) * click * 0.6
	return _wav(s)


func _species_scene(species: String) -> PackedScene:
	if species == "tree" or species == "":
		return tree_scene
	if not _scene_cache.has(species):
		var sc := load("res://props/nature/%s.glb" % species) as PackedScene
		_scene_cache[species] = sc if sc else tree_scene
	return _scene_cache[species]
