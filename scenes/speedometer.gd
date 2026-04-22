extends Label

@onready var car := get_parent().get_parent().get_parent() as VehicleBody3D

func _process(_delta: float) -> void:
	if car:
		var speed_mps = car.linear_velocity.length()
		text = "%.2f" % speed_mps

		#var speed_kmh = speed_mps * 3.6
		#text = str(round(speed_kmh)) + " km/h"
