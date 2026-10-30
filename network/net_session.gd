class_name NetSession
extends Node
## Synchronisation d'une partie à deux (ajoutée par main.gd quand Net.is_online()).
##
## - Conducteur : la voiture roule chez lui. Il envoie à chaque image physique sa
##   position et ce qu'affiche le tableau de bord (vitesse, régime...), et deux fois par
##   seconde l'état des commandes (vitesse engagée, comodos, frein à main), la météo...
## - Copilote : sa voiture ne conduit pas (ni moteur ni boîte) ; elle est recalée à
##   chaque image sur celle du conducteur, avec ~0,1 s de retard pour pouvoir
##   interpoler en douceur. La police, les arbres qui tombent, les animaux et les
##   textes de l'histoire sont décidés chez le conducteur et recopiés chez lui. Il peut
##   tout toucher (volant, vitesses...) mais pas les pédales : son clavier envoie au
##   conducteur la direction et le frein arrière, jamais l'accélérateur ni le frein.
## - Les positions dans le monde passent en coordonnées « absolues » (+ world_offset de
##   la route) : chacun recentre son monde tous les 1,5 km, pas forcément à la même image.
## - Les deux : chacun envoie sa tête et ses mains (repère de la voiture) et chaque
##   saisie / lâcher / action. Chez l'autre, un avatar les montre et des mains
##   « fantômes » (NetRemoteHand) rejouent les gestes sur les mêmes objets : saisies,
##   prises du bout de l'index, et appuis au toucher (klaxon, radio, comodos). Un objet
##   lâché ne retombe pas forcément pareil chez les deux : celui qui l'a lâché envoie
##   ensuite où il s'est posé.
## - Tous les messages de position sont datés avec le temps de simulation (Net.sim_time)
##   et rejoués un peu dans le passé (NetClock) : voiture, tête et mains de l'autre
##   joueur glissent entre deux messages au lieu de sauter de l'un à l'autre, et ses
##   gestes (saisir, lâcher) arrivent au moment où sa main affichée y est.
## - Objets en vrac dans la voiture : le conducteur fait foi. Le copilote ne les fait plus
##   glisser ni sauter lui-même (chaque machine les faisait bouger à sa façon) : il
##   reçoit leurs places (on_items), sauf ceux qu'il vient de lâcher, qu'il pose lui-même.
## - Radio : le copilote cale le morceau et sa position sur ceux du conducteur.
## - Consommer (pilule, cigarette, joint, bière, café) à la bouche de l'autre joueur :
##   la machine de la main qui tient l'objet décide et prévient l'autre (Net.feed ->
##   on_feed), qui applique l'effet à son joueur.
## - Bonnet mis sur une tête : la machine qui le lâche décide (Net.wear -> on_wear).

enum HandEvent { GRAB, RELEASE, TOGGLE, BUTTON }

## Au-delà de la dernière position reçue, on prolonge le mouvement au plus ce temps (s).
const MAX_EXTRAPOLATION := 0.25
## Fréquence d'envoi de la voiture et de la tête et des mains (par seconde) : la moitié
## de l'image du casque (72 Hz) suffit, l'autre machine interpole entre deux messages ;
## deux fois moins de paquets dans le Wi-Fi (moins de gigue) et moins de travail.
const POSE_RATE := 36.0
## Fréquence d'envoi des animaux (par seconde).
const ANIMAL_RATE := 15.0
## Fréquence d'envoi des objets en vrac qui bougent (par seconde), et de tous (rattrapage).
const ITEM_RATE := 15.0
const ITEM_FULL_PERIOD := 2.0
## Le copilote rapproche l'objet de la place reçue à cette vitesse (1/s).
const ITEM_FOLLOW_RATE := 18.0
## Délai (s) après un lâcher avant d'envoyer la position où l'objet s'est posé.
const ITEM_REST_DELAY := 2.0
## Méthodes qu'un message de l'autre joueur a le droit d'appeler (raccourcis clavier).
const ALLOWED_CALLS := ["toggle", "press", "unpress", "_key_shortcut", "_press", "toggle_power", "set_volume",
	"set_notch", "step", "net_roll", "net_receive"]

var car: SUV4x4
var _road: RoadGenerator
var _pursuer: Pursuer
var _director: ChaseDirector
var _trees: FallingTreeManager
var _animals: AnimalManager
var _rivals: Rivals
var _deliveries: DeliveryManager
var remote_player: Node3D
var _remote_head: Node3D
## Yeux (caméra non active) de l'autre joueur : sa bouche (Net.other_head).
var remote_eyes: Camera3D
var _avatar: NetAvatar
var _remote_hand_meshes: Array[Node3D] = []
var _remote_hands: Array[NetRemoteHand] = []
var _remote_head_local := Transform3D.IDENTITY
var _remote_hand_local: Array = [null, null, null]   # gauche, droite, souris
var _remote_touch: Array = [null, null]   # mains VR : [peut toucher, bout de l'index, paume, main affichée]
var _remote_posed := [false, false]       # poing refermé sur une commande (pose appliquée)
var _grip_poses: Array = []               # pose « poing » des mains XR Tools (gauche, droite)
## Mains XR Tools affichées pour l'autre joueur (les mêmes que les nôtres).
const HAND_SCENES := ["res://addons/godot-xr-tools/hands/scenes/lowpoly/left_hand_low.tscn",
	"res://addons/godot-xr-tools/hands/scenes/lowpoly/right_hand_low.tscn"]

