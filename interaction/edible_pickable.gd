class_name EdiblePickable
extends VRPickable
## Pilule qu'on peut avaler : en VR, la porter à la bouche (sous les yeux) ; sans
## casque, la viser et appuyer sur F. En partie à deux, on peut aussi la porter à la
## bouche de l'autre joueur : c'est lui qui l'avale (mouth_near). Seule la machine de la
## main qui la tient cherche une bouche (chez l'autre, cette main n'est qu'un reflet en
## retard : les deux machines ne tombaient pas d'accord) ; si c'est celle de l'autre
## joueur, elle le prévient (Net.feed -> net_feed).
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


## Bouche la plus proche de `point`, à moins de `radius` : celle du joueur local ou, en
## partie à deux, celle de l'autre joueur (on peut lui faire fumer une cigarette, boire
## une bière ou un café, avaler une pilule, même pendant qu'il conduit). Renvoie
## [position, tête (caméra), vrai si c'est le joueur local], ou [] si aucune. Les deux
## joueurs font le même calcul ; l'effet ne s'applique que chez celui dont c'est la
## bouche.
static func mouth_near(tree: SceneTree, point: Vector3, radius: float) -> Array:
	var heads := [[tree.root.get_viewport().get_camera_3d(), true]]
	if Net.is_online():
		heads.append([Net.other_head(), false])
	var best := []
	var best_d := radius
	for hd in heads:
		var cam := hd[0] as Node3D
		if cam == null or not is_instance_valid(cam):
			continue
		var m := cam.global_transform * MOUTH_OFFSET
		var d := m.distance_to(point)
		if d < best_d:
			best_d = d
			best = [m, cam, hd[1]]
	return best


func _on_grab_update(hand: Node3D) -> void:
	super._on_grab_update(hand)
	if _eaten or not is_inside_tree():
		return
	if Net.is_online() and Net.held_by_remote(self):
		return   # tenue par l'autre joueur : sa machine décide (net_feed)
	var m := mouth_near(get_tree(), item.global_position, MOUTH_RADIUS)
	if not m.is_empty():
		if not m[2]:
			Net.feed(self, 0.0, true)   # avant qu'elle disparaisse
		eat(m[2])


## Partie à deux : l'autre joueur nous l'a mise dans la bouche.
func net_feed(_amount: float) -> void:
	eat(true)


func _on_grab_end(hand: Node3D) -> void:
	if _eaten:
		return   # avalée : pas de rangement ni de chute
	super._on_grab_end(hand)


## F (bureau) en visant la pilule : avalée tout de suite.
func toggle() -> void:
	eat()


## `local_player` : avalée par le joueur local (vrai) ou par l'autre (faux) ; null =
## d'après le geste (rejoué de l'autre joueur ou non).
func eat(local_player = null) -> void:
	if _eaten:
		return
	_eaten = true
	for h in _grab_hands.duplicate():
		release(h)
	swallow(get_tree(), local_player)
	eaten.emit()
	item.queue_free()


## Effet d'une pilule avalée (sert aussi à la pochette, F sans sortir la pilule).
static func swallow(tree: SceneTree, local_player = null) -> void:
	var mine: bool = (not Net.applying_remote) if local_player == null else local_player
	if not mine:
		return   # c'est l'autre joueur qui l'a avalée
	var addiction := tree.get_first_node_in_group(GROUP_ADDICTION)
	if addiction and addiction.has_method("take_pill"):
		addiction.take_pill()
	for h in tree.get_nodes_in_group(VRHandInteractor.GROUP):
		(h as VRHandInteractor).pulse(0.35, 0.12)
	var counter := tree.root.get_meta("pills_eaten", 0) as int
	tree.root.set_meta("pills_eaten", counter + 1)
