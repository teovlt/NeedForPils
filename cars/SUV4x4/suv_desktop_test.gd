extends Node3D
## Scène de test sans casque : conduite au clavier + caméra.
## V = caméra extérieure / place conducteur, H = simuler une main proche de
## toutes les pièces interactives (pour voir les contours lumineux).
## Le 4x4 démarre ici en D, frein à main desserré (voir SUV4x4 dans la scène).
## Autres touches : voir l'en-tête de suv_4x4.gd.

@export var autotest := false
## Scénario du test automatique : "objets" (rangements) ou "arbres".
@export_enum("objets", "arbres", "aleatoire", "phares", "retros", "portes", "boite", "combine", "essuie", "plafonnier", "nature") var autotest_scenario := "objets"

@onready var car: SUV4x4 = $SUV4x4
@onready var cam: Camera3D = $Camera3D

var _inside := false
var _debug_highlight := false
var _t := 0.0


var _mouse_hand: MouseHand


func _ready() -> void:
	# Main souris pour attraper les objets en vue conducteur (V pour changer de vue).
	_mouse_hand = MouseHand.new()
	_mouse_hand.camera = cam
	_mouse_hand.anchor = car.driver_seat
	add_child(_mouse_hand)
	if not autotest:
		_inside = true


func _physics_process(delta: float) -> void:
	_mouse_hand.set_process(_inside)
	_mouse_hand.set_physics_process(_inside)
	if autotest:
		if autotest_scenario == "arbres":
			_run_autotest(delta)
		elif autotest_scenario == "aleatoire":
			_run_autotest_random(delta)
		elif autotest_scenario == "phares":
			_run_autotest_lights(delta)
		elif autotest_scenario == "retros":
			_run_autotest_mirrors(delta)
		elif autotest_scenario == "portes":
			_run_autotest_doors(delta)
		elif autotest_scenario == "boite":
			_run_autotest_glovebox(delta)
		elif autotest_scenario == "combine":
			_run_autotest_cluster(delta)
		elif autotest_scenario == "essuie":
			_run_autotest_rear_wiper(delta)
		elif autotest_scenario == "plafonnier":
			_run_autotest_dome(delta)
		elif autotest_scenario == "nature":
			_run_autotest_nature(delta)
		else:
			_run_autotest_items(delta)
		if not _inside:
			return
	if _inside:
		pass   # la caméra est placée par la main souris (regard au clic droit)
	else:
		var target := car.global_position + Vector3.UP * 1.2
		var behind := car.global_position - car.global_basis.z * 7.0 + Vector3.UP * 3.0
		cam.global_position = cam.global_position.lerp(behind, clampf(4.0 * delta, 0.0, 1.0))
		cam.look_at(target)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	match (event as InputEventKey).physical_keycode:
		KEY_V:
			_inside = not _inside
		KEY_H:
			_debug_highlight = not _debug_highlight
			for it in get_tree().get_nodes_in_group(VRInteractable.GROUP):
				it.set_hand_distance(self, 0.03 if _debug_highlight else -1.0)


