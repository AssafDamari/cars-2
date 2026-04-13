extends Control


func _on_cargo_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/cargo_loading_main.tscn")


func _on_drift_button_pressed() -> void:
		get_tree().change_scene_to_file("res://scenes/drift_race_main.tscn")
