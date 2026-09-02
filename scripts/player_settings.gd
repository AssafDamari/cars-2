
extends Node

const SAVE_PATH := "user://player_settings.cfg"

var DEFAULT_CAR_COLOR := Color.from_rgba8(249, 0, 0)  # Default color if not set

# Settings are stored per car type so future stats (body model, etc.) can be
# added per type without changing the structure. Keyed by car_type as int.
var _car_settings: Dictionary = {}

func _ready() -> void:
	load_settings()

func get_car_color(car_type: int) -> Color:
	var settings: Dictionary = _car_settings.get(car_type, {})
	return settings.get("color", DEFAULT_CAR_COLOR)

func set_car_color(car_type: int, color: Color) -> void:
	var settings: Dictionary = _car_settings.get(car_type, {})
	settings["color"] = color
	_car_settings[car_type] = settings

func save_settings() -> void:
	var config := ConfigFile.new()
	for car_type: int in _car_settings:
		var settings: Dictionary = _car_settings[car_type]
		for key: String in settings:
			config.set_value(str(car_type), key, settings[key])
	config.save(SAVE_PATH)

func load_settings() -> void:
	_car_settings.clear()
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for section in config.get_sections():
		var car_type: int = section.to_int()
		var settings: Dictionary = {}
		for key in config.get_section_keys(section):
			settings[key] = config.get_value(section, key)
		_car_settings[car_type] = settings

func reset_to_defaults() -> void:
	_car_settings.clear()
	save_settings()
