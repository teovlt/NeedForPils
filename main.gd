extends StartXR

func _ready():
	super._ready()
	# Initialise le casque VR quand la session démarre
	if xr_interface and xr_interface.is_initialized():
		xr_interface.session_begun.connect(_on_openxr_session_begun)

func _on_openxr_session_begun() -> void:
	# Force le mode VR opaque (pas de passthrough)
	xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_OPAQUE
