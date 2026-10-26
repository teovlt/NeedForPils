@icon("res://addons/godot-xr-tools/editor/icons/node.svg")
class_name CarStorage
extends Node3D
## Gère les objets relâchés dans/autour d'un véhicule (enfant du véhicule, repère identique).
## - près d'un StorageZone accessible  -> rangé dedans
## - ailleurs dans l'habitacle         -> tombe sur le siège / le plancher / le tableau de bord
## Les objets posés en vrac suivent une physique simplifiée (ItemPhysics) : ils glissent,
## roulent et rebondissent selon les accélérations de la voiture.
## - hors de l'habitacle (par la fenêtre) -> objet libre soumis à la physique

const GROUP := "car_storage"
const ITEM_LAYER := 16

## Volume de l'habitacle (repère du véhicule).
@export var cabin := AABB(Vector3(-0.9, 0.5, -2.45), Vector3(1.8, 1.45, 3.5))
## Surfaces où un objet lâché peut tomber : AABB plates (position.y = hauteur de la surface).
@export var surfaces: Array[AABB] = []
## Pour chaque surface : côtés fermés par une paroi (1 = -X, 2 = +X, 4 = -Z, 8 = +Z).
## Un objet qui glisse vers un côté ouvert tombe de la surface.
@export var surface_walls := PackedInt32Array()
## Pour chaque surface : adhérence (tissu, moquette > plastique).
@export var surface_friction := PackedFloat32Array()
## Volumes pleins de l'habitacle (sièges, dossiers, banquette, console, bas du tableau
## de bord...) que les objets en vrac ne traversent pas (AABB, repère du véhicule).
@export var obstacles: Array[AABB] = []
## Objets en vrac soumis aux accélérations de la voiture (sinon : collés à leur place).
@export var item_physics := true
## Durée de vie (s) d'un objet jeté dehors.
@export var thrown_lifetime := 40.0
## Range les objets au hasard à chaque lancement de partie.
@export var randomize_on_start := true
## Probabilité qu'un objet traîne en vrac (siège, plancher, tableau de bord) au lieu d'être rangé.
@export_range(0.0, 1.0) var loose_chance := 0.15
## Endroits où un objet peut traîner en vrac au départ (AABB plates, repère du véhicule).
@export var loose_spots: Array[AABB] = [AABB(Vector3(-0.68, 0.85, -0.12), Vector3(0.46, 0, 0.5))]
## Graine du tirage (0 = différent à chaque partie).
@export var random_seed := 0

var _zones: Array[StorageZone] = []
var _car: RigidBody3D


func _ready() -> void:
	add_to_group(GROUP)
	_car = find_vehicle(self)
	for z in get_parent().find_children("*", "Node3D", true, false):
		if z is StorageZone:
			_zones.append(z)
	if randomize_on_start:
		randomize_items.call_deferred()   # après le _ready des zones


## Répartit au hasard les objets rangés (sauf ceux d'un support fixe comme le GPS).
func randomize_items() -> void:
	var rng := RandomNumberGenerator.new()
	if random_seed != 0:
		rng.seed = random_seed
	else:
		rng.randomize()
	var items: Array[RigidBody3D] = []
	var fill_zones: Array[StorageZone] = []
	for z in _zones:
		if z.random_fill and not z.exact_snap:
			fill_zones.append(z)
			for c in z.get_children():
				if c is RigidBody3D and c.get_node_or_null("Grab"):
					items.append(c)
	for c in get_children():
		if c is RigidBody3D and c.get_node_or_null("Grab"):
			items.append(c)
	# Les gros objets d'abord, pour qu'ils trouvent encore de la place.
	items.shuffle()
	items.sort_custom(func(a, b): return _volume(a) > _volume(b))
	var taken := {}   # zone -> Array[Rect2]
	for z in fill_zones:
		taken[z] = []
	var loose_taken: Array = []
	var report := PackedStringArray()
	for it in items:
		var placed := false
		if rng.randf() >= loose_chance:
			var order := fill_zones.duplicate()
			for i in range(order.size() - 1, 0, -1):   # mélange avec notre générateur
				var j := rng.randi_range(0, i)
				var tmp = order[i]
				order[i] = order[j]
				order[j] = tmp
			for z in order:
				if z.try_random_place(it, rng, taken[z]):
					report.append("%s -> %s" % [it.name, z.zone_name])
					placed = true
					break
		if not placed:
			_place_loose(it, rng, loose_taken)
			report.append("%s -> en vrac" % it.name)
	print("Objets rangés au hasard : ", ", ".join(report))


