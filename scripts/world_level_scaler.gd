class_name WorldLevelScaler
extends RefCounted

## Système centralisé d'iLvl et de Scaling des Monstres (Mode Exploration & Vagues) :
## - Monstres sauvages & cocons de la carte : iLvl 1 -> 5 selon l'éloignement au point de spawn du joueur
## - Camps d'Orcs & Camps PNJ : iLvl de leur zone +1 ou +2 (déterministe par seed & position)
## - Totems d'enchantement : toujours iLvl 6 à 8
## - Boss d'arène : toujours iLvl 10
## - Un monstre d'iLvl N reçoit exactement un Scaling Monstre de niveau N (PV, Dégâts, XP) et droppe des objets d'iLvl N.

const MIN_ZONE_ILVL: int = 1
const MAX_ZONE_ILVL: int = 5

const CAMP_BONUS_MIN: int = 1
const CAMP_BONUS_MAX: int = 2

const TOTEM_MIN_ILVL: int = 6
const TOTEM_MAX_ILVL: int = 8

const BOSS_ILVL: int = 10

const HP_BONUS_PER_LEVEL: float = 0.12
const DAMAGE_BONUS_PER_LEVEL: float = 0.08
const XP_BONUS_PER_LEVEL: float = 0.12
const MOD_SOURCE_ID: String = "monster_level_scaling"

static var _cached_map_gen: Node = null


static func find_map_generator(ctx: Node) -> Node:
	if _cached_map_gen != null and is_instance_valid(_cached_map_gen) and _cached_map_gen.is_inside_tree():
		return _cached_map_gen
	_cached_map_gen = null
	if ctx == null:
		return null

	var cur: Node = ctx
	while cur != null:
		if cur.has_method("get_spawn_point") and "path_generator" in cur:
			_cached_map_gen = cur
			return cur
		cur = cur.get_parent()

	var tree: SceneTree = ctx.get_tree()
	if tree != null and tree.root != null:
		var found: Node = tree.root.find_child("Map_generator", true, false)
		if found == null:
			for n: Node in tree.root.find_children("*", "Node3D", true, false):
				if n.has_method("get_spawn_point") and "path_generator" in n:
					found = n
					break
		_cached_map_gen = found
		return found
	return null


## Calcule l'iLvl de zone (1 à 5) selon l'éloignement horizontal par rapport au VRAI point de spawn du joueur.
static func get_zone_ilvl_at(ctx: Node, world_pos: Vector3) -> int:
	var pos_2d := Vector2(world_pos.x, world_pos.z)
	var map_gen: Node = find_map_generator(ctx)

	var spawn_2d := Vector2.ZERO
	var has_spawn: bool = false
	var map_w: float = 1024.0
	var map_h: float = 1024.0
	var b_margin: float = 40.0

	if map_gen != null:
		if "region_size" in map_gen and "map_width_chunks" in map_gen and "map_height_chunks" in map_gen:
			var rs: float = float(map_gen.get("region_size"))
			map_w = maxf(256.0, rs * float(map_gen.get("map_width_chunks")))
			map_h = maxf(256.0, rs * float(map_gen.get("map_height_chunks")))
		if "border_margin" in map_gen:
			b_margin = maxf(10.0, float(map_gen.get("border_margin")))
		var pg: Node = map_gen.get("path_generator") as Node
		if pg != null and "start_pos" in pg:
			var sp: Vector2 = pg.get("start_pos") as Vector2
			if sp != Vector2.ZERO:
				spawn_2d = sp
				has_spawn = true

	if not has_spawn and ctx != null and ctx.is_inside_tree():
		var tree: SceneTree = ctx.get_tree()
		if tree != null and tree.current_scene != null:
			var players_node: Node3D = tree.current_scene.get_node_or_null("Players") as Node3D
			if players_node != null and players_node.global_position != Vector3.ZERO:
				spawn_2d = Vector2(players_node.global_position.x, players_node.global_position.z)
				has_spawn = true

	if not has_spawn:
		# Repli standard : le spawn procédural est au Sud-Centre de la carte
		spawn_2d = Vector2(map_w * 0.5, map_h - (b_margin + 25.0))

	# Distance maximale praticable depuis le spawn jusqu'aux coins les plus éloignés de la carte
	var corners: Array[Vector2] = [
		Vector2(b_margin, b_margin),
		Vector2(map_w - b_margin, b_margin),
		Vector2(b_margin, map_h - b_margin),
		Vector2(map_w - b_margin, map_h - b_margin),
	]
	var max_corner_dist: float = 400.0
	for c: Vector2 in corners:
		max_corner_dist = maxf(max_corner_dist, spawn_2d.distance_to(c))

	# À ~85% de l'éloignement maximal (bord Nord / coins éloignés), on atteint pleinement l'iLvl 5
	var effective_span: float = maxf(250.0, max_corner_dist * 0.85)
	var dist: float = pos_2d.distance_to(spawn_2d)
	var ratio: float = clampf(dist / effective_span, 0.0, 0.9999)
	var zone_lvl: int = int(floor(ratio * float(MAX_ZONE_ILVL - MIN_ZONE_ILVL + 1))) + MIN_ZONE_ILVL
	return clampi(zone_lvl, MIN_ZONE_ILVL, MAX_ZONE_ILVL)


