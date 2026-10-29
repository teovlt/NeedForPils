class_name VRGestureHandle
extends VRInteractable
## Partie d'un objet qu'on actionne d'un geste de l'autre main en VR, à la place du
## bouton A/X (réservé au recalage du pare-soleil et des rétroviseurs) : l'objet tenu
## dans une main, l'autre main pince la partie (gâchette, bout de l'index) ou la saisit
## (grip) et tire de quelques centimètres -> `action` est appelée une fois (zip de la
## pochette écarté, couvercle du paquet soulevé, languette de la canette levée...).
##
## La partie est un segment (deux points monde rendus par `segment`) : bande du zip,
## bord du couvercle, languette... Active seulement quand `available` le permet et que
## l'objet `owner_grab` est tenu ; la main qui le tient ne peut pas la prendre.
## Nom de nœud stable : en partie à deux, l'autre joueur rejoue le même geste.

## Objet auquel appartient la partie (doit être tenu pour que le geste soit possible).
var owner_grab: VRInteractable
## -> [Vector3, Vector3] : extrémités monde de la partie à saisir.
var segment: Callable
## -> bool : le geste a un sens maintenant (ex. canette encore fermée).
var available: Callable
## Appelée une fois par prise, quand la main a tiré de `pull_distance`.
var action: Callable
## Rayon (m) autour du segment.
var radius := 0.012
## Distance (m) à tirer pour déclencher.
var pull_distance := 0.025

var _start := {}      # main -> position de départ (repère de l'objet)
var _done := {}       # main -> geste déjà fait pendant cette prise


func _ready() -> void:
	highlight_distance = 0.06
	grab_distance = 0.035
	outline_width = 0.0015
	pick_bonus = 0.03
	grab_with_trigger = true
	super._ready()


func _physics_process(_delta: float) -> void:
	enabled = is_grabbed() or (owner_grab != null and owner_grab.is_grabbed()
			and (not available.is_valid() or available.call()))


func get_distance_to(global_point: Vector3) -> float:
	var s: Array = segment.call()
	var p := Geometry3D.get_closest_point_to_segment(global_point, s[0], s[1])
	return maxf(p.distance_to(global_point) - radius, 0.0)


## Seule l'autre main (ou le bout de son index) : pas celle qui tient l'objet.
func accepts_hand(hand: Node3D) -> bool:
	if owner_grab == null:
		return true
	if hand in owner_grab._grab_hands:
		return false
	var owner_hand = hand.get("owner_hand")   # bout de l'index d'une main
	return owner_hand == null or not owner_hand in owner_grab._grab_hands


func _on_grab_begin(hand: Node3D) -> void:
	_start[hand] = _frame().affine_inverse() * hand.global_position
	_done[hand] = false


func _on_grab_update(hand: Node3D) -> void:
	if _done.get(hand, true):
		return
	var from: Vector3 = _frame() * (_start[hand] as Vector3)
	if from.distance_to(hand.global_position) >= pull_distance:
		_done[hand] = true
		if hand.has_method("pulse"):
			hand.pulse(0.35, 0.04)
		if action.is_valid():
			action.call()


func _on_grab_end(hand: Node3D) -> void:
	_start.erase(hand)
	_done.erase(hand)


## Segment de saisie pris sur les maillages de `node` (boîte calculée une fois, repère du
## nœud, qui peut tourner : couvercle, rabat) : « bord » = bord avant (+Z, loin de la
## charnière, à mi-hauteur), « centre » = centre de la boîte (languette, couvercle rond).
static func part_segment(node: Node3D, mode: String) -> Callable:
	var box := AABB()
	var first := true
	var inv := node.global_transform.affine_inverse()
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or mi.has_meta("_vr_outline"):
			continue
		var b := (inv * mi.global_transform) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var a := box.get_center()
	var b := a
	if mode == "bord":
		a = Vector3(box.position.x + box.size.x * 0.15, box.get_center().y, box.end.z)
		b = Vector3(box.end.x - box.size.x * 0.15, a.y, a.z)
	return func() -> Array: return [node.global_transform * a, node.global_transform * b]


## Repère de l'objet : le geste se mesure par rapport à lui (il bouge avec la main qui
## le tient et la voiture qui roule).
func _frame() -> Transform3D:
	var it = owner_grab.get("item") if owner_grab else null
	return (it as Node3D).global_transform if it is Node3D else global_transform
