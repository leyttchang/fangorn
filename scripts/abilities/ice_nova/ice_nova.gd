extends Node3D

@export var duration_on_ground: float = 0.5

@onready var scaling_component = $SpellScalingComponent
@onready var collision = $AttackComponent/CollisionShape3D

func _ready() -> void:
	# Solution ultime pour forcer toutes les particules One Shot à exploser au spawn
	for child in get_children():
		if child is GPUParticles3D:
			child.restart()

func execute(caster: Node, target_data: Dictionary) -> void:
	# Ice Nova est centré sur le lanceur
	if caster is Node3D:
		global_position = caster.global_position 
	
	# 1. On lance le calcul des stats (Dégâts, Radius, Knockback...)
	if scaling_component != null and scaling_component.has_method("on_execute"):
		scaling_component.on_execute(caster, target_data)
		
		# On récupère le rayon final
		var final_radius = scaling_component.final_impact_radius
		
		# 2. SCALING DE LA HITBOX
		if collision != null and (collision.shape is CylinderShape3D or collision.shape is SphereShape3D):
			collision.shape = collision.shape.duplicate()
			collision.shape.radius = final_radius
			
	# 3. DESTRUCTION DE LA HITBOX UNIQUEMENT (pour ne faire des dégâts qu'une seule fois)
	await get_tree().create_timer(duration_on_ground).timeout
	var attack_node = get_node_or_null("AttackComponent")
	if attack_node != null:
		attack_node.queue_free()

# NOUVEAU : Méthode à appeler depuis ton AnimationPlayer tout à la fin de l'animation
func disappear() -> void:
	queue_free()
