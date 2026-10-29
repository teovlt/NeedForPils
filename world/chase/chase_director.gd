class_name ChaseDirector
extends Node
## Histoire et déroulé de la partie : départ garé moteur coupé (voix d'intro), puis la
## route, où la police surgit au hasard (Pursuer : bas-côté, barrage, derrière) ; on
## peut la semer. Conseils, fin de partie. (L'ancienne intro cinématique existe encore
## derrière `play_intro`, désactivée.)
##
## Lore : la Pils, une pilule rose, a envahi la ville et la police traque tous ceux qui
## en ont. Tu t'enfuis avec un sachet de vingt. Une Pils te rend plus rapide... et
## chaque Pils te rend un peu plus accro.
## Deux fins : rattrapé par la police, ou assimilé (100 %) : perdu dans la Pils.
##
## Les textes s'affichent devant les yeux (Label3D collé à la caméra, invisible dans
## les rétros) : lisibles en VR comme en mode bureau. Chacun a sa voix
## (audio/voice/<identifiant>, VoiceLine ; liste dans audio/voice/A_ENREGISTRER.md) :
## le texte reste à l'écran le temps de la réplique, ou disparaît si
## `show_text_with_voice` est décoché et que la réplique est enregistrée. Espace / Entrée ou A / X pour
## passer l'intro ou rejouer.

const LORE := [
	["2049.", "La Pils est arrivée en ville. Une pilule rose. Tout le monde en a pris."],
	["LA POLICE", "Elle traque tous ceux qui en ont. Barrages, patrouilles, partout."],
	["TOI", "Tu viens de filer avec vingt Pils dans la boîte à gants."],
	["LA PILS", "Elle te rend plus rapide qu'eux. Mais chaque Pils te rend un peu plus accro."],
]

@export var car_path: NodePath
@export var pursuer_path: NodePath
@export var addiction_path: NodePath
@export var pills_path: NodePath
@export var play_intro := false
## Voix jouée au début de la partie, tant que le moteur n'est pas démarré.
@export_file("*.wav", "*.ogg", "*.mp3") var start_voice_path := "res://audio/voice/demarre.wav"
@export var start_voice_db := 0.0
## Délai (s) avant la voix, le temps que le joueur s'installe.
@export var start_voice_delay := 1.0
## Garder les textes à l'écran quand leur voix est enregistrée (sous-titres).
@export var show_text_with_voice := true
@export var voice_db := 0.0
@export_file("*.tscn") var menu_scene := "res://menu/main_menu.tscn"
## Secondes d'affichage de chaque écran de lore.
@export var lore_time := 5.5
## Durée du plan aérien (s) et vitesse du pilote automatique pendant l'intro (km/h).
@export var aerial_time := 10.0
@export var intro_speed := 95.0

var game_over := false

var _car: SUV4x4
var _pursuer: Pursuer
var _addiction: PillAddiction
var _pills: PillSpawner
var _co_running := false
var _skip := false
var _skip_down := false
var _title: Label3D
var _sub: Label3D
var _text_alpha := 0.0
var _text_target := 0.0
var _hint_done := {}
var _end_time := 0.0
var _autopilot := false
var _drone: Node3D
var _drone_t := 0.0
var _drone_fwd := Vector3.ZERO
var _origin: Node3D
var _trees: FallingTreeManager
## Concurrents (créés ici) ; NetSession les recopie chez le copilote.
var _rivals: Rivals
## Partie à deux, chez le copilote : rien ne se décide ici, on affiche les textes du
## conducteur (et Espace / A demande au conducteur de rejouer à la fin).
var net_puppet := false
var _voice_id := ""
var _voice_seq := 0
var _voice_heard := 0


