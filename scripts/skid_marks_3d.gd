extends Node3D

@export var drift_threshold: float = 5.5
@export var min_speed: float = 4.0
@export var lifetime: float = 1.5
@export var trail_width: float = 0.32
@export var min_vertex_distance: float = 0.2
@export var max_render_distance: float = 50.0

@onready var vehicle: VehicleBody3D = get_parent() as VehicleBody3D
@onready var left_marker: Node3D = $Left
@onready var right_marker: Node3D = $Right
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

const MAX_POINTS: int = 64

# Ring buffer for Left wheel
var left_points: PackedVector3Array
var left_times: PackedFloat32Array
var left_segment_ids: PackedInt32Array
var left_head: int = 0
var left_count: int = 0
var left_last_pos: Vector3 = Vector3.ZERO

# Ring buffer for Right wheel
var right_points: PackedVector3Array
var right_times: PackedFloat32Array
var right_segment_ids: PackedInt32Array
var right_head: int = 0
var right_count: int = 0
var right_last_pos: Vector3 = Vector3.ZERO

var current_segment_id: int = 0
var was_drifting: bool = false
var wheels: Array[VehicleWheel3D] = []
var active_camera: Camera3D = null
var array_mesh: ArrayMesh

var min_speed_sq: float
var min_dist_sq: float
var max_distance_sq: float

# Mesh rebuild throttle: rebuild only when geometry changed, capped to a max rate
const _MIN_REBUILD_INTERVAL: float = 0.05
const _MAX_REBUILD_INTERVAL: float = 0.1
var _rebuild_dirty: bool = true
var _last_rebuild_time: float = 0.0

# Pre-allocated arrays for mesh generation
var varray: PackedVector3Array
var carray: PackedColorArray
var uarray: PackedVector2Array
var iarray: PackedInt32Array

func _ready() -> void:
	min_speed_sq = min_speed * min_speed
	min_dist_sq = min_vertex_distance * min_vertex_distance
	max_distance_sq = max_render_distance * max_render_distance
	
	if vehicle:
		for child in vehicle.get_children():
			if child is VehicleWheel3D:
				wheels.append(child)
				
	active_camera = get_viewport().get_camera_3d()
	
	left_points.resize(MAX_POINTS)
	left_times.resize(MAX_POINTS)
	left_segment_ids.resize(MAX_POINTS)
	
	right_points.resize(MAX_POINTS)
	right_times.resize(MAX_POINTS)
	right_segment_ids.resize(MAX_POINTS)
	
	array_mesh = ArrayMesh.new()
	mesh_instance.mesh = array_mesh
	mesh_instance.top_level = true
	mesh_instance.global_transform = Transform3D.IDENTITY