func _volume(item: RigidBody3D) -> float:
	var g := item.get_node_or_null("Grab") as VRPickable
	return g.get_local_aabb().get_volume() if g else 0.0


## Pose un objet en vrac sur un des `loose_spots` (siège passager par défaut).
func _place_loose(item: RigidBody3D, rng: RandomNumberGenerator, taken: Array) -> void:
	var grab := item.get_node_or_null("Grab") as VRPickable
	if loose_spots.is_empty() or grab == null:
		return
	if item.get_parent() != self:
		item.reparent(self, false)
	item.freeze = true
	item.collision_layer = 0
	item.collision_mask = 0
	var dir := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
	var basis := lying_basis(grab, dir if dir.length() > 0.1 else Vector3.RIGHT, Vector3.UP)
	var box := rotated_aabb(grab.get_local_aabb(), basis)
	var half := box.size * 0.5
	var centre := box.position + half
	for _i in 30:
		var s: AABB = loose_spots[rng.randi() % loose_spots.size()]
		if box.size.x > s.size.x or box.size.z > s.size.z:
			continue
		var cx := rng.randf_range(s.position.x + half.x, s.end.x - half.x)
		var cz := rng.randf_range(s.position.z + half.z, s.end.z - half.z)
		var rect := Rect2(cx - half.x, cz - half.z, box.size.x, box.size.z)
		var ok := true
		for r in taken:
			if (r as Rect2).intersects(rect):
				ok = false
				break
		if not ok:
			continue
		taken.append(rect)
		settle(item, Transform3D(basis, Vector3(cx - centre.x, s.position.y - box.position.y + 0.001, cz - centre.z)), 0.0)
		return


func receive(item: RigidBody3D, velocity: Vector3) -> void:
	for z in _zones:
		if z.accepts(item.global_position):
			z.store(item)
			return
	if cabin.has_point(to_local(item.global_position)):
		_drop_in_cabin(item, velocity)
	else:
		throw_free(item, velocity)


## L'objet lâché dans l'habitacle tombe vraiment : il part avec la vitesse de la main
## (par rapport à la voiture), se couche en tombant, rebondit puis glisse.
func _drop_in_cabin(item: RigidBody3D, velocity := Vector3.ZERO) -> void:
	item.reparent(self, true)
	item.freeze = true
	item.collision_layer = 0
	item.collision_mask = 0
	var grab := item.get_node_or_null("Grab") as VRPickable
	var held_basis := item.basis
	var long_dir := _long_axis_dir(grab, item.basis)
	item.basis = lying_basis(grab, long_dir, Vector3.UP)
	var rel := velocity
	if _car:
		var bs := PhysicsServer3D.body_get_direct_state(_car.get_rid())
		var com := _car.global_position + (bs.center_of_mass if bs else Vector3.ZERO)
		rel -= _car.linear_velocity + _car.angular_velocity.cross(item.global_position - com)
	var st := ItemPhysics.begin(item, true, global_basis.orthonormalized().inverse() * rel.limit_length(6.0))
	st["blend_from"] = held_basis
	st["blend_t"] = 0.0
	ItemPhysics.apply(item, st)


