class_name NetRemoteTip
extends NetRemoteHand
## Bout de l'index de l'autre joueur (prise à la gâchette), comme VRHandInteractor.TipHand.

## Main (NetRemoteHand) à laquelle appartient ce doigt.
var owner_hand: NetRemoteHand


func is_fingertip() -> bool:
	return true
