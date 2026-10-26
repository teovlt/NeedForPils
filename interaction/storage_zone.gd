@icon("res://addons/godot-xr-tools/editor/icons/node.svg")
class_name StorageZone
extends Node3D
## Compartiment de rangement (boîte à gants, vide-poche, accoudoir...) ou support (GPS).
## L'origine du noeud = centre du fond ; la boîte va de -size.x/2 à +size.x/2,
## de 0 à size.y (vers le haut), de -size.z/2 à +size.z/2.
## Les objets (RigidBody3D + VRPickable) placés comme enfants y sont rangés au démarrage.

@export var zone_name := ""
@export var size := Vector3(0.3, 0.15, 0.3)
## Charnière qui ferme le compartiment : les objets ne sont attrapables qu'ouvert.
@export var access_hinge: NodePath
@export var min_open_deg := 25.0
## Support exact (GPS) : l'objet se cale sur l'origine du noeud, orientation comprise.
@export var exact_snap := false
## Marge (m) autour de la boîte pour accepter un objet relâché.
@export var accept_margin := 0.07
## Peut recevoir des objets lors du rangement aléatoire de début de partie
## (faux pour le support du GPS, qui garde son objet).
@export var random_fill := true
## Les objets rangés bougent (glissent, roulent, sautillent) dans le compartiment.
@export var item_physics := true
## Adhérence du fond du compartiment.
@export var floor_friction := 0.8

var _hinge: VRHingeInteractable
var _car: RigidBody3D


func _ready() -> void:
	_hinge = get_node_or_null(access_hinge) as VRHingeInteractable
	# Range proprement les objets placés dans la scène.
	for c in get_children():
		if c is RigidBody3D:
			_place(c as RigidBody3D, false)


func _physics_process(delta: float) -> void:
	var open := is_accessible()
	if _car == null:
		_car = CarStorage.find_vehicle(self)
	var g := ItemPhysics.apparent_gravity(self, _car, delta) if item_physics and not exact_snap else Vector3.ZERO
	var states: Array = []
	var bodies: Array[RigidBody3D] = []
	for c in get_children():
		if not c is RigidBody3D:
			continue
		var item := c as RigidBody3D
		var grab := item.get_node_or_null("Grab") as VRPickable
		if grab:
			grab.enabled = open
			if grab.is_grabbed():
				continue
		if exact_snap or not item_physics:
			CarStorage.hold(item)
			continue
		if item.has_meta("rest_xf"):
			CarStorage.hold(item)   # pose animée en cours
			if CarStorage.anim_done(item):
				item.remove_meta("rest_xf")
				ItemPhysics.begin(item)
			continue
		# les objets bougent dans le compartiment (freinage, virages, bosses)
		var st := ItemPhysics.get_state(item)
		if st.is_empty():
			st = ItemPhysics.begin(item)
		var old_yaw: float = st["yaw"]
		ItemPhysics.integrate(st, g, delta, 0.0, floor_friction)
		var lo := Vector2(-size.x, -size.z) * 0.5
		var hi := Vector2(size.x, size.z) * 0.5
		ItemPhysics.keep_yaw_if_fits(st, old_yaw, lo, hi)
		ItemPhysics.collide_bounds(st, lo, hi, 15)
		# couvercle fermé : ils ne sortent pas par le haut
		var top := size.y if open else size.y - float((st["half"] as Vector3).y) * 2.0
		var pos: Vector3 = st["pos"]
		if pos.y > maxf(top, 0.0):
			pos.y = maxf(top, 0.0)
			var v: Vector3 = st["vel"]
			v.y = minf(v.y, 0.0)
			st["vel"] = v
			st["pos"] = pos
		states.append(st)
		bodies.append(item)
	ItemPhysics.separate(states)
	# la séparation ne doit pas pousser un objet à travers les parois du compartiment
	for st2 in states:
		ItemPhysics.collide_bounds(st2, Vector2(-size.x, -size.z) * 0.5, Vector2(size.x, size.z) * 0.5, 15)
	for k in bodies.size():
		ItemPhysics.apply(bodies[k], states[k])


