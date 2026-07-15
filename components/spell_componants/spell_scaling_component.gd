class_name SpellScalingComponent
extends Node

# On demande à Godot une case pour lier l'AttackComponent du sort
@export var attack_component: AttackComponent
@export var base_impact_radius: float = 4.0

var final_impact_radius: float = 4.0 

func on_execute(caster: Node3D, _target_data: Dictionary) -> void:
	var caster_stats = caster.find_child("StatsComponent", true, false)
	
	if caster_stats != null:
		if attack_component != null:
			# 1. Scaling des dégâts magiques (Ton code original)
			attack_component.damage *= caster_stats.get_stat_value("magic_damage")
			
			# 2. NOUVEAU : Scaling du Knockback
			var kb_mult = caster_stats.get_stat_value("knockback_power")
			if kb_mult == 0.0: # Sécurité au cas où la stat est mal lue ou vaut 0
				kb_mult = 1.0
			attack_component.knockback_force *= kb_mult
		
		# 3. Scaling de la zone d'effet (Ton code original)
		var aoe_mult = caster_stats.get_stat_value("area_of_effect")
		if aoe_mult == 0.0:
			aoe_mult = 1.0
			
		final_impact_radius = base_impact_radius * aoe_mult
