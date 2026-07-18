extends Node3D

@export var duration_on_ground: float = 5.0

# On récupère directement les enfants grâce à ton architecture
@onready var scaling_component = $SpellScalingComponent
@onready var collision = $AttackComponent/CollisionShape3D
@onready var decal = $Ice_crash_effect/Decal

func _ready() -> void:
	pass


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
			
		# 3. SCALING DU VISUEL (Le Decal)
		if decal != null:
			decal.size = Vector3(final_radius * 2.0, decal.size.y, final_radius * 2.0)
			
	# 4. DESTRUCTION AUTOMATIQUE
	await get_tree().create_timer(duration_on_ground).timeout
	queue_free()
