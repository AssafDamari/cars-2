class_name TrackSpawner
extends Node3D


var tracks = {
	1: "res://scenes/track_1.tscn",
	2: "res://scenes/track_2.tscn",
	3: "res://scenes/track_3.tscn",
	4: "res://scenes/track_4_downhill.tscn"
}

func spawn_track(track_number: int)->Track:
	var track_scene: PackedScene = load(tracks[track_number])
	var track: Track = track_scene.instantiate()
	add_child(track)
	return track
