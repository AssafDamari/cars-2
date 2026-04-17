class_name Car
extends VehicleBody3D

@export var color: Color = Color.WHITE
@export var max_speed: float = 20
@export var max_brake_force: float = 40.0
@export var off_road_penalty: float = 0.1 # Only 10% power when off-track

@onready var body_mesh: MeshInstance3D = $Body/MeshInstance3D
@onready var brake_indicator: Node3D = $brake_indicator
@onready var wheel_front_left: VehicleWheel3D = $VehicleWheel3DFrontLeft
@onready var wheel_front_right: VehicleWheel3D = $VehicleWheel3DFrontRight
@onready var wheel_back_right: VehicleWheel3D = $VehicleWheel3DBackRight
@onready var wheel_back_left: VehicleWheel3D = $VehicleWheel3DBackLeft
@onready var dust: GPUParticles3D = $DustParticles
@onready var track_sensor: RayCast3D = $TrackSensor

# Internal state
var _current_modifier: float = 1.0

func _ready() -> void:
	apply_color_to_mesh(color)

func _physics_process(delta: float) -> void:
		# 1. Surface Detection & Penalty
	_handle_off_road_logic(delta)

	# Example of how to apply the force with the penalty
	# Replace 'INPUT_ACCEL_VALUE' with your actual acceleration logic
	engine_force = engine_force * _current_modifier

func _handle_off_road_logic(_delta: float) -> void:
	var target_mod = 1.0 # Default to full speed
	
	if track_sensor.is_colliding():
		var collider = track_sensor.get_collider()
		# If the raycast hits something NOT in the TRACK group
		if not collider.is_in_group("TRACK") and not collider.is_in_group("CAR"):
			target_mod = off_road_penalty
	
	# Smoothly interpolate the modifier so the car doesn't jerk
	_current_modifier = target_mod
	if _current_modifier != 1.0:
		show_dast()
	else:
		hide_dast()
		
func apply_color_to_mesh(_color: Color) -> void:
	var material := body_mesh.get_active_material(0).duplicate(true)
	material.albedo_color = _color
	body_mesh.set_surface_override_material(0, material)
	for child_mesh in body_mesh.get_children():
		if child_mesh is MeshInstance3D:
			child_mesh.set_surface_override_material(0, material)

func brake_car():
	engine_force = 0
	brake = max_brake_force

func show_brake_indicator():
	if not brake_indicator.visible:
		brake_indicator.visible = true
	
func hide_brake_indicator():
	if brake_indicator.visible:
		brake_indicator.visible = false

func show_dast():
	if not dust.emitting:
		dust.emitting = true
	
func hide_dast():
	if dust.emitting:
		dust.emitting = false
	
	
