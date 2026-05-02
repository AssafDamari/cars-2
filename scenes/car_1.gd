class_name Car
extends VehicleBody3D

@export var color: Color = Color.WHITE
@export var max_speed: float = 40
@export var max_brake_force: float = 20.0

@onready var body: Node3D = $Body
@onready var brake_indicator: Node3D = $brake_indicator
@onready var wheel_front_left: VehicleWheel3D = $VehicleWheel3DFrontLeft
@onready var wheel_front_right: VehicleWheel3D = $VehicleWheel3DFrontRight
@onready var wheel_back_right: VehicleWheel3D = $VehicleWheel3DBackRight
@onready var wheel_back_left: VehicleWheel3D = $VehicleWheel3DBackLeft
var engine_force_to_apply: float = 0

# Internal state
var engine_force_modifier: float = 1.0

func _ready() -> void:
	apply_color_to_mesh(color)


func _physics_process(_delta: float) -> void:
	var speed_sq = linear_velocity.length_squared()
	if speed_sq < max_speed * max_speed:
		engine_force = engine_force_to_apply * engine_force_modifier
	else:
		engine_force = 0.0
	

func apply_color_to_mesh(_color: Color) -> void:
	var body_mesh := get_first_mesh_instance(body)
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


func get_first_mesh_instance(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		var result = get_first_mesh_instance(child)
		if result:
			return result
	return null
	