func _ready() -> void:
	_car = get_node_or_null(car_path) as SUV4x4
	_pursuer = get_node_or_null(pursuer_path) as Pursuer
	_addiction = get_node_or_null(addiction_path) as PillAddiction
	_pills = get_node_or_null(pills_path) as PillSpawner
	_trees = get_tree().get_first_node_in_group(FallingTreeManager.GROUP) as FallingTreeManager
	if _pursuer:
		_pursuer.caught.connect(_on_caught)
		_pursuer.chase_started.connect(_on_chase_started)
		_pursuer.lost.connect(_on_police_lost)
	# concurrents (camping-car) : créés ici, pas besoin de les placer dans la scène
	var road := _pills.get_road() if _pills else null
	if road and _car:
		_rivals = Rivals.new()
		_rivals.name = "Rivals"
		add_child(_rivals)
		_rivals.road_path = _rivals.get_path_to(road)
		_rivals.car_path = _rivals.get_path_to(_car)
		_rivals._ready_links()
		_rivals.started.connect(_on_rivals_started)
		_rivals.lost.connect(_on_rivals_lost)
		_rivals.hit.connect(_on_rivals_hit)
		_rivals.killed.connect(_on_rivals_killed)
	if _addiction:
		_addiction.assimilated.connect(_on_assimilated)
		_addiction.pill_taken.connect(_on_pill_taken)
	_run_intro.call_deferred()


# --- Intro ---------------------------------------------------------------------------

func _run_intro() -> void:
	await get_tree().process_frame
	await get_tree().process_frame   # le joueur est installé au volant, la caméra existe
	if net_puppet:
		if _car and not _car.is_engine_running():
			_play_start_voice()
		return
	if not play_intro:
		_set_paused(true)
		await _wait_engine_start()
		if not is_inside_tree():
			return   # partie quittée (rejouer, menu) avant le démarrage
		_start_chase()
		return
	# Pendant l'intro, le 4x4 roule tout seul ; ni pilules, ni arbres, ni manque.
	_set_paused(true)
	_autopilot = true
	_set_curtain(1.0)
	for k in LORE.size():
		await _say(LORE[k][0], LORE[k][1], lore_time, "intro_lore_%d" % (k + 1))
		if _skip:   # une pression passe tout le lore
			break
	# Plan aérien : les deux voitures lancées sur la route.
	_begin_aerial()
	if _pursuer:
		_pursuer.start_escort(55.0)
	_fade_curtain(0.0, 1.2)
	await _say("ILS T'ONT TROUVÉ.", "La police est sur tes traces.", aerial_time * 0.45, "intro_trouve")
	if not _skip:
		await _say("ILS SE RAPPROCHENT.", "Ne ralentis jamais.", aerial_time * 0.45, "intro_rapprochent")
	# Fondu au noir, retour au volant.
	await _fade_curtain(1.0, 0.7)
	_end_aerial()
	_autopilot = false
	if _car:
		_car.external_input = false
	await _fade_curtain(0.0, 0.8)
	await _wait_engine_start()
	if not is_inside_tree():
		return   # partie quittée (rejouer, menu) avant le démarrage
	_start_chase()
	await _say("PRENDS LE VOLANT !", _controls_text(), 4.5, "intro_volant_vr" if _is_vr() else "intro_volant_clavier")


## Le 4x4 part moteur coupé : la poursuite ne commence qu'une fois le moteur
## démarré (il faut d'abord trouver les clés).
func _wait_engine_start() -> void:
	if _car == null or _car.is_engine_running():
		return
	_play_start_voice()
	while is_inside_tree() and not _car.is_engine_running():
		await get_tree().process_frame


## Voix du début (« trouve les clés, démarre… ») : à remplacer par ton enregistrement
## dans audio/voice/demarre.wav (même nom), ou changer start_voice_path.
func _play_start_voice() -> void:
	if not ResourceLoader.exists(start_voice_path):
		return
	var stream := load(start_voice_path) as AudioStream
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.name = "StartVoice"
	p.stream = stream
	p.volume_db = start_voice_db
	add_child(p)
	await get_tree().create_timer(start_voice_delay).timeout
	if is_instance_valid(p):
		p.play()
		print("Voix de départ : ", start_voice_path, " (%.1f s)" % stream.get_length())
		p.finished.connect(p.queue_free)


