extends Node
## Réseau (autoload « Net ») : partie à deux sur le réseau local.
##
## - JOUER À DEUX : on cherche une partie sur le réseau local (~1,5 s). Trouvée : on la
##   rejoint (copilote). Sinon on en crée une (conducteur) et on attend l'autre joueur.
##   Dès que les deux ont cliqué, le conducteur lance la partie chez les deux.
## - Le conducteur fait tourner la partie (physique de la voiture, route, police...) ;
##   le copilote reçoit la position de la voiture (voir NetSession).
## - Les messages de jeu passent tous par ce noeud (même chemin chez les deux joueurs,
##   même pendant le chargement de la scène) puis sont confiés à la NetSession.
##
## Tests sur une seule machine : lancer deux fois le jeu ; ou en ligne de commande,
## `-- --host` (conducteur) et `-- --join=127.0.0.1` (copilote) lancent directement,
## `-- --lan` fait comme le bouton JOUER À DEUX.

signal status_changed(text: String)
## Les deux joueurs sont connectés : la partie va démarrer.
signal lobby_complete
## La connexion a échoué ou l'autre joueur est parti (message à afficher).
signal connection_lost(reason: String)

enum Role { SOLO, DRIVER, COPILOT }
enum State { IDLE, SEARCHING, HOSTING, JOINING, IN_LOBBY, IN_GAME }

const GAME_PORT := 7777
## Les copilotes écoutent ici les annonces des parties ; les parties écoutent ici les
## recherches (deux ports : deux instances sur la même machine ne se gênent pas).
const DISCOVERY_PORT := 7778
const PROBE_PORT := 7779
const PROTOCOL := "NFP1"
const SEARCH_TIME := 1.5
const GAME_SCENE := "res://main.tscn"
const MENU_SCENE := "res://menu/main_menu.tscn"

var role := Role.SOLO
var state := State.IDLE
## Graine commune du monde (route, rangements, météo...) ; 0 en solo.
var game_seed := 0
## Vrai pendant qu'on rejoue chez soi un geste de l'autre joueur (sa main a saisi,
## lâché, actionné un objet) : les effets personnels (pilule avalée, bouffée...) ne
## s'appliquent pas au joueur local.
var applying_remote := false
## Caméra (tête) de l'autre joueur pendant `applying_remote` : sert de bouche.
var remote_camera: Node3D

## NetSession de la partie en cours (créée par main.gd).
var session: Node
## Raison de la dernière déconnexion (affichée par le menu à son retour).
var last_message := ""
## Temps de simulation (s) : avance d'un pas à chaque image physique. Date les messages
## de position : régulier même quand une image arrive en retard (l'heure système, elle,
## faisait accélérer et ralentir la voiture du copilote).
var sim_time := 0.0
## Consommations à envoyer à l'autre joueur (chemin de l'objet -> quantité), voir feed().
var _feeds := {}
var _feed_timer := 0.0
## Tests : retard aléatoire (s) des messages de position reçus (option `--net-jitter=ms`),
## pour simuler un Wi-Fi irrégulier sur une seule machine.
var _jitter := 0.0
var _jitter_queue: Array = []   # [instant de remise, méthode, arguments]

var _udp: PacketPeerUDP          # écoute (annonces ou recherches)
var _udp_send: PacketPeerUDP
var _timer := 0.0
var _announce_timer := 0.0
var _token := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_check_command_line.call_deferred()


# --- État ------------------------------------------------------------------------

func is_online() -> bool:
	return role != Role.SOLO and multiplayer.multiplayer_peer != null \
		and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer


func is_driver() -> bool:
	return role != Role.COPILOT


func is_copilot() -> bool:
	return role == Role.COPILOT


## Graine dérivée de la graine commune (0 en solo : chaque système tire au hasard).
func world_seed(salt: String) -> int:
	if game_seed == 0:
		return 0
	var s := hash(str(game_seed) + ":" + salt)
	return s if s != 0 else 1


