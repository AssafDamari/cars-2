extends Node3D
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
	
	var steer_target = steer_input * vehicle.max_steering_angle
	vehicle.steering = move_toward(vehicle.steering, steer_target, delta * vehicle.steering_speed)
	
	# 3. Braking
	if should_brake(joystick_input):
		vehicle.brake_car()
		#speed_slider.value = 0
		vehicle.show_brake_indicator()
	else:
		vehicle.brake = 0.0
		vehicle.hide_brake_indicator()

func get_engine_force():
	if gear_slider.current_gear == gear_slider.Gear.DRIVE:
		return 2000
	elif gear_slider.current_gear == gear_slider.Gear.NEUTRAL:
		return 0
	elif gear_slider.current_gear == gear_slider.Gear.REVERSE:
		return -1000
		
func should_brake(joystick_input: Vector2) -> bool:
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
