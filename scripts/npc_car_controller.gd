extends Node3D

@export var debug_mode: bool = false

@export_group("Path Following")
## The Path3D node the NPC will follow.
## Effect: Provides the spatial track data that guides the car's general route.
@export var path_node: Path3D

## Minimum distance in meters the car looks ahead for a target point.
## Effect: Prevents the car from micro-adjusting and spinning out at slow speeds. 
## Lower values = twitchy at low speed; Higher values = smooth but sluggish.
@export var min_look_ahead: float = 5.0

## Maximum distance in meters the car looks ahead for a target point.
## Effect: Prevents the car from looking too far down the track at high speeds. 
## Lower values = sharp turning/cutting corners; Higher values = takes wider, smoother racing lines.
@export var max_look_ahead: float = 40.0

## Controls how rapidly the look-ahead distance scales up as the car speeds up.
## Effect: Higher values push the look-ahead point further away faster as speed increases.
@export var speed_factor: float = 1.0


@export_group("Driving Dynamics")
## The default forward force applied to the vehicle's wheels.
## Effect: Higher values create faster acceleration and a higher top climbing speed.
@export var engine_force_fwd: float = 2000.0

## Proportional gain for steering (PD Controller).
## Effect: Dictates how hard the car tries to steer toward the error. 
## Higher values = aggressive turning and tighter correction; Too high = side-to-side wobbling.
@export var steer_p: float = 0.5

## Derivative gain for steering (PD Controller).
## Effect: Dampens the steering to prevent the car from overshooting the target. 
## Higher values = smoother transitions, counteracts wobbling; Too high = sluggish steering response.
@export var steer_d: float = 0.7

## The maximum distance (in meters) an NPC can drift left or right from the center of the path.
## Effect: Higher values create wider spacing between cars, effectively creating multi-lane behavior.
@export var max_lane_offset: float = 5 


@onready var vehicle: VehicleBody3D = get_parent() as VehicleBody3D
@onready var collision_sensor: Area3D = $CollisionSensor
@onready var marker: MeshInstance3D = $marker

# --- Internal state ---
var curve: Curve3D
var path_length: float = 0.0
var current_offset: float = -1.0 # Cached path offset for fast local curve lookups
var _sample_points: Array[Vector3] = [] # Reused buffer to eliminate allocations
var last_steer_error: float = 0.0 # Stores previous frame's error for the 'D' part of PD steering.
var is_blocked: bool = false # Flag that stops the car if another car is detected ahead.

# --- Individual Variation ---
var individual_lane_offset: float = 0.0 # This specific NPC's chosen distance from the path center.
var personality_speed_mod: float = 1.0 # Multiplier for this specific NPC's top speed.


func _ready() -> void:
	## Effect: Validates nodes, caches curve calculations for performance, connects signals, 
	## and initiates the randomized variations so each spawned NPC behaves uniquely.
	if not vehicle:
		push_error("NPC Controller must be child of a VehicleBody3D")
		return
	
	if path_node:
		curve = path_node.curve
		path_length = curve.get_baked_length()
	else:
		push_error("NPC Controller path_node is not set.")

	if collision_sensor:
		collision_sensor.body_entered.connect(_on_collision_sensor_entered)
		collision_sensor.body_exited.connect(_on_collision_sensor_exited)

	_apply_random_variation()
	_setup_debug_marker()


func _apply_random_variation() -> void:
	## Effect: Breaks the "conga line" effect. It forces each car to take a different lane 
	## and modifies its personality variables slightly so cars don't drive at the exact same speeds or turn rates.
	
	# Randomize lateral position (lane)
	individual_lane_offset = randf_range(-max_lane_offset, max_lane_offset)
	
	# Randomize driving style (creates fast/slow cars and aggressive/lazy turners)
	personality_speed_mod = randf_range(0.9, 1.1)
	steer_p *= randf_range(0.8, 1.2)
	min_look_ahead *= randf_range(0.8, 1.2)


func _physics_process(delta: float) -> void:
	## Effect: The main brain. Every physics frame it updates the NPC's desired look-ahead, 
	## figures out where the track is, applies the lateral offset, projects that into 3D world space, 
	## updates the visual helper marker, and makes the decision to either stop or drive.
	if not curve or not vehicle or path_length == 0.0:
		return

	# 1. Calculate Look-Ahead (further ahead = smoother lines at speed)
	var look_ahead = min(max_look_ahead, min_look_ahead + vehicle.current_speed * speed_factor)

	# 2. Get Path Coordinates (finds where the car currently maps onto the 3D curve using fast local search)
	var path_transform = path_node.global_transform
	var inv_path_transform = path_transform.affine_inverse()
	var local_pos = inv_path_transform * vehicle.global_transform.origin
	var offset = _get_closest_offset_local(local_pos)

	# 3. Calculate Target Point with Lateral Offset
	# Wrap-around logic for looping tracks
	var target_path_offset = fposmod(offset + look_ahead, path_length) 
	
	# Sample points to calculate the "Right" vector for perpendicular lane offsetting
	var raw_pos = curve.sample_baked(target_path_offset)
	var ahead_pos = curve.sample_baked(fposmod(target_path_offset + 0.5, path_length))
	var dir = (ahead_pos - raw_pos).normalized()
	var side_vec = dir.cross(Vector3.UP).normalized()
	
	# Push the target point to the left or right based on the individual's lane offset
	var offset_pos = raw_pos + (side_vec * individual_lane_offset)
	var target_point_global = path_transform * offset_pos
	
	# Update debug marker position so you can visually track where the car wants to go
	if debug_mode:
		marker.global_position = target_point_global

	# 4. Obstacle Avoidance Decision
	if is_blocked:
		vehicle.brake_car()
		vehicle.show_brake_indicator()
	else:
		vehicle.brake = 0.0
		vehicle.hide_brake_indicator()
		_drive_towards(vehicle.to_local(target_point_global), delta)


