class_name EdiblePickable
extends VRPickable
## Pilule qu'on peut avaler : en VR, la porter à la bouche (sous les yeux) ; sans
## casque, la viser et appuyer sur F (ou A/X avec la manette).
## Avaler appelle PillAddiction.take_pill() (boost, effet, manque à zéro, assimilation).

const GROUP_ADDICTION := "pill_addiction"
## Distance (m) entre la pilule et la bouche pour l'avaler.
const MOUTH_RADIUS := 0.09
## Position de la bouche dans le repère de la caméra (sous les yeux, un peu devant).
const MOUTH_OFFSET := Vector3(0.0, -0.075, -0.06)

signal eaten

var _eaten := false


## Position de la bouche du joueur (monde), ou null sans caméra. Partie à deux : celle
## de l'autre joueur si c'est lui qui tient l'objet.
static func mouth_position(tree: SceneTree, held: VRInteractable = null) -> Variant:
	var cam: Node3D = Net.camera_for(held) if Net.is_online() else tree.root.get_viewport().get_camera_3d()
	if cam == null:
		return null
	return cam.global_transform * MOUTH_OFFSET


func _on_grab_update(hand: Node3D) -> void:
	super._on_grab_update(hand)
	if _eaten or not is_inside_tree():
		return
	var mouth = mouth_position(get_tree(), self)
	if mouth != null and item.global_position.distance_to(mouth) < MOUTH_RADIUS:
		eat()


func _on_grab_end(hand: Node3D) -> void:
	if _eaten:
		return   # avalée : pas de rangement ni de chute
	super._on_grab_end(hand)


## F (bureau) ou A/X (VR) en visant la pilule : avalée tout de suite.
func toggle() -> void:
	eat()


func eat() -> void:
	if _eaten:
		return
	_eaten = true
	for h in _grab_hands.duplicate():
		release(h)
	swallow(get_tree())
	eaten.emit()
	item.queue_free()


## Effet d'une pilule avalée (sert aussi à la pochette, F sans sortir la pilule).
static func swallow(tree: SceneTree) -> void:
	if Net.applying_remote:
		return   # c'est l'autre joueur qui l'a avalée
	var addiction := tree.get_first_node_in_group(GROUP_ADDICTION)
	if addiction and addiction.has_method("take_pill"):
		addiction.take_pill()
	for h in tree.get_nodes_in_group(VRHandInteractor.GROUP):
		(h as VRHandInteractor).pulse(0.35, 0.12)
	var counter := tree.root.get_meta("pills_eaten", 0) as int
	tree.root.set_meta("pills_eaten", counter + 1)
