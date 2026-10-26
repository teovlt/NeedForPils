extends StartXR

# Menu d'accueil : un panneau 3D flottant au milieu d'une forêt.
# - Avec casque : on clique avec le laser des manettes (gâchette).
# - Sans casque : caméra classique, on clique à la souris.

## Scène lancée par JOUER avec le casque
@export_file("*.tscn") var game_scene: String = "res://main.tscn"
## Scène lancée par JOUER sans casque (main.tscn passe seule en mode bureau : clavier + souris)
@export_file("*.tscn") var desktop_game_scene: String = "res://main.tscn"

# Amplitude (m) et vitesse du flottement du panneau
@export var float_amplitude: float = 0.03
@export var float_speed: float = 1.2

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

var vr_enabled := false
var _panel_base_y: float
var _time: float = 0.0
var _height_calibrated := false
var _leaving := false


func _ready():
	var openxr := XRServer.find_interface("OpenXR")
	vr_enabled = openxr != null and openxr.is_initialized()

	if vr_enabled:
		# StartXR configure le casque (et quitterait le jeu sans casque)
		super._ready()
		# Force le mode VR opaque (pas de passthrough)
		xr_interface.session_begun.connect(_set_opaque)
		_set_opaque()
	else:
		_setup_desktop()

	_panel_base_y = menu_panel.position.y

	var ui = menu_panel.get_scene_instance()
	ui.play_pressed.connect(_on_play_pressed)
	ui.quit_pressed.connect(_on_quit_pressed)

	_start_audio()


func _process(delta: float) -> void:
	# Petit effet de flottement du panneau
	_time += delta
	menu_panel.position.y = _panel_base_y + sin(_time * float_speed) * float_amplitude

	if vr_enabled and not _height_calibrated:
		_calibrate_height()


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

# Si la référence d'espace n'est pas au niveau du sol (la tête est alors vers y = 0),
# on remonte l'origine XR pour que le sol virtuel corresponde au vrai sol.
func _calibrate_height() -> void:
	var head_y := xr_camera.position.y
	if is_zero_approx(xr_camera.position.length()):
		return # Pas encore de suivi du casque
	if head_y < 1.0:
		xr_origin.position.y = fallback_eye_height - head_y
	_height_calibrated = true


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
	_leaving = true
	var tween := create_tween().set_parallel()
	tween.tween_property(music_player, "volume_db", -60.0, fade_time)
	tween.tween_property(ambience_player, "volume_db", -60.0, fade_time)
	tween.chain().tween_callback(action)


func _on_play_pressed() -> void:
	var scene := game_scene if vr_enabled else desktop_game_scene
	_fade_out_then(func(): get_tree().change_scene_to_file(scene))


func _on_quit_pressed() -> void:
	_fade_out_then(func(): get_tree().quit())
