extends Node

## Holds the spawn point name until the new scene loads
var _pending_spawn_point: String = ""

func travel_to(scene_path: String, spawn_point: String) -> void:
	_pending_spawn_point = spawn_point
	get_tree().change_scene_to_file(scene_path)

func get_pending_spawn() -> String:
	var spawn := _pending_spawn_point
	_pending_spawn_point = ""   # clear it after reading — important
	return spawn
