extends VehicleBody3D

@export var max_engine_force : float = 200.0
@export var max_steering_angle : float = 0.5 # En radians (~30 deg)
@export var max_brake_force : float = 10.0

@onready var steering_hinge = $Cockpit/SteeringWheel
@onready var throttle_hinge = $Cockpit/ThrottleLever

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_steering_wheel_hinge_moved(angle: Variant) -> void:
	var normalized_angle = clamp(angle / PI, -1.0, 1.0)
	steering = -normalized_angle * max_steering_angle

func _on_throttle_lever_hinge_moved(angle: Variant) -> void:
	var ratio = clamp(angle / (PI / 4.0), -1.0, 1.0)
	
	if ratio > 0.05:
		engine_force = ratio * max_engine_force
		brake = 0.0
	elif ratio < -0.05:
		# Marche arrière (ou freinage)
		engine_force = ratio * (max_engine_force * 0.5)
		brake = 0.0
	else:
		# Zone neutre au milieu = frein moteur
		engine_force = 0.0
		brake = max_brake_force
