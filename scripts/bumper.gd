extends StaticBody3D

@export var vertical_offset: float = 0.4
#@export var horizontal_offset: float = 2.0
@export var vertical_duration: float = 1.0
#@export var horizontal_duration: float = 0.5

var base_position: Vector3

#var x_offset: float = 0.0
var y_offset: float = 0.0

func _ready() -> void:
	base_position = position
	animate_movement()

func _process(_delta: float) -> void:
	var p = base_position
	#p.x = base_position.x + x_offset
	p.y = base_position.y + y_offset
	position = p


func animate_movement() -> void:
	var vt = create_tween()
	vt.set_loops()
	vt.tween_property(self, "y_offset", vertical_offset, vertical_duration)
	vt.tween_property(self, "y_offset", -vertical_offset, vertical_duration)

	#var ht = create_tween()
	#ht.set_loops()
	#ht.tween_property(self, "x_offset", horizontal_offset, horizontal_duration)
	#ht.tween_property(self, "x_offset", -horizontal_offset, horizontal_duration)