## Tête de l'autre joueur (caméra non active de son avatar), ou null : sa bouche, pour
## lui faire fumer / boire / avaler quelque chose (EdiblePickable.mouth_near).
func other_head() -> Node3D:
	if session == null or not is_instance_valid(session):
		return null
	var eyes = session.get("remote_eyes")
	return eyes as Node3D if is_instance_valid(eyes) else null


## L'objet est-il tenu par une main de l'autre joueur ?
func held_by_remote(it: VRInteractable) -> bool:
	for h in it._grab_hands:
		if is_instance_valid(h) and h.is_in_group(NetRemoteHand.GROUP):
			return true
	return false


## Tête du joueur qui tient l'objet : l'autre joueur (s'il le tient) ou le joueur local.
func camera_for(it: VRInteractable) -> Node3D:
	if applying_remote and remote_camera:
		return remote_camera
	if it:
		for h in it._grab_hands:
			if is_instance_valid(h) and h.is_in_group(NetRemoteHand.GROUP):
				return h.get("camera")
	return get_viewport().get_camera_3d()


## Partie à deux : l'objet `node`, tenu par une main du joueur local, est à la bouche
## de l'autre joueur, qui en consomme `amount` (bouffée, gorgée ; 0 pour une pilule).
## Seule la machine de la main qui tient l'objet cherche une bouche (chez l'autre, la
## main n'est qu'un reflet en retard) ; l'autre machine applique l'effet à son joueur
## (session.on_feed -> net_feed de l'objet). Regroupé par dixièmes de seconde ;
## `now` : envoyé tout de suite (pilule avalée, objet qui va disparaître).
func feed(node: Node, amount := 0.0, now := false) -> void:
	if not is_online() or session == null or not is_instance_valid(session):
		return
	var path := String(session.get_parent().get_path_to(node))
	_feeds[path] = float(_feeds.get(path, 0.0)) + amount
	if now:
		_flush_feeds()
	elif _feed_timer <= 0.0:
		_feed_timer = 0.1


func _flush_feeds() -> void:
	for path in _feeds:
		rx_feed.rpc(path, _feeds[path])
	_feeds.clear()
	_feed_timer = 0.0


## Bonnet (DockerCap) mis sur la tête du conducteur ou du copilote : la machine qui l'a
## lâché décide, l'autre le met sur la même tête (par le nom de l'objet : son chemin
## n'est pas forcément le même chez les deux à ce moment-là).
func wear(item: Node, driver_seat: bool) -> void:
	if is_online() and not applying_remote:
		rx_wear.rpc(String(item.name), driver_seat)


## Action clavier (raccourci) : faite chez soi et rejouée chez l'autre joueur.
func perform(node: Node, method: StringName, args: Array = []) -> void:
	node.callv(method, args)
	if is_online() and session and is_instance_valid(session) and not applying_remote:
		rx_call.rpc(String(session.get_parent().get_path_to(node)), String(method), args)


## Fait faire `method` au même objet chez l'autre joueur seulement (le résultat d'une
## action qui vient d'avoir lieu chez soi). Méthode à ajouter à NetSession.ALLOWED_CALLS.
func remote_call(node: Node, method: StringName, args: Array = []) -> void:
	if is_online() and session and is_instance_valid(session) and not applying_remote:
		rx_call.rpc(String(session.get_parent().get_path_to(node)), String(method), args)


# --- Lobby -----------------------------------------------------------------------

## JOUER À DEUX : cherche une partie sur le réseau local, sinon en crée une.
func find_or_host() -> void:
	cancel()
	_token = randi() % 1000000000 + 1
	_udp = PacketPeerUDP.new()
	if _udp.bind(DISCOVERY_PORT) != OK:
		# port déjà pris (une autre recherche sur cette machine) : on crée la partie
		_udp = null
		_start_host()
		return
	_udp.set_broadcast_enabled(true)
	state = State.SEARCHING
	_timer = SEARCH_TIME + randf() * 0.5   # deux clics simultanés : l'un finit avant
	_announce_timer = 0.0
	_status("Recherche d'une partie sur le réseau...", "reseau_recherche")


func cancel() -> void:
	_close_udp()
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	role = Role.SOLO
	state = State.IDLE
	game_seed = 0