## Finds the closest offset on the curve using a fast local search window around the cached offset.
func _get_closest_offset_local(local_pos: Vector3) -> float:
	if current_offset < 0.0:
		current_offset = curve.get_closest_offset(local_pos)
		return current_offset

	const SEARCH_BACK: float = 10.0
	const SEARCH_FWD: float = 25.0
	const STEP: float = 2.5
	const FALLBACK_DIST_SQ: float = 900.0 # 30 meters squared

	var start_s = current_offset - SEARCH_BACK
	var end_s = current_offset + SEARCH_FWD
	var num_steps = int((end_s - start_s) / STEP) + 1

	if _sample_points.size() != num_steps:
		_sample_points.resize(num_steps)

	var best_s = start_s
	var best_dist_sq = INF
	var best_idx = 0

	for i in range(num_steps):
		var s = start_s + i * STEP
		var pt = curve.sample_baked(fposmod(s, path_length))
		_sample_points[i] = pt
		var d_sq = pt.distance_squared_to(local_pos)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best_s = s
			best_idx = i

	# If car drifted off-track or was teleported, recover via global lookup
	if best_dist_sq > FALLBACK_DIST_SQ:
		current_offset = curve.get_closest_offset(local_pos)
		return current_offset

	# Analytical line-segment projection refinement on adjacent segments
	var refined_s = best_s
	var min_refined_dist_sq = best_dist_sq

	if best_idx > 0:
		var p1 = _sample_points[best_idx - 1]
		var p2 = _sample_points[best_idx]
		var seg = p2 - p1
		var seg_len_sq = seg.length_squared()
		if seg_len_sq > 0.0001:
			var t = clampf((local_pos - p1).dot(seg) / seg_len_sq, 0.0, 1.0)
			var proj = p1 + seg * t
			var d_sq = proj.distance_squared_to(local_pos)
			if d_sq < min_refined_dist_sq:
				min_refined_dist_sq = d_sq
				refined_s = (start_s + (best_idx - 1) * STEP) + t * STEP

	if best_idx < num_steps - 1:
		var p1 = _sample_points[best_idx]
		var p2 = _sample_points[best_idx + 1]
		var seg = p2 - p1
		var seg_len_sq = seg.length_squared()
		if seg_len_sq > 0.0001:
			var t = clampf((local_pos - p1).dot(seg) / seg_len_sq, 0.0, 1.0)
			var proj = p1 + seg * t
			var d_sq = proj.distance_squared_to(local_pos)
			if d_sq < min_refined_dist_sq:
				min_refined_dist_sq = d_sq
				refined_s = (start_s + best_idx * STEP) + t * STEP

	current_offset = fposmod(refined_s, path_length)
	return current_offset

func _drive_towards(local_target: Vector3, delta: float) -> void:
	## Effect: Applies the mechanical control inputs to the VehicleBody3D based on where 
	## the offset target is relative to the car's current position.
	
	# PD Controller for Steering
	# atan2(-x, -z) reads angles natively in Godot's -Z forward system
	var steer_error = atan2(-local_target.x, -local_target.z)
	
	# D (Derivative) detects how fast the error is closing to prevent overshooting
	var error_change = (steer_error - last_steer_error) / delta
	last_steer_error = steer_error

	# Combine P and D calculations to get final steering amount
	var target_steering = steer_error * steer_p + error_change * steer_d
	
	# Smooth the steering application so the wheels don't instantly snap left/right
	vehicle.steering = lerp(vehicle.steering, clamp(target_steering, -0.6, 0.6), 10 * delta)

	# Throttle Logic
	vehicle.engine_force = engine_force_fwd


func _on_collision_sensor_entered(body: Node3D) -> void:
	## Effect: Prevents bumper-to-bumper collisions. If the car's front Area3D detects 
	## another vehicle in group "CAR", it trips the 'is_blocked' state and brakes.
	if body != vehicle and body.is_in_group("CAR"):
		is_blocked = true


func _on_collision_sensor_exited(body: Node3D) -> void:
	## Effect: Clears the brake state once the obstruction pulls away or turns.
	if body != vehicle and body.is_in_group("CAR"):
		is_blocked = false


func _setup_debug_marker() -> void:
	if not debug_mode:
		return
	marker.visible = debug_mode
	## Effect: Purely cosmetic. It colors the little target marker to match the color 
	## of the car chasing it, making it easy to see which marker belongs to which NPC.
	if marker and vehicle.get("color"):
		var material := marker.get_active_material(0).duplicate(true)
		material.albedo_color = vehicle.color
		marker.set_surface_override_material(0, material)
