extends VehicleBody3D

@export var path_follow: PathFollow3D 
@export var target_speed: float = 10.0
@export var braking_force: float = 20.0
@export var steering_sensitivity: float = 0.8
@export var min_follow_distance: float = 5.0 # Don't get closer than this

@onready var sensor: RayCast3D = $Sensor

func _physics_process(delta: float) -> void:
	if not path_follow:
		return

	# 1. Update the ghost target position
	path_follow.progress += target_speed * delta

	# 2. Calculate distance and local position
	var target_pos = path_follow.global_position
	var dist_to_target = global_position.distance_to(target_pos)
	var local_target = to_local(target_pos)
	
	# 3. Handle Obstacle Detection
	if sensor.is_colliding():
		apply_braking()
	else:
		# Pass the distance to the driving function
		apply_driving(local_target, dist_to_target)

func apply_driving(local_target: Vector3, distance: float) -> void:
	brake = 0.0
	
	# Steering logic (remains the same)
	var steer_angle = atan2(local_target.x, local_target.z)
	steering = lerp(steering, steer_angle * steering_sensitivity, 0.1)
	
	# 4. Speed Scaling Logic
	# If we are closer than 10 meters, we start reducing the engine force
	var speed_scaler = clamp(distance / 10.0, 0.0, 1.0)
	
	# If we're dangerously close (below min_follow_distance), 
	# we cut the engine entirely or even light-brake
	if distance < min_follow_distance:
		engine_force = 0.0
		brake = 2.0 # Light drag to prevent overtaking
	else:
		engine_force = (target_speed * 5.0) * speed_scaler

func apply_braking() -> void:
	engine_force = 0.0
	brake = braking_force
