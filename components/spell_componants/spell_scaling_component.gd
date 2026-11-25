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
@export_range(0.0, 1.0) var magic_ratio: float = 0.0
@export_range(0.0, 1.0) var fire_ratio: float = 0.0
@export_range(0.0, 1.0) var ice_ratio: float = 0.0
@export_range(0.0, 1.0) var lightning_ratio: float = 0.0

var final_impact_radius: float = 4.0
var final_aoe_multiplier: float = 1.0
var final_spell_level: int = 1
var final_level_power_multiplier: float = 1.0


static func resolve_spell_level(caster: Node, ability_data: AbilityData, target_data: Dictionary) -> int:
	if target_data.has("spell_level"):
		return maxi(1, int(target_data["spell_level"]))
	if caster != null and ability_data != null:
		var sb: Node = caster.get_node_or_null("SpellBook_UI")
		if sb == null:
			sb = caster.find_child("SpellBook_UI", true, false)
		if sb != null and sb.has_method("get_spell_level"):
			return maxi(1, int(sb.call("get_spell_level", ability_data)))
	return 1


static func resolve_level_power_multiplier(caster: Node, ability_data: AbilityData, target_data: Dictionary) -> float:
	if ability_data == null:
		return 1.0
	var lvl: int = resolve_spell_level(caster, ability_data, target_data)
	return ability_data.get_level_power_multiplier(lvl)


func on_execute(caster: Node3D, target_data: Dictionary) -> void:
	var ability_data: AbilityData = target_data.get("ability_data") as AbilityData
	var caster_stats: Node = caster.find_child("StatsComponent", true, false) if caster != null else null
	var equipment: Node = caster.find_child("EquipmentComponent", true, false) if caster != null else null

	final_spell_level = resolve_spell_level(caster, ability_data, target_data)
	final_level_power_multiplier = ability_data.get_level_power_multiplier(final_spell_level) if ability_data != null else 1.0

	if attack_component != null:
		var final_base: float = attack_component.base_damage * final_level_power_multiplier

		# ====================================================
		# 1. GESTION DE L'ARME (Si c'est une Attaque)
		# ====================================================
		if skill_type == SkillType.ATTACK:
			var weapon_damage: float = 0.0
			if equipment != null and "equipped_items" in equipment:
				var eq_dict: Dictionary = equipment.get("equipped_items") as Dictionary
				if eq_dict.has("main_hand"):
					var weapon: Variant = eq_dict["main_hand"]
					if weapon is Object and "base_damage" in weapon:
						weapon_damage = float(weapon.get("base_damage"))

			var flat_phys_stat: float = 0.0
			if caster_stats != null and caster_stats.has_method("get_stat"):
				var stat: Object = caster_stats.call("get_stat", "flat_physical_damage") as Object
				if stat != null and stat.has_method("get_value"):
					flat_phys_stat = float(stat.call("get_value"))

			var mult: float = base_weapon_multiplier
			final_base += (weapon_damage + flat_phys_stat) * mult

		# ====================================================
		# 2. CALCUL DES DEGATS (Systeme Additif)
		# ====================================================
		if caster_stats != null:
			var global_bonus: float = 0.0
			if skill_type == SkillType.SPELL:
				global_bonus += _get_stat_bonus(caster_stats, "magic_damage")
			if is_aoe:
				global_bonus += _get_stat_bonus(caster_stats, "aoe_damage")

			var physical_bonus: float = global_bonus + _get_stat_bonus(caster_stats, "physical_damage")
			attack_component.damage_physical = (final_base * phys_ratio) * maxf(0.0, 1.0 + physical_bonus)

			var arcane_bonus: float = global_bonus + _get_stat_bonus(caster_stats, "arcane_damage")
			attack_component.damage_magic = (final_base * magic_ratio) * maxf(0.0, 1.0 + arcane_bonus)

			var fire_bonus: float = global_bonus + _get_stat_bonus(caster_stats, "fire_damage")
			attack_component.damage_fire = (final_base * fire_ratio) * maxf(0.0, 1.0 + fire_bonus)

			var ice_bonus: float = global_bonus + _get_stat_bonus(caster_stats, "ice_damage")
			attack_component.damage_ice = (final_base * ice_ratio) * maxf(0.0, 1.0 + ice_bonus)

			var lightning_bonus: float = global_bonus + _get_stat_bonus(caster_stats, "lightning_damage")
			attack_component.damage_lightning = (final_base * lightning_ratio) * maxf(0.0, 1.0 + lightning_bonus)
		else:
			attack_component.damage_physical = final_base * phys_ratio
			attack_component.damage_magic = final_base * magic_ratio
			attack_component.damage_fire = final_base * fire_ratio
			attack_component.damage_ice = final_base * ice_ratio
			attack_component.damage_lightning = final_base * lightning_ratio

		# ====================================================
		# 3. SCALING DU KNOCKBACK
		# ====================================================
		if caster_stats != null and caster_stats.has_method("get_stat"):
			var kb_stat: Object = caster_stats.call("get_stat", "knockback_power") as Object
			var kb_mult: float = 1.0
			if kb_stat != null and kb_stat.has_method("get_value"):
				kb_mult = float(kb_stat.call("get_value"))
			if kb_mult == 0.0:
				kb_mult = 1.0
			attack_component.knockback_force *= kb_mult

	# ====================================================
	# 4. SCALING AOE (Taille visuelle/hitbox)
	# ====================================================
	if caster_stats != null and caster_stats.has_method("get_stat"):
		var aoe_stat: Object = caster_stats.call("get_stat", "area_of_effect") as Object
		var aoe_mult: float = 1.0
		if aoe_stat != null and aoe_stat.has_method("get_value"):
			aoe_mult = float(aoe_stat.call("get_value"))
		if aoe_mult == 0.0:
			aoe_mult = 1.0
		final_aoe_multiplier = aoe_mult
		final_impact_radius = base_impact_radius * aoe_mult


func _get_stat_bonus(stats_node: Node, stat_name: String) -> float:
	if not stats_node.has_method("get_stat"):
		return 0.0
	var stat: Object = stats_node.call("get_stat", stat_name) as Object
	if stat == null or not stat.has_method("get_value"):
		return 0.0
	return float(stat.call("get_value")) - 1.0
