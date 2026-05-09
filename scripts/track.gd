class_name Track
extends Node3D

@onready var path_3d: Path3D = $Path3D

func get_path_3d() -> Path3D:
	return path_3d
