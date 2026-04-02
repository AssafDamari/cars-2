extends Node3D
@onready var vehicle: VehicleBody3D = get_parent()
@onready var joystick: VirtualJoystickPlus = $"Player controllsUI/VirtualJoystickPlus"
@onready var touch_screen_button_shift: TouchScreenButton = $"Player controllsUI/Shift/TouchScreenButtonShift"

var is_reverse: bool = false
# Preload textures to avoid stuttering during gameplay
var texture_reverse = preload("res://textures/joystickLeft.png")
var texture_forward = preload("res://textures/joystickRight.png") # Example second texture

	
func _physics_process(delta: float) -> void:
	# 1. Acceleration and Reverse Logic
	var gas = Input.is_action_pressed("ui_up")
	
	# FIX: Use is_action_just_pressed so it only toggles ONCE per click
	if Input.is_action_just_pressed("ui_down"):
		is_reverse = !is_reverse
		
		# CORRECT WAY TO CHANGE TEXTURE:
		if is_reverse:
			touch_screen_button_shift.texture_normal = texture_reverse
		else:
			touch_screen_button_shift.texture_normal = texture_forward

	if gas:
		# Apply force based on direction
		vehicle.engine_force = vehicle.max_engine_force * (-1.0 if is_reverse else 1.0)
	else:
		vehicle.engine_force = 0

	# 2. Steering
	var steer_input = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
	var joystick_input := joystick.get_value()
	if joystick_input.length() > 0.0:
		steer_input = -joystick_input.x
		
	var steer_target = steer_input * vehicle.max_steering_angle
	vehicle.steering = move_toward(vehicle.steering, steer_target, delta * vehicle.steering_speed)
	
	# 3. Braking
	if Input.is_action_pressed("ui_accept"):
		vehicle.brake = vehicle.max_brake_force
	else:
		vehicle.brake = 0.0