func is_accessible() -> bool:
	return _hinge == null or absf(_hinge.angle) >= deg_to_rad(min_open_deg)


## Vrai si la position (monde) est dans la zone (avec marge).
func accepts(world_pos: Vector3) -> bool:
	if not is_accessible():
		return false
	var p := to_local(world_pos)
	if exact_snap:
		return p.length() < size.length() * 0.5 + accept_margin
	var m := accept_margin
	return absf(p.x) <= size.x * 0.5 + m and absf(p.z) <= size.z * 0.5 + m and p.y >= -m and p.y <= size.y + m * 2.0


func store(item: RigidBody3D) -> void:
	_place(item, true)


func on_item_taken(_item: RigidBody3D) -> void:
	pass


func _place(item: RigidBody3D, animate: bool) -> void:
	if item.get_parent() != self:
		item.reparent(self, true)
	item.freeze = true
	item.collision_layer = 0
	item.collision_mask = 0
	var target: Transform3D
	if exact_snap:
		target = Transform3D.IDENTITY
	else:
		var grab := item.get_node_or_null("Grab") as VRPickable
		# Objet couché à plat, son grand côté aligné sur le grand côté du compartiment.
		var long_dir := Vector3.RIGHT if size.x >= size.z else Vector3.BACK
		var basis := CarStorage.lying_basis(grab, long_dir, Vector3.UP)
		var box := CarStorage.rotated_aabb(grab.get_local_aabb(), basis)
		var p := item.position
		var half := box.size * 0.5
		var centre := box.position + half
		p.x = clampf(p.x, -size.x * 0.5 + half.x - centre.x, size.x * 0.5 - half.x - centre.x) if half.x * 2.0 < size.x else -centre.x
		p.z = clampf(p.z, -size.z * 0.5 + half.z - centre.z, size.z * 0.5 - half.z - centre.z) if half.z * 2.0 < size.z else -centre.z
		p.y = -box.position.y + 0.001
		target = Transform3D(basis, p)
	CarStorage.settle(item, target, 0.18 if animate else 0.0)


## Range `item` à une place libre tirée au hasard dans le compartiment.
## `taken` : rectangles (x, z en repère de la zone) déjà occupés. Renvoie false s'il n'y a pas la place.
func try_random_place(item: RigidBody3D, rng: RandomNumberGenerator, taken: Array) -> bool:
	if exact_snap:
		return false
	var grab := item.get_node_or_null("Grab") as VRPickable
	if grab == null:
		return false
	var long_dir := Vector3.RIGHT if size.x >= size.z else Vector3.BACK
	if rng.randf() < 0.5:
		long_dir = -long_dir   # objet tourné d'un demi-tour au hasard
	var basis := CarStorage.lying_basis(grab, long_dir, Vector3.UP)
	var box := CarStorage.rotated_aabb(grab.get_local_aabb(), basis)
	var gap := 0.006
	if box.size.x + gap > size.x or box.size.z + gap > size.z or box.size.y > size.y + 0.03:
		return false
	var half := box.size * 0.5
	var centre := box.position + half
	for _i in 24:
		var cx := rng.randf_range(-size.x * 0.5 + half.x, size.x * 0.5 - half.x)
		var cz := rng.randf_range(-size.z * 0.5 + half.z, size.z * 0.5 - half.z)
		var rect := Rect2(cx - half.x - gap, cz - half.z - gap, box.size.x + gap * 2.0, box.size.z + gap * 2.0)
		var free := true
		for r in taken:
			if (r as Rect2).intersects(rect):
				free = false
				break
		if not free:
			continue
		taken.append(rect)
		if item.get_parent() != self:
			item.reparent(self, false)
		item.freeze = true
		item.collision_layer = 0
		item.collision_mask = 0
		CarStorage.settle(item, Transform3D(basis, Vector3(cx - centre.x, -box.position.y + 0.001, cz - centre.z)), 0.0)
		return true
	return false
