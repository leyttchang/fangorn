extends Node3D
class_name NetworkSmoother

@export var lerp_speed: float = 15.0
var _parent: Node3D

func _ready() -> void:
	if multiplayer.is_server():
		set_process(false)
		return
		
	_parent = get_parent() as Node3D
	top_level = true
	
	if _parent:
		global_transform = _parent.global_transform

func _process(delta: float) -> void:
	if is_instance_valid(_parent):
		global_position = global_position.lerp(_parent.global_position, lerp_speed * delta)
		global_transform.basis = global_transform.basis.slerp(_parent.global_transform.basis, lerp_speed * delta)
