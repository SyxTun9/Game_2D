extends Node
## Owns the active game screen and starts the player in the lobby.

@export var starting_scene: PackedScene = preload("res://scenes/lobby.tscn")
@export var map_scene: PackedScene = preload("res://scenes/map.tscn")

@onready var scene_container: Node = $SceneContainer

var active_scene: Node


func _ready() -> void:
	change_scene(starting_scene)


func change_scene(scene: PackedScene, carry_player: bool = false) -> void:
	if scene == null:
		push_error("Cannot change to an empty scene.")
		return

	var carried_player: Node2D
	var carried_menu: CanvasLayer
	if carry_player and is_instance_valid(active_scene):
		carried_player = active_scene.get_node_or_null("Player") as Node2D
		carried_menu = active_scene.get_node_or_null("TransformationMenu") as CanvasLayer
		if carried_player != null:
			active_scene.remove_child(carried_player)
		if carried_menu != null:
			active_scene.remove_child(carried_menu)

	if is_instance_valid(active_scene):
		active_scene.queue_free()

	active_scene = scene.instantiate()
	scene_container.add_child(active_scene)

	if carried_menu != null:
		active_scene.add_child(carried_menu)
	if carried_player != null:
		active_scene.add_child(carried_player)
		var player_spawn := active_scene.get_node_or_null("PlayerSpawn") as Node2D
		if player_spawn != null:
			carried_player.global_position = player_spawn.global_position
		var carried_body := carried_player as CharacterBody2D
		if carried_body != null:
			carried_body.velocity = Vector2.ZERO
		if active_scene.has_method("configure_player"):
			active_scene.call("configure_player", carried_player)

	if active_scene.has_signal("map_requested"):
		active_scene.connect("map_requested", _on_map_requested, CONNECT_ONE_SHOT)


func _on_map_requested() -> void:
	change_scene(map_scene, true)
