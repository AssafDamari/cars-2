extends VehicleBody3D

@export var max_engine_force: float = 400.0
@export var max_brake_force: float = 20.0
@export var max_steering_angle: float = 0.4  # In radians (0.3 is approx 30 degrees)
@export var steering_speed: float = 2.0 # Lower = Slower steering

func _physics_process(delta: float) -> void:
	# 1. Acceleration and Reverse
	var throttle = Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")

	engine_force = throttle * max_engine_force
	
	# 2. Steering
	var steer_input = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
	var steer_target = steer_input * max_steering_angle
	steering = move_toward(steering, steer_target, delta * steering_speed)
	
	# 3. Braking (Optional separate key)
	if Input.is_action_pressed("ui_accept"): # Example: Spacebar
		brake = max_brake_force
	else:
		brake = 0.0
