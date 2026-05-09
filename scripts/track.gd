class_name Track
extends Node3D

@onready var path_3d: Path3D = $Path3D
@onready var start_position: Marker3D = $StartPosition

func get_path_3d() -> Path3D:
	return path_3d

func get_start_position() -> Marker3D:
	return start_position
