class_name ChaseDirector
extends Node
## Histoire et déroulé de la partie : intro (lore sur fond noir, puis plan aérien des
## deux voitures lancées sur la route, puis fondu dans l'habitacle : on prend le
## volant), poursuite, conseils, fin de partie.
##
## Lore : la Pils, une pilule rose, a transformé toute la ville en « Essaim ».
## Tu es le dernier qu'ils n'ont pas assimilé, et tu t'enfuis avec leur stock.
## Une Pils te rend plus rapide qu'eux... et un peu plus comme eux.
## Deux fins : rattrapé par l'Essaim, ou assimilé (100 %) : tu es devenu l'un d'eux.
##
## Les textes s'affichent devant les yeux (Label3D collé à la caméra, invisible dans
## les rétros) : lisibles en VR comme en mode bureau. Espace / Entrée ou A / X pour
## passer l'intro ou rejouer.

const LORE := [
	["2049.", "La Pils est arrivée en ville. Une pilule rose. Tout le monde en a pris."],
	["L'ESSAIM", "Ceux qui l'avalent sourient pareil, pensent pareil, roulent pareil."],
	["TOI", "Le dernier qu'ils n'ont pas assimilé. Et tu viens de voler leur stock."],
	["LA PILS", "Elle te rend plus rapide qu'eux. Mais chaque Pils te rend un peu plus comme eux."],
]

@export var car_path: NodePath
@export var pursuer_path: NodePath
@export var addiction_path: NodePath
@export var pills_path: NodePath
@export var play_intro := true
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
var _origin: Node3D
var _trees: FallingTreeManager


func _ready() -> void:
	_car = get_node_or_null(car_path) as SUV4x4
	_pursuer = get_node_or_null(pursuer_path) as Pursuer
	_addiction = get_node_or_null(addiction_path) as PillAddiction
	_pills = get_node_or_null(pills_path) as PillSpawner
	_trees = get_tree().get_first_node_in_group(FallingTreeManager.GROUP) as FallingTreeManager
	if _pursuer:
		_pursuer.caught.connect(_on_caught)
	if _addiction:
		_addiction.assimilated.connect(_on_assimilated)
		_addiction.pill_taken.connect(_on_pill_taken)
	_run_intro.call_deferred()


# --- Intro ---------------------------------------------------------------------------

func _run_intro() -> void:
	await get_tree().process_frame
	await get_tree().process_frame   # le joueur est installé au volant, la caméra existe
	if not play_intro:
		_start_chase()
		return
	# Pendant l'intro, le 4x4 roule tout seul ; ni pilules, ni arbres, ni manque.
	_set_paused(true)
	_autopilot = true
	_set_curtain(1.0)
	for line in LORE:
		await _say(line[0], line[1], lore_time)
		if _skip:   # une pression passe tout le lore
			break
	# Plan aérien : les deux voitures lancées sur la route.
	_begin_aerial()
	if _pursuer:
		_pursuer.start_escort(55.0)
	_fade_curtain(0.0, 1.2)
	await _say("ILS T'ONT TROUVÉ.", "L'Essaim est sur tes traces.", aerial_time * 0.45)
	if not _skip:
		await _say("ILS SE RAPPROCHENT.", "Ne ralentis jamais.", aerial_time * 0.45)
	# Fondu au noir, retour au volant.
	await _fade_curtain(1.0, 0.7)
	_end_aerial()
	_autopilot = false
	_start_chase()
	await _fade_curtain(0.0, 0.8)
	await _say("PRENDS LE VOLANT !", _controls_text(), 4.5)


func _start_chase() -> void:
	if _car:
		_car.external_input = false
	if _pursuer:
		_pursuer.start_chase()
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
	_update_drone(0.0)
	_origin.reparent(_drone, false)
	_origin.transform = Transform3D.IDENTITY


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
	var fwd := _car.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var left := Vector3.UP.cross(fwd)
	var car_pos := _car.global_position
	if _is_vr():
		# À niveau, en hauteur, un peu derrière et sur le côté : les deux voitures en dessous.
		var p := car_pos + left * 7.0 + Vector3.UP * 13.0 - fwd * 26.0
		_drone.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), p)
		return
	# Bureau : de côté et en hauteur, centré entre les deux voitures, puis la caméra
	# glisse derrière le 4x4.
	var pursuer_pos := _pursuer.get_car_position() if _pursuer else car_pos - fwd * 50.0
	var mid := (car_pos + pursuer_pos) * 0.5
	var from := mid + left * 30.0 + Vector3.UP * 15.0 - fwd * 6.0
	var to := car_pos + left * 3.0 + Vector3.UP * 6.0 - fwd * 13.0
	var pos := from.lerp(to, k)
	var look := mid.lerp(car_pos + fwd * 25.0, k)
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
	if pressed and not _skip_down:
		if game_over:
			get_tree().reload_current_scene()
			return
		_skip = true
	_skip_down = pressed
	if game_over:
		_end_time += delta
		if _end_time > 20.0:
			get_tree().change_scene_to_file(menu_scene)
		return
	if _pursuer and _addiction:
		var close := clampf((70.0 - _pursuer.gap) / 60.0, 0.0, 1.0) if _pursuer.state == Pursuer.State.CHASE else 0.0
		_addiction.chase = close
	_hints()


## Conseils affichés une seule fois, au bon moment.
func _hints() -> void:
	if _addiction == null or _pursuer == null or _pursuer.state != Pursuer.State.CHASE:
		return
	if _addiction.craving > 0.65:
		_hint_once("manque", "LE MANQUE", "Il te ralentit. Trouve une Pils : suis le faisceau rose.")
	if _pursuer.gap < 45.0:
		_hint_once("proche", "ILS SONT DERRIÈRE TOI", "Une Pils = un boost. Avale-la.")
	if _addiction.assimilation >= 0.45:
		_hint_once("inversion", "TU CHANGES", "Sans Pils, tout devient flou. Tu deviens l'un d'eux.")
	if _addiction.assimilation >= 0.8:
		_hint_once("presque", "ASSIMILATION " + str(roundi(_addiction.assimilation * 100.0)) + " %", "Encore quelques Pils et tu seras l'Essaim.")


func _hint_once(key: String, title: String, sub: String) -> void:
	if _hint_done.has(key) or _co_running:
		return
	_hint_done[key] = true
	_say(title, sub, 3.5)


func _on_pill_taken(count: int) -> void:
	if count == 1 and not game_over:
		_hint_done["premiere"] = true
		_say("BOOST !", "Mais tu leur ressembles un peu plus...", 3.0)


# --- Fins ---------------------------------------------------------------------------------

func _on_caught() -> void:
	_end("ILS T'ONT RATTRAPÉ.", "L'Essaim t'a eu.")


func _on_assimilated() -> void:
	if _pursuer:
		_pursuer.stop()
	_end("TU ES L'ESSAIM.", "Tu souris. Comme eux.")


func _end(title: String, line: String) -> void:
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
	_fade_curtain(0.85, 1.0)
	_show(title, stats + "\n\nEspace / A : rejouer")


# --- Texte et rideau -----------------------------------------------------------------

func _say(title: String, sub: String, duration: float) -> void:
	_co_running = true
	_skip = false
	_show(title, sub)
	var t := 0.0
	while t < duration and not _skip:
		t += get_process_delta_time()
		await get_tree().process_frame
	if not game_over:
		_text_target = 0.0
		var f := 0.0
		while f < 0.4:
			f += get_process_delta_time()
			await get_tree().process_frame
	_co_running = false


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