var _local_hands := {}            # main locale -> indice (0 gauche, 1 droite, 2 souris)
var _snapshots: Array = []        # copilote : [temps conducteur, Transform3D, vitesse, vitesse angulaire, police, rivaux, message]
var _car_clock := NetClock.new()
var _pose_clock := NetClock.new()
var _poses: Array = []            # [temps de l'autre, pose]
var _hand_events: Array = []      # gestes de l'autre en attente : [temps de l'autre, arguments]
var _items_timer := 0.0
var _items_full_timer := 0.0
var _item_list: Array = []        # conducteur : objets de la voiture (rafraîchi chaque seconde)
var _item_list_timer := 0.0
var _item_sent := {}              # conducteur : id -> [chemin du parent, transformation envoyée]
var _item_names := {}             # copilote : nom -> objet
var _followed: Array = []         # copilote : objets qui suivent les places reçues
var _world_timer := 0.0
var _animal_timer := 0.0
var _last_text: Array = []
var _props_sig := ""
var _controls_sent := [0.0, false]
var _controls_timer := 0.0
var _car_send_t := 0.0
var _pose_send_t := 0.0
var _hands_scan_t := 0.0


func _ready() -> void:
	Net.session = self
	car = get_tree().get_first_node_in_group(SUV4x4.GROUP) as SUV4x4
	if car == null:
		push_warning("NetSession : pas de voiture dans la scène")
		return
	var main := get_parent()
	_road = main.get_node_or_null("RoadGenerator") as RoadGenerator
	_pursuer = main.get_node_or_null("Pursuer") as Pursuer
	_director = main.get_node_or_null("ChaseDirector") as ChaseDirector
	_trees = main.get_node_or_null("FallingTrees") as FallingTreeManager
	_animals = main.get_node_or_null("RoadGenerator/Animals") as AnimalManager
	_deliveries = main.get_node_or_null("RoadGenerator/Deliveries") as DeliveryManager
	_rivals = _director._rivals if _director else null
	_car_clock.send_interval = 1.0 / POSE_RATE
	_pose_clock.send_interval = 1.0 / POSE_RATE
	if Net.is_copilot():
		# le copilote applique la position reçue avant que le reste de la scène bouge
		process_physics_priority = -100
		_setup_copilot()
	else:
		process_physics_priority = 100   # après la physique de la voiture
		if _trees:
			_trees.tree_falling.connect(_on_host_tree)
		if _rivals:
			_rivals.net_event.connect(func(kind: String, data: Array):
				if Net.is_online():
					Net.rx_rivals_fx.rpc(kind, data))
	# la pose des mains part en fin d'image physique, une fois les mains placées
	var late := _LateSender.new()
	late.session = self
	add_child(late)
	if "--net-test" in OS.get_cmdline_user_args():
		var test: Node = preload("res://network/net_autotest.gd").new()
		test.set("session", self)
		add_child(test)


func _exit_tree() -> void:
	if Net.session == self:
		Net.session = null


## L'autre joueur a quitté la partie (le conducteur continue seul).
func on_remote_left() -> void:
	for h in _remote_hands:
		_release_proxy(h)
	if remote_player:
		remote_player.queue_free()
		remote_player = null
	_remote_hands.clear()
	_remote_hand_meshes.clear()
	car.remote_steer = 0.0
	car.remote_rear_brake = false


func _setup_copilot() -> void:
	# Pas figée (un VehicleBody3D figé donne des roues en NaN) : la voiture garde sa
	# physique mais elle est recalée à chaque image physique sur celle du conducteur,
	# avec sa vitesse (les roues tournent et les suspensions travaillent).
	car.net_puppet = true
	car.engine_force = 0.0
	if _pursuer:
		_pursuer.net_puppet = true
	if _director:
		_director.net_puppet = true
	if _trees:
		_trees.enabled = false   # les arbres viennent du conducteur
	if _animals:
		_animals.net_puppet = true
	if _deliveries:
		_deliveries.net_puppet = true   # les adresses viennent du conducteur
	var pills := get_parent().get_node_or_null("Pills")
	if pills:
		pills.process_mode = Node.PROCESS_MODE_DISABLED   # pilules sur la route : pas encore recopiées
	var weather := get_tree().get_first_node_in_group(WeatherSystem.GROUP)
	if weather:
		weather.set("random_events", false)


# --- Boucle -----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if car == null or not Net.is_online():
		return
	_hands_scan_t -= delta
	if _hands_scan_t <= 0.0:
		_hands_scan_t = 0.5   # (mains apparues : rare, pas besoin de chercher à chaque image)
		_find_local_hands()
	if Net.is_copilot():
		_apply_car()
		_send_controls(delta)
		_follow_items(delta)
	else:
		_car_send_t -= delta
		if _car_send_t <= 0.0:
			_car_send_t += 1.0 / POSE_RATE
			_car_send_t = maxf(_car_send_t, 0.0)
			_send_car()
		_send_items(delta)
		_world_timer -= delta
		if _world_timer <= 0.0:
			_world_timer = 0.5
			Net.rx_world.rpc(_world_state())
		_send_world_events(delta)
	_update_remote_hands()


class _LateSender extends Node:
	var session: NetSession

	func _ready() -> void:
		process_physics_priority = 1000

	func _physics_process(delta: float) -> void:
		if session.car and Net.is_online():
			session._pose_send_t -= delta
			if session._pose_send_t <= 0.0:
				session._pose_send_t = maxf(session._pose_send_t + 1.0 / POSE_RATE, 0.0)
				session._send_pose()


