extends Node3D

func _ready() -> void:
	call_deferred("_setup_children")

func _setup_children() -> void:
	for child in get_children():
		child.tree_exited.connect(_check_children)

func _check_children() -> void:
	if not is_inside_tree(): return
	if get_child_count() <= 1:
		if is_multiplayer_authority():
			rpc("rpc_delete_bundle")

@rpc("authority", "call_local", "reliable")
func rpc_delete_bundle() -> void:
	queue_free()
