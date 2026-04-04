extends Node3D

@onready var load_button: Button = $CanvasLayer/LoadButton
@onready var unload_button: Button = $CanvasLayer/UnloadButton
@onready var load_pos: Marker3D = $LoadPos
@onready var active_marker: MeshInstance3D = $ActiveMarker

var currentActiveCargo: RigidBody3D = null

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("CARGO"):
		# replace previus activeCargo if any
		if currentActiveCargo:
			active_marker.visible = false
			currentActiveCargo = null
		
		active_marker.global_position = body.global_position
		active_marker.visible = true
		load_button.visible = true
		currentActiveCargo = body
		
func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("CARGO"):
		active_marker.visible = false
		load_button.visible = false
		currentActiveCargo = null


func _on_load_button_pressed() -> void:
	if currentActiveCargo:
		active_marker.visible = false
		currentActiveCargo.freeze = true
		currentActiveCargo.global_position = load_pos.global_position
		currentActiveCargo.freeze = false
		currentActiveCargo = null
