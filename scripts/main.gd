extends Node
## Owns the active game screen and starts the player in the lobby.

@export var starting_scene: PackedScene = preload("res://scenes/lobby.tscn")

@onready var scene_container: Node = $SceneContainer

var active_scene: Node


func _ready() -> void:
	change_scene(starting_scene)


func change_scene(scene: PackedScene) -> void:
	if scene == null:
		push_error("Cannot change to an empty scene.")
		return

	if is_instance_valid(active_scene):
		active_scene.queue_free()

	active_scene = scene.instantiate()
	scene_container.add_child(active_scene)
