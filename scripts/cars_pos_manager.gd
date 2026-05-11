class_name CarsPosManager
extends Node3D

## Tracks each car's race progress: laps, position, and finish time.
## Expects to be fed cars via load_cars() and lap crossings via car_crossed_finish().

var number_of_laps: int = 1
var race_start_time: float = 0.0

# Key = Car node, Value = { "current_lap": int, "finished": bool, "finish_time": float, "position": int }
var car_data: Dictionary = {}

# Ordered list of cars that have finished (first element = 1st place, etc.)
var finished_cars: Array[Car] = []

# All cars in the race
var cars: Array[Car] = []

# Track path reference for distance-based sorting
var track_path: Path3D

var ResultsPanel = preload("res://scripts/race_results_panel.gd")
var results_panel: Node = null

signal car_finished(car: Car, position: int, finish_time: float)
signal player_finished(position: int, finish_time: float, results: Array)
signal race_complete()


func load_cars(race_cars: Array[Car]) -> void:
	cars = race_cars
	car_data.clear()
	finished_cars.clear()
	for car in cars:
		car_data[car] = {
			"current_lap": 0,
			"finished": false,
			"finish_time": 0.0,
			"position": 0,
		}
	race_start_time = Time.get_ticks_msec() / 1000.0


func set_track_path(path: Path3D) -> void:
	track_path = path


func set_number_of_laps(laps: int) -> void:
	number_of_laps = laps


## Called by RaceManager when a car's body enters the finish Area3D.
func car_crossed_finish(car: Car) -> void:
	if not car_data.has(car):
		return

	var data: Dictionary = car_data[car]

	# Already finished the race — ignore further crossings
	if data["finished"]:
		return

	# Increment lap
	data["current_lap"] += 1

	# Check if the car has completed all laps
	if data["current_lap"] >= number_of_laps:
		data["finished"] = true
		data["finish_time"] = Time.get_ticks_msec() / 1000.0 - race_start_time
		finished_cars.append(car)
		data["position"] = finished_cars.size()  # 1-indexed position

		car_finished.emit(car, data["position"], data["finish_time"])
		print("[Race] %s finished in P%d — Time: %.2fs" % [car.name, data["position"], data["finish_time"]])

		# Update floating results panel (if visible)
		if results_panel:
			results_panel.update_results(get_results())

		# If the player finished, print results and emit signal
		if car.is_in_group("PLAYER"):
				# Show a floating results panel when the player finishes
				if not results_panel:
					results_panel = ResultsPanel.new()
					get_tree().get_root().add_child(results_panel)
				results_panel.update_results(get_results())
				results_panel.show()
				player_finished.emit(data["position"], data["finish_time"], get_results())

		# Check if all cars are done
		if finished_cars.size() == cars.size():
			race_complete.emit()
			print("[Race] All cars have finished!")


## Returns the current lap for a given car (1-indexed for display).
func get_car_lap(car: Car) -> int:
	if car_data.has(car):
		return car_data[car]["current_lap"]
	return 0


## Returns whether the car has finished the race.
func has_car_finished(car: Car) -> bool:
	if car_data.has(car):
		return car_data[car]["finished"]
	return false


## Returns the frozen finish position for a finished car, or the live position for an active car.
func get_car_position(car: Car) -> int:
	if car_data.has(car) and car_data[car]["finished"]:
		return car_data[car]["position"]
	# For active cars, calculate live positions
	var positions = _calculate_live_positions()
	return positions.get(car, cars.size())


## Returns the finish time for a finished car, or -1.0 if not finished.
func get_car_finish_time(car: Car) -> float:
	if car_data.has(car) and car_data[car]["finished"]:
		return car_data[car]["finish_time"]
	return -1.0


## Returns an ordered array of result dictionaries for all cars (finished first, then active).
func get_results() -> Array:
	var results: Array = []

	# Add finished cars in their finishing order
	for car in finished_cars:
		var data: Dictionary = car_data[car]
		results.append({
			"car": car,
			"name": car.name,
			"position": data["position"],
			"finish_time": data["finish_time"],
			"is_player": car.is_in_group("PLAYER"),
			"finished": true,
		})

	# Add non-finished cars sorted by lap progress + path distance
	var active_cars: Array[Car] = []
	for car in cars:
		if not car_data[car]["finished"]:
			active_cars.append(car)

	# Sort active cars: more laps = better; same laps = further along path = better
	active_cars.sort_custom(_compare_active_cars)

	var pos = finished_cars.size() + 1
	for car in active_cars:
		results.append({
			"car": car,
			"name": car.name,
			"position": pos,
			"finish_time": -1.0,
			"is_player": car.is_in_group("PLAYER"),
			"finished": false,
		})
		pos += 1

	return results


## Calculates live positions for all non-finished cars.
func _calculate_live_positions() -> Dictionary:
	var active_cars: Array[Car] = []
	for car in cars:
		if not car_data[car]["finished"]:
			active_cars.append(car)

	active_cars.sort_custom(_compare_active_cars)

	var positions: Dictionary = {}
	var pos = finished_cars.size() + 1
	for car in active_cars:
		positions[car] = pos
		pos += 1
	return positions


## Comparison function: cars with more laps are ahead; ties broken by path progress.
func _compare_active_cars(a: Car, b: Car) -> bool:
	var a_laps: int = car_data[a]["current_lap"]
	var b_laps: int = car_data[b]["current_lap"]

	if a_laps != b_laps:
		return a_laps > b_laps  # More laps = better position

	# Same lap count — compare distance along the track path
	if track_path and track_path.curve:
		var a_offset = _get_path_offset(a)
		var b_offset = _get_path_offset(b)
		return a_offset > b_offset  # Further along = better position

	return false


## Gets the car's current offset along the track path curve.
func _get_path_offset(car: Car) -> float:
	if not track_path or not track_path.curve:
		return 0.0
	var local_pos = track_path.global_transform.affine_inverse() * car.global_position
	return track_path.curve.get_closest_offset(local_pos)


## Prints a formatted leaderboard to the console and shows it in the debug label.
func _print_race_results() -> void:
	var results = get_results()
	var text := "=== RACE RESULTS ===\n"
	for entry in results:
		var time_str: String
		if entry["finished"]:
			time_str = "%.2fs" % entry["finish_time"]
		else:
			time_str = "DNF"
		var player_marker = "  ★" if entry["is_player"] else ""
		var line = "P%d  %s  —  %s%s" % [entry["position"], entry["name"], time_str, player_marker]
		text += line + "\n"
		print(line)
	text += "===================="
	print("====================")
	GlobalSignals.show_debug_text.emit(text)
