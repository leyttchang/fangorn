class_name SpellScalingComponent
extends Node

@export var attack_component: AttackComponent
@export var base_impact_radius: float = 4.0

@export_group("Type de Competence")
enum SkillType { SPELL, ATTACK }
@export var skill_type: SkillType = SkillType.SPELL

@export_group("Tags Globaux")
## Si coche, le sort beneficie de la stat aoe_damage (en plus de magic_damage si SPELL)
@export var is_aoe: bool = false

@export_group("Weapon Scaling (Si ATTACK)")
## Utilise si le sort n'a pas d'AbilityData (1.0 = 100% des degats de l'arme)
@export var base_weapon_multiplier: float = 1.0

@export_group("Base Damage Split (%)")
@export_range(0.0, 1.0) var phys_ratio: float = 1.0
@export_range(0.0, 1.0) var fire_ratio: float = 0.0
@export_range(0.0, 1.0) var ice_ratio: float = 0.0
@export_range(0.0, 1.0) var lightning_ratio: float = 0.0

var final_impact_radius: float = 4.0 
var final_aoe_multiplier: float = 1.0

func on_execute(caster: Node3D, target_data: Dictionary) -> void:
	var ability_data = target_data.get("ability_data") as AbilityData
	var caster_stats = caster.find_child("StatsComponent", true, false)
	var equipment = caster.find_child("EquipmentComponent", true, false)
	
	if attack_component != null:
		var final_base = attack_component.base_damage
		
		# ====================================================
		# 1. GESTION DE L'ARME (Si c'est une Attaque)
		# ====================================================
		if skill_type == SkillType.ATTACK:
			var weapon_damage = 0.0
			if equipment != null and equipment.equipped_items.has("main_hand"):
				var weapon = equipment.equipped_items["main_hand"]
				if weapon != null and "base_damage" in weapon: 
					weapon_damage = weapon.base_damage
			
			var flat_phys_stat = 0.0
			if caster_stats != null:
				var stat = caster_stats.get_stat("flat_physical_damage")
				if stat != null: flat_phys_stat = stat.get_value()
				
			var mult = base_weapon_multiplier
			if ability_data != null:
				mult = ability_data.weapon_damage_multiplier
				
			final_base += (weapon_damage + flat_phys_stat) * mult
			
		# ====================================================
		# 2. CALCUL DES DEGATS (Systeme Additif)
		# ====================================================
		if caster_stats != null:
			# A. Recuperation des bonus globaux (Tags)
			var global_bonus = 0.0
			if skill_type == SkillType.SPELL:
				global_bonus += _get_stat_bonus(caster_stats, "magic_damage")
			if is_aoe:
				global_bonus += _get_stat_bonus(caster_stats, "aoe_damage")
			
			# B. Repartition sur les elements (On ajoute les bonus elementaires bruts, puis on remet la base 1.0)
			var physical_bonus = global_bonus + _get_stat_bonus(caster_stats, "physical_damage")
			attack_component.damage_physical = (final_base * phys_ratio) * (1.0 + physical_bonus)
			
			var fire_bonus = global_bonus + _get_stat_bonus(caster_stats, "fire_damage")
			attack_component.damage_fire = (final_base * fire_ratio) * (1.0 + fire_bonus)
			
			var ice_bonus = global_bonus + _get_stat_bonus(caster_stats, "ice_damage")
			attack_component.damage_ice = (final_base * ice_ratio) * (1.0 + ice_bonus)
			
			var lightning_bonus = global_bonus + _get_stat_bonus(caster_stats, "lightning_damage")
			attack_component.damage_lightning = (final_base * lightning_ratio) * (1.0 + lightning_bonus)
		else:
			# Sans stats, on divise juste la base
			attack_component.damage_physical = final_base * phys_ratio
			attack_component.damage_fire = final_base * fire_ratio
			attack_component.damage_ice = final_base * ice_ratio
			attack_component.damage_lightning = final_base * lightning_ratio
		
		# ====================================================
		# 3. SCALING DU KNOCKBACK
		# ====================================================
		if caster_stats != null:
			var kb_stat = caster_stats.get_stat("knockback_power")
			var kb_mult = 1.0
			if kb_stat != null:
				kb_mult = kb_stat.get_value()
			if kb_mult == 0.0: 
				kb_mult = 1.0
			attack_component.knockback_force *= kb_mult
	
	# ====================================================
	# 4. SCALING AOE (Taille visuelle/hitbox)
	# ====================================================
	if caster_stats != null:
		var aoe_stat = caster_stats.get_stat("area_of_effect")
		var aoe_mult = 1.0
		if aoe_stat != null:
			aoe_mult = aoe_stat.get_value()
		if aoe_mult == 0.0:
			aoe_mult = 1.0
		final_aoe_multiplier = aoe_mult
		final_impact_radius = base_impact_radius * aoe_mult


# --- NOUVELLE FONCTION ---
# Permet de faire la difference entre "La stat n'existe pas" et "La stat a ete reduite a 0 par des malus"
func _get_stat_bonus(stats_node: Node, stat_name: String) -> float:
	var stat = stats_node.get_stat(stat_name)
	if stat == null:
		# La stat n'a pas encore ete codee dans StatsComponent -> Pas de bonus, pas de malus
		return 0.0
	
	# La stat existe ! On soustrait 1.0 pour recuperer UNIQUEMENT le bonus
	# (Si des malus ont mis la valeur a 0.0, ca renverra bien 0.0 - 1.0 = -1.0)
	return stat.get_value() - 1.0
