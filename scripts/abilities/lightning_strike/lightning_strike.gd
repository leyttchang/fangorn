extends Node3D

@export var duration_on_ground: float = 0.5

@onready var scaling_component = $SpellScalingComponent
@onready var collision = $AttackComponent/CollisionShape3D

func _ready() -> void:
	pass

func execute(caster: Node, target_data: Dictionary) -> void:
	# L'architecture (SkillBarComponent) a DÉJÀ calculé la position et l'a mise dans "impact_point"
	if target_data.has("impact_point"):
		global_position = target_data["impact_point"]
		print("⚡ Lightning Strike spawn at impact_point: ", global_position)
	elif target_data.has("target_position"):
		global_position = target_data["target_position"]
		print("⚡ Lightning Strike spawn at target_position: ", global_position)
	elif caster is Node3D:
		global_position = caster.global_position
		print("⚡ Lightning Strike spawn at caster position: ", global_position)
	
	# 1. On lance le calcul des stats (Dégâts, Radius, Knockback...)
	if scaling_component != null and scaling_component.has_method("on_execute"):
		scaling_component.on_execute(caster, target_data)
		
		# On récupère le rayon final
		var final_radius = scaling_component.final_impact_radius
		
		# 2. SCALING DE LA HITBOX
		if collision != null and (collision.shape is CylinderShape3D or collision.shape is SphereShape3D):
			collision.shape = collision.shape.duplicate()
			collision.shape.radius = final_radius
			print("⚡ Lightning Strike radius set to: ", final_radius)
			
	# 3. DESTRUCTION DE LA HITBOX UNIQUEMENT (pour éviter de faire des dégâts en boucle)
	# Le visuel (particules, decal) reste affiché jusqu'à ce que l'AnimationPlayer appelle disappear()
	await get_tree().create_timer(duration_on_ground).timeout
	if has_node("AttackComponent"):
		$AttackComponent.queue_free()

# NOUVEAU : Fonction à appeler depuis ton AnimationPlayer (via "Call Method Track")
# Mets cette clé à la toute fin de ton animation pour détruire la scène proprement.
func disappear() -> void:
	queue_free()
