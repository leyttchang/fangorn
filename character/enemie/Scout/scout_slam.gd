extends Node3D

func _ready() -> void:
	if is_multiplayer_authority():
		# On attend 1 frame que le spawner ait propag le noeud
		await get_tree().physics_frame
		rpc("rpc_set_position", global_position)

@rpc("authority", "call_remote", "reliable")
func rpc_set_position(pos: Vector3) -> void:
	global_position = pos
