extends Node3D

@rpc("authority", "call_remote", "reliable")
func rpc_set_position(pos: Vector3) -> void:
	global_position = pos
