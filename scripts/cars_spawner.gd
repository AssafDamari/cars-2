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
	# pickup
	1: { 
		"car_scene_path": "res://scenes/car_1.tscn",
		"car_body_scene_path": [
			"res://scenes/car_3_body_model.tscn"
		]
		},
	# drift car
	2: { 
		"car_scene_path":"res://scenes/car_2.tscn" ,
		"car_body_scene_path": [
			"res://scenes/car_2_body_model.tscn",
			"res://scenes/car_muscle_2_body_model.tscn"
		]
		},
	# terrain car
	3: { 
		"car_scene_path":"res://scenes/car_3.tscn" ,
		"car_body_scene_path": [
			"res://scenes/car_3_body_model.tscn"
		]
		},
	# Race car
	4: { 
		"car_scene_path":"res://scenes/car_4.tscn" ,
		"car_body_scene_path": [
			"res://scenes/race_car_body_5.tscn",
			"res://scenes/race_car_body_6.tscn"
		]
		}
}

func spawn_cars(number_of_cars: int, car_type: int, track: Track, engine_force_base: int) -> Array[Car]:
	var spawned_cars: Array[Car] = []
	
	# Pre-load scenes for better performance on mobile
	var car_info: Dictionary = car_types.get(car_type, car_types[1])
	var car_scene: PackedScene = load(car_info["car_scene_path"])
	var car_body_paths: Array = car_info["car_body_scene_path"]
	var body_scenes: Array[PackedScene] = []
	for body_path in car_body_paths:
		body_scenes.append(load(body_path))
	var npc_ctrl_scene: PackedScene = load("res://scenes/npc_car_controller.tscn")
	var player_ctrl_scene: PackedScene = load("res://scenes/player_controller.tscn")
	var skid_marks_scene: PackedScene = load("res://scenes/skid_marks_3d.tscn")
	var offroad_mod_scene: PackedScene = load("res://scenes/offroad_modifier.tscn")
	var camera_scene: PackedScene = load("res://scenes/camera_3d_follow.tscn")
	var modifiers: Array[float] = get_engine_force_modifiers(car_type)
	var engine_force_modifier_min: float = modifiers[0]
	var engine_force_modifier_max: float = modifiers[1]
	
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
			car.color = PlayerSettings.get_car_color(car_type)
			car.add_to_group("PLAYER")
			add_car_body(car, body_scenes[0])
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
			add_car_body(car, body_scenes.pick_random())
			car.apply_color_to_mesh(car.color)
			
			var npc_ctrl = npc_ctrl_scene.instantiate()
			# Setup the NpcCarController
			npc_ctrl.path_node = path
			npc_ctrl.engine_force_fwd = engine_force_base * randf_range(engine_force_modifier_min, engine_force_modifier_max)
			car.add_child(npc_ctrl)
		
		spawned_cars.append(car)
		
	return spawned_cars
	
func add_car_body(car: Car, body_scene: PackedScene) -> void:
	var body_instance = body_scene.instantiate()
	if car.body:
		car.body.add_child(body_instance)
	else:
		car.add_child(body_instance)

# For each car type we have different min and max engine force modifiers
func get_engine_force_modifiers(car_type: int) -> Array[float]:
	match car_type:
		1:
			return [0.9, 1.05]
		2:
			return [0.7, 0.9]
		3:
			return [0.9, 1.05]
		4:
			return [0.9, 1.05]
		_:
			return [0.9, 1.05]
