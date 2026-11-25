extends Node3D

@onready var omni_light: OmniLight3D = $OmniLight3D
@onready var anim_player: AnimationPlayer = $OmniLight3D/AnimationPlayer
@onready var particles: GPUParticles3D = $chest_particule/aura_glow_effect/particles
@onready var aura: MeshInstance3D = $chest_particule/aura_glow_effect as MeshInstance3D
@onready var scaling_component: SpellScalingComponent = $SpellScalingComponent
@onready var attack_component: AttackComponent = $AttackComponent


func _ready() -> void:
	if omni_light != null:
		omni_light.shadow_enabled = false
		omni_light.omni_range = 12.0
	if anim_player != null and anim_player.has_animation("glow"):
		anim_player.play("glow")

	var timer: SceneTreeTimer = get_tree().create_timer(3.2)
	timer.timeout.connect(_on_timer_timeout)


func execute(caster: Node3D, target_data: Dictionary) -> void:
	if target_data.has("impact_point"):
		global_position = target_data["impact_point"] as Vector3

	if attack_component != null:
		attack_component.on_execute(caster, target_data)
	if scaling_component != null:
		scaling_component.on_execute(caster, target_data)
		var final_rad: float = scaling_component.final_impact_radius
		var col: CollisionShape3D = attack_component.get_node_or_null("CollisionShape3D") as CollisionShape3D if attack_component != null else null
		if col != null and col.shape is CylinderShape3D:
			var cyl: CylinderShape3D = (col.shape as CylinderShape3D).duplicate() as CylinderShape3D
			cyl.radius = final_rad
			col.shape = cyl
		var scale_f: float = final_rad / maxf(0.1, scaling_component.base_impact_radius)
		var part_root: Node3D = get_node_or_null("chest_particule") as Node3D
		if part_root != null:
			part_root.scale = Vector3(scale_f * 1.4, 1.35, scale_f * 1.4)

	SpellAudioManager.play_lightning_cast(self, global_position, 1.32, -2.5)

	# Coupe la hitbox d'impact initial après 0.30s pour que seule la frappe céleste blesse
	await get_tree().create_timer(0.30).timeout
	if is_instance_valid(attack_component):
		attack_component.set_deferred("monitoring", false)


func _on_timer_timeout() -> void:
	if anim_player != null:
		anim_player.stop()
	if particles != null:
		particles.emitting = false

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	if omni_light != null:
		tween.tween_property(omni_light, "light_energy", 0.0, 0.75)
	if aura != null and aura.material_override != null:
		var mat: ShaderMaterial = aura.material_override as ShaderMaterial
		if mat != null:
			tween.tween_property(mat, "shader_parameter/fading_param", 0.0, 0.75)

	tween.chain().tween_callback(queue_free)
