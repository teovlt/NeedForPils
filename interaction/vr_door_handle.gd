class_name VRDoorHandle
extends VRHingeInteractable
## Poignée de porte (intérieure ou extérieure) qui pivote comme une vraie poignée.
##
## - Porte fermée : on tire la poignée (elle pivote autour de son axe) ; au-delà de
##   `unlatch_ratio` de sa course, la porte se déverrouille et suit ensuite la main.
## - Porte ouverte : saisir la poignée entraîne directement la porte (pour la fermer).
## - Relâchée, la poignée revient en place ; une porte repoussée presque fermée se
##   referme et se verrouille toute seule.
## - A/X (ou F à la souris) près de la poignée : ouvre / ferme la porte automatiquement.
## La porte elle-même n'est plus saisissable : seules ses poignées s'illuminent.

## Porte (VRHingeInteractable) commandée par cette poignée.
@export var door_path: NodePath
## Part de la course de la poignée à partir de laquelle la porte se déverrouille.
@export_range(0.1, 1.0) var unlatch_ratio := 0.6
## Distance (m) dont il faut tirer la main pour amener la poignée en butée.
@export var pull_travel := 0.035
## Vrai (boîte à gants) : une fois déverrouillée puis lâchée, la pièce s'ouvre
## complètement d'elle-même (elle tombe), au lieu de rester où on l'a laissée.
@export var open_on_release := false

var door: VRHingeInteractable
var _swinging := false
var _pull_anim := 0.0
var _pull_dir := Vector3.ZERO      # sens de traction (repère de la porte)
var _grab_local := Vector3.ZERO
var _grab_ratio := 0.0
var _started_closed := false


func _ready() -> void:
	snap_closed_deg = 0.0
	auto_speed_deg = 260.0
	super._ready()
	door = get_node_or_null(door_path) as VRHingeInteractable
	if door:
		door.enabled = false   # on ouvre la porte par ses poignées


func _pull_limit() -> float:
	return deg_to_rad(max_angle_deg if absf(max_angle_deg) >= absf(min_angle_deg) else min_angle_deg)


## Sens dans lequel part le bout de la poignée quand on la tire (repère du parent).
func _compute_pull_dir() -> void:
	var tip := Vector3.ZERO
	for m in find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh and not mi.has_meta("_vr_outline"):
			tip = to_local(mi.to_global(mi.mesh.get_aabb().get_center()))
			break
	var rot := Basis(hinge_axis.normalized(), _pull_limit())
	_pull_dir = (rot * (_rest_basis * tip) - _rest_basis * tip).normalized()


func _local_hand(hand: Node3D) -> Vector3:
	var parent_xf: Transform3D = get_parent().global_transform if get_parent() is Node3D else Transform3D.IDENTITY
	return parent_xf.affine_inverse() * hand.global_position


func _on_grab_begin(hand: Node3D) -> void:
	_target_angle = null
	if _pull_dir == Vector3.ZERO:
		_compute_pull_dir()
	_grab_local = _local_hand(hand)
	_grab_ratio = angle / _pull_limit() if _pull_limit() != 0.0 else 0.0
	_swinging = false
	_started_closed = door != null and not door.is_open()
	if door and door.is_open():
		_start_swing(hand)


func _on_grab_update(hand: Node3D) -> void:
	if _swinging:
		door._on_grab_update(hand)
		return
	# La poignée pivote selon la distance dont la main la tire.
	var disp := (_local_hand(hand) - _grab_local).dot(_pull_dir)
	_set_angle(_pull_limit() * clampf(_grab_ratio + disp / pull_travel, 0.0, 1.0))
	if door and absf(angle) >= absf(_pull_limit()) * unlatch_ratio:
		_start_swing(hand)
		if hand.has_method("pulse"):
			hand.pulse(0.5, 0.05)   # "clac" du pêne


func _start_swing(hand: Node3D) -> void:
	_swinging = true
	door._on_grab_begin(hand)


func _on_grab_end(hand: Node3D) -> void:
	if is_grabbed():
		return
	if _swinging and door:
		door._on_grab_end(hand)
		if open_on_release and _started_closed:
			door.open()
	_swinging = false
	_target_angle = 0.0   # la poignée revient en place


func toggle() -> void:
	if is_grabbed() or door == null:
		return
	if not door.is_open():
		# petite animation de la poignée tirée puis relâchée
		_target_angle = _pull_limit()
		_pull_anim = 0.25
	door.toggle()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _pull_anim > 0.0:
		_pull_anim -= delta
		if _pull_anim <= 0.0 and not is_grabbed():
			_target_angle = 0.0
