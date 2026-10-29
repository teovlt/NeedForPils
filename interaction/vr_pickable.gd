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
## Coefficient de frottement de l'objet posé (glisse plus ou moins quand la voiture
## freine, accélère ou tourne). Multiplié par celui de la surface.
@export_range(0.05, 1.5) var friction := 0.45

## Objets qui acceptent qu'on leur lâche un autre objet dessus : try_receive(grab) -> bool.
const RECEIVERS := "item_receivers"

var item: RigidBody3D
var hand_velocity := Vector3.ZERO

var _active_hand: Node3D
var _offset := Transform3D.IDENTITY
var _last_pos := Vector3.ZERO
var _local_aabb: AABB
var _aabb_ready := false
var _lag_local := Transform3D.IDENTITY
var _lag_ready := false
var _prev_local := Vector3.ZERO
var _prev_ok := false
## Retard de l'objet sur la main (bloqué par une paroi) à l'image précédente (m).
var _lag := 0.0
## Vitesse mini (m/s) à laquelle l'objet resté en arrière rejoint la main : il glisse
## jusqu'à elle au lieu de s'y téléporter dès que le chemin est libre.
const CATCH_UP_SPEED := 3.0


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
## Objet rangé dans un compartiment ouvert : nettement prioritaire sur les pièces de la
## voiture autour (frein à main, boucles de ceinture, couvercle), dont les boîtes
## englobantes débordent devant l'ouverture et volaient la sélection.
func get_pick_bonus() -> float:
	var zone := item.get_parent() as StorageZone if item else null
	if zone and zone.is_accessible():
		return pick_bonus + 0.05
	return pick_bonus


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
	CarStorage.pin_body(item)
	var xf := _hand_xf(hand) * _offset
	var dt := get_physics_process_delta_time()
	# défoncé (joint) : l'objet suit la main avec du retard (calculé dans le repère de la
	# voiture, pour ne pas rester en arrière quand elle roule)
	var st := PillAddiction.stoned_level(get_tree())
	if st > 0.01:
		var frame := CarStorage.find_vehicle(item)
		var fx: Transform3D = frame.global_transform if frame else Transform3D.IDENTITY
		var target := fx.affine_inverse() * xf
		if not _lag_ready:
			_lag_local = target
			_lag_ready = true
		var w := 1.0 - exp(-lerpf(30.0, 5.0, st) * dt)
		_lag_local = _lag_local.interpolate_with(target, w)
		xf = fx * _lag_local
	else:
		_lag_ready = false
	# ne traverse pas l'intérieur de la voiture
	var storage := _nearest_storage()
	if storage:
		if not _prev_ok:
			_prev_local = storage.to_local(item.global_position)
			_prev_ok = true
		if _collides_while_held(xf):
			var target := xf.origin
			if _lag > 0.02:
				var from := storage.to_global(_prev_local)
				xf.origin = from + (target - from).limit_length(maxf(CATCH_UP_SPEED * dt, _lag * 0.3))
			xf = storage.constrain_held(self, xf, _prev_local)
			_lag = xf.origin.distance_to(target)
		else:
			_lag = 0.0
		_prev_local = storage.to_local(xf.origin)
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
	# partie à deux : lâcher rejoué pour l'autre joueur (les points de livraison l'ignorent)
	item.set_meta("net_remote", Net.applying_remote)
	# lâché sur un objet qui le prend (tête dans le grinder, pincée / filtre sur une
	# feuille à rouler...) : c'est lui qui s'en occupe
	for r in get_tree().get_nodes_in_group(RECEIVERS):
		if r != self and is_instance_valid(r) and r.call("try_receive", self):
			return
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
	ItemPhysics.stop(item)
	item.top_level = true
	CarStorage.pin_body(item)
	_offset = _hand_xf(hand).affine_inverse() * item.global_transform
	_last_pos = item.global_position
	_lag_ready = false
	_prev_ok = false
	_lag = 0.0
	hand_velocity = Vector3.ZERO


## L'objet tenu `old` est remplacé par `new` (feuille roulée -> joint) : les mains et
## les zones qui transmettaient les mouvements à `old` les transmettent à `new`.
static func replace_held(tree: SceneTree, old: VRInteractable, new: VRInteractable) -> void:
	for n in tree.get_nodes_in_group(VRInteractable.GROUP):
		var d = n.get("_held")
		if d is Dictionary:
			for k in d:
				if d[k] == old:
					d[k] = new
	for grp in [VRHandInteractor.GROUP, MouseHand.GROUP, NetRemoteHand.GROUP]:
		for h in tree.get_nodes_in_group(grp):
			if h.get("held") == old:
				h.set("held", new)
			if h.get("tip_held") == old:
				h.set("tip_held", new)


## Pose de la main qui tient l'objet : la main affichée en VR (elle bute sur la
## voiture, l'objet reste dedans), la main elle-même sinon.
func _hand_xf(hand: Node3D) -> Transform3D:
	if hand.has_method("visual_transform"):
		return hand.visual_transform()
	return hand.global_transform


## L'objet tenu bute-t-il sur l'intérieur de la voiture à cette position ? (la clé
## doit pouvoir entrer dans le contact, enfoncé dans le tableau de bord)
func _collides_while_held(_xf: Transform3D) -> bool:
	return true


func _nearest_storage() -> CarStorage:
	var best: CarStorage = null
	var best_d := INF
	for s in get_tree().get_nodes_in_group(CarStorage.GROUP):
		var d := (s as Node3D).global_position.distance_to(item.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best if best_d < 6.0 else null
