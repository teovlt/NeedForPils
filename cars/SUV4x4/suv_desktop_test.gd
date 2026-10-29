extends Node3D
## Scène de test sans casque : conduite au clavier + caméra.
## V = caméra extérieure / place conducteur, H = simuler une main proche de
## toutes les pièces interactives (pour voir les contours lumineux).
## Le 4x4 démarre ici en D, frein à main desserré (voir SUV4x4 dans la scène).
## Autres touches : voir l'en-tête de suv_4x4.gd.

@export var autotest := false
## Scénario du test automatique : "objets" (rangements) ou "arbres".
@export_enum("objets", "arbres", "aleatoire", "phares", "retros", "portes", "boite", "combine", "essuie", "plafonnier", "nature", "pluie", "balayage", "menu", "lunette", "moteur", "klaxon", "vitres", "ceinture", "cle", "depart", "pare_soleil", "cle_f", "physique", "eclairage", "radio", "radio_nuit", "radio_pwr", "ambiance", "rangements", "ceintures", "vitesses", "sapins", "balises", "playlist", "animaux", "pochette", "lieu", "police", "manque", "zoo", "balade", "klaxon_animaux", "police_vue", "pochette_places", "briquet", "glisser", "mains_bloquees") var autotest_scenario := "objets"

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
		elif autotest_scenario == "pochette_places":
			_run_autotest_bag_places(delta)
		elif autotest_scenario == "briquet":
			_run_autotest_lighter(delta)
		elif autotest_scenario == "fumer":
			_run_autotest_smoke(delta)
		elif autotest_scenario == "fumee_debug":
			_run_autotest_smoke_debug(delta)
		elif autotest_scenario == "fumer_souris":
			_run_autotest_smoke_mouse(delta)
		elif autotest_scenario == "fumer_effets":
			_run_autotest_smoke_effects(delta)
		elif autotest_scenario == "sortie_rangements":
			_run_autotest_take_out(delta)
		elif autotest_scenario == "visee_rangements":
			_run_autotest_pick_in_zones(delta)
		elif autotest_scenario == "vue_accoudoir":
			_run_autotest_console_view(delta)
		elif autotest_scenario == "paquet":
			_run_autotest_cig_pack(delta)
		elif autotest_scenario == "traverser":
			_run_autotest_no_clip(delta)
		elif autotest_scenario == "glisser":
			_run_autotest_slide(delta)
		elif autotest_scenario == "concurrents":
			_run_autotest_rivals(delta)
		elif autotest_scenario == "portee":
			_run_autotest_reach(delta)
		elif autotest_scenario == "thermos":
			_run_autotest_thermos(delta)
		elif autotest_scenario == "fatigue":
			_run_autotest_fatigue(delta)
		elif autotest_scenario == "toucher":
			_run_autotest_touch(delta)
		elif autotest_scenario == "pochette_index":
			_run_autotest_bag_index(delta)
		elif autotest_scenario == "paquet_deux_mains":
			_run_autotest_pack_two_hands(delta)
		elif autotest_scenario == "pochette_deux_mains":
			_run_autotest_bag_two_hands(delta)
		elif autotest_scenario == "mains":
			_run_autotest_hands(delta)
		elif autotest_scenario == "mains_bloquees":
			_run_autotest_hands_stuck(delta)
		elif autotest_scenario == "rouler":
			_run_autotest_roll(delta)
		elif autotest_scenario == "sachet_tabac":
			_run_autotest_pouch_view(delta)
		elif autotest_scenario == "glaciere":
			_run_autotest_cooler(delta)
		elif autotest_scenario == "enceintes":
			_run_autotest_speakers(delta)
		elif autotest_scenario == "sac_a_dos":
			_run_autotest_backpack(delta)
		elif autotest_scenario == "livraison":
			_run_autotest_delivery(delta)
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
	if at.call(2.9):
		_log("AUTOTEST clé approchée, encore tenue : entrée toute seule=%s, tenue pour tourner=%s" % [ign.has_key(), grab.is_grabbed()])
	if at.call(3.1):
		grab.release(_hand)
		_log("AUTOTEST lâchée près du barillet : clé dans le contact=%s" % ign.has_key())
	if at.call(3.8): _shot("cle_2_inseree")
	# tourner le poignet jusqu'à II
	if at.call(4.0):
		_hand.global_transform = Transform3D(ign.global_basis, ign.global_position + (ign.global_basis as Basis).z * 0.04)
		grab.grab(_hand)
	var twist := 0.0
	# (poignet démultiplié : twist_gain = 2, 36° de poignet = 72° de clé)
	if _t > 4.0 and _t <= 4.3: twist = (_t - 4.0) / 0.3 * 36.0
	elif _t > 4.3 and _t <= 5.0: twist = 36.0
	elif _t > 5.0 and _t <= 6.4: twist = 52.0
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
		var cg := _car_item("Cigarette") as RigidBody3D
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
		var wfl: Node3D = car.window_cranks["FL"].window
		_log("AUTOTEST vitre FL : centre %s" % car.to_local((wfl as MeshInstance3D).global_transform * (wfl as MeshInstance3D).get_aabb().get_center()))
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
		var now: Array = r._playlist_now()
		var left: float = r._playlist[now[0]]["length"] - now[1]
		r._pl_started -= left - 1.5
		r._load(r.station)   # les haut-parleurs repartent à la nouvelle position
		_log("AUTOTEST saut à 1,5 s de la fin du morceau")
	if at.call(5.2):
		_log("AUTOTEST avant la fin : " + st.call())
	if at.call(7.5):
		_log("AUTOTEST après la fin (morceau suivant depuis le début, une seule fois) : " + st.call())
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


# --- Pochette rangée dans chaque rangement (gros plans) -----------------------------

const BP_ZONES := [["Storage/Glovebox", Vector3(-0.2, 1.3, 0.2), Vector3(-0.52, 0.86, 0.83)],
	["Storage/Console", Vector3(0.0, 1.45, -0.1), Vector3(0.0, 0.8, 0.2)],
	["Doors/DoorFL/Pocket", Vector3(0.45, 1.45, -0.05), Vector3(0.80, 0.7, 0.5)],
	["Doors/DoorFR/Pocket", Vector3(-0.45, 1.45, -0.05), Vector3(-0.80, 0.7, 0.5)],
	["", Vector3(-0.2, 1.5, -0.4), Vector3(-0.45, 0.85, 0.15)]]