func _start_host() -> void:
	_close_udp()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(GAME_PORT, 1) != OK:
		# une partie existe déjà sur cette machine : on la rejoint
		_start_join("127.0.0.1")
		return
	multiplayer.multiplayer_peer = peer
	role = Role.DRIVER
	state = State.HOSTING
	_udp = PacketPeerUDP.new()
	if _udp.bind(PROBE_PORT) != OK:
		_udp = null
	_udp_send = PacketPeerUDP.new()
	_udp_send.set_broadcast_enabled(true)
	_announce_timer = 0.0
	_status("En attente de l'autre joueur...\n(il doit cliquer sur JOUER À DEUX)", "reseau_attente")


func _start_join(ip: String) -> void:
	_close_udp()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip, GAME_PORT) != OK:
		_fail("Impossible de rejoindre %s" % ip, "reseau_echec_rejoindre")
		return
	multiplayer.multiplayer_peer = peer
	role = Role.COPILOT
	state = State.JOINING
	_status("Partie trouvée (%s), connexion..." % ip, "reseau_trouvee")


func _physics_process(delta: float) -> void:
	sim_time += delta
	var now := Time.get_ticks_msec() / 1000.0
	while not _jitter_queue.is_empty() and _jitter_queue[0][0] <= now:
		var e: Array = _jitter_queue.pop_front()
		_to_session(e[1], e[2])
	if not _feeds.is_empty():
		_feed_timer -= delta
		if _feed_timer <= 0.0:
			_flush_feeds()


func _process(delta: float) -> void:
	match state:
		State.SEARCHING:
			_search(delta)
		State.HOSTING:
			_announce(delta)


func _search(delta: float) -> void:
	_timer -= delta
	_announce_timer -= delta
	if _announce_timer <= 0.0:
		_announce_timer = 0.3
		# demande aux parties de se signaler (réponse directe : marche même si
		# l'appareil filtre les annonces en diffusion)
		var probe := ("%s|LOOK|%d" % [PROTOCOL, _token]).to_utf8_buffer()
		for ip in ["255.255.255.255", "127.0.0.1"]:
			_udp.set_dest_address(ip, PROBE_PORT)
			_udp.put_packet(probe)
	while _udp and _udp.get_available_packet_count() > 0:
		var msg := _udp.get_packet().get_string_from_utf8().split("|")
		var ip := _udp.get_packet_ip()
		if msg.size() >= 3 and msg[0] == PROTOCOL and msg[1] == "HOST" and int(msg[2]) != _token:
			_start_join(ip)
			return
	if _timer <= 0.0:
		_start_host()


func _announce(delta: float) -> void:
	_announce_timer -= delta
	if _announce_timer <= 0.0:
		_announce_timer = 0.5
		var pkt := ("%s|HOST|%d" % [PROTOCOL, _token]).to_utf8_buffer()
		for ip in ["255.255.255.255", "127.0.0.1"]:
			for port in [DISCOVERY_PORT, PROBE_PORT]:
				_udp_send.set_dest_address(ip, port)
				_udp_send.put_packet(pkt)
	while _udp and _udp.get_available_packet_count() > 0:
		var msg := _udp.get_packet().get_string_from_utf8().split("|")
		var ip := _udp.get_packet_ip()
		var port := _udp.get_packet_port()
		if msg.size() < 3 or msg[0] != PROTOCOL or int(msg[2]) == _token:
			continue
		if msg[1] == "LOOK":
			_udp.set_dest_address(ip, port)
			_udp.put_packet(("%s|HOST|%d" % [PROTOCOL, _token]).to_utf8_buffer())
		elif msg[1] == "HOST" and int(msg[2]) < _token:
			# deux parties créées en même temps : la plus « petite » garde la sienne
			multiplayer.multiplayer_peer.close()
			_start_join(ip)
			return


func _close_udp() -> void:
	if _udp:
		_udp.close()
	_udp = null
	if _udp_send:
		_udp_send.close()
	_udp_send = null