## Calcule de façon 100% déterministe l'iLvl d'un Camp Orc ou Camp PNJ : iLvl de sa zone (1..5) + 1 ou + 2.
static func get_camp_ilvl_at(ctx: Node, world_pos: Vector3, explicit_seed: int = 0) -> int:
	var zone_lvl: int = get_zone_ilvl_at(ctx, world_pos)
	var seed_val: int = _resolve_world_seed(ctx, explicit_seed)
	var qx: int = int(round(world_pos.x * 0.5))
	var qz: int = int(round(world_pos.z * 0.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_val, qx, qz, "camp_ilvl_bonus"])
	var bonus: int = rng.randi_range(CAMP_BONUS_MIN, CAMP_BONUS_MAX)
	return zone_lvl + bonus


## Calcule de façon 100% déterministe l'iLvl d'un Totem (toujours compris entre 6 et 8 inclus).
static func get_totem_ilvl_for_arena(seed_val: int, arena_name: String, is_hidden_totem: bool = false) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_val, arena_name, "totem_ilvl_6_8"])
	if is_hidden_totem:
		# Les totems cachés récompensent l'exploration hors-piste (7 ou 8, toujours dans [6..8])
		return rng.randi_range(7, TOTEM_MAX_ILVL)
	return rng.randi_range(TOTEM_MIN_ILVL, TOTEM_MAX_ILVL)


## Résout l'iLvl contextuel (Mode Vagues via SmartSpawner, sinon Zone 1..5 selon distance au spawn).
static func resolve_context_ilvl(ctx: Node, world_pos: Vector3) -> int:
	if ctx != null and ctx.is_inside_tree():
		var tree: SceneTree = ctx.get_tree()
		if tree != null:
			var spawners: Array[Node] = tree.get_nodes_in_group("SmartSpawner")
			if not spawners.is_empty():
				var sp: Node = spawners[0]
				if "current_effective_wave" in sp and int(sp.get("current_effective_wave")) > 0:
					return maxi(1, int(sp.get("current_effective_wave")))
				if "current_wave" in sp and int(sp.get("current_wave")) > 0:
					return maxi(1, int(float(int(sp.get("current_wave"))) / 1.5))
	return get_zone_ilvl_at(ctx, world_pos)


static func get_monster_level(mob: Node) -> int:
	if mob == null or not is_instance_valid(mob):
		return 1
	if mob.has_meta("monster_level"):
		return maxi(1, int(mob.get_meta("monster_level")))
	if "ilvl" in mob:
		return maxi(1, int(mob.get("ilvl")))
	return 1


static func get_damage_multiplier_for_level(level: int) -> float:
	var eff: int = maxi(1, level)
	return 1.0 + float(eff - 1) * DAMAGE_BONUS_PER_LEVEL


## Applique à un monstre le Scaling de Niveau N (PV, Dégâts mêlée/distance, XP) ET force son drop à iLvl N.
static func apply_level_to_monster(mob: Node, level: int) -> void:
	if mob == null or not is_instance_valid(mob):
		return
	var eff_lvl: int = maxi(1, level)
	mob.set_meta("monster_level", eff_lvl)
	if "ilvl" in mob:
		mob.set("ilvl", eff_lvl)

	if not mob.is_node_ready():
		if not mob.is_connected("ready", _on_deferred_mob_ready.bind(mob, eff_lvl)):
			mob.connect("ready", _on_deferred_mob_ready.bind(mob, eff_lvl), Object.CONNECT_ONE_SHOT)
		return

	_apply_level_components_now(mob, eff_lvl)


static func _on_deferred_mob_ready(mob: Node, eff_lvl: int) -> void:
	if mob != null and is_instance_valid(mob):
		_apply_level_components_now(mob, eff_lvl)


