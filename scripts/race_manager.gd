class_name RaceManager
extends Node3D

@onready var minimap: Minimap = $Minimap
@onready var track_spawner: TrackSpawner = $TrackSpawner
@onready var cars_spawner: CarsSpawner = $CarsSpawner
var track: Track
var start_position: Marker3D

func _ready() -> void:
	setup_track()
	setup_cars()


func setup_track() -> void:
	var track_number = GlobalSceneManager.scene_parameters.get("track_number", 1)
	track = track_spawner.spawn_track(track_number)
	GlobalSignals.track_setup_done.emit()
	
	
func setup_cars() -> void:
	var num_cars = GlobalSceneManager.scene_parameters.get("number_of_cars", 10)
	var car_type = GlobalSceneManager.scene_parameters.get("car_type", 2)
	var engine_force_base = GlobalSceneManager.scene_parameters.get("engine_force_base", 2)
	var _cars = cars_spawner.spawn_cars(num_cars, car_type, track, engine_force_base)
	GlobalSignals.cars_setup_done.emit()
