extends Control


func _on_cargo_button_pressed() -> void:
	GlobalSceneManager.load_cargo_loading({})


func _on_drift_button_pressed() -> void:
	GlobalSceneManager.load_drift_race({
		"number_of_cars": 10,
		"car_type": 2
	})
