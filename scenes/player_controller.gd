extends Node3D

@export_group("Engine Settings")
@export var engine_force_fwd: float = 2000 
@export var off_road_penalty: float = 0.25 # Only 25% power when off-track

@export_group("Physics Settings")
@export var base_friction: float = 6.0
@export var drift_friction: float = 3.5
@export var steering_limit: float = 0.5

@onready var vehicle: Car = get_parent() as Car
@onready var joystick: VirtualJoystickPlus = $"Player controllsUI/VirtualJoystickPlus"
@onready var debug_lable: Label = $"Player controllsUI/DebugLable"
@onready var gear_slider: GearSlider = $"Player controllsUI/GearSlider"
@onready var track_sensor: RayCast3D = $TrackSensor
@onready var debug: MeshInstance3D = $MeshInstance3D

# Internal state
var _current_modifier: float = 1.0

func _physics_process(delta: float) -> void:
	var joystick_input := joystick.get_value()
	
	# 1. Surface Detection & Penalty
	_handle_off_road_logic(delta)
	
	# 2. Power Logic
	var speed_sq = vehicle.linear_velocity.length_squared()
	if speed_sq < vehicle.max_speed * vehicle.max_speed:
		# Apply the calculated modifier to the engine force
		vehicle.engine_force = get_engine_force() * _current_modifier
	else:
		vehicle.engine_force = 0.0
	
	# 3. Steering Logic
	var steer_input = -joystick_input.x	
	if steer_input == 0.0:
		steer_input = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
	
	vehicle.steering = lerp(vehicle.steering, steer_input * steering_limit, 10 * delta)	
	
	# 4. Braking Logic
	if should_brake(joystick_input):
		vehicle.brake_car()
		vehicle.show_brake_indicator()
	else:
		vehicle.brake = 0.0
		vehicle.hide_brake_indicator()
	
	_apply_dynamic_drift(steer_input, delta)

func _handle_off_road_logic(_delta: float) -> void:
	var target_mod = 1.0 # Default to full speed
	
	if track_sensor.is_colliding():
		var collider = track_sensor.get_collider()
		# If the raycast hits something NOT in the TRACK group
		if not collider.is_in_group("TRACK"):
			target_mod = off_road_penalty
	else:
		# If raycast hits nothing (in the air or out of bounds)
		target_mod = off_road_penalty
	
	# Smoothly interpolate the modifier so the car doesn't jerk
	_current_modifier = target_mod
	debug.visible = false if target_mod == 1.0 else true
	
func _apply_dynamic_drift(steer_input: float, delta: float) -> void:
	var speed = vehicle.linear_velocity.length()
	var steer_intensity = abs(steer_input)
	var target_friction = base_friction
	
	if steer_intensity > 0.6 and speed > 5.0:
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

func should_brake(_joystick_input: Vector2) -> bool:
	return Input.is_action_pressed("ui_accept")
		
func _on_button_pressed() -> void:
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
