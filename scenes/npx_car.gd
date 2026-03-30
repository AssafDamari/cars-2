extends VehicleBody3D

@export var debug_mode: bool = false
@export var path_node: Path3D 
@export var target_speed: float = 40.0
@export var color: Color = Color.WHITE
@export var braking_force: float = 30.0

@export_group("Steering Tuning")
@export var steer_speed: float = 10.0
@export var steer_p: float = 0.8 
@export var steer_d: float = 0.3 

@export_group("Look Ahead Settings")
@export var min_look_ahead: float = 5.0
@export var max_look_ahead: float = 40.0
@export var speed_factor: float = 0.8

@export_group("Performance")
@export var sensor_interval: float = 0.1  # Raycast update rate (seconds)

@onready var body_mesh: MeshInstance3D = $Body/MeshInstance3D
@onready var debug_marker: MeshInstance3D = $DebugMarker


# Cached values
var curve: Curve3D
var path_length: float = 0.0

# Steering state
var last_steer_error: float = 0.0
var is_blocked: bool = false


func _ready() -> void:
	if path_node:
		curve = path_node.curve
		path_length = curve.get_baked_length()

	apply_color_to_mesh(color)

	if not debug_mode and debug_marker:
		debug_marker.visible = false


func _physics_process(delta: float) -> void:
	if not curve:
		return

	# --- Speed ---
	var vel = linear_velocity
	var speed_sq = vel.length_squared()
	var speed = sqrt(speed_sq)  # only once

	# --- Dynamic look-ahead ---
	var look_ahead = min(max_look_ahead, min_look_ahead + speed * speed_factor)

	# --- Cache transforms ---
	var path_transform = path_node.global_transform
	var inv_path_transform = path_transform.affine_inverse()

	# --- Current position on path ---
	var global_pos = global_transform.origin
	var local_pos = inv_path_transform * global_pos
	var current_offset = curve.get_closest_offset(local_pos)

	# --- Target point ---
	var target_offset = current_offset + look_ahead
	if path_length > 0.0:
		target_offset = fmod(target_offset, path_length)

	var target_point = path_transform * curve.sample_baked(target_offset)

	if debug_mode:
		debug_marker.global_position = target_point

	var local_target = to_local(target_point)

	# --- Decision ---
	if is_blocked:
		apply_braking()
		return

	drive_towards(local_target, delta, speed_sq)


func drive_towards(target: Vector3, delta: float, speed_sq: float) -> void:
	brake = 0.0

	# --- Steering (PD controller) ---
	var steer_error = atan2(target.x, target.z)
	var error_change = (steer_error - last_steer_error) / delta
	last_steer_error = steer_error

	var target_steering = steer_error * steer_p + error_change * steer_d
	target_steering = clamp(target_steering, -0.6, 0.6)

	steering = lerp(steering, target_steering, delta * steer_speed)

	# --- Throttle ---
	if speed_sq < target_speed * target_speed:
		engine_force = 1000.0
	else:
		engine_force = 0.0


func apply_braking() -> void:
	engine_force = 0.0
	brake = braking_force


func apply_color_to_mesh(_color: Color) -> void:
	var material := body_mesh.get_active_material(0).duplicate(true)
	material.albedo_color = _color
	body_mesh.set_surface_override_material(0, material)

	if debug_mode:
		debug_marker.set_surface_override_material(0, material)
