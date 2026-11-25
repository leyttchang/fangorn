extends Node3D

@export var max_bounces: int = 5
@export var bounce_radius: float = 10.0
@export var line_duration: float = 0.5
@export var line_thickness: float = 0.1
@export var line_spread: float = 0.1 # L'écartement du triangle (réduit pour être plus proche)
@export var line_material_1: Material
@export var line_material_2: Material
@export var line_material_3: Material
@export var sphere_radius: float = 0.5
@export var sphere_material: Material
# Layer 4 (8 = HitboxEnemie) | Layer 9 (256 = enemie)
@export_flags_3d_physics var bounce_collision_mask: int = 8 | 256

static var _shared_bounce_sphere: SphereShape3D = null
static var _shared_bounce_params: PhysicsShapeQueryParameters3D = null

@onready var attack_component: AttackComponent = $AttackComponent
@onready var spell_scaling_component: SpellScalingComponent = $SpellScalingComponent

# This is called by the SkillBarComponent when the spell fires
func execute(caster: Node3D, target_data: Dictionary) -> void:
	if not target_data.has("collider") or target_data["collider"] == null:
		queue_free()
		return
		
	# Mettre à l'échelle les dégâts de l'AttackComponent et le nombre de rebonds
	if spell_scaling_component != null:
		spell_scaling_component.attack_component = attack_component
		spell_scaling_component.on_execute(caster, target_data)
		var old_bounces = max_bounces
		# On augmente le nombre de rebonds (en gardant un entier) basé sur la stat AoE du joueur
		max_bounces = int(round(max_bounces * spell_scaling_component.final_aoe_multiplier))
		
	var initial_target = target_data["collider"]
	var hit_targets: Array[Node3D] = []
	
	var start_node: Node3D = caster
	var main_gauche = caster.find_child("MainGauche", true, false)
	if main_gauche != null:
		start_node = main_gauche
		
	_process_bounce(initial_target, start_node, hit_targets)
	if not hit_targets.is_empty() and is_instance_valid(caster):
		var pitch_b: float = clampf(0.98 + float(mini(hit_targets.size(), 5)) * 0.02, 0.98, 1.08)
		SpellAudioManager.play_lightning_cast(caster, start_node.global_position, pitch_b, 0.0)
	# Le sort n'a plus besoin d'exister en tant que nœud, les lignes gèrent leur propre durée de vie
	queue_free()


func _process_bounce(current_target: Node3D, previous_target: Node3D, hit_targets: Array[Node3D]) -> void:
	# 1. Vérifier que c'est un ennemi (groupe "Enemie") et qu'il n'a pas déjà été touché
	if hit_targets.has(current_target) or not current_target.is_in_group("Enemie"):
		return
		
	# 2. Infliger les dégâts via la Hitbox
	var hitbox = current_target.get_node_or_null("HitboxComponent")
	# Chercher de manière récursive si pas trouvé directement
	if hitbox == null:
		hitbox = current_target.find_child("HitboxComponent", true, false)
		
	if hitbox != null and hitbox.has_method("receive_hit"):
		hit_targets.append(current_target)
		
		if attack_component.is_active_for_network:
			hitbox.receive_hit(attack_component)
		
		# 3. Dessiner la ligne du nœud précédent jusqu'à cet ennemi
		_draw_line(previous_target, current_target)
		
		# 4. Si on a atteint le max de rebonds, on s'arrête
		if hit_targets.size() >= max_bounces:
			return
			
		# 5. Chercher la prochaine cible avec intersect_shape (forme et paramètres partagés, masque ciblé ennemis)
		var target_pos = current_target.global_position
		var space_state = get_world_3d().direct_space_state
		if _shared_bounce_sphere == null:
			_shared_bounce_sphere = SphereShape3D.new()
			_shared_bounce_sphere.radius = bounce_radius
		elif not is_equal_approx(_shared_bounce_sphere.radius, bounce_radius):
			_shared_bounce_sphere.radius = bounce_radius

		if _shared_bounce_params == null:
			_shared_bounce_params = PhysicsShapeQueryParameters3D.new()
		_shared_bounce_params.shape = _shared_bounce_sphere
		_shared_bounce_params.transform = Transform3D(Basis(), target_pos)
		# Si la scène .tscn sérialisait l'ancien masque complet 0xFFFFFFFF, restreindre aux couches ennemies (8 | 256)
		_shared_bounce_params.collision_mask = (8 | 256) if bounce_collision_mask == 4294967295 else bounce_collision_mask
		# On exclut le collider actuel pour éviter de se trouver soi-même
		_shared_bounce_params.exclude = [current_target.get_rid()]

		var results = space_state.intersect_shape(_shared_bounce_params, 64)
		
		var nearest_enemy: Node3D = null
		var min_dist = bounce_radius + 1.0
		
		for result in results:
			var col = result["collider"]
			if col.is_in_group("Enemie") and not hit_targets.has(col):
				var dist = target_pos.distance_to(col.global_position)
				if dist < min_dist:
					min_dist = dist
					nearest_enemy = col
					
		# S'il y a un ennemi proche, on fait rebondir !
		if nearest_enemy != null:
			_process_bounce(nearest_enemy, current_target, hit_targets)


func _draw_line(p_start: Node3D, p_end: Node3D) -> void:
	# On instancie notre ligne et on l'ajoute directement à la racine de la scène 
	# pour qu'elle survive à la destruction du sort.
	var line = LightningLine.new()
	line.setup(p_start, p_end, line_duration, line_thickness, line_spread, line_material_1, line_material_2, line_material_3, sphere_radius, sphere_material)
	get_tree().root.add_child(line)
