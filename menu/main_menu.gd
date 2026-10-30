extends StartXR

# Menu d'accueil : un panneau 3D flottant au bord de la route du jeu (menu_scenery.gd),
# sous la vraie météo du jeu (heure et temps tirés au hasard, qui changent pendant
# qu'on reste dans le menu).
# - Avec casque : on clique avec le laser des manettes (gâchette).
# - Sans casque : caméra classique, on clique à la souris.
# - JOUER À DEUX : attend l'autre joueur sur le réseau local (voir network/net.gd) ;
#   le premier arrivé conduit, le second est copilote. JOUER SEUL : partie solo.

## Scène lancée par JOUER avec le casque
@export_file("*.tscn") var game_scene: String = "res://main.tscn"
## Scène lancée par JOUER sans casque (main.tscn passe seule en mode bureau : clavier + souris)
@export_file("*.tscn") var desktop_game_scene: String = "res://main.tscn"

# Amplitude (m) et vitesse du flottement du panneau
@export var float_amplitude: float = 0.03
@export var float_speed: float = 1.2

## Météos possibles à l'ouverture du menu, avec leur poids.
const START_WEATHERS := {"degage": 3.0, "eclaircies": 3.0, "nuageux": 2.0, "couvert": 1.0,
	"brouillard": 1.0, "pluie_legere": 1.5, "pluie": 1.0, "orage": 0.5}
## Heures possibles à l'ouverture du menu (souvent au coucher du soleil, vers 17-18 h,
## parfois la nuit).
const START_HOURS := [8.0, 10.5, 13.0, 15.5, 16.8, 17.3, 17.6, 17.9, 18.6, 21.0]

## Hauteur des yeux utilisée si le casque ne fournit pas une référence au niveau du sol
@export var fallback_eye_height: float = 1.7

@export var music_volume_db: float = -6.0
@export var ambience_volume_db: float = -10.0
@export var fade_time: float = 1.5

# Calque physique « pointable » des panneaux XR Tools (calque 21)
const POINTABLE_LAYER := 1 << 20

@onready var menu_panel: Node3D = $MenuPanel
@onready var panel_viewport: SubViewport = $MenuPanel/Viewport
@onready var panel_body: StaticBody3D = $MenuPanel/StaticBody3D
@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var xr_camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var desktop_camera: Camera3D = $DesktopCamera
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var ambience_player: AudioStreamPlayer = $AmbiencePlayer
@onready var weather: WeatherSystem = $Weather
@onready var headlights: Array[Light3D] = [$CarShowcase/HeadlightL, $CarShowcase/HeadlightR]
@onready var fireflies: CPUParticles3D = $Fireflies
@onready var butterflies: CPUParticles3D = $Butterflies

var vr_enabled := false
var _panel_base_y: float
var _time: float = 0.0
var _height_calibrated := false
var _leaving := false
var _ui: Node


func _ready():
	var openxr := XRServer.find_interface("OpenXR")
	vr_enabled = openxr != null and openxr.is_initialized()

	if vr_enabled:
		# StartXR configure le casque (et quitterait le jeu sans casque)
		super._ready()
		# Force le mode VR opaque (pas de passthrough)
		xr_interface.session_begun.connect(_set_opaque)
		_set_opaque()
		# Vue recentrée : le panneau pile en face, où qu'on soit dans la pièce.
		xr_interface.session_begun.connect(func(): get_tree().create_timer(0.5).timeout.connect(_recenter))
		if xr_interface.has_signal("pose_recentered"):
			xr_interface.pose_recentered.connect(_recenter)
		_recenter.call_deferred()
	else:
		_setup_desktop()

	_panel_base_y = menu_panel.position.y

	var ui = menu_panel.get_scene_instance()
	_ui = ui
	ui.play_pressed.connect(_on_play_pressed)
	ui.solo_pressed.connect(_on_solo_pressed)
	ui.quit_pressed.connect(_on_quit_pressed)
	ui.cancel_pressed.connect(_on_cancel_pressed)
	Net.status_changed.connect(_on_net_status)
	Net.connection_lost.connect(_on_net_lost)
	# de retour d'une partie à deux interrompue : on dit pourquoi
	if Net.last_message != "":
		ui.show_main(Net.last_message)
		Net.last_message = ""

	_start_weather()
	_start_audio()
	SceneLoader.loading_started.connect(func(_path): _fade_out_audio())
	# le jeu se charge en arrière-plan pendant qu'on est dans le menu
	get_tree().create_timer(1.5).timeout.connect(func(): SceneLoader.preload_scene(game_scene))


func _process(delta: float) -> void:
	# Petit effet de flottement du panneau
	_time += delta
	menu_panel.position.y = _panel_base_y + sin(_time * float_speed) * float_amplitude

	if vr_enabled and not _height_calibrated:
		_calibrate_height()
	_update_ambience(delta)


