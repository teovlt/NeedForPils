class_name VRHandInteractor
extends Node3D
## À placer comme enfant d'un XRController3D.
## Cherche l'objet VRInteractable le plus proche, le fait s'illuminer,
## le saisit avec "grip" et l'ouvre/ferme avec A/X (si l'objet a toggle()).
## Les objets `grab_with_trigger` (pilules de la pochette) se prennent aussi du bout de
## l'index avec la gâchette : ils suivent alors le bout du doigt (`tip_hand`) tant que
## la gâchette reste enfoncée, et la gâchette ne sert plus d'accélérateur / de frein.
##
## Main affichée (XRToolsHand, sœur de ce nœud) :
## - elle ne traverse plus l'habitacle : deux sphères (paume, phalanges) avancent vers la
##   vraie main par petits pas et glissent le long des surfaces de la voiture (mêmes
##   collisions que les objets tenus, CarStorage.HELD_LAYER) ;
## - en saisissant une commande à accroche (`hand_snap` : volant, frein à main, levier de
##   vitesse, comodos), elle s'y accroche, poing refermé autour, et suit la commande.

const GROUP := "vr_hands"
## Mains qui appuient au toucher (klaxon, touches de la radio, comodos poussés du doigt) :
## les mains VR locales et celles de l'autre joueur en partie à deux (NetRemoteHand).
const TOUCH_GROUP := "touch_hands"

## Saisie (0), lâcher (1) ou action A/X (2) sur un objet : la partie à deux (NetSession)
## rejoue le geste chez l'autre joueur.
signal interacted(kind: int, target: VRInteractable)
## Pareil pour une prise du bout de l'index (gâchette).
signal tip_interacted(kind: int, target: VRInteractable)

@export var grip_action := "grip"
@export var toggle_action := "ax_button"
@export var grab_threshold := 0.6
@export var release_threshold := 0.35
@export var haptics := true

var controller: XRController3D
var hovered: VRInteractable
var held: VRInteractable

var _grip_down := false
var tip_hand: TipHand             # « main » placée au bout de l'index (prise à la gâchette)
var tip_held: VRInteractable      # objet tenu du bout de l'index
var _tip_hover: VRInteractable
var _tip_in_reach := false
var _trig_down := false
var _toggle_down := false
var _hover_grabbable := false
var _pending: VRInteractable      # saisie en attente (défoncé : gestes plus lents)
var _pending_t := 0.0
var _skel: Skeleton3D
var _tip_bone := -1
var _palm_bone := -1
## Tests sans casque : [bout de l'index, paume] imposés (monde). Vide = vraie main.
var debug_points: Array = []
## Tests sans casque : valeur de gâchette imposée (< 0 : vraie manette).
var debug_trigger := -1.0
## La main affichée bute sur l'intérieur de la voiture.
@export var hand_collision := true

const PALM_RADIUS := 0.03
const KNUCKLE_RADIUS := 0.024
const GRIP_POSE_RIGHT := "res://addons/godot-xr-tools/hands/animations/right/Grip Shaft.res"
const GRIP_POSE_LEFT := "res://addons/godot-xr-tools/hands/animations/left/Grip Shaft.res"

var _xr_hand: Node3D               # XRToolsHand affichée
var _free_target: Node3D           # pose de la main affichée (bloquée par la voiture)
var _snap_target: Node3D           # main accrochée à une commande
var _free_local := Vector3.ZERO    # position de la main affichée, repère de l'XROrigin
var _free_ok := false
var _sphere_offsets: Array[Vector3] = []
var _sphere_shapes: Array[SphereShape3D] = []
var _shrunk_shapes: Array[SphereShape3D] = []
var _query: PhysicsShapeQueryParameters3D
var _grip_pose: Resource


## Bout de l'index, utilisé comme une main par les objets pris à la gâchette.
class TipHand:
	extends Node3D
	var owner_hand
	func pulse(amplitude: float, duration: float) -> void:
		owner_hand.pulse(amplitude, duration)
	func is_left() -> bool:
		return owner_hand.is_left()
	func is_fingertip() -> bool:
		return true


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(TOUCH_GROUP)
	controller = get_parent() as XRController3D
	tip_hand = TipHand.new()
	tip_hand.name = "IndexTip"
	tip_hand.owner_hand = self
	tip_hand.top_level = true
	add_child(tip_hand)
	process_physics_priority = -80     # avant la main XR Tools (-70), qui lit nos cibles
	_setup_visual_hand.call_deferred()


