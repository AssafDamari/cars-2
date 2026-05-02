extends Node3D

@onready var vehicle: VehicleBody3D = get_parent() as VehicleBody3D
@onready var left_trail: TrailRenderer = $Left
@onready var right_trail: TrailRenderer = $Right

# Reference to the visibility notifier we added in the scene
@onready var visibility_notifier: VisibleOnScreenNotifier3D = $VisibleOnScreenNotifier3D

@export var drift_threshold: float = 3.0
@export var min_speed: float = 5.0
@onready var min_speed_sq: float = min_speed * min_speed

# Distance optimization
@export var max_render_distance: float = 40.0
@onready var max_distance_sq: float = max_render_distance * max_render_distance

var wheels: Array[VehicleWheel3D] = []
var active_camera: Camera3D = null
var frame_count: int = 0

func _ready() -> void:
	for child in vehicle.get_children():
		if child is VehicleWheel3D:
			wheels.append(child)
			
	# Cache the main camera. 
	# (If you switch cameras mid-game, you will need to update this reference)
	active_camera = get_viewport().get_camera_3d()

func _physics_process(_delta: float) -> void:
	# Optimization 1: Skip entirely if not on screen (Frustum Culling)
	if not visibility_notifier.is_on_screen():
		disable_trails()
		return
		
	# Optimization 2: Spread calculations across frames for multiple cars
	# Car A updates on frame 1, Car B on frame 2, etc.
	frame_count += 1
	if frame_count % 3 != 0: 
		return

	# Optimization 3: Distance Check
	if active_camera:
		# Use squared distance to avoid expensive square root calculations
		var dist_sq = global_transform.origin.distance_squared_to(active_camera.global_transform.origin)
		if dist_sq > max_distance_sq:
			disable_trails()
			return

	# If it passes visibility and distance, run the drift logic
	var should_emit: bool = is_drifting()
	
	if left_trail.is_emitting != should_emit:
		left_trail.is_emitting = should_emit
		right_trail.is_emitting = should_emit

func is_drifting() -> bool:
	var vel = vehicle.linear_velocity
	
	if vel.length_squared() < min_speed_sq:
		return false
	
	var on_ground = false
	for wheel in wheels:
		if wheel.is_in_contact():
			on_ground = true
			break
	
	if not on_ground:
		return false
	
	var lateral_velocity = vel.dot(vehicle.global_transform.basis.x)
	return abs(lateral_velocity) > drift_threshold

func disable_trails() -> void:
	if left_trail.is_emitting:
		left_trail.is_emitting = false
		right_trail.is_emitting = false
