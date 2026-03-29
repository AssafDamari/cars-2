extends VehicleBody3D

@export var path_node: Path3D # Assign the Path3D from your scene
@export var target_speed: float = 30.0
@export var look_ahead_distance: float = 10.0 # How far down the path to "look"
@export var braking_force: float = 30.0

@onready var sensor: RayCast3D = $Sensor
var curve: Curve3D

func _ready() -> void:
	if path_node:
		curve = path_node.curve

func _physics_process(_delta: float) -> void:
	if not curve:
		return

	# 1. Find where the car is on the path (in units of distance/offset)
	var current_global_pos = global_transform.origin
	# This converts the car's world position to the nearest point on the path
	var local_pos = path_node.to_local(current_global_pos)
	var current_offset = curve.get_closest_offset(local_pos)

	# 2. Set a target point further down the path
	# This prevents the car from "overtaking" its target
	var target_offset = current_offset + look_ahead_distance
	
	# If the path is closed/looped, wrap the offset
	if curve.bake_interval > 0: # Ensure curve exists
		target_offset = fmod(target_offset, curve.get_baked_length())

	var target_path_point = path_node.to_global(curve.sample_baked(target_offset))
	var local_target = to_local(target_path_point)

	# 3. Logic Switch: Obstacle vs Driving
	if sensor.is_colliding():
		apply_braking()
	else:
		drive_towards(local_target)

func drive_towards(target: Vector3) -> void:
	brake = 0.0
	
	# Steering: Angle to the target point
	var steer_angle = atan2(target.x, target.z)
	steering = lerp(steering, steer_angle, 0.1)
	
	# Simple Cruise Control:
	# If the car is moving slower than target_speed, apply force
	var current_velocity = linear_velocity.length()
	if current_velocity < target_speed:
		engine_force = 50.0 # Adjust based on car weight
	else:
		engine_force = 0.0

func apply_braking() -> void:
	engine_force = 0.0
	brake = braking_force
