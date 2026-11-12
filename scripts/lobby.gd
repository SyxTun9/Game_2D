extends Node2D

signal map_requested

@onready var teleport_trigger: Area2D = $TeleportTrigger

var transition_requested := false


func _ready() -> void:
	teleport_trigger.body_entered.connect(_on_teleport_trigger_body_entered)


func _on_teleport_trigger_body_entered(body: Node2D) -> void:
	if transition_requested or body.name != "Player":
		return

	transition_requested = true
	teleport_trigger.set_deferred("monitoring", false)
	call_deferred("_emit_map_requested")


func _emit_map_requested() -> void:
	map_requested.emit()
