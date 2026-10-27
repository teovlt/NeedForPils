class_name PillSpawner
extends Node
## Pose des pilules sur la route devant la voiture et détecte quand on roule dessus.
##
## - Une pilule tous les `spacing` m environ, sur sa voie, sur la voie d'en face ou
##   sur l'accotement ; parfois une rangée de trois (tentant, mais chaque pilule de
##   plus fait monter l'assimilation).
## - Appât : quand un arbre tombe, une pilule apparaît parfois juste derrière lui,
##   dans la voie qu'il bloque.
## Les pilules sont enfants des tronçons de route : elles disparaissent avec eux et
## suivent les recalages d'origine du monde.

const GROUP := "pill_spawner"

@export var road_path: NodePath
@export var car_path: NodePath
@export var addiction_path: NodePath
@export var enabled := true
## Pilules géantes posées sur la route (désactivé le 27/10 : les pilules se prennent
## maintenant dans la pochette du 4x4, voir interaction/pill_bag.gd). Le nœud reste
## pour la distance parcourue et l'accès à la route utilisés par ChaseDirector.
@export var road_pills := false
## Pas de pilule avant cette distance parcourue (m).
@export var safe_start_distance := 120.0
## Distance (m) entre deux pilules (mini/maxi).
@export var spacing := Vector2(170.0, 360.0)
## Probabilités : voie d'en face, accotement, rangée de trois (le reste : sa voie).
@export_range(0.0, 1.0) var oncoming_chance := 0.3
@export_range(0.0, 1.0) var shoulder_chance := 0.15
@export_range(0.0, 1.0) var row_chance := 0.12
## Probabilité de poser une pilule derrière un arbre qui tombe.
@export_range(0.0, 1.0) var bait_chance := 0.5
@export var lane_offset := 1.75
@export var shoulder_offset := 4.7
## Hauteur de la pilule au-dessus du sol (m).
@export var height := 0.9

var travelled := 0.0
var pills_spawned := 0

var _road: RoadGenerator
var _car: Node3D
var _addiction: PillAddiction
var _next := 0.0
var _last_pos := Vector3.ZERO
var _pills: Array[RoadPill] = []


func _ready() -> void:
	add_to_group(GROUP)
	_road = get_node_or_null(road_path) as RoadGenerator
	_car = get_node_or_null(car_path) as Node3D
	_addiction = get_node_or_null(addiction_path) as PillAddiction
	if _addiction == null:
		_addiction = get_tree().get_first_node_in_group(PillAddiction.GROUP) as PillAddiction
	_next = safe_start_distance
	if _road:
		_road.origin_shifted.connect(func(off: Vector3): _last_pos -= off)
	var trees := get_tree().get_first_node_in_group(FallingTreeManager.GROUP) as FallingTreeManager
	if trees:
		trees.tree_falling.connect(_on_tree_falling)


func _physics_process(_delta: float) -> void:
	if _road == null or _car == null:
		return
	var pos := _car.global_position
	if _last_pos != Vector3.ZERO:
		travelled += Vector3(pos.x - _last_pos.x, 0, pos.z - _last_pos.z).length()
	_last_pos = pos
	_check_pickups()
	if enabled and travelled >= _next:
		_next = travelled + randf_range(spacing.x, spacing.y)
		spawn_ahead()


## (Re)lance la pose des pilules à partir de maintenant.
func start() -> void:
	enabled = true
	_next = travelled + randf_range(spacing.x, spacing.y)


func get_road() -> RoadGenerator:
	return _road


## Pose une pilule (ou une rangée) devant la voiture (distance auto si <= 0).
func spawn_ahead(distance := -1.0) -> void:
	if not road_pills:
		return
	var speed := (_car as RigidBody3D).linear_velocity.length() if _car is RigidBody3D else 0.0
	if distance <= 0.0:
		distance = clampf(speed * 6.0 + 40.0, 90.0, 220.0)
	var own := _own_side()
	var roll := randf()
	if roll < oncoming_chance:
		spawn_at(distance, -own * lane_offset)
	elif roll < oncoming_chance + shoulder_chance:
		spawn_at(distance, own * shoulder_offset)
	elif roll < oncoming_chance + shoulder_chance + row_chance:
		for k in 3:
			spawn_at(distance + k * 14.0, own * lane_offset)
	else:
		spawn_at(distance, own * lane_offset)


func spawn_at(distance: float, lateral: float) -> RoadPill:
	if not road_pills:
		return null
	var sample := _road.sample_ahead(_car.global_position, distance)
	if not sample["found"]:
		return null
	var pill := RoadPill.new()
	pill.name = "Pill%d" % pills_spawned
	(sample["chunk"] as Node3D).add_child(pill)
	pill.global_position = _road.ground_position(sample, lateral) + Vector3.UP * height
	_pills.append(pill)
	pills_spawned += 1
	return pill


func get_active_pills() -> Array[RoadPill]:
	_pills = _pills.filter(func(p): return is_instance_valid(p) and not p.collected)
	return _pills


## Côté de la route où roule la voiture (+1 = à droite de l'axe).
func _own_side() -> float:
	var s := _road.sample_road(_car.global_position)
	if s["found"] and absf(s["lateral"]) > 0.4:
		return signf(s["lateral"])
	return 1.0


## La voiture passe sur une pilule : boîte un peu plus large que la carrosserie.
func _check_pickups() -> void:
	for p in get_active_pills():
		var local := _car.to_local(p.global_position)
		if absf(local.x) < 1.4 and absf(local.z) < 2.7 and local.y > -0.8 and local.y < 2.6:
			p.collect()
			if _addiction:
				_addiction.take_pill()


func _on_tree_falling(tree: FallingTree) -> void:
	if not road_pills or not enabled or randf() >= bait_chance or _car == null:
		return
	var car_s := _road.sample_road(_car.global_position)
	var tree_s := _road.sample_road(tree.road_point)
	if not car_s["found"] or not tree_s["found"]:
		return
	# Juste derrière l'arbre, au milieu de la voie qu'il bloque.
	var dist: float = tree_s["s"] - car_s["s"] + randf_range(5.0, 9.0)
	var lat := clampf((tree.blocked_lateral.x + tree.blocked_lateral.y) * 0.5, -lane_offset, lane_offset)
	if absf(lat) < 0.5:
		lat = lane_offset * signf(lat if lat != 0.0 else 1.0)
	spawn_at(dist, lat)
