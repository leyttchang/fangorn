extends Node3D

var _blood_pool: Array[Node3D] = []
var _pool_size: int = 50
var _current_blood_index: int = 0
var blood_scene: PackedScene = preload("res://particule/blood/blood_particule.tscn")
var blood_script = preload("res://particule/blood/blood_particule.gd")

func _ready() -> void:
	print("[VFXPool] Initializing ", _pool_size, " blood particles...")
	for i in range(_pool_size):
		var blood = blood_scene.instantiate() as Node3D
		if blood.get_script() == null:
			blood.set_script(blood_script)
			# Re-trigger onready variables if we just attached the script manually
			if blood.has_method("_ready"):
				blood._ready()
			# manually set the references because _ready might not trigger correctly
			blood.anim_player = blood.get_node_or_null("AnimationPlayer")
			blood.gpu_particles = blood.get_node_or_null("GPUParticles3D")
			
		add_child(blood)
		_blood_pool.append(blood)
	print("[VFXPool] Done. Pool size: ", _blood_pool.size())

func get_blood() -> Node3D:
	if _blood_pool.is_empty():
		print("[VFXPool] ERREUR: Pool is empty!")
		return null
		
	var blood = _blood_pool[_current_blood_index]
	_current_blood_index = (_current_blood_index + 1) % _pool_size
	return blood
