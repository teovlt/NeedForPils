class_name AnimalManager
extends Node
## Animaux du décor, créés par RoadGenerator (nœud « Animals »).
##
## - Promeneurs : quelques groupes d'animaux autour de la voiture (devant elle, entre
##   9 et 40 m de la route), qui broutent, se baladent et fuient quand la voiture
##   arrive vite. L'espèce dépend du biome (RoadGenerator.get_biome_at) :
##   forêt de sapins -> sangliers, biches, lapins ; bois mixte -> biches, lapins,
##   sangliers ; prairie -> moutons, lapins ; montagne -> moutons, biches.
## - Traversées : de temps en temps, un animal (ou un troupeau de moutons, une laie et
##   ses marcassins, deux biches...) traverse la route devant la voiture, réglé pour
##   arriver sur la route quand elle y passe (3,5 à 5,5 s pour réagir). Une biche peut
##   s'arrêter net au milieu de la voie. Il faut freiner ou l'éviter.
## - Choc : la voiture ralentit selon la masse de l'animal (lapin : à peine ; sanglier,
##   mouton, biche : nettement), vibration, bruit sourd et cri ; l'animal est projeté,
##   retombe, se relève et s'enfuit en boitant.
## Les animaux sont des Node3D en coordonnées monde, décalés au recentrage d'origine.

signal animal_hit(animal: Node3D, strength: float)

const ANIMAL := preload("res://world/animals/animal.gd")

const GROUP := "animal_manager"
const SPECIES := {
	"rabbit": {"scene": "res://props/animals/rabbit.glb", "mass": 2.0, "walk": 0.5, "run": 7.0,
		"cross_speed": 5.5, "radius": 0.12, "height": 0.4, "length": 0.45, "group": Vector2i(1, 2),
		"weights": [1.2, 2.0, 2.5, 0.4], "shy": 14.0, "step_freq": 2.2, "stride": 0.4, "graze_angle": 0.35,
		"idle": ["res://audio/animals/rabbit_thump.wav"], "alarm": ["res://audio/animals/rabbit_thump.wav"],
		"hit": ["res://audio/animals/rabbit_squeal.wav"], "idle_gap": Vector2(14, 30), "sound_unit": 2.5},
	"boar": {"scene": "res://props/animals/boar.glb", "mass": 90.0, "walk": 0.9, "run": 6.5,
		"cross_speed": 4.0, "radius": 0.3, "height": 0.85, "length": 1.4, "group": Vector2i(1, 4),
		"young_scale": 0.55, "weights": [3.0, 2.0, 0.4, 0.3], "shy": 18.0, "step_freq": 2.0, "stride": 0.5,
		"graze_angle": 0.45,
		"idle": ["res://audio/animals/boar_grunt_1.wav", "res://audio/animals/boar_grunt_2.wav", "res://audio/animals/boar_grunt_3.wav"],
		"alarm": ["res://audio/animals/boar_grunt_2.wav"], "hit": ["res://audio/animals/boar_squeal.wav"],
		"idle_gap": Vector2(6, 15), "sound_unit": 5.0},
	"deer": {"scene": "res://props/animals/deer.glb", "mass": 60.0, "walk": 1.1, "run": 9.0,
		"cross_speed": 7.0, "radius": 0.25, "height": 1.5, "length": 1.4, "group": Vector2i(1, 3),
		"weights": [2.5, 3.0, 0.8, 1.2], "shy": 30.0, "step_freq": 1.4, "stride": 0.8, "graze_angle": 1.2,
		"freeze_chance": 0.35,
		"idle": ["res://audio/animals/deer_call.wav"], "alarm": ["res://audio/animals/deer_bark_1.wav", "res://audio/animals/deer_bark_2.wav"],
		"hit": ["res://audio/animals/deer_bark_1.wav"], "idle_gap": Vector2(15, 35), "sound_unit": 6.0},
	"sheep": {"scene": "res://props/animals/sheep.glb", "mass": 70.0, "walk": 0.6, "run": 3.0,
		"cross_speed": 2.0, "radius": 0.32, "height": 0.85, "length": 1.3, "group": Vector2i(3, 7),
		"young_scale": 0.65, "weights": [0.0, 0.4, 3.0, 3.0], "shy": 12.0, "step_freq": 1.8, "stride": 0.4,
		"graze_angle": 0.9,
		"idle": ["res://audio/animals/sheep_1.wav", "res://audio/animals/sheep_2.wav", "res://audio/animals/sheep_3.wav"],
		"alarm": ["res://audio/animals/sheep_2.wav"], "hit": ["res://audio/animals/sheep_3.wav"],
		"idle_gap": Vector2(5, 14), "sound_unit": 5.0},
}
const IMPACT_SOUND := "res://audio/animals/impact.wav"

