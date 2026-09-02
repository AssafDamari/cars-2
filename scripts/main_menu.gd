extends Control


func _on_cargo_button_pressed() -> void:
	GlobalSceneManager.load_cargo_loading({})


func _on_drift_button_pressed() -> void:
	GlobalSceneManager.load_race({
		"track_number": 1,
		"number_of_cars": 10,
		"car_type": 2,
		"engine_force_base": 5500,
		"number_of_laps" : 2
	})


func _on_drift_button_2_pressed() -> void:
	GlobalSceneManager.load_race({
		"track_number": 2,
		"number_of_cars": 10,
		"car_type": 3,
		"engine_force_base": 1800,
		"number_of_laps" : 2
	})


func _on_race_button_pressed() -> void:
	GlobalSceneManager.load_race({
		"track_number": 3,
		"number_of_cars": 15,
		"car_type": 4,
		"engine_force_base": 3800,
		"number_of_laps" : 2
	})