func _set_opaque() -> void:
	xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_OPAQUE


# ------------------------------------------------------------------ Mode sans casque

func _setup_desktop() -> void:
	print("Menu : pas de casque détecté, mode écran (souris)")
	# Désactive les mains / lasers VR et passe sur la caméra classique
	xr_origin.visible = false
	for pointer in xr_origin.find_children("*", "XRToolsFunctionPointer", true, false):
		pointer.enabled = false
	desktop_camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if vr_enabled or _leaving:
		return
	if not (event is InputEventMouseMotion or event is InputEventMouseButton):
		return

	# Rayon depuis la souris vers le panneau
	var from := desktop_camera.project_ray_origin(event.position)
	var to := from + desktop_camera.project_ray_normal(event.position) * 20.0
	var query := PhysicsRayQueryParameters3D.create(from, to, POINTABLE_LAYER)
	var hit := desktop_camera.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty() or hit.collider != panel_body:
		# Hors du panneau : on envoie la souris hors champ pour enlever le survol
		var away := InputEventMouseMotion.new()
		away.position = Vector2(-100, -100)
		panel_viewport.push_input(away)
		return

	# Convertit le point touché en coordonnées 2D du panneau et transmet l'événement
	var forwarded: InputEventMouse = event.duplicate()
	forwarded.position = panel_body.global_to_viewport(hit.position)
	forwarded.global_position = forwarded.position
	panel_viewport.push_input(forwarded)
	get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ VR

func _recenter() -> void:
	XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)


# Si la référence d'espace n'est pas au niveau du sol (la tête est alors vers y = 0),
# on remonte l'origine XR pour que le sol virtuel corresponde au vrai sol.
func _calibrate_height() -> void:
	var head_y := xr_camera.position.y
	if is_zero_approx(xr_camera.position.length()):
		return # Pas encore de suivi du casque
	if head_y < 1.0:
		xr_origin.position.y = fallback_eye_height - head_y
	_height_calibrated = true


# ------------------------------------------------------------------ Météo / ambiance

func _start_weather() -> void:
	var total := 0.0
	for k in START_WEATHERS:
		total += START_WEATHERS[k]
	var r := randf() * total
	for k in START_WEATHERS:
		r -= START_WEATHERS[k]
		if r <= 0.0:
			weather.set_weather(k, true)
			break
	weather.hour = START_HOURS[randi() % START_HOURS.size()] + randf_range(-0.2, 0.2)
	$Scenery.set_wet(weather.rain > 0.05)


# Phares et lucioles quand il fait sombre, papillons quand il fait beau.
func _update_ambience(delta: float) -> void:
	var dark := weather.get_darkness()
	var lights_on := dark > 0.45
	for l in headlights:
		l.light_energy = move_toward(l.light_energy, 3.0 if lights_on else 0.0, delta * 6.0)
		l.visible = l.light_energy > 0.01
	fireflies.emitting = dark > 0.55 and weather.rain < 0.1
	butterflies.emitting = dark < 0.3 and weather.rain < 0.02 and weather.wind < 0.9


# ------------------------------------------------------------------ Audio / actions

func _start_audio() -> void:
	for player in [music_player, ambience_player]:
		if player.stream is AudioStreamOggVorbis:
			player.stream.loop = true
		player.volume_db = -60.0
		player.play()
	var tween := create_tween().set_parallel()
	tween.tween_property(music_player, "volume_db", music_volume_db, fade_time)
	tween.tween_property(ambience_player, "volume_db", ambience_volume_db, fade_time)


# Baisse la musique en fondu puis exécute l'action
func _fade_out_then(action: Callable) -> void:
	if _leaving:
		return
	_fade_out_audio()
	get_tree().create_timer(fade_time).timeout.connect(action)


func _fade_out_audio() -> void:
	_leaving = true
	var tween := create_tween().set_parallel()
	tween.tween_property(music_player, "volume_db", -60.0, fade_time)
	tween.tween_property(ambience_player, "volume_db", -60.0, fade_time)
	weather.rain_volume = 0.0


func _on_play_pressed() -> void:
	if _leaving:
		return
	_ui.show_waiting("Recherche d'une partie sur le réseau...")
	Net.find_or_host()


func _on_solo_pressed() -> void:
	if _leaving:
		return
	Net.cancel()
	var scene := game_scene if vr_enabled else desktop_game_scene
	# écran de chargement en fondu pendant que la musique s'éteint
	SceneLoader.change_scene(scene, fade_time)


func _on_cancel_pressed() -> void:
	Net.cancel()
	_ui.show_main()


func _on_net_status(text: String) -> void:
	if Net.state != Net.State.IDLE:
		_ui.show_waiting(text)


func _on_net_lost(reason: String) -> void:
	Net.last_message = ""
	_ui.show_main(reason)


func _on_quit_pressed() -> void:
	_fade_out_then(func(): get_tree().quit())
