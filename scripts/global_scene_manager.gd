extends Node

# parameters used by different scenes globally
var scene_parameters: Dictionary = {}

func load_race(params: Dictionary):
	scene_parameters = params
	get_tree().change_scene_to_file("res://scenes/race.tscn")

func load_cargo_loading(params: Dictionary):
	scene_parameters = params
	get_tree().change_scene_to_file("res://scenes/cargo_loading_main.tscn")
	
func load_menu():
	scene_parameters = {}
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
