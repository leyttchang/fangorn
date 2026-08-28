extends Node3D

signal interacted

func _ready() -> void:
	pass # Position geree par MultiplayerSynchronizer (Spawn)

func interact(player: Node3D) -> void:
	rpc_id(1, "_rpc_request_interact")

@rpc("any_peer", "call_local", "reliable")
func _rpc_request_interact() -> void:
	if multiplayer.is_server():
		interacted.emit()
		queue_free()