func _setup_visual_hand() -> void:
	if controller == null:
		return
	for c in controller.get_children():
		if c != self and c.has_method("add_target_override"):
			_xr_hand = c
			break
	if _xr_hand == null:
		return
	_free_target = Node3D.new()
	_free_target.name = "VisualHandTarget"
	_free_target.top_level = true
	add_child(_free_target)
	_free_target.global_transform = global_transform
	_xr_hand.add_target_override(_free_target, 1)


## Pose de la main affichée (monde) : les objets tenus la suivent.
func visual_transform() -> Transform3D:
	if _free_target and hand_collision:
		return _free_target.global_transform
	return global_transform


## Main affichée : avance vers la vraie main sans traverser la voiture.
func _update_visual_hand() -> void:
	if _free_target == null:
		return
	var desired := global_transform
	if not hand_collision:
		_free_target.global_transform = desired
		return
	if _query == null and not _setup_hand_spheres():
		_free_target.global_transform = desired
		return
	var frame := _frame_xf()
	var basis := desired.basis
	var pos := desired.origin
	if _free_ok:
		var cur := frame * _free_local
		pos = cur
		# légèrement en contact (la voiture a bougé, la main a tourné) : toléré, sphères
		# réduites de 4 mm ; vraiment dedans : la main affichée reste où elle est
		if _hand_free(basis, cur, 0.004):
			var d := desired.origin - cur
			var n := clampi(int(ceil(d.length() / 0.01)), 1, 50)
			var step := d / n
			for i in n:
				if _hand_free(basis, pos + step):
					pos += step
					continue
				var moved := false
				for ax in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
					var sl: Vector3 = ax * step.dot(ax)
					if sl.length_squared() > 1e-10 and _hand_free(basis, pos + sl):
						pos += sl
						moved = true
				if not moved:
					break
		# vraie main bien plus loin (passée derrière une paroi, ou main coincée) : on la
		# rejoint si elle est dans un endroit libre
		if pos.distance_to(desired.origin) > 0.45 and _hand_free(basis, desired.origin):
			pos = desired.origin
	_free_local = frame.affine_inverse() * pos
	_free_ok = true
	_free_target.global_transform = Transform3D(basis, pos)


## Repère qui suit la voiture (l'XROrigin) : les pas de la main y sont calculés.
func _frame_xf() -> Transform3D:
	var o := get_parent()
	while o and not (o is XROrigin3D):
		o = o.get_parent()
	return (o as Node3D).global_transform if o else Transform3D.IDENTITY


func _setup_hand_spheres() -> bool:
	if not _find_bones() or _palm_bone < 0:
		return false
	var storage := get_tree().get_first_node_in_group(CarStorage.GROUP)
	if storage == null:
		return false
	storage.call("_ensure_held_collision")
	# os de la main dans le repère de la cible (la main XR Tools = cible * _transform)
	var hand_tr = _xr_hand.get("_transform")
	var to_target: Transform3D = hand_tr if hand_tr is Transform3D else Transform3D.IDENTITY
	var inv := (_xr_hand as Node3D).global_transform.affine_inverse()
	var palm := inv * (_skel.global_transform * _skel.get_bone_global_pose(_palm_bone).origin)
	var tip := inv * (_skel.global_transform * _skel.get_bone_global_pose(_tip_bone).origin)
	_sphere_offsets = [to_target * palm, to_target * palm.lerp(tip, 0.45)]
	for r in [PALM_RADIUS, KNUCKLE_RADIUS]:
		var sh := SphereShape3D.new()
		sh.radius = r
		_sphere_shapes.append(sh)
		var sm := SphereShape3D.new()
		sm.radius = r - 0.004
		_shrunk_shapes.append(sm)
	_query = PhysicsShapeQueryParameters3D.new()
	_query.collision_mask = CarStorage.HELD_LAYER
	_query.collide_with_areas = false
	_query.collide_with_bodies = true
	return true


func _hand_free(basis: Basis, pos: Vector3, shrink := 0.0) -> bool:
	var space := get_world_3d().direct_space_state
	var xf := Transform3D(basis, pos)
	for i in _sphere_offsets.size():
		var sh := _sphere_shapes[i]
		if shrink > 0.0:
			sh = _shrunk_shapes[i]
		_query.shape = sh
		_query.transform = Transform3D(Basis.IDENTITY, xf * _sphere_offsets[i])
		if not space.intersect_shape(_query, 1).is_empty():
			return false
	return true


