class_name VRHingeInteractable
extends VRInteractable
## Pièce montée sur charnière (porte, boîte à gants, accoudoir...).
## Le noeud tourne autour de `hinge_axis` (exprimé dans l'espace du parent),
## en suivant la main qui la tient. Bouton A/X près de la pièce = ouvrir/fermer.

signal opened
signal closed

@export var hinge_axis := Vector3.UP
## Angle min/max en degrés (l'angle fermé, 0, doit être compris dedans).
@export_range(-180.0, 180.0) var min_angle_deg := 0.0
@export_range(-180.0, 180.0) var max_angle_deg := 70.0
## En dessous de cet angle, la pièce relâchée se referme toute seule.
@export var snap_closed_deg := 8.0
## Vitesse d'ouverture/fermeture automatique (degrés/s).
@export var auto_speed_deg := 220.0
## Angle au démarrage (degrés).
@export var initial_angle_deg := 0.0

var angle := 0.0   # radians

var _rest_basis: Basis
var _grab_hand_angle := 0.0
var _grab_start_angle := 0.0
var _target_angle = null
var _was_open := false


func _ready() -> void:
	super._ready()
	_rest_basis = transform.basis
	if initial_angle_deg != 0.0:
		_set_angle(deg_to_rad(initial_angle_deg))


func get_open_angle() -> float:
	## Angle "ouvert" = la borne la plus éloignée de 0.
	return deg_to_rad(max_angle_deg if absf(max_angle_deg) >= absf(min_angle_deg) else min_angle_deg)


func is_open() -> bool:
	return absf(angle) > deg_to_rad(snap_closed_deg)


func toggle() -> void:
	if is_grabbed():
		return
	_target_angle = 0.0 if is_open() else get_open_angle()


func open() -> void:
	_target_angle = get_open_angle()


func close() -> void:
	_target_angle = 0.0


## Place la pièce à un angle donné (degrés), instantanément ou en douceur.
func set_angle_deg(value: float, instant := false) -> void:
	if instant:
		_target_angle = null
		_set_angle(deg_to_rad(value))
	else:
		_target_angle = deg_to_rad(value)


func _on_grab_begin(hand: Node3D) -> void:
	_target_angle = null
	var a = _hand_angle(hand.global_position)
	_grab_hand_angle = a if a != null else 0.0
	_grab_start_angle = angle


func _on_grab_update(hand: Node3D) -> void:
	var a = _hand_angle(hand.global_position)
	if a == null:
		return
	var delta := wrapf(a - _grab_hand_angle, -PI, PI)
	_set_angle(_grab_start_angle + delta)


func _on_grab_end(_hand: Node3D) -> void:
	if not is_grabbed() and absf(angle) < deg_to_rad(snap_closed_deg):
		_target_angle = 0.0


func _physics_process(delta: float) -> void:
	if _target_angle != null and not is_grabbed():
		_set_angle(move_toward(angle, _target_angle, deg_to_rad(auto_speed_deg) * delta))
		if is_equal_approx(angle, _target_angle):
			_target_angle = null


func _set_angle(value: float) -> void:
	angle = clampf(value, deg_to_rad(minf(min_angle_deg, max_angle_deg)), deg_to_rad(maxf(min_angle_deg, max_angle_deg)))
	transform.basis = Basis(hinge_axis.normalized(), angle) * _rest_basis
	var now_open := is_open()
	if now_open != _was_open:
		_was_open = now_open
		if now_open:
			opened.emit()
		else:
			closed.emit()


## Angle de la main autour de l'axe de la charnière (null si trop près de l'axe).
func _hand_angle(global_point: Vector3):
	var parent_xf: Transform3D = get_parent().global_transform if get_parent() is Node3D else Transform3D.IDENTITY
	var p := parent_xf.affine_inverse() * global_point - position
	var axis := hinge_axis.normalized()
	p -= axis * p.dot(axis)
	if p.length() < 0.03:
		return null
	var ref := Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var u := axis.cross(ref).normalized()
	var v := axis.cross(u)
	return atan2(p.dot(v), p.dot(u))
