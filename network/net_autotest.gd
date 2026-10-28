extends Node
## Test automatique d'une partie à deux sur une seule machine (sans casque) :
##   godot --path . -- --host --net-test        (conducteur)
##   godot --path . -- --join=127.0.0.1 --net-test   (copilote)
## (ou `-- --lan --net-test` deux fois : comme le bouton JOUER À DEUX)
## Le conducteur démarre et accélère, puis fait surgir un barrage de police, un arbre et
## des animaux. Le copilote desserre le frein à main (main souris + F), éteint la radio,
## prend le briquet, tourne à gauche au clavier (Q) puis passe au point mort (N).
## Chacun écrit chaque seconde ce qu'il voit dans la console (« NETTEST »).

var session: NetSession
var _t := 0.0
var _next_log := 0.0
var _done := {}


func _physics_process(delta: float) -> void:
	var car := session.car if session else null
	if car == null:
		return
	_t += delta
	if Net.is_driver():
		# conduite au clavier, comme un joueur : Z enfoncé (le copilote peut tourner)
		if _t > 1.0:
			car.engine_state = 2   # (pas de clé dans le contact)
		_once("demarre", 1.0, func(): car.gear_lever.set_notch(SUV4x4.Gear.D, true))
		_once("accelere", 5.5, func(): _key(KEY_Z, true))
		_once("texte", 4.0, func(): session.get_parent().get_node("ChaseDirector").call("_say", "TEST", "Texte du conducteur", 2.0))
	else:
		_once("frein", 4.0, func(): _hand_toggle(car.handbrake_lever))
		_once("radio", 5.0, func(): _hand_toggle(_radio_power_grip(car)))
		# l'accélérateur du copilote ne doit rien faire (frein à main déjà desserré)
		_once("z_copilote", 4.3, func(): _key(KEY_Z, true))
		_once("z_copilote_fin", 5.3, func(): _key(KEY_Z, false))
		_once("gauche", 9.5, func(): _key(KEY_Q, true))
		_once("gauche_fin", 11.0, func(): _key(KEY_Q, false))
		_once("neutre", 12.5, func(): _key(KEY_N, true); _key(KEY_N, false))
	if Net.is_driver():
		_once("monde", 3.0, func():
			var main := session.get_parent()
			var police := main.get_node("Pursuer") as Pursuer
			print("NETTEST conducteur barrage : %s" % police.force_encounter("barrage", 150.0))
			(main.get_node("FallingTrees") as FallingTreeManager).spawn_ahead(70.0, 1)
			print("NETTEST conducteur animaux : %d" % (main.get_node("RoadGenerator/Animals") as AnimalManager).spawn_crossing("", 90.0, 1).size()))
	_once("siege", 3.0, func():
		var cam := get_viewport().get_camera_3d()
		var head := car.to_local(cam.global_position)
		print("NETTEST %s tête dans la voiture=(%.2f, %.2f, %.2f)" % ["conducteur" if Net.is_driver() else "copilote", head.x, head.y, head.z])
		if session.remote_player:
			var other := car.to_local(session._remote_head.global_position)
			print("NETTEST %s voit l'autre à (%.2f, %.2f, %.2f)" % ["conducteur" if Net.is_driver() else "copilote", other.x, other.y, other.z]))
	if not Net.is_driver():
		_once("accoudoir", 6.2, func():
			Net.perform(car.get_node("ConsoleLid"), &"toggle")
			print("NETTEST copilote ouvre l'accoudoir (C)"))
		_once("prend", 7.0, func():
			var hand := _mouse_hand()
			hand.hovered = _lighter(car).get_node("Grab")
			hand._grab_now()
			print("NETTEST copilote prend le briquet"))
		_once("lache", 8.5, func():
			_mouse_hand()._release()
			print("NETTEST copilote lâche le briquet"))
	for at in [6.0, 8.0, 10.0, 12.0]:
		_once("briquet%d" % at, at, func():
			var l := _lighter(car)
			var lp := car.to_local(l.global_position)
			print("NETTEST %s briquet t=%.0f dans %s pos_voiture=(%.2f, %.2f, %.2f) tenu=%s" % [
				"conducteur" if Net.is_driver() else "copilote", at, l.get_parent().name, lp.x, lp.y, lp.z,
				(l.get_node("Grab") as VRInteractable).is_grabbed()]))
	if _t >= _next_log and _t > 2.0:
		var main := session.get_parent()
		var police := main.get_node("Pursuer") as Pursuer
		var pp := car.to_local(police.get_car_position())
		var trees := (main.get_node("FallingTrees") as FallingTreeManager).get_active_trees()
		var animals := (main.get_node("RoadGenerator/Animals") as AnimalManager).animals
		var a0 := car.to_local(animals[0].global_position) if not animals.is_empty() else Vector3.ZERO
		var director := main.get_node("ChaseDirector")
		var title: Label3D = director.get("_title")
		print("NETTEST %s monde t=%.0f police=%s à (%.1f, %.1f) barrage=%d arbres=%d angle=%.2f animaux=%d 1er à (%.1f, %.1f) texte=« %s » volant=%.2f" % [
			"conducteur" if Net.is_driver() else "copilote", _t, police._visual.visible, pp.x, pp.z,
			police._props.size(), trees.size(), trees[0].angle if not trees.is_empty() else 0.0,
			animals.size(), a0.x, a0.z, title.text if title and title.modulate.a > 0.1 else "",
			car.steering_wheel.get_steer()])
	if _t >= _next_log:
		_next_log += 1.0
		var hb := rad_to_deg(car.handbrake_lever.angle)
		print("NETTEST %s t=%.0f pos=(%.2f, %.2f, %.2f) vitesse=%.1f km/h frein_main=%.0f° radio=%s rapport=%s autre_joueur=%s" % [
			"conducteur" if Net.is_driver() else "copilote", _t, car.global_position.x, car.global_position.y,
			car.global_position.z, car.forward_speed * 3.6, hb, car.radio.get("power"),
			car.gear_lever.get_notch_label(), session.remote_player != null])
	if _t > 16.0 and not _done.has("fin"):
		_done["fin"] = true
		get_tree().quit()


func _once(key: String, at: float, f: Callable) -> void:
	if _t >= at and not _done.has(key):
		_done[key] = true
		f.call()


func _key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)
	print("NETTEST %s touche %s %s" % ["conducteur" if Net.is_driver() else "copilote", OS.get_keycode_string(code), "appuyée" if pressed else "relâchée"])


func _lighter(car: SUV4x4) -> RigidBody3D:
	return car.find_child("Lighter", true, false) as RigidBody3D


func _mouse_hand() -> MouseHand:
	for h in get_tree().get_nodes_in_group(MouseHand.GROUP):
		if h is MouseHand:
			return h
	return null


## Vise l'objet avec la main souris et appuie sur F.
func _hand_toggle(target: VRInteractable) -> void:
	var hand := _mouse_hand()
	if hand == null or target == null:
		print("NETTEST ERREUR pas de main souris ou d'objet")
		return
	hand.hovered = target
	hand._toggle()
	print("NETTEST copilote : F sur %s" % target.name)


func _radio_power_grip(car: SUV4x4) -> VRInteractable:
	for g in car.radio.find_children("*", "VRInteractable", true, false):
		if g.get("kind") == "power":
			return g
	return null
