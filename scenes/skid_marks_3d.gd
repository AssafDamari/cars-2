extends Node3D

@onready var vehicle: VehicleBody3D = get_parent() as VehicleBody3D
@onready var left_trail: TrailRenderer = $Left
@onready var right_trail: TrailRenderer = $Right

# Optimization: Pre-calculate the squared speed to avoid square root calculations
@export var drift_threshold: float = 3.0
@export var min_speed: float = 5.0
@onready var min_speed_sq: float = min_speed * min_speed

# Optimization: Cache wheel references so we don't call get_children() every frame
var wheels: Array[VehicleWheel3D] = []

func _ready() -> void:
	for child in vehicle.get_children():
		if child is VehicleWheel3D:
			wheels.append(child)

func _physics_process(_delta: float) -> void:
	# Only update if the vehicle is actually moving to save cycles
	var should_emit: bool = is_drifting()
	
	# Only set property if it actually changed (prevents unnecessary state sets)
	if left_trail.is_emitting != should_emit:
		left_trail.is_emitting = should_emit
		right_trail.is_emitting = should_emit

func is_drifting() -> bool:
	var vel = vehicle.linear_velocity
	
	# 1. Use length_squared() - much faster than length() because it skips the sqrt()
	if vel.length_squared() < min_speed_sq:
		return false
	
	# 2. Check ground contact using our cached array (direct access is fast)
	var on_ground = false
	for wheel in wheels:
		if wheel.is_in_contact():
			on_ground = true
			break
	
	if not on_ground:
		return false
	
	# 3. Lateral velocity check
	# Optimization: Localize the basis to avoid repeated deep property access
	var lateral_velocity = vel.dot(vehicle.global_transform.basis.x)
	
	return abs(lateral_velocity) > drift_threshold
