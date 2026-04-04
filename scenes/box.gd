class_name Cargo
extends RigidBody3D

@onready var active_marker: MeshInstance3D = $ActiveMarker

func show_active_marker():		
	active_marker.visible = true

func hide_active_marker():		
	active_marker.visible = false
