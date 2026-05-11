class_name RaceResultsPanel
extends Control

var results_grid: GridContainer

func _ready() -> void:
	name = "RaceResultsPanel"
	# Make the panel occupy most of the screen
	anchor_left = 0.05
	anchor_top = 0.05
	anchor_right = 0.95
	anchor_bottom = 0.95
	visible = false

	var panel = Panel.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "RACE RESULTS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(0, 180)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font_size(title, 160)
	vbox.add_child(title)

	results_grid = GridContainer.new()
	results_grid.columns = 3
	results_grid.custom_minimum_size = Vector2(0, 600)
	results_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(results_grid)

	var close_hbox = HBoxContainer.new()
	close_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(close_hbox)
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.size_flags_horizontal = Control.SIZE_FILL
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_btn.custom_minimum_size = Vector2(0, 120)
	_apply_font_size(close_btn, 96)
	close_btn.connect("pressed", Callable(self, "_on_close_pressed"))
	close_hbox.add_child(close_btn)


func _on_close_pressed() -> void:
	hide()

func _apply_font_size(control: Control, font_size: int) -> void:
	if control.has_method("add_theme_font_size_override"):
		control.add_theme_font_size_override("font_size", font_size)

func update_results(results: Array) -> void:
	# Clear previous entries
	for child in results_grid.get_children():
		results_grid.remove_child(child)
		child.queue_free()

	# Populate header row
	var h_pos = Label.new(); h_pos.text = "Pos"; _apply_font_size(h_pos, 120); results_grid.add_child(h_pos)
	var h_name = Label.new(); h_name.text = "Name"; _apply_font_size(h_name, 120); results_grid.add_child(h_name)
	var h_time = Label.new(); h_time.text = "Time"; _apply_font_size(h_time, 120); results_grid.add_child(h_time)

	for entry in results:
		var pos_label = Label.new()
		pos_label.text = "P%d" % entry["position"]
		_apply_font_size(pos_label, 112)
		results_grid.add_child(pos_label)

		var name_label = Label.new()
		name_label.text = entry["name"] + (" ★" if entry["is_player"] else "")
		_apply_font_size(name_label, 112)
		results_grid.add_child(name_label)

		var time_label = Label.new()
		if entry["finished"]:
			time_label.text = "%.2fs" % entry["finish_time"]
		else:
			time_label.text = "DNF"
		_apply_font_size(time_label, 112)
		results_grid.add_child(time_label)

	show()
