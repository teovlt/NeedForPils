extends Node3D
## Scène de test sans casque : conduite au clavier + caméra.
## V = caméra extérieure / place conducteur, H = simuler une main proche de
## toutes les pièces interactives (pour voir les contours lumineux).
## Le 4x4 démarre ici en D, frein à main desserré (voir SUV4x4 dans la scène).
## Autres touches : voir l'en-tête de suv_4x4.gd.

@export var autotest := false
## Scénario du test automatique : "objets" (rangements) ou "arbres".
@export_enum("objets", "arbres", "aleatoire", "phares", "retros", "portes", "boite", "combine", "essuie", "plafonnier", "nature", "pluie", "balayage", "menu", "lunette", "moteur", "klaxon", "vitres", "ceinture", "cle", "depart", "pare_soleil", "cle_f", "physique", "eclairage", "radio", "radio_nuit", "radio_pwr", "ambiance", "rangements", "ceintures", "vitesses", "sapins", "balises", "playlist", "animaux", "pochette", "lieu", "police", "manque", "zoo", "balade", "klaxon_animaux", "police_vue") var autotest_scenario := "objets"

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
		# traversées d'animaux aléatoires coupées, sauf dans leur propre scénario
		var am := $RoadGenerator.get_node_or_null("Animals")
		if am and autotest_scenario not in ["animaux", "balade"]:
			am.set("crossings_enabled", false)
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
		elif autotest_scenario == "pluie":
			_run_autotest_rain(delta)
		elif autotest_scenario == "balayage":
			_run_autotest_sweep(delta)
		elif autotest_scenario == "menu":
			_run_autotest_menu(delta)
		elif autotest_scenario == "lunette":
			_run_autotest_rear_window(delta)
		elif autotest_scenario == "moteur":
			_run_autotest_engine(delta)
		elif autotest_scenario == "klaxon":
			_run_autotest_horn(delta)
		elif autotest_scenario == "vitres":
			_run_autotest_windows(delta)
		elif autotest_scenario == "ceinture":
			_run_autotest_belt(delta)
		elif autotest_scenario == "cle":
			_run_autotest_key(delta)
		elif autotest_scenario == "depart":
			_run_autotest_start(delta)
		elif autotest_scenario == "pare_soleil":
			_run_autotest_visor(delta)
		elif autotest_scenario == "cle_f":
			_run_autotest_key_f(delta)
		elif autotest_scenario == "physique":
			_run_autotest_physics(delta)
		elif autotest_scenario == "eclairage":
			_run_autotest_cluster_light(delta)
		elif autotest_scenario == "radio":
			_run_autotest_radio(delta)
		elif autotest_scenario == "radio_nuit":
			_run_autotest_radio_night(delta)
		elif autotest_scenario == "radio_pwr":
			_run_autotest_radio_power(delta)
		elif autotest_scenario == "ambiance":
			_run_autotest_ambience(delta)
		elif autotest_scenario == "rangements":
			_run_autotest_storage_spots(delta)
		elif autotest_scenario == "ceintures":
			_run_autotest_all_belts(delta)
		elif autotest_scenario == "vitesses":
			_run_autotest_gears(delta)
		elif autotest_scenario == "sapins":
			_run_autotest_tree_hits(delta)
		elif autotest_scenario == "balises":
			_run_autotest_posts(delta)
		elif autotest_scenario == "playlist":
			_run_autotest_playlist(delta)
		elif autotest_scenario == "animaux":
			_run_autotest_animals(delta)
		elif autotest_scenario == "pochette":
			_run_autotest_pill_bag(delta)
		elif autotest_scenario == "lieu":
			_run_autotest_start_site(delta)
		elif autotest_scenario == "police":
			_run_autotest_police(delta)
		elif autotest_scenario == "manque":
			_run_autotest_craving(delta)
		elif autotest_scenario == "zoo":
			_run_autotest_zoo(delta)
		elif autotest_scenario == "balade":
			_run_autotest_drive_animals(delta)
		elif autotest_scenario == "klaxon_animaux":
			_run_autotest_horn_animals(delta)
		elif autotest_scenario == "police_vue":
			_run_autotest_police_view(delta)
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
		_steer(clampf(fwd.cross(to_t.normalized()).y * 2.0, -1.0, 1.0))
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


## Direction de la voiture pendant les tests (-1 à 1, + = gauche). Passe par les deux
## chemins : `_kb_steer` (direction clavier) et `external_steer` (ajouté sur dev pour le
## pilote automatique de l'intro : quand external_input est vrai, c'est lui que la voiture
## lit). `set` ne fait rien si la propriété n'existe pas, donc ça marche sur les deux branches.
func _steer(value: float) -> void:
	car.set("_kb_steer", value)
	car.set("external_steer", value)


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
	# Pochette de pilules : vers le siège passager (lâchée en l'air)
	if at.call(4.0): _grab_item("PillBag", Vector3(-0.45, 1.15, 0.0), 1.0)
	if at.call(5.3): _release_item()
	# Pochette : siège -> accoudoir (rangement)
	if at.call(5.5): _grab_item("PillBag", Vector3(0.0, 0.75, 0.1), 1.0)
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
		_steer(0.0)
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
		_steer(clampf(fwd.cross(to_t.normalized()).y * 2.0, -1.0, 1.0))
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



# --- Test de la pluie et des essuie-glaces ----------------------------------------
# Roule à 80 km/h sous les 3 niveaux de pluie avec différents modes d'essuie-glace et
# mesure l'eau restante sur le pare-brise côté conducteur (moyenne et maxi par étape).
const RAIN_STEPS := [
	# [début (s), météo, cran d'essuie-glace, nom]
	[0.0, "pluie_legere", 0, "legere_off"],
	[8.0, "pluie_legere", 1, "legere_int"],
	[22.0, "pluie", 1, "forte_int"],
	[32.0, "pluie", 2, "forte_lent"],
	[44.0, "pluie", 3, "forte_rapide"],
	[56.0, "orage", 3, "orage_rapide"],
	[68.0, "", 0, "fin"],
]
var _rain_stats := {}

func _run_autotest_rain(delta: float) -> void:
	var w: WeatherSystem = $Weather
	var road: RoadGenerator = $RoadGenerator
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	w.random_events = false
	w.transition_time = 0.5
	$FallingTrees.enabled = false
	car.external_input = true
	if at.call(0.05):
		w.hour = 13.0
		car.handbrake_lever.set_angle_deg(0.0, true)
		car.gear_lever.set_notch(2, true)
	# pilote automatique, voie de droite, 80 km/h
	var fwd := car.global_basis.z
	var info := road.sample_road(car.global_position + fwd * 14.0)
	if info["found"]:
		var target: Vector3 = info["point"] + info["right"] * 1.75
		var to_t := target - car.global_position
		to_t.y = 0.0
		_steer(clampf(fwd.cross(to_t.normalized()).y * 2.0, -1.0, 1.0))
	car.throttle_input = 1.0 if car.forward_speed * 3.6 < 80.0 else 0.0
	car.brake_input = 0.0
	_inside = false
	cam.fov = 75.0
	# vue du conducteur, sauf un instant de l'extérieur pour voir la pluie sur le toit
	var outside := (_t > 50.0 and _t < 53.0)
	if outside:
		cam.fov = 60.0
		_cabin_cam(Vector3(-2.6, 2.6, -1.0), Vector3(0.0, 1.6, 0.4))
	elif _t > 60.0 and _t < 63.0:
		_cabin_cam(Vector3(-0.1, 1.45, -0.35), Vector3(2.0, 1.25, 0.2))   # vitre conducteur
	else:
		_cabin_cam(Vector3(0.42, 1.52, -0.2), Vector3(0.42, 1.25, 4.0))
	for k in RAIN_STEPS.size():
		var st: Array = RAIN_STEPS[k]
		if at.call(st[0] + 0.05):
			if st[1] != "":
				w.set_weather(st[1], true)
				car.wiper_stalk.set_notch(st[2], true)
			if k > 0:
				var prev: String = RAIN_STEPS[k - 1][3]
				var sd: Dictionary = _rain_stats.get(prev, {"sum": 0.0, "n": 0, "max": 0.0})
				_log("AUTOTEST pluie %s : eau moyenne=%.2f maxi=%.2f (niveau de pluie %d, essuie-glace %s)" % [prev, sd["sum"] / maxf(sd["n"], 1), sd["max"], w.get_rain_level(), car.wiper_stalk.get_notch_label()])
		# mesure sur la seconde moitié de chaque étape (régime établi)
		if k < RAIN_STEPS.size() - 1:
			var t_end: float = RAIN_STEPS[k + 1][0]
			if _t > (st[0] + t_end) * 0.5 and _t < t_end:
				var wv: float = car._windshield.get_view_wetness()
				var sd2: Dictionary = _rain_stats.get(st[3], {"sum": 0.0, "n": 0, "max": 0.0})
				sd2["sum"] += wv
				sd2["n"] += 1
				sd2["max"] = maxf(sd2["max"], wv)
				_rain_stats[st[3]] = sd2
			if at.call(t_end - 0.6):
				_shot("pluie_" + st[3])
	if at.call(51.5): _shot("pluie_toit")
	if at.call(62.5): _shot("pluie_vitre_laterale")
	if at.call(68.5): get_tree().quit()


# Pare-brise mouillé à l'arrêt, puis un seul aller-retour des essuie-glaces : vue de
# face pour vérifier que la zone essuyée correspond bien au passage des balais.
func _run_autotest_sweep(delta: float) -> void:
	var w: WeatherSystem = $Weather
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	w.random_events = false
	w.transition_time = 0.5
	$FallingTrees.enabled = false
	car.external_input = true
	car.throttle_input = 0.0
	car.brake_input = 1.0
	_inside = false
	cam.fov = 50.0
	if at.call(0.05):
		w.hour = 13.0
		w.set_weather("pluie", true)
	if _t < 12.0:
		_cabin_cam(Vector3(0.0, 3.2, 4.2), Vector3(0.0, 1.45, 0.75))
	else:
		_cabin_cam(Vector3(0.42, 1.52, -0.2), Vector3(0.42, 1.25, 4.0))
	if at.call(8.0): _shot("balayage_1_mouille")
	if at.call(8.1): car.wiper_stalk.set_notch(2, true)
	if at.call(8.8): _shot("balayage_2_milieu")
	if at.call(8.85): car.wiper_stalk.set_notch(0, true)   # finit le cycle puis se gare
	if at.call(10.5):
		_shot("balayage_3_essuye")
		_log("AUTOTEST balayage : eau zone conducteur=%.2f" % car._windshield.get_view_wetness())
	if at.call(13.0): _shot("balayage_4_conducteur")
	if at.call(13.5): get_tree().quit()


# Menu météo/heure (F1) : ouverture, choix d'une météo et d'une heure.
func _run_autotest_menu(delta: float) -> void:
	var w: WeatherSystem = $Weather
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	$FallingTrees.enabled = false
	car.external_input = true
	car.throttle_input = 0.0
	car.brake_input = 1.0
	var menu = w.get_node("WeatherMenu")
	if at.call(1.0):
		var ev := InputEventKey.new()
		ev.keycode = KEY_F1
		ev.pressed = true
		Input.parse_input_event(ev)
	if at.call(2.0):
		_log("AUTOTEST menu ouvert=%s" % menu.visible)
		_shot("menu_1_ouvert")
		menu._on_weather("orage")
		menu._set_hour(21.0)
	if at.call(4.0):
		_log("AUTOTEST menu : %s %s niveau=%d" % [w.get_time_string(), w.get_weather_name(), w.get_rain_level()])
		_shot("menu_2_orage_nuit")
		menu._on_weather("degage")
		menu._set_hour(12.0)
		(menu._speed_buttons[60.0] as Button).pressed.emit()
	if at.call(6.0):
		_log("AUTOTEST menu : %s %s vitesse=%.0f" % [w.get_time_string(), w.get_weather_name(), w.time_scale])
		_shot("menu_3_midi")
	if at.call(6.5): get_tree().quit()


# Lunette arrière mouillée à l'arrêt, puis un aller-retour de l'essuie-glace arrière :
# vues de derrière et de l'intérieur.
func _run_autotest_rear_window(delta: float) -> void:
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
	if at.call(0.05):
		w.hour = 13.0
		w.set_weather("pluie", true)
	var inside_view := fmod(_t, 2.0) > 1.0
	if _t > 13.0:
		inside_view = true
	if inside_view:
		_cabin_cam(Vector3(0.0, 1.55, -0.6), Vector3(0.0, 1.45, -4.0))
	else:
		_cabin_cam(Vector3(0.6, 2.0, -5.2), Vector3(0.0, 1.5, -2.25))
	if at.call(9.6): _shot("lunette_1_mouillee_dehors")
	if at.call(10.6): _shot("lunette_2_mouillee_dedans")
	if at.call(10.7): car.wiper_stalk.set_notch(2, true)
	if at.call(11.2): car.wiper_stalk.set_notch(0, true)   # finit son aller-retour puis se gare
	if at.call(11.55): _shot("lunette_3_balai_dedans")
	if at.call(13.6): _shot("lunette_4_essuyee_dedans")
	if at.call(14.0): get_tree().quit()


# Bruit du moteur : point mort (coups d'accélérateur), puis pleine accélération en D
# jusqu'à ~110 km/h, lever de pied, puis en « 2 ». Le son est enregistré dans
# .godot/autotest_moteur.wav et le régime noté toutes les 0,5 s.
var _rec: AudioEffectRecord

func _run_autotest_engine(delta: float) -> void:
	var w: WeatherSystem = $Weather
	var road: RoadGenerator = $RoadGenerator
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	w.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	if at.call(0.05):
		w.set_weather("degage", true)
		w.rain_volume = 0.0
		_rec = AudioEffectRecord.new()
		AudioServer.add_bus_effect(0, _rec)
		_rec.set_recording_active(true)
		car.gear_lever.set_notch(1, true)   # N
		car.handbrake_lever.set_angle_deg(0.0, true)
	var thr := 0.0
	var brk := 0.0
	if _t < 6.0:
		car.gear_lever.set_notch(1, true)
		brk = 1.0
		thr = 1.0 if (fmod(_t, 2.0) > 1.0 and _t > 1.0) else 0.0   # coups d'accélérateur au point mort
	elif _t < 26.0:
		if at.call(6.0): car.gear_lever.set_notch(2, true)   # D
		thr = 1.0 if car.forward_speed * 3.6 < 110.0 else 0.0
	elif _t < 31.0:
		thr = 0.0   # lever de pied
	else:
		if at.call(31.0): car.gear_lever.set_notch(3, true)   # « 2 »
		thr = 1.0 if car.forward_speed * 3.6 < 58.0 else 0.0
	var fwd := car.global_basis.z
	var info := road.sample_road(car.global_position + fwd * 14.0)
	if info["found"]:
		var target: Vector3 = info["point"] + info["right"] * 1.75
		var to_t := target - car.global_position
		to_t.y = 0.0
		_steer(clampf(fwd.cross(to_t.normalized()).y * 2.0, -1.0, 1.0))
	car.throttle_input = thr
	car.brake_input = brk
	_inside = false
	_cabin_cam(Vector3(0.42, 1.52, -0.2), Vector3(0.42, 1.25, 4.0))
	var es = car.engine_sound
	if fmod(_t, 0.5) < delta and _t > 0.2:
		_log("AUTOTEST moteur t=%.1f levier=%s vitesse=%.0f km/h rapport interne=%d régime=%.0f charge=%.2f" % [_t, car.gear_lever.get_notch_label(), car.forward_speed * 3.6, car.auto_gear + 1, es.rpm, es.engine_load])
	if at.call(40.0):
		_rec.set_recording_active(false)
		_rec.get_recording().save_to_wav(ProjectSettings.globalize_path("res://.godot/autotest_moteur.wav"))
		_log("AUTOTEST moteur : son enregistré")
	if at.call(40.5): get_tree().quit()


