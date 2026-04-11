extends Node3D

@export var max_points: int = 1000 
@export var mark_width: float = 0.25
@export var min_speed: float = 5.0
@export var slip_threshold: float = 2.0
@export var fade_speed: float = 0.5 # Higher = fades faster

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var left_wheel: Marker3D = $LeftWheel
@onready var right_wheel: Marker3D = $RightWheel

var mesh: ImmediateMesh = ImmediateMesh.new()
var skid_material: Material 

# Data for the strips
var points_left: Array[Vector3] = []
var points_right: Array[Vector3] = []
var directions: Array[Vector3] = []
var alphas: Array[float] = [] # Track the transparency of each segment

func _ready() -> void:
	mesh_instance.top_level = true
	mesh_instance.global_position = Vector3.ZERO
	mesh_instance.global_rotation = Vector3.ZERO
	mesh_instance.mesh = mesh
	skid_material = mesh_instance.material_override

func _physics_process(delta: float) -> void:
	var car := get_parent() as VehicleBody3D
	if car == null: return

	# 1. Update existing points (Fade them out)
	var i = 0
	while i < alphas.size():
		alphas[i] -= fade_speed * delta
		if alphas[i] <= 0:
			# Remove old points that are completely invisible
			alphas.remove_at(i)
			points_left.remove_at(i)
			points_right.remove_at(i)
			directions.remove_at(i)
		else:
			i += 1

	# 2. Check for new drift points
	var velocity: Vector3 = car.linear_velocity
	var speed: float = velocity.length()
	var local_vel: Vector3 = car.global_transform.basis.inverse() * velocity
	var slip: float = abs(local_vel.x)

	if speed > min_speed and slip > slip_threshold:
		_add_marks(car.global_transform.basis.x)

	_update_mesh()

func _add_marks(car_right: Vector3) -> void:
	var lp: Vector3 = left_wheel.global_transform.origin
	var rp: Vector3 = right_wheel.global_transform.origin

	lp.y += 0.02
	rp.y += 0.02

	points_left.append(lp)
	points_right.append(rp)
	directions.append(car_right)
	alphas.append(1.0) # Start fully visible

	if points_left.size() > max_points:
		points_left.pop_front()
		points_right.pop_front()
		directions.pop_front()
		alphas.pop_front()

func _update_mesh() -> void:
	mesh.clear_surfaces()
	if points_left.size() < 2: return

	# Draw Left Tire
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, skid_material)
	for i in range(points_left.size()):
		var p = points_left[i]
		var side = directions[i] * (mark_width / 2.0)
		var color = Color(1, 1, 1, alphas[i]) # White color, but with our fade alpha
		
		mesh.surface_set_color(color) # Set color BEFORE adding the vertex
		mesh.surface_add_vertex(p + side)
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(p - side)
	mesh.surface_end()

	# Draw Right Tire
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, skid_material)
	for i in range(points_right.size()):
		var p = points_right[i]
		var side = directions[i] * (mark_width / 2.0)
		var color = Color(1, 1, 1, alphas[i])
		
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(p + side)
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(p - side)
	mesh.surface_end()
