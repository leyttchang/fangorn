extends Node3D

@onready var anim_player: AnimationPlayer = $AnimationPlayer
var caster: Node3D = null

@onready var slash1_local_basis = $slash_1.transform.basis
@onready var slash2_local_basis = $slash_2.transform.basis if has_node("slash_2") else Basis()

func start_complex_cast(player: Node3D) -> void:
	caster = player
	# On s'oriente dans la meme direction que le joueur pour que les projectiles partent droit devant !
	global_transform.basis = player.global_transform.basis

func on_mid_cast_event(event_name: String) -> void:

	if event_name == "slash_1":
		# On aligne UNIQUEMENT slash_1 sur le joueur
		if is_instance_valid(caster):
			$slash_1.global_position = caster.global_position
			var target_basis = caster.global_transform.basis
			var cam = caster.get_node_or_null("Camera3D")
			if cam != null:
				target_basis = cam.global_transform.basis
			
			# On applique la direction + on conserve ta rotation locale (editor) !
			$slash_1.global_transform.basis = target_basis * slash1_local_basis
			# On donne la VRAIE direction d'avancement au script (pour qu'il avance tout droit)
			$slash_1.forward_direction = -target_basis.z
		
		var slash_anim = $slash_1/AnimationPlayer
		if slash_anim != null:
			slash_anim.stop()
			slash_anim.play("cast") 
			$slash_1.visible = true
			
			# On calcule les degats AVANT d'activer la hitbox !
			var scaling_comp = $SpellScalingComponent
			if scaling_comp != null:
				scaling_comp.on_execute(caster, {})
			
			var attack_comp = $slash_1.get_node_or_null("AttackComponent")
			if attack_comp != null:
				attack_comp.set_deferred("monitoring", true)
				attack_comp.set_deferred("monitorable", true)

	elif event_name == "slash_2":
		# On aligne UNIQUEMENT slash_2 sur le joueur
		if is_instance_valid(caster):
			$slash_2.global_position = caster.global_position
			var target_basis = caster.global_transform.basis
			var cam = caster.get_node_or_null("Camera3D")
			if cam != null:
				target_basis = cam.global_transform.basis
			
			$slash_2.global_transform.basis = target_basis * slash2_local_basis
			
			if $slash_2.get("forward_direction") != null:
				$slash_2.forward_direction = -target_basis.z
		
		var slash_anim = $slash_2/AnimationPlayer
		if slash_anim != null:
			slash_anim.stop()
			slash_anim.play("cast") 
			$slash_2.visible = true
			
			# On calcule les degats AVANT d'activer la hitbox !
			var scaling_comp = $SpellScalingComponent2
			if scaling_comp != null:
				scaling_comp.on_execute(caster, {})
			
			var attack_comp = $slash_2.get_node_or_null("AttackComponent")
			if attack_comp != null:
				attack_comp.set_deferred("monitoring", true)
				attack_comp.set_deferred("monitorable", true)

func execute(player: Node3D, target_data: Dictionary) -> void:
	# On attend assez longtemps pour laisser les eclairs voyager (ex: 5 secondes)
	await get_tree().create_timer(5.0).timeout
	queue_free()
