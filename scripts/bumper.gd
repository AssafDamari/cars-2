extends StaticBody3D

@export var min_scale: float = 0.8
@export var max_scale: float = 1.2
@export var animation_duration: float = 2.0

func _ready() -> void:
	animate_size()

func animate_size() -> void:
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "scale", Vector3.ONE * max_scale, animation_duration)
	tween.tween_property(self, "scale", Vector3.ONE * min_scale, animation_duration)
