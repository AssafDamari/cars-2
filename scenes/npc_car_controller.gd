extends Node3D

@export var path_node: Path3D
@export var target_speed: float = 40.0
@export var braking_force: float = 30.0

@export_group("Steering Tuning")
@export var steer_speed: float = 10.0
@export var steer_p: float = 0.8 
@export var steer_d: float = 0.3 

@export_group("Look Ahead Settings")
@export var min_look_ahead: float = 5.0
@export var max_look_ahead: float = 40.0
@export var speed_factor: float = 0.8

@onready var vehicle: VehicleBody3D = get_parent()
@onready var collision_sensor: Area3D = $CollisionSensor

# Cached values
var curve: Curve3D
var path_length: float = 0.0

# Steering state
var last_steer_error: float = 0.0
var is_blocked: bool = false


func _ready() -> void:
	if not vehicle is VehicleBody3D:
		push_error("NPC Controller must be child of a VehicleBody3D")
		return
	
	if path_node:
		curve = path_node.curve
		path_length = curve.get_baked_length()
		print("Controller ready. Vehicle: ", vehicle.name, ", Path: ", path_node.name, ", Curve length: ", path_length)
	else:
		push_error("NPC Controller path_node is not set for ", name, " and could not be auto-found")
	
	if collision_sensor:
		collision_sensor.area_entered.connect(_on_collision_sensor_entered)
		collision_sensor.area_exited.connect(_on_collision_sensor_exited)


func _physics_process(delta: float) -> void:
	if not curve or not vehicle:
		return

	# --- Speed ---
	var vel = vehicle.linear_velocity
	var speed_sq = vel.length_squared()

	# --- Dynamic look-ahead ---
	var look_ahead = min(max_look_ahead, min_look_ahead + sqrt(speed_sq) * speed_factor)

	# --- Cache transforms ---
	var path_transform = path_node.global_transform
	var inv_path_transform = path_transform.affine_inverse()

	# --- Current position on path ---
	var global_pos = vehicle.global_transform.origin
	var local_pos = inv_path_transform * global_pos
	var current_offset = curve.get_closest_offset(local_pos)

	# --- Target point ---
	var target_offset = current_offset + look_ahead
	if path_length > 0.0:
		target_offset = fmod(target_offset, path_length)

	var target_point = path_transform * curve.sample_baked(target_offset)
	var local_target = vehicle.to_local(target_point)

	# --- Decision ---
	if is_blocked:
		apply_braking()
		return

	drive_towards(local_target, delta, speed_sq)


func drive_towards(target: Vector3, delta: float, speed_sq: float) -> void:
	vehicle.brake = 0.0

	# --- Steering (PD controller) ---
	var steer_error = atan2(target.x, target.z)
	var error_change = (steer_error - last_steer_error) / delta
	last_steer_error = steer_error

	var target_steering = steer_error * steer_p + error_change * steer_d
	target_steering = clamp(target_steering, -0.6, 0.6)

	vehicle.steering = lerp(vehicle.steering, target_steering, delta * steer_speed)

	# --- Throttle ---
	if speed_sq < target_speed * target_speed:
		vehicle.engine_force = 1000.0
	else:
		vehicle.engine_force = 0.0


func apply_braking() -> void:
	vehicle.engine_force = 0.0
	vehicle.brake = braking_force


func _on_collision_sensor_entered(area: Area3D) -> void:
	print("Collision sensor entered by: ", area.name)
	if area.is_in_group("CAR"):
		is_blocked = true
		vehicle.show_brakes_lights()

func _on_collision_sensor_exited(area: Area3D) -> void:
	if area.is_in_group("CAR"):
		is_blocked = false
		vehicle.hide_brakes_lights()