@export var enabled := true
## Promeneurs : nombre de groupes gardés autour de la voiture.
@export var ambient_groups := 5
## Traversées : pas avant cette distance parcourue (m) ; intervalle (s) au début /
## au plus difficile ; distance (m) pour atteindre la difficulté maximale.
@export var crossings_enabled := true
@export var safe_start_distance := 400.0
@export var interval_start := Vector2(35.0, 70.0)
@export var interval_hard := Vector2(15.0, 35.0)
@export var hard_distance := 15000.0
@export var reaction_time := Vector2(3.5, 5.5)

var road: Node3D          # RoadGenerator
var car: RigidBody3D
var animals: Array = []
var animals_hit := 0
var crossings := 0
var crossings_avoided := 0
var travelled := 0.0

var _sounds := {}
var _next_cross := 30.0
var _ambient_t := 0.0
var _last_pos := Vector3.ZERO
var _impact: AudioStreamPlayer3D
var _cross_groups: Array = []    # [{animals, done}]


func _ready() -> void:
	add_to_group(GROUP)
	if road and road.has_signal("origin_shifted"):
		road.origin_shifted.connect(_on_origin_shifted)
	_next_cross = randf_range(interval_start.x, interval_start.y)


func _on_origin_shifted(off: Vector3) -> void:
	_last_pos -= off
	for a in animals:
		if is_instance_valid(a):
			a.global_position -= off
			a.target -= off


func sound(path: String) -> AudioStream:
	if not _sounds.has(path):
		_sounds[path] = load(path)
	return _sounds[path]


func _physics_process(delta: float) -> void:
	if road == null or car == null:
		return
	var pos := car.global_position
	if _last_pos != Vector3.ZERO:
		travelled += Vector3(pos.x - _last_pos.x, 0, pos.z - _last_pos.z).length()
	_last_pos = pos
	animals = animals.filter(func(a): return is_instance_valid(a))
	_despawn_far()
	_check_crossings_done()
	if not enabled:
		return
	_ambient_t -= delta
	if _ambient_t <= 0.0:
		_ambient_t = 1.5
		_keep_ambient()
	if crossings_enabled and travelled > safe_start_distance:
		_next_cross -= delta
		if _next_cross <= 0.0:
			var k := clampf(travelled / hard_distance, 0.0, 1.0)
			var iv := interval_start.lerp(interval_hard, k)
			_next_cross = randf_range(iv.x, iv.y)
			spawn_crossing()


# --- Aide pour les animaux ----------------------------------------------------

## Distance signée à l'axe de la route (> 0 à droite), 999 si inconnue.
func lateral_of(p: Vector3) -> float:
	var info: Dictionary = road.call("sample_road", p)
	if not info["found"]:
		return 999.0
	return (p - (info["point"] as Vector3)).dot(info["right"] as Vector3)


## Direction horizontale qui s'éloigne de la route.
func away_from_road(p: Vector3) -> Vector3:
	var info: Dictionary = road.call("sample_road", p)
	if not info["found"]:
		return Vector3.FORWARD
	var r: Vector3 = info["right"]
	var lat := (p - (info["point"] as Vector3)).dot(r)
	var v := r * (1.0 if lat >= 0.0 else -1.0)
	v.y = 0.0
	return v.normalized()


func play_impact(p: Vector3, strength: float) -> void:
	if _impact == null:
		_impact = AudioStreamPlayer3D.new()
		_impact.stream = sound(IMPACT_SOUND)
		_impact.unit_size = 8.0
		add_child(_impact)
	_impact.global_position = p if _impact.is_inside_tree() else Vector3.ZERO
	_impact.volume_db = linear_to_db(clampf(0.3 + strength, 0.3, 1.3))
	_impact.play()


# --- Choix de l'espèce --------------------------------------------------------

func pick_species(p: Vector3) -> String:
	var bw: Array = road.call("get_biome_at", p) if road.has_method("get_biome_at") else [0.25, 0.25, 0.25, 0.25]
	var total := 0.0
	var ws := {}
	for sp in SPECIES:
		var w := 0.0
		var sw: Array = SPECIES[sp]["weights"]
		for b in 4:
			w += float(bw[b]) * float(sw[b])
		ws[sp] = w
		total += w
	var r := randf() * total
	for sp in ws:
		r -= ws[sp]
		if r <= 0.0:
			return sp
	return "rabbit"


func _make(sp: String, p: Vector3, young := false) -> Node3D:
	var a: Node3D = ANIMAL.new()
	var sc := randf_range(0.92, 1.08)
	if young and SPECIES[sp].has("young_scale"):
		sc *= float(SPECIES[sp]["young_scale"])
	a.call("setup", sp, SPECIES[sp], car, self, sc)
	a.name = sp.capitalize()
	a.position = p     # avant add_child : _ready cale l'animal sur le sol à cet endroit
	add_child(a)
	a.set("heading", randf() * TAU)
	a.connect("hit_car", _on_animal_hit)
	animals.append(a)
	return a


func _on_animal_hit(a: Node3D, strength: float) -> void:
	animals_hit += 1
	animal_hit.emit(a, strength)
	for h in get_tree().get_nodes_in_group(VRHandInteractor.GROUP):
		(h as VRHandInteractor).pulse(clampf(0.25 + strength, 0.25, 1.0), 0.3)