## Décalage du monde local (recentrages de la route) : absolu = local + décalage.
func _offset() -> Vector3:
	return _road.world_offset if _road else Vector3.ZERO


func _to_abs(xf: Transform3D) -> Transform3D:
	xf.origin += _offset()
	return xf


func _from_abs(xf: Transform3D) -> Transform3D:
	xf.origin -= _offset()
	return xf


# --- Voiture : conducteur -> copilote -------------------------------------------------

func _send_car() -> void:
	var w := car.steering_wheel
	var police := []
	if _pursuer:
		police = _pursuer.net_state()
		police[1] = _to_abs(police[1])
	var rivals := []
	if _rivals:
		rivals = _rivals.net_state()
		rivals[1] = _to_abs(rivals[1])
	Net.rx_car.rpc([Net.sim_time, _to_abs(car.global_transform), car.linear_velocity, car.forward_speed,
		car.throttle_input, car.brake_input, car.auto_gear, car.shift_timer, car.engine_state,
		w.input_target_angle / deg_to_rad(w.max_rotation_deg), car.angular_velocity, police, rivals])


func on_car(data: Array) -> void:
	if not Net.is_copilot() or data.size() < 13:
		return
	var t: float = data[0]
	_car_clock.sample(t, Net.sim_time)
	if not _snapshots.is_empty() and t <= _snapshots[-1][0]:
		return
	_snapshots.append([t, data[1], data[2], data[10], data[11], data[12], data])
	while _snapshots.size() > 40:
		_snapshots.pop_front()


## Position de la voiture du copilote : courbe d'Hermite entre les deux messages qui
## encadrent l'instant affiché (positions et vitesses : pas de cassure de trajectoire
## à chaque message), orientation interpolée.
func _apply_car() -> void:
	if _snapshots.is_empty() or not _car_clock.is_ready():
		return
	var rt := _car_clock.render_time(Net.sim_time)
	while _snapshots.size() > 2 and _snapshots[1][0] <= rt:
		_snapshots.pop_front()
	var a: Array = _snapshots[0]
	var xf: Transform3D = a[1]
	var vel: Vector3 = a[2]
	var ang: Vector3 = a[3]
	var police: Array = a[4]
	var police_xf: Transform3D = police[1] if not police.is_empty() else Transform3D.IDENTITY
	var rivals: Array = a[5]
	var rivals_xf: Transform3D = rivals[1] if not rivals.is_empty() else Transform3D.IDENTITY
	var shown: Array = a[6]
	if _snapshots.size() >= 2 and rt >= a[0]:
		var b: Array = _snapshots[1]
		var span: float = b[0] - a[0]
		var w := clampf((rt - a[0]) / span, 0.0, 1.0) if span > 0.0 else 1.0
		if rt > b[0]:
			# plus de message assez récent : on prolonge un peu le mouvement
			xf = b[1]
			xf.origin += (b[2] as Vector3) * minf(rt - b[0], MAX_EXTRAPOLATION)
			vel = b[2]
			ang = b[3]
		else:
			var p0: Vector3 = (a[1] as Transform3D).origin
			var p1: Vector3 = (b[1] as Transform3D).origin
			var w2 := w * w
			var w3 := w2 * w
			var pos := p0 * (2.0 * w3 - 3.0 * w2 + 1.0) + (a[2] as Vector3) * span * (w3 - 2.0 * w2 + w) \
				+ p1 * (-2.0 * w3 + 3.0 * w2) + (b[2] as Vector3) * span * (w3 - w2)
			var b0 := (a[1] as Transform3D).basis.orthonormalized()
			xf = Transform3D(b0.slerp((b[1] as Transform3D).basis.orthonormalized(), w), pos)
			vel = (a[2] as Vector3).lerp(b[2], w)
			ang = (a[3] as Vector3).lerp(b[3], w)
		var pb: Array = b[4]
		if not police.is_empty() and not pb.is_empty():
			police_xf = police_xf.interpolate_with(pb[1], w) if police[0] and pb[0] else pb[1]
			police = pb
		var rb: Array = b[5]
		if not rivals.is_empty() and not rb.is_empty():
			rivals_xf = rivals_xf.interpolate_with(rb[1], w) if rivals[0] and rb[0] else rb[1]
			rivals = rb
		shown = b[6]
	if _pursuer and not police.is_empty():
		_pursuer.net_apply(police, _from_abs(police_xf))
	if _rivals and not rivals.is_empty():
		_rivals.net_apply(rivals, _from_abs(rivals_xf))
	car.global_transform = _from_abs(xf)
	car.linear_velocity = vel
	car.angular_velocity = ang
	car.engine_force = 0.0
	# tableau de bord et volant : ceux du message affiché (pas du dernier reçu, en avance)
	car.forward_speed = shown[3]
	car.throttle_input = shown[4]
	car.brake_input = shown[5]
	car.auto_gear = shown[6]
	car.shift_timer = shown[7]
	car.engine_state = shown[8]
	car.external_steer = shown[9]


# --- Police, arbres, animaux, textes (conducteur -> copilote) --------------------------

func _send_world_events(delta: float) -> void:
	if _animals:
		_animal_timer -= delta
		if _animal_timer <= 0.0:
			_animal_timer = 1.0 / ANIMAL_RATE
			var list := _animals.net_state()
			var off := _offset()
			for e in list:
				e[3] += off
			Net.rx_animals.rpc(list)
	if _pursuer:
		var props := _pursuer.net_props()
		var sig := str(props.size()) + (str(props[0][1].origin.snapped(Vector3.ONE * 0.1)) if not props.is_empty() else "")
		if sig != _props_sig:
			_props_sig = sig
			for e in props:
				e[1] = _to_abs(e[1])
			Net.rx_props.rpc(props)
	if _director:
		var t := _director.net_text()
		t[4] = snappedf(t[4], 0.05)
		if t != _last_text:
			_last_text = t
			Net.rx_text.rpc(t)


