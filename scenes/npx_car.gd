extends VehicleBody3D

@export var color: Color = Color.WHITE

@onready var body_mesh: MeshInstance3D = $Body/MeshInstance3D
@onready var brake_lights: Node3D = $BrakeLights


func _ready() -> void:
	apply_color_to_mesh(color)


func apply_color_to_mesh(_color: Color) -> void:
	var material := body_mesh.get_active_material(0).duplicate(true)
	material.albedo_color = _color
	body_mesh.set_surface_override_material(0, material)

func show_brakes_lights():
	brake_lights.visible = true

func hide_brakes_lights():
	brake_lights.visible = false
