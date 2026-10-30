class_name GeneratedSound
extends RefCounted
## Sons fabriqués par calcul (bruits de choc, battement de cœur, hoquet...) : générés
## dans un fil de travail plutôt qu'au démarrage, où ils bloquaient l'image (~0,3 s
## sur PC, plusieurs fois plus sur le casque). Le son arrive une fraction de seconde
## après le lancement ; d'ici là, le lecteur n'a pas de son (il ne joue rien).


## Lance `maker` (Callable qui renvoie le son) dans un fil de travail, puis pose le
## résultat dans la propriété `property` de `target` (sur le fil principal).
static func make_later(maker: Callable, target: Object, property: StringName) -> void:
	var id := target.get_instance_id()
	WorkerThreadPool.add_task(func():
		var s = maker.call()
		_assign.call_deferred(id, property, s), false, "Son généré")


static func _assign(id: int, property: StringName, value) -> void:
	var target := instance_from_id(id)
	if target:
		target.set(property, value)
