extends Node3D
## Only 10% power when off-track
@export var off_road_penalty: float = 0.1
@onready var vehicle: Car = get_parent() as Car
@onready var dust: GPUParticles3D = $DustParticles
@onready var track_sensor: RayCast3D = $TrackSensor


func _physics_process(delta: float) -> void:
	_handle_off_road_logic(delta)
	

func _handle_off_road_logic(_delta: float) -> void:
	var target_mod = 1.0 # Default to full speed
	
	if track_sensor.is_colliding():
		var collider = track_sensor.get_collider()
		# If the raycast hits something NOT in the TRACK group
		if not collider.is_in_group("TRACK") and not collider.is_in_group("CAR"):
			target_mod = off_road_penalty

	vehicle.engine_force_modifier = target_mod
	
	if target_mod != 1.0:
		show_dast()
	else:
		hide_dast()
		
func show_dast():
	if not dust.emitting:
		dust.emitting = true
	
func hide_dast():
	if dust.emitting:
		dust.emitting = false
