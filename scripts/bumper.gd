extends StaticBody3D

@export var vertical_offset: float = 0.4
@export var vertical_duration: float = 1.0

var base_y: float = 0.0


func _ready() -> void:
	base_y = position.y
	animate_movement()


## Effect: Bobs the bumper up and down forever.
## The tween drives `position.y` directly. The old version tweened a dummy
## `y_offset` variable and copied it into `position` from `_process` every frame,
## which cost a GDScript callback plus a Vector3 rebuild per bumper per frame
## (27 of them in track_2, more on a 120 Hz display).
func animate_movement() -> void:
	var vt = create_tween()
	vt.set_loops()
	vt.tween_property(self, "position:y", base_y + vertical_offset, vertical_duration)
	vt.tween_property(self, "position:y", base_y - vertical_offset, vertical_duration)
