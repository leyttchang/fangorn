extends Node3D

@onready var anim_player = $AnimationPlayer
@onready var gpu_particles = $GPUParticles3D

func play_effect() -> void:
	if anim_player == null:
		anim_player = get_node_or_null("AnimationPlayer")
	if gpu_particles == null:
		gpu_particles = get_node_or_null("GPUParticles3D")
		
	force_update_transform()
	if gpu_particles != null:
		gpu_particles.force_update_transform()
		
	if anim_player != null:
		anim_player.stop()
		anim_player.play("pft")
