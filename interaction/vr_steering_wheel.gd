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
## Jante mesurée sur les maillages : [rayon du cercle central, demi-épaisseur, hauteur
## le long de la colonne] (vide tant que les maillages ne sont pas là).
var _rim: Array = []


func _ready() -> void:
	super._ready()
	_rest_basis = transform.basis


## Distance à la jante (anneau) et non à la boîte englobante du volant : la boîte
## couvrait tout le disque et débordait sur le contact à clé, juste à côté, dont la clé
## devenait presque impossible à saisir.
func get_distance_to(global_point: Vector3) -> float:
	if _rim.is_empty():
		_measure_rim()
		if _rim.is_empty():
			return super.get_distance_to(global_point)
	var axis := column_axis.normalized()
	var p := _parent_xf().affine_inverse() * global_point - position
	var h := p.dot(axis) - float(_rim[2])
	var rho := (p - axis * p.dot(axis)).length()
	return maxf(Vector2(rho - float(_rim[0]), h).length() - float(_rim[1]), 0.0)


func _parent_xf() -> Transform3D:
	return get_parent().global_transform if get_parent() is Node3D else Transform3D.IDENTITY


## Rayon et épaisseur de la jante, d'après les sommets les plus éloignés de la colonne.
func _measure_rim() -> void:
	_ensure_built()
	var axis := column_axis.normalized()
	var inv := _parent_xf().affine_inverse()
	var pts: Array[Vector2] = []   # (distance à la colonne, hauteur)
	var max_rho := 0.0
	for m in _meshes:
		if not is_instance_valid(m) or m.mesh == null:
			continue
		var xf := inv * m.global_transform
		for v in m.mesh.get_faces():
			var p: Vector3 = xf * v - position
			var h := p.dot(axis)
			var rho := (p - axis * h).length()
			pts.append(Vector2(rho, h))
			max_rho = maxf(max_rho, rho)
	if max_rho < 0.05:
		return
	var lo := INF
	var h_sum := 0.0
	var n := 0
	for q in pts:
		if q.x > max_rho * 0.8:   # sommets de la jante (pas les branches ni le moyeu)
			lo = minf(lo, q.x)
			h_sum += q.y
			n += 1
	var half := maxf((max_rho - lo) * 0.5, 0.012)
	_rim = [max_rho - half, half, h_sum / n]


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
