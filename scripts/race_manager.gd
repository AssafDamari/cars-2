class_name RaceManager
extends Node3D

@onready var cars_spawner: CarsSpawner = $CarsSpawner
@onready var path_3d: Path3D = $Track/Path3D


func _ready() -> void:
	setup_cars()


func setup_cars() -> void:
	var num_cars = GlobalSceneManager.scene_parameters.get("number_of_cars", 10)
	var car_type = GlobalSceneManager.scene_parameters.get("car_type", 2)
	var _cars = cars_spawner.spawn_cars(num_cars, car_type, path_3d)
	GlobalSignals.cars_setup_done.emit()