func _start_chase() -> void:
	if _car:
		_car.external_input = false
	if _pursuer:
		_pursuer.start_patrols()   # la police surgira au hasard sur la route
	if _rivals:
		_rivals.start()            # les concurrents aussi
	_set_paused(false)
	if _pills:
		_pills.start()
		_pills.spawn_at(170.0, _pills.lane_offset)   # une première pilule à portée
	if _trees:
		_trees.travelled = 0.0   # les arbres attendent de nouveau leur distance de sécurité
		_trees.enabled = true


func _set_paused(p: bool) -> void:
	if _addiction:
		_addiction.paused = p
	if _pills:
		_pills.enabled = not p
	if _trees and p:
		_trees.enabled = false


func _controls_text() -> String:
	if _is_vr():
		return "Gâchette droite : accélérer. Ne lâche pas l'accélérateur."
	return "Z : accélérer   ·   Q / D : tourner   ·   ne ralentis pas !"


func _is_vr() -> bool:
	return XRServer.primary_interface != null and XRServer.primary_interface.is_initialized()


## Pilote automatique de l'intro : tient sa voie à `intro_speed` km/h.
func _physics_process(delta: float) -> void:
	if _drone:
		_update_drone(delta)
	if not _autopilot or _car == null:
		return
	_car.external_input = true
	if _car.get_gear() != SUV4x4.Gear.D:
		_car.gear_lever.set_notch(SUV4x4.Gear.D, true)
	if _car.get_handbrake_amount() > 0.0:
		_car.handbrake_lever.set_angle_deg(0.0, true)
	var kmh := _car.forward_speed * 3.6
	_car.throttle_input = clampf((intro_speed - kmh) / 10.0, 0.0, 1.0)
	_car.brake_input = 0.0
	var road := _pills.get_road() if _pills else null
	if road:
		var look := road.sample_ahead(_car.global_position, 14.0)
		if look["found"]:
			var target: Vector3 = road.ground_position(look, _pills.lane_offset)
			var to := (target - _car.global_position).normalized()
			_car.external_steer = clampf(_car.global_basis.z.signed_angle_to(to, Vector3.UP) * 2.5, -1.0, 1.0)


# --- Plan aérien ------------------------------------------------------------------------
# Le point de vue du joueur (XROrigin3D) quitte le siège et suit un « drone » au-dessus
# des deux voitures. En VR, le drone reste à niveau (pas de tangage imposé) : on
# baisse la tête soi-même. En mode bureau, il descend en survolant la scène.

func _begin_aerial() -> void:
	if _car == null:
		return
	_origin = _car.driver_seat.get_node_or_null("XROrigin3D") as Node3D
	if _origin == null:
		return
	_drone = Node3D.new()
	_drone.name = "IntroDrone"
	get_parent().add_child(_drone)
	_drone_t = 0.0
	_drone_fwd = Vector3.ZERO
	_update_drone(0.0)
	_origin.reparent(_drone, false)
	_origin.transform = Transform3D.IDENTITY
	if _is_vr():
		_car.recenter_view()   # regard vers l'avant de la route, donc vers les voitures


func _end_aerial() -> void:
	if _origin and is_instance_valid(_origin):
		_origin.reparent(_car.driver_seat, false)
		_origin.transform = Transform3D.IDENTITY
	if _drone:
		_drone.queue_free()
		_drone = null
	if _is_vr():
		_car.recenter_view()


