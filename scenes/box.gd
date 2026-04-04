extends RigidBody3D

@onready var active_marker: MeshInstance3D = $ActiveMarker
var on_ground: bool = false
func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.name == "Ground":
		on_ground = true	
	elif body is Car:
		if on_ground:
			active_marker.visible = true

func _on_area_3d_body_exited(_body: Node3D) -> void:
	active_marker.visible = false
