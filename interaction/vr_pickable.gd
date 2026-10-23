class_name VRPickable
extends VRInteractable
## Rend attrapable l'objet parent (un RigidBody3D) à la main (VR) ou à la souris.
##
## Structure attendue :   RigidBody3D (l'objet)
##                         ├ Model (meshes)
##                         ├ CollisionShape3D (utilisée seulement quand on le jette dehors)
##                         └ Grab  <- ce script
## Pendant la saisie, l'objet suit la main. Au relâchement, le CarStorage le plus
## proche décide : rangement (boîte à gants, vide-poche...), chute dans l'habitacle,
## ou objet jeté par la fenêtre (physique libre).

## Nom affiché (aide, débogage).
@export var item_name := ""
## Axe local (0 = X, 1 = Y, 2 = Z) qui doit rester vers le haut quand l'objet est posé.
## -1 = automatique (le plus petit côté vers le haut : l'objet est posé à plat).
@export_range(-1, 2) var rest_up_axis := -1

var item: RigidBody3D
var hand_velocity := Vector3.ZERO

var _active_hand: Node3D
var _offset := Transform3D.IDENTITY
var _last_pos := Vector3.ZERO
var _local_aabb: AABB
var _aabb_ready := false


func _ready() -> void:
	item = get_parent() as RigidBody3D
	if mesh_root == null:
		mesh_root = item
	highlight_distance = 0.14
	grab_distance = 0.08
	outline_width = 0.0025
	pick_bonus = 0.02   # devant les pièces de la voiture quand c'est ambigu
	super._ready()


## Boîte englobante des meshes de l'objet, dans le repère de l'objet.
func get_local_aabb() -> AABB:
	if not _aabb_ready:
		_aabb_ready = true
		var inv := item.global_transform.affine_inverse()
		var first := true
		for mi in item.find_children("*", "MeshInstance3D", true, false):
			if mi.has_meta("_vr_outline"):
				continue
			var box: AABB = (inv * (mi as MeshInstance3D).global_transform) * (mi as MeshInstance3D).get_aabb()
			_local_aabb = box if first else _local_aabb.merge(box)
			first = false
	return _local_aabb


func _on_grab_begin(hand: Node3D) -> void:
	_take(hand)


func _on_grab_update(hand: Node3D) -> void:
	if hand != _active_hand:
		return
	var xf := hand.global_transform * _offset
	var dt := get_physics_process_delta_time()
	hand_velocity = hand_velocity.lerp((xf.origin - _last_pos) / maxf(dt, 0.001), 0.5)
	_last_pos = xf.origin
	item.global_transform = xf


func _on_grab_end(hand: Node3D) -> void:
	if hand != _active_hand:
		return
	if is_grabbed():
		_take(_grab_hands[-1])   # l'autre main reprend l'objet
		return
	_active_hand = null
	item.top_level = false
	var storage := _nearest_storage()
	if storage:
		storage.receive(item, hand_velocity)
	else:
		CarStorage.throw_free(item, hand_velocity)


func _take(hand: Node3D) -> void:
	_active_hand = hand
	var zone := item.get_parent() as StorageZone
	if zone:
		zone.on_item_taken(item)
	item.freeze = true
	item.collision_layer = 0
	item.collision_mask = 0
	item.linear_velocity = Vector3.ZERO
	item.angular_velocity = Vector3.ZERO
	if item.has_meta("free_timer"):
		item.remove_meta("free_timer")
	if item.has_meta("rest_xf"):
		item.remove_meta("rest_xf")
	item.top_level = true
	_offset = hand.global_transform.affine_inverse() * item.global_transform
	_last_pos = item.global_position
	hand_velocity = Vector3.ZERO


func _nearest_storage() -> CarStorage:
	var best: CarStorage = null
	var best_d := INF
	for s in get_tree().get_nodes_in_group(CarStorage.GROUP):
		var d := (s as Node3D).global_position.distance_to(item.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best if best_d < 6.0 else null
