class_name GameData
extends RefCounted

static var player_pseudos: Dictionary = {}

const PERCENT_STATS: Array[String] = [
	"attack_speed",
	"cd_red",
	"area_of_effect",
	"movement_speed",
	"casting_speed",
	"physical_damage",
	"magic_damage",
	"fire_damage",
	"ice_damage",
	"lightning_damage",
	"knockback_power"
]

static var _all_affixes: Array[AffixData] = []

static func get_all_affixes() -> Array[AffixData]:
	if _all_affixes.is_empty():
		_all_affixes = [
			preload("res://item/affixes/affix_health.tres"),
			preload("res://item/affixes/affix_armor.tres"),
			preload("res://item/affixes/affix_attack_speed.tres"),
			preload("res://item/affixes/affix_movement_speed.tres"),
			preload("res://item/affixes/affix_physical_damage.tres"),
			preload("res://item/affixes/affix_magic_damage.tres"),
			preload("res://item/affixes/affix_fire_damage.tres"),
			preload("res://item/affixes/affix_ice_damage.tres"),
			preload("res://item/affixes/affix_lightning_damage.tres"),
			preload("res://item/affixes/affix_cd_red.tres"),
			preload("res://item/affixes/affix_area_of_effect.tres"),
			preload("res://item/affixes/affix_knockback_resistance.tres"),
			preload("res://item/affixes/affix_casting_speed.tres"),
			preload("res://item/affixes/affix_knockback_power.tres"),
			preload("res://item/affixes/affix_max_mana.tres"),
			preload("res://item/affixes/affix_mana_regen.tres")
		]
	return _all_affixes

static var _all_bases: Array[EquipmentItem] = []

static func get_all_bases() -> Array[EquipmentItem]:
	if _all_bases.is_empty():
		_all_bases = [
			preload("res://item/armes/test_sword_stats.tres"),
			preload("res://item/armes/test_axe.tres"),
			preload("res://item/armes/spear_test.tres"),
			preload("res://item/armes/starting_sword.tres"),
			#preload("res://item/armures/chest_armor.tres"),
			preload("res://item/armures/chest/heavy_armor.tres"),
			preload("res://item/armures/chest/hunter_chest_armor.tres"),
			preload("res://item/armures/feet/heavy_boots.tres"),
			preload("res://item/armures/feet/hunter_boots.tres"),
			preload("res://item/armures/head/heavy_helmet.tres"),
			preload("res://item/armures/head/hunter_helmet.tres"),
			preload("res://item/armures/legs/heavy_pants.tres"),
			preload("res://item/armures/legs/hunter_pants.tres"),
			preload("res://item/armures/gloves/heavy_gloves.tres"),
			preload("res://item/armures/gloves/hunter_gloves.tres")
		]
	return _all_bases

static var _all_spells: Array[AbilityData] = []

static func get_all_spells() -> Array[AbilityData]:
	if _all_spells.is_empty():
		_all_spells = [
			preload("res://scripts/abilities/fireball/Fireball.tres"),
			preload("res://scripts/abilities/dash/dash.tres"),
			preload("res://scripts/abilities/magic_shot/MagicShot.tres"),
			preload("res://scripts/abilities/Burning_ground/BurningGround.tres"),
			preload("res://scripts/abilities/Ice Crash/IceCrash.tres"),
			preload("res://scripts/abilities/light_pilar/light_pillar.tres"),
			preload("res://scripts/abilities/chain_lightning/chain_lightning.tres"),
			preload("res://scripts/abilities/ice_nova/IceNova.tres"),
			preload("res://scripts/abilities/lightning_strike/LightningStrike.tres"),
			preload("res://scripts/abilities/thunder_slash/thunder_slash.tres"),
			preload("res://scripts/abilities/flaming_stab/flaming_stab.tres"),
			preload("res://scripts/abilities/thunder_aspect/thunder_aspect.tres"),
			preload("res://scripts/abilities/Warcry/warcry_ability.tres"),
			preload("res://scripts/abilities/prismatic_blade/prismatic_blade.tres"),
		]
	return _all_spells
