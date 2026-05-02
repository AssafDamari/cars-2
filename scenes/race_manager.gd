class_name RaceManager
extends Node3D

@onready var cars_spawner: CarsSpawner = $CarsSpawner
@onready var path_3d: Path3D = $Track/Path3D

func _ready() -> void:
	var _cars = cars_spawner.spawn_cars(10, 2, path_3d)
