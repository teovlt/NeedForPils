class_name VRHandInteractor
extends Node3D
## À placer comme enfant d'un XRController3D.
## Cherche l'objet VRInteractable le plus proche, le fait s'illuminer,
## le saisit avec "grip" et l'ouvre/ferme avec A/X (si l'objet a toggle()).

const GROUP := "vr_hands"

@export var grip_action := "grip"
@export var toggle_action := "ax_button"
@export var grab_threshold := 0.6
@export var release_threshold := 0.35
@export var haptics := true

var controller: XRController3D
var hovered: VRInteractable
var held: VRInteractable

var _grip_down := false
var _toggle_down := false
var _hover_grabbable := false
var _pending: VRInteractable      # saisie en attente (défoncé : gestes plus lents)
var _pending_t := 0.0
var _skel: Skeleton3D
var _tip_bone := -1
var _palm_bone := -1
## Tests sans casque : [bout de l'index, paume] imposés (monde). Vide = vraie main.
var debug_points: Array = []


func _ready() -> void:
	add_to_group(GROUP)
	controller = get_parent() as XRController3D


func is_left() -> bool:
	return controller != null and controller.tracker == &"left_hand"


func get_trigger() -> float:
	if controller == null or not controller.get_has_tracking_data():
		return 0.0
	return controller.get_float("trigger")


# --- Toucher (sans bouton) -------------------------------------------------------
# Klaxon, comodos et touches de la radio réagissent au contact de la main : ils lisent
# ces positions (os de la main XR Tools : Index_Tip_*, Palm_*).

## Vrai si la main peut toucher : suivie, et ne tient rien (sinon on klaxonnerait ou on
## bougerait un comodo en tenant le volant, un objet...).
func can_touch() -> bool:
	if held != null:
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
		_set_hover(null, -1.0)
		if held:
			_release()
		return

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
				pulse(0.4, 0.05)
			_toggle_down = toggle_held
		return

	# Recherche de l'objet interactif le plus proche.
	var best: VRInteractable = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(VRInteractable.GROUP):
		var it := n as VRInteractable
		if it == null or not it.enabled or not it.is_visible_in_tree():
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
			pulse(0.4, 0.05)
		_toggle_down = toggle_now
	else:
		_toggle_down = controller.is_button_pressed(toggle_action)


func _grab_now(it: VRInteractable) -> void:
	held = it
	_set_hover(null, -1.0)
	held.grab(self)
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
	if held and is_instance_valid(held):
		held.release(self)
	held = null


## Petite vibration de la manette.
func pulse(amplitude: float, duration: float) -> void:
	if haptics and controller:
		controller.trigger_haptic_pulse("haptic", 0.0, amplitude, duration, 0.0)
