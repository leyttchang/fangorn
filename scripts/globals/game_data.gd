class_name GameData
extends RefCounted

enum GameMode { WAVE, NORMAL }
static var current_game_mode: GameMode = GameMode.WAVE
static var current_seed: int = 50122

static var player_pseudos: Dictionary = {}
## Nombre de joueurs au lancement de la partie (fixé au début, ne change pas en cours de partie)
static var starting_player_count: int = 1

## Compteur des totems élémentaires complétés durant la run actuelle (ex: {"lightning": 1, "arcane": 1})
static var completed_totems: Dictionary = {}

static func reset_completed_totems() -> void:
	completed_totems.clear()

static func register_completed_totem(element: String, tree: SceneTree = null) -> int:
	var key := element.strip_edges().to_lower()
	if key.is_empty():
		return 0
	var new_count: int = int(completed_totems.get(key, 0)) + 1
	completed_totems[key] = new_count
	print("[GameData] Totem complété enregistré : '%s' (total pour cet élément = %d)" % [key, new_count])
	if tree != null:
		for arena in tree.get_nodes_in_group("BossArena"):
			if is_instance_valid(arena) and arena.has_method("on_totem_completed_in_world"):
				arena.on_totem_completed_in_world(key, new_count)
	return new_count

static func get_completed_totem_count(element: String) -> int:
	return int(completed_totems.get(element.strip_edges().to_lower(), 0))

static func get_completed_totems_list() -> Array[String]:
	var result: Array[String] = []
	for k in completed_totems.keys():
		var cnt: int = int(completed_totems[k])
		for _i in range(cnt):
			result.append(str(k))
	return result

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

const ALL_SPELL_PATHS: Array[String] = [
	# --- TIER I SPELLS ---
	"res://scripts/abilities/ember_bolt/EmberBolt.tres",
	"res://scripts/abilities/cinder_trail/CinderTrail.tres",
	"res://scripts/abilities/creeping_roots/CreepingRoots.tres",
	"res://scripts/abilities/kinetic_bolt/KineticBolt.tres",
	"res://scripts/abilities/glacial_shell/GlacialShell.tres",
	"res://scripts/abilities/frost_pulse/FrostPulse.tres",
	"res://scripts/abilities/crackling_arc/CracklingArc.tres",
	"res://scripts/abilities/spark_step/SparkStep.tres",
	# --- TIER II SPELLS (Evolutions & Rare Drops) ---
	"res://scripts/abilities/fireball/Fireball.tres",
	"res://scripts/abilities/dragons_breath/DragonsBreath.tres",
	"res://scripts/abilities/Burning_ground/BurningGround.tres",
	"res://scripts/abilities/blazing_stride/BlazingStride.tres",
	"res://scripts/abilities/immolation_aura/ImmolationAura.tres",
	"res://scripts/abilities/living_bomb/LivingBomb.tres",
	"res://scripts/abilities/grasping_briars/GraspingBriars.tres",
	"res://scripts/abilities/sylvan_grapple/SylvanGrapple.tres",
	"res://scripts/abilities/singularity_orb/SingularityOrb.tres",
	"res://scripts/abilities/glacial_ram/GlacialRam.tres",
	"res://scripts/abilities/frostmirror_aegis/FrostmirrorAegis.tres",
	"res://scripts/abilities/ice_nova/IceNova.tres",
	"res://scripts/abilities/ice_spikes/IceSpikes.tres",
	"res://scripts/abilities/ice_path/IcePath.tres",
	"res://scripts/abilities/chain_lightning/chain_lightning.tres",
	"res://scripts/abilities/lodestone_beam/LodestoneBeam.tres",
	"res://scripts/abilities/living_lightning/LivingLightning.tres",
	"res://scripts/abilities/stormwire/Stormwire.tres",
	"res://scripts/abilities/lightning_strike/LightningStrike.tres",
	# --- UTILITY & MARTIAL ATTACKS ---
	"res://scripts/abilities/dash/dash.tres",
	"res://scripts/abilities/Ice Crash/IceCrash.tres",
	"res://scripts/abilities/thunder_slash/thunder_slash.tres",
	"res://scripts/abilities/flaming_stab/flaming_stab.tres",
	"res://scripts/abilities/thunder_aspect/thunder_aspect.tres",
	"res://scripts/abilities/Warcry/warcry_ability.tres",
	"res://scripts/abilities/prismatic_blade/prismatic_blade.tres",
	"res://scripts/abilities/leap_slam/leap_slam.tres",
	"res://scripts/abilities/cleave/cleave.tres",
]

static var _all_spells: Array[AbilityData] = []

static func get_all_spells() -> Array[AbilityData]:
	if _all_spells.is_empty():
		for path: String in ALL_SPELL_PATHS:
			if ResourceLoader.exists(path):
				var ab: AbilityData = load(path) as AbilityData
				if ab != null:
					_all_spells.append(ab)
	return _all_spells


## Retourne les compétences éligibles aux Stèles et récompenses aléatoires :
## - Exclut toujours les sorts d'évolution pure (`is_evolution_only == true`), débloqués via le niveau max du sort parent.
## - Inclut les compétences de base (Tier I + Attaques) et, avec une faible probabilité (`rare_drop_chance`), les sorts Tier II `[Rare Drop]`.
static func get_droppable_skills(rare_drop_chance: float = 0.14) -> Array[AbilityData]:
	var base_pool: Array[AbilityData] = []
	var rare_pool: Array[AbilityData] = []
	for ab: AbilityData in get_all_spells():
		if ab == null or ab.is_evolution_only:
			continue
		if ab.is_rare_drop:
			rare_pool.append(ab)
		else:
			base_pool.append(ab)

	if not rare_pool.is_empty() and randf() < rare_drop_chance:
		base_pool.append_array(rare_pool)
	return base_pool


static func get_all_non_evolution_skills() -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	for ab: AbilityData in get_all_spells():
		if ab != null and not ab.is_evolution_only:
			result.append(ab)
	return result

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
	"tree_man.tscn": { "cost": 35, "weight": 0.5 },
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
	elif "tree_man" in lower or "treeman" in lower:
		return DEFAULT_MONSTER_DATA.get("tree_man.tscn", {})
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