func _update_drone(delta: float) -> void:
	_drone_t += delta
	var k := smoothstep(0.0, 1.0, clampf(_drone_t / aerial_time, 0.0, 1.0))
	if _pursuer and _pursuer.state == Pursuer.State.ESCORT:
		_pursuer.set_escort_gap(lerpf(55.0, 28.0, k))   # elle se rapproche
	# Direction de la route (et non du 4x4, qui oscille avec le pilote automatique),
	# lissée : la caméra ne tourne que doucement dans les virages.
	var car_pos := _car.global_position
	var dir := _car.global_basis.z
	var road := _pills.get_road() if _pills else null
	if road:
		var s := road.sample_road(car_pos)
		if s["found"]:
			dir = s["dir"]
	dir.y = 0.0
	dir = dir.normalized()
	_drone_fwd = dir if _drone_fwd == Vector3.ZERO else _drone_fwd.slerp(dir, clampf(delta * 1.5, 0.0, 1.0)).normalized()
	var fwd := _drone_fwd
	var left := Vector3.UP.cross(fwd)
	var pursuer_pos := _pursuer.get_car_position() if _pursuer else car_pos - fwd * 50.0
	var mid := (car_pos + pursuer_pos) * 0.5
	if _is_vr():
		# À niveau (jamais de tangage imposé), derrière la poursuivante et en hauteur :
		# les deux voitures sont devant, un peu en dessous du regard.
		var p := pursuer_pos + Vector3.UP * 10.0 - fwd * 18.0
		_drone.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), p)
		return
	# Bureau : au-dessus de la route, derrière la poursuivante (jamais dans le relief du
	# bord de route), puis la caméra glisse jusque derrière le 4x4.
	var from := pursuer_pos + left * 3.0 + Vector3.UP * 12.0 - fwd * 22.0
	var to := car_pos + left * 2.0 + Vector3.UP * 6.0 - fwd * 13.0
	var pos := from.lerp(to, k)
	var look := (mid + fwd * 5.0).lerp(car_pos + fwd * 25.0, k)
	_drone.global_transform = Transform3D(Basis.looking_at(look - pos, Vector3.UP), pos)


# --- Boucle ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_ensure_labels()
	_text_alpha = move_toward(_text_alpha, _text_target, delta * 2.5)
	if _title:
		_title.modulate.a = _text_alpha
		_title.outline_modulate.a = _text_alpha
		_sub.modulate.a = _text_alpha
		_sub.outline_modulate.a = _text_alpha
	var pressed := _skip_pressed()
	if net_puppet:
		if pressed and not _skip_down and game_over:
			Net.request_restart()
		_skip_down = pressed
		return
	if pressed and not _skip_down:
		if game_over:
			Net.restart_game()   # partie à deux : le copilote recharge aussi
			return
		_skip = true
	_skip_down = pressed
	if game_over:
		_end_time += delta
		if _end_time > 20.0:
			if Net.is_online():
				Net.leave_to_menu()
			else:
				get_tree().change_scene_to_file(menu_scene)
		return
	if _pursuer and _addiction:
		var close := clampf((70.0 - _pursuer.gap) / 60.0, 0.0, 1.0) if _pursuer.state == Pursuer.State.CHASE else 0.0
		_addiction.chase = close
	_hints()


# --- Partie à deux ------------------------------------------------------------------

## Texte affiché chez le conducteur : [titre, sous-titre, visible, fin de partie, rideau,
## voix, numéro de la voix].
func net_text() -> Array:
	return [_title.text if _title else "", _sub.text if _sub else "", _text_target,
		game_over, _addiction.curtain if _addiction else 0.0, _voice_id, _voice_seq]


func net_apply_text(t: Array) -> void:
	_ensure_labels()
	if _title and (_title.text != t[0] or _sub.text != t[1]):
		_show(t[0], t[1])
	_text_target = t[2]
	game_over = t[3]
	if _addiction:
		_addiction.curtain = t[4]
	# la même voix que chez le conducteur
	if t.size() > 6 and int(t[6]) != _voice_heard:
		_voice_heard = int(t[6])
		if _voice_heard > 0:
			_voice(String(t[5]))