func _on_host_tree(tree: FallingTree) -> void:
	if not Net.is_online():
		return
	Net.rx_tree.rpc({
		"base": tree.global_position + _offset(), "basis": tree.global_basis,
		"species": tree.get_meta("species", "tree"), "height": tree.height, "yaw": tree.visual_yaw,
		"road_point": tree.road_point + _offset(), "road_dir": tree.road_dir, "blocked": tree.blocked_lateral,
	})


func on_tree(p: Dictionary) -> void:
	if not Net.is_copilot() or _trees == null:
		return
	p["base"] -= _offset()
	p["road_point"] -= _offset()
	_trees.spawn_remote(p)


func on_props(list: Array) -> void:
	if not Net.is_copilot() or _pursuer == null or _road == null:
		return
	_pursuer.net_set_props(list, func(xf_abs: Transform3D) -> Array:
		var xf := _from_abs(xf_abs)
		return [_road.chunk_at(xf.origin), xf])


func on_animals(list: Array) -> void:
	if not Net.is_copilot() or _animals == null:
		return
	var off := _offset()
	_animals.net_sync(list, func(p: Vector3) -> Vector3: return p - off)


func on_rivals_fx(kind: String, data: Array) -> void:
	if Net.is_copilot() and _rivals:
		_rivals.net_fx(kind, data)


func on_text(t: Array) -> void:
	if Net.is_copilot() and _director:
		_director.net_apply_text(t)


# --- Clavier du copilote : direction et frein arrière, jamais les pédales --------------

func _send_controls(delta: float) -> void:
	var steer := car.keyboard_steer_target() if car.keyboard_controls else 0.0
	var rear := car.keyboard_controls and Input.is_key_pressed(KEY_SPACE)
	_controls_timer -= delta
	if steer != _controls_sent[0] or rear != _controls_sent[1] or _controls_timer <= 0.0:
		_controls_sent = [steer, rear]
		_controls_timer = 0.5
		Net.rx_controls.rpc(steer, rear)


func on_controls(steer: float, rear_brake: bool) -> void:
	if Net.is_driver():
		car.remote_steer = clampf(steer, -1.0, 1.0)
		car.remote_rear_brake = rear_brake


# --- État des commandes et du monde (conducteur -> copilote) ---------------------------

func _world_state() -> Dictionary:
	var st := {
		"gear": car.gear_lever.notch,
		"wiper": car.wiper_stalk.notch,
		"light": car.light_stalk.notch,
		"hb": rad_to_deg(car.handbrake_lever.angle),
	}
	var weather := get_tree().get_first_node_in_group(WeatherSystem.GROUP)
	if weather:
		st["weather"] = weather.get("weather_id")
		st["hour"] = weather.get("hour")
	var addiction := car.get_addiction()
	if addiction:
		st["paused"] = addiction.paused
	if _deliveries:
		st["deliv"] = _deliveries.net_state()
	if car.radio and car.radio.has_method("net_state"):
		st["radio"] = car.radio.net_state()
	return st


func on_world(st: Dictionary) -> void:
	if not Net.is_copilot() or car == null:
		return
	# une commande que quelqu'un tient suit déjà sa main : on ne la corrige pas
	if not car.gear_lever.is_grabbed() and car.gear_lever.notch != st.get("gear", car.gear_lever.notch):
		car.gear_lever.set_notch(st["gear"])
	if not car.wiper_stalk.is_grabbed() and car.wiper_stalk.notch != st.get("wiper", car.wiper_stalk.notch):
		car.wiper_stalk.set_notch(st["wiper"])
	if not car.light_stalk.is_grabbed() and car.light_stalk.notch != st.get("light", car.light_stalk.notch):
		car.light_stalk.set_notch(st["light"])
	var hb: float = st.get("hb", 0.0)
	if not car.handbrake_lever.is_grabbed() and absf(rad_to_deg(car.handbrake_lever.angle) - hb) > 1.5:
		car.handbrake_lever.set_angle_deg(hb)
	var weather := get_tree().get_first_node_in_group(WeatherSystem.GROUP)
	if weather and st.has("weather"):
		if weather.get("weather_id") != st["weather"]:
			weather.call("set_weather", st["weather"])
		if absf(float(weather.get("hour")) - float(st["hour"])) > 0.05:
			weather.set("hour", st["hour"])
	var addiction := car.get_addiction()
	if addiction and st.has("paused"):
		addiction.paused = st["paused"]
	if _deliveries and st.has("deliv"):
		_deliveries.net_apply(st["deliv"])
	if st.has("radio") and car.radio and car.radio.has_method("net_apply"):
		car.radio.net_apply(st["radio"], _latency())


## Temps (s) que met un message pour arriver (moitié de l'aller-retour mesuré par ENet).
func _latency() -> float:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null:
		return 0.0
	var p := peer.get_peer(1)
	if p == null:
		return 0.0
	return p.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME) / 2000.0


## L'autre joueur a livré un sachet.
func on_delivered(target_id: String, bag_name: String) -> void:
	if _deliveries:
		_deliveries.net_delivered(target_id, bag_name)


# --- Mains locales -> autre joueur ----------------------------------------------------

