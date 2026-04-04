extends Node3D
@onready var vehicle: Car = get_parent() as Car
@onready var joystick: VirtualJoystickPlus = $"Player controllsUI/VirtualJoystickPlus"
@onready var debug_lable: Label = $"Player controllsUI/DebugLable"
@onready var speed_slider: VSlider = $"Player controllsUI/SpeedSlider"


func _physics_process(delta: float) -> void:
	 
	var speed_sq = vehicle.linear_velocity.length_squared()
	
	var joystick_input := joystick.get_value()
	
	# 1. power 
	if speed_sq < vehicle.max_speed * vehicle.max_speed:
		vehicle.engine_force = speed_slider.value
	else:
		vehicle.engine_force = 0.0
	
	
	# 2. steering
	var steer_input = -joystick_input.x	
	var steer_target = steer_input * vehicle.max_steering_angle
	vehicle.steering = move_toward(vehicle.steering, steer_target, delta * vehicle.steering_speed)
	
	# 3. Braking
	if Input.is_action_pressed("ui_accept"):
		vehicle.engine_force = 0
		vehicle.brake = vehicle.max_brake_force
	else:
		vehicle.brake = 0.0


func _on_button_pressed() -> void:
	get_tree().reload_current_scene()