## Conseils affichés une seule fois, au bon moment.
func _hints() -> void:
	if _addiction == null or _pursuer == null or _pursuer.state != Pursuer.State.CHASE:
		return
	if _addiction.craving > 0.65:
		_hint_once("manque", "LE MANQUE", "Il te ralentit. Avale une Pils : le sachet est quelque part dans la voiture.")
	if _pursuer.gap < 45.0:
		_hint_once("proche", "ILS SONT DERRIÈRE TOI", "Une Pils = un boost. Avale-la.")
	if _addiction.assimilation >= 0.45:
		_hint_once("inversion", "TU CHANGES", "Sans Pils, tout devient flou. Tu ne peux plus t'en passer.")
	if _addiction.assimilation >= 0.8:
		_hint_once("presque", "ASSIMILATION " + str(roundi(_addiction.assimilation * 100.0)) + " %", "Encore quelques Pils et tu ne reviendras pas.")


func _hint_once(key: String, title: String, sub: String) -> void:
	if _hint_done.has(key) or _co_running:
		return
	_hint_done[key] = true
	_say(title, sub, 3.5, "conseil_" + key)


func _on_pill_taken(count: int) -> void:
	if net_puppet:
		return   # c'est le conducteur qui décide
	if count == 1 and not game_over:
		_hint_done["premiere"] = true
		_say("BOOST !", "Mais tu leur ressembles un peu plus...", 3.0, "pilule_boost")


func _on_chase_started(kind: String) -> void:
	if game_over:
		return
	var sub := "Sème-la : creuse l'écart jusqu'à ce qu'elle te perde."
	if kind == "barrage":
		sub = "Elle a démarré derrière toi. " + sub
	if not _hint_done.has("police"):
		_hint_done["police"] = true
		_say("LA POLICE !", sub, 3.5, "police_barrage" if kind == "barrage" else "police_debut")


func _on_police_lost() -> void:
	if not game_over and not _co_running:
		_say("SEMÉE !", "La police a perdu ta trace... pour l'instant.", 3.0, "police_semee")


func _on_rivals_started() -> void:
	if game_over:
		return
	if not _hint_done.has("rivaux"):
		_hint_done["rivaux"] = true
		_say("LES CONCURRENTS !", "Le camping-car veut ta came. Ils vont tirer : sème-les.", 3.5, "rivaux_debut")
	else:
		_say("ILS SONT REVENUS", "Le camping-car est derrière toi.", 2.5, "rivaux_retour")


func _on_rivals_lost() -> void:
	if not game_over and not _co_running:
		_say("SEMÉS !", "Le camping-car a disparu du rétro.", 3.0, "rivaux_semes")


func _on_rivals_hit(count: int) -> void:
	if game_over or _co_running:
		return
	var left := _rivals.max_hits - count
	if count == 1 or left <= 2:
		var vid := "rivaux_tir_premier" if count == 1 else "rivaux_tir_%d" % clampi(left, 1, 2)
		_say("ON TE TIRE DESSUS !", "Encore %d balle%s et c'est fini." % [left, "s" if left > 1 else ""], 1.6, vid)


func _on_rivals_killed() -> void:
	if _pursuer:
		_pursuer.stop()
	_end("ILS T'ONT EU.", "Les concurrents ont pris ta came.", "fin_rivaux")


# --- Fins ---------------------------------------------------------------------------------

func _on_caught() -> void:
	if net_puppet:
		return   # c'est le conducteur qui décide
	if _rivals:
		_rivals.stop()
	_end("ILS T'ONT RATTRAPÉ.", "La police t'a eu.", "fin_police")


func _on_assimilated() -> void:
	if net_puppet:
		return   # c'est le conducteur qui décide
	if _pursuer:
		_pursuer.stop()
	_end("PERDU DANS LA PILS.", "Tu souris. Tu ne sais plus pourquoi tu roulais.", "fin_assimile")


