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

enum HandEvent { GRAB, RELEASE, TOGGLE, BUTTON }

## Retard de l'interpolation de la voiture chez le copilote (s).
const INTERP_DELAY := 0.1
## Au-delà de la dernière position reçue, on prolonge le mouvement au plus ce temps (s).
const MAX_EXTRAPOLATION := 0.25
## Fréquence d'envoi des animaux (par seconde).
const ANIMAL_RATE := 15.0
## Délai (s) après un lâcher avant d'envoyer la position où l'objet s'est posé.
const ITEM_REST_DELAY := 2.0
## Méthodes qu'un message de l'autre joueur a le droit d'appeler (raccourcis clavier).
const ALLOWED_CALLS := ["toggle", "press", "unpress", "_key_shortcut", "_press", "toggle_power", "set_volume",
	"set_notch", "step"]

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
var _snapshots: Array = []        # copilote : [temps conducteur, Transform3D, vitesse, vitesse angulaire]
var _clock_offset := 0.0
var _clock_ready := false
var _world_timer := 0.0
var _last_car: Array = []
var _animal_timer := 0.0
var _last_text: Array = []
var _props_sig := ""
var _controls_sent := [0.0, false]
var _controls_timer := 0.0


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
	_find_local_hands()
	if Net.is_copilot():
		_apply_car()
		_send_controls(delta)
	else:
		_send_car()
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

	func _physics_process(_delta: float) -> void:
		if session.car and Net.is_online():
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


func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0


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
	Net.rx_car.rpc([_now(), _to_abs(car.global_transform), car.linear_velocity, car.forward_speed,
		car.throttle_input, car.brake_input, car.auto_gear, car.shift_timer, car.engine_state,
		w.input_target_angle / deg_to_rad(w.max_rotation_deg), car.angular_velocity, police, rivals])


func on_car(data: Array) -> void:
	if not Net.is_copilot() or data.size() < 13:
		return
	var t: float = data[0]
	var offset := t - _now()
	if not _clock_ready or absf(offset - _clock_offset) > 0.5:
		_clock_offset = offset
		_clock_ready = true
		_snapshots.clear()
	elif offset > _clock_offset:
		_clock_offset = offset   # paquet moins retardé : c'est le vrai décalage
	else:
		_clock_offset = lerpf(_clock_offset, offset, 0.01)   # suit lentement une dérive
	if not _snapshots.is_empty() and t <= _snapshots[-1][0]:
		return
	_snapshots.append([t, data[1], data[2], data[10], data[11], data[12]])
	while _snapshots.size() > 30:
		_snapshots.pop_front()
	_last_car = data


func _apply_car() -> void:
	if _snapshots.is_empty():
		return
	var rt := _now() + _clock_offset - INTERP_DELAY
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
	if _snapshots.size() >= 2 and rt >= a[0]:
		var b: Array = _snapshots[1]
		var span: float = b[0] - a[0]
		var w := clampf((rt - a[0]) / span, 0.0, 1.0) if span > 0.0 else 1.0
		xf = a[1].interpolate_with(b[1], w)
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
		if rt > b[0]:
			xf = b[1]
			xf.origin += (b[2] as Vector3) * minf(rt - b[0], MAX_EXTRAPOLATION)
	if _pursuer and not police.is_empty():
		_pursuer.net_apply(police, _from_abs(police_xf))
	if _rivals and not rivals.is_empty():
		_rivals.net_apply(rivals, _from_abs(rivals_xf))
	car.global_transform = _from_abs(xf)
	car.linear_velocity = vel
	car.angular_velocity = ang
	car.engine_force = 0.0
	if _last_car.size() >= 10:
		car.forward_speed = _last_car[3]
		car.throttle_input = _last_car[4]
		car.brake_input = _last_car[5]
		car.auto_gear = _last_car[6]
		car.shift_timer = _last_car[7]
		car.engine_state = _last_car[8]
		car.external_steer = _last_car[9]


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
	Net.rx_pose.rpc([inv * cam.global_transform, hands[0], hands[1], hands[2], touch[0], touch[1]])


func _on_local_interaction(kind: int, target: Node, hand: Node3D) -> void:
	if not Net.is_online() or not is_instance_valid(target) or not _local_hands.has(hand):
		return
	var path := String(get_parent().get_path_to(target))
	Net.rx_hand.rpc(_local_hands[hand], kind, path, car.global_transform.affine_inverse() * hand.global_transform)
	if kind == HandEvent.RELEASE and target is VRPickable:
		var item := (target as VRPickable).item
		get_tree().create_timer(ITEM_REST_DELAY).timeout.connect(_send_item_rest.bind(item))


## Prise du bout de l'index : rejouée par le doigt fantôme 3 (gauche) ou 4 (droit).
func _on_local_tip(kind: int, target: Node, hand: VRHandInteractor) -> void:
	if not Net.is_online() or not is_instance_valid(target) or not _local_hands.has(hand):
		return
	var path := String(get_parent().get_path_to(target))
	Net.rx_hand.rpc(3 + _local_hands[hand], kind, path, car.global_transform.affine_inverse() * hand.tip_hand.global_transform)
	if kind == HandEvent.RELEASE and target is VRPickable:
		get_tree().create_timer(ITEM_REST_DELAY).timeout.connect(_send_item_rest.bind((target as VRPickable).item))


## Objet lâché par le joueur local, maintenant posé : sa place fait foi chez l'autre.
func _send_item_rest(item: RigidBody3D) -> void:
	if not Net.is_online() or not is_instance_valid(item) or not item.is_inside_tree() or not car.is_ancestor_of(item):
		return   # jeté dehors : il est resté sur la route, on laisse
	var grab := item.get_node_or_null("Grab") as VRInteractable
	if grab and grab.is_grabbed():
		return
	Net.rx_item.rpc(String(item.name), String(car.get_path_to(item.get_parent())), item.transform)


func on_item(item_name: String, parent_path: String, local_xf: Transform3D) -> void:
	if car == null:
		return
	var found := get_parent().find_children(item_name, "RigidBody3D", true, false)
	var parent := car.get_node_or_null(NodePath(parent_path)) as Node3D
	if found.is_empty() or parent == null:
		return
	var item := found[0] as RigidBody3D
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
	for m in ["rest_xf", "free_timer"]:
		if item.has_meta(m):
			item.remove_meta(m)
	ItemPhysics.stop(item)
	item.transform = local_xf
	ItemPhysics.begin(item)


# --- Autre joueur -> chez soi ----------------------------------------------------------

func on_pose(data: Array) -> void:
	if car == null or data.size() < 6:
		return
	_ensure_remote_player()
	_remote_head_local = data[0]
	for i in 3:
		_remote_hand_local[i] = data[i + 1]
	for i in 2:
		_remote_touch[i] = data[i + 4]


func on_hand(index: int, kind: int, path: String, local_xf: Transform3D) -> void:
	if car == null or index < 0 or index > 4:
		return
	_ensure_remote_player()
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
	remote_player = Node3D.new()
	remote_player.name = "RemotePlayer"
	add_child(remote_player)
	# corps assis simple ; haut rouge pour le conducteur, bleu pour le copilote
	_avatar = NetAvatar.new(Color(0.55, 0.22, 0.18) if Net.is_copilot() else Color(0.18, 0.32, 0.55))
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
			shown.top_level = true
			shown.set_physics_process(false)   # pas de manette à suivre : posée à la main
			shown.visible = false
			_remote_hand_meshes.append(shown)
			continue
		# main souris : un point lumineux là où vise l'autre joueur
		var mesh := MeshInstance3D.new()
		mesh.top_level = true
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
