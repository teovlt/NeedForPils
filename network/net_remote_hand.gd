class_name NetRemoteHand
extends Node3D
## Main de l'autre joueur, rejouée chez soi : placée là où est sa main (dans le repère
## de la voiture), elle saisit, tire, lâche et actionne les mêmes objets que lui
## (grab / grab_update / release / toggle), avec la même interface que les vraies mains
## (pulse, is_left, camera pour la souris). Tout le comportement des objets (frein à
## main, radio, portes, objets attrapés...) se rejoue donc à l'identique.

const GROUP := "net_remote_hands"

## Indice de la main chez l'autre joueur : 0 gauche, 1 droite, 2 souris.
var index := 0
## Tête de l'autre joueur (caméra non active) : les objets « souris » s'en servent.
var camera: Camera3D
var held: VRInteractable
var hand_velocity := Vector3.ZERO


func _ready() -> void:
	add_to_group(GROUP)
	top_level = true
	if index == 2:
		# objets qui se manipulent autrement à la souris (clé, ceinture, volume)
		add_to_group(MouseHand.GROUP)


func is_left() -> bool:
	return index == 0


## Pas de vibration : la main n'est pas la nôtre.
func pulse(_amplitude: float, _duration: float) -> void:
	pass


func get_trigger() -> float:
	return 0.0


func is_button_pressed(_action: StringName) -> bool:
	return false
