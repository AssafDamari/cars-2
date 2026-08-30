extends Label

func _process(_delta: float) -> void:
	# Engine.get_frames_per_second() returns the current FPS
	var new_text = "FPS: %d" % Engine.get_frames_per_second()
	if text != new_text:
		text = new_text