func _log(msg: String) -> void:
	printerr(msg)
	var f := FileAccess.open("res://.godot/suv_autotest.log", FileAccess.READ_WRITE if FileAccess.file_exists("res://.godot/suv_autotest.log") else FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line(msg)


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("res://.godot/autotest_%s.png" % name)
	_log("AUTOTEST shot=%s t=%.1f" % [name, _t])


var _tree_a: FallingTree
var _tree_b: FallingTree
var _avoid := true


func _run_autotest(delta: float) -> void:
	# Scénario arbres : un arbre esquivé, puis un arbre percuté (pilote sans esquive).
	var w: WeatherSystem = $Weather
	var road: RoadGenerator = $RoadGenerator
	var trees: FallingTreeManager = $FallingTrees
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	w.random_events = false
	trees.enabled = false   # chutes déclenchées à la main dans ce test
	car.external_input = true
	if at.call(0.05):
		w.hour = 15.0
		w.set_weather("eclaircies", true)
	if at.call(4.0):
		_tree_a = trees.spawn_ahead(75.0, 1)
		_log("AUTOTEST arbre A : hauteur %.1f m, bloque latéral %s" % [_tree_a.height, _tree_a.blocked_lateral])
	if at.call(14.0):
		_avoid = false
		_tree_b = trees.spawn_ahead(60.0, 1)
		_log("AUTOTEST arbre B (sans esquive) : hauteur %.1f m, bloque latéral %s" % [_tree_b.height, _tree_b.blocked_lateral])
	var fwd := car.global_basis.z
	# Voie visée : voie de droite, sauf si un arbre tombé/en chute barre la route devant.
	var target_lat := 1.75
	if _avoid:
		for t in trees.get_active_trees():
			if t.state == FallingTree.State.SHAKING:
				continue
			var ahead := (t.road_point - car.global_position).dot(t.road_dir)
			if ahead > -5.0 and ahead < 45.0:
				var lo := t.blocked_lateral.x
				var hi := t.blocked_lateral.y
				var free_left := lo - (-5.5)     # place entre le bord gauche et l'arbre
				var free_right := 5.5 - hi
				target_lat = (-5.5 + lo) * 0.5 if free_left > free_right else (hi + 5.5) * 0.5
				target_lat = clampf(target_lat, -3.6, 3.6)
	var info := road.sample_road(car.global_position + fwd * 14.0)
	if info["found"]:
		var target: Vector3 = info["point"] + info["right"] * target_lat
		var to_t := target - car.global_position
		to_t.y = 0.0
		car._kb_steer = clampf(fwd.cross(to_t.normalized()).y * 2.0, -1.0, 1.0)
	var speed_kmh := car.forward_speed * 3.6
	car.throttle_input = 0.8 if speed_kmh < 45.0 else 0.0
	car.brake_input = 0.0
	# Caméra de poursuite haute
	_inside = false
	cam.global_position = car.global_position - fwd * 11.0 + Vector3.UP * 6.5
	cam.look_at(car.global_position + fwd * 22.0)
	if _tree_a and is_instance_valid(_tree_a):
		if _tree_a.state == FallingTree.State.FALLING and not _tree_a.has_meta("shot1") and _tree_a.angle > 0.6:
			_tree_a.set_meta("shot1", true)
			_shot("arbre_1_chute")
		if _tree_a.state == FallingTree.State.FALLEN and not _tree_a.has_meta("shot2") and (_tree_a.road_point - car.global_position).dot(fwd) < 14.0:
			_tree_a.set_meta("shot2", true)
			_shot("arbre_2_esquive")
	if _tree_b and is_instance_valid(_tree_b) and _tree_b.has_meta("hit") and not _tree_b.has_meta("shot3"):
		_tree_b.set_meta("shot3", true)
		_shot("arbre_3_choc")
	if int(_t) != int(t0):
		var lat: float = road.sample_road(car.global_position).get("lateral", 0.0)
		var st_a: String = (["tremble", "tombe", "au sol"][_tree_a.state] if _tree_a and is_instance_valid(_tree_a) else "-")
		var st_b: String = (["tremble", "tombe", "au sol"][_tree_b.state] if _tree_b and is_instance_valid(_tree_b) else "-")
		_log("AUTOTEST t=%d vitesse=%d km/h voie=%.2f cible=%.2f arbreA=%s arbreB=%s évités=%d chocs=%d" % [int(_t), speed_kmh, lat, target_lat, st_a, st_b, trees.trees_avoided, trees.tree_hits])
	if at.call(26.0): get_tree().quit()


# --- Test automatique des objets rangés -------------------------------------

var _hand: Node3D
var _held: VRPickable
var _move_from := Vector3.ZERO
var _move_to := Vector3.ZERO
var _move_t0 := 0.0
var _move_dur := 1.0


func _item(path: String) -> RigidBody3D:
	for it in car.find_children("*", "RigidBody3D", true, false):
		if it.name == path:
			return it
	return null


func _report(tag: String) -> void:
	for it in car.find_children("*", "RigidBody3D", true, false):
		var g := it.get_node_or_null("Grab") as VRPickable
		if g:
			var lp := car.to_local(it.global_position)
			_log("AUTOTEST %s %s dans %s pos_voiture=(%.3f, %.3f, %.3f) attrapable=%s" % [tag, it.name, it.get_parent().name, lp.x, lp.y, lp.z, g.enabled])
	for it in get_tree().current_scene.find_children("*", "RigidBody3D", true, false):
		if it.get_node_or_null("Grab") and not car.is_ancestor_of(it):
			_log("AUTOTEST %s %s hors voiture (parent %s) pos=%s vitesse=%.1f" % [tag, it.name, it.get_parent().name, it.global_position, it.linear_velocity.length()])


func _grab_item(name: String, to_car_local: Vector3, dur: float) -> void:
	var it := _item(name)
	if it == null:
		_log("AUTOTEST ERREUR objet introuvable : " + name)
		return
	_held = it.get_node("Grab")
	_hand.global_transform = Transform3D(car.global_basis, it.global_position)
	_held.grab(_hand)
	_move_from = car.to_local(it.global_position)
	_move_to = to_car_local
	_move_t0 = _t
	_move_dur = dur
	_log("AUTOTEST attrape %s (attrapé=%s)" % [name, _held.is_grabbed()])


func _release_item() -> void:
	if _held:
		_log("AUTOTEST lâche %s" % _held.item.name)
		_held.release(_hand)
		_held = null


func _cabin_cam(pos: Vector3, look: Vector3) -> void:
	cam.global_position = car.to_global(pos)
	cam.look_at(car.to_global(look))


func _run_autotest_items(delta: float) -> void:
	var w: WeatherSystem = $Weather
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	w.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	car.throttle_input = 0.0
	car.brake_input = 1.0
	_inside = false
	if _hand == null:
		_hand = Node3D.new()
		add_child(_hand)
	# Déplacement de la main qui tient l'objet (repère voiture)
	if _held:
		var k := clampf((_t - _move_t0) / _move_dur, 0.0, 1.0)
		_hand.global_position = car.to_global(_move_from.lerp(_move_to, k))
		_held.grab_update(_hand)
	if at.call(0.05):
		w.hour = 13.0
		w.set_weather("degage", true)
		cam.fov = 80.0
	# Vue de la tête du conducteur vers la planche de bord
	if _t < 2.5:
		_cabin_cam(Vector3(0.3, 1.5, -0.25), Vector3(-0.25, 0.95, 0.8))      # vue conducteur
	elif _t < 5.0:
		_cabin_cam(Vector3(-0.25, 1.22, 0.3), Vector3(-0.55, 0.86, 0.85))    # boîte à gants
	elif _t < 9.0:
		_cabin_cam(Vector3(0.12, 1.4, -0.3), Vector3(0.0, 0.62, 0.1))        # accoudoir
	elif _t < 13.0:
		_cabin_cam(Vector3(3.5, 2.2, -2.5), Vector3(0.8, 0.9, 0.6))          # lancer par la fenêtre
	else:
		_cabin_cam(Vector3(-0.3, 1.2, 0.0), Vector3(-0.8, 0.64, 0.55))       # vide-poche passager (cigarette)
	if at.call(1.5):
		_report("départ")
		_shot("objets_1_fermes")
	if at.call(2.0):
		$SUV4x4/GloveboxLid.open()
		$SUV4x4/ConsoleLid.open()
	if at.call(3.5):
		_report("ouverts")
		_shot("objets_2_boite_a_gants")
	# Pilule : de la boîte à gants vers le siège passager (lâchée en l'air)
	if at.call(4.0): _grab_item("PillCapsule", Vector3(-0.45, 1.15, 0.0), 1.0)
	if at.call(5.3): _release_item()
	# Pilule smiley : boîte à gants -> accoudoir (rangement)
	if at.call(5.5): _grab_item("PillSmiley", Vector3(0.0, 0.75, 0.1), 1.0)
	if at.call(6.8): _release_item()
	# GPS : décroché puis remis sur son support
	if at.call(7.0): _grab_item("GPS", Vector3(0.2, 1.15, 0.4), 0.6)
	if at.call(7.7):
		_move_from = _move_to
		_move_to = Vector3(0.12, 1.27, 0.79)
		_move_t0 = _t
		_move_dur = 0.6
	if at.call(8.5): _release_item()
	if at.call(5.4): _shot("objets_3_accoudoir")
	if at.call(8.8):
		_report("rangés")
		_shot("objets_4_ranges")
	# Thermos (vide-poche conducteur) : jeté par la fenêtre
	if at.call(9.2): _grab_item("Thermos", Vector3(0.75, 1.35, 0.1), 0.5)
	if at.call(9.7):
		_move_from = _move_to
		_move_to = Vector3(2.0, 1.5, 0.3)
		_move_t0 = _t
		_move_dur = 0.15
	if at.call(9.85): _release_item()
	if at.call(10.2): _shot("objets_5_lancer")
	if at.call(12.5):
		_report("après lancer")
		_shot("objets_6_thermos_dehors")
	if at.call(13.5): _shot("objets_7_vide_poche")
	if at.call(14.5): get_tree().quit()


func _run_autotest_random(delta: float) -> void:
	# Vérifie le rangement aléatoire : journal + captures de chaque rangement.
	var w: WeatherSystem = $Weather
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	w.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	car.throttle_input = 0.0
	car.brake_input = 1.0
	_inside = false
	cam.fov = 80.0
	if at.call(0.05):
		w.hour = 13.0
		w.set_weather("degage", true)
		$SUV4x4/GloveboxLid.open()
		$SUV4x4/ConsoleLid.open()
	if _t < 2.0:
		_cabin_cam(Vector3(0.3, 1.5, -0.25), Vector3(-0.25, 0.85, 0.6))
	elif _t < 3.0:
		_cabin_cam(Vector3(-0.25, 1.22, 0.3), Vector3(-0.55, 0.86, 0.85))
	elif _t < 4.0:
		_cabin_cam(Vector3(0.12, 1.4, -0.3), Vector3(0.0, 0.62, 0.1))
	elif _t < 5.0:
		_cabin_cam(Vector3(0.2, 1.25, 0.05), Vector3(0.8, 0.66, 0.5))
	else:
		_cabin_cam(Vector3(-0.2, 1.25, 0.05), Vector3(-0.8, 0.66, 0.5))
	if at.call(1.5):
		_report("aléatoire")
		_shot("alea_1_conducteur")
	if at.call(2.8): _shot("alea_2_boite_a_gants")
	if at.call(3.8): _shot("alea_3_accoudoir")
	if at.call(4.8): _shot("alea_4_vide_poche_conducteur")
	if at.call(5.8): _shot("alea_5_vide_poche_passager")
	if at.call(6.2): get_tree().quit()


func _run_autotest_lights(delta: float) -> void:
	# De nuit : chaque cran du comodo des phares, vu de derrière la voiture.
	var w: WeatherSystem = $Weather
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	w.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	car.throttle_input = 0.0
	car.brake_input = 1.0
	_inside = false
	cam.fov = 70.0
	if at.call(0.05):
		w.hour = 23.5
		w.set_weather("degage", true)
		car.light_stalk.set_notch(0, true)
	if _t < 9.0:
		_cabin_cam(Vector3(1.2, 3.2, -6.5), Vector3(0.0, 0.5, 12.0))
	elif _t < 10.5:
		_cabin_cam(Vector3(0.45, 1.45, -0.05), Vector3(0.6, 0.95, 0.6))
	else:
		_cabin_cam(Vector3(3.5, 2.6, 5.5), Vector3(0.0, 1.4, 1.0))
	for i in 5:
		if at.call(1.0 + i * 1.6):
			car.light_stalk.set_notch(i, true)
		if at.call(2.2 + i * 1.6):
			_log("AUTOTEST phares cran=%s état=%d" % [car.light_stalk.get_notch_label(), car._lights_state])
			_shot("phares_%d_%s" % [i, car.light_stalk.get_notch_label().replace(" + ", "_").to_lower()])
	if at.call(10.2): _shot("phares_5_comodo")
	if at.call(11.5): _shot("phares_6_barre_avant")
	if at.call(12.0): get_tree().quit()


func _run_autotest_mirrors(delta: float) -> void:
	# Rétroviseurs : des repères colorés derrière la voiture, vus depuis la place du conducteur.
	var w: WeatherSystem = $Weather
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	w.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	car.throttle_input = 0.0
	car.brake_input = 1.0
	_inside = false
	cam.fov = 18.0 if _t >= 3.0 and _t < 6.0 else 75.0
	if at.call(0.05):
		w.hour = 14.0
		w.set_weather("degage", true)
	if at.call(1.0):
		var colors := [Color(1, 0.1, 0.1), Color(0.1, 0.4, 1), Color(1, 0.85, 0.1)]
		var spots := [Vector3(0, 1.0, -9), Vector3(3.2, 1.0, -14), Vector3(-3.2, 1.0, -14)]
		for i in 3:
			var m := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(1.2, 2.0, 1.2)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = colors[i]
			b.material = mat
			m.mesh = b
			add_child(m)
			m.global_position = car.to_global(spots[i])
		_log("AUTOTEST repères posés : rouge au centre, bleu à gauche, jaune à droite")
	var eye := Vector3(0.45, 1.45, -0.05)
	if _t < 3.0:
		_cabin_cam(eye, Vector3(0.0, 1.62, 0.55))
	elif _t < 4.5:
		_cabin_cam(eye, Vector3(1.1, 1.22, 0.79))
	elif _t < 6.0:
		_cabin_cam(eye, Vector3(-1.1, 1.22, 0.79))
	elif _t < 7.5:
		_cabin_cam(eye + Vector3(-0.15, 0.0, 0.0), Vector3(0.0, 1.62, 0.55))
	else:
		_cabin_cam(eye, Vector3(0.0, 1.62, 0.55))
	if at.call(2.5): _shot("retro_1_central")
	if at.call(4.2):
		_shot("retro_2_gauche")
		for path in ["RearMirror", "Doors/DoorFL/Mirror", "Doors/DoorFR/Mirror"]:
			var mm := car.get_node(path) as VRMirror
			mm._viewport.get_texture().get_image().save_png("res://.godot/autotest_mirrortex_%s.png" % path.replace("/", "_"))
			_log("AUTOTEST %s glace=%s normale=%s cam=%s cam_z=%s near=%.3f" % [path, car.to_local(mm._glass.global_position), car.global_basis.inverse() * mm._glass.global_basis.z, car.to_local(mm._cam.global_position), car.global_basis.inverse() * mm._cam.global_basis.z, mm._cam.near])
	if at.call(5.7): _shot("retro_3_droit")
	if at.call(7.2): _shot("retro_4_tete_decalee")
	# Réglage à la main du rétro central (main fictive déplacée de 4 cm)
	if at.call(7.6):
		if _hand == null:
			_hand = Node3D.new()
			add_child(_hand)
		var mirror := car.get_node("RearMirror") as VRMirror
		_hand.global_position = mirror.global_position
		mirror.grab(_hand)
		_hand.global_position = car.to_global(car.to_local(mirror.global_position) + Vector3(-0.04, 0, 0))
		mirror.grab_update(_hand)
		mirror.release(_hand)
	if at.call(8.5): _shot("retro_5_regle")
	# Vues rapprochées : rétro central de profil, rétros extérieurs de près
	if _t >= 8.7 and _t < 9.6:
		cam.fov = 40.0
		_cabin_cam(Vector3(0.38, 1.66, 0.12), Vector3(0.0, 1.68, 0.44))
	elif _t >= 9.6 and _t < 10.5:
		cam.fov = 40.0
		_cabin_cam(Vector3(1.75, 1.45, -0.6), Vector3(1.1, 1.23, 0.8))
	elif _t >= 10.5:
		cam.fov = 40.0
		_cabin_cam(Vector3(-1.75, 1.45, -0.6), Vector3(-1.1, 1.23, 0.8))
	if at.call(8.6):
		# Rétro central orienté au maximum vers le haut (cas où la tige traversait la glace)
		var rm := car.get_node("RearMirror") as VRMirror
		rm._pitch = -deg_to_rad(rm.max_adjust_deg)
		rm._apply_rotation()
	if at.call(9.4): _shot("retro_6_central_profil")
	if at.call(10.3): _shot("retro_7_gauche_dehors")
	if at.call(11.2): _shot("retro_8_droit_dehors")
	if at.call(11.5): get_tree().quit()


# --- Test des poignées de porte ----------------------------------------------

var _door_hand_path := []   # [t0, t1, from_local, to_local, hinge_local(or null)]


func _hand_arc(t0: float, t1: float, from_l: Vector3, to_angle: float, hinge_l: Vector3) -> void:
	_door_hand_path = [t0, t1, from_l, to_angle, hinge_l]


func _run_autotest_doors(delta: float) -> void:
	var w: WeatherSystem = $Weather
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	w.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	car.throttle_input = 0.0
	car.brake_input = 1.0
	_inside = false
	cam.fov = 60.0
	if _hand == null:
		_hand = Node3D.new()
		add_child(_hand)
	var door := car.get_node("Doors/DoorFL") as VRHingeInteractable
	var h_out := car.get_node("Doors/DoorFL/HandleOut") as VRDoorHandle
	var h_in := car.get_node("Doors/DoorFL/HandleIn") as VRDoorHandle
	var hinge := Vector3(0.95, 1.06, 0.98)
	# Déplacement de la main (repère voiture) : ligne droite ou arc autour de la charnière
	if not _door_hand_path.is_empty() and _t >= _door_hand_path[0] and _t <= _door_hand_path[1] + delta:
		var k := clampf((_t - _door_hand_path[0]) / (_door_hand_path[1] - _door_hand_path[0]), 0.0, 1.0)
		var from_l: Vector3 = _door_hand_path[2]
		var target = _door_hand_path[3]
		var p: Vector3
		if target is float:
			var hl: Vector3 = _door_hand_path[4]
			var off := from_l - hl
			p = hl + off.rotated(Vector3.UP, float(target) * k)
		else:
			var to_l: Vector3 = target
			p = from_l.lerp(to_l, k)
		_hand.global_position = car.to_global(p)
		for hh in [h_out, h_in]:
			if hh.is_grabbed():
				hh.grab_update(_hand)
	if at.call(0.05):
		w.hour = 14.0
		w.set_weather("degage", true)
	if _t < 5.5:
		_cabin_cam(Vector3(2.6, 1.7, -1.4), Vector3(0.95, 1.0, 0.3))
	else:
		_cabin_cam(Vector3(0.45, 1.45, -0.05), Vector3(0.85, 1.0, 0.45))
	if at.call(0.7): h_out.set_hand_distance(_hand, 0.03)
	if at.call(1.0):
		_log("AUTOTEST porte FL fermée angle=%.1f, porte saisissable=%s" % [rad_to_deg(door.angle), door.enabled])
		_shot("porte_1_poignee_ciblee")
	if at.call(1.2): h_out.set_hand_distance(_hand, -1.0)
	var grip := Vector3(0.97, 1.058, 0.14)   # milieu de la poignée extérieure
	if at.call(1.5):
		_hand.global_position = car.to_global(grip)
		h_out.grab(_hand)
		_door_hand_path = [1.5, 2.3, grip, grip + Vector3(0.035, 0.0, 0.0), null]
	if at.call(1.9):
		_log("AUTOTEST poignée tirée à moitié : angle=%.1f, porte=%.1f" % [rad_to_deg(h_out.angle), rad_to_deg(door.angle)])
		_shot("porte_2_poignee_tiree")
	if at.call(2.4):
		_log("AUTOTEST poignée tirée : angle=%.1f, déverrouillée=%s" % [rad_to_deg(h_out.angle), h_out._swinging])
		_hand_arc(2.4, 3.6, grip + Vector3(0.035, 0, 0), deg_to_rad(-50.0), hinge)
	if at.call(3.8):
		_log("AUTOTEST porte tirée par la poignée : angle=%.1f" % rad_to_deg(door.angle))
		_shot("porte_3_ouverte")
		h_out.release(_hand)
	if at.call(4.4):
		_log("AUTOTEST poignée relâchée : poignée=%.1f, porte=%.1f (doit rester ouverte)" % [rad_to_deg(h_out.angle), rad_to_deg(door.angle)])
	# Fermeture par la poignée intérieure
	if at.call(4.6):
		var gin := car.to_local(h_in.to_global(Vector3(-0.005, 0.0, -0.05)))
		_hand.global_position = car.to_global(gin)
		h_in.grab(_hand)
		_log("AUTOTEST poignée intérieure saisie (porte ouverte) : entraîne la porte=%s" % h_in._swinging)
		_hand_arc(4.6, 5.4, gin, deg_to_rad(48.0), hinge)
	if at.call(5.5):
		h_in.release(_hand)
	if at.call(6.3):
		_log("AUTOTEST porte refermée : angle=%.1f, ouverte=%s" % [rad_to_deg(door.angle), door.is_open()])
		_shot("porte_4_poignee_interieure")
	if at.call(6.0): h_in.set_hand_distance(_hand, 0.03)
	if at.call(6.5): h_in.set_hand_distance(_hand, -1.0)
	if at.call(6.6):
		h_in.toggle()
	if at.call(7.6):
		_log("AUTOTEST A/X sur la poignée intérieure : porte=%.1f" % rad_to_deg(door.angle))
		_shot("porte_5_toggle")
	if at.call(8.0): get_tree().quit()


# --- Test boîte à gants + boutons des leviers ---------------------------------

func _run_autotest_glovebox(delta: float) -> void:
	var w: WeatherSystem = $Weather
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	w.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	car.throttle_input = 0.0
	car.brake_input = 1.0
	_inside = false
	cam.fov = 60.0
	if _hand == null:
		_hand = Node3D.new()
		add_child(_hand)
	var lid := car.get_node("GloveboxLid") as VRHingeInteractable
	var handle := car.get_node("GloveboxLid/Handle") as VRDoorHandle
	if not _door_hand_path.is_empty() and _t >= _door_hand_path[0] and _t <= _door_hand_path[1] + delta:
		var k := clampf((_t - _door_hand_path[0]) / (_door_hand_path[1] - _door_hand_path[0]), 0.0, 1.0)
		var from_l: Vector3 = _door_hand_path[2]
		var target = _door_hand_path[3]
		var p: Vector3
		if target is float:
			var hl: Vector3 = _door_hand_path[4]
			p = hl + (from_l - hl).rotated(Vector3.RIGHT, float(target) * k)
		else:
			var to_l: Vector3 = target
			p = from_l.lerp(to_l, k)
		_hand.global_position = car.to_global(p)
		if handle.is_grabbed():
			handle.grab_update(_hand)
	if at.call(0.05):
		w.hour = 14.0
		w.set_weather("degage", true)
	if _t < 7.0:
		_cabin_cam(Vector3(-0.45, 1.4, 0.0), Vector3(-0.5, 0.92, 0.72))
	elif _t < 9.0:
		_cabin_cam(Vector3(0.12, 1.15, 0.2), Vector3(0.0, 0.92, 0.5))
	else:
		_cabin_cam(Vector3(0.0, 1.15, -0.45), Vector3(0.165, 0.88, -0.25))
	var grip := car.to_local(handle.to_global(Vector3(0, -0.018, 0.0)))
	if at.call(0.7): handle.set_hand_distance(_hand, 0.03)
	if at.call(1.0):
		_log("AUTOTEST boîte à gants fermée : angle=%.1f, couvercle saisissable=%s" % [rad_to_deg(lid.angle), lid.enabled])
		_shot("boite_1_poignee_ciblee")
	if at.call(1.2): handle.set_hand_distance(_hand, -1.0)
	if at.call(1.5):
		_hand.global_position = car.to_global(grip)
		handle.grab(_hand)
		_door_hand_path = [1.5, 2.1, grip, grip + Vector3(0, 0, -0.022), null]
	if at.call(1.9): _shot("boite_2_poignee_tiree")
	if at.call(2.2):
		_log("AUTOTEST poignée tirée : angle=%.1f, déverrouillée=%s" % [rad_to_deg(handle.angle), handle._swinging])
		handle.release(_hand)
	if at.call(2.45): _shot("boite_3_ouverture")
	if at.call(3.2):
		_log("AUTOTEST boîte à gants après lâcher : angle=%.1f (doit être ouverte à -80)" % rad_to_deg(lid.angle))
		_shot("boite_4_ouverte")
	# Fermeture : on saisit la poignée et on remonte le couvercle
	if at.call(3.6):
		var g2 := car.to_local(handle.to_global(Vector3(0, -0.018, 0.0)))
		_hand.global_position = car.to_global(g2)
		handle.grab(_hand)
		_log("AUTOTEST poignée saisie couvercle ouvert : entraîne le couvercle=%s" % handle._swinging)
		_door_hand_path = [3.6, 4.6, g2, deg_to_rad(76.0), Vector3(-0.525, 0.805, 0.7)]
	if at.call(4.7): handle.release(_hand)
	if at.call(5.5):
		_log("AUTOTEST boîte à gants refermée : angle=%.1f, ouverte=%s" % [rad_to_deg(lid.angle), lid.is_open()])
		_shot("boite_5_refermee")
	# Boutons des leviers
	var gb := car.get_node("GearLever/Button") as Node3D
	var hb := car.get_node("Handbrake/Button") as Node3D
	if at.call(7.0):
		_log("AUTOTEST bouton levier au repos : %s" % gb.position)
		_shot("bouton_1_levier_repos")
		_hand.global_position = car.gear_lever.global_position + Vector3.UP * 0.15
		car.gear_lever.grab(_hand)
	if at.call(7.6):
		_log("AUTOTEST bouton levier, levier tenu : %s" % gb.position)
		_shot("bouton_2_levier_enfonce")
		car.gear_lever.release(_hand)
	if at.call(8.3): _log("AUTOTEST bouton levier relâché : %s" % gb.position)
	if at.call(9.2):
		_log("AUTOTEST bouton frein à main au repos : %s" % hb.position)
		_shot("bouton_3_frein_repos")
		_hand.global_position = car.handbrake_lever.to_global(Vector3(0, 0.08, 0.25))
		car.handbrake_lever.grab(_hand)
	if at.call(9.8):
		_log("AUTOTEST bouton frein à main, levier tenu : %s" % hb.position)
		_shot("bouton_4_frein_enfonce")
		car.handbrake_lever.release(_hand)
	if at.call(10.5):
		_log("AUTOTEST bouton frein à main relâché : %s" % hb.position)
		get_tree().quit()


# --- Test du combiné d'instruments ----------------------------------------------

func _run_autotest_cluster(delta: float) -> void:
	var w: WeatherSystem = $Weather
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	w.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	_inside = false
	if at.call(0.05):
		w.hour = 20.6
		w.set_weather("degage", true)
		car.light_stalk.set_notch(1, true)   # AUTO
		car.handbrake_lever.set_angle_deg(car.handbrake_full_deg - 5.0, true)
	if _t < 2.0:
		car.throttle_input = 0.0
		car.brake_input = 1.0
	else:
		car.brake_input = 0.0
		car.throttle_input = 1.0 if car.forward_speed * 3.6 < 70.0 else 0.0
		car._kb_steer = 0.0
	if at.call(2.0):
		car.handbrake_lever.set_angle_deg(0.0, true)
		car.light_stalk.set_notch(4, true)   # PHARES + BARRE
	var eye := Vector3(0.45, 1.45, -0.05)
	if _t < 6.0 or _t >= 7.0:
		cam.fov = 38.0
		_cabin_cam(eye, Vector3(0.45, 1.17, 0.71))
	else:
		cam.fov = 75.0
		_cabin_cam(eye, Vector3(0.45, 1.2, 0.9))
	if at.call(1.5):
		_log("AUTOTEST arrêt : vitesse=%.0f, frein à main=%.2f, phares=%s" % [car.forward_speed * 3.6, car.get_handbrake_amount(), car.get_lights_on()])
		_shot("combine_1_arret")
	if at.call(5.5):
		_log("AUTOTEST roulage : vitesse=%.0f, phares=%s" % [car.forward_speed * 3.6, car.get_lights_on()])
		_shot("combine_2_roulage")
	if at.call(6.6):
		_shot("combine_3_vue_large")
		var cl := car.get_node("InstrumentCluster") as InstrumentCluster
		cl.get_node("ClusterView").get_texture().get_image().save_png("res://.godot/autotest_combine_ecran.png")
	if at.call(7.2): get_tree().quit()


# --- Test de l'essuie-glace arrière -------------------------------------------

func _run_autotest_rear_wiper(delta: float) -> void:
	var w: WeatherSystem = $Weather
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	w.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	car.throttle_input = 0.0
	car.brake_input = 1.0
	_inside = false
	cam.fov = 55.0
	if at.call(0.05):
		w.hour = 14.0
		w.set_weather("pluie", true)
	if at.call(1.0): car.wiper_stalk.set_notch(2, true)   # LENT
	# Vue de l'arrière, et une vue de l'avant pour comparer les angles
	if _t < 6.0:
		_cabin_cam(Vector3(0.5, 2.2, -4.8), Vector3(0.0, 1.5, -2.25))
	else:
		_cabin_cam(Vector3(1.2, 2.4, 4.0), Vector3(0.2, 1.2, 1.0))
	var rear := car.get_node("Wipers/WiperRear") as Node3D
	for tt in [1.0, 1.4, 1.75, 2.1, 2.45]:
		if at.call(tt):
			_log("AUTOTEST t=%.2f avant=%.0f° arrière=%.0f°" % [_t, rad_to_deg(car._wiper_angle), -rad_to_deg(rear.transform.basis.get_euler().z)])
	if at.call(1.4): _shot("essuie_1_depart")
	if at.call(1.75): _shot("essuie_2_milieu")
	if at.call(2.45): _shot("essuie_3_retour")
	if at.call(6.5): _shot("essuie_4_avant")
	if at.call(7.0): get_tree().quit()


# --- Test des plafonniers -----------------------------------------------------

func _run_autotest_dome(delta: float) -> void:
	var w: WeatherSystem = $Weather
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	w.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	car.throttle_input = 0.0
	car.brake_input = 1.0
	_inside = false
	cam.fov = 75.0
	if at.call(0.05):
		w.hour = 23.0
		w.set_weather("degage", true)
		car.light_stalk.set_notch(0, true)   # phares éteints, pour bien voir l'habitacle
	# Vue depuis la place passager arrière vers l'avant + le plafond
	if _t < 9.0:
		_cabin_cam(Vector3(-0.35, 1.45, -1.25), Vector3(0.15, 1.35, 0.6))
	else:
		cam.fov = 45.0
		_cabin_cam(Vector3(0.3, 1.4, 0.0), Vector3(0.0, 1.73, 0.25))
	var lens := car.dome_lenses[0]
	var light := car.get_node("DomeLights/FrontLight") as OmniLight3D
	var log_state := func(tag: String):
		_log("AUTOTEST %s : verre=%s (%.0f°), porte ouverte=%s, lumière avant=%.2f" % [tag, lens.get_notch_label(), rad_to_deg(lens.angle), car.is_any_door_open(), light.light_energy if light.visible else 0.0])
	if at.call(1.0):
		log_state.call("nuit, portes fermées")
		_shot("plafonnier_1_eteint")
	if at.call(1.2): car.get_node("Doors/DoorFL").set_angle_deg(-60.0, true)
	if at.call(2.0):
		log_state.call("porte ouverte")
		_shot("plafonnier_2_porte_ouverte")
	if at.call(2.2): car.get_node("Doors/DoorFL").set_angle_deg(0.0, true)
	if at.call(2.8):
		log_state.call("0,6 s après fermeture (extinction progressive)")
		_shot("plafonnier_3_extinction")
	if at.call(4.5): log_state.call("porte fermée depuis 2 s")
	# Appui sur le verre : PORTE -> OFF -> ON
	if at.call(5.0): lens.toggle()
	if at.call(5.6): log_state.call("1er appui")
	if at.call(5.8): lens.toggle()
	if at.call(6.6):
		log_state.call("2e appui")
		_shot("plafonnier_4_force_on")
	if at.call(9.6):
		_shot("plafonnier_5_verre_bascule")
	if at.call(10.0): get_tree().quit()


# --- Test de la végétation -----------------------------------------------------

func _run_autotest_nature(delta: float) -> void:
	var w: WeatherSystem = $Weather
	var road: RoadGenerator = $RoadGenerator
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	w.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	if at.call(0.05):
		w.hour = 11.0
		w.set_weather("degage", true)
		road.debug_timings = true
		car.handbrake_lever.set_angle_deg(0.0, true)
		car.gear_lever.set_notch(2, true)
	var fwd := car.global_basis.z
	var info := road.sample_road(car.global_position + fwd * 14.0)
	if info["found"]:
		var target: Vector3 = info["point"] + info["right"] * 1.75
		var to_t := target - car.global_position
		to_t.y = 0.0
		car._kb_steer = clampf(fwd.cross(to_t.normalized()).y * 2.0, -1.0, 1.0)
	car.throttle_input = 1.0 if car.forward_speed * 3.6 < 110.0 else 0.0
	car.brake_input = 0.0
	_inside = false
	cam.fov = 70.0
	cam.global_position = car.global_position - fwd * 14.0 + Vector3.UP * 9.0
	cam.look_at(car.global_position + fwd * 30.0)
	# vue latérale rapprochée juste après chaque capture (couleurs du décor)
	var ph := fposmod(_t - 3.0, 10.0)
	if _t > 3.0 and ph > 0.2 and ph <= 0.7:
		var side := car.global_basis.x * (1.0 if int((_t - 3.0) / 10.0) % 2 == 0 else -1.0)
		cam.global_position = car.global_position + Vector3.UP * 2.2 + side * 3.0 - fwd * 3.0
		cam.look_at(car.global_position + side * 22.0 + fwd * 8.0 + Vector3.UP * 1.5)
	for i in 6:
		if at.call(3.6 + i * 10.0):
			_shot("nature_cote_%d" % i)
		if at.call(3.0 + i * 10.0):
			var bw := road.get_biome_at(car.global_position)
			_log("AUTOTEST nature t=%.0f vitesse=%.0f biome sapins=%.2f mixte=%.2f prairie=%.2f montagne=%.2f altitude=%.0f" % [_t, car.forward_speed * 3.6, bw[0], bw[1], bw[2], bw[3], car.global_position.y])
			_shot("nature_%d" % i)
	if at.call(56.5): get_tree().quit()
