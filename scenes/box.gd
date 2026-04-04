extends RigidBody3D

@onready var active_marker: MeshInstance3D = $ActiveMarker

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is Car:
		active_marker.visible = true

func _on_area_3d_body_exited(body: Node3D) -> void:
	active_marker.visible = false
