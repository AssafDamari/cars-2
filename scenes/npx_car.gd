extends VehicleBody3D

@export var path_node: Path3D 
@export var target_speed: float = 40.0
@export var color: Color = Color.WHITE
@export var braking_force: float = 30.0

@export_group("Steering Tuning")
@export var steer_speed: float = 10.0
@export var steer_p: float = 0.8 
@export var steer_d: float = 0.3 

@export_group("Look Ahead Settings")
@export var min_look_ahead: float = 5.0    # Distance when nearly stopped
@export var max_look_ahead: float = 40.0   # Distance at top speed
@export var speed_factor: float = 0.8      # How much speed increases the distance

@onready var body_mesh: MeshInstance3D = $Body/MeshInstance3D
@onready var debug_marker: MeshInstance3D = $DebugMarker
@onready var sensor: RayCast3D = $Sensor

var last_steer_error: float = 0.0
var curve: Curve3D

func _ready() -> void:
	if path_node:
		curve = path_node.curve
		
	if debug_marker:
		debug_marker.top_level = true
		
	apply_color_to_mesh(color)

func _physics_process(_delta: float) -> void:
	if not curve:
		return

	# 1. Get current speed
	var current_velocity = linear_velocity.length()

	# 2. Calculate DYNAMIC Look-Ahead Distance
	# We start at min_look_ahead and add distance based on speed, capping it at max_look_ahead
	var dynamic_look_ahead = min_look_ahead + (current_velocity * speed_factor)
	dynamic_look_ahead = clamp(dynamic_look_ahead, min_look_ahead, max_look_ahead)

	# 3. Find where the car is on the path
	var current_global_pos = global_transform.origin
	var local_pos = path_node.to_local(current_global_pos)
	var current_offset = curve.get_closest_offset(local_pos)

	# 4. Set target point using the dynamic distance
	var target_offset = current_offset + dynamic_look_ahead
	
	var path_length = curve.get_baked_length()
	if path_length > 0:
		target_offset = fmod(target_offset, path_length)

	var target_path_point = path_node.to_global(curve.sample_baked(target_offset))
	
	if debug_marker:
		debug_marker.global_position = target_path_point

	var local_target = to_local(target_path_point)

	# 5. Logic Switch
	if sensor.is_colliding():
		apply_braking()
	else:
		drive_towards(local_target, _delta, current_velocity)

func drive_towards(target: Vector3, _delta: float, current_speed: float) -> void:
	brake = 0.0
	
	# Steering Error
	var steer_error = atan2(target.x, target.z)
	
	# Derivative (Damping)
	var error_change = (steer_error - last_steer_error) / _delta
	last_steer_error = steer_error
	
	# Combine for PID-style steering
	var target_steering = (steer_error * steer_p) + (error_change * steer_d)
	
	# Clamp steering to 0.6 (~35 degrees) to prevent physics glitches
	steering = lerp(steering, clamp(target_steering, -0.6, 0.6), _delta * steer_speed)
	
	# Throttle Logic
	if current_speed < target_speed:
		engine_force = 1000.0 
	else:
		engine_force = 0.0

func apply_braking() -> void:
	engine_force = 0.0
	brake = braking_force
	
func apply_color_to_mesh(_color: Color) -> void:
	var material = body_mesh.get_active_material(0).duplicate(true)
	material.albedo_color = _color
	body_mesh.set_surface_override_material(0, material)
	if debug_marker:
		debug_marker.set_surface_override_material(0, material)
