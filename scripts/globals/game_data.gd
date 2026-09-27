class_name GameData
extends RefCounted

enum GameMode { WAVE, NORMAL }
static var current_game_mode: GameMode = GameMode.WAVE
static var current_seed: int = 50122

static var player_pseudos: Dictionary = {}
## Nombre de joueurs au lancement de la partie (fixé au début, ne change pas en cours de partie)
static var starting_player_count: int = 1

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

const FLOAT_STATS: Array[String] = [
	"mana_regen"
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

static func get_bases_by_type(target_type: ItemData.ItemType) -> Array[EquipmentItem]:
	var result: Array[EquipmentItem] = []
	for b in get_all_bases():
		if b != null and b.item_type == target_type:
			result.append(b)
	return result

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

# ==========================================================
# CONFIGURATION CENTRALE DES MONSTRES (Crédits & Poids de spawn)
# ==========================================================
## Table par défaut associant chaque scène ou nom de monstre à son coût en crédits et son poids
const DEFAULT_MONSTER_DATA: Dictionary = {
	"dumb.tscn": { "cost": 10, "weight": 1.2 },
	"dumb_archer.tscn": { "cost": 15, "weight": 1.0 },
	"scout.tscn": { "cost": 25, "weight": 0.7 },
	"spider_enemie.tscn": { "cost": 5, "weight": 1.2 },
	"creep.tscn": { "cost": 20, "weight": 0.2 },
	"ogre_boss.tscn": { "cost": 100, "weight": 1.0 }
}

## Récupère le dictionnaire de configuration d'un monstre
static func get_monster_entry(scene_or_identifier: Variant) -> Dictionary:
	var key_str: String = ""
	if scene_or_identifier is PackedScene:
		key_str = scene_or_identifier.resource_path.get_file().to_lower().trim_suffix(".remap")
	elif scene_or_identifier is String:
		key_str = scene_or_identifier.get_file().to_lower().trim_suffix(".remap")
	elif scene_or_identifier is Node:
		key_str = scene_or_identifier.name.to_lower()
		
	# 1. Correspondance exacte par nom de fichier
	if DEFAULT_MONSTER_DATA.has(key_str):
		return DEFAULT_MONSTER_DATA[key_str]
		
	# 2. Correspondance avec extension .tscn
	if not key_str.ends_with(".tscn") and DEFAULT_MONSTER_DATA.has(key_str + ".tscn"):
		return DEFAULT_MONSTER_DATA[key_str + ".tscn"]
		
	# 3. Détection par sous-chaîne
	var lower = key_str.to_lower()
	if "archer" in lower:
		return DEFAULT_MONSTER_DATA.get("dumb_archer.tscn", {})
	elif "scout" in lower:
		return DEFAULT_MONSTER_DATA.get("scout.tscn", {})
	elif "spider" in lower:
		return DEFAULT_MONSTER_DATA.get("spider_enemie.tscn", {})
	elif "creep" in lower:
		return DEFAULT_MONSTER_DATA.get("creep.tscn", {})
	elif "dumb" in lower or "orc" in lower:
		return DEFAULT_MONSTER_DATA.get("dumb.tscn", {})
	elif "ogre" in lower:
		return DEFAULT_MONSTER_DATA.get("ogre_boss.tscn", {})
		
	return {}

## Retourne le coût en crédits d'un monstre (défaut: default_cost)
static func get_monster_cost(scene_or_identifier: Variant, default_cost: int = 10) -> int:
	var entry = get_monster_entry(scene_or_identifier)
	if entry.has("cost"):
		return int(entry["cost"])
	return default_cost

## Retourne le poids relatif de spawn d'un monstre (défaut: default_weight)
static func get_monster_weight(scene_or_identifier: Variant, default_weight: float = 1.0) -> float:
	var entry = get_monster_entry(scene_or_identifier)
	if entry.has("weight"):
		return float(entry["weight"])
	return default_weight
