class_name Teleporter
extends Area3D

## Path to the scene this teleporter leads to
@export var target_scene: String = ""
## Must match the name of a Marker3D node in the target scene
@export var target_spawn_point: String = ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		GameManager.travel_to(target_scene, target_spawn_point)
