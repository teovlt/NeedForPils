extends VRInteractable
## Pare-soleil : panneau rembourré sur une tige, au pavillon, au-dessus du pare-brise.
##
## - On le saisit (grip en VR, clic gauche à la souris) et on le rabat vers le bas : il
##   reste à l'angle où on le lâche (friction de la tige), et se recolle au pavillon
##   sous 10°.
## - Rabattu, on peut le décrocher et le pivoter contre la vitre latérale (tirer la main
##   vers la portière). Il ne se relève que remis devant.
## - F : relevé -> rabattu -> contre la vitre -> relevé. A/X (VR) : il revient à sa
##   place, relevé contre le pavillon.
## - Le pare-soleil conducteur a une sangle élastique qui tient la clé de la voiture, sur
##   la face collée au pavillon quand il est relevé : on ne la voit (et ne l'attrape)
##   qu'une fois le pare-soleil rabattu. Lâchée tout près de la sangle, la clé y retourne.
##
## Repère du noeud : origine = support au pavillon, côté montant. La tige part vers
## l'intérieur de la voiture (-X côté conducteur, +X côté passager).

const KEY_GROUP := "key_holder"

## "L" (conducteur, à gauche) ou "R" (passager).
@export var side := "L"
@export var flip_max_deg := 95.0
@export var swing_max_deg := 90.0

var flip := 0.0    # radians, 0 = relevé contre le pavillon, + = rabattu
var swing := 0.0   # radians, 0 = devant, + = contre la vitre latérale
var key_item: RigidBody3D

var _swing_node: Node3D
var _panel: Node3D
var _holder: Node3D
var _holder_marker: Node3D
var _grab_flip_ref := 0.0
var _grab_flip_start := 0.0
var _grab_yaw_ref = null
var _grab_swing_start := 0.0
var _can_swing := false
var _auto_flip := -1.0
var _auto_swing := -1.0


func _ready() -> void:
	super._ready()
	highlight_distance = 0.14
	grab_distance = 0.07
	outline_width = 0.004
	var parts: Node3D = preload("res://cars/SUV4x4/sun_visor_parts.glb").instantiate()
	add_child(parts)
	for n in ["Visor_Bracket_", "Visor_Clip_"]:
		var m := parts.get_node(n + side) as Node3D
		m.reparent(self, false)
		m.transform = Transform3D.IDENTITY
	_swing_node = Node3D.new()
	_swing_node.name = "Swing"
	add_child(_swing_node)
	var rod := parts.get_node("Visor_Rod_" + side) as Node3D
	rod.reparent(_swing_node, false)
	rod.transform = Transform3D.IDENTITY
	_panel = Node3D.new()
	_panel.name = "Panel"
	_swing_node.add_child(_panel)
	var pm := parts.get_node("Visor_Panel_" + side) as Node3D
	pm.reparent(_panel, false)
	pm.transform = Transform3D.IDENTITY
	parts.queue_free()
	mesh_root = _swing_node   # le contour ne prend pas la clé ni les supports fixes
	# porte-clé : sous la sangle, sur la face du dessus du panneau (collée au pavillon
	# quand il est relevé). Clé à plat, tête vers le bord libre.
	_holder_marker = Node3D.new()
	_holder_marker.name = "KeyMarker"
	var sx := 1.0 if side == "L" else -1.0
	var x := Vector3.UP          # épaisseur de la clé = normale de la face
	var z := Vector3.FORWARD     # tête vers le bord libre (-Z quand relevé)
	_holder_marker.transform = Transform3D(Basis(x, z.cross(x), z), Vector3(-0.215 * sx, 0.016, -0.07))
	_panel.add_child(_holder_marker)
	# le porte-clé suit le panneau mais n'en est pas un descendant (contour, saisie)
	_holder = Node3D.new()
	_holder.name = "KeyHolder"
	_holder.top_level = true
	_holder.add_to_group(KEY_GROUP)
	_holder.set_meta("visor", self)
	add_child(_holder)
	_apply()


func is_down() -> bool:
	return flip > deg_to_rad(60.0)


## Le porte-clé (sangle) est-il assez près pour y ranger la clé ?
func holder_near(world_pos: Vector3) -> bool:
	return side == "L" and is_down() and _holder.global_position.distance_to(world_pos) < 0.09


## Plan de la face du panneau (pour que le trousseau ne passe pas au travers).
func holder_plane() -> Array:
	return [_holder.global_position - _holder.global_basis.x * 0.006, _holder.global_basis.x]


func store_key(item: RigidBody3D) -> void:
	key_item = item
	item.reparent(_holder, true)
	item.top_level = false
	item.freeze = true
	item.collision_layer = 0
	item.collision_mask = 0
	if item.has_meta("rest_xf"):
		item.remove_meta("rest_xf")
	item.transform = Transform3D.IDENTITY