# Klaxon : vue rapprochée du volant, appui maintenu 1 s, puis coup bref (toggle),
# puis appui avec la main souris (grab du coussin). Son enregistré.
func _run_autotest_horn(delta: float) -> void:
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
	cam.fov = 50.0
	var horn = car.horn
	_cabin_cam(Vector3(0.45, 1.5, 0.1), horn.global_position * 0.0 + car.to_local(horn.global_position))
	if at.call(0.05):
		w.set_weather("degage", true)
		w.rain_volume = 0.0
		_rec = AudioEffectRecord.new()
		AudioServer.add_bus_effect(0, _rec)
		_rec.set_recording_active(true)
	if at.call(1.0): horn.press("test")
	if at.call(1.5):
		horn.set_hand_distance(self, 0.0)   # surbrillance comme si une main était dessus
		_shot("klaxon_1_appui")
		_log("AUTOTEST klaxon appui : klaxonne=%s" % horn.is_honking())
	if at.call(2.0): horn.unpress("test")
	if at.call(2.6):
		horn.set_hand_distance(self, -1.0)
		_shot("klaxon_2_repos")
		_log("AUTOTEST klaxon relâché : klaxonne=%s" % horn.is_honking())
	if at.call(3.0): horn.toggle()
	if at.call(3.1): _log("AUTOTEST klaxon coup bref : klaxonne=%s" % horn.is_honking())
	if at.call(4.0):
		# la main souris qui vise le centre du volant choisit-elle le klaxon ?
		var origin := cam.global_position
		var dir: Vector3 = (horn.global_position - origin).normalized()
		var best = null
		var best_t := INF
		for n in get_tree().get_nodes_in_group(VRInteractable.GROUP):
			var it := n as VRInteractable
			var tt := it.ray_hit_distance(origin, dir, 2.0, it.grab_distance * 0.3)
			if tt - it.pick_bonus * 3.0 < best_t - (best.pick_bonus * 3.0 if best else 0.0):
				best = it
				best_t = tt
		_log("AUTOTEST klaxon : visé au centre du volant -> %s" % (best.name if best else "rien"))
		var ev := InputEventKey.new()
		ev.keycode = KEY_J
		ev.pressed = true
		Input.parse_input_event(ev)
	if at.call(4.6):
		_log("AUTOTEST klaxon touche J : klaxonne=%s" % horn.is_honking())
		var ev2 := InputEventKey.new()
		ev2.keycode = KEY_J
		ev2.pressed = false
		Input.parse_input_event(ev2)
	if at.call(5.5):
		_log("AUTOTEST klaxon J relâchée : klaxonne=%s" % horn.is_honking())
		_rec.set_recording_active(false)
		_rec.get_recording().save_to_wav(ProjectSettings.globalize_path("res://.godot/autotest_klaxon.wav"))
	# le coussin tourne-t-il avec le volant ?
	if at.call(5.6): _steer(0.35)
	if at.call(7.6):
		_shot("klaxon_3_volant_gauche")
		_log("AUTOTEST klaxon volant %.0f° coussin %.0f°" % [rad_to_deg(car.steering_wheel.wheel_angle), rad_to_deg(horn.transform.basis.get_rotation_quaternion().get_angle())])
		_steer(-0.6)
	if at.call(10.0):
		_shot("klaxon_4_volant_droite")
		_log("AUTOTEST klaxon volant %.0f° coussin %.0f°" % [rad_to_deg(car.steering_wheel.wheel_angle), rad_to_deg(horn.transform.basis.get_rotation_quaternion().get_angle())])
	if at.call(10.5): get_tree().quit()



## Objet interactif visé par un rayon (même choix que la main souris).
func _ray_pick(origin: Vector3, target: Vector3) -> VRInteractable:
	var dir: Vector3 = (target - origin).normalized()
	var best: VRInteractable = null
	var best_t := INF
	for n in get_tree().get_nodes_in_group(VRInteractable.GROUP):
		var it := n as VRInteractable
		if it == null or not it.enabled or not it.is_visible_in_tree():
			continue
		var tt := it.ray_hit_distance(origin, dir, 2.0, it.grab_distance * 0.3)
		if tt - it.pick_bonus * 3.0 < best_t - (best.pick_bonus * 3.0 if best else 0.0):
			best = it
			best_t = tt
	return best if best_t < INF else null


func _run_autotest_windows(delta: float) -> void:
	# Manivelles : tourner celle du conducteur à la main, vitre baissée -> rétro attrapable.
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
	var fl: VRWindowCrank = car.window_cranks["FL"]
	var mirror_fl := car.get_node("Doors/DoorFL/Mirror") as VRInteractable
	var eye := Vector3(0.45, 1.45, -0.05)
	var knob := func(ang: float) -> Vector3: return fl.to_global(Vector3(cos(ang), sin(ang), 0.0) * 0.072 + Vector3(0, 0, 0.05))
	if _t < 0.6:
		cam.fov = 50.0
		_cabin_cam(Vector3(2.2, 1.75, 1.3), Vector3(0.93, 1.55, 0.45))   # coin avant de la vitre, dehors
	elif _t < 0.95:
		_cabin_cam(eye, Vector3(0.95, 1.75, 0.55))   # montant avant, depuis le siège
	elif _t < 7.9:
		_cabin_cam(eye, car.to_local(fl.global_position) + Vector3(0, 0.25, 0.2))
	else:
		cam.fov = 40.0
		_cabin_cam(Vector3(4.2, 1.6, -0.6), Vector3(0.9, 1.2, -0.1))
	if at.call(0.05):
		w.hour = 14.0
		w.set_weather("degage", true)
		_hand = Node3D.new()
		add_child(_hand)
	if at.call(0.55): _shot("vitres_0_coin_dehors")
	if at.call(0.9): _shot("vitres_0_coin_dedans")
	if at.call(1.0):
		_shot("vitres_1_fermee")
		var pick := _ray_pick(car.to_global(eye), mirror_fl.global_position)
		_log("AUTOTEST vitre fermée : rétro gauche attrapable=%s, visé -> %s" % [mirror_fl.enabled, pick.name if pick else "rien"])
		pick = _ray_pick(car.to_global(eye), knob.call(PI * 0.5))
		_log("AUTOTEST visé le bouton de la manivelle -> %s" % (pick.name if pick else "rien"))
		_hand.global_position = knob.call(PI * 0.5)
		fl.grab(_hand)
	# 1,5 tour dans le sens horaire (vu de l'habitacle) en 2 s : la vitre descend de moitié
	if _t > 1.0 and _t <= 3.0 and fl.is_grabbed():
		_hand.global_position = knob.call(PI * 0.5 - clampf((_t - 1.0) / 2.0, 0.0, 1.0) * 1.5 * TAU)
		fl.grab_update(_hand)
	if at.call(3.1):
		fl.release(_hand)
		_log("AUTOTEST 1,5 tour : ouverture=%.2f, rétro attrapable=%s" % [fl.opening, mirror_fl.enabled])
		_shot("vitres_2_mi_ouverte")
		_hand.global_position = knob.call(-PI * 0.5)
		fl.grab(_hand)
	# demi-tour dans l'autre sens : la vitre remonte un peu
	if _t > 3.1 and _t <= 3.8 and fl.is_grabbed():
		_hand.global_position = knob.call(-PI * 0.5 + clampf((_t - 3.1) / 0.7, 0.0, 1.0) * PI)
		fl.grab_update(_hand)
	if at.call(3.9):
		fl.release(_hand)
		_log("AUTOTEST demi-tour inverse : ouverture=%.2f" % fl.opening)
		fl.toggle()   # F / A-X : descend d'elle-même
	if at.call(6.0):
		var pick2 := _ray_pick(car.to_global(eye), mirror_fl.global_position)
		_log("AUTOTEST touche F : ouverture=%.2f, rétro attrapable=%s, visé le rétro -> %s" % [fl.opening, mirror_fl.enabled, pick2.name if pick2 else "rien"])
		_shot("vitres_3_ouverte")
		car.window_cranks["RL"].set_opening(0.5)
	if at.call(8.3):
		_shot("vitres_4_cote")
		fl.toggle()
	if at.call(10.2):
		_log("AUTOTEST remontée : ouverture=%.2f, rétro attrapable=%s" % [fl.opening, mirror_fl.enabled])
		_shot("vitres_5_remontee")
	if at.call(10.4): get_tree().quit()


func _run_autotest_belt(delta: float) -> void:
	# Ceinture : voyant et carillon en roulant sans, bouclage à la main, déblocage, bip rapide.
	var w: WeatherSystem = $Weather
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	w.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	car.throttle_input = 0.35 if _t > 2.0 and _t < 14.0 else 0.0
	car.brake_input = 0.0 if _t > 2.0 else 1.0
	_inside = false
	cam.fov = 60.0
	var belt = car.seatbelt
	var passenger := Vector3(-0.35, 1.42, 0.35)
	if _t > 4.6 and _t < 5.8:
		_cabin_cam(Vector3(0.45, 1.45, -0.05), Vector3(0.45, 1.2, 0.75))   # combiné
	elif (_t > 1.2 and _t < 1.8) or (_t > 7.8 and _t < 8.4):
		_cabin_cam(Vector3(0.45, 1.45, -0.05), Vector3(0.2, 0.95, 0.05))   # regard du conducteur vers la boucle
	else:
		_cabin_cam(passenger, Vector3(0.5, 1.1, -0.15))
	if at.call(0.05):
		w.hour = 14.0
		w.set_weather("degage", true)
		_hand = Node3D.new()
		add_child(_hand)
		_rec = AudioEffectRecord.new()
		AudioServer.add_bus_effect(0, _rec)
		_rec.set_recording_active(true)
	if at.call(1.0):
		_shot("ceinture_1_debouclee")
		_log("AUTOTEST ceinture à l'arrêt : bouclée=%s voyant=%d" % [belt.is_buckled(), car.get_belt_warning()])
	if at.call(1.7): _shot("ceinture_1b_vue_conducteur")
	if at.call(8.3): _shot("ceinture_3b_vue_conducteur")
	if at.call(5.0):
		_shot("ceinture_2_combine_a")
		_log("AUTOTEST ceinture en roulant (%.0f km/h) : voyant=%d carillon=%d" % [absf(car.forward_speed) * 3.6, car.get_belt_warning(), belt._chime_mode])
	if at.call(5.4): _shot("ceinture_2_combine_b")
	# main qui saisit le pêne et le tire devant le torse jusqu'à la boucle
	if at.call(6.0):
		_hand.global_position = belt._tongue.global_position
		var pick := _ray_pick(car.to_global(Vector3(0.45, 1.45, -0.05)), belt._tongue.global_position)
		_log("AUTOTEST visé le pêne -> %s" % (pick.name if pick else "rien"))
		belt._tongue.grab(_hand)
	if _t > 6.0 and _t <= 7.5 and belt._tongue.is_grabbed():
		var k := clampf((_t - 6.0) / 1.5, 0.0, 1.0)
		var start: Vector3 = belt._rest_point()
		var mid := Vector3(0.48, 1.2, 0.12)
		var end: Vector3 = belt._buckled_tongue_point()
		var p := start.lerp(mid, k).lerp(mid.lerp(end, k), k)
		_hand.global_position = car.to_global(p)
		belt._tongue.grab_update(_hand)
		if not belt._tongue.enabled:
			belt._tongue.release(_hand)
	if at.call(7.7):
		_shot("ceinture_3_bouclee")
		_log("AUTOTEST bouclée à la main : bouclée=%s voyant=%d carillon=%d" % [belt.is_buckled(), car.get_belt_warning(), belt._chime_mode])
	if at.call(9.0): belt._buckle.toggle()   # bouton rouge
	if at.call(10.2):
		_shot("ceinture_4_relachee")
		_log("AUTOTEST bouton rouge : bouclée=%s voyant=%d carillon=%d pêne au repos=%s" % [belt.is_buckled(), car.get_belt_warning(), belt._chime_mode, belt._state == 0])
		belt.unbelted_drive_time = 19.5
	if at.call(11.5):
		_log("AUTOTEST après 20 s sans ceinture : carillon=%d (2 = bip rapide)" % belt._chime_mode)
	if at.call(12.5): belt._tongue.toggle()   # F sur le pêne : se boucle seul
	if at.call(13.8):
		_log("AUTOTEST touche F sur le pêne : bouclée=%s carillon=%d" % [belt.is_buckled(), belt._chime_mode])
		_shot("ceinture_5_auto")
		_rec.set_recording_active(false)
		_rec.get_recording().save_to_wav(ProjectSettings.globalize_path("res://.godot/autotest_ceinture.wav"))
	if at.call(14.0): get_tree().quit()


var _key_angle_log := []


func _run_autotest_key(delta: float) -> void:
	# Clé : posée sur le siège, mise dans le contact, tournée jusqu'au démarreur, moteur
	# qui part ; trousseau qui se balance en roulant ; arrêt, clé retirée ; touche M.
	var w: WeatherSystem = $Weather
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	w.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	var ign = car.ignition
	var key: RigidBody3D = car._find_key_item()
	var grab: VRInteractable = key.get_node("Grab")
	var eye := Vector3(0.45, 1.45, -0.05)
	var ign_local: Vector3 = car.to_local(ign.global_position)
	car.throttle_input = 0.6 if _t > 7.0 and _t < 9.0 else (1.0 if _t > 0.3 and _t < 1.3 else 0.0)
	car.brake_input = 0.0 if (_t > 7.0 and _t < 9.0) or (_t > 0.3 and _t < 1.3) else 1.0
	_inside = false
	if _t < 1.6 or (_t > 11.4 and _t < 12.4):
		cam.fov = 60.0
		_cabin_cam(eye, Vector3(-0.3, 0.9, 0.1))      # siège passager
	elif _t > 4.4 and _t < 4.9:
		cam.fov = 60.0
		_cabin_cam(eye, Vector3(0.45, 1.2, 0.75))     # combiné
	else:
		cam.fov = 24.0
		_cabin_cam(eye, ign_local + Vector3(0.0, -0.03, 0.0))   # contact et trousseau
	if at.call(0.05):
		w.hour = 14.0
		w.set_weather("degage", true)
		_hand = Node3D.new()
		add_child(_hand)
		# départ : moteur coupé, clé sur le siège passager
		ign.set_key_angle(0.0)
		ign.key_held = false
		car.engine_state = 0
		var k: RigidBody3D = ign.eject()
		var storage := car.get_node("Storage") as CarStorage
		k.global_position = storage.to_global(Vector3(-0.45, 1.1, -0.05))
		storage.receive(k, Vector3.ZERO)
	if at.call(1.4):
		_shot("cle_1_siege")
		_log("AUTOTEST clé sur le siège : contact=%d moteur=%d clé dans le contact=%s ; plein gaz 1 s moteur coupé -> %.1f km/h" % [car.get_ignition_level(), car.engine_state, ign.has_key(), absf(car.forward_speed) * 3.6])
		_hand.global_transform = key.global_transform
		grab.grab(_hand)
	# la main porte la clé jusqu'au barillet
	if _t > 1.4 and _t <= 3.0 and grab.is_grabbed():
		var k2 := clampf((_t - 1.4) / 1.5, 0.0, 1.0)
		var from: Vector3 = car.to_global(Vector3(-0.45, 0.95, -0.05))
		var to: Vector3 = ign.global_position + (ign.global_basis as Basis).z * 0.02
		_hand.global_transform = Transform3D(ign.global_basis, from.lerp(to, k2) + Vector3.UP * 0.15 * sin(k2 * PI))
		grab.grab_update(_hand)
	if at.call(3.1):
		grab.release(_hand)
		_log("AUTOTEST lâchée près du barillet : clé dans le contact=%s" % ign.has_key())
	if at.call(3.8): _shot("cle_2_inseree")
	# tourner le poignet jusqu'à II
	if at.call(4.0):
		_hand.global_transform = Transform3D(ign.global_basis, ign.global_position + (ign.global_basis as Basis).z * 0.04)
		grab.grab(_hand)
	var twist := 0.0
	if _t > 4.0 and _t <= 4.3: twist = (_t - 4.0) / 0.3 * 72.0
	elif _t > 4.3 and _t <= 5.0: twist = 72.0
	elif _t > 5.0 and _t <= 6.4: twist = 104.0
	if _t > 4.0 and _t <= 6.4 and grab.is_grabbed():
		_hand.global_basis = (ign.global_basis as Basis) * Basis(Vector3.BACK, -deg_to_rad(twist))
		grab.grab_update(_hand)
	if at.call(4.7):
		_shot("cle_3_contact")
		_log("AUTOTEST clé sur II : contact=%d moteur=%d voyant ceinture=%d" % [car.get_ignition_level(), car.engine_state, car.get_belt_warning()])
		_rec = AudioEffectRecord.new()
		AudioServer.add_bus_effect(0, _rec)
		_rec.set_recording_active(true)
	if at.call(5.4): _log("AUTOTEST démarreur : contact=%d moteur=%d régime=%.0f" % [car.get_ignition_level(), car.engine_state, car.engine_sound.rpm])
	if at.call(6.3): _log("AUTOTEST démarreur tenu 1,3 s : moteur=%d" % car.engine_state)
	if at.call(6.4): grab.release(_hand)
	if at.call(6.9):
		_log("AUTOTEST clé lâchée : revenue sur %d, moteur=%d, régime=%.0f" % [car.get_ignition_level(), car.engine_state, car.engine_sound.rpm])
		_shot("cle_4_moteur")
	# en roulant : angle du trousseau par rapport à la verticale de la voiture
	if _t > 6.9 and _t < 10.0 and int(_t * 10.0) != int(t0 * 10.0):
		var cn: Node3D = grab._charm_nodes[0]
		var down: Vector3 = car.global_basis.inverse() * (-cn.global_basis.y)
		_key_angle_log.append("%.1fs %3.0fkm/h avant/arrière %+.0f°" % [_t, absf(car.forward_speed) * 3.6, rad_to_deg(atan2(down.z, -down.y))])
	if at.call(8.2): _shot("cle_5_acceleration")
	if at.call(9.25): _shot("cle_6_freinage")
	if at.call(10.0):
		_log("AUTOTEST trousseau : " + ", ".join(_key_angle_log.slice(0, _key_angle_log.size(), 3)))
		grab.toggle()   # F : coupe le moteur
	if at.call(10.6):
		_log("AUTOTEST touche F : contact=%d moteur=%d" % [car.get_ignition_level(), car.engine_state])
		_rec.set_recording_active(false)
		_rec.get_recording().save_to_wav(ProjectSettings.globalize_path("res://.godot/autotest_cle.wav"))
		_hand.global_transform = Transform3D(ign.global_basis, ign.global_position + (ign.global_basis as Basis).z * 0.04)
		grab.grab(_hand)
	if _t > 10.6 and _t <= 11.0 and grab.is_grabbed():
		_hand.global_position = ign.global_position + (ign.global_basis as Basis).z * (0.04 + (_t - 10.6) * 0.25)
		grab.grab_update(_hand)
	if at.call(11.1):
		_log("AUTOTEST main tirée : clé dans le contact=%s, tenue=%s" % [ign.has_key(), grab.is_grabbed()])
		_hand.global_position = car.to_global(Vector3(-0.4, 1.0, -0.05))
		grab.grab_update(_hand)
		grab.release(_hand)
	if at.call(12.0): _shot("cle_7_retiree")
	if at.call(12.5): car._key_shortcut()   # touche M
	if at.call(14.5):
		_log("AUTOTEST touche M : clé dans le contact=%s contact=%d moteur=%d" % [ign.has_key(), car.get_ignition_level(), car.engine_state])
		get_tree().quit()


