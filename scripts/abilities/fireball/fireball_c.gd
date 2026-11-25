extends RigidBody3D

@export var lifespan: float = 20

func _ready() -> void:
	# On gère juste la destruction après X secondes
	await get_tree().create_timer(lifespan).timeout
	if is_instance_valid(self):
		queue_free()

func execute(caster: Node3D, target_data: Dictionary) -> void:
	# On fouille dans tous les composants attachés à ce sort
	for child in get_children():
		# Si le composant a une fonction "on_execute", on l'appelle !
		if child.has_method("on_execute"):
			child.on_execute(caster, target_data)
	var cast_pos: Vector3 = global_position if global_position != Vector3.ZERO else (caster.global_position if is_instance_valid(caster) else Vector3.ZERO)
	SpellAudioManager.play_fire_cast(self, cast_pos)
	SpellAudioManager.attach_fire_loop(self, -7.2, 11.5, 44.0)
