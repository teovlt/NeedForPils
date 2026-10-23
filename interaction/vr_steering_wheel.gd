class_name VRSteeringWheel
extends VRInteractable
## Volant saisissable à une ou deux mains.
## Tourne autour de `column_axis` (espace du parent, orienté vers le conducteur).
## Angle positif = rotation anti-horaire vue du conducteur = tourner à gauche.

@export var column_axis := Vector3(0.0, 0.423, -0.906)
## Rotation maximale de chaque côté (degrés).
@export var max_rotation_deg := 270.0
## Vitesse de retour au centre quand on lâche le volant (degrés/s).
@export var return_speed_deg := 240.0

## Angle visé quand le volant n'est pas tenu (clavier, retour au centre...).
var input_target_angle := 0.0
var wheel_angle := 0.0   # radians

var _rest_basis: Basis
var _last_hand_angle := {}


func _ready() -> void:
	super._ready()
	_rest_basis = transform.basis


## Valeur de direction entre -1 (droite) et 1 (gauche).
func get_steer() -> float:
	return wheel_angle / deg_to_rad(max_rotation_deg)


func set_steer_input(value: float) -> void:
	input_target_angle = clampf(value, -1.0, 1.0) * deg_to_rad(max_rotation_deg)


func _on_grab_begin(hand: Node3D) -> void:
	_last_hand_angle[hand] = _hand_angle(hand.global_position)


func _on_grab_end(hand: Node3D) -> void:
	_last_hand_angle.erase(hand)


func _on_grab_update(hand: Node3D) -> void:
	var a = _hand_angle(hand.global_position)
	var last = _last_hand_angle.get(hand)
	_last_hand_angle[hand] = a
	if a == null or last == null:
		return
	# Chaque main contribue à part égale à la rotation.
	var delta := wrapf(a - last, -PI, PI) / float(_grab_hands.size())
	_apply_angle(wheel_angle + delta)


func _physics_process(delta: float) -> void:
	if not is_grabbed():
		_apply_angle(move_toward(wheel_angle, input_target_angle, deg_to_rad(return_speed_deg) * delta))


func _apply_angle(value: float) -> void:
	var limit := deg_to_rad(max_rotation_deg)
	wheel_angle = clampf(value, -limit, limit)
	transform.basis = Basis(column_axis.normalized(), wheel_angle) * _rest_basis


func _hand_angle(global_point: Vector3):
	var parent_xf: Transform3D = get_parent().global_transform if get_parent() is Node3D else Transform3D.IDENTITY
	var p := parent_xf.affine_inverse() * global_point - position
	var axis := column_axis.normalized()
	p -= axis * p.dot(axis)
	if p.length() < 0.04:   # main trop près du moyeu : angle instable
		return null
	var u := axis.cross(Vector3.RIGHT).normalized()
	var v := axis.cross(u)
	return atan2(p.dot(v), p.dot(u))