## Message d'état du réseau (menu principal) et sa voix (VoiceLine, canal « menu »).
func _status(text: String, voice := "") -> void:
	print("Réseau : ", text.replace("\n", " "))
	status_changed.emit(text)
	if voice != "":
		VoiceLine.play(self, voice, "menu")


func _fail(reason: String, voice := "") -> void:
	if state == State.IDLE:
		return   # déjà traité (déconnexion signalée deux fois)
	var was_in_game := state == State.IN_GAME
	cancel()
	_status(reason, voice)
	last_message = reason
	connection_lost.emit(reason)
	if was_in_game:
		SceneLoader.change_scene(MENU_SCENE)


func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	if state != State.HOSTING:
		# déjà deux joueurs : on refuse le troisième
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id)
		return
	_close_udp()
	state = State.IN_LOBBY
	_status("Joueur trouvé ! Tu conduis.", "reseau_conducteur")
	lobby_complete.emit()
	game_seed = randi() % 2000000000 + 1
	get_tree().create_timer(1.0).timeout.connect(func():
		if state == State.IN_LOBBY:
			_rpc_start_game.rpc(game_seed))


func _on_connected_to_server() -> void:
	state = State.IN_LOBBY
	_status("Connecté ! Tu es copilote.", "reseau_copilote")
	lobby_complete.emit()


# Les signaux du réseau arrivent pendant que la connexion se met à jour : la fermer
# tout de suite fait planter Godot, on attend la fin de l'image (call_deferred).
func _on_connection_failed() -> void:
	_fail.call_deferred("Connexion impossible.", "reseau_echec")


func _on_peer_disconnected(_id: int) -> void:
	if multiplayer.is_server() and state == State.IN_GAME:
		# le conducteur continue seul
		print("Réseau : le copilote est parti")
		role = Role.SOLO
		if session:
			session.call("on_remote_left")
		return
	if state != State.IDLE:
		_fail.call_deferred("L'autre joueur est parti.", "reseau_parti")


func _on_server_disconnected() -> void:
	_fail.call_deferred("Le conducteur a quitté la partie.", "reseau_conducteur_parti")


func _check_command_line() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--host":
			_token = 1
			_start_host()
		elif arg == "--lan":
			find_or_host()   # comme le bouton JOUER À DEUX
		elif arg.begins_with("--join="):
			_start_join(arg.trim_prefix("--join="))
		elif arg.begins_with("--net-jitter="):
			_jitter = float(arg.trim_prefix("--net-jitter=")) / 1000.0
		elif arg == "--perftest":
			# banc de mesure sur le casque (tools/perf_cycle.gd), avec --solo
			var pc: Node = load("res://tools/perf_cycle.gd").new()
			pc.name = "PerfCycle"
			add_child(pc)
		elif arg == "--solo":
			# partie solo tout de suite, sans le menu (tests sur le casque par adb :
			# am start ... --esa command_line_params "++,--solo")
			change_scene_async.call_deferred(GAME_SCENE)


# --- Démarrage de la partie --------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _rpc_start_game(seed_value: int) -> void:
	game_seed = seed_value
	state = State.IN_GAME
	SceneLoader.change_scene(GAME_SCENE)


## Passe à une scène en la chargeant dans un fil de travail, derrière l'écran de
## chargement (voir menu/scene_loader.gd) : l'image ne fige pas pendant la lecture
## des fichiers (~1 s sur PC, bien plus sur le casque).
func change_scene_async(path: String) -> void:
	SceneLoader.change_scene(path)


## Le conducteur relance la partie (rejouer) : le copilote recharge aussi.
func restart_game() -> void:
	if is_online() and multiplayer.is_server():
		_rpc_start_game.rpc(game_seed)
	else:
		SceneLoader.reload_current()


## Le copilote demande à rejouer (fin de partie) : c'est le conducteur qui relance.
func request_restart() -> void:
	if is_online() and not multiplayer.is_server():
		rx_restart_request.rpc_id(1)


## Retour au menu : on quitte la partie à deux.
func leave_to_menu() -> void:
	cancel()
	SceneLoader.change_scene(MENU_SCENE)


