extends Node3D

signal interacted

func interact(player: Node3D) -> void:
	interacted.emit()
	queue_free()