## Accroche la main affichée à la commande saisie, poing refermé autour.
func _snap_to(it: VRInteractable) -> void:
	_unsnap()
	if _xr_hand == null:
		return
	var sx = it.get_hand_snap(global_transform)
	if sx == null:
		return
	_snap_target = Node3D.new()
	_snap_target.name = "HandSnap"
	it.add_child(_snap_target)
	_snap_target.global_transform = sx
	_xr_hand.add_target_override(_snap_target, 10)
	if _grip_pose == null:
		_grip_pose = XRToolsHandPoseSettings.new()
		var anim := load(GRIP_POSE_LEFT if is_left() else GRIP_POSE_RIGHT) as Animation
		_grip_pose.open_pose = anim
		_grip_pose.closed_pose = anim
	_xr_hand.add_pose_override(self, 10, _grip_pose)


## Main affichée (modèle XR Tools) pour la partie à deux : [transformation (monde),
## grip, gâchette, poing refermé sur une commande], ou [] sans main affichée.
func visual_state() -> Array:
	if _xr_hand == null or not is_instance_valid(_xr_hand):
		return []
	var tree := _xr_hand.get_node_or_null("AnimationTree") as AnimationTree
	var grip: float = tree.get("parameters/Grip/blend_amount") if tree else 0.0
	var trig: float = tree.get("parameters/Trigger/blend_amount") if tree else 0.0
	return [(_xr_hand as Node3D).global_transform, grip, trig, _snap_target != null]


func _unsnap() -> void:
	if _snap_target == null:
		return
	if _xr_hand:
		_xr_hand.remove_target_override(_snap_target)
		_xr_hand.remove_pose_override(self)
	if is_instance_valid(_snap_target):
		_snap_target.queue_free()
	_snap_target = null


func is_left() -> bool:
	return controller != null and controller.tracker == &"left_hand"


func get_trigger() -> float:
	if controller == null or not controller.get_has_tracking_data():
		return 0.0
	if tip_held or _tip_in_reach:
		return 0.0   # l'index prend une pilule : pas d'accélération ni de freinage
	return controller.get_float("trigger")


# --- Toucher (sans bouton) -------------------------------------------------------
# Klaxon, comodos et touches de la radio réagissent au contact de la main : ils lisent
# ces positions (os de la main XR Tools : Index_Tip_*, Palm_*).

## Vrai si la main peut toucher : suivie, et ne tient rien (sinon on klaxonnerait ou on
## bougerait un comodo en tenant le volant, un objet...).
func can_touch() -> bool:
	if held != null or tip_held != null:
		return false
	if not debug_points.is_empty():
		return true
	return controller != null and controller.get_has_tracking_data()


## Bout de l'index (monde).
func fingertip_position() -> Vector3:
	if not debug_points.is_empty():
		return debug_points[0]
	if _find_bones() and _tip_bone >= 0:
		return _skel.global_transform * _skel.get_bone_global_pose(_tip_bone).origin
	return global_transform * Vector3(0.0, -0.02, -0.12)


## Centre de la paume (monde).
func palm_position() -> Vector3:
	if not debug_points.is_empty():
		return debug_points[1] if debug_points.size() > 1 else Vector3(0, -1000, 0)
	if _find_bones() and _palm_bone >= 0:
		return _skel.global_transform * _skel.get_bone_global_pose(_palm_bone).origin
	return global_position


func _find_bones() -> bool:
	if _skel and is_instance_valid(_skel):
		return true
	if controller == null:
		return false
	for sk in controller.find_children("*", "Skeleton3D", true, false):
		var k := sk as Skeleton3D
		for i in k.get_bone_count():
			var n := k.get_bone_name(i).to_lower()
			if n.begins_with("index_tip"):
				_tip_bone = i
			elif n.begins_with("palm"):
				_palm_bone = i
		if _tip_bone >= 0:
			_skel = k
			return true
	return false


func is_button_pressed(action: StringName) -> bool:
	return controller != null and controller.get_has_tracking_data() and controller.is_button_pressed(action)


