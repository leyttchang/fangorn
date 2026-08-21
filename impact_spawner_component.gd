class_name ImpactSpawnerComponent
extends Node

@export var impact_scene: PackedScene 
@export var duration_on_ground: float = 4.0 
@export var destroy_parent_on_impact: bool = true

# Il a besoin de l'AttackComponent pour savoir quand on touche
@export var attack_component: AttackComponent
# Il a besoin du ScalingComponent pour connaître la taille calculée !
@export var scaling_component: SpellScalingComponent 

func _ready() -> void:
	if attack_component != null:
		attack_component.attack_landed.connect(_on_attack_landed)

func _on_attack_landed(_target: Node) -> void:
	if impact_scene != null:
		var impact_instance = impact_scene.instantiate()
		
		if impact_instance.has_method("setup"):
			# On récupère le rayon depuis notre autre composant
			var radius = 4.0
			if scaling_component != null:
				radius = scaling_component.final_impact_radius
				
			impact_instance.setup(radius, duration_on_ground) 
		
		# --- TRANSMISSION DE L'AUTORITE RESEAU ---
		# On passe l'identit du lanceur de la boule de feu au burning ground
		if attack_component != null and attack_component.has_meta("caster_authority"):
			var impact_attack_comp = impact_instance.get_node_or_null("AttackComponent")
			if impact_attack_comp == null:
				impact_attack_comp = impact_instance.find_child("AttackComponent*", true, false)
			if impact_attack_comp != null:
				impact_attack_comp.set_meta("caster_authority", attack_component.get_meta("caster_authority"))
				
		get_tree().root.add_child(impact_instance)
		impact_instance.global_position = _get_ground_position(get_parent().global_position)
		
		
	# On détruit le sort entier SEULEMENT si c'est demandé (utile pour les boules de feu, pas pour les éclairs)
	if destroy_parent_on_impact:
		get_parent().hide()
		await get_tree().create_timer(0.05).timeout
		get_parent().queue_free()

func _get_ground_position(current_pos: Vector3) -> Vector3:
	var parent3d = get_parent() as Node3D
	if not parent3d: return current_pos
	
	var space_state = parent3d.get_world_3d().direct_space_state
	var start_pos = current_pos + Vector3(0, 1.0, 0)
	var end_pos = start_pos + Vector3(0, -100.0, 0)
	
	var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	# On peut spécifier le masque de collision ici si on veut ignorer les monstres (ex: layer environnement)
	query.collision_mask = 1 
	
	var result = space_state.intersect_ray(query)
	if result:
		return result.position
	
	return current_pos
