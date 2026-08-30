extends Node3D

@onready var anim_player = $AnimationPlayer
@onready var gpu_particles = $GPUParticles3D

var follow_target: Node3D = null
var initial_local_transform: Transform3D

func set_follow_target(target: Node3D) -> void:
	follow_target = target
	if target != null and is_instance_valid(target):
		# On calcule la position et rotation relative par rapport a la cible
		initial_local_transform = target.global_transform.affine_inverse() * global_transform
	set_process(target != null)

func _process(_delta: float) -> void:
	if follow_target != null and is_instance_valid(follow_target) and follow_target.is_inside_tree():
		global_transform = follow_target.global_transform * initial_local_transform
	else:
		follow_target = null
		set_process(false)

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
