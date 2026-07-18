class_name SpellScalingComponent
extends Node

@export var attack_component: AttackComponent
@export var base_impact_radius: float = 4.0
var final_impact_radius: float = 4.0 

func on_execute(caster: Node3D, target_data: Dictionary) -> void:
	
	# On récupère le .tres depuis le dictionnaire (injecté par la SkillBar)
	var ability_data = target_data.get("ability_data") as AbilityData
	
	var caster_stats = caster.find_child("StatsComponent", true, false)
	var equipment = caster.find_child("EquipmentComponent", true, false)
	
	if attack_component != null:
		var base_spell_damage = attack_component.damage
		var final_damage = base_spell_damage
		
		# ====================================================
		# 1. CALCUL DES DÉGÂTS SELON LA CATÉGORIE DU SORT
		# ====================================================
		if ability_data != null:
			if ability_data.category == AbilityData.AbilityCategory.WEAPON_ATTACK:
				# --- CAS A : ATTAQUE PHYSIQUE ---
				var weapon_damage = 0.0
				
				if equipment != null and equipment.equipped_items.has("main_hand"):
					var weapon = equipment.equipped_items["main_hand"]
					# CORRECTION : On cherche "base_damage" sur ton arme
					if weapon != null and "base_damage" in weapon: 
						weapon_damage = weapon.base_damage
				
				var phys_stat = 0.0
				if caster_stats != null:
					phys_stat = caster_stats.get_stat_value("physical_damage") 
					
				final_damage = (weapon_damage * ability_data.weapon_damage_multiplier) * phys_stat
				
			else:
				# --- CAS B : SORT MAGIQUE ---
				var magic_stat = 1.0
				if caster_stats != null:
					magic_stat = caster_stats.get_stat_value("magic_damage")
					if magic_stat == 0.0: 
						magic_stat = 1.0 
					
				final_damage = base_spell_damage * magic_stat
		
		# On applique les dégâts finaux à la Hitbox
		attack_component.damage = final_damage
		
		# ====================================================
		# 2. SCALING DU KNOCKBACK ET AOE
		# ====================================================
		if caster_stats != null:
			var kb_mult = caster_stats.get_stat_value("knockback_power")
			if kb_mult == 0.0: 
				kb_mult = 1.0
			attack_component.knockback_force *= kb_mult
			
			var aoe_mult = caster_stats.get_stat_value("area_of_effect")
			if aoe_mult == 0.0:
				aoe_mult = 1.0
			final_impact_radius = base_impact_radius * aoe_mult