func _run_autotest_bag_places(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	$Weather.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	car.brake_input = 1.0
	_inside = false
	if at.call(0.05):
		$Weather.hour = 13.0
		$Weather.set_weather("degage", true)
		car.get_node("GloveboxLid").set_angle_deg(-80.0, true)
		car.get_node("ConsoleLid").set_angle_deg(-100.0, true)
	var i := int((_t - 1.0) / 1.0)
	if _t < 1.0:
		return
	if i >= BP_ZONES.size():
		get_tree().quit()
		return
	var bag := car.find_child("PillBag", true, false) as RigidBody3D
	var zd: Array = BP_ZONES[i]
	if not has_meta("bp%d" % i):
		set_meta("bp%d" % i, true)
		var z := bag.get_parent() as StorageZone
		if z: z.on_item_taken(bag)
		ItemPhysics.stop(bag)
		var rng := RandomNumberGenerator.new()
		var ok := false
		if zd[0] == "":
			car.get_node("Storage")._place_loose(bag, rng, [])
			ok = true
		else:
			ok = (car.get_node(zd[0]) as StorageZone).try_random_place(bag, rng, [])
		var g := bag.get_node("Grab") as VRPickable
		_log("AUTOTEST pochette -> %s : %s, boîte %s, haut=%s" % [zd[0] if zd[0] != "" else "en vrac", ok, g.get_local_aabb().size, bag.global_basis.y.snapped(Vector3.ONE * 0.01)])
	cam.fov = 55.0
	_cabin_cam(zd[1], zd[2])
	if fmod(_t - 1.0, 1.0) > 0.85 and not has_meta("bps%d" % i):
		set_meta("bps%d" % i, true)
		_shot("pochette_place_%d" % i)


# --- Briquet : rangé au hasard, attrapé, allumé / éteint ---------------------------

func _run_autotest_lighter(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	$Weather.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	car.brake_input = 1.0
	_inside = false
	var lt := car.find_child("Lighter", true, false) as RigidBody3D
	if at.call(0.05):
		$Weather.hour = 21.5   # nuit : on voit la lumière de la flamme
		$Weather.set_weather("degage", true)
	if at.call(0.5):
		var where := PackedStringArray()
		for i in 8:
			car.get_node("Storage").randomize_items()
			var z := lt.get_parent()
			where.append(str(z.get("zone_name")) if z.get("zone_name") else "en vrac")
		_log("AUTOTEST briquet rangé (8 tirages) : %s ; boîte %s" % [", ".join(where), (lt.get_node("Grab") as VRPickable).get_local_aabb().size])
		_shot("briquet_0_range")
	if at.call(1.5):
		if _hand == null:
			_hand = Node3D.new()
			add_child(_hand)
		_held = lt.get_node("Grab")
		_hand.global_transform = Transform3D(car.global_basis, lt.global_position)
		_held.grab(_hand)
		_log("AUTOTEST briquet attrapé=%s" % _held.is_grabbed())
	if _t > 1.5 and _t < 5.0 and _held:
		_hand.global_transform = Transform3D(car.global_basis, car.to_global(Vector3(-0.45, 1.15, 0.1)))
		_held._on_grab_update(_hand)
	var g := lt.get_node("Grab") as Lighter
	if at.call(2.2):
		g.toggle()
		_log("AUTOTEST F -> allumé=%s, flamme visible=%s" % [g.lit, g._flame.visible if g._flame else null])
	if _t > 1.6 and _t < 4.8:
		cam.fov = 45.0
		cam.global_position = lt.global_position + car.global_basis * Vector3(0.12, 0.08, -0.2)
		cam.look_at(lt.global_position + car.global_basis.y * 0.06)
	if at.call(3.0):
		_shot("briquet_1_allume")
		_log("AUTOTEST briquet en main : local voiture %s, main %s, caméra %s" % [car.to_local(lt.global_position), car.to_local(_hand.global_position), car.to_local(cam.global_position)])
	if at.call(3.5):
		g.toggle()
		_log("AUTOTEST F -> allumé=%s" % g.lit)
		g.toggle()
	if at.call(4.2):
		_release_item()
		_log("AUTOTEST lâché -> allumé=%s, posé dans %s" % [g.lit, lt.get_parent().name])
	if at.call(5.5):
		get_tree().quit()


# --- Fumer : cigarette allumée au briquet (deux mains VR), bouffées à la bouche,
# joint allumé et fumé avec F (sans casque), cigarette fumée jusqu'au filtre ----------

var _sm := {}


func _sm_hand(key: String) -> Node3D:
	if not _sm.has(key):
		var h := Node3D.new()
		add_child(h)
		_sm[key] = h
	return _sm[key]


## Tient l'objet `g` (déjà attrapé par `h`) pour que son point local `local_pt` soit en `p`.
func _sm_hold(h: Node3D, g: VRPickable, basis: Basis, local_pt: Vector3, p: Vector3) -> void:
	h.global_transform = Transform3D(basis, p - basis * local_pt)
	g._on_grab_update(h)


func _run_autotest_smoke(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	$Weather.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	car.brake_input = 1.0
	_inside = false
	var lt := car.find_child("Lighter", true, false) as RigidBody3D
	var cig := _car_item("Cigarette") as RigidBody3D
	var jt := car.find_child("Joint", true, false) as RigidBody3D
	var gl := lt.get_node("Grab") as Lighter
	var gc := cig.get_node("Grab") as Smokable
	var gj := jt.get_node("Grab") as Smokable
	var hA := _sm_hand("A")
	var hB := _sm_hand("B")
	# caméra = tête du conducteur (la bouche en dépend)
	cam.fov = 70.0
	cam.global_position = car.to_global(Vector3(-0.36, 1.25, -0.12))
	cam.look_at(car.to_global(Vector3(-0.36, 1.18, 1.0)))
	var fwd := -cam.global_basis.z
	var flat := Basis.looking_at(car.global_basis.x, car.global_basis.y)   # objet couché, +X vers la gauche voiture
	if at.call(0.05):
		$Weather.hour = 21.5
		$Weather.set_weather("degage", true)
	if at.call(0.4):
		for b in [[hA, gl, lt], [hB, gc, cig]]:
			(b[0] as Node3D).global_transform = (b[2] as Node3D).global_transform
			(b[1] as VRPickable).grab(b[0])
		gl.toggle()
		_log("AUTOTEST briquet allumé=%s, cigarette tenue=%s allumée=%s" % [gl.lit, gc.is_grabbed(), gc.lit])
	var lpos := car.to_global(Vector3(-0.30, 1.05, 0.30))
	var up_basis := Basis(car.global_basis.x, car.global_basis.y, car.global_basis.z)
	if _t > 0.4 and _t < 3.6:
		_sm_hold(hA, gl, up_basis, Vector3.ZERO, lpos)
		# la cigarette approche le briquet, puis le bout dans la flamme à partir de 1,2 s
		var tip_target := gl.flame_position() + (Vector3.ZERO if _t > 1.2 else car.global_basis.x * 0.08)
		var cb := Basis(fwd.cross(Vector3.UP).normalized() * -1.0, Vector3.UP, fwd.cross(Vector3.UP).normalized() * -1.0).orthonormalized()
		cb = Basis.looking_at(-car.global_basis.x, Vector3.UP) * Basis(Vector3.UP, -PI * 0.5)
		_sm_hold(hB, gc, cb, Vector3(gc.tip_x, 0, 0), tip_target)
		if gc.lit and not _sm.has("lit_t"):
			_sm["lit_t"] = _t
			_log("AUTOTEST cigarette allumée au briquet après %.1f s dans la flamme" % (_t - 1.2))
	if at.call(2.4):
		_shot("fumer_1_allumage")
	if at.call(3.6):
		gl.toggle()
		gl.release(hA)
		_log("AUTOTEST briquet éteint et lâché ; cigarette allumée=%s" % gc.lit)
	# bouffée de 3 s : filtre à la bouche
	var mouth: Vector3 = EdiblePickable.mouth_position(get_tree())
	var mb := Basis.looking_at(-fwd, Vector3.UP) * Basis(Vector3.UP, -PI * 0.5)   # +X de l'objet vers l'avant
	if _t > 3.8 and _t < 6.8:
		if not _sm.has("b0"):
			_sm["b0"] = gc.burnt
		_sm_hold(hB, gc, mb, Vector3(gc.butt_x, 0, 0), mouth)
	if _t >= 6.8 and _t < 8.5:
		_sm_hold(hB, gc, mb, Vector3(gc.butt_x, 0, 0), mouth + fwd * 0.25 - cam.global_basis.y * 0.15)
	if at.call(6.8):
		_log("AUTOTEST bouffée de 3 s : papier consumé %.1f mm -> %.1f mm (sur %.0f mm)" % [_sm["b0"] * 1000.0, gc.burnt * 1000.0, (gc.paper_length() - gc.stub) * 1000.0])
	if at.call(7.2):
		_shot("fumer_2_recrache")
		_log("AUTOTEST bouffées=%d, fumée recrachée=%s" % [gc.puffs, gc._exhale.emitting if gc._exhale else null])
	if at.call(8.5):
		_log("AUTOTEST   (avant de lâcher : cigarette en %s, main en %s)" % [car.to_local(cig.global_position), car.to_local(hB.global_position)])
		gc.release(hB)
		_log("AUTOTEST cigarette posée, toujours allumée=%s, parent %s" % [gc.lit, cig.get_parent().name])
	# joint : sans casque, F l'allume avec le briquet de la voiture, F = une bouffée
	if at.call(9.0):
		hB.global_transform = jt.global_transform
		gj.grab(hB)
		gj.toggle()
		_log("AUTOTEST joint tenu, F -> allumé=%s" % gj.lit)
	if _t > 9.0 and _t < 12.5:
		_sm_hold(hB, gj, mb, Vector3(gj.butt_x, 0, 0), mouth + fwd * 0.3 - cam.global_basis.y * 0.12)
	if at.call(9.6):
		_sm["j0"] = gj.burnt
		gj.toggle()
	if at.call(11.5):
		_log("AUTOTEST joint F -> bouffée : consumé %.1f -> %.1f mm, bouffées=%d" % [_sm["j0"] * 1000.0, gj.burnt * 1000.0, gj.puffs])
		_shot("fumer_3_joint")
	if at.call(12.5):
		gj.release(hB)
		# cigarette fumée jusqu'au bout (bouffées accélérées)
		hB.global_transform = cig.global_transform
		gc.grab(hB)
		gc.puff_time = 1.5
	if _t > 12.6 and _t < 15.0:
		_sm_hold(hB, gc, mb, Vector3(gc.butt_x, 0, 0), mouth)
	if at.call(15.0):
		_log("AUTOTEST jusqu'au bout : éteinte=%s, mégot=%s, reste %.1f mm de papier" % [not gc.lit, gc.burnt_out, (gc.paper_length() - gc.burnt) * 1000.0])
		gc.toggle()
		_log("AUTOTEST F sur le mégot -> allumé=%s" % gc.lit)
		gc.release(hB)
	if at.call(15.5):
		get_tree().quit()


func _run_autotest_smoke_debug(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	car.external_input = true
	car.brake_input = 1.0
	_inside = false
	cam.global_position = car.to_global(Vector3(0, 3, -6))
	cam.look_at(car.to_global(Vector3(0, 1.5, 3)))
	if at.call(0.05):
		$Weather.hour = 13.0
		var gc := _car_item("Cigarette").get_node("Grab") as Smokable
		for i in 3:
			var p: CPUParticles3D = gc._make_smoke(30, 3.0, 0.2, 0.8)
			p.direction = Vector3.UP
			p.initial_velocity_min = 0.3
			p.initial_velocity_max = 0.5
			add_child(p)
			p.global_position = car.to_global(Vector3(-1.5 + i * 1.5, 2.0, 2.0))
			var m := (p.mesh as QuadMesh).material as StandardMaterial3D
			if i == 1:
				m.vertex_color_use_as_albedo = false
				m.albedo_color = Color(0.8, 0.8, 0.8, 0.5)
			elif i == 2:
				m.albedo_texture = null
			p.emitting = true
	if at.call(2.5):
		_shot("fumee_debug")
		get_tree().quit()


# --- Souris (sans casque) : la touche F agit sur l'objet tenu --------------------

func _run_autotest_smoke_mouse(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	car.external_input = true
	car.brake_input = 1.0
	_inside = true
	var gl := car.find_child("Lighter", true, false).get_node("Grab") as Lighter
	var gc := _car_item("Cigarette").get_node("Grab") as Smokable
	if at.call(0.5):
		_mouse_hand.held = gl
		gl.grab(_mouse_hand)
		_mouse_hand._toggle()
		_log("AUTOTEST souris : briquet tenu, F -> allumé=%s" % gl.lit)
		_mouse_hand._release()
		_log("AUTOTEST briquet lâché -> allumé=%s" % gl.lit)
	if at.call(1.0):
		_mouse_hand.held = gc
		gc.grab(_mouse_hand)
		_mouse_hand._toggle()
		_log("AUTOTEST souris : cigarette tenue, F -> allumée=%s" % gc.lit)
		_sm["b0"] = gc.burnt
		_mouse_hand._toggle()
	if at.call(3.0):
		_log("AUTOTEST F -> bouffée : consumé %.1f -> %.1f mm, bouffées=%d" % [_sm["b0"] * 1000.0, gc.burnt * 1000.0, gc.puffs])
		get_tree().quit()


# --- Effets : cigarette = moins de manque ; joint = moins de manque + défonce --------

var _se := {}


func _run_autotest_smoke_effects(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	car.external_input = true
	car.brake_input = 1.0
	_inside = true
	var gc := _car_item("Cigarette").get_node("Grab") as Smokable
	var gj := car.find_child("Joint", true, false).get_node("Grab") as Smokable
	if at.call(0.05):
		$Weather.hour = 15.0
		$Weather.set_weather("degage", true)
		var add = preload("res://world/pills/pill_addiction.gd").new()
		add.set("car_path", NodePath("../SUV4x4"))
		add_child(add)
		_se["add"] = add
	var add = _se.get("add")
	if add == null:
		return
	if at.call(0.6):
		add.craving = 0.7
		_mouse_hand.held = gc
		gc.grab(_mouse_hand)
		_mouse_hand._toggle()
		_se["c0"] = add.craving
	# 4 bouffées de cigarette (≈ la moitié)
	for k in 4:
		if at.call(1.0 + k * 1.6):
			_mouse_hand._toggle()
	if at.call(7.6):
		_log("AUTOTEST cigarette : %d bouffées, manque %.2f -> %.2f, défonce %.2f, consumée %.0f %%" % [gc.puffs, _se["c0"], add.craving, add.stoned, gc.burnt / (gc.paper_length() - gc.stub) * 100.0])
		_mouse_hand._release()
		add.craving = 0.7
		_mouse_hand.held = gj
		gj.grab(_mouse_hand)
		_mouse_hand._toggle()
		_se["j0"] = add.craving
	for k in 6:
		if at.call(8.0 + k * 1.6):
			_mouse_hand._toggle()
	if at.call(17.8):
		_log("AUTOTEST joint : %d bouffées, manque %.2f -> %.2f, défonce %.2f, consumé %.0f %%" % [gj.puffs, _se["j0"], add.craving, add.stoned, gj.burnt / (gj.paper_length() - gj.stub) * 100.0])
		_log("AUTOTEST voiture : vitesse max x%.2f, couple x%.2f, retard du volant %.2f" % [car.drug_speed_mult, car.drug_torque_mult, car.drug_steer_lag])
		var lp := -1.0
		for i in AudioServer.get_bus_effect_count(0):
			var e := AudioServer.get_bus_effect(0, i)
			if e is AudioEffectLowPassFilter:
				lp = (e as AudioEffectLowPassFilter).cutoff_hz
		_log("AUTOTEST son étouffé : passe-bas %.0f Hz" % lp)
		_shot("fumer_effets_vue")
		# objet tenu : retard derrière la main
		_se["hand0"] = _mouse_hand.global_position
	if _t > 17.8 and _t < 18.6:
		_mouse_hand.global_position = _se["hand0"] + car.global_basis.x * 0.25 * minf((_t - 17.8) / 0.1, 1.0)
		gj._on_grab_update(_mouse_hand)
	if at.call(18.0):
		var want: Vector3 = (_mouse_hand.global_transform * gj._offset).origin
		_log("AUTOTEST main déplacée de 25 cm : le joint suit avec %.1f cm de retard après 0,2 s" % [gj.item.global_position.distance_to(want) * 100.0])
	if at.call(18.7):
		_mouse_hand._release()
		_mouse_hand.hovered = gc
		_mouse_hand._try_grab()
		_log("AUTOTEST saisie défoncé : tout de suite tenu=%s, en attente=%s (%.2f s)" % [_mouse_hand.held != null, _mouse_hand._pending != null, _mouse_hand._pending_t])
		get_tree().quit()


# --- Sortir un objet de la boîte à gants et de l'accoudoir ouverts (souris réelle) ----

var _to := {}


func _run_autotest_take_out(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	car.external_input = true
	car.brake_input = 1.0
	_inside = true
	var zones := ["Storage/Glovebox", "Storage/Console"]
	if at.call(0.05):
		$Weather.hour = 14.0
		car.get_node("GloveboxLid").set_angle_deg(-80.0, true)
		car.get_node("ConsoleLid").set_angle_deg(-100.0, true)
	var i := int((_t - 0.5) / 3.0)
	if _t < 0.5 or i >= zones.size():
		if _t > 0.5 + 3.0 * zones.size():
			get_tree().quit()
		return
	var zone := car.get_node(zones[i]) as StorageZone
	var ph := fmod(_t - 0.5, 3.0)
	var key := "z%d" % i
	if not _to.has(key):
		_to[key] = true
		var it := car.find_child("Phone", true, false) as RigidBody3D
		var z0 := it.get_parent() as StorageZone
		if z0: z0.on_item_taken(it)
		ItemPhysics.stop(it)
		zone.try_random_place(it, RandomNumberGenerator.new(), [])
		_to["item"] = it
	var item: RigidBody3D = _to["item"]
	# vise l'objet depuis la tête du conducteur (rayon souris au centre)
	var head := car.driver_seat.global_position + car.global_basis.y * 0.62
	if ph < 1.0:
		_mouse_hand._yaw = 0.0
		_mouse_hand._pitch = 0.0
		var dirv := (item.global_position - car.driver_seat.global_position).normalized()
		var lb := car.driver_seat.global_basis.inverse() * dirv
		_mouse_hand._yaw = atan2(-lb.x, -lb.z)
		_mouse_hand._pitch = asin(clampf(lb.y, -1.0, 1.0))
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if at.call(0.5 + i * 3.0 + 0.7):
		_shot("sortie_%d_vise" % i)
	if at.call(0.5 + i * 3.0 + 0.8):
		var hv = _mouse_hand.hovered
		_log("AUTOTEST %s : visé = %s (objet %s, accessible=%s, attrapable=%s)" % [zone.zone_name, hv.item.name if hv and "item" in hv and hv.item else (hv.get_parent().name + "/" + hv.name if hv else "rien"), item.name, zone.is_accessible(), (item.get_node("Grab") as VRPickable).enabled])
		_mouse_hand._try_grab()
		_log("AUTOTEST   clic -> tenu = %s" % [_mouse_hand.held.get_parent().name if _mouse_hand.held else "rien"])
	if ph > 1.0 and ph < 2.0 and _mouse_hand.held:
		# on ramène l'objet vers soi (molette) et on regarde le siège passager
		_mouse_hand._depth = maxf(_mouse_hand._depth - delta * 0.4, 0.3)
		_mouse_hand._pitch = lerpf(_mouse_hand._pitch, -0.3, delta * 2.0)
	if at.call(0.5 + i * 3.0 + 2.0):
		_log("AUTOTEST   objet tenu à %.2f m de la zone" % item.global_position.distance_to(zone.global_position))
		_mouse_hand._release()
	if at.call(0.5 + i * 3.0 + 2.8):
		_log("AUTOTEST   lâché -> parent %s, à %.2f m de la zone" % [item.get_parent().name, item.global_position.distance_to(zone.global_position)])


## Pour chaque objet des rangements ouverts : ce que choisit une main VR posée dessus,
## et ce que choisit le rayon de la souris depuis la tête du conducteur / du passager.
func _run_autotest_pick_in_zones(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	car.external_input = true
	car.brake_input = 1.0
	if at.call(0.05):
		car.get_node("GloveboxLid").set_angle_deg(-80.0, true)
		car.get_node("ConsoleLid").set_angle_deg(-100.0, true)
	_vp_drag(delta)
	if at.call(0.5):
		var rng := RandomNumberGenerator.new()
		var plan := {"Phone": "Storage/Glovebox", "Lighter": "Storage/Glovebox", "Joint": "Storage/Console", "Cigarette": "Storage/Console"}
		for n in plan:
			var it := car.find_child(n, true, false) as RigidBody3D
			var z0 := it.get_parent() as StorageZone
			if z0: z0.on_item_taken(it)
			ItemPhysics.stop(it)
			(car.get_node(plan[n]) as StorageZone).try_random_place(it, rng, [])
	if not at.call(1.0):
		return
	var heads := {"conducteur": car.to_global(Vector3(0.36, 1.25, -0.1)), "passager": car.to_global(Vector3(-0.36, 1.25, -0.1))}
	for zp in ["Storage/Glovebox", "Storage/Console"]:
		var zone := car.get_node(zp) as StorageZone
		for c in zone.get_children():
			if not c is RigidBody3D:
				continue
			var item := c as RigidBody3D
			var p := item.global_position + car.global_basis.y * 0.01
			# main VR (même calcul que VRHandInteractor)
			var best: VRInteractable = null
			var best_d := INF
			for n in get_tree().get_nodes_in_group(VRInteractable.GROUP):
				var it := n as VRInteractable
				if it == null or not it.enabled or not it.is_visible_in_tree():
					continue
				var d := it.get_distance_to(p)
				if d < it.highlight_distance and d - it.get_pick_bonus() < best_d - (best.get_pick_bonus() if best else 0.0):
					best = it
					best_d = d
			var res := "main VR -> %s (%.3f)" % [_itname(best), best_d]
			var aim_ok := 0
			var aim_n := 0
			var aim_bad := {}
			for hk in 10:
				var hn: String = heads.keys()[hk / 5]
				var k := hk % 5
				var o: Vector3 = heads[hn]
				var gb := (item.get_node("Grab") as VRPickable).get_local_aabb()
				var lp := gb.get_center() + gb.size * Vector3((k % 3 - 1) * 0.35, 0.3, (k / 3 - 0.5) * 0.5)
				var dir := (item.global_transform * lp - o).normalized()
				var b2: VRInteractable = null
				var bt := INF
				for n in get_tree().get_nodes_in_group(VRInteractable.GROUP):
					var it := n as VRInteractable
					if it == null or not it.enabled or not it.is_visible_in_tree():
						continue
					var tt := it.ray_hit_distance(o, dir, 1.6, it.grab_distance * 0.3)
					if tt < INF:
						var tp := it.ray_hit_precise(o, dir, 1.6)
						tt = tp if tp < INF else tt + 1.0
					if tt - it.get_pick_bonus() * 3.0 < bt - (b2.get_pick_bonus() * 3.0 if b2 else 0.0):
						b2 = it
						bt = tt
				aim_n += 1
				var nm := _itname(b2) if bt < INF else "rien"
				if k == 0 and nm != item.name:
					var ig := item.get_node("Grab") as VRInteractable
					var it_box := ig.ray_hit_distance(o, dir, 1.6, ig.grab_distance * 0.3)
					var it_pre := ig.ray_hit_precise(o, dir, 1.6)
					var wb := b2.ray_hit_distance(o, dir, 1.6, b2.grab_distance * 0.3)
					var wp := b2.ray_hit_precise(o, dir, 1.6)
					_log("AUTOTEST   %s %s : objet boîte %.3f précis %.3f bonus %.3f ; %s boîte %.3f précis %.3f bonus %.3f" % [hn, item.name, it_box, it_pre, ig.get_pick_bonus(), nm, wb, wp, b2.get_pick_bonus()])
				if nm == item.name:
					aim_ok += 1
				else:
					aim_bad[nm] = aim_bad.get(nm, 0) + 1
			res += " ; souris : %d/%d visées justes %s" % [aim_ok, aim_n, aim_bad]
			_log("AUTOTEST %s / %s : %s" % [zone.zone_name, item.name, res])
	_vp_items = []
	for zp in ["Storage/Glovebox", "Storage/Console"]:
		for c in car.get_node(zp).get_children():
			if c is RigidBody3D:
				_vp_items.append(c)
	_vp_t = _t


var _vp_items: Array = []
var _vp_t := -1.0
var _vp_hand: Node3D


func _vp_drag(delta: float) -> void:
	# chaque objet : main posée dessus, saisie, sortie de 40 cm vers le haut et l'arrière
	# en 1 s, lâchée au-dessus du siège passager
	if _vp_t < 0.0:
		return
	var i := int((_t - _vp_t) / 2.0)
	if i >= _vp_items.size():
		get_tree().quit()
		return
	var item: RigidBody3D = _vp_items[i]
	var g := item.get_node("Grab") as VRPickable
	var ph := fmod(_t - _vp_t, 2.0)
	if _vp_hand == null:
		_vp_hand = Node3D.new()
		add_child(_vp_hand)
	if not item.has_meta("vp0"):
		item.set_meta("vp0", item.global_position)
		_vp_hand.global_transform = item.global_transform
		g.grab(_vp_hand)
		_log("AUTOTEST [drag] %s saisi=%s (zone %s)" % [item.name, g.is_grabbed(), item.get_parent().name])
	var p0: Vector3 = item.get_meta("vp0")
	var target := car.to_global(Vector3(-0.42, 1.0, -0.05))
	if ph < 1.2 and g.is_grabbed():
		_vp_hand.global_position = p0.lerp(target, clampf(ph / 1.0, 0.0, 1.0))
		g.grab_update(_vp_hand)
	if ph >= 1.2 and g.is_grabbed():
		_log("AUTOTEST [drag]   tenu à %.2f m du départ (main à %.2f m)" % [item.global_position.distance_to(p0), _vp_hand.global_position.distance_to(p0)])
		g.release(_vp_hand)
	if ph > 1.9 and not item.has_meta("vp1"):
		item.set_meta("vp1", true)
		_log("AUTOTEST [drag]   lâché -> parent %s, à %.2f m du départ" % [item.get_parent().name, item.global_position.distance_to(p0)])


func _itname(it) -> String:
	if it == null:
		return "rien"
	if "item" in it and it.item:
		return it.item.name
	return "%s/%s" % [it.get_parent().name, it.name]


func _run_autotest_console_view(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	car.external_input = true
	car.brake_input = 1.0
	_inside = false
	if at.call(0.05):
		$Weather.hour = 13.0
		car.get_node("GloveboxLid").set_angle_deg(-80.0, true)
		car.get_node("ConsoleLid").set_angle_deg(-100.0, true)
		var z := car.get_node("Storage/Console") as StorageZone
		var it := car.find_child("Phone", true, false) as RigidBody3D
		var z0 := it.get_parent() as StorageZone
		if z0: z0.on_item_taken(it)
		ItemPhysics.stop(it)
		z.try_random_place(it, RandomNumberGenerator.new(), [])
	cam.fov = 60.0
	if _t < 1.5:
		_cabin_cam(Vector3(0.0, 1.55, 0.05), Vector3(0.0, 0.6, 0.06))
		if at.call(1.2):
			_shot("accoudoir_dessus")
	elif _t < 3.0:
		_cabin_cam(Vector3(0.36, 1.25, -0.12), Vector3(0.0, 0.7, 0.1))
		if at.call(2.7):
			_shot("accoudoir_conducteur")
	else:
		for c in car.get_node("Storage/Console").get_children():
			if c is RigidBody3D:
				_log("AUTOTEST accoudoir : %s à %s (local voiture)" % [c.name, car.to_local(c.global_position)])
		var hb := car.get_node("Handbrake")
		_log("AUTOTEST frein à main : %s" % car.to_local(hb.global_position))
		get_tree().quit()


# --- Paquet de cigarettes : toujours dans la voiture (endroit et nombre aléatoires),
# ouverture, cigarette sortie à la souris, allumée et fumée ; briquet toujours présent --

var _cp := {}


func _run_autotest_cig_pack(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	car.external_input = true
	car.brake_input = 1.0
	_inside = false
	var pack_body := car.find_child("CigarettePack", true, false) as RigidBody3D
	var pack := pack_body.get_node("Grab") as CigarettePack
	var lt := car.find_child("Lighter", true, false) as RigidBody3D
	if at.call(0.05):
		$Weather.hour = 14.0
		car.get_node("GloveboxLid").set_angle_deg(-80.0, true)
		car.get_node("ConsoleLid").set_angle_deg(-100.0, true)
	if at.call(0.6):
		var cabin: AABB = car.get_node("Storage").cabin
		var wp := {}
		var wl := {}
		var inside := 0
		for i in 30:
			car.get_node("Storage").randomize_items()
			for pair in [[pack_body, wp], [lt, wl]]:
				var b: RigidBody3D = pair[0]
				var z := b.get_parent()
				var nm := str(z.get("zone_name")) if z.get("zone_name") else "en vrac"
				pair[1][nm] = pair[1].get(nm, 0) + 1
				var lpos := car.to_local(b.global_position)
				if cabin.grow(0.05).has_point(lpos) and b.visible:
					inside += 1
		_log("AUTOTEST 30 tirages : paquet %s ; briquet %s ; dans l'habitacle %d/60" % [wp, wl, inside])
		var counts := {}
		for i in 200:
			var n := randi_range(pack.count_range.x, pack.count_range.y)
			counts[n] = true
		_log("AUTOTEST paquet : %d cigarettes (bornes %s), boîte %s" % [pack.cigarette_count, pack.count_range, pack.get_local_aabb().size])
		# paquet posé sur le siège passager pour la suite
		car.get_node("Storage")._place_loose(pack_body, RandomNumberGenerator.new(), [])
	var view_p := pack_body.global_position + car.global_basis.y * 0.05
	if _t > 0.7 and _t < 6.0:
		cam.global_position = view_p + car.global_basis * Vector3(0.12, 0.22, 0.18)
		cam.look_at(view_p)
		cam.fov = 45.0
	if at.call(1.2):
		_shot("paquet_1_ferme")
		_mouse_hand.hovered = pack
		_mouse_hand._toggle()
		_cp["n0"] = pack.cigarettes_left()
		_log("AUTOTEST F en visant le paquet -> ouvert=%s, cigarettes=%d, zone cigarettes active=%s" % [pack.open, pack.cigarettes_left(), pack._taker.enabled])
	if at.call(1.8):
		_shot("paquet_2_ouvert")
		# visée souris sur le dessus du paquet ouvert
		var o := cam.global_position
		var target := pack_body.global_transform * Vector3(0, CigarettePack.SIZE.y - CigarettePack.LID_H + 0.015, 0)
		var dir := (target - o).normalized()
		var bp := pack.ray_hit_distance(o, dir, 2.0, 0.0)
		var bt := pack._taker.ray_hit_distance(o, dir, 2.0, pack._taker.grab_distance * 0.3)
		_log("AUTOTEST visée sur les cigarettes : paquet %s, cigarettes %.3f" % [bp, bt])
		_mouse_hand.hovered = pack._taker
		_mouse_hand._try_grab()
		var held = _mouse_hand.held
		_log("AUTOTEST clic -> tenu %s ; cigarettes restantes %d (avant %d)" % [held.name if held else "rien", pack.cigarettes_left(), _cp["n0"]])
	if _t > 1.8 and _t < 3.5 and _mouse_hand.held:
		_mouse_hand.global_position = view_p + car.global_basis * Vector3(0.0, 0.12 * minf((_t - 1.8) / 0.5, 1.0), 0.05)
		_mouse_hand.held.grab_update(_mouse_hand)
	if at.call(2.6):
		_shot("paquet_3_sortie")
		_mouse_hand._toggle()
		var cig = null
		for c in get_tree().get_nodes_in_group("smokables"):
			if c.is_grabbed():
				cig = c
		_log("AUTOTEST F sur la cigarette sortie -> allumée=%s" % [cig.lit if cig else null])
	if at.call(3.5):
		_mouse_hand._release()
		_mouse_hand.hovered = pack
		_mouse_hand._toggle()
		_log("AUTOTEST paquet refermé : ouvert=%s, zone cigarettes active=%s" % [pack.open, pack._taker.enabled])
	if at.call(4.0):
		get_tree().quit()


# --- Objet tenu : la main passe à travers la voiture, pas l'objet ---------------

var _nc := {}
## [nom, départ, arrivée (repère voiture)] : la main va du départ à l'arrivée en 1 s.
const NC_MOVES := [
	["dossier conducteur", Vector3(0.45, 1.05, 0.25), Vector3(0.45, 1.05, -0.6)],
	["assise passager (vers le bas)", Vector3(-0.45, 1.05, 0.05), Vector3(-0.45, 0.45, 0.05)],
	["tableau de bord", Vector3(-0.3, 1.05, 0.35), Vector3(-0.3, 1.0, 1.3)],
	["console (de côté)", Vector3(0.35, 0.95, 0.1), Vector3(-0.35, 0.95, 0.1)],
	["portière gauche", Vector3(0.5, 1.2, 0.0), Vector3(1.4, 1.2, 0.0)],
	["toit", Vector3(-0.3, 1.3, 0.15), Vector3(-0.3, 2.4, 0.15)],
	["dans la boîte à gants (ouverte)", Vector3(-0.52, 0.9, 0.45), Vector3(-0.52, 0.88, 0.83)],
	["dans l'accoudoir (ouvert)", Vector3(0.0, 1.15, 0.05), Vector3(0.0, 0.68, 0.05)],
	["ressortir de l'accoudoir", Vector3(0.0, 0.68, 0.05), Vector3(0.0, 1.2, 0.05)],
	["haut du pare-brise", Vector3(-0.3, 1.5, 0.2), Vector3(-0.3, 1.75, 1.4)],
	["toit (arrière)", Vector3(0.3, 1.4, -1.2), Vector3(0.3, 2.3, -1.2)],
	["levier de vitesse", Vector3(0.2, 0.89, 0.515), Vector3(-0.25, 0.89, 0.515)],
	["frein à main", Vector3(0.3, 0.87, 0.12), Vector3(0.02, 0.87, 0.12)],
	["tableau de bord côté conducteur", Vector3(0.45, 1.05, 0.3), Vector3(0.45, 1.0, 1.3)],
	["vitre conducteur fermée", Vector3(0.35, 1.3, 0.15), Vector3(1.5, 1.3, 0.15)],
	["vitre conducteur ouverte", Vector3(0.35, 1.3, 0.15), Vector3(1.5, 1.3, 0.15)],
	["portière passager ouverte", Vector3(-0.35, 1.0, 0.15), Vector3(-1.6, 1.0, 0.15)],
]


func _run_autotest_no_clip(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	car.external_input = true
	car.brake_input = 1.0
	_inside = false
	if at.call(0.05):
		car.get_node("GloveboxLid").set_angle_deg(-80.0, true)
		car.get_node("ConsoleLid").set_angle_deg(-100.0, true)
		_nc["hand"] = Node3D.new()
		add_child(_nc["hand"])
	if at.call(0.3):
		for nm in ["GearLever", "Handbrake"]:
			var bb := AABB()
			var first := true
			for mi in car.get_node(nm).find_children("*", "MeshInstance3D", true, false):
				var b: AABB = car.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
				bb = b if first else bb.merge(b)
				first = false
			_log("AUTOTEST %s : boîte %s -> %s" % [nm, bb.position.snapped(Vector3.ONE * 0.01), bb.end.snapped(Vector3.ONE * 0.01)])
	if _t < 0.5:
		return
	var i := int((_t - 0.5) / 1.6)
	if i >= NC_MOVES.size():
		get_tree().quit()
		return
	var mv: Array = NC_MOVES[i]
	var hand: Node3D = _nc["hand"]
	if str(mv[0]) == "vitre conducteur ouverte" and not _nc.has("win"):
		_nc["win"] = true
		car.window_cranks["FL"].set_opening(1.0)
		var wfl: Node3D = car.window_cranks["FL"].window
		_log("AUTOTEST vitre FL : centre %s" % car.to_local((wfl as MeshInstance3D).global_transform * (wfl as MeshInstance3D).get_aabb().get_center()))
	if str(mv[0]) == "portière passager ouverte" and not _nc.has("door"):
		_nc["door"] = true
		car.get_node("Doors/DoorFR").set_angle_deg(65.0, true)
	var ph := fmod(_t - 0.5, 1.6)
	var it := _car_item("Phone")
	if it == null:
		it = _car_item("Thermos")
	var g := it.get_node("Grab") as VRPickable
	if not _nc.has("m%d" % i):
		_nc["m%d" % i] = true
		if g.is_grabbed():
			g.release(hand)
		hand.global_transform = Transform3D(car.global_basis, car.to_global(mv[1]))
		# l'objet part de la main (comme s'il venait d'être attrapé là)
		var z := it.get_parent() as StorageZone
		if z and i != 8: z.on_item_taken(it)
		ItemPhysics.stop(it)
		if i != 8:
			it.global_transform = hand.global_transform
		g.grab(hand)
	if ph <= 1.1:
		hand.global_position = car.to_global((mv[1] as Vector3).lerp(mv[2], clampf(ph / 1.0, 0.0, 1.0)))
		g.grab_update(hand)
	if ph > 1.1 and not _nc.has("r%d" % i):
		_nc["r%d" % i] = true
		var ip := car.to_local(it.global_position)
		var hp := car.to_local(hand.global_position)
		var blk: String = car.get_node("Storage").last_held_blocker
		car.get_node("Storage").last_held_blocker = ""
		_log("AUTOTEST %-32s : main %s, objet arrêté en %s (écart %.2f m) %s" % [mv[0], hp.snapped(Vector3.ONE * 0.01), ip.snapped(Vector3.ONE * 0.01), ip.distance_to(hp), "par " + blk if blk != "" else ""])
		if i == 6 or i == 7:
			g.release(hand)
			_log("AUTOTEST   lâché -> rangé dans %s" % it.get_parent().name)


# --- Glisser : objet tenu poussé contre une surface puis main déplacée de côté ----------
# Il doit glisser le long de la surface (et non rester collé), puis revenir dans la main
# sans se téléporter quand la main ressort dans le vide.

## [nom, départ, enfoncé dans la surface, glissé (toujours enfoncé), ressorti dans le vide]
const SLIDE_MOVES := [
	["tableau de bord", Vector3(-0.3, 1.1, 0.3), Vector3(-0.3, 1.0, 1.0), Vector3(0.15, 1.05, 1.0), Vector3(0.0, 1.2, 0.2)],
	["assise passager", Vector3(-0.45, 1.1, 0.05), Vector3(-0.45, 0.5, 0.05), Vector3(-0.45, 0.5, 0.35), Vector3(-0.4, 1.15, 0.0)],
]
var _sl := {}


func _run_autotest_slide(delta: float) -> void:
	var t0 := _t
	_t += delta
	car.external_input = true
	car.brake_input = 1.0
	_inside = false
	if t0 == 0.0:
		_sl["hand"] = Node3D.new()
		add_child(_sl["hand"])
	if _t < 0.5:
		return
	var i := int((_t - 0.5) / 2.4)
	if i >= SLIDE_MOVES.size():
		get_tree().quit()
		return
	var mv: Array = SLIDE_MOVES[i]
	var hand: Node3D = _sl["hand"]
	var it := _car_item("Phone")
	var g := it.get_node("Grab") as VRPickable
	var ph := fmod(_t - 0.5, 2.4)
	if not _sl.has("m%d" % i):
		_sl["m%d" % i] = true
		if g.is_grabbed():
			g.release(hand)
		hand.global_transform = Transform3D(car.global_basis, car.to_global(mv[1]))
		var z := it.get_parent() as StorageZone
		if z: z.on_item_taken(it)
		ItemPhysics.stop(it)
		it.global_transform = hand.global_transform
		g.grab(hand)
		_sl["prev"] = it.global_position
		_sl["jump"] = 0.0
	# 0-0,6 s : enfoncé ; 0,6-1,4 s : glissé (en tournant un peu le poignet) ; 1,4-1,9 s : ressorti
	var p: Vector3
	var twist := 0.0
	if ph < 0.6:
		p = (mv[1] as Vector3).lerp(mv[2], ph / 0.6)
	elif ph < 1.4:
		var k := (ph - 0.6) / 0.8
		p = (mv[2] as Vector3).lerp(mv[3], k)
		twist = sin(k * PI) * 0.5
	elif ph < 1.9:
		p = (mv[3] as Vector3).lerp(mv[4], (ph - 1.4) / 0.5)
	else:
		p = mv[4]
	if ph < 2.2:
		hand.global_transform = Transform3D(car.global_basis * Basis(Vector3.UP, twist), car.to_global(p))
		g.grab_update(hand)
		var jump: float = it.global_position.distance_to(_sl["prev"])
		if ph > 1.4:
			_sl["jump"] = maxf(_sl["jump"], jump)
		_sl["prev"] = it.global_position
	var log_at := func(x: float) -> bool: return t0 - 0.5 - i * 2.4 < x and ph >= x
	if log_at.call(0.59):
		_sl["pushed"] = car.to_local(it.global_position)
	if log_at.call(1.39):
		var a: Vector3 = _sl["pushed"]
		var b := car.to_local(it.global_position)
		var want: Vector3 = (mv[3] as Vector3) - (mv[2] as Vector3)
		var along := (b - a).dot(want.normalized())
		_log("AUTOTEST glisser %-16s : objet enfoncé %s puis %s ; a glissé de %.2f m sur %.2f m demandés" % [mv[0], a.snapped(Vector3.ONE * 0.01), b.snapped(Vector3.ONE * 0.01), along, want.length()])
	if log_at.call(2.15):
		_log("AUTOTEST glisser %-16s : ressorti, écart main-objet %.3f m, plus grand saut en une image %.3f m" % [mv[0], it.global_position.distance_to(hand.global_position), _sl["jump"]])


## Objet de la voiture (RigidBody3D) par son nom (le modèle du paquet de cigarettes
## contient aussi des nœuds « Cigarette »).
func _car_item(n: String) -> RigidBody3D:
	for c in car.find_children(n, "RigidBody3D", true, false):
		return c
	return null


# --- Concurrents : le camping-car surgit, remonte, tire, colle ; on accélère et on le sème --

var _rv: Rivals
var _rvl := {}


func _run_autotest_rivals(delta: float) -> void:
	var road: RoadGenerator = $RoadGenerator
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	$Weather.random_events = false
	$FallingTrees.enabled = false
	road.get_node("Animals").set("enabled", false)
	car.external_input = true
	_inside = false
	var kmh: float = car.forward_speed * 3.6
	if at.call(0.05):
		$Weather.hour = 16.0
		$Weather.set_weather("degage", true)
		car.handbrake_lever.set_angle_deg(0.0, true)
		car.gear_lever.set_notch(2, true)
		_rv = Rivals.new()
		_rv.road_path = NodePath("../RoadGenerator")
		_rv.car_path = NodePath("../SUV4x4")
		_rv.auto_encounters = false
		_rv.cruise_kmh = 115.0
		_rv.lose_gap = 160.0
		_rv.lose_time = 3.0
		_rv.max_hits = 99
		add_child(_rv)
		_rv.hit.connect(func(n): _log("AUTOTEST [%.1f s] touché %d (écart %.0f m)" % [_t, n, _rv.gap]))
		_rv.lost.connect(func(): _log("AUTOTEST [%.1f s] SEMÉS (impacts %d, vitesse 4x4 %.0f km/h)" % [_t, _rv.hits, car.forward_speed * 3.6]); _rvl["lost"] = _t)
	if _rv == null:
		return
	# conduite : voie de droite ; 95 km/h (il nous rattrape), puis pied au plancher
	var fwd: Vector3 = car.global_basis.z
	var info := road.sample_road(car.global_position + fwd * (8.0 + absf(car.forward_speed) * 0.45))
	if info["found"]:
		var target: Vector3 = info["point"] + info["right"] * 1.75
		var to_t := target - car.global_position
		to_t.y = 0.0
		_steer(clampf(fwd.cross(to_t.normalized()).y * 2.2, -1.0, 1.0))
	var full := _t > 42.0
	car.throttle_input = 1.0 if full else clampf((95.0 - kmh) * 0.15, 0.0, 1.0)
	car.brake_input = 0.0
	if at.call(8.0):
		_rv.force_encounter()
	var close := _rv.state == Rivals.State.CHASE and _rv.gap < 40.0
	if close and not _rvl.has("shot1"):
		_rvl["shot1"] = true
		_log("AUTOTEST [%.1f s] camping-car à %.0f m, vitesse %.0f km/h" % [_t, _rv.gap, _rv.get_speed_kmh()])
	if _t > 8.0 and fmod(_t, 3.0) < delta and _rv.state == Rivals.State.CHASE:
		_log("AUTOTEST [%.1f s] écart %.0f m, camping-car %.0f km/h, nous %.0f km/h, impacts %d" % [_t, _rv.gap, _rv.get_speed_kmh(), kmh, _rv.hits])
	# caméras : derrière la voiture, puis vue de côté quand il est à notre hauteur
	if _rv.state == Rivals.State.CHASE and _rv.gap < 8.0 and _rv.get_car_position() != Vector3.ZERO:
		var rp := _rv.get_car_position()
		cam.global_position = car.global_position + car.global_basis.z * 9.0 + car.global_basis.y * 2.5 + car.global_basis.x * 2.5
		cam.look_at((rp + car.global_position) * 0.5 + Vector3.UP)
		if not _rvl.has("side"):
			_rvl["side_t"] = _t
			_rvl["side"] = true
		if _t - float(_rvl["side_t"]) > 1.5 and not _rvl.has("shot_side"):
			_rvl["shot_side"] = true
			_shot("concurrents_2_a_cote")
	else:
		_cabin_cam(Vector3(0.0, 3.5, -10.0), Vector3(0.0, 1.0, 10.0))
		if _rv.state == Rivals.State.CHASE and _rv.gap < 60.0 and not _rvl.has("shot_back"):
			_rvl["shot_back"] = true
			_shot("concurrents_1_derriere")
	if at.call(30.0):
		_log("AUTOTEST [30 s] pied au plancher")
	if _rvl.has("lost") and _t - float(_rvl["lost"]) > 1.0 or _t > 70.0:
		_log("AUTOTEST fin : impacts %d, état %d" % [_rv.hits, _rv.state])
		get_tree().quit()


# --- Portée VR : géométrie de l'habitacle autour du siège conducteur ---------------

func _run_autotest_reach(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	car.external_input = true
	car.brake_input = 1.0
	_inside = false
	cam.fov = 90.0
	if at.call(0.05):
		$Weather.hour = 13.0
		for m in car.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh == null or not mi.is_visible_in_tree():
				continue
			var ab: AABB = car.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
			var c := ab.get_center()
			if absf(c.x) < 1.0 and c.y > 0.3 and c.y < 2.0 and c.z > -1.2 and c.z < 1.4 and ab.size.length() < 2.5:
				_log("AUTOTEST mesh %s : %s .. %s" % [mi.get_path().get_concatenated_names().right(60), ab.position, ab.end])
		var eye := car.to_local(car.driver_seat.global_position)
		_log("AUTOTEST oeil %s" % eye)
	var eye_g := car.driver_seat.global_position
	if _t < 1.0:
		_cabin_cam(car.to_local(eye_g), Vector3(0.45, 1.1, 1.0))
		if at.call(0.8): _shot("portee_avant")
	elif _t < 2.0:
		_cabin_cam(car.to_local(eye_g), Vector3(0.0, 0.8, 0.5))
		if at.call(1.8): _shot("portee_levier")
	elif _t < 3.0:
		_cabin_cam(Vector3(2.4, 1.3, 0.2), Vector3(0.0, 1.1, 0.2))
		if at.call(2.8): _shot("portee_cote")
	else:
		get_tree().quit()


# --- Thermos : dévisser (2 mains VR), verser dans la tasse, boire, revisser ; puis à la
# souris (F) : dévisser, verser tout seul, boire --------------------------------------

var _th := {}


func _th_set(body: RigidBody3D, hand: Node3D, g: VRPickable, xf: Transform3D) -> void:
	hand.global_transform = xf * g._offset.affine_inverse()
	g.grab_update(hand)


func _run_autotest_thermos(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	car.external_input = true
	car.brake_input = 1.0
	_inside = false
	var body := _car_item("Thermos")
	if body == null:
		return
	var th := body.get_node("Grab") as Thermos
	var cb := car.global_basis
	var P := car.to_global(Vector3(-0.3, 1.05, 0.3))
	var up_xf := Transform3D(cb, P)
	if at.call(0.05):
		$Weather.hour = 13.0
		var ha := Node3D.new()
		ha.name = "HandA"
		add_child(ha)
		var hb := Node3D.new()
		hb.name = "HandB"
		add_child(hb)
		_th["a"] = ha
		_th["b"] = hb
		car.get_node("GloveboxLid").set_angle_deg(-80.0, true)
		car.get_node("Storage")._place_loose(body, RandomNumberGenerator.new(), [])
		var f := get_tree().get_first_node_in_group(Fatigue.GROUP) as Fatigue
		_log("AUTOTEST thermos : fermé=%s, %.1f tasses ; fatigue %s" % [th.capped, th.cups, f != null])
	var ha: Node3D = _th.get("a")
	var hb: Node3D = _th.get("b")
	if ha == null:
		return
	if at.call(0.5):
		ha.global_transform = body.global_transform
		th.grab(ha)
	if _t > 0.5 and _t < 13.0 and th.is_grabbed():
		var xf := up_xf
		if _t > 2.2 and _t < 6.0:
			# penché au-dessus de la tasse : rotation jusqu'à 115°, bord du goulot au-dessus
			var k := smoothstep(2.2, 3.0, _t) * (1.0 - smoothstep(5.4, 6.0, _t))
			var cupg: ThermosCup = th.get_cup()
			var b := cb * Basis(Vector3(0, 0, 1), -deg_to_rad(115.0) * k)
			body.global_transform = Transform3D(b, P)
			var lip := th.lip_position()
			var target := P
			if cupg:
				target = cupg.rim_center() + Vector3.UP * 0.1
				target = P.lerp(target - (lip - P), k)
			xf = Transform3D(b, target)
		_th_set(body, ha, th, xf)
	var cam_p := car.to_global(Vector3(0.15, 1.3, 0.0))
	if _t < 6.0:
		cam.global_position = cam_p
		cam.look_at(P + cb.z * 0.02 + cb.x * 0.08)
		cam.fov = 55.0
	if at.call(1.0):
		_shot("thermos_1_ferme")
	if at.call(1.3):
		var cap := th._cap_grip
		hb.global_transform = cap.global_transform
		cap.grab(hb)
		var cupg: ThermosCup = th.get_cup()
		_th["cup"] = cupg
		_log("AUTOTEST bouchon attrapé (main B) -> fermé=%s, tasse=%s tenue=%s, retournée=%s" % [th.capped, cupg != null, cupg.is_grabbed() if cupg else false, cupg.item.global_basis.y.dot(Vector3.UP) < 0 if cupg else false])
	var cupv = _th.get("cup")
	var cupg: ThermosCup = cupv if is_instance_valid(cupv) else null
	if cupg and is_instance_valid(cupg) and _t > 1.3 and _t < 9.5 and cupg.is_grabbed():
		var cxf := Transform3D(cb, car.to_global(Vector3(-0.12, 0.92, 0.32)))
		var k2 := smoothstep(1.3, 2.0, _t)
		var start := body.global_transform * Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, Thermos.CUP_TOP, 0))
		cxf = start.interpolate_with(cxf, k2)
		if _t > 6.5:
			# à la bouche, penchée de 55° vers le visage
			var mouth = EdiblePickable.mouth_position(get_tree())
			var tb := cam.global_basis * Basis(Vector3.RIGHT, deg_to_rad(55.0))
			var k3 := smoothstep(6.5, 7.0, _t)
			var mxf := Transform3D(tb, mouth - tb.y * ThermosCup.HEIGHT)
			cxf = cxf.interpolate_with(mxf, k3)
		if _t > 8.6:
			# retournée au-dessus du goulot pour la revisser
			var sxf := body.global_transform * Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, Thermos.CUP_TOP + 0.01, 0))
			cxf = sxf
		_th_set(cupg.item, hb, cupg, cxf)
	if _t >= 6.0 and _t < 8.6:
		cam.global_position = car.to_global(Vector3(0.0, 1.35, -0.1))
		cam.look_at(car.to_global(Vector3(-0.2, 1.2, 0.6)))
	if at.call(2.1):
		_log("AUTOTEST tasse à l'endroit sous le thermos : fill=%.2f" % cupg.fill)
	for tt in [3.0, 3.8, 4.6, 5.4]:
		if at.call(tt):
			_log("AUTOTEST t=%.1f verse : débit %.2f, tasse %.2f, thermos %.2f tasses, versé dans la tasse %.2f, renversé %.2f" % [_t, th._pouring, cupg.fill, th.cups, th.poured_in_cup, cupg.spilled])
	if at.call(3.4):
		_shot("thermos_2_verse")
	if at.call(6.3):
		var f := get_tree().get_first_node_in_group(Fatigue.GROUP) as Fatigue
		f.fatigue = 0.8
		_th["f0"] = f.fatigue
		_log("AUTOTEST avant de boire : tasse %.2f, fatigue %.2f" % [cupg.fill, f.fatigue])
	if at.call(7.6):
		_shot("thermos_3_boire")
	if at.call(8.5):
		var f := get_tree().get_first_node_in_group(Fatigue.GROUP) as Fatigue
		_log("AUTOTEST après avoir bu : tasse %.2f, bu %.2f, fatigue %.2f (avant %.2f)" % [cupg.fill, cupg.drunk, f.fatigue, _th["f0"]])
	if at.call(9.2):
		cupg.release(hb)
		_log("AUTOTEST tasse lâchée sur le goulot -> revissée=%s, thermos %.2f tasses" % [th.capped, th.cups])
	if at.call(9.6):
		_shot("thermos_4_revisse")
		th.toggle()
		var c2 := th.get_cup()
		_log("AUTOTEST F sur le thermos fermé -> fermé=%s, tasse posée dans %s" % [th.capped, c2.item.get_parent().name if c2 else "?"])
	if at.call(10.4):
		th.toggle()
		_log("AUTOTEST F sur le thermos ouvert -> versement auto %.1f s" % th._auto_pour)
	if at.call(12.0):
		var c2 := th.get_cup()
		_log("AUTOTEST après versement auto : tasse %.2f, thermos %.2f" % [c2.fill if c2 else -1.0, th.cups])
		if c2:
			c2.toggle()
	if at.call(13.5):
		var c2 := th.get_cup()
		var f := get_tree().get_first_node_in_group(Fatigue.GROUP) as Fatigue
		_log("AUTOTEST F sur la tasse -> tasse %.2f, fatigue %.2f" % [c2.fill if c2 else -1.0, f.fatigue])
		get_tree().quit()


# --- Fatigue : monte en roulant (plus vite la nuit), effets à l'écran ---------------

var _fa := {}


func _run_autotest_fatigue(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	car.external_input = true
	car.external_steer = 0.0
	_inside = false
	var f := get_tree().get_first_node_in_group(Fatigue.GROUP) as Fatigue
	if f == null:
		return
	var w: WeatherSystem = $Weather
	w.random_events = false
	$FallingTrees.enabled = false
	if _t < 9.0:
		car.throttle_input = 0.5
		car.brake_input = 0.0
	else:
		car.throttle_input = 0.0
		car.brake_input = 1.0
	if at.call(0.05):
		w.hour = 13.0
		f.fatigue = 0.0
	if at.call(1.5):
		_fa["d0"] = f.fatigue
	if at.call(4.5):
		_fa["d1"] = f.fatigue
		w.hour = 1.0
	if at.call(5.5):
		_fa["n0"] = f.fatigue
	if at.call(8.5):
		var day_rate: float = (_fa["d1"] - _fa["d0"]) / 3.0
		var night_rate: float = (f.fatigue - _fa["n0"]) / 3.0
		_log("AUTOTEST fatigue/s : jour %.5f, nuit %.5f (x%.2f), vitesse %.0f km/h ; pleine fatigue de jour en %.0f s" % [day_rate, night_rate, night_rate / maxf(day_rate, 1e-6), car.forward_speed * 3.6, 1.0 / maxf(day_rate, 1e-6)])
		w.hour = 13.0
	# vue conducteur
	_cabin_cam(car.to_local(car.driver_seat.global_position), car.to_local(car.driver_seat.global_position) + Vector3(0, -0.1, 1.0))
	cam.fov = 75.0
	if at.call(9.0):
		f.fatigue = 0.0
	if at.call(10.0):
		_shot("fatigue_0")
		f.fatigue = 0.65
	if at.call(11.0):
		_shot("fatigue_65")
		f.fatigue = 1.0
		_fa["lids_max"] = 0.0
		_fa["closed"] = 0.0
		_fa["b0"] = f.microsleeps
	if _t > 11.0 and _t < 41.0:
		_fa["lids_max"] = maxf(_fa["lids_max"], f.lids)
		if f.lids > 0.95:
			_fa["closed"] += delta
		if not _fa.has("shot_lids") and f.lids > 0.45 and f.lids < 0.8:
			_fa["shot_lids"] = true
			_shot("fatigue_paupieres")
	if at.call(13.0):
		_shot("fatigue_100")
	if at.call(20.0):
		f.yawn()
		_fa["y"] = f.yawns
	if at.call(22.6):
		_shot("fatigue_baillement")
	if at.call(25.0):
		_shot("fatigue_larmes")
	if at.call(41.0):
		_log("AUTOTEST épuisé pendant 30 s : paupières max %.2f, yeux fermés %.1f s, micro-sommeils %d, bâillements %d" % [_fa["lids_max"], _fa["closed"], f.microsleeps - _fa["b0"], f.yawns])
		f.drink_coffee(1.0)
		_log("AUTOTEST une tasse de café -> fatigue %.2f" % f.fatigue)
		get_tree().quit()


# --- VR au toucher : main posée sur le klaxon, comodos poussés, touches de la radio au
# doigt (mains VR simulées : VRHandInteractor.debug_points) ---------------------------

var _tc := {}


func _run_autotest_touch(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	car.external_input = true
	car.brake_input = 1.0
	_inside = false
	var horn := car.get_node("Horn") as HornPad
	var wiper := car.get_node("WiperStalk") as VRNotchedLever
	var light := car.get_node("LightStalk") as VRNotchedLever
	var radio := car.get_node("Radio")
	if at.call(0.05):
		$Weather.hour = 13.0
		var holder := Node3D.new()
		add_child(holder)
		var h := VRHandInteractor.new()
		holder.add_child(h)
		h.debug_points = [Vector3(0, -100, 0), Vector3(0, -100, 0)]
		_tc["h"] = h
		_tc["notches"] = []
		wiper.notch_changed.connect(func(i): _tc["notches"].append(["essuie-glace", i]))
		light.notch_changed.connect(func(i): _tc["notches"].append(["phares", i]))
	var h: VRHandInteractor = _tc.get("h")
	if h == null:
		return
	var far := Vector3(0, -100, 0)
	# 1) klaxon : le doigt arrive sur le coussin, puis la paume, puis repart
	var pad_c: Vector3 = horn._pad.global_position
	var axis: Vector3 = (horn.global_basis * horn.column_axis).normalized()
	if _t < 3.0:
		var k := 0.0
		if _t > 0.5: k = smoothstep(0.5, 0.9, _t) * (1.0 - smoothstep(1.3, 1.5, _t))
		var tip := pad_c + axis * lerpf(0.06, 0.004, k)
		var palm := far
		if _t > 1.8 and _t < 2.6:
			palm = pad_c + axis * 0.02
			tip = pad_c + axis * 0.02 + car.global_basis.z * 0.09
		h.debug_points = [tip, palm]
		cam.global_position = car.to_global(Vector3(0.45, 1.42, 0.08))
		cam.look_at(pad_c)
		cam.fov = 60.0
	for tt in [0.4, 1.1, 1.6, 2.2, 2.9]:
		if at.call(tt):
			_log("AUTOTEST t=%.1f klaxon : klaxonne=%s" % [_t, horn.is_honking()])
	if at.call(1.1):
		_shot("toucher_klaxon")
	# 2) comodo d'essuie-glace : le doigt le pousse vers le bas puis vers le haut
	if _t >= 3.0 and _t < 9.0:
		var stalk := wiper if _t < 7.5 else light
		var parent_xf: Transform3D = stalk.get_parent().global_transform
		var ax := (parent_xf.basis * stalk.hinge_axis).normalized()
		var hinge := stalk.global_position
		if not _tc.has("frame_" + stalk.name) or _t < 3.05 or (_t >= 7.5 and _t < 7.55):
			_tc["frame_" + stalk.name] = stalk.touch_arm_frame(0.2)   # pris levier au repos
		var fr: Array = _tc["frame_" + stalk.name]
		var perp: Vector3 = fr[1]
		var arm_dir: Vector3 = (fr[0] - hinge).normalized()
		if not _tc.has("perp_log"):
			_tc["perp_log"] = true
			_log("AUTOTEST comodo : bras %s, sens + %s (repère voiture)" % [car.global_basis.inverse() * arm_dir, car.global_basis.inverse() * perp])
		var base: Vector3 = fr[0]
		var off := 0.0
		if _t < 5.0:
			off = lerpf(-0.07, 0.05, smoothstep(3.3, 4.5, _t))       # pousse dans le sens +
		elif _t < 5.4:
			off = 0.16                                                # main loin : retour au cran
		elif _t < 7.4:
			off = lerpf(0.12, -0.03, smoothstep(5.4, 5.6, _t)) if _t < 5.6 else lerpf(-0.03, -0.03, 0.0)
			if _t >= 5.6:
				# repart de l'autre côté : arrive par le bas (sens -) et pousse vers +... puis vers -
				off = lerpf(0.15, -0.04, smoothstep(5.8, 7.0, _t))
		else:
			off = lerpf(0.08, -0.06, smoothstep(7.6, 8.6, _t))
		if _t >= 5.4 and _t < 5.8:
			h.debug_points = [far, far]
		else:
			# arrivée : d'abord loin sur le bord de départ
			h.debug_points = [base + perp * off + ax * 0.0, far]
		cam.global_position = car.to_global(Vector3(0.3, 1.25, 0.2))
		cam.look_at(hinge + arm_dir * 0.15)
	for tt in [3.2, 4.0, 4.6, 5.3, 6.4, 7.0, 7.45, 8.7]:
		if at.call(tt):
			_log("AUTOTEST t=%.2f comodos : essuie-glace cran %d (%.1f°), phares cran %d (%.1f°)" % [_t, wiper.notch, rad_to_deg(wiper.angle), light.notch, rad_to_deg(light.angle)])
	if at.call(4.6):
		_shot("toucher_comodo")
	# 3) radio : touches au doigt
	if _t >= 9.0 and _t < 15.0:
		var seq := [["next", 9.2], ["next", 10.2], ["p2", 11.2], ["power", 12.2], ["power", 13.4]]
		var tip := far
		for e in seq:
			var dt: float = _t - float(e[1])
			if dt >= 0.0 and dt < 0.8:
				var m: Node3D = radio._buttons[e[0]][0]
				var g := m.get_parent() as Node3D
				var ab: AABB = (m as MeshInstance3D).get_aabb() if m is MeshInstance3D else AABB()
				var face_l := g.position + Vector3(ab.get_center().x, ab.get_center().y, ab.end.z)
				var depth := lerpf(0.03, -0.003, smoothstep(0.0, 0.3, dt)) if dt < 0.5 else lerpf(-0.003, 0.03, smoothstep(0.5, 0.7, dt))
				tip = radio.to_global(face_l + Vector3(0, 0, depth))
		h.debug_points = [tip, far]
		cam.global_position = car.to_global(Vector3(0.2, 1.3, 0.1))
		cam.look_at(radio.global_position)
	for tt in [9.1, 9.9, 10.9, 11.9, 12.9, 14.1]:
		if at.call(tt):
			_log("AUTOTEST t=%.1f radio : allumée=%s, station %d" % [_t, radio.is_on(), radio.station])
	if at.call(10.4):
		_shot("toucher_radio")
	if at.call(15.0):
		_log("AUTOTEST crans changés : %s" % [_tc["notches"]])
		get_tree().quit()


# --- Pochette : grande ouverture arrondie, pilule prise du bout de l'index (gâchette) --

var _bi := {}


func _run_autotest_bag_index(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	car.external_input = true
	car.brake_input = 1.0
	_inside = false
	var body := _car_item("PillBag")
	var bag := body.get_node("Grab") as PillBag
	if at.call(0.05):
		$Weather.hour = 13.0
		car.get_node("Storage")._place_loose(body, RandomNumberGenerator.new(), [])
		var holder := Node3D.new()
		add_child(holder)
		var h := VRHandInteractor.new()
		holder.add_child(h)
		h.debug_points = [Vector3(0, -100, 0), Vector3(0, -100, 0)]
		h.debug_trigger = 0.0
		_bi["h"] = h
		_bi["n0"] = 0
	var h: VRHandInteractor = _bi.get("h")
	if h == null:
		return
	var bx := body.global_transform
	var mouth := bx * Vector3(0, 0.02, PillBag.SIZE.y * 0.5 + 0.02)
	cam.fov = 50.0
	if _t < 1.6:
		cam.global_position = bx * Vector3(0.0, 0.16, 0.26)
		cam.look_at(bx * Vector3(0, 0.0, 0.0))
	elif _t < 2.0:
		cam.global_position = bx * Vector3(0.0, 0.05, 0.22)
		cam.look_at(bx * Vector3(0, 0.0, 0.0))
	else:
		# vue conducteur (la bouche du joueur est là, loin de la pochette)
		cam.global_position = car.driver_seat.global_position
		cam.look_at(body.global_position)
	if at.call(0.8):
		_shot("pochette_fermee")
		bag.toggle()
	if at.call(1.6):
		_shot("pochette_ouverte")
		_bi["n0"] = bag.pills_left()
	if at.call(1.8):
		_shot("pochette_ouverture_face")
	# l'index entre par l'ouverture jusqu'à la pilule la plus proche, gâchette, ressort
	if _t > 2.0 and _t < 6.0:
		var target := bag._nearest_visible(bx * Vector3(0, 0, 0.0)).global_position if not _bi.has("held") else bx * Vector3(0, 0, 0)
		if not _bi.has("target"):
			_bi["target"] = target
		var tg: Vector3 = _bi["target"]
		var tip := mouth
		if _t < 3.0:
			tip = mouth.lerp(tg, smoothstep(2.0, 2.8, _t))
		elif _t < 3.4:
			tip = tg
			h.debug_trigger = 1.0
		else:
			# ressort par l'ouverture puis monte vers la bouche du joueur
			var mp = EdiblePickable.mouth_position(get_tree())
			tip = tg.lerp(mouth, smoothstep(3.4, 4.0, _t)).lerp(mp, smoothstep(4.2, 5.2, _t))
		h.debug_points = [tip, Vector3(0, -100, 0)]
		h._update_trigger_grab()
	if at.call(2.85):
		_log("AUTOTEST index sur la pilule : visée=%s, à portée=%s" % [h._tip_hover.name if h._tip_hover else "rien", h._tip_in_reach])
	if at.call(3.5):
		_bi["held"] = true
		var held_name: String = h.tip_held.name if h.tip_held else "rien"
		var pill = null
		for n in get_tree().get_nodes_in_group(VRInteractable.GROUP):
			if n is EdiblePickable and n.is_grabbed():
				pill = n
		_bi["pill"] = pill
		_log("AUTOTEST gâchette -> tenu par l'index : %s, pilule %s à %.3f m du bout du doigt ; pilules %d (avant %d)" % [held_name, pill.item.name if pill else "aucune", pill.item.global_position.distance_to(h.tip_hand.global_position) if pill else -1.0, bag.pills_left(), _bi["n0"]])
	if at.call(4.1):
		var pill = _bi.get("pill")
		_log("AUTOTEST pilule sortie de la pochette : suit le doigt=%s" % [pill != null and is_instance_valid(pill) and pill.item.global_position.distance_to(h.tip_hand.global_position) < 0.03])
		_shot("pochette_pilule_doigt")
	if at.call(5.6):
		var pill = _bi.get("pill")
		_log("AUTOTEST à la bouche -> pilule avalée=%s, prises=%d" % [pill == null or not is_instance_valid(pill) or pill._eaten, get_tree().root.get_meta("pills_eaten", 0)])
		h.debug_trigger = 0.0
		h._update_trigger_grab()
		get_tree().quit()


# --- Paquet tenu dans une main : l'autre main n'attrape que les cigarettes, la visée
# est surlignée seule ------------------------------------------------------------------

var _p2 := {}


func _run_autotest_pack_two_hands(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	car.external_input = true
	car.brake_input = 1.0
	_inside = false
	var body := _car_item("CigarettePack")
	var pack := body.get_node("Grab") as CigarettePack
	var P := car.to_global(Vector3(-0.15, 1.1, 0.3))
	if at.call(0.05):
		$Weather.hour = 13.0
		car.get_node("GloveboxLid").set_angle_deg(-80.0, true)
		car.get_node("ConsoleLid").set_angle_deg(-100.0, true)
		car.get_node("Storage")._place_loose(body, RandomNumberGenerator.new(), [])
		for k in ["a", "b"]:
			var holder := Node3D.new()
			add_child(holder)
			var h := VRHandInteractor.new()
			holder.add_child(h)
			h.debug_points = [Vector3(0, -100, 0), Vector3(0, -100, 0)]
			holder.global_position = Vector3(0, -100, 0)
			_p2[k] = h
	var ha: VRHandInteractor = _p2.get("a")
	var hb: VRHandInteractor = _p2.get("b")
	if ha == null:
		return
	if at.call(0.3):
		ha.global_transform = body.global_transform
		pack.grab(ha)
	if pack.is_grabbed() and _t < 6.0:
		ha.global_transform = Transform3D(car.global_basis, P) * pack._offset.affine_inverse() if false else Transform3D(car.global_basis, P)
		pack._offset = Transform3D.IDENTITY
		pack.grab_update(ha)
	cam.fov = 40.0
	cam.global_position = P + car.global_basis * Vector3(0.0, 0.2, -0.22)
	cam.look_at(P + car.global_basis.y * 0.07)
	if at.call(0.8):
		pack.toggle()   # A/X de la main qui tient
		_log("AUTOTEST main A tient le paquet, A/X -> ouvert=%s ; main B accepte : paquet=%s, cigarettes=%s ; main A accepte le paquet=%s" % [pack.open, pack.accepts_hand(hb), pack._taker.accepts_hand(hb), pack.accepts_hand(ha)])
	# main B : approche des cigarettes, à gauche puis à droite du paquet
	if _t > 1.2 and _t < 3.4:
		var side := -1.0 if _t < 2.3 else 1.0
		var tip := body.global_transform * Vector3(side * 0.02, CigarettePack.SIZE.y + 0.02, 0.0)
		hb.get_parent().global_position = tip
		var d := pack._taker.get_distance_to(tip)
		pack._taker.set_hand_distance(hb, d)
		if not _p2.has("d%d" % int(side)):
			_p2["d%d" % int(side)] = true
			_p2["side_target%d" % int(side)] = pack._taker._target
	if at.call(2.1):
		_shot("paquet2_vise_gauche")
		_log("AUTOTEST main B à gauche : distance %.3f, cigarette visée %s (x=%.4f), surlignés %d mesh(es)" % [pack._taker.get_distance_to(hb.global_position), pack._taker._target.name, pack._taker._target.position.x, pack._taker._meshes.size()])
	if at.call(3.2):
		_shot("paquet2_vise_droite")
		var tg: Node3D = pack._taker._target
		_p2["tg"] = tg
		_log("AUTOTEST main B à droite : cigarette visée %s (x=%.4f), surlignés %d mesh(es)" % [tg.name, tg.position.x, pack._taker._meshes.size()])
	if at.call(3.4):
		var n0 := pack.cigarettes_left()
		pack._taker.grab(hb)
		var tg: Node3D = _p2["tg"]
		_log("AUTOTEST main B saisit -> cigarettes %d (avant %d), la visée est sortie=%s" % [pack.cigarettes_left(), n0, not tg.visible])
	if _t > 3.4 and _t < 4.5 and pack._taker.is_grabbed():
		hb.get_parent().global_position = body.global_transform * Vector3(0.02, CigarettePack.SIZE.y + 0.02 + 0.12 * smoothstep(3.4, 4.2, _t), 0.0)
		pack._taker.grab_update(hb)
	if at.call(4.3):
		_shot("paquet2_sortie")
		pack._taker.release(hb)
	if at.call(4.6):
		get_tree().quit()


# --- Pochette tenue dans une main : l'autre main n'attrape que les pilules, la visée est
# surlignée seule ------------------------------------------------------------------------

var _b2 := {}


func _run_autotest_bag_two_hands(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	car.external_input = true
	car.brake_input = 1.0
	_inside = false
	var body := _car_item("PillBag")
	var bag := body.get_node("Grab") as PillBag
	var P := car.to_global(Vector3(-0.15, 1.05, 0.3))
	if at.call(0.05):
		$Weather.hour = 13.0
		car.get_node("GloveboxLid").set_angle_deg(-80.0, true)
		car.get_node("ConsoleLid").set_angle_deg(-100.0, true)
		car.get_node("Storage")._place_loose(body, RandomNumberGenerator.new(), [])
		for k in ["a", "b"]:
			var holder := Node3D.new()
			add_child(holder)
			var h := VRHandInteractor.new()
			holder.add_child(h)
			h.debug_points = [Vector3(0, -100, 0), Vector3(0, -100, 0)]
			holder.global_position = Vector3(0, -100, 0)
			_b2[k] = h
	var ha: VRHandInteractor = _b2.get("a")
	var hb: VRHandInteractor = _b2.get("b")
	if ha == null:
		return
	if at.call(0.3):
		ha.global_transform = body.global_transform
		bag.grab(ha)
	if bag.is_grabbed() and _t < 6.0:
		ha.global_transform = Transform3D(car.global_basis, P)
		bag._offset = Transform3D.IDENTITY
		bag.grab_update(ha)
	cam.fov = 40.0
	cam.global_position = P + car.global_basis * Vector3(0.0, 0.22, -0.2)
	cam.look_at(P)
	if at.call(0.8):
		bag.toggle()   # A/X de la main qui tient
		_log("AUTOTEST main A tient la pochette, A/X -> ouverte=%s ; main B accepte : pochette=%s, pilules=%s ; main A accepte la pochette=%s" % [bag.open, bag.accepts_hand(hb), bag._taker.accepts_hand(hb), bag.accepts_hand(ha)])
	if _t > 1.3 and _t < 3.4:
		var side := -1.0 if _t < 2.3 else 1.0
		var tip := body.global_transform * Vector3(side * 0.03, 0.012, -0.02)
		hb.get_parent().global_position = tip
		bag._taker.set_hand_distance(hb, bag._taker.get_distance_to(tip))
	if at.call(2.1):
		_shot("pochette2_vise_gauche")
		_log("AUTOTEST main B à gauche : pilule visée x=%.3f, surlignés %d mesh(es)" % [bag._taker._target.position.x, bag._taker._meshes.size()])
	if at.call(3.2):
		_shot("pochette2_vise_droite")
		_b2["tg"] = bag._taker._target
		_log("AUTOTEST main B à droite : pilule visée x=%.3f, surlignés %d mesh(es)" % [bag._taker._target.position.x, bag._taker._meshes.size()])
	if at.call(3.4):
		var n0 := bag.pills_left()
		bag._taker.grab(hb)
		var tg: Node3D = _b2["tg"]
		_log("AUTOTEST main B saisit -> pilules %d (avant %d), la visée est sortie=%s" % [bag.pills_left(), n0, not tg.visible])
	if _t > 3.4 and _t < 4.5 and bag._taker.is_grabbed():
		hb.get_parent().global_position = body.global_transform * Vector3(0.03, 0.012 + 0.1 * smoothstep(3.4, 4.2, _t), 0.0)
		bag._taker.grab_update(hb)
	if at.call(4.3):
		_shot("pochette2_sortie")
		bag._taker.release(hb)
	if at.call(4.6):
		get_tree().quit()


# --- Mains VR affichées qui restaient coincées dans l'habitacle -------------------------
# La vraie main passe dans une paroi (tableau de bord, console, volant), en tournant le
# poignet, puis revient dans le vide : la main affichée doit la rejoindre vite.

## [nom, points de passage (repère voiture), poignet tourné pendant le geste]
const STUCK_MOVES := [
	["tableau de bord puis retour", [Vector3(-0.25, 1.12, 0.3), Vector3(-0.25, 1.0, 1.0), Vector3(-0.25, 1.05, 0.95), Vector3(-0.2, 1.15, 0.25)], true],
	["à travers la console", [Vector3(0.3, 1.0, 0.1), Vector3(-0.3, 0.85, 0.1), Vector3(-0.35, 1.1, 0.1)], false],
	["à travers le volant", [Vector3(0.45, 1.25, 0.3), Vector3(0.45, 1.0, 0.75), Vector3(0.45, 1.25, 0.25)], true],
	["sous le siège puis remontée", [Vector3(-0.45, 1.0, 0.1), Vector3(-0.45, 0.6, 0.1), Vector3(-0.45, 1.15, 0.1)], false],
]
var _hs := {}


func _run_autotest_hands_stuck(delta: float) -> void:
	_t += delta
	car.external_input = true
	car.brake_input = 1.0
	_inside = false
	if not _hs.has("c"):
		var ctrl := XRController3D.new()
		ctrl.tracker = &"right_hand"
		add_child(ctrl)
		ctrl.add_child((load("res://addons/godot-xr-tools/hands/scenes/lowpoly/right_hand_low.tscn") as PackedScene).instantiate())
		var hi := VRHandInteractor.new()
		ctrl.add_child(hi)
		hi.debug_points = [Vector3(0, -100, 0)]
		_hs["c"] = ctrl
		_hs["h"] = hi
	if _t < 0.5:
		return
	var i := int((_t - 0.5) / 3.0)
	if i >= STUCK_MOVES.size():
		get_tree().quit()
		return
	var mv: Array = STUCK_MOVES[i]
	var pts: Array = mv[1]
	var ph := fmod(_t - 0.5, 3.0)
	var ctrl: XRController3D = _hs["c"]
	var hi: VRHandInteractor = _hs["h"]
	# 0-1,6 s : le geste (de point en point) ; ensuite la main reste au dernier point
	var k := clampf(ph / 1.6, 0.0, 1.0) * (pts.size() - 1)
	var j := mini(int(k), pts.size() - 2)
	var p: Vector3 = (pts[j] as Vector3).lerp(pts[j + 1], k - j)
	var twist := sin(clampf(ph / 1.6, 0.0, 1.0) * PI * 3.0) * 0.9 if mv[2] else 0.0
	var hb := car.global_basis * Basis.from_euler(Vector3(deg_to_rad(-20.0), PI, twist))
	ctrl.global_transform = Transform3D(hb, car.to_global(p))
	var gap := hi.visual_transform().origin.distance_to(ctrl.global_position)
	if ph > 1.6:
		_hs["max_after"] = maxf(_hs.get("max_after", 0.0), gap if ph > 2.0 else 0.0)
	var log_at := func(x: float) -> bool: return ph - delta < x and ph >= x
	if log_at.call(1.7):
		_log("AUTOTEST %-28s : main revenue dans le vide, écart main affichée %.3f m" % [mv[0], gap])
	if log_at.call(2.9):
		_log("AUTOTEST %-28s : 1,3 s plus tard, écart %.3f m (libre à la vraie main=%s)" % [mv[0], gap, hi._hand_free(hb, ctrl.global_position)])


# --- Mains VR affichées : butent sur l'habitacle, s'accrochent aux commandes ---------
# (main droite XR Tools sur un XRController3D déplacé à la main)

var _hd := {}


func _run_autotest_hands(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	car.external_input = true
	car.brake_input = 1.0
	_inside = false
	if at.call(0.05):
		$Weather.hour = 13.0
		var ctrl := XRController3D.new()
		ctrl.name = "TestRightController"
		ctrl.tracker = &"right_hand"
		ctrl.pose = &"grip"
		add_child(ctrl)
		var hand := (load("res://addons/godot-xr-tools/hands/scenes/lowpoly/right_hand_low.tscn") as PackedScene).instantiate()
		ctrl.add_child(hand)
		var hi := VRHandInteractor.new()
		ctrl.add_child(hi)
		hi.debug_points = [Vector3(0, -100, 0)]
		_hd["c"] = ctrl
		_hd["h"] = hi
		_hd["xh"] = hand
	var ctrl: XRController3D = _hd.get("c")
	var hi: VRHandInteractor = _hd.get("h")
	if ctrl == null:
		return
	var eye := car.to_local(car.driver_seat.global_position)
	var cb := car.global_basis
	# poignet orienté « main tendue vers l'avant, paume vers le bas-gauche »
	var hb := cb * Basis.from_euler(Vector3(deg_to_rad(-20.0), PI, 0.0))
	cam.fov = 70.0
	# 1) la main avance dans le tableau de bord
	if _t < 2.5:
		var k := smoothstep(0.3, 1.8, _t)
		var p := car.to_global(Vector3(-0.25, 1.12, 0.35).lerp(Vector3(-0.25, 1.0, 1.05), k))
		ctrl.global_transform = Transform3D(hb, p)
		_cabin_cam(eye, Vector3(-0.25, 1.0, 0.9))
	for tt in [0.9, 1.5, 2.2]:
		if at.call(tt):
			var vis: Vector3 = hi.visual_transform().origin
			_log("AUTOTEST t=%.1f main réelle %s, main affichée %s (écart %.3f m) ; libre ici=%s, libre à la vraie main=%s" % [_t, car.to_local(ctrl.global_position), car.to_local(vis), vis.distance_to(ctrl.global_position), hi._hand_free(ctrl.global_basis, vis), hi._hand_free(ctrl.global_basis, ctrl.global_position)])
	if at.call(2.2):
		_shot("mains_tableau_de_bord")
	# 2) volant : main sur la jante à 10 h, saisie, on tourne
	var wheel := car.get_node("SteeringWheel") as VRSteeringWheel
	var ax: Vector3 = (wheel.get_parent().global_basis * wheel.column_axis).normalized()
	var wc := wheel.global_position
	var up_in_plane := (cb.y - ax * cb.y.dot(ax)).normalized()
	var left_in_plane := ax.cross(up_in_plane).normalized()
	if _t >= 2.5 and _t < 6.0:
		var ang := deg_to_rad(50.0) - (deg_to_rad(40.0) * smoothstep(4.0, 5.2, _t))
		var rim := wc + (up_in_plane * cos(ang) + left_in_plane * sin(ang)) * 0.2 + ax * 0.02
		ctrl.global_transform = Transform3D(hb, rim)
		_cabin_cam(eye, car.to_local(wc))
		if hi.held:
			hi.held.grab_update(hi)
	if at.call(3.0):
		hi._grab_now(wheel)
		var xh: Node3D = _hd["xh"]
		_log("AUTOTEST volant saisi : main accrochée=%s ; distance du poing à l'axe %.3f m (jante ~%.3f)" % [hi._snap_target != null, _dist_to_axis(xh.global_position, wc, ax), wheel._snap_radius])
	if at.call(3.8):
		_shot("mains_volant")
		var xh: Node3D = _hd["xh"]
		_log("AUTOTEST main affichée à %.3f m de l'axe du volant" % _dist_to_axis(xh.global_position, wc, ax))
	if at.call(5.4):
		_log("AUTOTEST volant tourné à %.0f° ; main toujours accrochée=%s" % [rad_to_deg(wheel.wheel_angle), hi._snap_target != null])
		_shot("mains_volant_tourne")
	if at.call(5.8):
		hi._release()
		wheel.set_steer_input(0.0)
	# 3) levier de vitesse, frein à main, comodo
	var seq := [["GearLever", 6.0, Vector3(0.0, 0.93, 0.5)], ["Handbrake", 7.5, Vector3(0.165, 0.9, 0.18)], ["WiperStalk", 9.0, Vector3(0.22, 0.96, 0.57)]]
	for e in seq:
		var t_s: float = e[1]
		if _t >= t_s and _t < t_s + 1.5:
			var it := car.get_node(e[0]) as VRInteractable
			ctrl.global_transform = Transform3D(hb, car.to_global(e[2]))
			_cabin_cam(eye, e[2])
			if at.call(t_s + 0.3):
				hi._grab_now(it)
				var xh: Node3D = _hd["xh"]
				_log("AUTOTEST %s saisi : main accrochée=%s, cible d'accroche à %.3f m de la main réelle" % [e[0], hi._snap_target != null, hi._snap_target.global_position.distance_to(ctrl.global_position) if hi._snap_target else -1.0])
			if at.call(t_s + 1.0):
				_shot("mains_" + str(e[0]).to_lower())
			if at.call(t_s + 1.4):
				hi._release()
	if at.call(10.6):
		get_tree().quit()


func _dist_to_axis(p: Vector3, c: Vector3, ax: Vector3) -> float:
	var v := p - c
	return (v - ax * v.dot(ax)).length()


# --- Rouler : pochon -> tête -> grinder -> moudre -> pincées sur une feuille + filtre ->
# joint ; puis deux pincées de tabac + filtre -> cigarette roulée -------------------------

var _rl := {}


func _rl_hand(k: String) -> VRHandInteractor:
	if not _rl.has(k):
		var holder := Node3D.new()
		add_child(holder)
		var h := VRHandInteractor.new()
		holder.add_child(h)
		h.debug_points = [Vector3(0, -100, 0), Vector3(0, -100, 0)]
		_rl[k] = h
	return _rl[k]


func _rl_move(h: VRHandInteractor, p: Vector3, basis := Basis.IDENTITY) -> void:
	h.get_parent().global_transform = Transform3D(car.global_basis * basis, p)
	for n in get_tree().get_nodes_in_group(VRInteractable.GROUP):
		var it := n as VRInteractable
		if it and h in it._grab_hands:
			it.grab_update(h)


func _run_autotest_roll(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	car.external_input = true
	car.brake_input = 1.0
	_inside = false
	var bag_b := _car_item("WeedBag")
	var gr_b := _car_item("Grinder")
	var pap_b := _car_item("RollingPapers")
	var fil_b := _car_item("FilterBox")
	var tob_b := _car_item("TobaccoPouch")
	if tob_b == null or bag_b == null or gr_b == null or pap_b == null or fil_b == null:
		if at.call(0.1):
			_log("AUTOTEST objets manquants : pochon %s grinder %s feuilles %s filtres %s tabac %s" % [bag_b, gr_b, pap_b, fil_b, tob_b])
			get_tree().quit()
		return
	var bag := bag_b.get_node("Grab") as WeedBag
	var gr := gr_b.get_node("Grab") as Grinder
	var pap := pap_b.get_node("Grab") as RollDispenser
	var fil := fil_b.get_node("Grab") as RollDispenser
	var tob := tob_b.get_node("Grab") as TobaccoPouch
	var ha := _rl_hand("a")
	var hb := _rl_hand("b")
	var S := car.to_global(Vector3(-0.2, 1.0, 0.35))        # où la main A tient la feuille
	var G := car.to_global(Vector3(-0.05, 0.98, 0.3))       # où la main A tient le grinder
	if at.call(0.05):
		$Weather.hour = 13.0
		_log("AUTOTEST dans la voiture : pochon (%d têtes) dans %s, grinder dans %s, feuilles (%d) dans %s, filtres (%d) dans %s" % [bag.pill_count, bag_b.get_parent().name, gr_b.get_parent().name, pap.count, pap_b.get_parent().name, fil.left(), fil_b.get_parent().name])
		car.get_node("GloveboxLid").set_angle_deg(-80.0, true)
		car.get_node("ConsoleLid").set_angle_deg(-100.0, true)
		var rng := RandomNumberGenerator.new()
		for b in [bag_b, pap_b, fil_b, gr_b, tob_b]:
			car.get_node("Storage")._place_loose(b, rng, [])
	cam.fov = 55.0
	cam.global_position = car.to_global(Vector3(0.1, 1.3, 0.05))
	cam.look_at(car.to_global(Vector3(-0.12, 0.98, 0.33)))
	# 1) grinder en main A, ouvert ; deux têtes sorties du pochon et lâchées dedans
	if at.call(0.3):
		var hc := _rl_hand("c")      # troisième main : tient le grinder tout du long
		hc.get_parent().global_transform = gr_b.global_transform
		gr.grab(hc)
		gr._offset = Transform3D.IDENTITY
		_rl_move(hc, G)
		gr.toggle()
		bag.toggle()
		_log("AUTOTEST grinder tenu, A/X -> ouvert=%s ; pochon ouvert=%s ; main B accepte le grinder=%s" % [gr.open, bag.open, gr.accepts_hand(hb)])
	if _t > 0.3 and gr.is_grabbed():
		_rl_move(_rl_hand("c"), G)
	for k in 2:
		var tk := 0.6 + k * 1.0
		if at.call(tk):
			var bud: Node3D = bag._nearest_visible(bag_b.global_position)
			_rl_move(hb, bud.global_position)
			bag._taker.set_hand_distance(hb, 0.0)
			bag._taker.grab(hb)
		if _t > tk and _t < tk + 0.6:
			_rl_move(hb, hb.global_position.lerp(gr.chamber_center() + car.global_basis.y * 0.03, 0.2))
		if at.call(tk + 0.6):
			var held_bud = bag._taker._held.get(hb)
			if held_bud:
				_log("   tête à %s du centre de la chambre (repère grinder)" % [gr_b.global_transform.affine_inverse() * held_bud.item.global_position])
			bag._taker.release(hb)
			_log("AUTOTEST tête %d lâchée au-dessus du grinder -> têtes dedans %d (pochon : %d restantes)" % [k + 1, gr.buds, bag.pills_left()])
	if at.call(2.7):
		_shot("rouler_1_grinder_tetes")
		gr.toggle()   # ferme (il y a des têtes : A/X ferme d'abord, puisqu'il est ouvert)
		_log("AUTOTEST grinder fermé=%s, couvercle à tourner actif=%s" % [not gr.open, gr._lid_grip.enabled])
	# 2) main B tourne le couvercle
	if at.call(2.9):
		_rl_move(hb, gr._lid.global_position)
		gr._lid_grip.grab(hb)
	if _t > 2.9 and _t < 4.6 and gr._lid_grip.is_grabbed():
		var ang := (_t - 2.9) * TAU * 1.1
		_rl_move(hb, gr._lid.global_position, Basis(Vector3.UP, ang))
	if at.call(4.7):
		gr._lid_grip.release(hb)
		_log("AUTOTEST couvercle tourné -> moutures %d, herbe moulue %.2f, têtes %d" % [gr.grinds, gr.ground, gr.buds])
		gr.toggle()   # ouvre
	if at.call(5.0):
		_shot("rouler_2_herbe_moulue")
	# 3) feuille sortie du carnet par la main A (le grinder est posé), tenue en S
	if at.call(5.2):
		pap.toggle()
		_rl_move(ha, pap_b.global_position + pap_b.global_basis.y * 0.006)
		pap._taker.grab(ha)
		_rl["sheet"] = null
		for sh in get_tree().get_nodes_in_group("rolling_sheets"):
			if sh.is_grabbed():
				_rl["sheet"] = sh
		_log("AUTOTEST carnet ouvert, feuille sortie=%s (reste %d)" % [_rl["sheet"] != null, pap.count])
	var sheet_v = _rl.get("sheet")
	var sheet: RollingSheet = sheet_v if is_instance_valid(sheet_v) else null
	if _t > 5.2 and _t < 9.6 and sheet and is_instance_valid(sheet) and sheet.is_grabbed():
		_rl_move(ha, ha.global_position.lerp(S, 0.15))
	# deux pincées puis un filtre lâchés sur la feuille par la main B
	var gives := [[gr, 6.0], [gr, 6.8], [fil, 7.6]]
	for e in gives:
		var src = e[0]
		var tg: float = e[1]
		if at.call(tg):
			if src == fil:
				fil.toggle()
				var u: Node3D = fil.nearest_unit(fil_b.global_position)
				_rl_move(hb, u.global_transform * Vector3(0, 0.014, 0))
				fil._taker.set_hand_distance(hb, 0.0)
				fil._taker.grab(hb)
			else:
				_rl_move(hb, gr.chamber_center())
				gr._taker.grab(hb)
		if _t > tg and _t < tg + 0.5:
			_rl_move(hb, hb.global_position.lerp(S + car.global_basis.y * 0.02, 0.25))
		if at.call(tg + 0.5):
			src._taker.release(hb)
			_log("AUTOTEST lâché sur la feuille -> herbe %.2f, tabac %.2f, filtre %s, prête %s (grinder : %.2f)" % [sheet.weed, sheet.tobacco, sheet.has_filter, sheet.is_ready_to_roll(), gr.ground])
	if at.call(8.4):
		cam.global_position = S + car.global_basis * Vector3(0.0, 0.14, -0.12)
		cam.look_at(S)
		_shot("rouler_3_feuille_garnie")
	if at.call(8.8):
		sheet.toggle()   # A/X de la main qui tient la feuille
		var j: Smokable = null
		for n in get_tree().get_nodes_in_group("smokables"):
			if n.is_grabbed() and ha in n._grab_hands:
				j = n
		_rl["joint"] = j
		_log("AUTOTEST A/X -> roulé : %s (%s), tenu par la main A=%s" % [j.item.name if j else "rien", j.kind if j else "-", j != null])
	var joint_v = _rl.get("joint")
	var joint: Smokable = joint_v if is_instance_valid(joint_v) else null
	if _t > 8.8 and _t < 9.6 and joint and is_instance_valid(joint):
		_rl_move(ha, S)
		cam.global_position = S + car.global_basis * Vector3(0.0, 0.12, -0.12)
		cam.look_at(S)
	if at.call(9.3):
		_shot("rouler_4_joint")
	# 4) cigarette : deux pincées de tabac + filtre sur une nouvelle feuille -> cigarette roulée
	if at.call(9.4):
		cam.global_position = tob_b.global_transform * Vector3(0, 0.2, -0.13)
		cam.look_at(tob_b.global_position)
		_shot("rouler_5_sachet_tabac")
	if at.call(9.6):
		pap._taker.release(ha)   # lâcher le grip : la zone transmet au joint
		_log("AUTOTEST joint lâché : tenu=%s" % [joint.is_grabbed() if joint and is_instance_valid(joint) else "?"])
		_rl_move(ha, pap_b.global_position + pap_b.global_basis.y * 0.006)
		var n0 := pap.count
		pap._taker.grab(ha)
		for sh in get_tree().get_nodes_in_group("rolling_sheets"):
			if sh.is_grabbed():
				_rl["sheet2"] = sh
		_log("AUTOTEST deuxième feuille : carnet %d -> %d, trouvée=%s, carnet ouvert=%s" % [n0, pap.count, _rl.has("sheet2"), pap.open])
		if not _rl.has("sheet2"):
			get_tree().quit()
	var sheet2_v = _rl.get("sheet2")
	var sheet2: RollingSheet = sheet2_v if is_instance_valid(sheet2_v) else null
	if _t > 9.6 and _t < 12.0 and sheet2 and is_instance_valid(sheet2) and sheet2.is_grabbed():
		pap._taker.grab_update(ha)
		_rl_move(ha, ha.global_position.lerp(S, 0.2))
	for k in 2:
		var tk := 10.0 + k * 0.4
		if at.call(tk):
			if k == 0:
				tob.toggle()
				_log("AUTOTEST sachet de tabac : %d pincées, ouvert=%s" % [tob.pills_left(), tob.open])
			var p: Node3D = tob._nearest_visible(tob_b.global_position)
			_rl_move(hb, p.global_position)
			tob._taker.set_hand_distance(hb, 0.0)
			tob._taker.grab(hb)
		if _t > tk and _t < tk + 0.3:
			_rl_move(hb, hb.global_position.lerp(S + car.global_basis.y * 0.02, 0.3))
		if at.call(tk + 0.3):
			tob._taker.release(hb)
			if k == 0:
				cam.global_position = tob_b.global_transform * Vector3(0, 0.16, 0.2)
				cam.look_at(tob_b.global_position)
				_shot("rouler_6_sachet_ouvert")
			_log("AUTOTEST pincée de tabac %d lâchée sur la feuille -> tabac %.2f, herbe %.2f (sachet : %d)" % [k + 1, sheet2.tobacco, sheet2.weed, tob.pills_left()])
	if at.call(10.8):
		var u: Node3D = fil.nearest_unit(fil_b.global_position)
		_rl_move(hb, u.global_transform * Vector3(0, 0.014, 0))
		fil._taker.set_hand_distance(hb, 0.0)
		fil._taker.grab(hb)
	if _t > 10.8 and _t < 11.3:
		_rl_move(hb, hb.global_position.lerp(S + car.global_basis.y * 0.02, 0.25))
	if at.call(11.3):
		fil._taker.release(hb)
	if at.call(11.6):
		sheet2.toggle()
		var c2: Smokable = null
		for n in get_tree().get_nodes_in_group("smokables"):
			if n.is_grabbed() and ha in n._grab_hands:
				c2 = n
		_log("AUTOTEST A/X -> roulé : %s (%s)" % [c2.item.name if c2 else "rien", c2.kind if c2 else "-"])
		get_tree().quit()


func _run_autotest_pouch_view(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	car.external_input = true
	car.brake_input = 1.0
	_inside = false
	var b := _car_item("TobaccoPouch")
	if at.call(0.05):
		$Weather.hour = 13.0
		car.get_node("Storage")._place_loose(b, RandomNumberGenerator.new(), [])
	cam.fov = 45.0
	if _t < 1.5:
		cam.global_position = b.global_transform * Vector3(0, 0.22, -0.12)
	else:
		cam.global_position = b.global_transform * Vector3(0, 0.12, 0.22)
	cam.look_at(b.global_position)
	if at.call(1.2):
		_shot("sachet_tabac_ferme")
		(b.get_node("Grab") as TobaccoPouch).toggle()
	if at.call(2.4):
		_shot("sachet_tabac_ouvert")
		get_tree().quit()


# --- Glacière : sur la banquette arrière, couvercle, canette sortie, ouverte, bue
# (bourré, moins de manque, plus de fatigue), canette fermée remise dans la glace -----

var _gl := {}


func _run_autotest_cooler(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	car.external_input = true
	car.brake_input = 1.0
	_inside = false
	var cooler := car.get_node("Cooler") as Cooler
	var eye := car.to_local(car.driver_seat.global_position)
	if at.call(0.05):
		$Weather.hour = 13.0
		var add = preload("res://world/pills/pill_addiction.gd").new()
		add.name = "PillAddiction"
		add.set("car_path", NodePath("../SUV4x4"))
		add_child(add)
		add.craving = 0.6
		_gl["add"] = add
		var holder := Node3D.new()
		add_child(holder)
		var h := VRHandInteractor.new()
		holder.add_child(h)
		h.debug_points = [Vector3(0, -100, 0), Vector3(0, -100, 0)]
		_gl["h"] = h
	if at.call(0.2):
		# relevé de la banquette arrière et des dossiers avant (hors glacière)
		car.get_node("Storage")._ensure_held_collision()
		var ex: Array[RID] = []
		for b in cooler.find_children("*", "StaticBody3D", true, false):
			ex.append((b as StaticBody3D).get_rid())
		var sp := get_world_3d().direct_space_state
		var rows := []
		for x in [0.0, -0.25, 0.25]:
			for z in [-0.42, -0.5, -0.6, -0.7, -0.8]:
				var q := PhysicsRayQueryParameters3D.create(car.to_global(Vector3(x, 1.5, z)), car.to_global(Vector3(x, 0.2, z)), CarStorage.HELD_LAYER, ex)
				var r := sp.intersect_ray(q)
				rows.append("(%.2f,%.2f)->%s" % [x, z, ("%.3f" % car.to_local(r.position).y) if r else "-"])
		_log("AUTOTEST banquette arrière (x,z)->y : %s" % [" ".join(rows)])
		var backs := []
		for x in [0.0, 0.2, -0.2, 0.45, -0.45]:
			var q2 := PhysicsRayQueryParameters3D.create(car.to_global(Vector3(x, 1.0, -0.42)), car.to_global(Vector3(x, 1.0, 0.3)), CarStorage.HELD_LAYER, ex)
			var r2 := sp.intersect_ray(q2)
			backs.append("x=%.2f->%s" % [x, ("%.3f" % car.to_local(r2.position).z) if r2 else "-"])
		_log("AUTOTEST dossiers avant à y=1.0 (premier obstacle en avançant depuis z=-0.42) : %s" % [" ".join(backs)])
		_log("AUTOTEST glacière : %d canettes, couvercle ouvert=%s" % [cooler.cans_left(), cooler.lid.is_open()])
	var add = _gl.get("add")
	var h: VRHandInteractor = _gl.get("h")
	if h == null:
		return
	if _t < 1.5:
		cam.fov = 75.0
		cam.global_position = car.to_global(eye + Vector3(-0.2, 0.0, 0.0))
		cam.look_at(cooler.global_position + car.global_basis.y * 0.15)
	if at.call(1.0):
		_shot("glaciere_fermee")
		cooler.lid.toggle()
	if at.call(1.8):
		cam.global_position = cooler.global_position + car.global_basis * Vector3(0.0, 0.55, 0.35)
		cam.look_at(cooler.global_position + car.global_basis.y * 0.1)
		_shot("glaciere_ouverte")
		_log("AUTOTEST couvercle ouvert=%s, zone canettes active=%s" % [cooler.lid.is_open(), cooler._taker.enabled])
	# main B : prend une canette, l'ouvre, la porte à la bouche
	if at.call(2.0):
		var c: Node3D = cooler.nearest_can(cooler.global_position)
		h.get_parent().global_position = c.global_transform * Vector3(0, 0.08, 0)
		cooler._taker.set_hand_distance(h, 0.0)
		cooler._taker.grab(h)
		var can: BeerCan = cooler._taker._held.get(h)
		_gl["can"] = can
		_log("AUTOTEST canette sortie : %s (%s), restent %d" % [can.item.name if can else "rien", "ouverte" if can and can.opened else "fermée", cooler.cans_left()])
	var can: BeerCan = _gl.get("can")
	if can and is_instance_valid(can) and _t > 2.0 and _t < 9.0:
		cam.fov = 70.0
		cam.global_position = car.to_global(eye)
		cam.look_at(car.to_global(eye + Vector3(0, -0.15, 1.0)))
		var mouth = EdiblePickable.mouth_position(get_tree(), can)
		var target: Vector3 = mouth
		var tb := cam.global_basis * Basis(Vector3.RIGHT, deg_to_rad(50.0))
		# sortie par le haut (au-dessus des dossiers avant), puis vers la bouche
		var k := smoothstep(2.6, 3.4, _t)
		var start: Vector3 = car.to_global(Vector3(0.2, 1.38, -0.15))
		var lift: Vector3 = cooler.global_position + car.global_basis.y * 0.55
		var pos: Vector3 = lift.lerp(start, smoothstep(2.0, 2.5, _t)).lerp(target - tb * Vector3(0, BeerCan.HEIGHT, 0.012), k)
		var hb := (cam.global_basis).slerp(tb, k)
		if _t > 6.2:
			pos = start
			hb = cam.global_basis
		h.get_parent().global_transform = Transform3D(hb, pos) * can._offset.affine_inverse()
		cooler._taker.grab_update(h)
	if at.call(2.4):
		can.toggle()
		_log("AUTOTEST A/X -> canette ouverte=%s" % can.opened)
	if at.call(2.5):
		_gl["c0"] = add.craving
		var f := get_tree().get_first_node_in_group(Fatigue.GROUP) as Fatigue
		_gl["f0"] = f.fatigue
	if at.call(4.5):
		_shot("glaciere_boire")
	if at.call(6.0):
		var f := get_tree().get_first_node_in_group(Fatigue.GROUP) as Fatigue
		_log("AUTOTEST à la bouche 2,5 s : bu %.2f canette, alcool %.2f (ivresse %.2f), manque %.2f -> %.2f, fatigue %.3f -> %.3f" % [can.drunk_amount, add.alcohol, add.get_booze(), _gl["c0"], add.craving, _gl["f0"], f.fatigue])
	if at.call(6.4):
		can.toggle()   # boire d'une traite (sans casque)
	if at.call(9.0):
		var f := get_tree().get_first_node_in_group(Fatigue.GROUP) as Fatigue
		_log("AUTOTEST canette finie : reste %.2f, alcool %.2f (ivresse %.2f), manque %.2f, fatigue %.3f, dérive direction %.2f°" % [can.fill, add.alcohol, add.get_booze(), add.craving, f.fatigue, rad_to_deg(car.drug_steer_offset)])
		cooler._taker.release(h)
	# bien bourré : la vue
	if at.call(9.2):
		add.alcohol = 1.5
	if _t > 9.2 and _t < 11.0:
		cam.global_position = car.to_global(eye)
		cam.look_at(car.to_global(eye + Vector3(0, -0.1, 1.0)))
	if at.call(10.5):
		_shot("glaciere_bourre")
		_log("AUTOTEST bien bourré : ivresse %.2f, dérive %.2f°, retard direction %.2f, gestes ralentis %.2f" % [add.get_booze(), rad_to_deg(car.drug_steer_offset), car.drug_steer_lag, PillAddiction.stoned_level(get_tree())])
		add.alcohol = 0.0
	# une canette fermée remise dans la glace
	if at.call(11.0):
		var c: Node3D = cooler.nearest_can(cooler.global_position)
		h.get_parent().global_position = c.global_transform * Vector3(0, 0.08, 0)
		cooler._taker.set_hand_distance(h, 0.0)
		cooler._taker.grab(h)
		_gl["n1"] = cooler.cans_left()
	if _t > 11.0 and _t < 11.6:
		h.get_parent().global_position = cooler.global_position + car.global_basis.y * 0.35
		cooler._taker.grab_update(h)
	if at.call(11.6):
		cooler._taker.release(h)
		_log("AUTOTEST canette fermée lâchée au-dessus de la glacière : %d -> %d canettes" % [_gl["n1"], cooler.cans_left()])
		cooler.lid.toggle()
	if at.call(12.4):
		_log("AUTOTEST couvercle refermé=%s, zone canettes active=%s" % [not cooler.lid.is_open(), cooler._taker.enabled])
		get_tree().quit()


# --- Haut-parleurs de portières : visibles depuis les sièges avant, son au même endroit --

func _run_autotest_speakers(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	car.external_input = true
	car.brake_input = 1.0
	_inside = false
	var radio := car.get_node("Radio")
	var eye_d := car.to_local(car.driver_seat.global_position)
	var eye_p := Vector3(-eye_d.x, eye_d.y, eye_d.z)
	if at.call(0.1):
		$Weather.hour = 13.0
		car.get_node("Storage")._ensure_held_collision()
		var sp := get_world_3d().direct_space_state
		# repérage : quelles places de la porte avant gauche se voient depuis les deux sièges
		var rows := []
		for z in [0.82, 0.72, 0.64, 0.58, 0.52]:
			for y in [0.72, 0.8, 0.88]:
				var tgt := car.to_global(Vector3(0.835, y, z))
				var seen := []
				for e in [eye_d, eye_p]:
					var q := PhysicsRayQueryParameters3D.create(car.to_global(e), tgt, CarStorage.HELD_LAYER)
					var r := sp.intersect_ray(q)
					seen.append("oui" if r.is_empty() or (r.position as Vector3).distance_to(tgt) < 0.03 else "non(%s)" % (r.collider.get_parent().name))
				rows.append("z=%.2f y=%.2f %s" % [z, y, "/".join(seen)])
		_log("AUTOTEST porte gauche, vu du conducteur / du passager :\n   " + "\n   ".join(rows))
		var surf := []
		for side in [1.0, -1.0]:
			for z in [0.66, 0.58, 0.5, -0.3, -0.4, -0.5, -0.6, -0.7]:
				for y in [0.72, 0.8, 0.88, 0.94, 1.0, 1.06]:
					var q := PhysicsRayQueryParameters3D.create(car.to_global(Vector3(0.3 * side, y, z)), car.to_global(Vector3(1.3 * side, y, z)), CarStorage.HELD_LAYER)
					var r := sp.intersect_ray(q)
					surf.append("(%.0f,%.2f,%.2f)->%s %s" % [side, y, z, ("%.3f" % car.to_local(r.position).x) if r else "-", r.collider.get_parent().name if r else ""])
		_log("AUTOTEST surface intérieure des portières (côté, y, z) -> x :\n   " + "\n   ".join(surf))
		var eye_rl := Vector3(0.42, 1.35, -0.62)
		var eye_rr := Vector3(-0.42, 1.35, -0.62)
		for p in radio.speakers:
			var gp: Vector3 = (p as Node3D).global_position
			var vis := []
			for e in [eye_d, eye_p, eye_rl, eye_rr]:
				var q := PhysicsRayQueryParameters3D.create(car.to_global(e), gp, CarStorage.HELD_LAYER)
				var r := sp.intersect_ray(q)
				vis.append("visible" if r.is_empty() or (r.position as Vector3).distance_to(gp) < 0.04 else "caché par %s" % r.collider.get_parent().name)
			_log("AUTOTEST haut-parleur %s à %s (vu du conducteur / passager / arrière gauche / arrière droit) : %s" % [p.get_parent().name, car.to_local(gp), " / ".join(vis)])
	cam.fov = 70.0
	if _t < 1.5:
		cam.global_position = car.to_global(eye_d)
		cam.look_at(car.to_global(Vector3(0.84, 0.95, 0.6)))
	elif _t < 3.0:
		cam.global_position = car.to_global(eye_d)
		cam.look_at(car.to_global(Vector3(-0.84, 0.95, 0.6)))
	else:
		cam.global_position = car.to_global(Vector3(0.3, 1.3, -0.75))
		cam.look_at(car.to_global(Vector3(0.84, 0.95, -0.58)))
	if at.call(1.2):
		_shot("enceinte_avant_gauche")
	if at.call(2.7):
		_shot("enceinte_avant_droite")
	if at.call(4.2):
		_shot("enceinte_arriere_gauche")
	if _t > 4.3:
		var cool := car.get_node("Cooler") as Node3D
		cam.global_position = cool.global_transform * Vector3(-0.45, 0.15, 0.0)
		cam.look_at(cool.global_transform * Vector3(0, 0.12, 0))
	if at.call(5.0):
		_shot("glaciere_cote")
		get_tree().quit()


# --- Sac à dos : à côté de la glacière, rabat, sachets de smileys prêts à livrer -------

var _bp := {}


func _run_autotest_backpack(delta: float) -> void:
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	car.external_input = true
	car.brake_input = 1.0
	_inside = false
	var pack := car.get_node("Backpack") as Backpack
	var eye := car.to_local(car.driver_seat.global_position)
	if at.call(0.05):
		$Weather.hour = 13.0
		for k in ["a", "b"]:
			var holder := Node3D.new()
			add_child(holder)
			var h := VRHandInteractor.new()
			holder.add_child(h)
			h.debug_points = [Vector3(0, -100, 0), Vector3(0, -100, 0)]
			_bp[k] = h
		_log("AUTOTEST sac à dos : %d sachets, rabat ouvert=%s, zone sachets active=%s" % [pack.bags_left(), pack.flap.is_open(), pack._taker.enabled])
	var ha: VRHandInteractor = _bp.get("a")
	var hb: VRHandInteractor = _bp.get("b")
	if ha == null:
		return
	cam.fov = 65.0
	if _t < 1.0:
		cam.global_position = car.to_global(eye + Vector3(-0.35, 0.0, -0.05))
		cam.look_at(pack.global_position + car.global_basis.y * 0.25)
	elif _t < 3.0:
		cam.global_position = car.to_global(Vector3(-0.05, 1.62, -0.42))
		cam.look_at(pack.global_transform * Vector3(0, 0.3, 0))
	if at.call(0.8):
		_shot("sac_ferme")
		pack.flap.toggle()
	if at.call(1.8):
		_shot("sac_ouvert")
		_log("AUTOTEST rabat ouvert=%s, zone sachets active=%s" % [pack.flap.is_open(), pack._taker.enabled])
	# main A prend le sachet le plus proche, le sort par le haut, l'amène devant soi
	if at.call(2.0):
		var b: Node3D = pack.nearest_bag(pack.global_transform * Vector3(0, 0.3, 0))
		ha.get_parent().global_position = b.global_transform * Vector3(0, 0.05, 0)
		pack._taker.set_hand_distance(ha, 0.0)
		pack._taker.grab(ha)
		var g: DealerBag = pack._taker._held.get(ha)
		_bp["bag"] = g
		_log("AUTOTEST sachet sorti : %s, %d smileys, restent %d sachets" % [g.item.name if g else "rien", g.pills_left() if g else 0, pack.bags_left()])
	var bag_v = _bp.get("bag")
	var bag: DealerBag = bag_v if is_instance_valid(bag_v) else null
	var P := car.to_global(Vector3(0.0, 1.15, 0.25))
	if bag and _t > 2.0 and _t < 6.0 and bag.is_grabbed():
		var up := pack.global_transform * Vector3(0, 0.75, 0)
		var mid := car.to_global(Vector3(0.0, 1.5, -0.35))
		var pos := (pack.global_transform * Vector3(0, 0.3, 0)).lerp(up, smoothstep(2.0, 2.3, _t)).lerp(mid, smoothstep(2.3, 2.6, _t)).lerp(P, smoothstep(2.6, 3.3, _t))
		ha.get_parent().global_transform = Transform3D(car.global_basis, pos) * bag._offset.affine_inverse()
		pack._taker.grab_update(ha)
	if _t >= 3.0 and _t < 6.0:
		cam.global_position = car.to_global(Vector3(0.0, 1.32, 0.05))
		cam.look_at(P)
	if at.call(3.5):
		bag.toggle()   # A/X de la main qui le tient : ouvert
	if at.call(4.2):
		_shot("sachet_ouvert")
		var n0 := bag.pills_left()
		var pill: Node3D = bag._nearest_visible(bag.item.global_position)
		hb.get_parent().global_position = pill.global_position
		bag._taker.set_hand_distance(hb, 0.0)
		bag._taker.grab(hb)
		var got = bag._taker._held.get(hb)
		_log("AUTOTEST sachet ouvert=%s ; main B prend une pilule : %s (%d -> %d) ; main B accepte le sachet=%s" % [bag.open, got.item.name if got else "rien", n0, bag.pills_left(), bag.accepts_hand(hb)])
		bag._taker.release(hb)
	if at.call(4.6):
		bag.toggle()   # refermé
	# remis dans le sac
	if bag and _t > 4.8 and _t < 5.6 and bag.is_grabbed():
		var mid := car.to_global(Vector3(0.0, 1.5, -0.35))   # entre les deux sièges avant, par le haut
		var pos2 := P.lerp(mid, smoothstep(4.8, 5.1, _t)).lerp(pack.global_transform * Vector3(0, 0.6, 0), smoothstep(5.1, 5.45, _t))
		ha.get_parent().global_transform = Transform3D(car.global_basis, pos2) * bag._offset.affine_inverse()
		pack._taker.grab_update(ha)
	if at.call(5.6):
		var n1 := pack.bags_left()
		# (le trajet entre les sièges avant n'est pas l'objet du test : on y pose le sachet)
		var above := pack.global_transform * Vector3(0, 0.55, 0)
		bag.item.global_position = above
		bag._prev_ok = false
		ha.get_parent().global_transform = Transform3D(car.global_basis, above) * bag._offset.affine_inverse()
		pack._taker.grab_update(ha)
		_log("   sachet à %s (repère du sac)" % [pack.global_transform.affine_inverse() * bag.item.global_position])
		pack._taker.release(ha)
		_log("AUTOTEST sachet lâché au-dessus du sac ouvert : %d -> %d sachets" % [n1, pack.bags_left()])
		pack.flap.toggle()
	if at.call(6.3):
		_log("AUTOTEST rabat refermé=%s, zone sachets active=%s" % [not pack.flap.is_open(), pack._taker.enabled])
		get_tree().quit()


# --- Livraison : carton au bord de la route, boîte aux lettres, lieu (station...) --------

var _lv := {"phase": 0}


func _lv_log(msg: String) -> void:
	_log("AUTOTEST [%.1f s] %s" % [_t, msg])


func _lv_shot(n: String) -> void:
	_lv["pending_shot"] = n
	_lv["shot_frames"] = 4
	_lv["shot_cam"] = [cam.global_transform, cam.fov]
	_lv_apply_cam.call_deferred()


func _lv_apply_cam() -> void:
	if _lv.has("pending_shot"):
		cam.global_transform = _lv["shot_cam"][0]
		cam.fov = _lv["shot_cam"][1]


## Sort un sachet du sac à dos dans la main `h` (renvoie le DealerBag).
func _lv_take(h: VRHandInteractor) -> DealerBag:
	var pack := car.get_node("Backpack") as Backpack
	if not pack.flap.is_open():
		pack.flap.toggle()
		pack.refresh_state()
	var b: Node3D = pack.nearest_bag(pack.global_transform * Vector3(0, 0.3, 0))
	if b == null:
		return null
	h.get_parent().global_position = b.global_transform * Vector3(0, 0.05, 0)
	pack._taker.set_hand_distance(h, 0.0)
	pack._taker.grab(h)
	return pack._taker._held.get(h)


## Place le sachet tenu (main `h`) à `pos` (monde), sans le bloquer sur l'habitacle.
func _lv_hold_at(h: VRHandInteractor, bag: DealerBag, pos: Vector3) -> void:
	var pack := car.get_node("Backpack") as Backpack
	bag.item.global_position = pos
	bag._prev_ok = false
	h.get_parent().global_transform = Transform3D(car.global_basis, pos) * bag._offset.affine_inverse()
	pack._taker.grab_update(h)


## Conduite : suit la voie à `lat` m de l'axe à `kmh` km/h ; s'arrête si `stop_s` > 0 et atteint.
func _lv_drive(road: RoadGenerator, lat: float, kmh_target: float, stop_s := -1.0) -> float:
	var fwd: Vector3 = car.global_basis.z
	var here := road.sample_road(car.global_position)
	var info := road.sample_road(car.global_position + fwd * 8.0)
	if info["found"]:
		var target: Vector3 = info["point"] + info["right"] * lat + info["dir"] * 4.0
		var to_t := target - car.global_position
		to_t.y = 0.0
		_steer(clampf(fwd.cross(to_t.normalized()).y * 2.5, -1.0, 1.0))
	var kmh: float = car.forward_speed * 3.6
	var cs: float = here["s"] if here["found"] else 0.0
	if stop_s > 0.0 and cs >= stop_s:
		car.throttle_input = 0.0
		car.brake_input = 1.0
	else:
		car.throttle_input = clampf((kmh_target - kmh) * 0.12, 0.0, 0.8)
		car.brake_input = clampf((kmh - kmh_target - 4.0) * 0.1, 0.0, 1.0)
	return cs


## Pose la voiture sur la route à l'abscisse s, à `lat` m de l'axe, à l'arrêt.
func _lv_place(road: RoadGenerator, s: float, lat: float) -> bool:
	var smp := road.sample_at_s(s)
	if not smp["found"]:
		return false
	var xf := Transform3D(Basis(-(smp["right"] as Vector3), Vector3.UP, smp["dir"]), (smp["point"] as Vector3) + (smp["right"] as Vector3) * lat + Vector3.UP * 0.6)
	car.global_transform = xf
	PhysicsServer3D.body_set_state(car.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	return true


func _run_autotest_delivery(delta: float) -> void:
	var road: RoadGenerator = $RoadGenerator
	var dm := road.get_node("Deliveries") as DeliveryManager
	var t0 := _t
	_t += delta
	var at := func(x: float) -> bool: return t0 < x and _t >= x
	$Weather.random_events = false
	$FallingTrees.enabled = false
	car.external_input = true
	cam.fov = 65.0
	if _lv.has("pending_shot"):
		# la caméra reste figée quelques images (l'image lue a du retard sur le rendu)
		_lv["shot_frames"] = int(_lv["shot_frames"]) - 1
		if _lv["shot_frames"] <= 0:
			_shot(_lv["pending_shot"])
			_lv.erase("pending_shot")
		else:
			_lv_apply_cam.call_deferred()
	var ph: int = _lv["phase"]
	if at.call(0.05):
		$Weather.hour = 13.0
		$Weather.set_weather("degage", true)
		dm._delay = 9999.0   # pas d'adresse automatique pendant le test
		var holder := Node3D.new()
		add_child(holder)
		var h := VRHandInteractor.new()
		holder.add_child(h)
		h.debug_points = [Vector3(0, -100, 0), Vector3(0, -100, 0)]
		_lv["hand"] = h
		# type du premier lieu du bord de la route (réglage nfp/test_lot)
		var want := str(ProjectSettings.get_setting("nfp/test_lot", "station"))
		var lot: Dictionary = road._lot_plans[0]
		var size: Vector2 = road.LOT_SIZES[want] if road.LOT_SIZES.has(want) else road.SITE_SIZES[want]
		lot["type"] = want
		lot["depth"] = size.x
		lot["length"] = size.y
		lot["s1"] = float(lot["s0"]) + size.y
		_lv["lot"] = lot
		_lv_log("lieux prévus : %s ; sachets %d" % [str(road.get_lots().map(func(l): return "%s %d-%d" % [l["type"], l["s0"], l["s1"]])), dm._bags_left()])
	var h: VRHandInteractor = _lv.get("hand")
	if h == null:
		return
	var here := road.sample_road(car.global_position)
	var cs: float = here["s"] if here.get("found", false) else 0.0
	match ph:
		0:   # carton à droite, 60 m devant
			if _t < 0.5:
				car.brake_input = 1.0
				return
			dm.target = {"id": "road:900", "kind": "carton", "s": cs + 60.0, "lateral": 4.85, "qty": 1, "done": 0, "place": "route"}
			_lv["s"] = cs + 60.0
			_lv["phase"] = 1
			_lv["t"] = _t
		1:
			var stop: float = _lv["s"] - 1.0
			_lv_drive(road, 1.75, 30.0, stop)
			_inside = false
			if dm._drop and not _lv.has("drop1"):
				_lv["drop1"] = dm._drop
			var drop: DeliveryDrop = _lv.get("drop1")
			if drop and not _lv.has("shot1") and _t - _lv["t"] > 1.0:
				_lv["shot1"] = true
				cam.global_position = drop.global_transform * Vector3(2.5, 2.2, 5.5)
				cam.look_at(drop.global_position + Vector3.UP * 0.8)
				_lv_shot("livraison_1_carton")
				_lv_log("carton posé à %.1f m de l'axe, actif=%s ; GPS %s" % [road.sample_road(drop.global_position)["lateral"], drop.active, str(dm.gps_info())])
			elif _lv.has("shot1") and not _lv.has("gps") and _t - _lv["t"] > 1.6:
				_lv["gps"] = true
				var gps := car.find_child("GPS", true, false) as Node3D
				var scr := gps.find_child("Display", true, false) as Node3D
				cam.global_position = scr.global_transform * Vector3(0, 0, 0.16)
				cam.look_at(scr.global_position)
				_lv_shot("livraison_2_gps")
			elif _lv.has("gps"):
				_cabin_cam(Vector3(0.0, 3.0, -7.0), Vector3(0.0, 1.0, 10.0))
			if cs >= stop and absf(car.forward_speed) < 0.3 and not _lv.has("bag1"):
				_lv["bag1"] = _lv_take(h)
				_lv["t"] = _t
			if _lv.has("bag1") and _t - _lv["t"] > 0.3 and not _lv.has("thrown1"):
				_lv["thrown1"] = true
				var bag: DealerBag = _lv["bag1"]
				var p0 := car.to_global(Vector3(-1.15, 1.35, 0.3))   # par la vitre du passager
				_lv_hold_at(h, bag, p0)
				var target := drop.global_transform * Vector3(0, 0.45, 0)
				var tf := 0.6
				bag.hand_velocity = (target - p0) / tf + Vector3(0, 4.9 * tf, 0)
				(car.get_node("Backpack") as Backpack)._taker.release(h)
				_lv_log("sachet %s lancé vers le carton (%.1f m)" % [bag.item.name, p0.distance_to(target)])
			if _lv.has("thrown1") and _t - _lv["t"] > 2.2 and not _lv.has("done1"):
				_lv["done1"] = true
				var bag: DealerBag = _lv["bag1"]
				cam.global_position = drop.global_transform * Vector3(0.6, 1.6, 1.6)
				cam.look_at(drop.global_position + Vector3.UP * 0.2)
				_lv_shot("livraison_3_dans_le_carton")
				_lv_log("livraisons=%d ratées=%d ; sachet dans le carton=%s, livraison en cours=%s" % [dm.delivered, dm.missed, bag.item.get_parent() == drop, str(dm.target)])
				_lv["phase"] = 2
		2:   # boîte aux lettres à gauche : on se rabat sur l'autre voie
			car.brake_input = 0.0
			dm.target = {"id": "road:901", "kind": "mailbox", "s": cs + 45.0, "lateral": -4.55, "qty": 2, "done": 0, "place": "route"}
			_lv["s"] = cs + 45.0
			_lv["phase"] = 3
			_lv["t"] = _t
		3:
			var stop2: float = _lv["s"] - 1.6
			_lv_drive(road, -3.25, 12.0, stop2)
			_cabin_cam(Vector3(1.5, 2.6, -6.0), Vector3(0.0, 1.0, 8.0))
			if dm._drop and not _lv.has("drop2"):
				_lv["drop2"] = dm._drop
			var drop2: DeliveryDrop = _lv.get("drop2")
			if drop2 == null:
				return
			if cs >= stop2 and absf(car.forward_speed) < 0.2 and not _lv.has("bag2"):
				var mouth := drop2.global_transform * Vector3(0, 1.21, 0.24)
				var eye := car.driver_seat.global_position
				_lv_log("arrêt devant la boîte : bouche à %.2f m de l'œil du conducteur (%.2f m latéral)" % [eye.distance_to(mouth), car.to_local(mouth).x - car.to_local(eye).x])
				cam.global_position = eye + car.global_basis.z * -0.15 + car.global_basis.x * -0.1
				cam.look_at(mouth)
				_lv_shot("livraison_4_boite_depuis_le_volant")
				_lv["bag2"] = _lv_take(h)
				_lv["t"] = _t
			if _lv.has("bag2") and not _lv.has("in2"):
				var bag2: DealerBag = _lv["bag2"]
				var mouth2 := drop2.global_transform * Vector3(0, 1.21, 0.24)
				var k := clampf((_t - _lv["t"]) / 0.8, 0.0, 1.0)
				var start := car.to_global(Vector3(0.5, 1.25, 0.25))
				_lv_hold_at(h, bag2, start.lerp(mouth2 + (drop2.global_basis.z * 0.12), k))
				cam.global_position = drop2.global_transform * Vector3(0.9, 1.75, -0.9)
				cam.look_at(mouth2)
				if k >= 1.0:
					_lv["in2"] = true
					_lv_shot("livraison_5_porte_ouverte")
					(car.get_node("Backpack") as Backpack)._taker.release(h)
					_lv_log("1er sachet glissé : livraison en cours %s, restant affiché %d" % [str(dm.target), drop2.remaining])
					_lv["t"] = _t
			if _lv.has("in2") and not _lv.has("bag3") and _t - _lv["t"] > 1.4:
				_lv["bag3"] = _lv_take(h)
				_lv["t3"] = _t
			if _lv.has("bag3") and not _lv.has("in3"):
				var bag3: DealerBag = _lv["bag3"]
				var mouth3 := drop2.global_transform * Vector3(0, 1.21, 0.24)
				var k3 := clampf((_t - _lv["t3"]) / 0.6, 0.0, 1.0)
				_lv_hold_at(h, bag3, car.to_global(Vector3(0.5, 1.25, 0.25)).lerp(mouth3 + drop2.global_basis.z * 0.12, k3))
				if k3 >= 1.0:
					_lv["in3"] = true
					(car.get_node("Backpack") as Backpack)._taker.release(h)
					_lv["t"] = _t
			if _lv.has("in3") and _t - _lv["t"] > 1.0 and not _lv.has("done3"):
				_lv["done3"] = true
				cam.global_position = drop2.global_transform * Vector3(0.9, 1.6, -0.9)
				cam.look_at(drop2.global_transform * Vector3(0, 1.2, 0))
				_lv_shot("livraison_6_drapeau_leve")
				_lv_log("livraisons=%d ; livraison en cours=%s ; sachets restants %d" % [dm.delivered, str(dm.target), dm._bags_left()])
				_lv["phase"] = 4
				_lv["t"] = _t
		4:   # lieu du bord de la route : on y va (téléportations successives)
			var lot: Dictionary = _lv["lot"]
			dm.target = {"id": "lot:%d" % lot["id"], "kind": "", "s": float(lot["s0"]) + float(lot["length"]) * 0.5,
				"lateral": 6.0 + float(lot["depth"]) * 0.4, "qty": 1, "done": 0, "place": lot["type"]}
			var goal := float(lot["s0"]) - 25.0
			if cs < goal - 5.0:
				if _t - _lv["t"] > 0.4:
					_lv["t"] = _t
					_lv_place(road, minf(cs + 200.0, goal), 1.75)
				car.brake_input = 1.0
				return
			_lv["phase"] = 5
			_lv["t"] = _t
		5:
			car.brake_input = 1.0
			var site := road.find_child("Lot%d" % _lv["lot"]["id"], true, false) as Node3D
			if site == null:
				if _t - _lv["t"] > 3.0 and not _lv.has("nolot"):
					_lv["nolot"] = true
					_lv_log("ÉCHEC : lieu pas construit")
					get_tree().quit()
				return
			var dep: float = site.get("depth")
			var slen: float = site.get("length")
			var sx := site.global_transform
			if not _lv.has("lot_log"):
				_lv["lot_log"] = true
				var d3 := site.find_child("Drop", true, false) as DeliveryDrop
				_lv["drop3"] = d3
				_lv_log("lieu %s construit ; point de livraison %s (%s) actif=%s ; GPS %s" % [site.get("site_type"), d3 != null, d3.kind if d3 else "-", d3.active if d3 else false, str(dm.gps_info())])
				var ray := PhysicsRayQueryParameters3D.create(sx * Vector3(0, 3, dep * 0.4), sx * Vector3(0, -3, dep * 0.4))
				var hit := get_world_3d().direct_space_state.intersect_ray(ray)
				_lv_log("sol du lieu : %s ; route y=%.2f" % [("%s y=%.2f" % [hit["collider"].name, hit["position"].y]) if hit else "rien", sx.origin.y])
			var tl: float = _t - float(_lv["t"])
			if tl < 1.4:
				cam.global_position = sx * Vector3(-slen * 0.15, 15.0, -16.0)
				cam.look_at(sx * Vector3(0, 0, dep * 0.45))
				if tl > 1.2 and not _lv.has("ls1"):
					_lv["ls1"] = true
					_lv_shot("livraison_7_lieu_%s_vue" % site.get("site_type"))
				return
			if tl < 2.4:
				cam.global_position = sx * Vector3(-slen * 0.5 - 12.0, 1.8, -4.8)
				cam.look_at(sx * Vector3(-slen * 0.1, 2.5, dep * 0.4))
				if tl > 2.2 and not _lv.has("ls2"):
					_lv["ls2"] = true
					_lv_shot("livraison_8_lieu_%s_route" % site.get("site_type"))
				return
			if tl < 3.4:
				cam.global_position = sx * Vector3(slen * 0.35, 3.0, 2.0)
				cam.look_at(sx * Vector3(-slen * 0.1, 1.5, dep * 0.5))
				if tl > 3.2 and not _lv.has("ls3"):
					_lv["ls3"] = true
					_lv_shot("livraison_9_lieu_%s_parking" % site.get("site_type"))
				return
			var d3: DeliveryDrop = _lv.get("drop3")
			if d3 == null:
				_lv_log("ÉCHEC : pas de point de livraison")
				get_tree().quit()
				return
			if not _lv.has("bag4"):
				_lv["bag4"] = _lv_take(h)
				_lv["t4"] = _t
				return
			if not _lv.has("in4"):
				var bag4: DealerBag = _lv["bag4"]
				var mouth4 := d3._mouth()
				_lv_hold_at(h, bag4, mouth4 + (d3.global_basis.z * 0.12 if d3.kind == "mailbox" else Vector3.UP * 0.2))
				cam.global_position = d3.global_transform * Vector3(1.5, 2.0, 2.5)
				cam.look_at(d3.global_transform * Vector3(0, 0.8, 0))
				if _t - _lv["t4"] > 0.4:
					_lv["in4"] = true
					_lv_shot("livraison_10_lieu_point")
					(car.get_node("Backpack") as Backpack)._taker.release(h)
					_lv["t4"] = _t
				return
			if _t - _lv["t4"] > 1.2 and not _lv.has("done4"):
				_lv["done4"] = true
				_lv_log("livraisons=%d ratées=%d ; livraison en cours=%s" % [dm.delivered, dm.missed, str(dm.target)])
				dm._delay = 0.0
				_lv["t"] = _t
				_lv["phase"] = 6
		6:
			car.brake_input = 1.0
			if _t - _lv["t"] > 1.0:
				_lv_log("adresse suivante choisie : %s ; GPS %s" % [str(dm.target), str(dm.gps_info())])
				get_tree().quit()