func _physics_process(delta: float) -> void:
	var g := ItemPhysics.apparent_gravity(self, _car, delta)
	var states: Array = []
	var bodies: Array[RigidBody3D] = []
	for c in get_children():
		if not c is RigidBody3D:
			continue
		var item := c as RigidBody3D
		var grab := item.get_node_or_null("Grab") as VRPickable
		if grab:
			grab.enabled = true   # objet en vrac : toujours attrapable
			if grab.is_grabbed():
				continue
		if item.has_meta("rest_xf"):
			hold(item)   # pose animée en cours
			if anim_done(item):
				item.remove_meta("rest_xf")
				ItemPhysics.begin(item)
			continue
		if not item_physics:
			continue
		var st := ItemPhysics.get_state(item)
		if st.is_empty():
			st = ItemPhysics.begin(item)
		var prev: Vector3 = st["pos"]
		var old_yaw: float = st["yaw"]
		var idx := _support_index(st["pos"])
		var sy := surfaces[idx].position.y if idx >= 0 else cabin.position.y + 0.05
		var mu := surface_friction[idx] if idx >= 0 and idx < surface_friction.size() else 1.0
		ItemPhysics.integrate(st, g, delta, sy, mu)
		if idx >= 0 and idx < surface_walls.size() and not st["air"]:
			var s: AABB = surfaces[idx]
			ItemPhysics.collide_bounds(st, Vector2(s.position.x, s.position.z), Vector2(s.end.x, s.end.z), surface_walls[idx])
		ItemPhysics.collide_bounds(st, Vector2(cabin.position.x, cabin.position.z), Vector2(cabin.end.x, cabin.end.z), 15)
		ItemPhysics.collide_obstacles(st, prev, obstacles)
		# il ne tourne sur lui-même que s'il a la place (sinon ses bouts traverseraient)
		var lo := Vector2(cabin.position.x, cabin.position.z)
		var hi := Vector2(cabin.end.x, cabin.end.z)
		if ItemPhysics.obstacle_penetration(st, obstacles) > 0.002 or absf(float(st["yaw"]) - old_yaw) > 1e-6:
			var y_now: float = st["yaw"]
			ItemPhysics.keep_yaw_if_fits(st, old_yaw, lo, hi, obstacles)
			if float(st["yaw"]) != y_now:
				ItemPhysics.collide_obstacles(st, prev, obstacles)
		states.append(st)
		bodies.append(item)
	ItemPhysics.separate(states)
	for st2 in states:   # la séparation entre objets ne doit pas les pousser dans un siège ni dehors
		ItemPhysics.collide_obstacles(st2, st2["pos"], obstacles)
		ItemPhysics.collide_bounds(st2, Vector2(cabin.position.x, cabin.position.z), Vector2(cabin.end.x, cabin.end.z), 15)
	for k in bodies.size():
		_apply_blended(bodies[k], states[k], delta)


## Surface la plus haute sous le centre de l'objet (et pas au-dessus de lui), ou -1.
func _support_index(p: Vector3) -> int:
	var best := -1
	var best_y := -INF
	for i in surfaces.size():
		var s := surfaces[i]
		if p.x >= s.position.x and p.x <= s.end.x and p.z >= s.position.z and p.z <= s.end.z:
			if s.position.y <= p.y + 0.02 and s.position.y > best_y:
				best_y = s.position.y
				best = i
	return best


## Applique l'état ; juste après un lâcher, l'orientation passe en douceur de celle de
## la main à l'objet couché.
static func _apply_blended(item: RigidBody3D, st: Dictionary, delta: float) -> void:
	ItemPhysics.apply(item, st)
	if st.has("blend_from"):
		var t: float = minf(float(st["blend_t"]) + delta / 0.3, 1.0)
		st["blend_t"] = t
		var from: Basis = st["blend_from"]
		item.basis = from.orthonormalized().slerp(item.basis.orthonormalized(), smoothstep(0.0, 1.0, t))
		if t >= 1.0:
			st.erase("blend_from")


static func anim_done(item: RigidBody3D) -> bool:
	if not item.has_meta("anim_dur"):
		return true
	var dur: float = item.get_meta("anim_dur")
	return dur <= 0.0 or Time.get_ticks_msec() / 1000.0 - float(item.get_meta("anim_t0")) >= dur


## Le véhicule (RigidBody3D) qui porte ce noeud, ou null.
static func find_vehicle(n: Node) -> RigidBody3D:
	while n:
		if n is VehicleBody3D:
			return n as RigidBody3D
		n = n.get_parent()
	return null


## Pose un objet rangé à `target` (repère de son parent), avec une petite animation.
## Un RigidBody3D gelé garde sinon sa position MONDE quand la voiture bouge :
## son parent doit appeler hold() à chaque pas physique pour qu'il suive.
static func settle(item: RigidBody3D, target: Transform3D, duration: float, fall := false) -> void:
	item.set_meta("rest_xf", target)
	item.set_meta("anim_from", item.transform)
	item.set_meta("anim_t0", Time.get_ticks_msec() / 1000.0)
	item.set_meta("anim_dur", maxf(duration, 0.0))
	item.set_meta("anim_fall", fall)
	hold(item)


