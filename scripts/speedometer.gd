extends Label

@onready var car := get_parent().get_parent().get_parent() as VehicleBody3D

func _ready() -> void:
	set_process(true)

func _process(_delta: float) -> void:
	if car:
		text = "%.2f" % car.current_speed
		#var speed_kmh = speed_mps * 3.6
		#text = str(round(speed_kmh)) + " km/h"