func _process(_delta: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	
	if not active_camera:
		active_camera = get_viewport().get_camera_3d()
	
	var in_range: bool = true
	if active_camera:
		var dist_sq = global_transform.origin.distance_squared_to(active_camera.global_transform.origin)
		if dist_sq > max_distance_sq:
			in_range = false
	
	var is_drifting_now: bool = in_range and is_drifting()
	
	if is_drifting_now and not was_drifting:
		current_segment_id += 1
	was_drifting = is_drifting_now
	
	if is_drifting_now:
		_add_point_left(left_marker.global_position, now)
		_add_point_right(right_marker.global_position, now)
	
	_expire_points(now)
	
	if left_count > 1 or right_count > 1:
		var time_since_rebuild: float = now - _last_rebuild_time
		if _rebuild_dirty and time_since_rebuild >= _MIN_REBUILD_INTERVAL \
				or time_since_rebuild >= _MAX_REBUILD_INTERVAL:
			_update_mesh(now)
			_rebuild_dirty = false
			_last_rebuild_time = now
	elif array_mesh.get_surface_count() > 0:
		array_mesh.clear_surfaces()

func is_drifting() -> bool:
	if not vehicle:
		return false
	var vel: Vector3 = vehicle.linear_velocity
	if vel.length_squared() < min_speed_sq:
		return false
	
	var on_ground: bool = false
	for wheel in wheels:
		if wheel.is_in_contact():
			on_ground = true
			break
	if not on_ground:
		return false
	
	var lateral_velocity: float = vel.dot(vehicle.global_transform.basis.x)
	
	return abs(lateral_velocity) > drift_threshold

func _add_point_left(pos: Vector3, now: float) -> void:
	if left_count > 0 and pos.distance_squared_to(left_last_pos) < min_dist_sq:
		return
	var idx: int = (left_head + left_count) % MAX_POINTS
	left_points[idx] = pos
	left_times[idx] = now
	left_segment_ids[idx] = current_segment_id
	left_last_pos = pos
	if left_count < MAX_POINTS:
		left_count += 1
	else:
		left_head = (left_head + 1) % MAX_POINTS
	_rebuild_dirty = true

func _add_point_right(pos: Vector3, now: float) -> void:
	if right_count > 0 and pos.distance_squared_to(right_last_pos) < min_dist_sq:
		return
	var idx: int = (right_head + right_count) % MAX_POINTS
	right_points[idx] = pos
	right_times[idx] = now
	right_segment_ids[idx] = current_segment_id
	right_last_pos = pos
	if right_count < MAX_POINTS:
		right_count += 1
	else:
		right_head = (right_head + 1) % MAX_POINTS
	_rebuild_dirty = true

func _expire_points(now: float) -> void:
	var expired: bool = false
	while left_count > 0 and (now - left_times[left_head]) > lifetime:
		left_head = (left_head + 1) % MAX_POINTS
		left_count -= 1
		expired = true
		
	while right_count > 0 and (now - right_times[right_head]) > lifetime:
		right_head = (right_head + 1) % MAX_POINTS
		right_count -= 1
		expired = true
	if expired:
		_rebuild_dirty = true

func _update_mesh(now: float) -> void:
	var half_width: float = trail_width * 0.5
	var y_offset: Vector3 = Vector3(0.0, 0.02, 0.0)
	
	varray.clear()
	carray.clear()
	uarray.clear()
	iarray.clear()
	
	if left_count > 1:
		_build_wheel_trail(left_points, left_times, left_segment_ids, left_head, left_count, now, half_width, y_offset)
		
	if right_count > 1:
		_build_wheel_trail(right_points, right_times, right_segment_ids, right_head, right_count, now, half_width, y_offset)
	
	array_mesh.clear_surfaces()
	if varray.size() >= 4 and iarray.size() >= 6:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = varray
		arrays[Mesh.ARRAY_COLOR] = carray
		arrays[Mesh.ARRAY_TEX_UV] = uarray
		arrays[Mesh.ARRAY_INDEX] = iarray
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func _build_wheel_trail(
	pts: PackedVector3Array,
	tms: PackedFloat32Array,
	segs: PackedInt32Array,
	head: int,
	cnt: int,
	now: float,
	half_width: float,
	y_offset: Vector3
) -> void:
	var base_idx: int = varray.size()
	var vert_count: int = 0
	
	for i in range(cnt):
		var idx: int = (head + i) % MAX_POINTS
		var p: Vector3 = pts[idx]
		var seg: int = segs[idx]
		var age: float = now - tms[idx]
		var alpha: float = clampf(1.0 - (age / lifetime), 0.0, 1.0)
		var color: Color = Color(1.0, 1.0, 1.0, alpha)
		
		var tangent: Vector3 = Vector3.ZERO
		if i < cnt - 1 and segs[(head + i + 1) % MAX_POINTS] == seg:
			tangent = (pts[(head + i + 1) % MAX_POINTS] - p).normalized()
		elif i > 0 and segs[(head + i - 1) % MAX_POINTS] == seg:
			tangent = (p - pts[(head + i - 1) % MAX_POINTS]).normalized()
		
		var bitangent: Vector3 = tangent.cross(Vector3.UP).normalized() * half_width
		if bitangent.length_squared() < 0.0001:
			bitangent = Vector3.RIGHT * half_width
		
		varray.append(p - bitangent + y_offset)
		varray.append(p + bitangent + y_offset)
		carray.append(color)
		carray.append(color)
		uarray.append(Vector2(0.0, float(i) / float(cnt)))
		uarray.append(Vector2(1.0, float(i) / float(cnt)))
		
		if i > 0 and segs[(head + i - 1) % MAX_POINTS] == seg:
			var prev_l: int = base_idx + (vert_count - 2)
			var prev_r: int = base_idx + (vert_count - 1)
			var cur_l: int = base_idx + vert_count
			var cur_r: int = base_idx + vert_count + 1
			
			iarray.append(prev_l)
			iarray.append(prev_r)
			iarray.append(cur_l)
			
			iarray.append(prev_r)
			iarray.append(cur_r)
			iarray.append(cur_l)
			
		vert_count += 2
