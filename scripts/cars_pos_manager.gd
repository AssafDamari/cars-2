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


@export var update_interval: float = 0.1 ## Throttled update interval in seconds (10 Hz)
var _update_timer: float = 0.1 # Start at update_interval so first frame updates immediately
var _sample_points: Array[Vector3] = []

func _ready() -> void:
	add_to_group("CARS_POS_MANAGER")


func _process(delta: float) -> void:
	if not track_path or not track_path.curve:
		return
		
	var track_length = track_path.curve.get_baked_length()
	if track_length == 0.0:
		return

	_update_timer += delta
	if _update_timer < update_interval:
		return
	_update_timer = 0.0
		
	for car in cars:
		if not is_instance_valid(car) or not car_data.has(car):
			continue
		if car_data[car]["finished"]:
			continue
			
		var last_known_offset = car_data[car].get("last_offset", -1.0)
		var current_offset = _get_path_offset(car, last_known_offset)
		
		if not car_data[car].has("last_offset"):
			car_data[car]["last_offset"] = current_offset
			# If a car starts near the end of the track (wrap-around), make its initial progress negative
			if current_offset > track_length * 0.5:
				car_data[car]["progress"] = current_offset - track_length
			else:
				car_data[car]["progress"] = current_offset
			continue
			
		var prev_offset = car_data[car]["last_offset"]
		var delta_offset = current_offset - prev_offset
		
		# Detect wrap-around across the start/finish line of the path
		if delta_offset > track_length * 0.5:
			delta_offset -= track_length
		elif delta_offset < -track_length * 0.5:
			delta_offset += track_length
			
		car_data[car]["progress"] += delta_offset
		car_data[car]["last_offset"] = current_offset


func load_cars(race_cars: Array[Car]) -> void:
	cars = race_cars
	car_data.clear()
	finished_cars.clear()
	_update_timer = update_interval
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
				results_panel.display()
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

	# Sort active cars: more laps = better; same laps = further progress
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

	# Same lap count — compare continuous progress
	var a_progress = car_data[a].get("progress", 0.0)
	var b_progress = car_data[b].get("progress", 0.0)
	return a_progress > b_progress  # Further progress = better position


## Gets the car's current offset along the track path curve using a fast local window search.
func _get_path_offset(car: Car, last_offset: float = -1.0) -> float:
	if not track_path or not track_path.curve:
		return 0.0
	var curve = track_path.curve
	var track_length = curve.get_baked_length()
	if track_length == 0.0:
		return 0.0

	var local_pos = track_path.global_transform.affine_inverse() * car.global_position

	# If no prior offset known, do a global search once
	if last_offset < 0.0:
		return curve.get_closest_offset(local_pos)

	# Local window search around last_offset
	const SEARCH_BACK: float = 15.0
	const SEARCH_FWD: float = 35.0
	const STEP: float = 2.5
	const FALLBACK_DIST_SQ: float = 900.0 # 30 meters squared

	var start_s = last_offset - SEARCH_BACK
	var end_s = last_offset + SEARCH_FWD
	var num_steps = int((end_s - start_s) / STEP) + 1

	if _sample_points.size() != num_steps:
		_sample_points.resize(num_steps)

	var best_s = start_s
	var best_dist_sq = INF
	var best_idx = 0

	for i in range(num_steps):
		var s = start_s + i * STEP
		var pt = curve.sample_baked(fposmod(s, track_length))
		_sample_points[i] = pt
		var d_sq = pt.distance_squared_to(local_pos)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best_s = s
			best_idx = i

	# If car drifted off-track or was teleported, recover via global lookup
	if best_dist_sq > FALLBACK_DIST_SQ:
		return curve.get_closest_offset(local_pos)

	# Analytical line-segment projection refinement on adjacent segments
	var refined_s = best_s
	var min_refined_dist_sq = best_dist_sq

	if best_idx > 0:
		var p1 = _sample_points[best_idx - 1]
		var p2 = _sample_points[best_idx]
		var seg = p2 - p1
		var seg_len_sq = seg.length_squared()
		if seg_len_sq > 0.0001:
			var t = clampf((local_pos - p1).dot(seg) / seg_len_sq, 0.0, 1.0)
			var proj = p1 + seg * t
			var d_sq = proj.distance_squared_to(local_pos)
			if d_sq < min_refined_dist_sq:
				min_refined_dist_sq = d_sq
				refined_s = (start_s + (best_idx - 1) * STEP) + t * STEP

	if best_idx < num_steps - 1:
		var p1 = _sample_points[best_idx]
		var p2 = _sample_points[best_idx + 1]
		var seg = p2 - p1
		var seg_len_sq = seg.length_squared()
		if seg_len_sq > 0.0001:
			var t = clampf((local_pos - p1).dot(seg) / seg_len_sq, 0.0, 1.0)
			var proj = p1 + seg * t
			var d_sq = proj.distance_squared_to(local_pos)
			if d_sq < min_refined_dist_sq:
				min_refined_dist_sq = d_sq
				refined_s = (start_s + best_idx * STEP) + t * STEP

	return fposmod(refined_s, track_length)


func _exit_tree() -> void:
	# Clean up the results panel when the race scene exits (e.g., when reloading or going to menu)
	if results_panel and is_instance_valid(results_panel):
		results_panel.queue_free()