func _run_autotest_start(delta: float) -> void:
	# Départ comme dans le jeu (start_engine_running = false) : où est la clé, moteur coupé.
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	$Weather.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	car.throttle_input = 1.0
	car.brake_input = 0.0
	if at.call(2.0):
		var key: RigidBody3D = car._find_key_item()
		var where := key.get_parent().name
		var z := key.get_parent() as StorageZone
		if z:
			where = z.zone_name
		_log("AUTOTEST départ : clé dans « %s » (%s), contact=%d moteur=%d, plein gaz 2 s -> %.1f km/h, meshes de la clé=%d" % [where, car.to_local(key.global_position), car.get_ignition_level(), car.engine_state, absf(car.forward_speed) * 3.6, key.find_children("*", "MeshInstance3D", true, false).size()])
		get_tree().quit()


func _run_autotest_visor(delta: float) -> void:
	# Pare-soleil : rabattre, pivoter contre la vitre, clé sous la sangle conducteur.
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	$Weather.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	car.throttle_input = 0.0
	car.brake_input = 1.0
	_inside = false
	var vl = car.sun_visors[0]
	var vr = car.sun_visors[1]
	var ign = car.ignition
	var key: RigidBody3D = car._find_key_item()
	var kgrab: VRInteractable = key.get_node("Grab")
	var eye := Vector3(0.45, 1.45, -0.05)
	var eye_g: Vector3 = car.to_global(eye)
	cam.fov = 70.0
	if _t > 9.0 and _t < 13.5:
		cam.fov = 26.0
		_cabin_cam(eye, car.to_local(ign.global_position))
	elif _t > 15.0:
		_cabin_cam(Vector3(-0.1, 1.42, -0.2), Vector3(0.0, 1.62, 0.42))
	else:
		_cabin_cam(eye, Vector3(0.55, 1.62, 0.42))
	if at.call(0.05):
		$Weather.hour = 14.0
		$Weather.set_weather("degage", true)
		_hand = Node3D.new()
		add_child(_hand)
		# départ comme dans le jeu : moteur coupé, clé sous la sangle du pare-soleil
		ign.set_key_angle(0.0)
		car.engine_state = 0
		var k: RigidBody3D = ign.eject()
		if k:
			vl.store_key(k)
	if at.call(1.0):
		_shot("ps_1_releve")
		var pick := _ray_pick(eye_g, key.global_position)
		_log("AUTOTEST pare-soleil relevé : clé sous la sangle=%s, clé attrapable=%s, visé la clé -> %s" % [key.get_parent().name, kgrab.enabled, pick.name if pick else "rien"])
		# main sur le bord libre du panneau, qu'on rabat vers le bas
		var sw: Node3D = vl._swing_node
		_hand.global_position = sw.to_global(Vector3(-0.2, 0.0, -0.15))
		vl.grab(_hand)
	if _t > 1.0 and _t <= 2.2 and vl.is_grabbed():
		var a := clampf((_t - 1.0) / 1.0, 0.0, 1.0) * deg_to_rad(90.0)
		var sw2: Node3D = vl._swing_node
		_hand.global_position = sw2.to_global(Vector3(-0.2, -sin(a) * 0.15, -cos(a) * 0.15))
		vl.grab_update(_hand)
	if at.call(2.3):
		vl.release(_hand)
		_log("AUTOTEST rabattu à la main : angle=%.0f° clé attrapable=%s" % [rad_to_deg(vl.flip), kgrab.enabled])
	if at.call(3.3):
		_shot("ps_2_rabattu")
		var pick2 := _ray_pick(eye_g, key.global_position)
		_log("AUTOTEST visé la clé -> %s" % (pick2.get_parent().name if pick2 else "rien"))
		# décrocher et pivoter vers la vitre
		_hand.global_position = vl.global_transform * Vector3(-0.2, -0.12, 0.0)
		vl.grab(_hand)
	if _t > 3.3 and _t <= 4.5 and vl.is_grabbed():
		var b := clampf((_t - 3.3) / 1.0, 0.0, 1.0) * deg_to_rad(90.0)
		_hand.global_position = vl.global_transform * Vector3(-cos(b) * 0.2, -0.12, -sin(b) * 0.2)
		vl.grab_update(_hand)
	if at.call(4.6):
		vl.release(_hand)
		_log("AUTOTEST pivoté contre la vitre : pivot=%.0f° rabat=%.0f°" % [rad_to_deg(vl.swing), rad_to_deg(vl.flip)])
	if at.call(5.2): _shot("ps_3_vitre")
	if at.call(5.4): vl.toggle()   # contre la vitre -> relevé
	if at.call(6.8):
		_log("AUTOTEST F (vitre -> relevé) : pivot=%.0f° rabat=%.0f° clé attrapable=%s" % [rad_to_deg(vl.swing), rad_to_deg(vl.flip), kgrab.enabled])
		vl.toggle()   # relevé -> rabattu
	if at.call(7.8):
		_log("AUTOTEST F (relevé -> rabattu) : rabat=%.0f°" % rad_to_deg(vl.flip))
		_hand.global_transform = key.global_transform
		kgrab.grab(_hand)
	# la main prend la clé et la porte au contact
	if _t > 7.8 and _t <= 9.2 and kgrab.is_grabbed():
		var k2 := clampf((_t - 7.8) / 1.2, 0.0, 1.0)
		var from: Vector3 = vl._holder.global_position
		var to: Vector3 = ign.global_position + (ign.global_basis as Basis).z * 0.02
		_hand.global_transform = Transform3D(ign.global_basis, from.lerp(to, k2))
		kgrab.grab_update(_hand)
	if at.call(9.3):
		kgrab.release(_hand)
		_log("AUTOTEST clé prise au pare-soleil et lâchée au contact : dans le contact=%s" % ign.has_key())
		kgrab.toggle()   # F : démarrer
	if at.call(10.8):
		_log("AUTOTEST démarrage : moteur=%d" % car.engine_state)
		_shot("ps_4_demarre")
		kgrab.toggle()   # F : couper
	if at.call(11.6):
		_hand.global_transform = Transform3D(ign.global_basis, ign.global_position + (ign.global_basis as Basis).z * 0.04)
		kgrab.grab(_hand)
	if _t > 11.6 and _t <= 13.2 and kgrab.is_grabbed():
		var k3 := clampf((_t - 11.6) / 1.4, 0.0, 1.0)
		var from2: Vector3 = ign.global_position + (ign.global_basis as Basis).z * 0.04
		_hand.global_position = from2.lerp(vl._holder.global_position, k3)
		kgrab.grab_update(_hand)
	if at.call(13.3):
		kgrab.release(_hand)
		_log("AUTOTEST clé remise sous la sangle : %s (moteur=%d)" % [key.get_parent().name, car.engine_state])
	if at.call(14.0): _shot("ps_5_cle_remise")
	if at.call(14.2):
		vl.toggle()   # rabattu -> contre la vitre
	if at.call(15.0):
		vl._auto_flip = 0.0
		vl._auto_swing = 0.0
		vr.toggle()   # passager rabattu (miroir de courtoisie)
	if at.call(16.5):
		_log("AUTOTEST relevé avec la clé : rabat=%.0f° clé attrapable=%s ; passager rabat=%.0f°" % [rad_to_deg(vl.flip), kgrab.enabled, rad_to_deg(vr.flip)])
		_shot("ps_6_passager")
	if at.call(16.8): get_tree().quit()


func _run_autotest_key_f(delta: float) -> void:
	# F en regardant la clé (pare-soleil rabattu, puis posée sur le siège) : elle va au contact.
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	$Weather.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	car.throttle_input = 0.0
	car.brake_input = 1.0
	_inside = false
	var vl = car.sun_visors[0]
	var ign = car.ignition
	var key: RigidBody3D = car._find_key_item()
	var kgrab: VRInteractable = key.get_node("Grab")
	var eye := Vector3(0.45, 1.45, -0.05)
	cam.fov = 75.0
	_cabin_cam(eye, Vector3(0.4, 1.35, 0.5))
	if at.call(0.05):
		$Weather.hour = 14.0
		$Weather.set_weather("degage", true)
		ign.set_key_angle(0.0)
		car.engine_state = 0
		var k: RigidBody3D = ign.eject()
		if k:
			vl.store_key(k)
		vl.toggle()   # pare-soleil rabattu
	if at.call(1.2):
		var pick := _ray_pick(car.to_global(eye), key.global_position)
		_log("AUTOTEST visé la clé dans le pare-soleil -> %s" % (pick.get_parent().name if pick else "rien"))
		if pick:
			pick.toggle()   # F
	if at.call(1.4): _shot("clef_1_vol")
	if at.call(2.0):
		_shot("clef_2_contact")
		_log("AUTOTEST F sur la clé : dans le contact=%s contact=%d moteur=%d" % [ign.has_key(), car.get_ignition_level(), car.engine_state])
		kgrab.toggle()   # F de nouveau : démarre
	if at.call(3.6):
		_log("AUTOTEST 2e F : moteur=%d contact=%d" % [car.engine_state, car.get_ignition_level()])
		kgrab.toggle()   # coupe
	if at.call(4.3):
		var k2: RigidBody3D = ign.eject()
		var storage := car.get_node("Storage") as CarStorage
		k2.global_position = storage.to_global(Vector3(-0.45, 1.1, -0.05))
		storage.receive(k2, Vector3.ZERO)
	if at.call(5.0):
		_log("AUTOTEST clé posée sur le siège : parent=%s" % key.get_parent().name)
		kgrab.toggle()
	if at.call(5.7):
		_log("AUTOTEST F sur la clé posée : dans le contact=%s" % ign.has_key())
		get_tree().quit()


var _phys_items := {}
var _phys_max_pen := 0.0
var _phys_pen_frames := 0
var _phys_worst := ""
var _phys_who := {}


func _run_autotest_physics(delta: float) -> void:
	# Objets posés en vrac : accélération franche, gros freinage, virages ; on note où ils vont.
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	$Weather.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	_inside = false
	var storage := car.get_node("Storage") as CarStorage
	car.throttle_input = 1.0 if _t > 2.0 and _t < 6.0 else (0.55 if _t > 8.0 and _t < 13.0 else 0.0)
	car.brake_input = 1.0 if (_t < 2.0 or (_t > 6.0 and _t < 7.8) or _t > 13.0) else 0.0
	var steer := 0.0
	if _t > 8.5 and _t < 10.5: steer = 0.7
	elif _t > 10.5 and _t < 12.5: steer = -0.7
	_steer(steer)
	cam.fov = 78.0
	_cabin_cam(Vector3(0.42, 1.45, -0.1), Vector3(-0.35, 0.98, 0.42))
	if at.call(0.05):
		$Weather.hour = 14.0
		$Weather.set_weather("degage", true)
		# objets posés à la main (lâchés juste au-dessus de leur surface)
		var spots := {
			"Phone": Vector3(-0.47, 0.92, -0.02), "Joint": Vector3(-0.32, 0.92, 0.18),
			"PillBag": Vector3(-0.42, 1.2, 0.76), "Thermos": Vector3(-0.42, 0.66, 0.62),
			"Cigarette": Vector3(0.0, 0.98, 0.05),
		}
		for n in spots:
			var it := car.find_child(n, true, false) as RigidBody3D
			if it == null:
				continue
			var z := it.get_parent() as StorageZone
			if z:
				z.on_item_taken(it)
			ItemPhysics.stop(it)
			if it.has_meta("rest_xf"):
				it.remove_meta("rest_xf")
			it.global_position = car.to_global(spots[n])
			storage.receive(it, car.linear_velocity)
			_phys_items[n] = it
	if _t > 0.5 and int(_t * 2.0) != int(t0 * 2.0):
		var parts := PackedStringArray()
		for n in _phys_items:
			var it: RigidBody3D = _phys_items[n]
			var st := ItemPhysics.get_state(it)
			var p: Vector3 = car.to_local(it.global_position)
			parts.append("%s(%.2f,%.2f,%.2f)%s" % [n.left(5), p.x, p.y, p.z, "^" if st.get("air", false) else ""])
		var gl: Vector3 = storage.get_meta("_g", Vector3.ZERO)
		var ph := ItemPhysics.get_state(_phys_items["Phone"])
		_log("AUTOTEST phys t=%.1f %3.0fkm/h g ressentie av=%+.1f lat=%+.1f vert=%+.1f phone v=%.2f | %s" % [_t, absf(car.forward_speed) * 3.6, gl.z, gl.x, gl.y, (ph.get("vel", Vector3.ZERO) as Vector3).length(), " ".join(parts)])
	# intrusion dans un volume plein (siège, dossier, console...) à chaque image
	for it2 in storage.get_children():
		if it2 is RigidBody3D:
			var st2 := ItemPhysics.get_state(it2)
			if st2.is_empty():
				continue
			var p2: Vector3 = st2["pos"]
			var h2: Vector3 = st2["half"]
			for ob in storage.obstacles:
				var b2: AABB = ob
				if p2.y >= b2.end.y - 0.012 or p2.y + h2.y * 2.0 <= b2.position.y:
					continue
				var pen := minf(minf(p2.x + h2.x - b2.position.x, b2.end.x - p2.x + h2.x), minf(p2.z + h2.z - b2.position.z, b2.end.z - p2.z + h2.z))
				if pen > 0.003:
					if pen > _phys_max_pen:
						_phys_worst = "%s dans le volume %d à t=%.1f (bas %.3f, haut %.3f, demi-taille %s, en l'air=%s)" % [it2.name, storage.obstacles.find(ob), _t, p2.y, p2.y + h2.y * 2.0, h2, st2["air"]]
					_phys_max_pen = maxf(_phys_max_pen, pen)
					_phys_pen_frames += 1
					_phys_who[it2.name] = _phys_who.get(it2.name, 0) + 1
	# deux lancers : un objet jeté vers l'arrière contre le dossier conducteur, un autre
	# jeté en travers vers la console centrale depuis le plancher passager
	if at.call(6.0) or at.call(14.0):
		var cg := car.find_child("Cigarette", true, false) as RigidBody3D
		var cs := ItemPhysics.get_state(cg)
		var cpos: Vector3 = cs.get("pos", Vector3.ZERO)
		var org: Vector3 = car.to_local(cg.global_position)
		_log("AUTOTEST écart position simulée / affichée de la cigarette à %.0f km/h : %.1f cm" % [absf(car.forward_speed) * 3.6, Vector2(org.x - cpos.x, org.z - cpos.z).length() * 100.0])
	if at.call(14.6):
		var a1 := car.find_child("Phone", true, false) as RigidBody3D
		var z1 := a1.get_parent() as StorageZone
		if z1: z1.on_item_taken(a1)
		ItemPhysics.stop(a1)
		a1.global_position = car.to_global(Vector3(0.45, 1.25, 0.25))
		storage.receive(a1, car.linear_velocity + car.global_basis * Vector3(0.0, 0.5, -3.5))
		var a2 := car.find_child("Thermos", true, false) as RigidBody3D
		var z2 := a2.get_parent() as StorageZone
		if z2: z2.on_item_taken(a2)
		ItemPhysics.stop(a2)
		a2.global_position = car.to_global(Vector3(-0.45, 0.75, 0.45))
		storage.receive(a2, car.linear_velocity + car.global_basis * Vector3(3.0, 0.3, 0.0))
	if at.call(16.2):
		var p1: Vector3 = car.to_local(car.find_child("Phone", true, false).global_position)
		var p2b: Vector3 = car.to_local(car.find_child("Thermos", true, false).global_position)
		_log("AUTOTEST lancers : téléphone jeté vers l'arrière -> (%.2f, %.2f, %.2f) (dossier conducteur de z -0,40 à -0,13) ; thermos jeté vers la console -> (%.2f, %.2f, %.2f) (console x ±0,15)" % [p1.x, p1.y, p1.z, p2b.x, p2b.y, p2b.z])
		_log("AUTOTEST intrusions dans un volume plein : %d images, au plus %.1f mm ; pire : %s ; par objet : %s" % [_phys_pen_frames, _phys_max_pen * 1000.0, _phys_worst, _phys_who])
		get_tree().quit()
	for k in [1.5, 5.5, 7.0, 9.8, 12.0, 14.5]:
		if at.call(k):
			_shot("phys_%04.1f" % k)
	if at.call(14.9):
		var rep := PackedStringArray()
		for z in car.find_children("*", "Node3D", true, false):
			if z is StorageZone and not z.exact_snap:
				for c in z.get_children():
					if c is RigidBody3D:
						var lp: Vector3 = z.to_local((c as RigidBody3D).global_position)
						var inside: bool = absf(lp.x) <= z.size.x * 0.5 + 0.01 and absf(lp.z) <= z.size.z * 0.5 + 0.01 and lp.y > -0.01 and lp.y < z.size.y + 0.02
						rep.append("%s dans %s : %s (%.2f, %.2f, %.2f)" % [c.name, z.zone_name, "OK" if inside else "SORTI", lp.x, lp.y, lp.z])
		_log("AUTOTEST compartiments : " + " ; ".join(rep))
	pass   # fin : voir les lancers (16,2 s)


