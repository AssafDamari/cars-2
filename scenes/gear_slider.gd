class_name GearSlider
extends Control

signal gear_changed(new_gear: String)

enum Gear { DRIVE, NEUTRAL, REVERSE }

@export var current_gear: Gear = Gear.NEUTRAL
@export var active_color: Color = Color.GREEN
@export var idle_color: Color = Color.DARK_SLATE_GRAY
@export var text_color: Color = Color.WHITE

@export_range(0.1, 1.0) var inactive_width_percentage: float = 0.7

var is_dragging: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		if event.is_pressed():
			is_dragging = true
			_update_gear_from_pos(event.position)
		else:
			is_dragging = false

	if (event is InputEventMouseMotion or event is InputEventScreenDrag) and is_dragging:
		_update_gear_from_pos(event.position)

func _update_gear_from_pos(pos: Vector2) -> void:
	var previous_gear = current_gear
	var height = size.y
	
	if pos.y < height / 3.0:
		current_gear = Gear.DRIVE
	elif pos.y < (height / 3.0) * 2.0:
		current_gear = Gear.NEUTRAL
	else:
		current_gear = Gear.REVERSE
	
	if previous_gear != current_gear:
		queue_redraw()
		gear_changed.emit(Gear.keys()[current_gear])

func _draw() -> void:
	var rect_height: float = size.y / 3.0
	var gear_labels = ["D", "N", "R"]
	var default_font = get_theme_default_font()
	var font_size: int = 60#int(get_theme_default_font_size())

	for i in range(3):
		var is_active = (current_gear == i)
		
		# Logic for "Gear Handle" look:
		# If active, width is full (size.x). If inactive, it's narrowed.
		var target_width = size.x if is_active else size.x * inactive_width_percentage
		var x_offset = (size.x - target_width) / 2.0
		
		var rect = Rect2(x_offset, i * rect_height, target_width, rect_height)
		var color = active_color if is_active else idle_color
		
		# Draw the slot background
		draw_rect(rect, color, true)
		
		# Optional: Add a subtle highlight border for the active gear
		if is_active:
			draw_rect(rect, Color.WHITE, false, 2.0)
		
		# Calculate centered text position
		# We use the full size.x for centering so labels stay aligned vertically
		var label_pos = Vector2(0, (i * rect_height) + (rect_height / 2.0) + (font_size / 3.0))
		
		draw_string(default_font, label_pos, gear_labels[i], HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, text_color)