static func _apply_level_components_now(mob: Node, eff_lvl: int) -> void:
	# 1. Forcer l'iLvl exact des items droppés par ce monstre
	var loot_comp: LootDropComponent = mob.get_node_or_null("LootDropComponent") as LootDropComponent
	if loot_comp == null:
		loot_comp = mob.find_child("LootDropComponent*", true, false) as LootDropComponent
	if loot_comp != null:
		loot_comp.ilvl_override = eff_lvl

	# 2. Appliquer les modificateurs de StatsComponent (PV max, XP, et multiplicateurs de dégâts de sorts/projectiles)
	var stats: StatsComponent = mob.get_node_or_null("StatsComponent") as StatsComponent
	if stats == null:
		stats = mob.find_child("StatsComponent", true, false) as StatsComponent
	if stats != null:
		stats.remove_modifier_by_source(MOD_SOURCE_ID)
		stats.remove_modifier_by_source("wave_scaling")
		if eff_lvl > 1:
			var hp_bonus: float = float(eff_lvl - 1) * HP_BONUS_PER_LEVEL
			var dmg_bonus: float = float(eff_lvl - 1) * DAMAGE_BONUS_PER_LEVEL
			var xp_bonus: float = float(eff_lvl - 1) * XP_BONUS_PER_LEVEL
			stats.add_modifier("max_health", StatModifier.Type.PERCENT, hp_bonus, MOD_SOURCE_ID)
			stats.add_modifier("xp_reward", StatModifier.Type.PERCENT, xp_bonus, MOD_SOURCE_ID)
			stats.add_modifier("physical_damage", StatModifier.Type.PERCENT, dmg_bonus, MOD_SOURCE_ID)
			stats.add_modifier("magic_damage", StatModifier.Type.PERCENT, dmg_bonus, MOD_SOURCE_ID)
			stats.add_modifier("fire_damage", StatModifier.Type.PERCENT, dmg_bonus, MOD_SOURCE_ID)
			stats.add_modifier("ice_damage", StatModifier.Type.PERCENT, dmg_bonus, MOD_SOURCE_ID)
			stats.add_modifier("lightning_damage", StatModifier.Type.PERCENT, dmg_bonus, MOD_SOURCE_ID)

	# 3. Mettre à l'échelle tous les AttackComponent intégrés au corps du monstre (sans double application)
	var dmg_mult: float = get_damage_multiplier_for_level(eff_lvl)
	_scale_attack_components_in_subtree(mob, dmg_mult)


## Met à l'échelle une scène d'attaque externe instanciée par un monstre (ex: slam du Scout, racines du TreeMan, rocher/slam du Boss).
static func scale_spawned_attack(attack_root: Node, caster_mob: Node) -> void:
	if attack_root == null or not is_instance_valid(attack_root):
		return
	var lvl: int = get_monster_level(caster_mob)
	if lvl <= 1:
		return
	var dmg_mult: float = get_damage_multiplier_for_level(lvl)
	if not attack_root.is_node_ready():
		attack_root.connect("ready", _scale_attack_components_in_subtree.bind(attack_root, dmg_mult), Object.CONNECT_ONE_SHOT)
	else:
		_scale_attack_components_in_subtree(attack_root, dmg_mult)


static func _scale_attack_components_in_subtree(root_node: Node, dmg_mult: float) -> void:
	if root_node == null or not is_instance_valid(root_node):
		return
	var atks: Array[Node] = []
	if root_node is AttackComponent:
		atks.append(root_node)
	for ch: Node in root_node.find_children("*", "Area3D", true, false):
		if ch is AttackComponent:
			atks.append(ch)

	for node_item: Node in atks:
		var atk: AttackComponent = node_item as AttackComponent
		if atk == null:
			continue
		# Si un SpellScalingComponent pilote déjà cet AttackComponent (ex: fire_arrow), StatsComponent le scale déjà
		var parent_n: Node = atk.get_parent()
		if parent_n != null and parent_n.find_child("SpellScalingComponent*", false, false) != null:
			continue

		var orig_base: float = float(atk.get_meta("orig_base_damage", atk.base_damage))
		atk.set_meta("orig_base_damage", orig_base)
		atk.base_damage = orig_base * dmg_mult
		atk.damage_physical = orig_base * dmg_mult


static func _resolve_world_seed(ctx: Node, explicit_seed: int = 0) -> int:
	if explicit_seed != 0:
		return explicit_seed
	if not Engine.is_editor_hint() and GameData.current_seed != 0:
		return GameData.current_seed
	var mg: Node = find_map_generator(ctx)
	if mg != null and "world_seed" in mg:
		return int(mg.get("world_seed"))
	return 1
