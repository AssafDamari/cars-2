class_name Minimap
extends Control

@export var update_interval: float = 0.5 # 500ms update rate

var path_3d: Path3D
var track_line: Line2D
var indicators_container: Node2D

var min_bound: Vector2
var max_bound: Vector2
var timer: float = 0.0

# Dictionary to map Car nodes to their Dot nodes { car_ref: color_rect_ref }
var car_dots = {}


func _ready():
	GlobalSignals.track_setup_done.connect(setup_track)
	GlobalSignals.cars_setup_done.connect(setup_car_indicators)


func _exit_tree():
	GlobalSignals.track_setup_done.disconnect(setup_track)
	GlobalSignals.cars_setup_done.disconnect(setup_car_indicators)


func _process(delta):
	timer += delta
	if timer >= update_interval:
		update_positions()
		timer = 0.0
		
	
func setup_track():
	var track: Track = get_tree().get_nodes_in_group("TRACK")[0]
	path_3d = track.get_path_3d()
	track_line = $TrackLine
	indicators_container = $Indicators
	bake_track_to_2d()


func setup_car_indicators():
	# Find all cars in a specific group
	var cars = get_tree().get_nodes_in_group("CAR")
	for car in cars:
		var dot = ColorRect.new()
		dot.color = car.color
		dot.size = Vector2(15, 15)
		# Distinguish player from AI
		if car.is_in_group("PLAYER"):
			dot.size = 1.5 * dot.size
			
		dot.pivot_offset = dot.size / 2
		indicators_container.add_child(dot)
		car_dots[car] = dot
		
		
func bake_track_to_2d():
	var curve = path_3d.curve
	var points_3d = curve.get_baked_points()
	var points_2d = PackedVector2Array()
	
	# Find world bounds to scale the map correctly
	min_bound = Vector2(INF, INF)
	max_bound = Vector2(-INF, -INF)
	
	for p in points_3d:
		var p2 = Vector2(p.x, p.z)
		points_2d.append(p2)
		if p2.x < min_bound.x: min_bound.x = p2.x
		if p2.y < min_bound.y: min_bound.y = p2.y
		if p2.x > max_bound.x: max_bound.x = p2.x
		if p2.y > max_bound.y: max_bound.y = p2.y
	
	# Transform points to fit inside the UI Rect
	var final_points = PackedVector2Array()
	var ui_size = size # The size of this Control node
	
	for p in points_2d:
		var normalized = (p - min_bound) / (max_bound - min_bound)
		final_points.append(normalized * ui_size)
		
	track_line.points = final_points


func update_positions():
	var ui_size = size
	for car in car_dots.keys():
		var dot = car_dots[car]
		var pos_3d = car.global_position
		var pos_2d = Vector2(pos_3d.x, pos_3d.z)
		
		# Normalize based on the baked track bounds
		var normalized = (pos_2d - min_bound) / (max_bound - min_bound)
		dot.position = (normalized * ui_size) - (dot.size / 2)