func _find_local_hands() -> void:
	for h in get_tree().get_nodes_in_group(VRHandInteractor.GROUP):
		if not _local_hands.has(h):
			_local_hands[h] = 0 if (h as VRHandInteractor).is_left() else 1
			h.connect("interacted", _on_local_interaction.bind(h))
			h.connect("tip_interacted", _on_local_tip.bind(h))
	for h in get_tree().get_nodes_in_group(MouseHand.GROUP):
		if h is MouseHand and not _local_hands.has(h):
			_local_hands[h] = 2
			h.connect("interacted", _on_local_interaction.bind(h))
	for h in _local_hands.keys():
		if not is_instance_valid(h):
			_local_hands.erase(h)


func _hand_active(h: Node3D) -> bool:
	if h is VRHandInteractor:
		var vh := h as VRHandInteractor
		return (vh.controller != null and vh.controller.get_has_tracking_data()) or not vh.debug_points.is_empty()
	return h.is_inside_tree() and h.is_physics_processing()


func _send_pose() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var inv := car.global_transform.affine_inverse()
	var hands: Array = [null, null, null]
	var touch: Array = [null, null]
	for h in _local_hands:
		if is_instance_valid(h) and _hand_active(h):
			var i: int = _local_hands[h]
			hands[i] = inv * (h as Node3D).global_transform
			if h is VRHandInteractor:
				var vh := h as VRHandInteractor
				var vis := vh.visual_state()
				if not vis.is_empty():
					vis[0] = inv * (vis[0] as Transform3D)
				touch[i] = [vh.can_touch(), inv * vh.fingertip_position(), inv * vh.palm_position(), vis]
	Net.rx_pose.rpc([inv * cam.global_transform, hands[0], hands[1], hands[2], touch[0], touch[1], Net.sim_time])


func _on_local_interaction(kind: int, target: Node, hand: Node3D) -> void:
	if not Net.is_online() or not is_instance_valid(target) or not _local_hands.has(hand):
		return
	var path := String(get_parent().get_path_to(target))
	Net.rx_hand.rpc(_local_hands[hand], kind, path, car.global_transform.affine_inverse() * hand.global_transform, Net.sim_time,
		_release_velocity(kind, target))
	if kind == HandEvent.RELEASE and target is VRPickable:
		var item := (target as VRPickable).item
		_mark_local_release(item)
		get_tree().create_timer(ITEM_REST_DELAY).timeout.connect(_send_item_rest.bind(item))


## Prise du bout de l'index : rejouée par le doigt fantôme 3 (gauche) ou 4 (droit).
func _on_local_tip(kind: int, target: Node, hand: VRHandInteractor) -> void:
	if not Net.is_online() or not is_instance_valid(target) or not _local_hands.has(hand):
		return
	var path := String(get_parent().get_path_to(target))
	Net.rx_hand.rpc(3 + _local_hands[hand], kind, path, car.global_transform.affine_inverse() * hand.tip_hand.global_transform, Net.sim_time,
		_release_velocity(kind, target))
	if kind == HandEvent.RELEASE and target is VRPickable:
		_mark_local_release((target as VRPickable).item)
		get_tree().create_timer(ITEM_REST_DELAY).timeout.connect(_send_item_rest.bind((target as VRPickable).item))


## Lâcher : vitesse de l'objet par rapport à la voiture (repère de la voiture), pour
## que l'autre machine le lance pareil (elle calculait sa propre vitesse d'après la
## main affichée, en retard : un objet posé pouvait partir par la fenêtre).
func _release_velocity(kind: int, target: Node) -> Vector3:
	if kind != HandEvent.RELEASE or not target is VRPickable:
		return Vector3.ZERO
	return car.global_basis.inverse() * ((target as VRPickable).hand_velocity - car.linear_velocity)


## Copilote : objet qu'il vient de lâcher ; il le fait tomber et le pose lui-même
## (les places envoyées par le conducteur sont ignorées) jusqu'à ce qu'il soit posé.
func _mark_local_release(item: RigidBody3D) -> void:
	if Net.is_copilot() and is_instance_valid(item):
		item.set_meta("net_local_until", Net.sim_time + ITEM_REST_DELAY + 1.5)
		_followed.erase(item)
		if item.has_meta("net_xf"):
			item.remove_meta("net_xf")


## Partie à deux, copilote : l'objet suit les places envoyées par le conducteur ; la
## physique simplifiée des rangements (CarStorage, StorageZone) ne le bouge pas.
static func follows_host(item: Node) -> bool:
	if not Net.is_online() or not Net.is_copilot():
		return false
	return float(item.get_meta("net_local_until", -1.0)) < Net.sim_time


# --- Objets en vrac : conducteur -> copilote ---------------------------------------------

