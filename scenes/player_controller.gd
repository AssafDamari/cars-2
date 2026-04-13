extends Node3D

@export var engine_force_fwd: float = 2000 
@export var base_friction: float = 6.0
@export var drift_friction: float = 3.5
@export var steering_limit: float = 0.5

@onready var vehicle: Car = get_parent() as Car
@onready var joystick: VirtualJoystickPlus = $"Player controllsUI/VirtualJoystickPlus"
@onready var debug_lable: Label = $"Player controllsUI/DebugLable"
@onready var gear_slider: GearSlider = $"Player controllsUI/GearSlider"

func _physics_process(delta: float) -> void:
	
	var joystick_input := joystick.get_value()
	# 1. power 
	var speed_sq = vehicle.linear_velocity.length_squared()
	if speed_sq < vehicle.max_speed * vehicle.max_speed:
		vehicle.engine_force = get_engine_force()
	else:
		vehicle.engine_force = 0.0
	
	# 2. steering
	var steer_input = -joystick_input.x	
	
	# if not using joystick, use keyboard input
	if steer_input == 0.0:
		steer_input = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
	
	#var steer_target = steer_input 
	#vehicle.steering = move_toward(vehicle.steering, steer_target, delta)
	vehicle.steering = lerp(vehicle.steering, steer_input * steering_limit, 10 * delta)	
	# 3. Braking
	if should_brake(joystick_input):
		vehicle.brake_car()
		#speed_slider.value = 0
		vehicle.show_brake_indicator()
	else:
		vehicle.brake = 0.0
		vehicle.hide_brake_indicator()
	_apply_dynamic_drift(steer_input, delta)
	
func _apply_dynamic_drift(steer_input: float, delta: float) -> void:
	# 2. Calculate "Drift Intensity" based on steering angle and speed
	# We want less grip when steering hard at high speeds
	var speed = vehicle.linear_velocity.length()
	var steer_intensity = abs(steer_input)
	
	var target_friction = base_friction
	
	# Logic: If steering hard and moving fast, drop friction to slide
	if steer_intensity > 0.6 and speed > 5.0:
		target_friction = drift_friction
	else:
		# Smoothly return to base friction to "catch" the car
		target_friction = base_friction

	# 3. Apply the friction slip smoothly to avoid "snapping"
	vehicle.wheel_back_left.wheel_friction_slip = lerp(vehicle.wheel_back_left.wheel_friction_slip, target_friction, 5 * delta)
	vehicle.wheel_back_right.wheel_friction_slip = lerp(vehicle.wheel_back_right.wheel_friction_slip, target_friction, 5 * delta)
	
	if steer_input > 0: # Turning Right
		vehicle.wheel_back_left.engine_force = vehicle.engine_force * 1.2
		vehicle.wheel_back_right.engine_force = vehicle.engine_force * 0.8
	elif steer_input < 0: # Turning Left
		vehicle.wheel_back_left.engine_force = vehicle.engine_force* 1.2
		vehicle.wheel_back_right.engine_force = vehicle.engine_force* 0.8
	
func get_engine_force():
	if gear_slider.current_gear == gear_slider.Gear.DRIVE:
		return engine_force_fwd
	elif gear_slider.current_gear == gear_slider.Gear.NEUTRAL:
		return 0
	elif gear_slider.current_gear == gear_slider.Gear.REVERSE:
		return -1000
		
func should_brake(_joystick_input: Vector2) -> bool:
	if Input.is_action_pressed("ui_accept"):
		# brake button clicked
		return true
	#elif joystick_input.y > 0.9:
		## going forward and joystick pulled down
		#return true
	#elif joystick_input.y < -0.9:
		## going back and joystick pulled up
		#return true
	# no need to brake
	return false
	
		
func _on_button_pressed() -> void:
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
