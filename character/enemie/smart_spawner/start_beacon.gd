extends Node3D

signal interacted

func _ready() -> void:
	if is_multiplayer_authority():
		# On attend 1 frame que le spawner ait propag le noeud
		await get_tree().physics_frame
		rpc("rpc_set_position", global_position)

@rpc("authority", "call_remote", "reliable")
func rpc_set_position(pos: Vector3) -> void:
	global_position = pos

func interact(player: Node3D) -> void:
	rpc_id(1, "_rpc_request_interact")

@rpc("any_peer", "call_local", "reliable")
func _rpc_request_interact() -> void:
	if multiplayer.is_server():
		interacted.emit()
		queue_free()