func _send_items(delta: float) -> void:
	_item_list_timer -= delta
	if _item_list_timer <= 0.0:
		_item_list_timer = 1.0
		_item_list.clear()
		for n in car.find_children("*", "RigidBody3D", true, false):
			if n.get_node_or_null("Grab") is VRPickable:
				_item_list.append(n)
	_items_timer -= delta
	if _items_timer > 0.0:
		return
	_items_timer = 1.0 / ITEM_RATE
	_items_full_timer -= 1.0 / ITEM_RATE
	var full := _items_full_timer <= 0.0
	if full:
		_items_full_timer = ITEM_FULL_PERIOD
	var list := []
	for item in _item_list:
		if not is_instance_valid(item) or not item.is_inside_tree() or not car.is_ancestor_of(item):
			continue
		var grab := item.get_node_or_null("Grab") as VRInteractable
		if grab and grab.is_grabbed():
			continue
		if float(item.get_meta("net_remote_until", -1.0)) > Net.sim_time:
			continue   # lâché par le copilote : il le pose lui-même
		if item.has_meta(DockerCap.WORN_META):
			continue   # sur une tête : il la suit chez les deux
		var parent_path := String(car.get_path_to(item.get_parent()))
		var xf: Transform3D = item.transform
		var last: Array = _item_sent.get(item.get_instance_id(), [])
		if not full and not last.is_empty() and last[0] == parent_path 				and (last[1] as Transform3D).origin.distance_to(xf.origin) < 0.002 				and ((last[1] as Transform3D).basis.get_rotation_quaternion().angle_to(xf.basis.get_rotation_quaternion())) < 0.03:
			continue
		_item_sent[item.get_instance_id()] = [parent_path, xf]
		list.append([String(item.name), parent_path, xf])
	if not list.is_empty():
		Net.rx_items.rpc(list)


func on_items(list: Array) -> void:
	if not Net.is_copilot() or car == null:
		return
	for e in list:
		var item := _item_named(e[0])
		if item == null or not follows_host(item) or item.has_meta(DockerCap.WORN_META):
			continue
		var grab := item.get_node_or_null("Grab") as VRInteractable
		if grab and grab.is_grabbed():
			continue
		var parent := car.get_node_or_null(NodePath(e[1])) as Node3D
		if parent == null:
			continue
		if item.get_parent() != parent:
			if item.get_parent() is StorageZone:
				(item.get_parent() as StorageZone).on_item_taken(item)
			item.reparent(parent, false)
			item.transform = e[2]
		item.top_level = false
		ItemPhysics.stop(item)   # sa simulation reprendra de la place reçue
		item.set_meta("net_xf", e[2])
		if not _followed.has(item):
			_followed.append(item)


## Rapproche en douceur les objets suivis de leur dernière place reçue.
func _follow_items(delta: float) -> void:
	var k := clampf(delta * ITEM_FOLLOW_RATE, 0.0, 1.0)
	for i in range(_followed.size() - 1, -1, -1):
		var item = _followed[i]
		if not is_instance_valid(item) or not item.has_meta("net_xf") or not follows_host(item):
			_followed.remove_at(i)
			continue
		var grab := item.get_node_or_null("Grab") as VRInteractable
		if grab and grab.is_grabbed():
			item.remove_meta("net_xf")   # pris en main : il suit la main, plus le conducteur
			_followed.remove_at(i)
			continue
		var target: Transform3D = item.get_meta("net_xf")
		var xf: Transform3D = item.transform
		if xf.origin.distance_to(target.origin) < 0.0005:
			item.transform = target
			_followed.remove_at(i)
			continue
		item.transform = xf.interpolate_with(target, k)


## Objet de la voiture d'après son nom (les noms sont les mêmes chez les deux joueurs).
func _item_named(item_name: String) -> RigidBody3D:
	var item = _item_names.get(item_name)
	if item != null and is_instance_valid(item) and String(item.name) == item_name and car.is_ancestor_of(item):
		return item
	_item_names.clear()
	for n in car.find_children("*", "RigidBody3D", true, false):
		_item_names[String(n.name)] = n
	item = _item_names.get(item_name)
	return item as RigidBody3D


# --- Consommer à la bouche de l'autre joueur ---------------------------------------------

## L'autre joueur nous fait consommer l'objet `path` (Net.feed) : l'effet est pour nous.
func on_feed(path: String, amount: float) -> void:
	var target := get_parent().get_node_or_null(NodePath(path))
	if target and target.has_method("net_feed"):
		target.call("net_feed", amount)
	elif amount <= 0.0:
		EdiblePickable.swallow(get_tree(), true)   # pilule déjà disparue chez nous


## Objet lâché par le joueur local, maintenant posé : sa place fait foi chez l'autre.
func _send_item_rest(item: RigidBody3D) -> void:
	if not Net.is_online() or not is_instance_valid(item) or not item.is_inside_tree() or not car.is_ancestor_of(item):
		return   # jeté dehors : il est resté sur la route, on laisse
	var grab := item.get_node_or_null("Grab") as VRInteractable
	if grab and grab.is_grabbed() or item.has_meta(DockerCap.WORN_META):
		return
	Net.rx_item.rpc(String(item.name), String(car.get_path_to(item.get_parent())), item.transform)


func on_item(item_name: String, parent_path: String, local_xf: Transform3D) -> void:
	if car == null:
		return
	var item := _item_named(item_name)
	var parent := car.get_node_or_null(NodePath(parent_path)) as Node3D
	if item == null or parent == null or item.has_meta(DockerCap.WORN_META):
		return
	var grab := item.get_node_or_null("Grab") as VRInteractable
	if grab and grab.is_grabbed():
		return
	if item.get_parent() != parent:
		if item.get_parent() is StorageZone:
			(item.get_parent() as StorageZone).on_item_taken(item)
		item.reparent(parent, false)
	item.top_level = false
	item.freeze = true
	item.collision_layer = 0
	item.collision_mask = 0
	item.linear_velocity = Vector3.ZERO
	item.angular_velocity = Vector3.ZERO
	for m in ["rest_xf", "free_timer", "net_remote_until", "net_xf"]:
		if item.has_meta(m):
			item.remove_meta(m)
	ItemPhysics.stop(item)
	item.transform = local_xf
	ItemPhysics.begin(item)


