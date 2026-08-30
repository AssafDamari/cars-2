extends Control

## Displays the leaderboard of cars on the left side of the screen.
## Decoupled and runs independently by listening to GlobalSignals and finding CarsPosManager.

@export var update_interval: float = 0.2
@export var font_size: int = 36

@onready var container: VBoxContainer = $VBoxContainer

var timer: float = 0.0
var pos_manager: CarsPosManager = null

# Map: Car -> PanelContainer
var car_items: Dictionary = {}


func _ready() -> void:
	GlobalSignals.cars_setup_done.connect(setup_cars_list)


func _exit_tree() -> void:
	GlobalSignals.cars_setup_done.disconnect(setup_cars_list)


func _process(delta: float) -> void:
	if not pos_manager or not is_instance_valid(pos_manager):
		return
		
	timer += delta
	if timer >= update_interval:
		update_list()
		timer = 0.0


func setup_cars_list() -> void:
	# Clean up any existing children first
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	car_items.clear()

	# Find CarsPosManager in the scene
	pos_manager = get_tree().get_first_node_in_group("CARS_POS_MANAGER") as CarsPosManager
	if not pos_manager:
		# Fallback search
		pos_manager = get_tree().current_scene.find_child("CarsPosManager", true, false) as CarsPosManager

	if not pos_manager:
		push_warning("[CarsList] CarsPosManager not found in scene tree.")
		set_process(false)
		return

	# Create a row item for each car
	for car in pos_manager.cars:
		if not is_instance_valid(car):
			continue

		var item = PanelContainer.new()
		item.name = "Item_" + car.name
		
		# Build custom StyleBoxFlat for glassmorphic design
		var style_box = StyleBoxFlat.new()
		style_box.corner_radius_top_left = 6
		style_box.corner_radius_top_right = 6
		style_box.corner_radius_bottom_left = 6
		style_box.corner_radius_bottom_right = 6
		# Larger margins for vertical mobile screens
		style_box.content_margin_left = 34
		style_box.content_margin_right = 14
		style_box.content_margin_top = 12
		style_box.content_margin_bottom = 12

		if car.is_in_group("PLAYER"):
			style_box.bg_color = Color(0.05, 0.15, 0.25, 0.75) # Slightly blue glassmorphism
			style_box.border_width_left = 2
			style_box.border_width_top = 2
			style_box.border_width_right = 2
			style_box.border_width_bottom = 2
			style_box.border_color = Color(0.0, 0.8, 1.0, 0.8) # Glowing cyan border
		else:
			style_box.bg_color = Color(0.05, 0.05, 0.05, 0.6) # Standard dark glassmorphism
			style_box.border_width_left = 1
			style_box.border_width_top = 1
			style_box.border_width_right = 1
			style_box.border_width_bottom = 1
			style_box.border_color = Color(0.3, 0.3, 0.3, 0.4) # Subtle gray border

		item.add_theme_stylebox_override("panel", style_box)

		# Horizontal layout for the row contents
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		item.add_child(hbox)

		# 1. Car Color indicator (Requirement 3: small box/line with car color)
		var color_bar = ColorRect.new()
		color_bar.color = car.color
		color_bar.custom_minimum_size = Vector2(20, 40)
		color_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(color_bar)

		# 2. Position Label
		var pos_label = Label.new()
		pos_label.text = "0"
		pos_label.custom_minimum_size = Vector2(35, 0)
		pos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pos_label.add_theme_font_size_override("font_size", font_size)
		if car.is_in_group("PLAYER"):
			pos_label.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0)) # Cyan text
		else:
			pos_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		hbox.add_child(pos_label)

		# 3. Name Label
		var name_label = Label.new()
		name_label.text = _get_clean_car_name(car)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", font_size)
		if car.is_in_group("PLAYER"):
			name_label.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0)) # Cyan text
			name_label.text += " ★"
		else:
			name_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		hbox.add_child(name_label)

		# 4. Lap / Finished Time Label
		var lap_label = Label.new()
		lap_label.text = ""
		lap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lap_label.add_theme_font_size_override("font_size", font_size - 4)
		hbox.add_child(lap_label)

		# Store references in metadata for quick access in update loop
		item.set_meta("pos_label", pos_label)
		item.set_meta("lap_label", lap_label)

		container.add_child(item)
		car_items[car] = item

	# Initial update
	update_list()


func update_list() -> void:
	if not pos_manager or not is_instance_valid(pos_manager):
		return

	var results = pos_manager.get_results()
	var total_laps = pos_manager.number_of_laps

	for i in range(results.size()):
		var res = results[i]
		var car = res["car"]
		var item = car_items.get(car)
		if not item or not is_instance_valid(item):
			continue

		# PERFORMANCE: Only rearrange hierarchy if index actually changed (saves significant redraw/layout overhead)
		if item.get_index() != i:
			container.move_child(item, i)

		# Retrieve label references
		var pos_label = item.get_meta("pos_label") as Label
		var lap_label = item.get_meta("lap_label") as Label

		# Set Position Text (only modify if changed to avoid layout recalculations)
		var pos_str = "%d" % res["position"]
		if pos_label.text != pos_str:
			pos_label.text = pos_str

		# Set Lap or Finished Time Status (Requirement 4 & 5)
		var lap_str = ""
		var lap_color = Color.WHITE
		if res["finished"]:
			lap_str = _format_time(res["finish_time"])
			lap_color = Color(0.3, 1.0, 0.3) # Greenish tint for finished
		else:
			var current_lap = pos_manager.get_car_lap(car)
			var display_lap = clampi(current_lap + 1, 1, total_laps)
			lap_str = "L%d/%d" % [display_lap, total_laps]
			lap_color = Color(1.0, 1.0, 1.0) # Normal white color

		if lap_label.text != lap_str:
			lap_label.text = lap_str
		if lap_label.modulate != lap_color:
			lap_label.modulate = lap_color


func _get_clean_car_name(car: Car) -> String:
	if car.is_in_group("PLAYER"):
		return "Player"
	var name_str = car.name
	if name_str.begins_with("NpcCar"):
		return "Car " + name_str.trim_prefix("NpcCar")
	return name_str


func _format_time(seconds: float) -> String:
	var mins = int(seconds / 60)
	var secs = int(seconds) % 60
	var msecs = int((seconds - int(seconds)) * 100)
	return "%d:%02d.%02d" % [mins, secs, msecs]
