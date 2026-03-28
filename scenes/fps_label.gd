extends Label

func _process(_delta: float) -> void:
	# Engine.get_frames_per_second() returns the current FPS
	text = "FPS: %d" % Engine.get_frames_per_second()