func _run_autotest_cluster_light(delta: float) -> void:
	# Lumière des compteurs, de nuit phares éteints : contact coupé / mis, vue conducteur et passager.
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	var w: WeatherSystem = $Weather
	w.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	car.throttle_input = 0.0
	car.brake_input = 1.0
	_inside = false
	var ign = car.ignition
	var glow: SpotLight3D = car.get_node("InstrumentCluster/Glow")
	cam.fov = 62.0
	if _t > 3.8 and _t < 5.6:
		_cabin_cam(Vector3(-0.35, 1.35, 0.15), Vector3(0.45, 1.1, 0.5))   # depuis le siège passager
	else:
		_cabin_cam(Vector3(0.45, 1.45, -0.05), Vector3(0.45, 1.12, 0.6))
	if at.call(0.05):
		w.hour = 23.0
		w.time_scale = 0.0 if "time_scale" in w else 1.0
		w.set_weather("degage", true)
		car.light_stalk.set_notch(0, true)   # phares éteints
		ign.set_key_angle(0.0)
		car.engine_state = 0
	if at.call(1.6):
		_shot("eclairage_1_coupe")
		_log("AUTOTEST contact coupé : lumière visible=%s énergie=%.2f" % [glow.visible, glow.light_energy])
		ign.set_key_angle(deg_to_rad(70.0))
		car.engine_state = 2
	if at.call(3.0):
		_shot("eclairage_2_contact")
		_log("AUTOTEST contact mis, moteur en marche : énergie=%.2f couleur=%s" % [glow.light_energy, glow.light_color])
	if at.call(4.5):
		_shot("eclairage_3_passager")
		car.handbrake_lever.set_angle_deg(car.handbrake_full_deg - 5.0, true)
	if at.call(5.4):
		_shot("eclairage_4_frein_a_main")
		_log("AUTOTEST frein à main + ceinture : couleur=%s" % glow.light_color)
	if at.call(5.7):
		w.hour = 14.0
	if at.call(6.6):
		_shot("eclairage_5_jour")
		get_tree().quit()


var _spk_closed := Vector3.ZERO


func _run_autotest_radio(delta: float) -> void:
	# Autoradio : touches, présélection, volume, portière ouverte, contact coupé.
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	var w: WeatherSystem = $Weather
	w.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	car.throttle_input = 0.0
	car.brake_input = 1.0
	_inside = false
	var r = car.radio
	var ign = car.ignition
	var eye := Vector3(0.45, 1.45, -0.05)
	if _t > 5.0 and _t < 6.0:
		cam.fov = 60.0
		_cabin_cam(Vector3(0.2, 1.3, -0.6), Vector3(1.2, 1.0, 0.4))
	else:
		cam.fov = 26.0
		_cabin_cam(eye, car.to_local(r.global_position))
	var status := func() -> String:
		var playing := 0
		for p in r.speakers:
			if p.playing: playing += 1
		return "allumée=%s station=%d (%s) volume=%.2f haut-parleurs actifs=%d, %.1f dB" % [r.is_on(), r.station, r.STATIONS[r.station]["name"], r.volume, playing, r.speakers[0].volume_db]
	if at.call(0.05):
		w.hour = 14.0
		w.set_weather("degage", true)
		_hand = Node3D.new()
		add_child(_hand)
		_rec = AudioEffectRecord.new()
		AudioServer.add_bus_effect(0, _rec)
		_rec.set_recording_active(true)
	if at.call(1.0):
		_shot("radio_1")
		_log("AUTOTEST radio au départ : " + status.call())
		var pick := _ray_pick(car.to_global(eye), r.get_node("Radio_next").global_position)
		_log("AUTOTEST visé la touche ▶ -> %s" % (pick.name if pick else "rien"))
		var g: VRInteractable = r.get_node("Radio_next")
		_hand.global_transform = g.global_transform
		g.grab(_hand)
		g.release(_hand)
	if at.call(1.15): _shot("radio_2_recherche")
	if at.call(2.0):
		_log("AUTOTEST touche ▶ : " + status.call())
		_shot("radio_3_station")
		(r.get_node("Radio_p2") as VRInteractable).toggle()   # touche 3
	if at.call(3.0):
		_log("AUTOTEST touche 3 : " + status.call())
		var k: VRInteractable = r.get_node("Radio_knob")
		_hand.global_transform = k.global_transform
		k.grab(_hand)
	if _t > 3.0 and _t <= 3.8 and (r.get_node("Radio_knob") as VRInteractable).is_grabbed():
		var kk: VRInteractable = r.get_node("Radio_knob")
		var a := clampf((_t - 3.0) / 0.7, 0.0, 1.0) * deg_to_rad(110.0)
		_hand.global_basis = (r.global_basis as Basis) * Basis(Vector3.BACK, -a)   # poignet dans le sens horaire
		kk.grab_update(_hand)
	if at.call(3.9):
		(r.get_node("Radio_knob") as VRInteractable).release(_hand)
		_shot("radio_4_volume")
		_log("AUTOTEST bouton tourné de 110° : " + status.call())
		_spk_closed = r.speakers[0].global_position
		car.get_node("Doors/DoorFL").set_angle_deg(-70.0, true)   # portière conducteur ouverte
	if at.call(4.6):
		var sp: Node3D = r.speakers[0]
		var to_spk: Vector3 = car.global_basis.inverse() * (sp.global_position - cam.global_position).normalized()
		var face: Vector3 = car.global_basis.inverse() * (sp.global_basis.z)
		_log("AUTOTEST portière ouverte : haut-parleur avant gauche déplacé de %.2f m, vers %s (voiture), tourné vers %s" % [sp.global_position.distance_to(_spk_closed), to_spk.snapped(Vector3.ONE * 0.01), face.snapped(Vector3.ONE * 0.01)])
	if at.call(5.5): _shot("radio_5_porte")
	if at.call(6.0):
		car.get_node("Doors/DoorFL").set_angle_deg(0.0, true)
		ign.set_key_angle(0.0)   # contact coupé
		car.engine_state = 0
	if at.call(6.5): _log("AUTOTEST contact coupé : " + status.call())
	if at.call(7.0): ign.set_key_angle(deg_to_rad(35.0))   # accessoires
	if at.call(7.4): _log("AUTOTEST contact sur I (accessoires) : " + status.call())
	if at.call(7.6): (r.get_node("Radio_knob") as VRInteractable).toggle()
	if at.call(7.9): _log("AUTOTEST F sur le bouton (arrêt) : " + status.call())
	if at.call(8.1):
		_rec.set_recording_active(false)
		_rec.get_recording().save_to_wav(ProjectSettings.globalize_path("res://.godot/autotest_radio.wav"))
		get_tree().quit()


func _run_autotest_radio_night(delta: float) -> void:
	# Lueur de l'écran de l'autoradio : nuit radio éteinte / allumée, puis jour.
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	var w: WeatherSystem = $Weather
	w.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	car.throttle_input = 0.0
	car.brake_input = 1.0
	_inside = false
	var r = car.radio
	var glow: SpotLight3D = r.get_node("ScreenGlow")
	cam.fov = 55.0
	_cabin_cam(Vector3(0.35, 1.38, 0.05), Vector3(0.0, 1.0, 0.6))
	if at.call(0.05):
		w.hour = 23.0
		w.time_scale = 0.0
		w.set_weather("degage", true)
		car.light_stalk.set_notch(0, true)
		r.power = false
	if at.call(1.2):
		_shot("radionuit_1_eteinte")
		_log("AUTOTEST nuit, radio éteinte : lueur visible=%s énergie=%.3f" % [glow.visible, glow.light_energy])
		r.power = true
	if at.call(2.4):
		_shot("radionuit_2_allumee")
		_log("AUTOTEST nuit, radio allumée : lueur visible=%s énergie=%.3f (obscurité %.2f)" % [glow.visible, glow.light_energy, w.get_darkness()])
		w.hour = 13.0
	if at.call(3.6):
		_log("AUTOTEST jour, radio allumée : lueur visible=%s énergie=%.3f (obscurité %.2f)" % [glow.visible, glow.light_energy, w.get_darkness()])
		get_tree().quit()


func _run_autotest_radio_power(delta: float) -> void:
	# Touche PWR de l'autoradio, de nuit.
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	var w: WeatherSystem = $Weather
	w.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	car.brake_input = 1.0
	_inside = false
	var r = car.radio
	var glow: SpotLight3D = r.get_node("ScreenGlow")
	var btn: VRInteractable = r.get_node("Radio_power")
	var eye := Vector3(0.45, 1.45, -0.05)
	cam.fov = 24.0
	_cabin_cam(eye, car.to_local(r.global_position))
	var status := func() -> String:
		var n := 0
		for p in r.speakers:
			if p.playing: n += 1
		return "allumée=%s haut-parleurs actifs=%d écran=%s lueur=%s" % [r.is_on(), n, r._freq_lbl.visible, glow.visible]
	if at.call(0.05):
		w.hour = 22.0
		w.time_scale = 0.0
		w.set_weather("degage", true)
		car.light_stalk.set_notch(0, true)
		_hand = Node3D.new()
		add_child(_hand)
	if at.call(1.0):
		_shot("radiopwr_1_allumee")
		var pick := _ray_pick(car.to_global(eye), btn.global_position)
		_log("AUTOTEST au départ : %s ; visé la touche PWR -> %s" % [status.call(), pick.name if pick else "rien"])
		_hand.global_transform = btn.global_transform
		btn.grab(_hand)
		btn.release(_hand)
	if at.call(1.8):
		_shot("radiopwr_2_eteinte")
		_log("AUTOTEST touche PWR : " + status.call())
		btn.toggle()   # F
	if at.call(2.6):
		_log("AUTOTEST F sur PWR : " + status.call())
		get_tree().quit()


func _run_autotest_ambience(delta: float) -> void:
	# Ambiance : fermé, vitres ouvertes, portière, vent en roulant, nuit.
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	var w: WeatherSystem = $Weather
	w.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	car.throttle_input = 0.8 if _t > 7.0 and _t < 10.5 else 0.0
	car.brake_input = 0.0 if _t > 7.0 and _t < 11.0 else 1.0
	_inside = false
	cam.fov = 70.0
	_cabin_cam(Vector3(0.45, 1.45, -0.05), Vector3(0.3, 1.3, 1.0))
	var amb = car.ambience
	var status := func() -> String:
		var bus := AudioServer.get_bus_index("Ambiance")
		var lp := AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter
		var beds := PackedStringArray()
		for b in amb._bed_gain:
			beds.append("%s %.2f" % [b, amb._bed_gain[b]])
		return "ouverture=%.2f bus=%.1f dB filtre=%.0f Hz vent=%.1f dB | %s" % [amb.exposure, AudioServer.get_bus_volume_db(bus), lp.cutoff_hz, amb._wind.volume_db, ", ".join(beds)]
	if at.call(0.05):
		w.hour = 9.0
		w.time_scale = 0.0
		w.set_weather("degage", true)
		car.radio.power = false
		_rec = AudioEffectRecord.new()
		AudioServer.add_bus_effect(0, _rec)
		_rec.set_recording_active(true)
	if at.call(2.9): _log("AUTOTEST tout fermé (%.0f km/h) : %s" % [absf(car.forward_speed) * 3.6, status.call()])
	if at.call(3.0):
		car.window_cranks["FL"].set_opening(1.0)
		car.window_cranks["FR"].set_opening(1.0)
	if at.call(5.9): _log("AUTOTEST vitres avant ouvertes : " + status.call())
	if at.call(6.0): car.get_node("Doors/DoorFL").set_angle_deg(-60.0, true)
	if at.call(6.8):
		_log("AUTOTEST + portière ouverte : " + status.call())
		car.get_node("Doors/DoorFL").set_angle_deg(0.0, true)
	if at.call(10.4): _log("AUTOTEST en roulant vitres ouvertes (%.0f km/h) : %s" % [absf(car.forward_speed) * 3.6, status.call()])
	if at.call(10.5):
		car.window_cranks["FL"].set_opening(0.0)
		car.window_cranks["FR"].set_opening(0.0)
	if at.call(11.4): _log("AUTOTEST vitres refermées (%.0f km/h) : %s" % [absf(car.forward_speed) * 3.6, status.call()])
	if at.call(11.5):
		w.hour = 23.0
		car.window_cranks["FL"].set_opening(1.0)
	if at.call(15.5): _log("AUTOTEST nuit, vitre conducteur ouverte : " + status.call())
	if at.call(15.6): _log("AUTOTEST cris d'oiseaux joués en 15,6 s : %d" % amb.calls_played)
	if at.call(16.0):
		_rec.set_recording_active(false)
		_rec.get_recording().save_to_wav(ProjectSettings.globalize_path("res://.godot/autotest_ambiance.wav"))
		get_tree().quit()


var _spot_excess := 0.0
var _spot_frames := 0
var _spot_worst := ""
var _spot_who := {}


func _run_autotest_storage_spots(delta: float) -> void:
	# Objets dans les rangements (thermos dans le vide-poche, téléphone et joint dans la
	# boîte à gants, cigarette dans l'accoudoir) : on secoue, rien ne doit dépasser.
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	$Weather.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	_inside = false
	car.throttle_input = 1.0 if _t > 2.0 and _t < 6.0 else (0.55 if _t > 8.0 and _t < 13.0 else 0.0)
	car.brake_input = 1.0 if (_t < 2.0 or (_t > 6.0 and _t < 7.8) or _t > 13.0) else 0.0
	var steer := 0.0
	if _t > 8.5 and _t < 10.5: steer = 0.8
	elif _t > 10.5 and _t < 12.5: steer = -0.8
	_steer(steer)
	var pocket := car.get_node("Doors/DoorFL/Pocket") as StorageZone
	var glove := car.get_node("Storage/Glovebox") as StorageZone
	var console := car.get_node("Storage/Console") as StorageZone
	if _t < 13.5:
		cam.fov = 60.0
		_cabin_cam(Vector3(0.45, 1.45, -0.05), Vector3(0.80, 0.7, 0.5))   # vide-poche conducteur
	else:
		cam.fov = 55.0
		_cabin_cam(Vector3(-0.2, 1.3, 0.2), Vector3(-0.52, 0.86, 0.83))   # boîte à gants ouverte
	if at.call(0.05):
		$Weather.hour = 14.0
		$Weather.set_weather("degage", true)
		car.get_node("GloveboxLid").set_angle_deg(-80.0, true)
		car.get_node("ConsoleLid").set_angle_deg(-100.0, true)
	if at.call(0.3):
		var plan := {"Thermos": pocket, "Phone": glove, "Joint": glove, "Cigarette": console}
		for n in plan:
			var it := car.find_child(n, true, false) as RigidBody3D
			var z := it.get_parent() as StorageZone
			if z: z.on_item_taken(it)
			ItemPhysics.stop(it)
			if it.has_meta("rest_xf"): it.remove_meta("rest_xf")
			var dst: StorageZone = plan[n]
			it.global_position = dst.global_position + dst.global_basis.y * 0.05
			dst.store(it)
	if at.call(1.0):
		car.get_node("GloveboxLid").set_angle_deg(0.0, true)
		car.get_node("ConsoleLid").set_angle_deg(0.0, true)
	# chaque image : l'empreinte de chaque objet rangé reste-t-elle dans son compartiment ?
	for z2 in [pocket, glove, console]:
		var zone: StorageZone = z2
		for c in zone.get_children():
			if c is RigidBody3D:
				var st := ItemPhysics.get_state(c)
				if st.is_empty() or c.has_meta("rest_xf") or _t < 1.2:
					continue   # pas encore posé (ou état pas encore recalculé)
				var p: Vector3 = st["pos"]
				var h: Vector3 = st["half"]
				var ex := maxf(maxf(absf(p.x) + h.x - zone.size.x * 0.5, absf(p.z) + h.z - zone.size.z * 0.5), 0.0)
				if ex > 0.003:
					_spot_frames += 1
					_spot_who[c.name] = _spot_who.get(c.name, 0) + 1
					if ex > _spot_excess:
						_spot_excess = ex
						_spot_worst = "%s dans %s à t=%.1f pos=%s demi=%s taille=%s orig=%s air=%s" % [c.name, zone.zone_name, _t, p, h, zone.size, (c as Node3D).position, st.get("air")]
	if at.call(5.5): _shot("rangement_1_acceleration")
	if at.call(7.0): _shot("rangement_2_freinage")
	if at.call(11.0): _shot("rangement_3_virage")
	if at.call(13.6): car.get_node("GloveboxLid").set_angle_deg(-80.0, true)
	if at.call(14.6):
		_shot("rangement_4_boite_a_gants")
		var rep := PackedStringArray()
		for z3 in [pocket, glove, console]:
			for c in (z3 as StorageZone).get_children():
				if c is RigidBody3D:
					rep.append("%s dans %s, orientation %.0f°" % [c.name, (z3 as StorageZone).zone_name, rad_to_deg(float(ItemPhysics.get_state(c).get("yaw", 0.0)))])
		_log("AUTOTEST rangements : " + " ; ".join(rep))
		_log("AUTOTEST dépassements hors du compartiment : %d images, au plus %.1f mm (%s) par objet %s" % [_spot_frames, _spot_excess * 1000.0, _spot_worst, _spot_who])
		get_tree().quit()


