class_name CarsSpawner
extends Node3D

var distance_between_cars: float = 10.0

var colors: Array[Color] = [
		Color.from_rgba8(141, 6, 6),
		Color.from_rgba8(255, 126, 0),
		Color.from_rgba8(255, 216, 62),
		Color.from_rgba8(0, 73, 70),
		Color.from_rgba8(0, 255, 120),
		Color.from_rgba8(0, 79, 154),
		Color.from_rgba8(0, 132, 255),
		Color.from_rgba8(255, 0, 204),
	]
	
var car_types = {
	1: "res://scenes/car_1.tscn",
	2: "res://scenes/car_2.tscn",
	3: "res://scenes/car_3.tscn",
	4: "res://scenes/car_4.tscn"
}

func spawn_cars(number_of_cars: int, car_type: int, track: Track, engine_force_base: int) -> Array[Car]:
	var spawned_cars: Array[Car] = []
	
	# Pre-load scenes for better performance on mobile
	var car_scene_path = car_types.get(car_type, car_types[1])
	var car_scene: PackedScene = load(car_scene_path)
	var npc_ctrl_scene: PackedScene = load("res://scenes/npc_car_controller.tscn")
	var player_ctrl_scene: PackedScene = load("res://scenes/player_controller.tscn")
	var skid_marks_scene: PackedScene = load("res://scenes/skid_marks_3d.tscn")
	var offroad_mod_scene: PackedScene = load("res://scenes/offroad_modifier.tscn")
	var camera_scene: PackedScene = load("res://scenes/camera_3d_follow.tscn")
	
	for i in range(number_of_cars):
		# Instance the car according to car_type
		var car: Car = car_scene.instantiate()
		
		# Add car to the scene tree first so global_position works
		add_child(car)
		var start_pos: Marker3D = track.get_start_position()
		var path = track.get_path_3d()
		# Find the closest offset on the path to the start_pos marker
		var start_local_pos = path.global_transform.affine_inverse() * start_pos.global_position
		var start_offset = path.curve.get_closest_offset(start_local_pos)
		# Position car on the path using distance_between_cars from start_pos
		var offset = start_offset + (i + 1) * distance_between_cars
		var local_pos = path.curve.sample_baked(offset)
		car.global_position = path.global_transform * local_pos
		
		# Orient car towards the next point on path for a natural start
		var next_pos = path.curve.sample_baked(offset + 1.0)
		var global_next_pos = path.global_transform * next_pos
		if car.global_position.distance_to(global_next_pos) > 0.1:
			car.look_at_from_position(car.global_position, global_next_pos, Vector3.UP)
		
		# Add components as child nodes
		car.add_child(skid_marks_scene.instantiate())
		car.add_child(offroad_mod_scene.instantiate())
		
		# The first car is the Player car, others are NPC cars
		if i == 0:
			car.name = "PlayerCar"
			car.color = Color.from_rgba8(249, 0, 0)
			car.add_to_group("PLAYER")
			car.apply_color_to_mesh(car.color)
			
			var player_ctrl = player_ctrl_scene.instantiate()
			player_ctrl.engine_force_fwd = engine_force_base
			car.add_child(player_ctrl)
			
			var camera_gimble = camera_scene.instantiate()
			car.add_child(camera_gimble)
		else:
			car.name = "NpcCar" + str(i)
			# Set color from colors array cyclically for NPCs
			car.color = colors[(i - 1) % colors.size()]
			car.apply_color_to_mesh(car.color)
			
			var npc_ctrl = npc_ctrl_scene.instantiate()
			# Setup the NpcCarController
			npc_ctrl.path_node = path
			npc_ctrl.engine_force_fwd = engine_force_base * randf_range(0.875, 1.05)
			car.add_child(npc_ctrl)
		
		spawned_cars.append(car)
		
	return spawned_cars