func _end(title: String, line: String, voice := "") -> void:
	if game_over:
		return
	game_over = true
	_end_time = 0.0
	if _addiction:
		_addiction.paused = true
		_addiction.chase = 0.0
	if _car:
		_car.external_input = true
		_car.throttle_input = 0.0
		_car.brake_input = 1.0
	var km := (_pills.travelled if _pills else 0.0) / 1000.0
	var pills := _addiction.pills_taken if _addiction else 0
	var assim := roundi((_addiction.assimilation if _addiction else 0.0) * 100.0)
	var stats := "%s\n%.1f km parcourus  ·  %d Pils  ·  assimilation %d %%" % [line, km, pills, assim]
	var deliveries := get_tree().get_first_node_in_group(DeliveryManager.GROUP) as DeliveryManager
	if deliveries and deliveries.delivered + deliveries.missed > 0:
		stats += "  ·  %d livraison%s" % [deliveries.delivered, "s" if deliveries.delivered > 1 else ""]
	_fade_curtain(0.85, 1.0)
	_show(title, stats + "\n\nEspace / A : rejouer")
	_end_voices(voice)


## Voix de la fin, puis « Espace / A : rejouer ».
func _end_voices(voice: String) -> void:
	var p := _voice(voice)
	if p:
		await p.finished
	if is_inside_tree() and game_over:
		_voice("fin_rejouer")


# --- Texte et rideau -----------------------------------------------------------------

func _say(title: String, sub: String, duration: float, voice := "") -> void:
	_co_running = true
	_skip = false
	_show(title, sub)
	_voice(voice)
	if voice != "" and not show_text_with_voice and VoiceLine.has_recording(voice):
		_text_target = 0.0   # la voix remplace le texte
	# le texte reste au moins le temps de la réplique
	duration = maxf(duration, VoiceLine.length(voice) + 0.4)
	var t := 0.0
	while t < duration and not _skip:
		t += get_process_delta_time()
		await get_tree().process_frame
	if _skip:
		VoiceLine.stop("narrateur")
	if not game_over:
		_text_target = 0.0
		var f := 0.0
		while f < 0.4:
			f += get_process_delta_time()
			await get_tree().process_frame
	_co_running = false


## Joue la voix (et la fait jouer chez le copilote). Renvoie le lecteur ou null.
func _voice(id: String) -> Node:
	if id == "":
		return null
	if not net_puppet:
		_voice_id = id
		_voice_seq += 1
	return VoiceLine.play(self, id, "narrateur", voice_db)


func _show(title: String, sub: String) -> void:
	_ensure_labels()
	if _title == null:
		return
	_title.text = title
	_sub.text = sub
	_text_alpha = 0.0
	_text_target = 1.0


func _set_curtain(v: float) -> void:
	if _addiction:
		_addiction.curtain = v


func _fade_curtain(to: float, duration: float) -> void:
	if _addiction == null:
		return
	var from := _addiction.curtain
	var t := 0.0
	while t < duration:
		t += get_process_delta_time()
		_addiction.curtain = lerpf(from, to, clampf(t / duration, 0.0, 1.0))
		await get_tree().process_frame


func _ensure_labels() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if _title and is_instance_valid(_title) and _title.get_parent() == cam:
		return
	if _title and is_instance_valid(_title):
		_title.queue_free()
		_sub.queue_free()
	_title = _make_label(cam, 64, Vector3(0.0, 0.3, -1.4))
	_sub = _make_label(cam, 30, Vector3(0.0, 0.16, -1.4))
	_sub.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_sub.width = 1100.0
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.modulate = Color(1.0, 0.45, 0.85, 0.0)


func _make_label(cam: Camera3D, size: int, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.font_size = size
	l.pixel_size = 0.0011
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0)
	l.modulate = Color(1, 1, 1, 0)
	l.no_depth_test = true
	l.shaded = false
	l.double_sided = true
	l.render_priority = 127
	l.outline_render_priority = 126
	l.layers = PillAddiction.OVERLAY_LAYER
	l.position = pos
	cam.add_child(l)
	return l


func _skip_pressed() -> bool:
	if Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_ESCAPE):
		return true
	for h in get_tree().get_nodes_in_group(VRHandInteractor.GROUP):
		if (h as VRHandInteractor).is_button_pressed(&"ax_button"):
			return true
	return false
