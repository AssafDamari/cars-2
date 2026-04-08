class_name GearSlider
extends Control

signal gear_changed(new_gear: String)

enum Gear { DRIVE, NEUTRAL, REVERSE }

@export var current_gear: Gear = Gear.NEUTRAL
@export var active_color: Color = Color.GREEN
@export var idle_color: Color = Color.GRAY

var is_dragging: bool = false

func _ready() -> void:
	# Ensure the control can receive input
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	# Works for both Mouse and Touch (if "Emulate Mouse from Touch" is on, 
	# or natively via InputEventScreenTouch)
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
	
	# Divide the vertical area into 3 zones
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
	# Visualizing the slider in the editor and game
	var rect_height: float = size.y / 3.0
	var gear_names = ["DRIVE", "NEUTRAL", "REVERSE"]
	
	for i in range(3):
		var rect = Rect2(0, i * rect_height, size.x, rect_height)
		var color = active_color if current_gear == i else idle_color
		
		draw_rect(rect, color, true)
		draw_rect(rect, Color.BLACK, false, 2.0) # Border
		
		var default_font = get_theme_default_font()
		# Wrap the font size in int() to satisfy the compiler
		var font_size: int = int(get_theme_default_font_size())

		# Also ensure the Y position calculation is cast to int if needed, 
		# though draw_string usually handles Vector2 floats fine.
		var text_pos = rect.position + Vector2(10, (rect_height / 2) + (font_size / 2.0))
		
		draw_string(default_font, text_pos, gear_names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
