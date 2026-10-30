extends Node
## Test automatique d'une partie à deux sur une seule machine (sans casque) :
##   godot --path . -- --host --net-test        (conducteur)
##   godot --path . -- --join=127.0.0.1 --net-test   (copilote)
## (ou `-- --lan --net-test` deux fois : comme le bouton JOUER À DEUX)
## Le conducteur démarre et accélère, puis fait surgir un barrage de police, un arbre et
## des animaux. Le copilote desserre le frein à main (main souris + F), éteint la radio,
## prend le briquet, tourne à gauche au clavier (Q) puis passe au point mort (N).
## Chacun écrit chaque seconde ce qu'il voit dans la console (« NETTEST »).
## Ensuite (17-28 s) : le conducteur fait avaler une pilule puis boire une bière au
## copilote, le copilote fait fumer un joint au conducteur ; on compare la radio et les
## objets chez les deux, et la régularité du mouvement de la voiture (« à-coups » :
## écart moyen d'une image à l'autre de la vitesse, en mm). Avec `--net-jitter=60`,
## les messages de position arrivent avec 0 à 60 ms de retard aléatoire (Wi-Fi).

var session: NetSession
var _t := 0.0
var _next_log := 0.0
var _done := {}
var _track: Array[Vector3] = []   # positions absolues de la voiture (à-coups)


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
		# arrêt avant les échanges d'objets (sinon la voiture finit dans le décor)
		_once("freine", 16.5, func(): _key(KEY_Z, false); _key(KEY_S, true))
		_once("texte", 4.0, func(): session.get_parent().get_node("ChaseDirector").call("_say", "TEST", "Texte du conducteur", 2.0))
	else:
		_once("frein", 4.0, func(): _hand_toggle(car.handbrake_lever))
		_once("radio", 5.0, func(): _hand_toggle(_radio_power_grip(car)))
		# l'accélérateur du copilote ne doit rien faire (frein à main déjà desserré)
		_once("z_copilote", 4.3, func(): _key(KEY_Z, true))
		_once("z_copilote_fin", 5.3, func(): _key(KEY_Z, false))
		_once("gauche", 9.5, func(): _key(KEY_Q, true))
		_once("gauche_fin", 10.0, func(): _key(KEY_Q, false))
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
	_smooth_sample(car)
	_feed_scenario(car)
	if _t > 29.0 and not _done.has("fin"):
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


# --- Régularité du mouvement ------------------------------------------------------------

func _smooth_sample(car: SUV4x4) -> void:
	if _t < 7.0:
		return
	var road := session._road
	_track.append(car.global_position + (road.world_offset if road else Vector3.ZERO))
	for at in [16.0, 28.0]:
		_once("acoups%.0f" % at, at, func():
			var sum := 0.0
			var worst := 0.0
			for i in range(2, _track.size()):
				var d2 := (_track[i] - 2.0 * _track[i - 1] + _track[i - 2]).length()
				sum += d2
				worst = maxf(worst, d2)
			var n := maxi(_track.size() - 2, 1)
			print("NETTEST %s à-coups t=%.0f : moyen %.2f mm, pire %.1f mm (%d images)" % [_who(), at, 1000.0 * sum / n, 1000.0 * worst, n])
			_track.clear())


# --- Faire consommer l'autre joueur -----------------------------------------------------

func _who() -> String:
	return "conducteur" if Net.is_driver() else "copilote"


