extends Node3D

@export var duration_on_ground: float = 15.0

# On récupère directement les enfants grâce à ton architecture
@onready var scaling_component = $SpellScalingComponent
@onready var collision = $AttackComponent/CollisionShape3D
@onready var decal = $Ice_crash_effect/Decal
@onready var attack_component = $AttackComponent
@onready var ice_crash_effect = $Ice_crash_effect







func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(attack_component):
		attack_component.queue_free()



func execute(caster: Node, target_data: Dictionary) -> void:
	
	# --- LA CORRECTION EST ICI ---
	if caster is Node3D:
		var forward_direction = -caster.global_transform.basis.z.normalized()
		
		# 1. On place le sort 1.5 mètre devant le joueur
		global_position = caster.global_position + (forward_direction * 1.5)
		
		# 2. NOUVEAU : On force le sort à avoir la même rotation horizontale que le joueur
		global_rotation.y = caster.global_rotation.y
		
		# (Alternative : si tu veux que le sort copie AUSSI l'inclinaison du joueur
		# s'il regarde en haut ou en bas sur une pente, utilise plutôt la ligne ci-dessous :)
		# global_transform.basis = caster.global_transform.basis
		
	else:
		global_position = caster.global_position 
	# -----------------------------
	
	# 1. On lance le calcul des stats (Dégâts, Radius, Knockback...)
	if scaling_component != null and scaling_component.has_method("on_execute"):
		scaling_component.on_execute(caster, target_data)
		
		# On récupère le rayon final (qui contient déjà le base_radius + l'Area of Effect du joueur)
		var final_radius = scaling_component.final_impact_radius
		
		# 2. SCALING DE LA HITBOX
		if collision != null and (collision.shape is CylinderShape3D or collision.shape is SphereShape3D):
			collision.shape = collision.shape.duplicate()
			collision.shape.radius = final_radius
			
		# 3. SCALING DU VISUEL (Le Decal + Les Pics + La fume)
		var scale_factor = final_radius / 6.0 # 6.0 est le radius de base de ton sort
		if ice_crash_effect != null:
			# a va scale TOUT ce qu'il y a dans Ice_crash_effect (pics, fume, decal)
			ice_crash_effect.scale = Vector3(scale_factor, scale_factor, scale_factor)
			
	# 4. DESTRUCTION AUTOMATIQUE DE SECOURS
	await get_tree().create_timer(duration_on_ground).timeout
	destroy_spell()
	
# --- NOUVELLE METHODE POUR LE DETRUIRE MANUELLEMENT ---
func destroy_spell() -> void:
	if is_instance_valid(self) and not is_queued_for_deletion():
		queue_free()