# --- Promeneurs ---------------------------------------------------------------

func _keep_ambient() -> void:
	var n_groups := 0
	var seen := {}
	for a in animals:
		if not a.crossing and not a.crossed:
			var key: int = a.get_meta("group", -1)
			if not seen.has(key):
				seen[key] = true
				n_groups += 1
	if n_groups >= ambient_groups:
		return
	var d := randf_range(70.0, 220.0)
	var sample: Dictionary = road.call("sample_ahead", car.global_position, d)
	if not sample["found"]:
		return
	var side := 1.0 if randf() < 0.5 else -1.0
	var lat := side * randf_range(12.0, 38.0)
	var centre: Vector3 = road.call("ground_position", sample, lat)
	spawn_group(pick_species(centre), centre, lat, false)


## Crée un groupe d'une espèce autour de `centre` ; renvoie les animaux.
func spawn_group(sp: String, centre: Vector3, _lat: float, for_crossing: bool) -> Array:
	var g: Vector2i = SPECIES[sp]["group"]
	var n := randi_range(g.x, g.y)
	var gid := randi()
	var out: Array = []
	for i in n:
		var off := Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5)) if i > 0 else Vector3.ZERO
		if for_crossing:
			off = Vector3.ZERO
		var young := i > 0 and (sp == "boar" or (sp == "sheep" and randf() < 0.3))
		var a = _make(sp, centre + off, young)
		a.set_meta("group", gid)
		out.append(a)
	return out


func _despawn_far() -> void:
	var cp := car.global_position
	var fwd := car.global_basis.z
	for a in animals:
		var d: Vector3 = a.global_position - cp
		var behind: bool = d.dot(fwd) < -120.0
		if (behind or d.length() > 320.0) and not a.crossing:
			animals.erase(a)
			a.queue_free()


# --- Traversées ---------------------------------------------------------------

## Fait traverser un animal (ou un groupe) devant la voiture. `sp` vide = selon le biome.
func spawn_crossing(sp := "", distance := -1.0, side := 0) -> Array:
	var v := maxf(car.linear_velocity.length(), 8.0)
	if distance <= 0.0:
		distance = clampf(v * randf_range(reaction_time.x, reaction_time.y) + 15.0, 45.0, 200.0)
	if side == 0:
		side = 1 if randf() < 0.5 else -1
	var sample: Dictionary = road.call("sample_ahead", car.global_position, distance)
	if not sample["found"]:
		return []
	if sp == "":
		sp = pick_species(sample["point"])
	var c: Dictionary = SPECIES[sp]
	var t_arrive := distance / v
	var cross_v: float = c["cross_speed"]
	# Départ calculé pour que l'animal soit dans la voie de la voiture quand elle y
	# arrive (si elle garde sa vitesse) : accélération 6 m/s² puis vitesse constante.
	var lane := clampf(lateral_of(car.global_position), -3.5, 3.5)
	var t_ramp := cross_v / 6.0
	var dist := cross_v * (t_arrive - t_ramp) + cross_v * cross_v / 12.0
	if t_arrive < t_ramp:
		dist = 3.0 * t_arrive * t_arrive
	var delay := 0.0
	var start_lat := lane + side * dist
	if absf(start_lat) > 40.0:   # trop loin : il part de 40 m mais attend un peu
		delay = (absf(start_lat) - 40.0) / cross_v
		start_lat = 40.0 * side
	if absf(start_lat) < 7.0:    # trop près de la route pour être caché : un peu plus loin
		start_lat = 7.0 * side
	var end_lat := -side * randf_range(13.0, 18.0)
	var right: Vector3 = sample["right"]
	var dir: Vector3 = sample["dir"]
	var group := spawn_group(sp, road.call("ground_position", sample, start_lat), start_lat, true)
	for i in group.size():
		var a = group[i]
		# troupeau en file indienne, légèrement décalé le long de la route
		var along: Vector3 = dir * (randf_range(-1.5, 1.5) + (i * 1.3 if sp == "sheep" else i * 0.9))
		a.global_position += along - right * side * (i * 0.8 if sp == "sheep" else 0.0)
		var to: Vector3 = road.call("ground_position", sample, end_lat) + along
		a.heading = atan2(to.x - a.global_position.x, to.z - a.global_position.z)
		a.start_crossing(to, delay + i * (0.9 if sp == "sheep" else 0.35))
	crossings += 1
	_cross_groups.append({"animals": group, "hits0": animals_hit})
	return group


func _check_crossings_done() -> void:
	for g in _cross_groups.duplicate():
		var alive: Array = (g["animals"] as Array).filter(func(a): return is_instance_valid(a))
		var all_done := true
		for a in alive:
			if a.crossing:
				all_done = false
		if all_done:
			var any_hit := false
			for a in alive:
				if a.was_hit or a.state == ANIMAL.State.HIT:
					any_hit = true
			if not any_hit and animals_hit == int(g["hits0"]):
				crossings_avoided += 1
			_cross_groups.erase(g)
