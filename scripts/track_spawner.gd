class_name TrackSpawner
extends Node3D


var tracks = {
	1: "res://scenes/track_1.tscn",
	2: "res://scenes/track_2.tscn"
}

func spawn_track(track_number: int)->Track:
	var track_scene: PackedScene = load(tracks[track_number])
	var track: Track = track_scene.instantiate()
	add_child(track)
	return track
