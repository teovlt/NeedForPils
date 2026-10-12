extends VehicleBody3D

@export var STEER_SPEED: float = 1.5
@export var STEER_LIMIT: float = 0.6
@export var engine_force_value: float = 40.0
@export var brake_force_value: float = 30.0

var reverse_mode: bool = false

# Mets -1 si l'accélération fait partir le modèle à l'envers.
@export var motor_direction: float = -1.0

@onready var left_hand: XRController3D = $look/XROrigin3D/LeftHand
@onready var right_hand: XRController3D = $look/XROrigin3D/RightHand
	
@onready var xr_origin: XROrigin3D = $look/XROrigin3D
@onready var xr_camera: XRCamera3D = $look/XROrigin3D/XRCamera3D
@onready var driver_eyes: Marker3D = $look/DriverEyes

var initial_recenter_done: bool = false
var tracking_time: float = 0.0


func _ready() -> void:
	right_hand.button_pressed.connect(_on_right_button_pressed)
	

func _physics_process(delta: float) -> void:
	var stick: Vector2 = left_hand.get_vector2("primary")
	var turn: float = stick.x

	if absf(turn) < 0.15:
		turn = 0.0

	var accelerator: float = right_hand.get_float("trigger")
	var brake_input: float = left_hand.get_float("trigger")

	var gear_direction: float = -1.0 if reverse_mode else 1.0
	engine_force = accelerator * engine_force_value \
		* motor_direction * gear_direction
	brake = brake_input * brake_force_value

	var steer_target: float = -turn * STEER_LIMIT
	steering = move_toward(
		steering,
		steer_target,
		STEER_SPEED * delta
	)
	
func _on_right_button_pressed(action_name: String) -> void:
	if action_name == "by_button":
		if linear_velocity.length() < 0.5:
			reverse_mode = not reverse_mode
			print("Marche arrière" if reverse_mode else "Marche avant")

	elif action_name == "primary_click":
		recenter_driver()
		if driver_eyes != null:
			initial_recenter_done = true
		
func recenter_driver() -> void:
	if driver_eyes == null:
		push_warning("Repère DriverEyes manquant")
		return

	xr_origin.current = true
	xr_camera.make_current()

	var rig_parent := xr_origin.get_parent() as Node3D

	# Retire l'inclinaison ajoutée à l'origine XR.
	# Le casque conserve son tracking naturel.
	xr_origin.rotation.x = 0.0
	xr_origin.rotation.z = 0.0

	# Directions exprimées dans le repère du parent.
	var inverse_basis := rig_parent.global_transform.basis.inverse()
	var head_forward := inverse_basis * (
		-xr_camera.global_transform.basis.z
	)
	var seat_forward := inverse_basis * (
		-driver_eyes.global_transform.basis.z
	)

	# Aligne uniquement la direction horizontale.
	head_forward.y = 0.0
	seat_forward.y = 0.0

	if head_forward.length_squared() > 0.001 \
			and seat_forward.length_squared() > 0.001:
		var angle := head_forward.normalized().signed_angle_to(
			seat_forward.normalized(), Vector3.UP
		)
		xr_origin.rotate_y(angle)

	# Replace les yeux après la rotation.
	var target := rig_parent.to_local(driver_eyes.global_position)
	var current := rig_parent.to_local(xr_camera.global_position)
	xr_origin.position += target - current


func print_camera_state() -> void:
	var active_camera := xr_camera.get_viewport().get_camera_3d()

	if active_camera != null:
		print("Caméra active : ", active_camera.get_path())

	print("Origine XR active : ", xr_origin.current)
	print("Yeux dans look : ",
		$look.to_local(xr_camera.global_position))
	print("Cible dans look : ", driver_eyes.position)
	
func _process(delta: float) -> void:
	if initial_recenter_done:
		return

	if driver_eyes == null:
		return

	var head := XRServer.get_tracker("head") as XRPositionalTracker
	if head == null:
		tracking_time = 0.0
		return

	var pose := head.get_pose("default")
	if pose == null:
		tracking_time = 0.0
		return

	if not pose.has_tracking_data \
			or pose.tracking_confidence == XRPose.XR_TRACKING_CONFIDENCE_NONE:
		tracking_time = 0.0
		return

	# Laisse quelques images au tracking pour démarrer.
	tracking_time += delta
	if tracking_time < 0.5:
		return

	recenter_driver()
	initial_recenter_done = true