func _physics_process(_delta: float) -> void:
	if controller == null or not controller.get_has_tracking_data():
		if _free_target and not debug_points.is_empty():
			_update_visual_hand()   # tests sans casque
			return
		_set_hover(null, -1.0)
		if held:
			_release()
		if tip_held and debug_points.is_empty():
			_release_tip()
		return

	_update_visual_hand()
	_update_trigger_grab()
	var grip := controller.get_float(grip_action)
	var grip_pressed := false
	if not _grip_down and grip > grab_threshold:
		_grip_down = true
		grip_pressed = true
	elif _grip_down and grip < release_threshold:
		_grip_down = false

	# Objet tenu : on le fait suivre la main jusqu'au relâchement.
	if held:
		if not _grip_down or not is_instance_valid(held) or not held.enabled:
			_release()
		else:
			held.grab_update(self)
			# A / X sur l'objet tenu (allumer le briquet, la cigarette...)
			var toggle_held := controller.is_button_pressed(toggle_action)
			if toggle_held and not _toggle_down and held.has_method("toggle"):
				held.toggle()
				interacted.emit(2, held)
				pulse(0.4, 0.05)
			_toggle_down = toggle_held
		return

	# Recherche de l'objet interactif le plus proche.
	var best: VRInteractable = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(VRInteractable.GROUP):
		var it := n as VRInteractable
		if it == null or not it.enabled or not it.is_visible_in_tree() or not it.accepts_hand(self):
			continue
		var d := it.get_distance_to(global_position)
		if d < it.highlight_distance and d - it.get_pick_bonus() < best_d - (best.get_pick_bonus() if best else 0.0):
			best = it
			best_d = d
	_set_hover(best, best_d)

	# saisie retardée en cours : il faut garder le grip sur le même objet
	if _pending:
		if not _grip_down or best != _pending:
			_pending = null
		else:
			_pending_t -= _delta
			if _pending_t <= 0.0:
				_pending = null
				_grab_now(best)
				return
	if best and best_d <= best.grab_distance:
		if grip_pressed:
			var wait := 0.45 * PillAddiction.stoned_level(get_tree())
			if wait > 0.03:
				_pending = best
				_pending_t = wait
			else:
				_grab_now(best)
				return
		var toggle_now := controller.is_button_pressed(toggle_action)
		if toggle_now and not _toggle_down and best.has_method("toggle"):
			best.toggle()
			interacted.emit(2, best)
			pulse(0.4, 0.05)
		_toggle_down = toggle_now
	else:
		_toggle_down = controller.is_button_pressed(toggle_action)


## Prise du bout de l'index à la gâchette (objets grab_with_trigger).
func _update_trigger_grab() -> void:
	tip_hand.global_transform = Transform3D(global_basis, fingertip_position())
	var trig := debug_trigger if debug_trigger >= 0.0 else (controller.get_float("trigger") if controller else 0.0)
	var trig_pressed := false
	if not _trig_down and trig > grab_threshold:
		_trig_down = true
		trig_pressed = true
	elif _trig_down and trig < release_threshold:
		_trig_down = false
	if tip_held:
		if not _trig_down or not is_instance_valid(tip_held) or not tip_held.enabled and not tip_held.is_grabbed():
			_release_tip()
		else:
			tip_held.grab_update(tip_hand)
		return
	var best: VRInteractable = null
	var best_d := INF
	if held == null:
		var tip := tip_hand.global_position
		for n in get_tree().get_nodes_in_group(VRInteractable.GROUP):
			var it := n as VRInteractable
			if it == null or not it.grab_with_trigger or not it.enabled or not it.is_visible_in_tree() or not it.accepts_hand(tip_hand):
				continue
			var d := it.get_distance_to(tip)
			if d < it.highlight_distance and d < best_d:
				best = it
				best_d = d
	if _tip_hover and _tip_hover != best and is_instance_valid(_tip_hover):
		_tip_hover.set_hand_distance(tip_hand, -1.0)
	_tip_hover = best
	_tip_in_reach = best != null and best_d <= best.grab_distance
	if best:
		best.set_hand_distance(tip_hand, best_d)
	if trig_pressed and _tip_in_reach:
		_tip_hover.set_hand_distance(tip_hand, -1.0)
		tip_held = best
		_tip_hover = null
		tip_held.grab(tip_hand)
		tip_interacted.emit(0, tip_held)
		pulse(0.4, 0.04)


func _release_tip() -> void:
	if tip_held and is_instance_valid(tip_held):
		tip_held.release(tip_hand)
		tip_interacted.emit(1, tip_held)
	tip_held = null


func _grab_now(it: VRInteractable) -> void:
	held = it
	_set_hover(null, -1.0)
	held.grab(self)
	interacted.emit(0, held)
	if it.hand_snap != 0:
		_snap_to(it)
	pulse(0.5, 0.06)


func _set_hover(target: VRInteractable, distance: float) -> void:
	if hovered and hovered != target and is_instance_valid(hovered):
		hovered.set_hand_distance(self, -1.0)
		_hover_grabbable = false
	hovered = target
	if hovered:
		hovered.set_hand_distance(self, distance)
		var grabbable := distance <= hovered.grab_distance
		if grabbable and not _hover_grabbable:
			pulse(0.15, 0.02)   # petit "tic" quand on peut saisir
		_hover_grabbable = grabbable


func _release() -> void:
	_unsnap()
	if held and is_instance_valid(held):
		held.release(self)
		interacted.emit(1, held)
	held = null


## Petite vibration de la manette.
func pulse(amplitude: float, duration: float) -> void:
	if haptics and controller:
		controller.trigger_haptic_pulse("haptic", 0.0, amplitude, duration, 0.0)