func _run_autotest_all_belts(delta: float) -> void:
	# Ceintures de toutes les places : seule celle du conducteur fait biper.
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	$Weather.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	car.throttle_input = 0.35 if _t > 1.0 and _t < 9.0 else 0.0
	car.brake_input = 0.0 if _t > 1.0 and _t < 9.0 else 1.0
	_inside = false
	var belts: Array = car.seatbelts
	var drv = belts[0]
	var rl = belts[2]
	cam.fov = 75.0
	if _t >= 8.7 and _t < 9.2:
		_cabin_cam(Vector3(0.15, 1.45, 0.45), Vector3(-0.5, 1.0, -0.15))   # place passager
	else:
		_cabin_cam(Vector3(0.0, 1.68, -0.30), Vector3(0.0, 0.85, -1.05))   # banquette arrière, vue plongeante
	var states := func() -> String:
		var parts := PackedStringArray()
		for b in belts:
			parts.append("%s=%s" % [b.name.replace("Seatbelt", "").replace("", ""), "bouclée" if b.is_buckled() else "libre"])
		return " ".join(parts)
	if at.call(0.05):
		$Weather.hour = 14.0
		$Weather.set_weather("degage", true)
		_hand = Node3D.new()
		add_child(_hand)
		drv.toggle()   # conducteur bouclé
	if at.call(0.8): _shot("ceintures_1_libres")
	if at.call(4.0):
		_log("AUTOTEST conducteur bouclé, autres libres, %.0f km/h : voyant=%d carillon(s)=%s | %s" % [absf(car.forward_speed) * 3.6, car.get_belt_warning(), [belts[0]._chime_mode, belts[1]._chime_mode, belts[2]._chime_mode, belts[3]._chime_mode, belts[4]._chime_mode], states.call()])
		drv.toggle()   # conducteur débouclé
	if at.call(5.5):
		_log("AUTOTEST conducteur débouclé : voyant=%d carillon conducteur=%d" % [car.get_belt_warning(), drv._chime_mode])
		drv.toggle()
		# arrière gauche bouclée à la main
		_hand.global_position = rl._tongue.global_position
		rl._tongue.grab(_hand)
	if _t > 5.5 and _t <= 7.0 and rl._tongue.is_grabbed():
		var k := clampf((_t - 5.5) / 1.4, 0.0, 1.0)
		var start: Vector3 = rl._rest_point()
		var mid := Vector3(0.55, 1.15, -0.6)
		var end: Vector3 = rl._buckled_tongue_point()
		_hand.global_position = car.to_global(start.lerp(mid, k).lerp(mid.lerp(end, k), k))
		rl._tongue.grab_update(_hand)
		if not rl._tongue.enabled:
			rl._tongue.release(_hand)
	if at.call(7.2):
		_log("AUTOTEST arrière gauche à la main : bouclée=%s" % rl.is_buckled())
		for i in [1, 3, 4]:
			belts[i]._tongue.toggle()   # F sur le pêne : se bouclent seules
	if at.call(8.6):
		_log("AUTOTEST toutes bouclées : " + states.call())
		_shot("ceintures_2_bouclees")
		belts[3]._buckle.toggle()   # bouton rouge de la ceinture du milieu
	if at.call(9.1): _shot("ceintures_passager")
	if at.call(9.9):
		_log("AUTOTEST bouton rouge arrière milieu : " + states.call())
		_shot("ceintures_3_milieu_libre")
		get_tree().quit()


# Boîte auto 6 rapports : plein gaz en D jusqu'au bridage (154 km/h), lever de pied,
# kickdown, puis « 2 » et « 1 ». Journal toutes les secondes.
var _gear_log := {"max": 0.0, "t100": -1.0, "shifts": [], "last": 0}

func _run_autotest_gears(delta: float) -> void:
	var w: WeatherSystem = $Weather
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	w.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	var kmh: float = car.forward_speed * 3.6
	if at.call(0.05):
		w.set_weather("degage", true)
		w.rain_volume = 0.0
		car.handbrake_lever.set_angle_deg(0.0, true)
		car.gear_lever.set_notch(2, true)   # D
		_gear_log = {"max": 0.0, "t100": -1.0, "shifts": [], "last": 0}
		# piste d'essai droite et plate, loin au-dessus de la carte
		var strip := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(40.0, 1.0, 4000.0)
		cs.shape = box
		strip.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = box.size
		mi.mesh = bm
		strip.add_child(mi)
		add_child(strip)
		strip.global_position = Vector3(0.0, 400.0, 0.0)
		car.global_transform = Transform3D(Basis(), Vector3(0.0, 401.2, -1950.0))
		car.linear_velocity = Vector3.ZERO
		car.angular_velocity = Vector3.ZERO
	var thr := 0.0
	var brk := 0.0
	if _t < 0.5:
		brk = 1.0
	elif _t < 45.0:
		thr = 1.0
		if kmh >= 100.0 and _gear_log["t100"] < 0.0:
			_gear_log["t100"] = _t - 0.5
			_log("AUTOTEST 0-100 km/h : %.1f s" % (_t - 0.5))
	elif _t < 52.0:
		thr = 0.0   # lever de pied puis freinage jusqu'à 70 km/h
		brk = 0.5 if kmh > 70.0 else 0.0
	elif _t < 56.0:
		thr = 1.0   # kickdown
	elif _t < 64.0:
		thr = 0.0
		brk = 0.6 if kmh > 95.0 else 0.0
		if at.call(57.0): car.gear_lever.set_notch(3, true)   # « 2 » (à ~100 km/h : pas de surrégime)
	elif _t < 74.0:
		thr = 1.0
		if at.call(69.0): car.gear_lever.set_notch(4, true)   # « 1 »
	if car.auto_gear != _gear_log["last"]:
		_gear_log["shifts"].append("%d→%d à %.0f km/h (t=%.1f)" % [_gear_log["last"] + 1, car.auto_gear + 1, kmh, _t])
		_gear_log["last"] = car.auto_gear
	if _t < 45.0:
		_gear_log["max"] = maxf(_gear_log["max"], kmh)
	var fwd := car.global_basis.z
	# tout droit vers +Z, en corrigeant l'écart latéral
	var to_t := Vector3(0.0, 0.0, car.global_position.z + 30.0 + absf(car.forward_speed)) - car.global_position
	to_t.y = 0.0
	_steer(clampf(fwd.cross(to_t.normalized()).y * 2.0, -1.0, 1.0))
	car.throttle_input = thr
	car.brake_input = brk
	_inside = false
	_cabin_cam(Vector3(0.42, 1.52, -0.2), Vector3(0.42, 1.25, 4.0))
	if fmod(_t, 1.0) < delta and _t > 0.5:
		_log("AUTOTEST t=%.0f levier=%s rapport=%d vitesse=%.0f km/h régime=%.0f" % [_t, car.gear_lever.get_notch_label(), car.auto_gear + 1, kmh, car.engine_sound.rpm])
	if at.call(30.0): _shot("vitesses_combine")
	if at.call(44.9):
		_log("AUTOTEST vitesse max en D : %.1f km/h" % _gear_log["max"])
	if at.call(74.0):
		_log("AUTOTEST passages : " + " | ".join(PackedStringArray(_gear_log["shifts"])))
		get_tree().quit()


# Collisions du décor : le 4x4 roule à ~15 km/h droit sur un sapin (branches basses),
# puis sur un arbre des collines et sur un rocher. On mesure la distance entre l'axe de
# l'obstacle et l'avant de l'habitacle / du pare-chocs.
var _tree_targets: Array = []
var _tree_idx := -1
var _tree_t0 := 0.0
var _tree_min := 99.0

func _find_obstacles() -> void:
	var road: RoadGenerator = $RoadGenerator
	var sapin = null
	var colline = null
	var rocher = null
	var hills := 0
	for body in road.find_children("NatureCollision", "StaticBody3D", true, false):
		for cs in body.get_children():
			var sh = (cs as CollisionShape3D).shape
			var gp: Vector3 = cs.global_position
			var info := road.sample_road(gp)
			var lat := 999.0
			if info["found"]:
				lat = (gp - info["point"]).dot(info["right"])
			var dist_car := gp.distance_to(car.global_position)
			if sh is CylinderShape3D and sh.radius > 0.9 and sh.radius < 1.7:
				var bottom: float = gp.y - sh.height * 0.5
				var ground: float = gp.y - sh.height * 0.5 - 1.2
				if absf(lat) > 48.0:
					hills += 1
				if sapin == null and absf(lat) > 14.0 and absf(lat) < 30.0 and dist_car < 120.0:
					sapin = {"pos": gp, "r": sh.radius, "bottom": bottom, "kind": "sapin (couronne)"}
				elif colline == null and absf(lat) > 50.0 and absf(lat) < 70.0 and dist_car < 150.0:
					colline = {"pos": gp, "r": sh.radius, "bottom": bottom, "kind": "arbre des collines (couronne)"}
			elif sh is ConvexPolygonShape3D and rocher == null and absf(lat) > 10.0 and absf(lat) < 30.0 and dist_car < 150.0:
				var mx := 0.0
				for v in sh.points:
					mx = maxf(mx, Vector2(v.x, v.z).length())
				if mx > 0.8:
					rocher = {"pos": gp, "r": mx, "bottom": gp.y, "kind": "rocher (enveloppe)"}
	_log("AUTOTEST couronnes d'arbres sur les collines (> 48 m) : %d" % hills)
	for o in [sapin, colline, rocher]:
		if o != null:
			_tree_targets.append(o)
	_log("AUTOTEST obstacles trouvés : %s" % ", ".join(PackedStringArray(_tree_targets.map(func(o): return o["kind"]))))

func _place_before(o: Dictionary) -> void:
	var target: Vector3 = o["pos"]
	var from := target + Vector3(9.0, 0.0, 0.0).rotated(Vector3.UP, randf() * TAU)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from + Vector3(0, 40, 0), from - Vector3(0, 60, 0))
	q.exclude = [car.get_rid()]
	var hit := space.intersect_ray(q)
	var y: float = hit["position"].y if hit else target.y
	var dir := Vector3(target.x - from.x, 0, target.z - from.z).normalized()
	car.global_transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), Vector3(from.x, y + 0.6, from.z))
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	_tree_min = 99.0

