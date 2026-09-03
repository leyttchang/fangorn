extends Node3D

func _ready() -> void:
	call_deferred("_setup_children")

func _setup_children() -> void:
	for child in get_children():
		child.tree_exited.connect(_check_children)

func _check_children() -> void:
	if get_child_count() <= 1:
		queue_free()
