@icon("res://addons/godot-xr-tools/editor/icons/hand.svg")
class_name VRWindowCrank
extends VRInteractable
## Manivelle de lève-vitre : on la saisit par le bouton (grip en VR, clic gauche
## maintenu à la souris) et on la fait tourner autour de son axe pour baisser ou
## remonter la vitre. A/X ou F : la vitre descend ou remonte d'elle-même (la manivelle
## tourne avec). Quand la vitre est assez baissée, le rétroviseur extérieur associé
## devient attrapable (`mirror`).
##
## Repère du noeud : axe de rotation = +Z (vers l'habitacle), bras au repos vers +Y.

signal opening_changed(value: float)

## Vitre qui coulisse (descend selon -Y du repère de son parent, la porte).
@export var window: Node3D
## Course de la vitre (m) quand elle est entièrement baissée.
@export var travel := 0.45
## Nombre de tours de manivelle pour baisser entièrement la vitre.
@export var turns := 3.0
## +1 : tourner dans le sens horaire (vu de l'habitacle) baisse la vitre ; -1 : l'inverse.
@export var open_direction := 1.0
## Rétroviseur extérieur attrapable seulement quand la vitre est assez ouverte.
@export var mirror: VRInteractable
@export_range(0.0, 1.0) var mirror_reach_opening := 0.55
## Vitesse de la vitre en automatique (fraction de course par seconde).
@export var auto_speed := 0.6

## 0 = vitre fermée, 1 = vitre entièrement baissée.
var opening := 0.0

var _arm: Node3D
var _window_rest := Vector3.ZERO
var _last_angle = null
var _auto_target := -1.0


func _ready() -> void:
	super._ready()
	var scene: Node3D = preload("res://cars/SUV4x4/window_crank.glb").instantiate()
	add_child(scene)
	_arm = scene.get_node_or_null("Crank_Arm")
	if window:
		_window_rest = window.position
	_apply()


## Ouverture entre 0 (fermée) et 1 (baissée).
func set_opening(value: float) -> void:
	opening = clampf(value, 0.0, 1.0)
	_apply()


func is_mirror_reachable() -> bool:
	return opening >= mirror_reach_opening


func toggle() -> void:
	_auto_target = 0.0 if opening > 0.5 else 1.0


func _apply() -> void:
	if _arm:
		# sens horaire vu de l'habitacle (+Z vers l'oeil) = rotation négative autour de +Z
		_arm.transform.basis = Basis(Vector3.BACK, -open_direction * opening * turns * TAU)
	if window:
		window.position = _window_rest + Vector3.DOWN * travel * opening
	if mirror:
		mirror.enabled = is_mirror_reachable()
	opening_changed.emit(opening)


func _hand_angle(global_point: Vector3):
	var p := global_transform.affine_inverse() * global_point
	if Vector2(p.x, p.y).length() < 0.02:   # main sur l'axe : angle instable
		return null
	return atan2(p.y, p.x)


func _on_grab_begin(hand: Node3D) -> void:
	_auto_target = -1.0
	_last_angle = _hand_angle(hand.global_position)


func _on_grab_update(hand: Node3D) -> void:
	var a = _hand_angle(hand.global_position)
	if a == null:
		return
	if _last_angle != null:
		# angle trigonométrique (anti-horaire vu de +Z) ; horaire = baisser si open_direction = 1
		var d := wrapf(float(a) - float(_last_angle), -PI, PI)
		var before := opening
		set_opening(opening - open_direction * d / (turns * TAU))
		if before != opening and (opening == 0.0 or opening == 1.0) and hand.has_method("pulse"):
			hand.pulse(0.5, 0.05)   # butée
	_last_angle = a


func _on_grab_end(_hand: Node3D) -> void:
	_last_angle = null


func _physics_process(delta: float) -> void:
	if _auto_target < 0.0 or is_grabbed():
		return
	set_opening(move_toward(opening, _auto_target, auto_speed * delta))
	if opening == _auto_target:
		_auto_target = -1.0
