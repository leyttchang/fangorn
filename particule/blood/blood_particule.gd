extends Node3D

const FOLLOW_MAX_DURATION: float = 1.25

@onready var anim_player = $AnimationPlayer
@onready var gpu_particles = $GPUParticles3D

var follow_target: Node3D = null
var initial_local_transform: Transform3D
var _follow_timer: float = 0.0

func _ready() -> void:
	set_process(follow_target != null)

func set_follow_target(target: Node3D) -> void:
	follow_target = target
	_follow_timer = 0.0
	if target != null and is_instance_valid(target):
		# On calcule la position et rotation relative par rapport a la cible
		initial_local_transform = target.global_transform.affine_inverse() * global_transform
		set_process(true)
	else:
		set_process(false)

func _process(delta: float) -> void:
	_follow_timer += delta
	if _follow_timer >= FOLLOW_MAX_DURATION:
		follow_target = null
		set_process(false)
		return
	if follow_target != null and is_instance_valid(follow_target) and follow_target.is_inside_tree():
		global_transform = follow_target.global_transform * initial_local_transform
	else:
		follow_target = null
		set_process(false)

func play_effect() -> void:
	_follow_timer = 0.0
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
