class_name VRNotchedLever
extends VRHingeInteractable
## Levier à crans (levier de vitesse, comodo...).
## Pendant la saisie, il suit la main et "clique" sur le cran le plus proche ;
## relâché, il se cale sur ce cran. A/X près du levier = cran suivant.

signal notch_changed(index: int)

## Angle de chaque cran (degrés), dans l'ordre.
@export var notch_angles_deg := PackedFloat32Array([0.0])
@export var notch_labels := PackedStringArray()
@export var initial_notch := 0

var notch := 0


func _ready() -> void:
	snap_closed_deg = 0.0
	if notch_angles_deg.size() > 0:
		min_angle_deg = Array(notch_angles_deg).min()
		max_angle_deg = Array(notch_angles_deg).max()
	super._ready()
	notch = clampi(initial_notch, 0, notch_angles_deg.size() - 1)
	_set_angle(deg_to_rad(notch_angles_deg[notch]))


func get_notch_label() -> String:
	return notch_labels[notch] if notch < notch_labels.size() else str(notch)


func set_notch(index: int, instant := false) -> void:
	index = clampi(index, 0, notch_angles_deg.size() - 1)
	var changed := index != notch
	notch = index
	set_angle_deg(notch_angles_deg[index], instant)
	if changed:
		notch_changed.emit(index)


func step(direction: int) -> void:
	set_notch(notch + direction)


func toggle() -> void:
	if not is_grabbed():
		set_notch((notch + 1) % notch_angles_deg.size())


func _on_grab_update(hand: Node3D) -> void:
	super._on_grab_update(hand)
	var nearest := _nearest_notch(angle)
	if nearest != notch:
		notch = nearest
		notch_changed.emit(notch)
		if hand.has_method("pulse"):
			hand.pulse(0.35, 0.03)   # "clic" du cran


func _on_grab_end(_hand: Node3D) -> void:
	if not is_grabbed():
		set_angle_deg(notch_angles_deg[notch])


func _nearest_notch(a: float) -> int:
	var best := 0
	for i in notch_angles_deg.size():
		if absf(deg_to_rad(notch_angles_deg[i]) - a) < absf(deg_to_rad(notch_angles_deg[best]) - a):
			best = i
	return best
