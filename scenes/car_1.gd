class_name Car
extends VehicleBody3D

@export var color: Color = Color.WHITE
@export var max_speed: float = 20
@export var max_brake_force: float = 40.0

@onready var body_mesh: MeshInstance3D = $Body/MeshInstance3D
@onready var brake_indicator: Node3D = $brake_indicator
@onready var wheel_front_left: VehicleWheel3D = $VehicleWheel3DFrontLeft
@onready var wheel_front_right: VehicleWheel3D = $VehicleWheel3DFrontRight
@onready var wheel_back_right: VehicleWheel3D = $VehicleWheel3DBackRight
@onready var wheel_back_left: VehicleWheel3D = $VehicleWheel3DBackLeft
@onready var track_sensor: RayCast3D = $RayCast3D

# Cache the modifier to avoid flickering performance issues
var _engine_modifier: float = 1.0

func _ready() -> void:
	apply_color_to_mesh(color)

func _physics_process(_delta: float) -> void:
	#_check_track_surface()
	
	# Example of how to apply the force with the penalty
	# Replace 'INPUT_ACCEL_VALUE' with your actual acceleration logic
	engine_force = engine_force * _engine_modifier

func _check_track_surface() -> void:
	# Check if the raycast is hitting anything at all
	if track_sensor.is_colliding():
		var collider = track_sensor.get_collider()
		
		# Check if the object hit is part of the "TRACK" group
		if collider.is_in_group("TRACK"):
			_engine_modifier = 1.0
		else:
			_engine_modifier = 0.7
	else:
		# If the raycast hits nothing (e.g., flying or off-map), apply penalty
		_engine_modifier = 0.7

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