# --- Messages de jeu (relayés à la NetSession) ---------------------------------------

func _to_session(method: StringName, args: Array) -> void:
	if session and is_instance_valid(session) and session.is_inside_tree():
		session.callv(method, args)


@rpc("authority", "unreliable_ordered", "call_remote", 1)
func rx_car(data: Array) -> void:
	_to_session_jittered(&"on_car", [data])


@rpc("authority", "reliable", "call_remote", 2)
func rx_world(data: Dictionary) -> void:
	_to_session(&"on_world", [data])


@rpc("any_peer", "unreliable_ordered", "call_remote", 3)
func rx_pose(data: Array) -> void:
	_to_session_jittered(&"on_pose", [data])


func _to_session_jittered(method: StringName, args: Array) -> void:
	if _jitter <= 0.0:
		_to_session(method, args)
		return
	# dans l'ordre d'arrivée (comme unreliable_ordered), chacun plus ou moins en retard
	var at := Time.get_ticks_msec() / 1000.0 + randf() * _jitter
	if not _jitter_queue.is_empty():
		at = maxf(at, _jitter_queue[-1][0])
	_jitter_queue.append([at, method, args])


@rpc("any_peer", "reliable", "call_remote", 2)
func rx_hand(hand: int, kind: int, path: String, local_xf: Transform3D, t: float, vel: Vector3) -> void:
	_to_session(&"on_hand", [hand, kind, path, local_xf, t, vel])


## L'autre joueur nous fait consommer l'objet `path` (voir feed()).
@rpc("any_peer", "reliable", "call_remote", 2)
func rx_feed(path: String, amount: float) -> void:
	_to_session(&"on_feed", [path, amount])


## Objets en vrac dans la voiture qui ont bougé chez le conducteur (voir NetSession).
@rpc("authority", "unreliable_ordered", "call_remote", 6)
func rx_items(list: Array) -> void:
	_to_session(&"on_items", [list])


@rpc("any_peer", "reliable", "call_remote", 2)
func rx_call(path: String, method: String, args: Array) -> void:
	_to_session(&"on_call", [path, method, args])


@rpc("any_peer", "reliable", "call_remote", 2)
func rx_item(item_name: String, parent_path: String, local_xf: Transform3D) -> void:
	_to_session(&"on_item", [item_name, parent_path, local_xf])


@rpc("any_peer", "reliable", "call_remote", 2)
func rx_wear(item_name: String, driver_seat: bool) -> void:
	_to_session(&"on_wear", [item_name, driver_seat])


@rpc("authority", "reliable", "call_remote", 2)
func rx_tree(params: Dictionary) -> void:
	_to_session(&"on_tree", [params])


@rpc("authority", "reliable", "call_remote", 2)
func rx_props(list: Array) -> void:
	_to_session(&"on_props", [list])


@rpc("authority", "reliable", "call_remote", 2)
func rx_text(t: Array) -> void:
	_to_session(&"on_text", [t])


@rpc("authority", "unreliable_ordered", "call_remote", 4)
func rx_animals(list: Array) -> void:
	_to_session(&"on_animals", [list])


@rpc("any_peer", "unreliable_ordered", "call_remote", 5)
func rx_controls(steer: float, rear_brake: bool) -> void:
	_to_session(&"on_controls", [steer, rear_brake])


@rpc("any_peer", "reliable", "call_remote", 2)
func rx_restart_request() -> void:
	if multiplayer.is_server() and session and is_instance_valid(session):
		var director := session.get_parent().get_node_or_null("ChaseDirector")
		if director and director.get("game_over"):
			restart_game()


@rpc("authority", "reliable", "call_remote", 2)
func rx_rivals_fx(kind: String, data: Array) -> void:
	_to_session(&"on_rivals_fx", [kind, data])


## Sachet livré par l'un des joueurs (point de livraison, nom stable du sachet).
@rpc("any_peer", "reliable", "call_remote", 2)
func rx_delivered(target_id: String, bag_name: String) -> void:
	_to_session(&"on_delivered", [target_id, bag_name])
