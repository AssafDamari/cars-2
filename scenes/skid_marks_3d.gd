extends Node3D

@onready var vehicle: VehicleBody3D = get_parent() as VehicleBody3D

@onready var left_trail: TrailRenderer = $Left
@onready var right_trail: TrailRenderer = $Right

# Adjust these values to tune the feel
@export var drift_threshold: float = 3.0  # Minimum sideways speed to trigger marks
@export var min_speed: float = 5.0        # Minimum forward speed to allow drifting

func _physics_process(_delta: float) -> void:
	var drifting = is_drifting()
	left_trail.is_emitting = drifting
	right_trail.is_emitting = drifting

func is_drifting() -> bool:
	# Check if at least one wheel is touching the ground
	var on_ground = false
	for wheel in vehicle.get_children():
		if wheel is VehicleWheel3D and wheel.is_in_contact():
			on_ground = true
			break
			
	if not on_ground:
		return false

	var lateral_velocity = vehicle.linear_velocity.dot(vehicle.global_transform.basis.x)
	return abs(lateral_velocity) > drift_threshold and vehicle.linear_velocity.length() > min_speed
