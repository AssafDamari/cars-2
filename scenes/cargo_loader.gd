extends Node3D

@onready var load_button: Button = $CanvasLayer/LoadButton
@onready var unload_button: Button = $CanvasLayer/UnloadButton
@onready var load_pos: Marker3D = $LoadPos

var currentActiveCargo: Cargo = null

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is Cargo:
		# replace previus activeCargo if any
		if currentActiveCargo:
			currentActiveCargo.hide_active_marker()
			currentActiveCargo = null
		body.show_active_marker()
		load_button.visible = true
		currentActiveCargo = body
		
func _on_area_3d_body_exited(body: Node3D) -> void:
	if body is Cargo:
		body.hide_active_marker()
		load_button.visible = false
		currentActiveCargo = null


func _on_load_button_pressed() -> void:
	if currentActiveCargo:
		currentActiveCargo.hide_active_marker()
		currentActiveCargo.freeze = true
		currentActiveCargo.global_position = load_pos.global_position
		currentActiveCargo.freeze = false
		currentActiveCargo = null
