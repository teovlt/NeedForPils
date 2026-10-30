extends StartXR
## Démarre la VR si un casque est disponible, sinon passe en mode bureau :
## clavier pour conduire (voir suv_4x4.gd) et souris pour regarder / attraper.
## Menu pause (bouton menu de la manette gauche, P sans casque). Partie à deux : ajoute
## la NetSession (synchronisation avec l'autre joueur).


func _enter_tree() -> void:
	# partie à deux : mêmes tirages au hasard chez les deux joueurs pendant le chargement
	# (nombre de cigarettes, place des objets...), avant le _ready des enfants
	if Net.world_seed("global") != 0:
		seed(Net.world_seed("global"))

func _ready():
	var xr := XRServer.find_interface("OpenXR")
	if xr and xr.is_initialized():
		super._ready()
		# Initialise le casque VR quand la session démarre
		if xr_interface and xr_interface.is_initialized() 				and not xr_interface.session_begun.is_connected(_on_openxr_session_begun):
			xr_interface.session_begun.connect(_on_openxr_session_begun)
	else:
		_start_desktop_mode()
	var pause := PauseMenu.new()
	pause.name = "PauseMenu"
	add_child(pause)
	if Net.is_online():
		var session := NetSession.new()
		session.name = "NetSession"
		add_child(session)


func _on_openxr_session_begun() -> void:
	# Force le mode VR opaque (pas de passthrough)
	xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_OPAQUE


func _start_desktop_mode() -> void:
	print("Pas de casque VR détecté : mode bureau (clavier + souris).")
	await get_tree().process_frame   # laisse le joueur s'installer au volant
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var hand := MouseHand.new()
	hand.name = "MouseHand"
	hand.camera = cam
	add_child(hand)
