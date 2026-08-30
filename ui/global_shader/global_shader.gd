extends Node3D

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F10:
		if has_node("quad_mesh"):
			var quad = $quad_mesh
			quad.visible = !quad.visible
