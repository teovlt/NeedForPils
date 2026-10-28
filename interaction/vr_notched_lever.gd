class_name VRNotchedLever
extends VRHingeInteractable
## Levier à crans (levier de vitesse, comodo...).
## Pendant la saisie, il suit la main et "clique" sur le cran le plus proche ;
## relâché, il se cale sur ce cran. A/X près du levier = cran suivant.
## `push_by_touch` (comodos) : en VR, on le pousse aussi avec le doigt ou la main, sans
## le saisir : la main qui arrive contre lui le fait tourner devant elle (vers le haut
## ou le bas) ; dès qu'elle le quitte, il se cale sur le cran le plus proche.

signal notch_changed(index: int)

## Angle de chaque cran (degrés), dans l'ordre.
@export var notch_angles_deg := PackedFloat32Array([0.0])
@export var notch_labels := PackedStringArray()
@export var initial_notch := 0
## Se pousse au contact de la main VR, sans grip (comodos).
@export var push_by_touch := false

var notch := 0

# géométrie du levier autour de l'axe (calculée au démarrage depuis ses meshes)
var _touch_ready := false
var _rho := Vector2.ZERO        # distance à l'axe : min, max
var _h := Vector2.ZERO          # position le long de l'axe : min, max
var _half_thick := 0.01
var _arm_angle0 := 0.0          # angle (autour de l'axe) du levier au démarrage
var _angle0 := 0.0
var _side := {}                 # [main, point] -> côté du levier où il se trouve (+1 / -1)
var _pushing := false


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


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if push_by_touch and not is_grabbed():
		_update_touch_push()


func _local_point(global_point: Vector3) -> Vector3:
	var parent_xf: Transform3D = get_parent().global_transform if get_parent() is Node3D else Transform3D.IDENTITY
	return parent_xf.affine_inverse() * global_point - position


func _setup_touch() -> void:
	# sommets réels des meshes (les boîtes englobantes d'un levier incliné sont trop larges)
	_touch_ready = true
	var axis := hinge_axis.normalized()
	var pts: Array[Vector3] = []
	for m in find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.has_meta("_vr_outline") or mi.mesh == null:
			continue
		var xf := mi.global_transform
		var faces := mi.mesh.get_faces()
		for i in faces.size():
			pts.append(_local_point(xf * faces[i]))
	if pts.is_empty():
		_touch_ready = false   # meshes pas encore là : on réessaiera
		return
	var rho_max := 0.0
	_h = Vector2(INF, -INF)
	_rho = Vector2(INF, 0.0)
	for p in pts:
		var h := p.dot(axis)
		var rho := (p - axis * h).length()
		rho_max = maxf(rho_max, rho)
		_rho = Vector2(minf(_rho.x, rho), maxf(_rho.y, rho))
		_h = Vector2(minf(_h.x, h), maxf(_h.y, h))
	# direction du bras : moyenne des sommets de la moitié extérieure
	var acc := Vector3.ZERO
	for p in pts:
		var q := p - axis * p.dot(axis)
		if q.length() > rho_max * 0.5:
			acc += q
	var arm := acc.normalized()
	_half_thick = 0.005
	for p in pts:
		var q := p - axis * p.dot(axis)
		if q.length() > rho_max * 0.5:
			_half_thick = maxf(_half_thick, absf(q.dot(axis.cross(arm))))
	_half_thick = minf(_half_thick, 0.025)
	var parent_xf: Transform3D = get_parent().global_transform if get_parent() is Node3D else Transform3D.IDENTITY
	_arm_angle0 = _hand_angle(parent_xf * (position + arm * rho_max * 0.7))
	_angle0 = angle


## Point du bras du levier à `rho` m de l'axe, et direction « angle + » en ce point
## (monde) : sert aux tests.
func touch_arm_frame(rho: float) -> Array:
	if not _touch_ready:
		_setup_touch()
	var axis := hinge_axis.normalized()
	var ref := Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var u := axis.cross(ref).normalized()
	var v := axis.cross(u)
	var a := _arm_angle0 + (angle - _angle0)
	var dir := u * cos(a) + v * sin(a)
	var pb: Basis = (get_parent() as Node3D).global_basis if get_parent() is Node3D else Basis.IDENTITY
	var pxf: Transform3D = (get_parent() as Node3D).global_transform if get_parent() is Node3D else Transform3D.IDENTITY
	return [pxf * (position + dir * rho), (pb * axis.cross(dir)).normalized()]


func _update_touch_push() -> void:
	if not _touch_ready:
		_setup_touch()
		if not _touch_ready:
			return
	var axis := hinge_axis.normalized()
	var arm := _arm_angle0 + (angle - _angle0)
	var new_angle := angle
	var pusher: Node3D = null
	for hand in get_tree().get_nodes_in_group(VRHandInteractor.TOUCH_GROUP):
		for k in 2:
			var key := [hand, k]
			if not hand.can_touch():
				_side.erase(key)
				continue
			var gp: Vector3 = hand.fingertip_position() if k == 0 else hand.palm_position()
			var p := _local_point(gp)
			var h := p.dot(axis)
			var rho := (p - axis * h).length()
			var r := 0.01 if k == 0 else 0.03     # rayon du doigt / de la main
			if rho < _rho.x or rho > _rho.y + r or h < _h.x - r or h > _h.y + r or rho < 0.03:
				_side.erase(key)
				continue
			var a = _hand_angle(gp)
			if a == null:
				continue
			var d := wrapf(float(a) - arm, -PI, PI)
			var th := atan2(_half_thick + r, rho)
			if absf(d) >= th:
				_side[key] = signf(d)
				continue
			if not _side.has(key):
				continue   # main apparue « dans » le levier : on l'ignore
			# la main a franchi le bord du levier : il tourne pour rester devant elle
			var push := d - float(_side[key]) * th
			new_angle += push
			arm += push
			pusher = hand
	if pusher:
		_target_angle = null
		_set_angle(new_angle)
		_pushing = true
		var nearest := _nearest_notch(angle)
		if nearest != notch:
			notch = nearest
			notch_changed.emit(notch)
			pusher.pulse(0.35, 0.03)
	elif _pushing:
		_pushing = false
		set_angle_deg(notch_angles_deg[notch])


func _nearest_notch(a: float) -> int:
	var best := 0
	for i in notch_angles_deg.size():
		if absf(deg_to_rad(notch_angles_deg[i]) - a) < absf(deg_to_rad(notch_angles_deg[best]) - a):
			best = i
	return best