## L'autre joueur a mis le bonnet `item_name` sur une tête (Net.wear) : pareil ici.
func on_wear(item_name: String, driver_seat: bool) -> void:
	var item := _item_named(item_name)
	var cap := item.get_node_or_null("Grab") as DockerCap if item else null
	if cap == null:
		return
	Net.applying_remote = true
	cap.wear(driver_seat)
	Net.applying_remote = false


# --- Autre joueur -> chez soi ----------------------------------------------------------

func on_pose(data: Array) -> void:
	if car == null or data.size() < 7:
		return
	_ensure_remote_player()
	var t: float = data[6]
	_pose_clock.sample(t, Net.sim_time)
	if not _poses.is_empty() and t <= _poses[-1][0]:
		return
	_poses.append([t, data])
	while _poses.size() > 40:
		_poses.pop_front()


## Pose de l'autre joueur à l'instant affiché (interpolée entre deux messages).
func _apply_remote_pose(rt: float) -> void:
	if _poses.is_empty():
		return
	while _poses.size() > 2 and _poses[1][0] <= rt:
		_poses.pop_front()
	var data: Array = _poses[0][1]
	if _poses.size() >= 2 and rt > _poses[0][0]:
		var span: float = _poses[1][0] - _poses[0][0]
		var w := clampf((rt - _poses[0][0]) / span, 0.0, 1.0) if span > 0.0 else 1.0
		data = NetClock.lerp_any(_poses[0][1], _poses[1][1], w)
	_remote_head_local = data[0]
	for i in 3:
		_remote_hand_local[i] = data[i + 1]
	for i in 2:
		_remote_touch[i] = data[i + 4]


## Geste de l'autre joueur : rejoué quand sa main affichée arrive à l'instant du geste.
func on_hand(index: int, kind: int, path: String, local_xf: Transform3D, t: float, vel: Vector3) -> void:
	if car == null or index < 0 or index > 4:
		return
	_ensure_remote_player()
	_hand_events.append([t, index, kind, path, local_xf, vel])


func _run_hand_events(rt: float) -> void:
	while not _hand_events.is_empty():
		var e: Array = _hand_events[0]
		# (horloge pas encore calée, ou geste vieux d'une demi-seconde : tout de suite)
		if _pose_clock.is_ready() and e[0] > rt and e[0] - rt < 0.5:
			return
		_hand_events.pop_front()
		_do_hand(e[1], e[2], e[3], e[4], e[5])


func _do_hand(index: int, kind: int, path: String, local_xf: Transform3D, vel: Vector3) -> void:
	var proxy := _remote_hands[index]
	if index < 3:
		_remote_hand_local[index] = local_xf
	proxy.global_transform = car.global_transform * local_xf
	var target := get_parent().get_node_or_null(NodePath(path)) as VRInteractable
	Net.applying_remote = true
	Net.remote_camera = proxy.camera
	match kind:
		HandEvent.GRAB:
			if target and target.enabled:
				if proxy.held and proxy.held != target:
					_release_proxy(proxy)
				proxy.held = target
				target.grab(proxy)
		HandEvent.RELEASE:
			if is_instance_valid(proxy.held) and proxy.held is VRPickable:
				var pk := proxy.held as VRPickable
				pk.hand_velocity = car.global_basis * vel + car.linear_velocity
				if Net.is_driver():
					# lâché par le copilote : c'est lui qui le pose (voir on_items)
					pk.item.set_meta("net_remote_until", Net.sim_time + ITEM_REST_DELAY + 1.5)
			_release_proxy(proxy)
		HandEvent.TOGGLE:
			if target and target.has_method("toggle"):
				target.toggle()
		HandEvent.BUTTON:
			if target and target.has_method("vr_button"):
				target.vr_button()
	Net.applying_remote = false


func on_call(path: String, method: String, args: Array) -> void:
	if method not in ALLOWED_CALLS:
		return
	var target := get_parent().get_node_or_null(NodePath(path))
	if target and target.has_method(method):
		Net.applying_remote = true
		target.callv(method, args)
		Net.applying_remote = false


func _release_proxy(proxy: NetRemoteHand) -> void:
	if proxy.held and is_instance_valid(proxy.held):
		var was_applying := Net.applying_remote
		Net.applying_remote = true
		Net.remote_camera = proxy.camera
		proxy.held.release(proxy)
		Net.applying_remote = was_applying
	proxy.held = null


func _update_remote_hands() -> void:
	if remote_player == null:
		return
	var rt := _pose_clock.render_time(Net.sim_time) if _pose_clock.is_ready() else INF
	_run_hand_events(rt)
	_apply_remote_pose(rt)
	var cxf := car.global_transform
	_remote_head.global_transform = cxf * _remote_head_local
	for i in 5:
		var proxy := _remote_hands[i]
		var local = _remote_hand_local[i if i < 3 else i - 3]
		if i < 3:
			_remote_hand_meshes[i].visible = local != null
		if local == null:
			proxy.remote_touch = false
			continue
		var touch = _remote_touch[i % 3] if i != 2 else null
		if i < 3:
			proxy.global_transform = cxf * (local as Transform3D)
			_show_remote_hand(i, proxy.global_transform, touch, cxf)
			proxy.remote_touch = touch != null and touch[0]
			if touch != null:
				proxy.tip_global = cxf * (touch[1] as Vector3)
				proxy.palm_global = cxf * (touch[2] as Vector3)
		elif touch != null:
			# bout de l'index : orientation de la main, au bout du doigt
			proxy.global_transform = Transform3D((cxf * (local as Transform3D)).basis, cxf * (touch[1] as Vector3))
		if proxy.held:
			if not is_instance_valid(proxy.held) or not proxy.held.enabled:
				_release_proxy(proxy)
			else:
				Net.applying_remote = true
				Net.remote_camera = proxy.camera
				proxy.held.grab_update(proxy)
				Net.applying_remote = false
	# corps assis : bras vers les mains affichées (mains VR), sinon posées sur les cuisses
	var hands: Array = [null, null]
	for i in 2:
		var shown := _remote_hand_meshes[i]
		if shown.visible and _remote_touch[i] != null and (_remote_touch[i] as Array).size() > 3 and not (_remote_touch[i][3] as Array).is_empty():
			hands[i] = shown.global_position
	var seat := car.driver_seat.position
	if Net.is_driver():
		seat.x = -seat.x   # l'autre joueur est le copilote, côté passager
	_avatar.pose(cxf, seat, _remote_head.global_transform, hands, get_physics_process_delta_time())


