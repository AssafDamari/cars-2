class_name PlayerController
extends Node3D

@export var engine_force_fwd: float = 2000 
@export var base_friction: float = 6.0
@export var drift_friction: float = 3.5
@export var steering_limit: float = 0.5

@onready var vehicle: Car = get_parent() as Car
@onready var virtual_joystick: VirtualJoystick = $"Player controllsUI/VirtualJoystick"
@onready var debug_lable: Label = $"Player controllsUI/DebugLable"
@onready var gear_slider: GearSlider = $"Player controllsUI/GearSlider"

func _ready() -> void:
	GlobalSignals.show_debug_text.connect(show_debug_lable)
	
func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		
	# Power Logic
	vehicle.engine_force_to_apply = get_engine_force() 
	
	# Steering Logic
	var steer_input = -input_dir.x
	
	vehicle.steering = lerp(vehicle.steering, steer_input * steering_limit, 10 * delta)	
	
	# Braking Logic
	if should_brake():
		vehicle.brake_car()
		vehicle.show_brake_indicator()
	else:
		vehicle.brake = 0.0
		vehicle.hide_brake_indicator()
	
	_apply_dynamic_drift(steer_input, delta)

	
func _apply_dynamic_drift(steer_input: float, delta: float) -> void:
	var steer_intensity = abs(steer_input)
	var target_friction = base_friction
	
	if steer_intensity > 0.6 and vehicle.current_speed > 5.0:
		target_friction = drift_friction
	else:
		target_friction = base_friction

	vehicle.wheel_back_left.wheel_friction_slip = lerp(vehicle.wheel_back_left.wheel_friction_slip, target_friction, 5 * delta)
	vehicle.wheel_back_right.wheel_friction_slip = lerp(vehicle.wheel_back_right.wheel_friction_slip, target_friction, 5 * delta)
	
	# Simple differential logic
	if steer_input > 0: # Turning Right
		vehicle.wheel_back_left.engine_force = vehicle.engine_force * 1.2
		vehicle.wheel_back_right.engine_force = vehicle.engine_force * 0.8
	elif steer_input < 0: # Turning Left
		vehicle.wheel_back_left.engine_force = vehicle.engine_force * 1.2
		vehicle.wheel_back_right.engine_force = vehicle.engine_force * 0.8

func get_engine_force() -> float:
	match gear_slider.current_gear:
		gear_slider.Gear.DRIVE:
			return engine_force_fwd
		gear_slider.Gear.REVERSE:
			return -1000.0
		_:
			return 0.0

func should_brake() -> bool:
	return Input.is_action_pressed("ui_accept")
		
func _on_button_pressed() -> void:
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	GlobalSceneManager.load_menu()

func show_debug_lable(debug_text)->void:
	debug_lable.text = debug_text
