class_name GameData
extends RefCounted

const PERCENT_STATS: Array[String] = [
	"attack_speed",
	"cd_red",
	"area_of_effect",
	"movement_speed",
	"casting_speed",
	"physical_damage",
	"magic_damage",
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
			preload("res://item/affixes/affix_cd_red.tres"),
			preload("res://item/affixes/affix_area_of_effect.tres"),
			preload("res://item/affixes/affix_knockback_resistance.tres"),
			preload("res://item/affixes/affix_casting_speed.tres"),
			preload("res://item/affixes/affix_max_mana.tres"),
			preload("res://item/affixes/affix_mana_regen.tres")
		]
	return _all_affixes
