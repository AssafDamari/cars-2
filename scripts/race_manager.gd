class_name RaceManager
extends Node3D

@onready var minimap: Minimap = $Minimap
@onready var track_spawner: TrackSpawner = $TrackSpawner
@onready var cars_spawner: CarsSpawner = $CarsSpawner
var path_3d: Path3D


func _ready() -> void:
	setup_track()
	setup_cars()


func setup_track() -> void:
	var track_number = GlobalSceneManager.scene_parameters.get("track_number", 1)
	var track: Track = track_spawner.load_track(track_number)
	path_3d = track.get_path_3d()
	GlobalSignals.track_setup_done.emit()
	
	
func setup_cars() -> void:
	var num_cars = GlobalSceneManager.scene_parameters.get("number_of_cars", 10)
	var car_type = GlobalSceneManager.scene_parameters.get("car_type", 2)
	var _cars = cars_spawner.spawn_cars(num_cars, car_type, path_3d)
	GlobalSignals.cars_setup_done.emit()