## Sort l'objet du moteur physique tant que c'est nous qui le plaçons (rangé, posé dans
## la voiture, tenu en main, dans le contact...). Sinon, un corps gelé est remis à sa
## position MONDE du pas précédent après chaque pas physique : quand la voiture roule, il
## traîne derrière elle (24 cm à 50 km/h) et semble traverser dossiers et console.
## À rappeler après un reparentage (entrer dans l'arbre remet le corps dans l'espace).
static func pin_body(item: RigidBody3D) -> void:
	var rid := item.get_rid()
	if PhysicsServer3D.body_get_space(rid).is_valid():
		PhysicsServer3D.body_set_space(rid, RID())


## Remet l'objet dans le moteur physique (objet jeté dehors).
static func unpin_body(item: RigidBody3D) -> void:
	var rid := item.get_rid()
	if not PhysicsServer3D.body_get_space(rid).is_valid() and item.is_inside_tree():
		PhysicsServer3D.body_set_space(rid, item.get_world_3d().space)
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, item.global_transform)


static func hold(item: RigidBody3D) -> void:
	pin_body(item)
	if not item.freeze or not item.has_meta("rest_xf"):
		return
	var grab := item.get_node_or_null("Grab") as VRPickable
	if grab and grab.is_grabbed():
		return
	var rest: Transform3D = item.get_meta("rest_xf")
	var dur: float = item.get_meta("anim_dur")
	var k := 1.0
	if dur > 0.0:
		k = clampf((Time.get_ticks_msec() / 1000.0 - float(item.get_meta("anim_t0"))) / dur, 0.0, 1.0)
	if k >= 1.0:
		item.transform = rest
		return
	var e := k * k if item.get_meta("anim_fall") else 1.0 - (1.0 - k) * (1.0 - k)
	var from: Transform3D = item.get_meta("anim_from")
	item.transform = from.interpolate_with(rest, e)


## Objet libre (jeté par la fenêtre) : physique normale, disparaît après un moment.
static func throw_free(item: RigidBody3D, velocity: Vector3) -> void:
	var tree := item.get_tree()
	var parent: Node = tree.current_scene
	var road := tree.get_first_node_in_group("road_generator")
	if road and road.has_method("sample_ahead"):
		var smp: Dictionary = road.sample_ahead(item.global_position, 0.0)
		if smp.get("found", false):
			parent = smp["chunk"]   # suit le recentrage du monde et disparaît avec le tronçon
	item.reparent(parent, true)
	item.top_level = false
	unpin_body(item)
	var grab := item.get_node_or_null("Grab") as VRPickable
	if grab:
		grab.enabled = true
	item.collision_layer = ITEM_LAYER
	item.collision_mask = 1
	item.continuous_cd = true
	item.freeze = false
	item.linear_velocity = velocity
	item.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	var token := randi()
	item.set_meta("free_timer", token)
	tree.create_timer(40.0).timeout.connect(func():
		if is_instance_valid(item) and item.get_meta("free_timer", -1) == token:
			item.queue_free())


# --- Outils d'orientation --------------------------------------------------------

## Base qui couche l'objet : grand côté -> long_dir, petit côté (ou rest_up_axis) -> up.
static func lying_basis(grab: VRPickable, long_dir: Vector3, up: Vector3) -> Basis:
	var size := grab.get_local_aabb().size
	var axes := [0, 1, 2]
	var up_i: int = grab.rest_up_axis
	if up_i < 0:
		up_i = 0
		for i in 3:
			if size[i] < size[up_i]:
				up_i = i
	axes.erase(up_i)
	var long_i: int = axes[0] if size[axes[0]] >= size[axes[1]] else axes[1]
	axes.erase(long_i)
	var other_i: int = axes[0]
	long_dir = (long_dir - up * long_dir.dot(up)).normalized()
	if long_dir.length_squared() < 0.5:
		long_dir = up.cross(Vector3.FORWARD).normalized()
	var cols := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	cols[long_i] = long_dir
	cols[up_i] = up
	# repère direct : l'axe restant = produit vectoriel dans l'ordre cyclique
	if (long_i + 1) % 3 == up_i:
		cols[other_i] = long_dir.cross(up)
	else:
		cols[other_i] = up.cross(long_dir)
	return Basis(cols[0], cols[1], cols[2])


## AABB de `box` (repère objet) une fois tournée par `basis`.
static func rotated_aabb(box: AABB, basis: Basis) -> AABB:
	return Transform3D(basis, Vector3.ZERO) * box


static func _long_axis_dir(grab: VRPickable, basis: Basis) -> Vector3:
	var size := grab.get_local_aabb().size
	var li := 0
	for i in 3:
		if size[i] > size[li]:
			li = i
	return basis[li]
