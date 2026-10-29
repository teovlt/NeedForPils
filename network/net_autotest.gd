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
		_finger_presses(car)
	if Net.is_driver():
		_once("main_vue", 15.0, func():
			var shown = session._remote_hand_meshes[1] if session._remote_hand_meshes.size() > 1 else null
			if shown:
				print("NETTEST conducteur voit la main droite du copilote : modèle %s, visible=%s, à (%.2f, %.2f, %.2f) dans la voiture" % [
					shown.name, shown.visible, car.to_local(shown.global_position).x, car.to_local(shown.global_position).y, car.to_local(shown.global_position).z]))
	else:
		_once("main_vue_c", 15.0, func():
			var h = _done.get("main")
			if h and h._xr_hand:
				var p := car.to_local((h._xr_hand as Node3D).global_position)
				print("NETTEST copilote sa main droite affichée à (%.2f, %.2f, %.2f)" % [p.x, p.y, p.z]))
	for at in [13.2, 14.4, 15.0, 15.8]:
		_once("toucher%.1f" % at, at, func():
			print("NETTEST %s t=%.1f radio=%s klaxon=%s" % ["conducteur" if Net.is_driver() else "copilote", at,
				car.radio.get("power"), car.horn.is_honking()]))
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
	_once("menu_pause", 16.0, func():
		var menu := session.get_parent().get_node("PauseMenu") as PauseMenu
		menu.open()
		print("NETTEST %s menu : ouvert=%s jeu en pause=%s REJOUER proposé=%s" % ["conducteur" if Net.is_driver() else "copilote",
			menu.is_open, get_tree().paused, menu._ui.restart_button.visible])
		menu.close())
	if _t > 16.5 and not _done.has("fin"):
		_done["fin"] = true
		get_tree().quit()


func _once(key: String, at: float, f: Callable) -> void:
	if _t >= at and not _done.has(key):
		_done[key] = true
		f.call()


## Main VR simulée (VRHandInteractor.debug_points) : le doigt appuie sur la touche
## marche de la radio (13,5 s) puis se pose sur le klaxon (14,6 à 15,4 s).
func _finger_presses(car: SUV4x4) -> void:
	_once("main_vr", 13.0, func():
		# manette sans suivi (tracker inventé) portant la main XR Tools, comme le joueur
		var holder := XRController3D.new()
		holder.tracker = &"test_right"
		car.add_child(holder)
		holder.position = Vector3(-0.2, 1.1, 0.4)
		holder.add_child((load("res://addons/godot-xr-tools/hands/scenes/lowpoly/right_hand_low.tscn") as PackedScene).instantiate())
		var h := VRHandInteractor.new()
		h.name = "TestRightHand"
		holder.add_child(h)
		h.debug_points = [Vector3(0, -100, 0), Vector3(0, -100, 0)]
		_done["main"] = h)
	var h = _done.get("main")
	if h == null:
		return
	var far := car.to_global(Vector3(0, -50, 0))
	var tip := far
	var radio := car.radio
	if _t > 13.5 and _t < 14.3:
		var m: Node3D = radio._buttons["power"][0]
		var g := m.get_parent() as Node3D
		var ab: AABB = (m as MeshInstance3D).get_aabb() if m is MeshInstance3D else AABB()
		var face := g.position + Vector3(ab.get_center().x, ab.get_center().y, ab.end.z)
		var dt := _t - 13.5
		var depth := lerpf(0.03, -0.003, smoothstep(0.0, 0.3, dt)) if dt < 0.5 else lerpf(-0.003, 0.03, smoothstep(0.5, 0.7, dt))
		tip = radio.to_global(face + Vector3(0, 0, depth))
	elif _t > 14.6 and _t < 15.4:
		var axis: Vector3 = (car.horn.global_basis * car.horn.column_axis).normalized()
		tip = car.horn._pad.global_position + axis * 0.004
	h.debug_points = [tip, far]


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
