extends Label

@onready var car := get_parent().get_parent().get_parent() as VehicleBody3D
var pos_manager: CarsPosManager = null

func _ready() -> void:
	set_process(true)

func _process(_delta: float) -> void:
	if not car:
		return
		
	if not pos_manager:
		pos_manager = get_tree().get_first_node_in_group("CARS_POS_MANAGER") as CarsPosManager
		if not pos_manager:
			pos_manager = get_tree().current_scene.find_child("CarsPosManager", true, false) as CarsPosManager
			
	if pos_manager:
		if pos_manager.has_car_finished(car):
			_set_text_if_changed("Finished")
		else:
			var current_lap = pos_manager.get_car_lap(car)
			var display_lap = clampi(current_lap + 1, 1, pos_manager.number_of_laps)
			_set_text_if_changed("Lap %d/%d" % [display_lap, pos_manager.number_of_laps])


func _set_text_if_changed(new_text: String) -> void:
	if text != new_text:
		text = new_text
