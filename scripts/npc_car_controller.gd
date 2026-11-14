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

## How often (in seconds) the car's position on the curve is measured.
## The curve search is the expensive part of this script, so it runs a few times
## per second and the offset is projected forward from the car's speed in between.
@export var path_search_interval: float = 0.1

## How far along the track (in meters) the cheap local search looks around the
## last known point before falling back to a full curve scan.
@export var local_search_radius: float = 30.0


@onready var vehicle: VehicleBody3D = get_parent() as VehicleBody3D
@onready var collision_sensor: Area3D = $CollisionSensor
@onready var marker: MeshInstance3D = $marker

# --- Internal state ---
var curve: Curve3D
var path_length: float = 0.0
var last_steer_error: float = 0.0 # Stores previous frame's error for the 'D' part of PD steering.
var is_blocked: bool = false # Flag that stops the car if another car is detected ahead.

# --- Path progress ---
const _OFFSETS_META: StringName = &"npc_baked_offsets"

var path_transform: Transform3D = Transform3D.IDENTITY
var inv_path_transform: Transform3D = Transform3D.IDENTITY
var current_offset: float = 0.0
var _baked_points: PackedVector3Array
var _baked_offsets: PackedFloat32Array
var _point_count: int = 0
var _avg_point_spacing: float = 0.5
var _closed: bool = false
var _offset_index: int = 0
var _search_timer: float = 0.0

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
		# The path never moves, so cache its transforms instead of inverting the
		# matrix for every NPC on every physics frame.
		path_transform = path_node.global_transform
		inv_path_transform = path_transform.affine_inverse()
		_closed = curve.closed
		_baked_points = curve.get_baked_points()
		_point_count = _baked_points.size()
		# Curve3D bakes points at *almost* even length, so baked point N is NOT at
		# offset N * bake_interval. Offsets are true cumulative arc length; build
		# that table once per track and share it between all NPCs.
		_baked_offsets = _get_baked_offsets(path_node, _baked_points)
		_avg_point_spacing = path_length / maxf(1.0, float(_point_count - 1))
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
	if not curve or not vehicle or _point_count == 0 or path_length <= 0.0:
		return

	# 1. Track progress. get_closest_offset() walks every baked point (~9,000 of
	# them on track 3), so it only runs at path_search_interval. Between searches
	# the offset is advanced from the car's speed; the next search corrects it.
	_search_timer -= delta
	if _search_timer <= 0.0:
		_search_timer = path_search_interval
		_refresh_offset()
	else:
		current_offset = fposmod(current_offset + vehicle.current_speed * delta, path_length)

	# 2. Calculate Look-Ahead (further ahead = smoother lines at speed)
	var look_ahead = min(max_look_ahead, min_look_ahead + vehicle.current_speed * speed_factor)

	# 3. Calculate Target Point with Lateral Offset
	# Wrap-around logic for looping tracks
	var target_path_offset = fmod(current_offset + look_ahead, path_length) 
	
	# Sample points to calculate the "Right" vector for perpendicular lane offsetting
	var raw_pos = curve.sample_baked(target_path_offset)
	var ahead_pos = curve.sample_baked(fmod(target_path_offset + 0.5, path_length))
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


## Effect: Re-measures where the car sits on the curve. Only a small window of
## baked points around the last known position is scanned; the full curve search
## is used only when the car jumped further than local_search_radius (respawn,
## reset, or a long frame hitch), where the local window would be unreliable.
func _refresh_offset() -> void:
	var local_pos: Vector3 = inv_path_transform * vehicle.global_transform.origin
	var window: int = maxi(1, int(ceil(local_search_radius / maxf(_avg_point_spacing, 0.01))))
	var best_idx: int = _offset_index
	var best_dist: float = INF

	for i in range(_offset_index - window, _offset_index + window + 1):
		var idx: int = i
		if _closed:
			idx = posmod(i, _point_count)
		elif idx < 0 or idx >= _point_count:
			continue
		var p: Vector3 = _baked_points[idx]
		var d: float = (p - local_pos).length_squared()
		if d < best_dist:
			best_dist = d
			best_idx = idx

	if best_dist > local_search_radius * local_search_radius:
		current_offset = curve.get_closest_offset(local_pos)
		_offset_index = _index_for_offset(current_offset)
	else:
		_offset_index = best_idx
		current_offset = _baked_offsets[best_idx]


## Effect: Maps an arc-length offset back to the nearest baked point index.
func _index_for_offset(p_offset: float) -> int:
	return clampi(_baked_offsets.bsearch(p_offset), 0, _point_count - 1)


## Effect: Builds (once per track) the cumulative arc length for each baked
## point, matching Curve3D's internal baked_dist_cache. Stored on the Path3D so
## every NPC on the track shares one copy and it dies with the scene.
static func _get_baked_offsets(p_path: Path3D, p_points: PackedVector3Array) -> PackedFloat32Array:
	if p_path.has_meta(_OFFSETS_META):
		var cached: PackedFloat32Array = p_path.get_meta(_OFFSETS_META)
		return cached

	var offsets := PackedFloat32Array()
	offsets.resize(p_points.size())
	var total: float = 0.0
	for i in range(1, p_points.size()):
		total += p_points[i - 1].distance_to(p_points[i])
		offsets[i] = total

	p_path.set_meta(_OFFSETS_META, offsets)
	return offsets

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