# --- Avatar de l'autre joueur ---------------------------------------------------------

## Main affichée de l'autre joueur : le modèle XR Tools posé exactement comme chez lui
## (calée sur le volant ou un levier, doigts selon son grip et sa gâchette, poing refermé
## sur une commande). Main souris : un point lumineux.
func _show_remote_hand(i: int, xf: Transform3D, touch, cxf: Transform3D) -> void:
	var mesh := _remote_hand_meshes[i]
	if i == 2 or touch == null or (touch as Array).size() < 4 or (touch[3] as Array).is_empty():
		mesh.global_transform = xf
		return
	var vis: Array = touch[3]
	mesh.global_transform = cxf * (vis[0] as Transform3D)
	var tree := mesh.get_node_or_null("AnimationTree") as AnimationTree
	if tree:
		tree.set("parameters/Grip/blend_amount", vis[1])
		tree.set("parameters/Trigger/blend_amount", vis[2])
	var posed: bool = vis[3]
	if posed != _remote_posed[i] and mesh.has_method("add_pose_override"):
		_remote_posed[i] = posed
		if posed:
			mesh.call("add_pose_override", self, 10, _grip_pose(i))
		else:
			mesh.call("remove_pose_override", self)


func _grip_pose(i: int) -> Resource:
	if _grip_poses.is_empty():
		for path in [VRHandInteractor.GRIP_POSE_LEFT, VRHandInteractor.GRIP_POSE_RIGHT]:
			var pose := XRToolsHandPoseSettings.new()
			var anim := load(path) as Animation
			pose.open_pose = anim
			pose.closed_pose = anim
			_grip_poses.append(pose)
	return _grip_poses[i]


func _ensure_remote_player() -> void:
	if remote_player:
		return
	# Accroché à la voiture : avatar, mains et yeux suivent la voiture à chaque instant.
	# Rangé ailleurs, il gardait la place de la voiture à l'image précédente pour les
	# scripts qui passent avant la NetSession (les mains du conducteur) : en roulant,
	# la bouche de l'autre joueur était 35 cm en arrière (à 90 km/h) et on ne pouvait
	# rien lui faire avaler.
	remote_player = Node3D.new()
	remote_player.name = "RemotePlayer"
	# son corps n'arrête pas les objets tenus (on doit pouvoir les porter à sa bouche)
	remote_player.set_meta("no_held_collision", true)
	car.add_child(remote_player)
	# corps assis simple ; haut rouge pour le conducteur, bleu pour le copilote
	# (l'autre est le conducteur chez le copilote : barbe rousse)
	_avatar = NetAvatar.new(Color(0.55, 0.22, 0.18) if Net.is_copilot() else Color(0.18, 0.32, 0.55), Net.is_copilot())
	_avatar.name = "Avatar"
	remote_player.add_child(_avatar)
	_remote_head = _avatar.head
	var cam := Camera3D.new()
	cam.name = "Eyes"
	_remote_head.add_child(cam)
	cam.current = false
	remote_eyes = cam
	for i in 3:
		var hand := NetRemoteHand.new()
		hand.name = ["LeftHand", "RightHand", "MouseHand"][i]
		hand.index = i
		hand.camera = cam
		remote_player.add_child(hand)
		_remote_hands.append(hand)
		if i < 2:
			# les mêmes mains que les nôtres (modèle XR Tools), posées par _show_remote_hand
			var shown := (load(HAND_SCENES[i]) as PackedScene).instantiate() as Node3D
			shown.name = ["RemoteLeftHand", "RemoteRightHand"][i]
			remote_player.add_child(shown)
			shown.set_physics_process(false)   # pas de manette à suivre : posée à la main
			shown.visible = false
			_remote_hand_meshes.append(shown)
			continue
		# main souris : un point lumineux là où vise l'autre joueur
		var mesh := MeshInstance3D.new()
		var dot := SphereMesh.new()
		dot.radius = 0.015
		dot.height = 0.03
		mesh.mesh = dot
		var m := _mat(Color(1.0, 0.75, 0.2))
		m.emission_enabled = true
		m.emission = Color(1.0, 0.6, 0.1)
		mesh.material_override = m
		mesh.visible = false
		remote_player.add_child(mesh)
		_remote_hand_meshes.append(mesh)
	for i in 2:
		var tip := NetRemoteTip.new()
		tip.name = ["LeftIndexTip", "RightIndexTip"][i]
		tip.index = 3 + i
		tip.camera = cam
		tip.owner_hand = _remote_hands[i]
		remote_player.add_child(tip)
		_remote_hands.append(tip)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m
