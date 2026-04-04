class_name Car
extends VehicleBody3D

@export var color: Color = Color.WHITE
@export var max_speed: float = 15
@export var max_brake_force: float = 20.0
@export var max_steering_angle: float = 0.4 
@export var steering_speed: float = 0.3

@onready var body_mesh: MeshInstance3D = $Body/MeshInstance3D


func _ready() -> void:
	apply_color_to_mesh(color)


func apply_color_to_mesh(_color: Color) -> void:
	var material := body_mesh.get_active_material(0).duplicate(true)
	material.albedo_color = _color
	body_mesh.set_surface_override_material(0, material)
