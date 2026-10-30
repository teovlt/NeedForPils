class_name NetRemoteHand
extends Node3D
## Main de l'autre joueur, rejouée chez soi : placée là où est sa main (dans le repère
## de la voiture), elle saisit, tire, lâche et actionne les mêmes objets que lui
## (grab / grab_update / release / toggle), avec la même interface que les vraies mains
## (pulse, is_left, camera pour la souris). Les mains VR appuient aussi au toucher
## (klaxon, radio, comodos) avec le bout de l'index et la paume de l'autre joueur.
## Tout le comportement des objets se rejoue donc à l'identique.

const GROUP := "net_remote_hands"

## Indice de la main chez l'autre joueur : 0 gauche, 1 droite, 2 souris,
## 3 / 4 bout de l'index gauche / droit (NetRemoteTip).
var index := 0
## Tête de l'autre joueur (caméra non active) : les objets « souris » s'en servent.
var camera: Camera3D
var held: VRInteractable
var hand_velocity := Vector3.ZERO
## Toucher (mains VR) : posé par NetSession à chaque image.
var remote_touch := false
var tip_global := Vector3.ZERO
var palm_global := Vector3.ZERO


func _ready() -> void:
	add_to_group(GROUP)   # (placée par la NetSession, dans la voiture : la suit)
	if index == 2:
		# objets qui se manipulent autrement à la souris (clé, ceinture, volume)
		add_to_group(MouseHand.GROUP)
	elif index < 2:
		add_to_group(VRHandInteractor.TOUCH_GROUP)


func is_left() -> bool:
	return index == 0 or index == 3


## Pas de vibration : la main n'est pas la nôtre.
func pulse(_amplitude: float, _duration: float) -> void:
	pass


func get_trigger() -> float:
	return 0.0


func is_button_pressed(_action: StringName) -> bool:
	return false


func can_touch() -> bool:
	return remote_touch and held == null


func fingertip_position() -> Vector3:
	return tip_global


func palm_position() -> Vector3:
	return palm_global
