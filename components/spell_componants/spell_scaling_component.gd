class_name SpellScalingComponent
extends Node

@export var attack_component: AttackComponent
@export var base_impact_radius: float = 4.0

@export_group("Weapon Scaling")
## Si coché, ajoute les dégâts de l'arme + le flat_physical_damage aux dégâts de base du sort.
@export var use_weapon_damage: bool = false
## Utilisé si le sort est passif ou n'a pas d'ability_data (1.0 = 100% des dégâts d'arme)
@export var base_weapon_multiplier: float = 1.0

@export_group("Damage Scaling Multipliers")
@export var scales_with_physical: bool = false
@export var scales_with_magic: bool = false
@export var scales_with_aoe_damage: bool = false
@export var scales_with_fire: bool = false
@export var scales_with_ice: bool = false
@export var scales_with_lightning: bool = false

var final_impact_radius: float = 4.0 
var final_aoe_multiplier: float = 1.0

func on_execute(caster: Node3D, target_data: Dictionary) -> void:
	
	# On récupère le .tres depuis le dictionnaire (injecté par la SkillBar)
	var ability_data = target_data.get("ability_data") as AbilityData
	
	var caster_stats = caster.find_child("StatsComponent", true, false)
	var equipment = caster.find_child("EquipmentComponent", true, false)
	
	if attack_component != null:
		var base_spell_damage = attack_component.damage
		var final_damage = base_spell_damage
		
		# ====================================================
		# 1. AJOUT DES DÉGÂTS D'ARME (Si coché)
		# ====================================================
		if use_weapon_damage:
			var weapon_damage = 0.0
			if equipment != null and equipment.equipped_items.has("main_hand"):
				var weapon = equipment.equipped_items["main_hand"]
				if weapon != null and "base_damage" in weapon: 
					weapon_damage = weapon.base_damage
			
			var flat_phys_stat = 0.0
			if caster_stats != null:
				flat_phys_stat = caster_stats.get_stat_value("flat_physical_damage")
				
			var mult = base_weapon_multiplier
			if ability_data != null:
				mult = ability_data.weapon_damage_multiplier
				
			# On additionne les dégâts de l'arme modifiés aux dégâts de base du sort
			final_damage += (weapon_damage + flat_phys_stat) * mult
			
		# ====================================================
		# 2. CALCUL PROPORTIONNEL DES ELEMENTS (CHUNKS)
		# ====================================================
		if caster_stats != null:
			var tags_count = 0
			if scales_with_physical: tags_count += 1
			if scales_with_magic: tags_count += 1
			if scales_with_aoe_damage: tags_count += 1
			if scales_with_fire: tags_count += 1
			if scales_with_ice: tags_count += 1
			if scales_with_lightning: tags_count += 1
			
			if tags_count > 0:
				var scaled_damage = 0.0
				var chunk_size = final_damage / float(tags_count)
				
				if scales_with_physical:
					scaled_damage += chunk_size * caster_stats.get_stat_value("physical_damage")
				if scales_with_magic:
					var magic_stat = caster_stats.get_stat_value("magic_damage")
					if magic_stat == 0.0: magic_stat = 1.0 
					scaled_damage += chunk_size * magic_stat
				if scales_with_aoe_damage:
					scaled_damage += chunk_size * caster_stats.get_stat_value("aoe_damage")
				if scales_with_fire:
					scaled_damage += chunk_size * caster_stats.get_stat_value("fire_damage")
				if scales_with_ice:
					scaled_damage += chunk_size * caster_stats.get_stat_value("ice_damage")
				if scales_with_lightning:
					scaled_damage += chunk_size * caster_stats.get_stat_value("lightning_damage")
					
				final_damage = scaled_damage
		
		# On applique les dégâts finaux à la Hitbox
		attack_component.damage = final_damage
		
		# ====================================================
		# 3. SCALING DU KNOCKBACK
		# ====================================================
		if caster_stats != null:
			var kb_mult = caster_stats.get_stat_value("knockback_power")
			if kb_mult == 0.0: 
				kb_mult = 1.0
			attack_component.knockback_force *= kb_mult
	
	# ====================================================
	# 4. SCALING AOE (Taille) Indépendant de l'AttackComponent
	# ====================================================
	if caster_stats != null:
		var aoe_mult = caster_stats.get_stat_value("area_of_effect")
		print("DEBUG SPELL SCALING: aoe_mult recupere = ", aoe_mult)
		if aoe_mult == 0.0:
			aoe_mult = 1.0
		final_aoe_multiplier = aoe_mult
		final_impact_radius = base_impact_radius * aoe_mult
	else:
		print("DEBUG SPELL SCALING: caster_stats est NULL pour ", caster.name)