func _run_autotest_tree_hits(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	$Weather.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	car.handbrake_lever.set_angle_deg(0.0, true)
	if at.call(0.05):
		$Weather.hour = 13.0
		$Weather.set_weather("degage", true)
		car.gear_lever.set_notch(2, true)
	if at.call(2.0):
		_find_obstacles()
		if _tree_targets.is_empty():
			_log("AUTOTEST aucun obstacle trouvé")
			get_tree().quit()
			return
		_tree_idx = 0
		_tree_t0 = _t
		_place_before(_tree_targets[0])
	if _tree_idx < 0:
		car.brake_input = 1.0
		car.throttle_input = 0.0
		return
	var o: Dictionary = _tree_targets[_tree_idx]
	var el := _t - _tree_t0
	var target: Vector3 = o["pos"]
	var fwd: Vector3 = car.global_basis.z
	var to_t := Vector3(target.x, 0, target.z) - Vector3(car.global_position.x, 0, car.global_position.z)
	_steer(clampf(fwd.cross(to_t.normalized()).y * 2.0, -1.0, 1.0) if el < 4.0 else 0.0)
	var kmh: float = car.forward_speed * 3.6
	car.throttle_input = (1.0 if kmh < 12.0 else 0.0) if el > 0.5 else 0.0
	car.brake_input = 1.0 if el < 0.5 else 0.0
	# avant de l'habitacle (bord du pare-brise, z = 1,1) et du pare-chocs (z = 2,5) à hauteur de capot
	var cab: Vector3 = car.to_global(Vector3(0, 1.5, 1.1))
	var bump: Vector3 = car.to_global(Vector3(0, 0.8, 2.5))
	var d_cab := Vector2(cab.x - target.x, cab.z - target.z).length()
	var d_bump := Vector2(bump.x - target.x, bump.z - target.z).length()
	_tree_min = minf(_tree_min, d_cab if o["kind"].begins_with("sapin") or o["kind"].begins_with("arbre") else d_bump)
	_inside = false
	cam.fov = 75.0
	_cabin_cam(Vector3(0.42, 1.52, -0.2), Vector3(0.42, 1.35, 4.0))
	if absf(el - 7.0) < delta * 0.5 + 0.0001 or (el >= 7.0 and el - delta < 7.0):
		_shot("sapins_%d" % _tree_idx)
	if el >= 9.0 and el - delta < 9.0:
		var passed := to_t.dot(fwd) < 0.0
		_log("AUTOTEST %s : rayon bloquant %.2f m, bas de la couronne à %.2f m du sol, distance mini axe-%s = %.2f m, vitesse finale %.1f km/h, traversé=%s" % [o["kind"], o["r"], o["bottom"] - (car.global_position.y - 0.0), "pare-brise" if not o["kind"].begins_with("rocher") else "pare-chocs", _tree_min, kmh, passed])
		_tree_idx += 1
		if _tree_idx >= _tree_targets.size():
			get_tree().quit()
			return
		_tree_t0 = _t
		_place_before(_tree_targets[_tree_idx])


# Balises souples : le 4x4 roule à 50 puis 90 km/h, décalé à droite pour que son aile
# droite accroche une balise. On note la vitesse avant/après, l'angle de la balise,
# la rotation de la voiture, puis le retour de la balise à la verticale.
var _post: Node3D
var _post_pass := 0
var _post_log := {}

func _next_post_ahead(min_d: float) -> Node3D:
	var road: RoadGenerator = $RoadGenerator
	var best: Node3D = null
	var best_d := 1e9
	var fwd: Vector3 = car.global_basis.z
	for p in get_tree().get_nodes_in_group("road_posts"):
		var d: Vector3 = p.global_position - car.global_position
		var ahead := d.dot(fwd)
		var info := road.sample_road(p.global_position)
		if not info["found"] or (p.global_position - info["point"]).dot(info["right"]) < 0.0:
			continue   # balises de droite seulement
		if ahead > min_d and ahead < best_d:
			best_d = ahead
			best = p
	return best

func _run_autotest_posts(delta: float) -> void:
	var road: RoadGenerator = $RoadGenerator
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	$Weather.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	var kmh: float = car.forward_speed * 3.6
	var want := 50.0 if _post_pass <= 1 else 90.0
	if at.call(0.05):
		$Weather.hour = 15.0
		$Weather.set_weather("degage", true)
		car.handbrake_lever.set_angle_deg(0.0, true)
		car.gear_lever.set_notch(2, true)
	# vitesse régulée, sauf pendant le passage sur la balise (pas de gaz)
	var near := false
	if _post != null:
		var dz: float = (_post.global_position - car.global_position).dot(car.global_basis.z)
		near = dz < 12.0 and dz > -6.0
	car.throttle_input = 0.0 if near else clampf((want - kmh) * 0.15, 0.0, 1.0)
	car.brake_input = 0.0
	# suit la route avec un décalage à droite : centre à 4,4 m de l'axe → l'aile droite
	# (1 m) passe à 5,4 m, la balise est à 5,0 m
	var lat := 4.3 if _post != null else 1.75
	var fwd: Vector3 = car.global_basis.z
	var info := road.sample_road(car.global_position + fwd * (8.0 + absf(car.forward_speed) * 0.5))
	if info["found"]:
		var target: Vector3 = info["point"] + info["right"] * lat
		var to_t := target - car.global_position
		to_t.y = 0.0
		_steer(clampf(fwd.cross(to_t.normalized()).y * 2.5, -1.0, 1.0))
	_inside = false
	cam.fov = 70.0
	if _post != null and not _post_log.has("cam_off"):
		var dzc: float = (_post.global_position - car.global_position).dot(car.global_basis.z)
		if dzc < 14.0:
			# caméra fixe au bord de la route, en arrière de la balise, côté extérieur
			if not _post_log.has("cam"):
				var rgt: Vector3 = -car.global_basis.x
				var fw: Vector3 = car.global_basis.z
				_post_log["cam"] = [_post.global_position + rgt * 4.0 - fw * 5.0 + Vector3(0, 1.6, 0), _post.global_position + Vector3(0, 0.3, 0) + fw * 1.0]
			cam.global_position = _post_log["cam"][0]
			cam.look_at(_post_log["cam"][1])
		else:
			_cabin_cam(Vector3(0.42, 1.52, -0.2), Vector3(0.42, 1.35, 4.0))
	else:
		_cabin_cam(Vector3(0.42, 1.52, -0.2), Vector3(0.42, 1.35, 4.0))
	if fmod(_t, 5.0) < delta:
		_log("AUTOTEST t=%.0f vitesse %.0f km/h, balises chargées : %d" % [_t, kmh, get_tree().get_nodes_in_group("road_posts").size()])
		if absf(kmh) < 2.0 and _t > 6.0 and not _post_log.has("stuck"):
			_post_log["stuck"] = true
			var inf2 := road.sample_road(car.global_position)
			_log("AUTOTEST voiture arrêtée à %.1f m de l'axe, inclinaison %.0f°" % [(car.global_position - inf2["point"]).dot(inf2["right"]), rad_to_deg(car.global_basis.y.angle_to(Vector3.UP))])
			_shot("balise_bloquee")
	if _post == null and _post_pass < 3 and kmh > want - 3.0 and _t > 3.0:
		_post = _next_post_ahead(45.0)
		if _post:
			_post_pass += 1
			_post_log = {"hits0": _post.hits, "v0": -1.0, "vmin": 999.0, "bend": 0.0, "yaw": 0.0, "t_hit": -1.0, "shot": false}
			_log("AUTOTEST passage %d à %.0f km/h vers une balise à %.0f m" % [_post_pass, kmh, (_post.global_position - car.global_position).length()])
	if _post != null:
		var dz: float = (_post.global_position - car.global_position).dot(car.global_basis.z)
		if dz < 8.0 and _post_log["v0"] < 0.0:
			_post_log["v0"] = kmh
		if _post.hits > _post_log["hits0"] and _post_log["t_hit"] < 0.0:
			_post_log["t_hit"] = _t
		if _post_log["t_hit"] > 0.0 and _t - _post_log["t_hit"] < 1.5:
			_post_log["vmin"] = minf(_post_log["vmin"], kmh)
			_post_log["bend"] = maxf(_post_log["bend"], _post.get_bend_deg())
			_post_log["yaw"] = maxf(_post_log["yaw"], rad_to_deg(absf(car.angular_velocity.y)))
		# captures depuis la caméra fixe : couchée sous la voiture, puis qui se redresse
		if _post_log["t_hit"] > 0.0:
			var dt_hit: float = _t - _post_log["t_hit"]
			for k in [[0.15, "a_contact"], [0.45, "b_couchee"], [1.0, "c_rebond"], [1.4, "d_retour"]]:
				if dt_hit >= k[0] and dt_hit - delta < k[0]:
					_shot("balise_%d_%s" % [_post_pass, k[1]])
		if _post_log["t_hit"] > 0.0 and _t - _post_log["t_hit"] > 1.5 and not _post_log.has("logged"):
			_post_log["logged"] = true
			_log("AUTOTEST passage %d : touchée=%s, %.0f → %.0f km/h (−%.1f), balise couchée à %.0f°, rotation voiture max %.1f°/s" % [_post_pass, _post.hits > _post_log["hits0"], _post_log["v0"], _post_log["vmin"], _post_log["v0"] - _post_log["vmin"], _post_log["bend"], _post_log["yaw"]])
			var p := _post
			var num := _post_pass
			_post_log["cam_off"] = true
			get_tree().create_timer(4.0).timeout.connect(func(): _log("AUTOTEST balise %d, 5,5 s après le choc : %.1f° (redressée=%s)" % [num, p.get_bend_deg(), p.get_bend_deg() < 1.0]))
			_post = null
		elif _post_log["t_hit"] < 0.0 and dz < -10.0:
			_log("AUTOTEST passage %d : balise PAS touchée" % _post_pass)
			_post = null
	if _post_pass >= 3 and _post == null and not _post_log.has("end"):
		_post_log["end"] = _t
	if _post_log.has("end") and _t - _post_log["end"] > 5.0:
		get_tree().quit()


# Station playlist (PILS MIX) : chargement du dossier, écran, morceau joué, passage au
# morceau suivant à la fin (ou reprise du même s'il est seul), radio éteinte/rallumée.
func _run_autotest_playlist(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	$Weather.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	car.brake_input = 1.0
	var r = car.radio
	_inside = false
	cam.fov = 40.0
	_cabin_cam(Vector3(0.1, 1.35, 0.25), Vector3(0.0, 1.06, 0.66))
	var st := func() -> String:
		var p: AudioStreamPlayer3D = r.speakers[0]
		var cls: String = p.stream.get_class() if p.stream else "aucun"
		return "station=%d (%s) écran=« %s » flux=%s lecture=%s pos=%.1f s titre=« %s »" % [r.station, r.STATIONS[r.station]["name"], r._name_lbl.text, cls, p.playing, p.get_playback_position(), r.get_track_title()]
	if at.call(0.5):
		_log("AUTOTEST playlist : %d morceau(x), durée totale %.0f s : %s" % [r._playlist.size(), r._playlist_total, ", ".join(PackedStringArray(r._playlist.map(func(e): return "%s (%.0f s)" % [e["title"], e["length"]])))])
		r.set_station(0)
		r.next_station(); r.next_station(); r.next_station(); r.next_station()   # 4 x ▶ -> 5e station
	if at.call(1.5):
		_log("AUTOTEST ▶ x4 : " + st.call())
		_shot("playlist_1_nom")
	if at.call(4.5):
		_log("AUTOTEST 3 s plus tard : " + st.call())
		_shot("playlist_2_titre")
	if at.call(5.0):
		# saute à 1,5 s de la fin du morceau en cours
		var now: Array = r._playlist_now(r.station)
		var left: float = r._playlist[now[0]]["length"] - now[1]
		r._clock += left - 1.5
		r._load(r.station)   # les haut-parleurs repartent à la nouvelle position
		_log("AUTOTEST saut à 1,5 s de la fin du morceau")
	if at.call(5.2):
		_log("AUTOTEST avant la fin : " + st.call())
	if at.call(7.5):
		_log("AUTOTEST après la fin : " + st.call())
	if at.call(8.0):
		r.toggle_power()
	if at.call(8.5):
		_log("AUTOTEST radio éteinte : lecture=%s" % r.speakers[0].playing)
		r.toggle_power()
	if at.call(9.0):
		_log("AUTOTEST rallumée : " + st.call())
		r.next_station()
	if at.call(9.8):
		_log("AUTOTEST ▶ encore (retour à la 1re) : station=%d (%s) flux=%s" % [r.station, r.STATIONS[r.station]["name"], r.speakers[0].stream.resource_path.get_file()])
		get_tree().quit()


# Animaux : espèces selon le biome, promeneurs, puis traversées devant la voiture à
# 60 km/h : biche et moutons avec freinage (évités), sanglier, lapin et biche sans
# freiner (chocs). Vitesse perdue au choc, captures depuis l'arrière de la voiture.
var _an_trials := [["deer", true], ["sheep", true], ["boar", false], ["rabbit", false], ["deer", false], ["sheep", false]]
var _an_i := -1
var _an_t0 := 0.0
var _an_log := {}
var _an_group: Array = []

func _run_autotest_animals(delta: float) -> void:
	var road: RoadGenerator = $RoadGenerator
	var am = road.get_node("Animals")
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	$Weather.random_events = false
	$FallingTrees.enabled = false
	am.crossings_enabled = false
	car.external_input = true
	var kmh: float = car.forward_speed * 3.6
	if at.call(0.05):
		$Weather.hour = 15.0
		$Weather.set_weather("degage", true)
		car.handbrake_lever.set_angle_deg(0.0, true)
		car.gear_lever.set_notch(2, true)
	if at.call(1.0):
		var bw: Array = road.get_biome_at(car.global_position)
		var counts := {}
		for i in 400:
			var sp: String = am.pick_species(car.global_position)
			counts[sp] = counts.get(sp, 0) + 1
		_log("AUTOTEST biome ici [sapins, mixte, prairie, montagne] = [%.2f, %.2f, %.2f, %.2f] -> tirages sur 400 : %s" % [bw[0], bw[1], bw[2], bw[3], counts])
		# tirages dans des biomes purs (poids donnés à la main)
		for pure in [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]:
			var c2 := {}
			for i in 400:
				var tot := 0.0
				var ws := {}
				for sp in am.SPECIES:
					var w := 0.0
					for b in 4:
						w += pure[b] * float(am.SPECIES[sp]["weights"][b])
					ws[sp] = w
					tot += w
				var r := randf() * tot
				for sp in ws:
					r -= ws[sp]
					if r <= 0.0:
						c2[sp] = c2.get(sp, 0) + 1
						break
			_log("AUTOTEST biome pur %s -> %s" % [pure, c2])
	if at.call(6.0):
		var desc := PackedStringArray()
		for a in am.animals:
			var lat: float = am.lateral_of(a.global_position)
			desc.append("%s à %.0f m (côté %.0f m)%s" % [a.species, a.global_position.distance_to(car.global_position), lat, " jeune" if a.size_scale < 0.8 else ""])
		_log("AUTOTEST promeneurs (%d) : %s" % [am.animals.size(), ", ".join(desc)])
		# vue sur le promeneur le plus proche
		var best = null
		var bd := 1e9
		for a in am.animals:
			var d: float = a.global_position.distance_to(car.global_position)
			if d < bd:
				bd = d
				best = a
		if best:
			_an_log["look"] = best
	if _t > 6.0 and _t < 7.0 and _an_log.has("look") and is_instance_valid(_an_log["look"]):
		var a: Node3D = _an_log["look"]
		cam.fov = 50.0
		cam.global_position = a.global_position + Vector3(3.5, 1.6, 3.5)
		cam.look_at(a.global_position + Vector3(0, 0.5, 0))
		if at.call(6.8):
			_shot("animaux_0_promeneur_" + a.species)
		return
	# conduite : voie de droite, 60 km/h, freinage si un animal traverse devant
	var fwd: Vector3 = car.global_basis.z
	var info := road.sample_road(car.global_position + fwd * (8.0 + absf(car.forward_speed) * 0.5))
	if info["found"]:
		var target: Vector3 = info["point"] + info["right"] * 1.75
		var to_t := target - car.global_position
		to_t.y = 0.0
		_steer(clampf(fwd.cross(to_t.normalized()).y * 2.0, -1.0, 1.0))
	var brake := false
	var nearest := 1e9
	if _an_i >= 0 and _an_i < _an_trials.size():
		for a in _an_group:
			if not is_instance_valid(a):
				continue
			var d: Vector3 = a.global_position - car.global_position
			var ahead: float = d.dot(fwd)
			var lat: float = am.lateral_of(a.global_position)
			if ahead > 0.0:
				nearest = minf(nearest, ahead)
			if _an_trials[_an_i][1] and ahead > 0.0 and ahead < 70.0 and (absf(lat) < 4.5 or a.crossing):
				brake = true
	car.throttle_input = 0.0 if brake else clampf((60.0 - kmh) * 0.15, 0.0, 1.0)
	car.brake_input = 1.0 if brake else 0.0
	_inside = false
	cam.fov = 70.0
	_cabin_cam(Vector3(0.0, 3.2, -8.0), Vector3(0.0, 1.0, 12.0))
	# essais successifs
	if _an_i < 0 and _t > 9.0 and kmh > 55.0:
		_an_i = 0
		_an_start_trial(am)
	if _an_i >= 0 and _an_i < _an_trials.size():
		var el := _t - _an_t0
		_an_log["vmax"] = maxf(_an_log.get("vmax", 0.0), kmh) if am.animals_hit == _an_log["hits0"] else _an_log.get("vmax", 0.0)
		if am.animals_hit > _an_log["hits0"]:
			if not _an_log.has("t_hit"):
				_an_log["t_hit"] = _t
				_an_log["v_hit"] = _an_log["vmax"]
			_an_log["vmin"] = minf(_an_log.get("vmin", 999.0), kmh) if _t - _an_log["t_hit"] < 1.2 else _an_log.get("vmin", 999.0)
			if not _an_log.has("shot_hit") and _t - _an_log["t_hit"] > 0.25:
				_an_log["shot_hit"] = true
				_shot("animaux_%d_%s_choc" % [_an_i + 1, _an_trials[_an_i][0]])
		if nearest < 30.0 and not _an_log.has("shot_near"):
			_an_log["shot_near"] = true
			_shot("animaux_%d_%s_traverse" % [_an_i + 1, _an_trials[_an_i][0]])
		# où est l'animal quand l'avant de la voiture passe à sa hauteur ?
		for a in _an_group:
			if not is_instance_valid(a):
				continue
			var l: Vector3 = car.to_local(a.global_position)
			var key := "pz%d" % a.get_instance_id()
			if _an_log.has(key) and _an_log[key] > 2.5 and l.z <= 2.5:
				_an_log["pass"] = _an_log.get("pass", "") + " %s x=%.1f m (état %d, vitesse %.1f)" % [a.species, l.x, a.state, a.speed]
			_an_log[key] = l.z
		# sons joués par le groupe
		for a in _an_group:
			if is_instance_valid(a) and a._player and a._player.playing:
				_an_log["sound"] = true
		var still_crossing := false
		for a in _an_group:
			if is_instance_valid(a) and a.crossing:
				still_crossing = true
		if el > 11.0 and (not still_crossing or el > 30.0) and kmh > 50.0:
			var sp: String = _an_trials[_an_i][0]
			var hit: bool = am.animals_hit > _an_log["hits0"]
			var txt := "AUTOTEST traversée %d : %s ×%d, %s : " % [_an_i + 1, sp, _an_group.size(), "freinage" if _an_trials[_an_i][1] else "sans freiner"]
			if hit:
				txt += "CHOC à %.0f km/h → %.0f km/h (−%.1f)" % [_an_log["v_hit"], _an_log["vmin"], _an_log["v_hit"] - _an_log["vmin"]]
			else:
				txt += "évité (vitesse mini %.0f km/h)" % _an_log.get("vmin_brake", kmh)
			var states := PackedStringArray()
			for a in _an_group:
				if is_instance_valid(a):
					states.append("%s(côté %.0f m, état %d)" % [a.species, am.lateral_of(a.global_position), a.state])
			txt += " ; son joué=%s ; après : %s" % [_an_log.get("sound", false), ", ".join(states)]
			txt += " ; au passage de la voiture :" + _an_log.get("pass", " -")
			_log(txt)
			_an_i += 1
			if _an_i >= _an_trials.size():
				_log("AUTOTEST bilan : traversées=%d évitées=%d chocs=%d" % [am.crossings, am.crossings_avoided, am.animals_hit])
				get_tree().quit()
			else:
				_an_start_trial(am)
		if brake:
			_an_log["vmin_brake"] = minf(_an_log.get("vmin_brake", 999.0), kmh)


func _an_start_trial(am) -> void:
	_an_t0 = _t
	_an_log = {"hits0": am.animals_hit}
	var sp: String = _an_trials[_an_i][0]
	_an_group = am.spawn_crossing(sp, 75.0, 1 if _an_i % 2 == 0 else -1)
	for a in _an_group:
		if sp == "deer":
			a._freeze = 0.0 if not _an_trials[_an_i][1] else a._freeze   # chocs : pas d'arrêt
	_log("AUTOTEST traversée %d lancée : %s ×%d à 75 m, voiture à %.0f km/h" % [_an_i + 1, sp, _an_group.size(), car.forward_speed * 3.6])


# Pochette de pilules : placement au hasard, ouverture (F), visée (pilules / zip),
# pilule avalée avec F, pilule sortie à la main et portée à la bouche (VR), pilule
# posée puis avalée avec F, fermeture. Un PillAddiction est ajouté pour l'effet.
var _pb_add: Node
var _pb_held: VRInteractable

## Interactable que viserait la souris (même règle que MouseHand).
func _aim_pick(origin: Vector3, to: Vector3) -> String:
	var dir := (to - origin).normalized()
	var best: VRInteractable = null
	var best_t := INF
	for n in get_tree().get_nodes_in_group(VRInteractable.GROUP):
		var it := n as VRInteractable
		if it == null or not it.enabled or not it.is_visible_in_tree():
			continue
		var tt := it.ray_hit_distance(origin, dir, 3.0, it.grab_distance * 0.3)
		if tt - it.pick_bonus * 3.0 < best_t - (best.pick_bonus * 3.0 if best else 0.0):
			best = it
			best_t = tt
	return best.name if best and best_t < INF else "rien"

## Interactable que prendrait une main VR à cette position (même règle que la main).
func _hand_pick(p: Vector3) -> String:
	var best: VRInteractable = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(VRInteractable.GROUP):
		var it := n as VRInteractable
		if it == null or not it.enabled or not it.is_visible_in_tree():
			continue
		var d := it.get_distance_to(p)
		if d < it.highlight_distance and d - it.pick_bonus < best_d - (best.pick_bonus if best else 0.0):
			best = it
			best_d = d
	return best.name if best else "rien"

func _run_autotest_pill_bag(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	$Weather.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	car.throttle_input = 0.0
	car.brake_input = 1.0
	_inside = false
	if _hand == null:
		_hand = Node3D.new()
		add_child(_hand)
	if _held or _pb_held:
		var k := clampf((_t - _move_t0) / _move_dur, 0.0, 1.0)
		_hand.global_position = car.to_global(_move_from.lerp(_move_to, k))
		(_held if _held else _pb_held).grab_update(_hand)
	var bag_item := _item("PillBag")
	var bag = bag_item.get_node("Grab") if bag_item else null
	cam.fov = 60.0
	_cabin_cam(Vector3(-0.2, 1.28, 0.28), Vector3(-0.45, 0.88, 0.0))
	var st := func() -> String:
		var taken: int = _pb_add.pills_taken if _pb_add else -1
		return "ouverte=%s pilules=%d avalées=%d (compteur %d) manque=%.2f" % [bag.open, bag.pills_left(), taken, get_tree().root.get_meta("pills_eaten", 0), _pb_add.craving if _pb_add else -1.0]
	if at.call(0.05):
		$Weather.hour = 14.0
		$Weather.set_weather("degage", true)
		_pb_add = get_tree().get_first_node_in_group("pill_addiction")
		if _pb_add == null:
			_pb_add = preload("res://world/pills/pill_addiction.gd").new()
			_pb_add.set("car_path", car.get_path())
			add_child(_pb_add)
		_pb_add.set("craving", 0.6)
	if at.call(0.3):
		var z = bag_item.get_parent()
		_log("AUTOTEST pochette rangée au hasard : %s (%s), %d pilules, fermée=%s" % [z.get("zone_name") if z.get("zone_name") else z.name, car.to_local(bag_item.global_position), bag.pills_left(), not bag.open])
		_grab_item("PillBag", Vector3(-0.45, 1.0, 0.0), 0.8)
	if at.call(1.3):
		_release_item()
	if at.call(2.2):
		var c := cam.global_position
		var pills: Vector3 = bag._pills_root.global_position + bag_item.global_basis * Vector3(0, 0.004, -0.01)
		var zip: Vector3 = bag_item.global_transform * Vector3(0, 0.004, 0.06)
		_log("AUTOTEST pochette posée : %s ; fermée, visée sur les pilules -> %s" % [car.to_local(bag_item.global_position), _aim_pick(c, pills)])
		_shot("pochette_1_fermee")
		bag.toggle()   # F sur la pochette fermée
	if at.call(2.8):
		var c := cam.global_position
		var pills: Vector3 = bag_item.global_transform * Vector3(0.0, 0.004, -0.02)
		var zip: Vector3 = bag_item.global_transform * Vector3(0, 0.005, 0.062)
		_log("AUTOTEST F -> %s ; visée pilules -> %s, visée zip -> %s ; main VR sur les pilules -> %s, sur le zip -> %s" % [st.call(), _aim_pick(c, pills), _aim_pick(c, zip), _hand_pick(pills + bag_item.global_basis.y * 0.01), _hand_pick(zip)])
		_shot("pochette_2_ouverte")
		bag._taker.toggle()   # F en visant les pilules
	if at.call(3.2):
		_log("AUTOTEST F sur les pilules : " + st.call())
		# VR : main dans la pochette, on serre -> une pilule dans la main
		_hand.global_position = bag_item.global_transform * Vector3(0.0, 0.01, -0.02)
		_pb_held = bag._taker
		_pb_held.grab(_hand)
		var mouth: Vector3 = EdiblePickable.mouth_position(get_tree())
		_move_from = car.to_local(_hand.global_position)
		_move_to = car.to_local(mouth)
		_move_t0 = _t
		_move_dur = 1.0
		_log("AUTOTEST main dans la pochette : %s ; pilule tenue=%s" % [st.call(), bag._taker._held.size()])
	if at.call(3.9):
		_shot("pochette_3_vers_la_bouche")
	if at.call(4.6):
		_log("AUTOTEST pilule portée à la bouche : " + st.call())
		_pb_held.release(_hand)
		_pb_held = null
	if at.call(5.0):
		# une pilule sortie et posée sur le siège
		_hand.global_position = bag_item.global_transform * Vector3(0.0, 0.01, -0.02)
		_pb_held = bag._taker
		_pb_held.grab(_hand)
		_move_from = car.to_local(_hand.global_position)
		_move_to = Vector3(-0.35, 0.95, -0.1)
		_move_t0 = _t
		_move_dur = 0.5
	if at.call(5.7):
		_pb_held.release(_hand)
		_pb_held = null
	if at.call(6.3):
		var loose: Array = []
		for n in car.find_children("*", "RigidBody3D", true, false):
			if n.get_node_or_null("Grab") is EdiblePickable:
				loose.append(n)
		_log("AUTOTEST pilule sortie et posée : %d pilule(s) hors pochette %s ; %s" % [loose.size(), loose.map(func(n): return "%s %s" % [n.name, car.to_local(n.global_position)]), st.call()])
		_shot("pochette_4_pilule_posee")
		for n in loose:
			n.get_node("Grab").toggle()   # F en la visant
	if at.call(6.8):
		_log("AUTOTEST F sur la pilule posée : " + st.call())
		bag.toggle()   # F sur le zip : fermée
	if at.call(7.4):
		_log("AUTOTEST refermée : %s ; zone pilules active=%s" % [st.call(), bag._taker.enabled])
		_shot("pochette_5_refermee")
		get_tree().quit()


# --- Lieu de départ (forcé par override.cfg : [nfp] start_site="motel") ---------

var _ls := {}


func _run_autotest_start_site(delta: float) -> void:
	var road: RoadGenerator = $RoadGenerator
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	$Weather.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	_inside = false
	var site: Node3D = road.find_child("StartSite", true, false)
	var kmh: float = car.forward_speed * 3.6
	if at.call(0.05):
		$Weather.hour = 14.0
		$Weather.set_weather("degage", true)
		car.handbrake_lever.set_angle_deg(0.0, true)
		car.gear_lever.set_notch(1, true)   # N le temps des photos
	if at.call(1.0):
		var info: Dictionary = road.get_start_site()
		var lp := road.to_local(car.global_position)
		var q := PhysicsRayQueryParameters3D.create(car.global_position + Vector3.UP, car.global_position + Vector3.DOWN * 5.0, 1, [car.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		var under := "rien"
		if hit:
			under = "%s (y=%.2f)" % [hit["collider"].name, hit["position"].y]
		_log("AUTOTEST lieu=%s noeud=%s voiture latéral=%.1f s=%.1f y=%.2f sur_lieu=%s sol=%s" % [info.get("type", "?"), site != null, -lp.x, lp.z, car.global_position.y, road.in_start_site(lp), under])
		_ls["y0"] = car.global_position.y
	if site == null:
		if at.call(3.0):
			_log("AUTOTEST ÉCHEC : pas de StartSite")
			get_tree().quit()
		return
	var sx := site.global_transform
	var depth: float = site.get("depth")
	var center := sx * Vector3(0, 1.0, depth * 0.5)
	cam.fov = 65.0
	if _t < 2.6:
		cam.global_position = sx * Vector3(-depth * 0.2, 13.0, -14.0)
		cam.look_at(center)
		if at.call(2.4):
			_shot("lieu_%s_1_vue" % site.get("site_type"))
		return
	if _t < 4.2:
		var slen: float = site.get("length")
		cam.global_position = sx * Vector3(-slen * 0.5 - 7.0, 2.0, -5.0)
		cam.look_at(sx * Vector3(-slen * 0.1, 2.0, depth * 0.45))
		if at.call(4.0):
			_shot("lieu_%s_2_route" % site.get("site_type"))
		return
	if _t < 5.8:
		cam.global_position = car.global_position + car.global_basis.z * -6.0 + Vector3.UP * 2.6
		cam.look_at(car.global_position + Vector3.UP)
		if at.call(5.6):
			_shot("lieu_%s_3_voiture" % site.get("site_type"))
			_log("AUTOTEST stabilité : voiture y=%.2f (départ %.2f), vitesse %.2f m/s" % [car.global_position.y, _ls.get("y0", 0.0), car.linear_velocity.length()])
		return
	if at.call(5.8):
		car.gear_lever.set_notch(2, true)   # D
	# sortie vers la route : vise la voie de droite un peu plus loin
	var fwd: Vector3 = car.global_basis.z
	var info2 := road.sample_road(car.global_position + fwd * 10.0)
	if info2["found"]:
		var target: Vector3 = info2["point"] + info2["right"] * 1.75 + info2["dir"] * 6.0
		var to_t := target - car.global_position
		to_t.y = 0.0
		_steer(clampf(fwd.cross(to_t.normalized()).y * 2.0, -1.0, 1.0))
	car.throttle_input = clampf((25.0 - kmh) * 0.15, 0.0, 1.0)
	car.brake_input = 0.0
	_cabin_cam(Vector3(0.0, 3.2, -8.0), Vector3(0.0, 1.0, 12.0))
	var here := road.sample_road(car.global_position)
	var lat: float = absf(float(here["lateral"])) if here["found"] else -1.0
	_ls["vmax"] = maxf(_ls.get("vmax", 0.0), kmh)
	if lat >= 0.0 and lat < 3.0 and not _ls.has("t_road"):
		_ls["t_road"] = _t
		_log("AUTOTEST sur la route après %.1f s (écart à l'axe %.1f m, %.0f km/h)" % [_t - 5.8, lat, kmh])
	if at.call(9.0):
		_shot("lieu_%s_4_sortie" % site.get("site_type"))
	if at.call(16.0):
		_shot("lieu_%s_5_route" % site.get("site_type"))
		_log("AUTOTEST fin : écart à l'axe %.1f m, vmax %.0f km/h, route atteinte=%s" % [lat, _ls["vmax"], _ls.has("t_road")])
		get_tree().quit()


# --- Police : bas-côté, barrage, derrière ; on la sème, puis on se fait prendre ----

var _pv := {"phase": 0, "lat": 1.75, "v": 100.0}
var _pol: Pursuer


func _pol_log(msg: String) -> void:
	_log("AUTOTEST [%.1f s] %s" % [_t, msg])


func _run_autotest_police(delta: float) -> void:
	var road: RoadGenerator = $RoadGenerator
	road.get_node("Animals").set("enabled", false)
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	$Weather.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	_inside = false
	var kmh: float = car.forward_speed * 3.6
	if at.call(0.05):
		$Weather.hour = 15.0
		$Weather.set_weather("degage", true)
		car.handbrake_lever.set_angle_deg(0.0, true)
		car.gear_lever.set_notch(2, true)
		_pol = Pursuer.new()
		_pol.name = "Pursuer"
		_pol.road_path = NodePath("../RoadGenerator")
		_pol.car_path = NodePath("../SUV4x4")
		_pol.auto_encounters = false
		# poursuivante lente et vite semée : le test reste court
		_pol.speed_start = 95.0
		_pol.speed_end = 95.0
		_pol.lose_gap = 150.0
		_pol.lose_time = 3.0
		add_child(_pol)
		_pol.chase_started.connect(func(k): _pol_log("poursuite lancée (%s), écart %.0f m, vitesse police %.0f km/h" % [k, _pol.gap, _pol.get_speed_kmh()]); _pv["t_chase"] = _t; _pv["v"] = 160.0; _pv["lat"] = 1.75)
		_pol.lost.connect(func(): _pol_log("SEMÉE (phase %d)" % _pv["phase"]); _pv["t_lost"] = _t)
		_pol.caught.connect(func(): _pol_log("RATTRAPÉ (écart %.1f m)" % _pol.gap); _pv["t_caught"] = _t)
	if at.call(1.0):
		_pol.start_patrols()
		_pol_log("patrouilles : état %d" % _pol.state)
	# conduite : tient la voie demandée à la vitesse demandée
	var fwd: Vector3 = car.global_basis.z
	var info := road.sample_road(car.global_position + fwd * (8.0 + absf(car.forward_speed) * 0.45))
	if info["found"]:
		var target: Vector3 = info["point"] + info["right"] * float(_pv["lat"])
		var to_t := target - car.global_position
		to_t.y = 0.0
		_steer(clampf(fwd.cross(to_t.normalized()).y * 2.2, -1.0, 1.0))
	var v: float = _pv["v"]
	car.throttle_input = 1.0 if v > 155.0 else clampf((v - kmh) * 0.15, 0.0, 1.0)
	car.brake_input = clampf((kmh - v - 4.0) * 0.1, 0.0, 1.0)
	cam.fov = 70.0
	if not _pv.has("cam_set"):
		_cabin_cam(Vector3(0.0, 3.2, -8.0), Vector3(0.0, 1.0, 12.0))
	_pv.erase("cam_set")
	if _pol == null or _t < 1.5:
		return
	var car_s: float = road.sample_road(car.global_position)["s"]
	var ph: int = _pv["phase"]
	if _t > 12.0 and kmh < 5.0 and not _pv.has("blk") and not _pv.has("t_caught"):
		_pv["blk"] = true
		_pv["cam_set"] = true
		cam.global_position = car.global_position + Vector3.UP * 9.0 - fwd * 4.0
		cam.look_at(car.global_position + fwd * 4.0)
		_shot("police_bloque")
		_pol_log("BLOQUÉ : police à %s, voiture à %s" % [_pol.get_car_position(), car.global_position])
	# --- 1 : voiture garée sur le bas-côté
	if ph == 0 and _t > 3.0:
		_pv["phase"] = 1
		_pol_log("bas-côté : %s" % _pol.force_encounter("bord", 200.0))
	if ph == 1:
		if _pol.state == Pursuer.State.WAIT:
			if _pol.gap > -45.0 and not _pv.has("s1a"):
				_pv["s1a"] = true
				_shot("police_1_bascote")
			if _pol.gap > -25.0:
				_pv["cam_set"] = true
				_cabin_cam(Vector3(-2.5, 2.0, 2.0), Vector3(3.0, 0.5, 25.0))
				if not _pv.has("s1b"):
					_pv["s1b"] = true
					_shot("police_1_bascote_proche")
		if _pv.has("t_chase") and _t - float(_pv["t_chase"]) > 2.0 and not _pv.has("s1c"):
			_pv["s1c"] = true
		if _pv.has("t_chase") and _t - float(_pv["t_chase"]) < 6.0:
			_pv["cam_set"] = true
			_cabin_cam(Vector3(0.0, 2.6, 6.0), Vector3(0.0, 1.0, -20.0))
			if _t - float(_pv["t_chase"]) > 1.5 and not _pv.has("s1d"):
				_pv["s1d"] = true
				_shot("police_1_demarre")
		if _pv.has("t_lost"):
			_pv["phase"] = 2
			_pv.erase("t_chase")
			_pv.erase("t_lost")
			_pv["v"] = 100.0
	# --- 2 : barrage
	if ph == 2 and not _pv.has("b_set") and kmh > 90.0:
		_pv["b_set"] = true
		_pol_log("barrage : %s" % _pol.force_encounter("barrage", 230.0))
		_pv["b_info"] = _pol.get_block_info()
		_pol_log("barrage : %s" % [_pv["b_info"]])
	if ph == 2 and _pv.has("b_set"):
		var bi: Array = _pv["b_info"]
		if bi.size() == 4 and not _pv.has("t_chase"):
			var d0: float = float(bi[0]) - car_s
			if d0 < 90.0:
				_pv["v"] = 42.0
			if car_s < float(bi[0]) + 4.0:
				_pv["lat"] = -float(bi[1])
			elif car_s < float(bi[2]) + 4.0:
				_pv["lat"] = -float(bi[3])
			else:
				_pv["lat"] = 1.75
			if d0 < 60.0 and not _pv.has("s2a"):
				_pv["s2a"] = true
				_shot("police_2_barrage")
			if d0 < 35.0 and d0 > -30.0:
				_pv["cam_set"] = true
				cam.global_position = car.global_position + Vector3.UP * 16.0 - fwd * 6.0
				cam.look_at(car.global_position + fwd * 18.0)
				if d0 < 8.0 and not _pv.has("s2b"):
					_pv["s2b"] = true
					_shot("police_2_chicane")
			# choc contre une voiture du barrage ?
			var prev: float = _pv.get("kmh_prev", kmh)
			if prev - kmh > 12.0:
				_pol_log("CHOC dans le barrage : %.0f -> %.0f km/h" % [prev, kmh])
		if _pv.has("t_chase") and _t - float(_pv["t_chase"]) < 5.0:
			_pv["cam_set"] = true
			_cabin_cam(Vector3(0.0, 2.6, 6.0), Vector3(0.0, 1.0, -20.0))
			if _t - float(_pv["t_chase"]) > 2.5 and not _pv.has("s2c"):
				_pv["s2c"] = true
				_shot("police_2_demarre")
		if _pv.has("t_lost"):
			_pv["phase"] = 3
			_pv.erase("t_chase")
			_pv.erase("t_lost")
			_pv["v"] = 100.0
			_pv["t3"] = _t
	_pv["kmh_prev"] = kmh
	# --- 3 : surgit derrière, puis on freine : rattrapé
	if ph == 3:
		if not _pv.has("d_set") and _t - float(_pv["t3"]) > 2.0:
			_pv["d_set"] = true
			_pol_log("derrière : %s" % _pol.force_encounter("derriere"))
			_pv["v"] = 100.0
		if _pv.has("t_chase"):
			var el: float = _t - float(_pv["t_chase"])
			_pv["v"] = 100.0 if el < 14.0 else 0.0
			if fmod(el, 2.0) < delta:
				_pol_log("écart %.0f m, police %.0f km/h, nous %.0f km/h" % [_pol.gap, _pol.get_speed_kmh(), kmh])
			if el > 12.0 and el < 13.0:
				_pv["cam_set"] = true
				_cabin_cam(Vector3(0.0, 2.6, 6.0), Vector3(0.0, 1.0, -20.0))
				if el > 12.8 and not _pv.has("s3"):
					_pv["s3"] = true
					_shot("police_3_derriere")
	if _pv.has("t_caught") and _t - float(_pv["t_caught"]) > 1.5:
		_pol_log("fin : %d poursuites" % _pol.encounters)
		get_tree().quit()
	if fmod(_t, 5.0) < delta:
		_pol_log("phase %d, état %d, écart %.0f m, police %.0f km/h, nous %.0f km/h" % [_pv["phase"], _pol.state, _pol.gap, _pol.get_speed_kmh(), kmh])
	if _t > 200.0:
		_pol_log("ÉCHEC : délai dépassé")
		get_tree().quit()


# --- Manque : montée lente, voix à 45 %, rien pendant l'effet d'une pilule --------

var _cr: Node
var _cr_log := {}


func _run_autotest_craving(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	if at.call(0.05):
		_cr = preload("res://world/pills/pill_addiction.gd").new()
		_cr.set("car_path", NodePath("../SUV4x4"))
		add_child(_cr)
	if _cr == null:
		return
	if at.call(1.0):
		_cr_log["c0"] = _cr.craving
	if at.call(5.0):
		var rate: float = (_cr.craving - float(_cr_log["c0"])) / 4.0
		_log("AUTOTEST manque : départ %.2f, +%.4f/s -> effets visibles (35 %%) après %.0f s, black-out après %.0f s" % [_cr_log["c0"], rate, 0.35 / maxf(rate, 1e-6), 1.0 / maxf(rate, 1e-6)])
		_cr.craving = 0.449
	if at.call(7.0):
		var v: AudioStreamPlayer = _cr.get_node("CravingVoice")
		_log("AUTOTEST voix : dite=%s, en lecture=%s, flux=%s" % [_cr.get("_voice_said"), v.playing, v.stream != null])
		_cr.take_pill()
	if at.call(12.0):
		_log("AUTOTEST 5 s après la pilule (effet en cours) : manque %.3f, voix réarmée=%s" % [_cr.craving, not _cr.get("_voice_said")])
		get_tree().quit()


# --- Zoo : chaque espèce posée à côté de la route, gros plans (modélisation) ------

var _zoo: Array = []


func _run_autotest_zoo(delta: float) -> void:
	var road: RoadGenerator = $RoadGenerator
	var am = road.get_node("Animals")
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	$Weather.random_events = false
	$FallingTrees.enabled = false
	am.enabled = false
	am.crossings_enabled = false
	car.external_input = true
	car.throttle_input = 0.0
	car.brake_input = 1.0
	_inside = false
	if at.call(0.05):
		$Weather.hour = 14.0
		$Weather.set_weather("degage", true)
	if at.call(0.6):
		for a in am.animals:
			a.queue_free()
		var sample: Dictionary = road.sample_ahead(car.global_position, 25.0)
		var list := [["rabbit", false], ["boar", false], ["boar", true], ["deer", false], ["sheep", false], ["sheep", true]]
		for i in list.size():
			var p: Vector3 = road.ground_position(road.sample_ahead(car.global_position, 18.0 + i * 3.2), -6.5)
			var a = am._make(list[i][0], p, list[i][1])
			a.set("heading", PI * 0.5)
			_zoo.append(a)
	if _zoo.is_empty():
		return
	cam.fov = 40.0
	var idx := int((_t - 1.5) / 1.2)
	if _t < 1.5:
		return
	if idx < _zoo.size():
		var a: Node3D = _zoo[idx]
		if not is_instance_valid(a):
			return
		var h: float = float(a.get("size_scale")) * 1.0
		var right: Vector3 = road.sample_road(a.global_position)["right"]
		var dir: Vector3 = road.sample_road(a.global_position)["dir"]
		var dist := 2.2 if idx == 0 else 4.0
		cam.global_position = a.global_position + right * dist * 0.7 + dir * dist * 0.7 + Vector3.UP * (0.5 + dist * 0.2)
		cam.look_at(a.global_position + Vector3.UP * (0.25 if idx == 0 else 0.6))
		if fmod(_t - 1.5, 1.2) > 1.0 and not _zoo[idx].has_meta("shot"):
			_zoo[idx].set_meta("shot", true)
			_shot("zoo_%d_%s" % [idx, a.get("species")])
	elif idx == _zoo.size():
		var mid: Node3D = _zoo[2]
		var right: Vector3 = road.sample_road(mid.global_position)["right"]
		cam.fov = 55.0
		cam.global_position = mid.global_position + right * 9.0 + Vector3.UP * 2.0
		cam.look_at(mid.global_position + Vector3.UP * 0.5)
		if fmod(_t - 1.5, 1.2) > 1.0 and not has_meta("zoo_all"):
			set_meta("zoo_all", true)
			_shot("zoo_tous")
	else:
		get_tree().quit()


# --- Balade : réglages du jeu, on roule 3 min et on compte les animaux croisés ----

var _bl := {"cross0": 0, "seen": {}, "close": {}, "near_road": 0}


func _run_autotest_drive_animals(delta: float) -> void:
	var road: RoadGenerator = $RoadGenerator
	var am = road.get_node("Animals")
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	$Weather.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	_inside = false
	var kmh: float = car.forward_speed * 3.6
	if at.call(0.05):
		$Weather.hour = 15.0
		$Weather.set_weather("degage", true)
		car.handbrake_lever.set_angle_deg(0.0, true)
		car.gear_lever.set_notch(2, true)
	var fwd: Vector3 = car.global_basis.z
	var info := road.sample_road(car.global_position + fwd * (8.0 + absf(car.forward_speed) * 0.45))
	if info["found"]:
		var target: Vector3 = info["point"] + info["right"] * 1.75
		var to_t := target - car.global_position
		to_t.y = 0.0
		_steer(clampf(fwd.cross(to_t.normalized()).y * 2.2, -1.0, 1.0))
	car.throttle_input = clampf((105.0 - kmh) * 0.15, 0.0, 1.0)
	car.brake_input = 0.0
	_cabin_cam(Vector3(0.0, 2.6, -7.0), Vector3(0.0, 1.0, 14.0))
	cam.fov = 70.0
	# animaux vus : à moins de 60 m devant, dans le champ (±40°)
	for a in am.animals:
		if not is_instance_valid(a):
			continue
		var d: Vector3 = a.global_position - car.global_position
		var dist := d.length()
		var id: int = a.get_instance_id()
		if dist < (110.0 if a.crossing else 60.0) and d.normalized().dot(fwd) > 0.75:
			if not _bl["seen"].has(id):
				_bl["seen"][id] = "%s%s" % [a.species, " (traversée)" if a.crossing else ""]
				if a.crossing:
					_log("AUTOTEST [%.0f s] %s qui traverse vu à %.0f m (latéral %.0f)" % [_t, a.species, dist, am.lateral_of(a.global_position)])
		var lat: float = absf(am.lateral_of(a.global_position))
		if a.crossing and dist < 25.0:
			_bl["close"][id] = minf(_bl["close"].get(id, 999.0), car.to_local(a.global_position).x if absf(car.to_local(a.global_position).z) < 3.0 else 999.0)
		if lat < 4.0 and dist < 80.0 and not _bl.has("nr%d" % id):
			_bl["nr%d" % id] = true
			_bl["near_road"] += 1
			if _bl["near_road"] <= 4:
				_pv["dummy"] = 0
	if am.crossings > int(_bl["cross0"]):
		_bl["cross0"] = am.crossings
		var desc := PackedStringArray()
		for a in am.animals:
			if is_instance_valid(a) and a.crossing:
				desc.append("%s à %.0f m (latéral %.0f)" % [a.species, a.global_position.distance_to(car.global_position), am.lateral_of(a.global_position)])
		_log("AUTOTEST [%.0f s, %.0f m] traversée n°%d : %s" % [_t, am.travelled, am.crossings, ", ".join(desc)])
		_bl["shot_t"] = _t + 2.0
	if _bl.has("shot_t") and _t >= float(_bl["shot_t"]):
		_bl.erase("shot_t")
		_shot("balade_traversee_%d" % am.crossings)
	if fmod(_t, 20.0) < delta:
		var amb := 0
		for a in am.animals:
			if is_instance_valid(a) and not a.crossing:
				amb += 1
		_log("AUTOTEST [%.0f s] %.0f m parcourus, %d animaux promeneurs, %d traversées, %d chocs, %d vus de près, %d près de la route" % [_t, am.travelled, amb, am.crossings, am.animals_hit, _bl["seen"].size(), _bl["near_road"]])
	if _t > 180.0:
		var counts := {}
		for id in _bl["seen"]:
			counts[_bl["seen"][id]] = counts.get(_bl["seen"][id], 0) + 1
		_log("AUTOTEST fin : vus à moins de 60 m devant : %s" % counts)
		_log("AUTOTEST écart latéral des animaux qui traversaient au passage de la voiture : %s" % [_bl["close"].values()])
		get_tree().quit()


# --- Klaxon : les animaux assez proches fuient (sans freiner, 60 km/h) ------------

var _ka := {"i": -1}
const KA_TRIALS := [["deer", "proche"], ["sheep", "sur la route"], ["deer", "trop loin puis proche"]]


func _run_autotest_horn_animals(delta: float) -> void:
	var road: RoadGenerator = $RoadGenerator
	var am = road.get_node("Animals")
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	$Weather.random_events = false
	$FallingTrees.enabled = false
	am.enabled = false
	am.crossings_enabled = false
	car.external_input = true
	_inside = false
	var kmh: float = car.forward_speed * 3.6
	if at.call(0.05):
		$Weather.hour = 15.0
		$Weather.set_weather("degage", true)
		car.handbrake_lever.set_angle_deg(0.0, true)
		car.gear_lever.set_notch(2, true)
	var fwd: Vector3 = car.global_basis.z
	var info := road.sample_road(car.global_position + fwd * (8.0 + absf(car.forward_speed) * 0.45))
	if info["found"]:
		var target: Vector3 = info["point"] + info["right"] * 1.75
		var to_t := target - car.global_position
		to_t.y = 0.0
		_steer(clampf(fwd.cross(to_t.normalized()).y * 2.2, -1.0, 1.0))
	car.throttle_input = clampf((60.0 - kmh) * 0.15, 0.0, 1.0)
	car.brake_input = 0.0
	_cabin_cam(Vector3(0.0, 3.0, -6.0), Vector3(0.0, 1.0, 16.0))
	cam.fov = 70.0
	var i: int = _ka["i"]
	if i < 0 and _t > 8.0 and kmh > 55.0:
		i = 0
		_ka["i"] = 0
		_ka_start(am, 0)
	if i < 0 or i >= KA_TRIALS.size():
		return
	var group: Array = _ka["group"]
	var near := 999.0
	var on_road := false
	for a in group:
		if is_instance_valid(a):
			near = minf(near, a.global_position.distance_to(car.global_position))
			if absf(am.lateral_of(a.global_position)) < 2.5:
				on_road = true
	var mode: String = KA_TRIALS[i][1]
	var honk := false
	if mode == "proche":
		honk = near < 55.0 and not _ka.has("honked")
	elif mode == "sur la route":
		honk = on_road and near < 70.0 and not _ka.has("honked")
	else:
		if near > 90.0 and near < 140.0 and not _ka.has("far_done"):
			honk = true
			_ka["far_t"] = _ka.get("far_t", 0.0) + delta
			if _ka["far_t"] > 1.0:
				_ka["far_done"] = true
				var st := PackedStringArray()
				for a in group:
					st.append("état %d%s" % [a.state, " fuit" if a.is_scared() else ""])
				_log("AUTOTEST   klaxon à %.0f m (hors de portée) : %s" % [near, ", ".join(st)])
		elif near < 50.0 and not _ka.has("honked"):
			honk = true
	if honk:
		car.horn.press("test")
		if not _ka.has("honk_start") and near < 90.0:
			_ka["honk_start"] = _t
			_ka["honk_d"] = near
	elif car.horn.is_honking():
		car.horn.unpress("test")
	if _ka.has("honk_start") and _t - float(_ka["honk_start"]) > 0.6 and not _ka.has("honked"):
		_ka["honked"] = true
		car.horn.unpress("test")
	if _ka.has("honk_start") and _t - float(_ka["honk_start"]) > 1.2 and not _ka.has("shot"):
		_ka["shot"] = true
		_shot("klaxon_%d_%s" % [i + 1, KA_TRIALS[i][0]])
	if _ka.has("honk_start") and _t - float(_ka["honk_start"]) > 1.5 and not _ka.has("report"):
		_ka["report"] = true
		var st := PackedStringArray()
		for a in group:
			if is_instance_valid(a):
				st.append("%s côté %.1f m %s" % [a.species, am.lateral_of(a.global_position), "FUIT" if a.state == 3 else "état %d" % a.state])
		_log("AUTOTEST   klaxon à %.0f m : %s" % [_ka["honk_d"], ", ".join(st)])
	if _t - float(_ka["t0"]) > 14.0:
		var hits: int = am.animals_hit - int(_ka["hits0"])
		var st := PackedStringArray()
		for a in group:
			if is_instance_valid(a):
				st.append("côté %.0f m" % am.lateral_of(a.global_position))
		_log("AUTOTEST essai %d (%s, %s) : %s, chocs=%d, après : %s" % [i + 1, KA_TRIALS[i][0], mode, "ÉVITÉ" if hits == 0 else "TOUCHÉ", hits, ", ".join(st)])
		for a in group:
			if is_instance_valid(a):
				a.queue_free()
		_ka["i"] = i + 1
		if i + 1 >= KA_TRIALS.size():
			_log("AUTOTEST klaxon : %d animaux effrayés au total" % am.horn_scares)
			get_tree().quit()
		else:
			_ka_start(am, i + 1)


func _ka_start(am, i: int) -> void:
	for k in ["honked", "honk_start", "honk_d", "shot", "report", "far_done", "far_t"]:
		_ka.erase(k)
	var sp: String = KA_TRIALS[i][0]
	var dist := 160.0 if KA_TRIALS[i][1].begins_with("trop") else 85.0
	_ka["group"] = am.spawn_crossing(sp, dist, 1 if i % 2 == 0 else -1)
	if sp == "sheep":
		_ka["group"] = _ka["group"].slice(0, 4)
	_ka["t0"] = _t
	_ka["hits0"] = am.animals_hit
	_log("AUTOTEST essai %d : %s ×%d à %.0f m (%s)" % [i + 1, sp, (_ka["group"] as Array).size(), dist, KA_TRIALS[i][1]])


# --- Police vue de près (voiture garée et barrage), voiture du joueur à l'arrêt ----

func _run_autotest_police_view(delta: float) -> void:
	var road: RoadGenerator = $RoadGenerator
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	$Weather.random_events = false
	$FallingTrees.enabled = false
	road.get_node("Animals").set("enabled", false)
	car.external_input = true
	car.brake_input = 1.0
	car.throttle_input = 0.0
	_inside = false
	if at.call(0.05):
		$Weather.hour = 14.0
		$Weather.set_weather("degage", true)
		_pol = Pursuer.new()
		_pol.road_path = NodePath("../RoadGenerator")
		_pol.car_path = NodePath("../SUV4x4")
		_pol.auto_encounters = false
		add_child(_pol)
	if at.call(0.5):
		_pol.force_encounter("bord", 25.0)
	if _pol == null or _t < 0.6:
		return
	var p := _pol.get_car_position()
	var sm := road.sample_road(p)
	var right: Vector3 = sm["right"]
	var dir: Vector3 = sm["dir"]
	cam.fov = 50.0
	if _t < 2.0:
		cam.global_position = p - right * 4.5 + dir * 3.0 + Vector3.UP * 1.3
		cam.look_at(p + Vector3.UP * 0.6)
		if at.call(1.8): _shot("police_vue_cote")
	elif _t < 3.0:
		cam.global_position = p - right * 3.0 - dir * 5.0 + Vector3.UP * 1.5
		cam.look_at(p + Vector3.UP * 0.6)
		if at.call(2.8): _shot("police_vue_arriere")
	elif _t < 3.2:
		if at.call(3.05): _pol.force_encounter("barrage", 30.0)
	elif _t < 5.0:
		var bi: Array = _pol.get_block_info()
		cam.global_position = car.global_position + Vector3.UP * 5.0 + car.global_basis.z * 12.0 + car.global_basis.x * 6.0
		cam.look_at(car.global_position + car.global_basis.z * 40.0)
		if at.call(4.8): _shot("police_vue_barrage")
	else:
		get_tree().quit()