func _feed_scenario(car: SUV4x4) -> void:
	# mêmes objets, même nom, même place chez les deux joueurs
	_once("objets_test", 17.0, func():
		for k in [["pill_smiley_item", "TestPill", Vector3(0.0, 1.0, 0.3)], ["beer_can_item", "TestBeer", Vector3(0.1, 1.0, 0.3)],
				["joint_item", "TestJoint", Vector3(0.2, 1.0, 0.3)]]:
			var it := (load("res://props/items/%s.tscn" % k[0]) as PackedScene).instantiate() as RigidBody3D
			it.name = k[1]
			car.add_child(it)
			it.freeze = true
			it.position = k[2]
			_done[k[1]] = it.get_node("Grab")
		(_done["TestBeer"] as BeerCan).opened = true
		(_done["TestBeer"] as BeerCan)._apply_open(true))
	if not _done.has("objets_test"):
		return
	var add := get_tree().get_first_node_in_group(PillAddiction.GROUP)
	var other := Net.other_head()
	if other == null or add == null:
		return
	var mouth := other.global_transform * EdiblePickable.MOUTH_OFFSET
	# main tenue au loin (celle du doigt, à 13 s, pose ses points sur la radio)
	_once("main_test", 17.2, func():
		var holder := Node3D.new()
		car.add_child(holder)
		var nh := VRHandInteractor.new()
		nh.name = "TestFeedHand"
		nh.hand_collision = false   # (téléportée d'un objet à une bouche : ne bute pas sur les sièges)
		holder.add_child(nh)
		nh.debug_points = [Vector3(0, -100, 0), Vector3(0, -100, 0)]
		_done["dh"] = nh)
	if Net.is_driver():
		var h: VRHandInteractor = _done.get("dh")
		if h == null:
			return
		var holder := h.get_parent() as Node3D
		var pill = _done["TestPill"]
		_once("pilule_prise", 17.5, func(): _test_grab(h, pill))
		if _t > 17.5 and _t < 18.8 and is_instance_valid(pill) and pill.is_grabbed():
			holder.global_position = holder.global_position.lerp(mouth, 0.2)
			pill.grab_update(h)
		var can: BeerCan = _done["TestBeer"]
		_once("biere_prise", 19.5, func(): _test_grab(h, can))
		if _t > 19.5 and _t < 22.0 and can.is_grabbed():
			var tilt := Basis(car.global_basis.x, deg_to_rad(60.0)) * car.global_basis
			var xf := Transform3D(tilt, Vector3.ZERO)
			xf.origin = mouth - xf.basis * Vector3(0, BeerCan.HEIGHT, 0.012)
			# la main avance vers la bouche (un objet tenu ne traverse pas l'habitacle)
			holder.global_transform = holder.global_transform.interpolate_with(xf * can._offset.affine_inverse(), 0.15)
			can.grab_update(h)
		_once("biere_lachee", 22.0, func(): _test_release(h, can))
	else:
		var h: VRHandInteractor = _done.get("dh")
		if h == null:
			return
		var holder := (h as Node3D).get_parent() as Node3D
		var joint: Smokable = _done["TestJoint"]
		_once("joint_pris", 22.5, func():
			_test_grab(h, joint)
			joint.light())
		if _t > 22.5 and _t < 25.5 and joint.is_grabbed():
			holder.global_position += (mouth - joint.butt_position()) * 0.2
			joint.grab_update(h)
		_once("joint_lache", 25.5, func(): _test_release(h, joint))
	_once("bilan_pilule", 19.2, func():
		print("NETTEST %s pilule portée par le conducteur à la bouche du copilote : pilules avalées ici = %d, pilule encore là = %s" % [
			_who(), add.pills_taken, is_instance_valid(_done["TestPill"])]))
	_once("bilan_biere", 22.4, func():
		print("NETTEST %s bière tenue par le conducteur à la bouche du copilote : alcool ici = %.3f, canette pleine à %.2f" % [
			_who(), add.alcohol, (_done["TestBeer"] as BeerCan).fill]))
	_once("bilan_joint", 26.0, func():
		print("NETTEST %s joint tenu par le copilote à la bouche du conducteur : défonce ici = %.3f" % [_who(), add.stoned]))
	# radio allumée sur la même station chez les deux : le copilote doit se caler
	_once("radio_on", 23.5, func():
		car.radio.set("car", null)   # (pas de clé de contact dans le test : marche quand même)
		car.radio.power = true
		car.radio.station = 1)
	_once("bilan_radio", 26.5, func():
		var r := car.radio
		var sp: AudioStreamPlayer3D = r.speakers[0] if not r.speakers.is_empty() else null
		print("NETTEST %s radio : marche=%s station=%d morceau=%d position=%.2f s à %.3f" % [_who(), r.is_on(), r.station,
			r.get("_track"), sp.get_playback_position() if sp and sp.playing else -1.0, Time.get_unix_time_from_system()]))
	_once("bilan_objets", 27.0, func():
		for n in ["Lighter", "TestBeer"]:
			var it := car.find_child(n, true, false) as Node3D
			if it:
				var p := car.to_local(it.global_position)
				print("NETTEST %s objet %s dans %s à (%.3f, %.3f, %.3f)" % [_who(), n, it.get_parent().name, p.x, p.y, p.z]))


## Saisie / lâcher par la main de test, signalés comme le fait la vraie main.
func _test_grab(h: VRHandInteractor, it: VRInteractable) -> void:
	(h.get_parent() as Node3D).global_position = it.item.global_position
	it.grab(h)
	h.interacted.emit(NetSession.HandEvent.GRAB, it)


func _test_release(h: VRHandInteractor, it: VRInteractable) -> void:
	it.release(h)
	h.interacted.emit(NetSession.HandEvent.RELEASE, it)
