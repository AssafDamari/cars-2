class_name PlayerController
extends Node3D

const DEFAULT_WHEEL_GRIP := 10.5

@export var engine_force_fwd: float = 2000 
@export var base_friction: float = 6.0
@export var drift_friction: float = 3.5

@export_group("Steering")
## Hard upper limit for the wheel angle (radians) at low speed.
@export var steering_limit: float = 0.45
## How fast the wheels turn toward the joystick position (higher = snappier).
@export var steer_speed_factor: float = 10.0
## How fast the wheels return to center after the joystick is released.
@export var steer_return_factor: float = 12.0
## Lateral acceleration (m/s²) the car may use at full tire grip. The actual
## limit is scaled down for slippery cars, which keeps them from spinning.
@export var max_lateral_acceleration: float = 80.0
## Lowest grip scaling applied to very slippery cars (0.5 = half the limit).
@export_range(0.1, 1.0, 0.05) var min_grip_steering_factor: float = 0.5
## Smallest wheel angle kept at very high speed so the car can still turn.
@export var min_steering_limit: float = 0.02
## Joystick travel around the center that is ignored.
@export_range(0.0, 0.5, 0.01) var steer_deadzone: float = 0.08
## Input response curve. Values above 1 give finer control near the center.
@export_range(1.0, 3.0, 0.05) var steer_curve: float = 1.4

@onready var vehicle: Car = get_parent() as Car
@onready var virtual_joystick: VirtualJoystick = $"Player controllsUI/VirtualJoystick"
@onready var debug_lable: Label = $"Player controllsUI/DebugLable"
@onready var gear_slider: GearSlider = $"Player controllsUI/GearSlider"

var wheelbase: float = 0.0
var grip_steering_factor: float = 1.0

func _ready() -> void:
	GlobalSignals.show_debug_text.connect(show_debug_lable)

	# The FPS counter is a debug tool only. Drop it (and its per-frame Label
	# update) from exported release builds and keep it in editor/debug runs.
	if not OS.is_debug_build():
		var fps_label := get_node_or_null("Player controllsUI/TopToolbar/FpsLabel")
		if fps_label:
			fps_label.queue_free()

func _exit_tree() -> void:
	GlobalSignals.show_debug_text.disconnect(show_debug_lable)
	
func _physics_process(delta: float) -> void:
	# Power Logic
	vehicle.engine_force_to_apply = get_engine_force() 
	
	# Steering Logic
	_update_steering(delta)
	
	# Braking Logic
	if should_brake():
		vehicle.brake_car()
		vehicle.show_brake_indicator()
	else:
		vehicle.brake = 0.0
		vehicle.hide_brake_indicator()
	
	# temp disable drift logic for now I want to check if we can get behavior viw vhicle and wheels configuration
	#_apply_dynamic_drift(steer_input, delta)

	
func _update_steering(delta: float) -> void:
	# Positive steering turns left, so invert the right/left joystick axis.
	var steer_input := -_get_steer_input()
	var target_steering := steer_input * _get_speed_steering_limit()

	# Turning in is slower than snapping back to center (or counter-steering).
	var is_returning := absf(steer_input) < 0.01 or vehicle.steering * target_steering < 0.0
	var response := steer_return_factor if is_returning else steer_speed_factor

	# Exponential smoothing is frame-rate independent and never overshoots.
	var weight := 1.0 - exp(-response * delta)
	vehicle.steering = lerpf(vehicle.steering, target_steering, weight)


func _get_steer_input() -> float:
	# Read the action strengths directly instead of Input.get_vector(): the
	# ui_* actions have a 0.5 deadzone for UI navigation, which would throw
	# away most of the analog range of the virtual joystick.
	var raw := Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	var magnitude := absf(clampf(raw, -1.0, 1.0))
	if magnitude <= steer_deadzone:
		return 0.0

	magnitude = (magnitude - steer_deadzone) / maxf(1.0 - steer_deadzone, 0.001)
	# At high speed, favour responsiveness over fine center control.
	var speed_blend := clampf(vehicle.current_speed / maxf(vehicle.max_speed, 1.0), 0.0, 1.0)
	var curve := lerpf(steer_curve, 1.0, speed_blend)
	magnitude = pow(magnitude, curve)
	return signf(raw) * magnitude


func _get_speed_steering_limit() -> float:
	# The parent car initializes its wheel references after this node is ready,
	# so measure the wheelbase and grip lazily on the first physics frame.
	if wheelbase <= 0.0:
		wheelbase = maxf(absf(vehicle.wheel_front_left.position.z - vehicle.wheel_back_left.position.z), 0.5)
		var front_grip := vehicle.wheel_front_left.wheel_friction_slip
		grip_steering_factor = clampf(front_grip / DEFAULT_WHEEL_GRIP, min_grip_steering_factor, 1.0)

	# Limit the wheel angle to what the tires can actually use at this speed:
	# lateral_acceleration = speed² / turn_radius, radius = wheelbase / tan(angle).
	# This keeps full lock available when slow but reduces it as speed rises.
	var speed := maxf(vehicle.current_speed, 0.001)
	var lateral_acceleration := max_lateral_acceleration * grip_steering_factor
	var grip_limited_angle := atan(wheelbase * lateral_acceleration / (speed * speed))
	return clampf(grip_limited_angle, minf(min_steering_limit, steering_limit), steering_limit)


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
