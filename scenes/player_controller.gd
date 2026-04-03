extends Node3D
@onready var vehicle: VehicleBody3D = get_parent()
@onready var joystick: VirtualJoystickPlus = $"Player controllsUI/VirtualJoystickPlus"
@onready var touch_screen_button_shift: TouchScreenButton = $"Player controllsUI/Shift/TouchScreenButtonShift"
@onready var debug_lable: Label = $"Player controllsUI/DebugLable"

@export var max_speed: float = 15
@export var max_engine_force: float = 1500.0
@export var max_brake_force: float = 20.0
@export var max_steering_angle: float = 0.4 
@export var steering_speed: float = 0.3

func _physics_process(delta: float) -> void:
	 
	var speed_sq = vehicle.linear_velocity.length_squared()
	
	var joystick_input := joystick.get_value()
	
	# 1. power 
	# --- Throttle ---
	if speed_sq < max_speed * max_speed:
		vehicle.engine_force = max_engine_force
	else:
		vehicle.engine_force = 0.0
	# 2. steering
	var steer_input = -joystick_input.x	
	var steer_target = steer_input * max_steering_angle
	vehicle.steering = move_toward(vehicle.steering, steer_target, delta * steering_speed)
	
	# 3. Braking
	if Input.is_action_pressed("ui_accept"):
		vehicle.engine_force = 0
		vehicle.brake = max_brake_force
	else:
		vehicle.brake = 0.0


func _on_button_pressed() -> void:
	get_tree().reload_current_scene()
