class_name StatModifierData
extends Resource

enum ModType { FLAT, PERCENT }

@export_enum("max_health", "max_mana", "mana_regen", "armor", "flat_physical_damage", "flat_fire_damage", "flat_ice_damage", "flat_lightning_damage", "physical_damage", "magic_damage", "fire_damage", "ice_damage", "lightning_damage", "attack_speed", "cd_red", "area_of_effect", "movement_speed", "knockback_power", "knockback_resistance", "casting_speed", "xp_reward", "fire_resistance", "ice_resistance", "lightning_resistance", "action_speed", "damage_taken_multiplier") var stat_name: String = "max_health"
@export var value: float = 0.0
@export var mod_type: ModType = ModType.FLAT

func _init(_stat_name: String = "max_health", _value: float = 0.0, _mod_type: ModType = ModType.FLAT):
	stat_name = _stat_name
	value = _value
	mod_type = _mod_type