## A/X en VR : retour à la position de départ (relevé, devant).
func vr_button() -> void:
	if is_grabbed():
		return
	_auto_swing = 0.0
	_auto_flip = 0.0


func toggle() -> void:
	if is_grabbed():
		return
	if not is_down():
		_auto_flip = deg_to_rad(90.0)
		_auto_swing = 0.0
	elif swing < deg_to_rad(10.0):
		_auto_swing = deg_to_rad(swing_max_deg)
		_auto_flip = deg_to_rad(90.0)
	else:
		_auto_swing = 0.0
		_auto_flip = 0.0


func _apply() -> void:
	var sx := 1.0 if side == "L" else -1.0
	# pivotement vers la vitre autour de l'axe vertical du support, rabat autour de la tige
	_swing_node.transform.basis = Basis(Vector3.UP, -swing * sx)
	_panel.transform.basis = Basis(Vector3.RIGHT, -flip)
	_holder.global_transform = _holder_marker.global_transform


func _set_angles(f: float, s: float) -> void:
	s = clampf(s, 0.0, deg_to_rad(swing_max_deg))
	# décroché (contre la vitre), il ne peut pas remonter au pavillon
	var fmin := deg_to_rad(75.0) if s > deg_to_rad(5.0) else 0.0
	f = clampf(f, fmin, deg_to_rad(flip_max_deg))
	if f < deg_to_rad(75.0):
		s = 0.0   # replié : il reste accroché devant
	flip = f
	swing = s
	_apply()


# --- Saisie ------------------------------------------------------------------

## Angle de la main autour de la tige (0 = vers l'arrière, + = vers le bas).
func _hand_flip_angle(hand: Node3D) -> float:
	var p := _swing_node.global_transform.affine_inverse() * hand.global_position
	return atan2(-p.y, -p.z)


## Angle de la main autour de l'axe vertical du support (0 = le long de la tige,
## + = vers l'arrière, donc vers la vitre latérale), ou null trop près de l'axe.
func _hand_yaw(hand: Node3D):
	var p := global_transform.affine_inverse() * hand.global_position
	var sx := 1.0 if side == "L" else -1.0
	if Vector2(p.x, p.z).length() < 0.06:
		return null
	return atan2(-p.z, -sx * p.x)


func _on_grab_begin(hand: Node3D) -> void:
	_auto_flip = -1.0
	_auto_swing = -1.0
	_grab_flip_ref = _hand_flip_angle(hand)
	_grab_flip_start = flip
	_grab_yaw_ref = _hand_yaw(hand)
	_grab_swing_start = swing
	# on ne peut décrocher et pivoter le pare-soleil que s'il est déjà rabattu
	_can_swing = flip > deg_to_rad(78.0)


func _on_grab_update(hand: Node3D) -> void:
	# pivotement d'abord (suivi relatif de la main autour de l'axe vertical)...
	var s := swing
	var y = _hand_yaw(hand)
	if _can_swing and y != null and _grab_yaw_ref != null:
		s = clampf(_grab_swing_start + wrapf(float(y) - float(_grab_yaw_ref), -PI, PI), 0.0, deg_to_rad(swing_max_deg))
		_swing_node.transform.basis = Basis(Vector3.UP, -s * (1.0 if side == "L" else -1.0))
	# ...puis rabat, mesuré dans le repère de la tige déjà pivotée
	var f := _grab_flip_start + wrapf(_hand_flip_angle(hand) - _grab_flip_ref, -PI, PI)
	_set_angles(f, s)


func _on_grab_end(_hand: Node3D) -> void:
	if flip < deg_to_rad(10.0):
		_auto_flip = 0.0


func _physics_process(delta: float) -> void:
	if not is_grabbed() and (_auto_flip >= 0.0 or _auto_swing >= 0.0):
		var f := flip
		var s := swing
		var spd := deg_to_rad(240.0) * delta
		# on rabat avant de pivoter, on remet devant avant de relever
		if _auto_swing >= 0.0 and (flip >= deg_to_rad(80.0) or _auto_swing < s):
			s = move_toward(s, _auto_swing, spd)
		if _auto_flip >= 0.0 and (s < deg_to_rad(5.0) or _auto_flip > f):
			f = move_toward(f, _auto_flip, spd)
		_set_angles(f, s)
		if (_auto_flip < 0.0 or is_equal_approx(flip, _auto_flip)) and (_auto_swing < 0.0 or is_equal_approx(swing, _auto_swing)):
			_auto_flip = -1.0
			_auto_swing = -1.0
	_holder.global_transform = _holder_marker.global_transform
	if key_item:
		if key_item.get_parent() != _holder or key_item.top_level:
			key_item = null   # la clé a été prise (main, contact...)
		else:
			CarStorage.pin_body(key_item)
			key_item.transform = Transform3D.IDENTITY
