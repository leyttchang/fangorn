class_name BossArcaneField
extends Node3D

## Contrôleur du Champ d'Arcane du Boss Final (activé si au moins 1 Totem Arcane a été complété) :
## - Fait émerger régulièrement des Orbes d'Arcane (1 toutes les 5 à 10s, plafond de 6 simultanées) réparties dans toute l'arène
## - Respecte la géométrie réelle de l'arène (polygone Path3D de MarkerTreeSpawnerComponent + marge intérieure)
## - Évite d'apparaître collé au boss ou sur les joueurs afin que les orbes arrivent de toutes les directions (flancs, dos, profondeur)
## - Chaque orbe naît avec une vitesse initiale aléatoire (synchronisée réseau) et accélère lentement au fil du temps

const MAX_SPAWN_ATTEMPTS: int = 32
const MIN_FLARE_SEPARATION_SQ: float = 36.0

@export_category("Champ d'Arcane du Boss")

@export_group("Quantité & Cadence des Flares (Sliders)")
## Plafond simultané d'orbes actives dans l'arène (pour 1 totem Arcane)
@export_range(1, 20, 1) var max_active_flares: int = 6
## Intervalle minimal entre deux apparitions d'orbes (en secondes)
@export_range(1.0, 30.0, 0.5, "suffix:s") var spawn_interval_min: float = 5.0
## Intervalle maximal entre deux apparitions d'orbes (en secondes)
@export_range(1.0, 45.0, 0.5, "suffix:s") var spawn_interval_max: float = 10.0
## Délai avant la toute première orbe au début du combat (en secondes)
@export_range(0.5, 15.0, 0.25, "suffix:s") var initial_spawn_delay: float = 2.5
## Nombre d'orbes créées simultanément à chaque déclenchement
@export_range(1, 6, 1) var flares_per_salvo: int = 1
## Bonus multiplicatif de cadence par totem Arcane additionnel (ex: 0.45 = +45% de vitesse de spawn par totem en plus)
@export_range(0.0, 2.0, 0.05) var extra_totem_rate_bonus: float = 0.45
## Bonus au plafond max_active_flares par totem Arcane additionnel
@export_range(0, 10, 1) var extra_totem_max_flares_bonus: int = 2

@export_group("Zone d'Apparition dans l'Arène & Hauteur (Sliders)")
## Distance horizontale minimale vis-à-vis de tout joueur vivant pour lui laisser le temps de voir/casser l'orbe
@export_range(0.0, 40.0, 0.5, "suffix:m") var min_distance_from_player: float = 13.0
## Distance horizontale maximale vis-à-vis du joueur le plus proche (évite un spawn hors de vue au fond opposé de l'arène)
@export_range(20.0, 160.0, 1.0, "suffix:m") var max_distance_from_player: float = 68.0
## Rayon minimal d'apparition autour du boss (évite que les orbes n'apparaissent collées au boss devant le joueur)
@export_range(0.0, 40.0, 0.5, "suffix:m") var min_radius_around_boss: float = 10.0
## Rayon maximal d'apparition autour du boss à travers l'arène (en mètres)
@export_range(15.0, 150.0, 1.0, "suffix:m") var max_radius_around_boss: float = 115.0
## Poids d'échantillonnage uniforme sur l'emprise du polygone de l'arène (complété par un anneau 360° autour du combat)
@export_range(0.0, 1.0, 0.05) var arena_wide_sample_weight: float = 0.60
## Hauteur minimale au-dessus du sol à laquelle émerge une orbe (en mètres)
@export_range(0.3, 10.0, 0.1, "suffix:m") var spawn_height_min: float = 1.5
## Hauteur maximale au-dessus du sol à laquelle émerge une orbe (en mètres)
@export_range(0.5, 12.0, 0.1, "suffix:m") var spawn_height_max: float = 3.8
## Marge intérieure minimale vis-à-vis du mur d'arbres (Path3D) de l'arène (en mètres)
@export_range(0.0, 15.0, 0.5, "suffix:m") var arena_wall_margin: float = 4.5

@export_group("Stats & Vitesse des Orbes du Boss (Sliders)")
## Vitesse initiale minimale d'une orbe à son apparition (en m/s)
@export_range(0.5, 15.0, 0.1, "suffix:m/s") var flare_speed_min: float = 2.6
## Vitesse initiale maximale d'une orbe à son apparition (en m/s — certaines partent déjà plus vite que les monstres)
@export_range(0.5, 18.0, 0.1, "suffix:m/s") var flare_speed_max: float = 5.3
## Accélération progressive des orbes au fil du temps (en m/s²)
@export_range(0.0, 5.0, 0.05, "suffix:m/s²") var flare_acceleration: float = 0.35
## Vitesse maximale plafond des orbes après accélération (en m/s)
@export_range(1.0, 25.0, 0.01, "suffix:m/s") var flare_max_speed: float = 7.31
## Vitesse de braquage de base des orbes en vol (en rad/s)
@export_range(0.2, 12.0, 0.1, "suffix:rad/s") var flare_turn_speed: float = 2.6
## Dégâts d'arcane infligés au contact avec un joueur
@export_range(1.0, 200.0, 1.0) var flare_damage: float = 20.0
## Durée de vie maximale d'une orbe avant dissipation (en secondes)
@export_range(2.0, 60.0, 0.5, "suffix:s") var flare_lifetime: float = 25.0
## Force de recul appliquée au joueur touché
@export_range(0.0, 25.0, 0.5) var flare_knockback: float = 4.5

@export_group("Buff Direct sur le Boss & Scènes")
## Bonus de PV max accordé au Boss par totem Arcane complété (0.15 = +15% PV max / totem)
@export_range(0.0, 1.0, 0.05) var boss_hp_bonus_per_totem: float = 0.15
## Chemin de la scène ArcaneFlare chargée paresseusement via ResourceLoader
@export var flare_scene_path: String = "res://scripts/status_effects/arcane_enchant/arcane_flare.tscn"
## Chemin du VFX d'aura d'Arcane sur le Boss chargé paresseusement via ResourceLoader
@export var boss_aura_vfx_path: String = "res://scripts/status_effects/arcane_enchant/arcane_enchant_vfx.tscn"
## Override optionnel direct de la scène de flare
@export var custom_flare_scene: PackedScene = null
## Override optionnel direct de la scène d'aura du boss
@export var custom_boss_aura_vfx_scene: PackedScene = null
## Override optionnel du Path3D délimitant le périmètre de l'arène
@export var custom_arena_path: Path3D = null

var is_field_active: bool = false
var active_totem_stacks: int = 0

var _tracked_boss: Node3D = null
var _spawn_timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _boss_aura_instance: Node3D = null
var _active_flares: Array = []
var _next_flare_net_id: int = 0

var _cached_flare_scene: PackedScene = null
var _cached_boss_aura_scene: PackedScene = null
var _flare_missing_warned: bool = false

var _arena_polygon_2d: PackedVector2Array = PackedVector2Array()
var _arena_centroid_2d: Vector2 = Vector2.ZERO
var _arena_bounds_2d: Rect2 = Rect2()
var _arena_path_last_transform: Transform3D = Transform3D.IDENTITY
var _has_arena_path_transform: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_rng.randomize()


func _exit_tree() -> void:
	_clear_local_visuals_and_flares()


## Appelé par BossArena côté serveur/solo quand le boss spawn (ou si un totem Arcane est validé en cours de combat)
func activate_for_boss(boss: Node3D, totem_stacks: int) -> void:
	if boss == null or not is_instance_valid(boss) or totem_stacks <= 0:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	var was_active: bool = is_field_active
	_tracked_boss = boss
	active_totem_stacks = totem_stacks
	is_field_active = true
	if not was_active:
		_spawn_timer = maxf(0.5, initial_spawn_delay)

	_rebuild_arena_polygon()

	# Appliquer le buff de PV max sur le Boss par totem Arcane complété
	if boss_hp_bonus_per_totem > 0.0:
		var stats_comp: StatsComponent = boss.get_node_or_null("StatsComponent") as StatsComponent
		if stats_comp != null:
			var total_hp_bonus: float = boss_hp_bonus_per_totem * float(totem_stacks)
			stats_comp.set_or_update_modifier("max_health", StatModifierData.ModType.PERCENT, total_hp_bonus, "TOTEM_ARCANE_BOSS")

	# Activer l'aura d'arcane visuelle sur le Boss sur tous les pairs
	var boss_path: NodePath = boss.get_path()
	if multiplayer.has_multiplayer_peer():
		_rpc_start_field_client_state.rpc(boss_path, totem_stacks)
	else:
		_rpc_start_field_client_state(boss_path, totem_stacks)

	var i_min: float = minf(spawn_interval_min, spawn_interval_max) / _get_rate_multiplier()
	var i_max: float = maxf(spawn_interval_min, spawn_interval_max) / _get_rate_multiplier()
	print("[BossArcaneField] Champ d'Arcane activé dans l'arène de '%s' (totems arcane = %d, intervalle = %.1f..%.1fs, plafond = %d orbes, polygone = %d pts) !" % [
		boss.name,
		totem_stacks,
		i_min,
		i_max,
		_get_effective_max_flares(),
		_arena_polygon_2d.size()
	])


@rpc("authority", "call_local", "reliable")
func _rpc_start_field_client_state(boss_path: NodePath, totem_stacks: int) -> void:
	active_totem_stacks = totem_stacks
	is_field_active = true
	_resolve_and_attach_boss_aura(boss_path, 4)


func _resolve_and_attach_boss_aura(boss_path: NodePath, retries_left: int) -> void:
	if not is_field_active or not is_inside_tree():
		return
	var raw_boss: Node = get_node_or_null(boss_path)
	if raw_boss != null and is_instance_valid(raw_boss):
		var boss: Node3D = raw_boss as Node3D
		if boss != null:
			_tracked_boss = boss
			_attach_boss_arcane_aura(boss)
			return
	if retries_left > 0 and get_tree() != null:
		get_tree().process_frame.connect(func() -> void:
			_resolve_and_attach_boss_aura(boss_path, retries_left - 1)
		, CONNECT_ONE_SHOT)


func _attach_boss_arcane_aura(boss: Node3D) -> void:
	if _boss_aura_instance != null and is_instance_valid(_boss_aura_instance):
		return
	var aura_scene: PackedScene = _get_boss_aura_vfx_scene()
	if aura_scene == null:
		return
	var aura: Node3D = aura_scene.instantiate() as Node3D
	if aura == null:
		return
	_boss_aura_instance = aura
	# Attacher sur status_effect_componant si présent pour bénéficier de l'alignement sur le torse
	var status_comp: Node3D = boss.get_node_or_null("status_effect_componant") as Node3D
	if status_comp != null:
		status_comp.add_child(aura)
	else:
		boss.add_child(aura)
		aura.position = Vector3(0.0, 1.2, 0.0)
	aura.scale = Vector3.ONE * 1.65


## Stoppe immédiatement les apparitions, retire l'aura du boss et détruit toutes les flares actives (appelé à la mort du boss)
func stop_effect() -> void:
	if not is_field_active and _active_flares.is_empty():
		return
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			_rpc_stop_field.rpc()
	else:
		_rpc_stop_field()


## Alias de stop_effect() pour cohérence avec BossLightningStorm
func stop_field() -> void:
	stop_effect()


@rpc("authority", "call_local", "reliable")
func _rpc_stop_field() -> void:
	is_field_active = false
	_tracked_boss = null
	_clear_local_visuals_and_flares()


func _clear_local_visuals_and_flares() -> void:
	if _boss_aura_instance != null and is_instance_valid(_boss_aura_instance):
		_boss_aura_instance.queue_free()
	_boss_aura_instance = null

	var flares_to_pop: Array = _active_flares.duplicate()
	_active_flares.clear()
	for raw_flare: Variant in flares_to_pop:
		if raw_flare != null and is_instance_valid(raw_flare):
			var flare: Node3D = raw_flare as Node3D
			if flare != null and not flare.is_queued_for_deletion():
				if flare.has_method("pop_flare"):
					flare.call("pop_flare", false)
				else:
					flare.queue_free()


func _get_rate_multiplier() -> float:
	var stacks_extra: int = maxi(active_totem_stacks - 1, 0)
	return maxf(0.1, 1.0 + extra_totem_rate_bonus * float(stacks_extra))


func _roll_next_spawn_interval() -> float:
	var i_min: float = maxf(0.5, minf(spawn_interval_min, spawn_interval_max))
	var i_max: float = maxf(i_min, maxf(spawn_interval_min, spawn_interval_max))
	var base_wait: float = _rng.randf_range(i_min, i_max)
	return maxf(0.5, base_wait / _get_rate_multiplier())


func _roll_flare_initial_speed() -> float:
	var s_min: float = maxf(0.2, minf(flare_speed_min, flare_speed_max))
	var s_max: float = maxf(s_min, maxf(flare_speed_min, flare_speed_max))
	return _rng.randf_range(s_min, s_max)


func _get_effective_max_flares() -> int:
	var stacks_extra: int = maxi(active_totem_stacks - 1, 0)
	return maxi(1, max_active_flares + extra_totem_max_flares_bonus * stacks_extra)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_field_active:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	if _tracked_boss == null or not is_instance_valid(_tracked_boss) or _is_boss_dead(_tracked_boss):
		stop_effect()
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_cleanup_invalid_flares()
		var max_cap: int = _get_effective_max_flares()
		if _active_flares.size() >= max_cap:
			_spawn_timer = 1.0
			return

		_spawn_timer = _roll_next_spawn_interval()
		_spawn_flare_salvo(max_cap)


func _is_boss_dead(raw_boss: Variant) -> bool:
	if raw_boss == null or not is_instance_valid(raw_boss):
		return true
	var boss: Node3D = raw_boss as Node3D
	if boss == null or boss.is_queued_for_deletion():
		return true
	var hc: HealthComponent = boss.get_node_or_null("HealthComponent") as HealthComponent
	if hc != null and hc.current_health <= 0.0:
		return true
	if "current_state" in boss and "State" in boss:
		var state_enum: Variant = boss.get("State")
		if state_enum is Dictionary:
			var state_dict: Dictionary = state_enum as Dictionary
			if state_dict.has("DEAD") and boss.get("current_state") == state_dict["DEAD"]:
				return true
	return false


func _cleanup_invalid_flares() -> void:
	for i: int in range(_active_flares.size() - 1, -1, -1):
		var raw_fl: Variant = _active_flares[i]
		if raw_fl == null or not is_instance_valid(raw_fl):
			_active_flares.remove_at(i)
			continue
		var fl_node: Node = raw_fl as Node
		if fl_node == null or fl_node.is_queued_for_deletion() or fl_node.get("is_dead") == true:
			_active_flares.remove_at(i)


func _spawn_flare_salvo(max_cap: int) -> void:
	if _tracked_boss == null or not is_instance_valid(_tracked_boss):
		return
	if _get_flare_scene() == null:
		return

	_ensure_arena_polygon_up_to_date()

	var count: int = maxi(1, flares_per_salvo)
	var boss_pos: Vector3 = _tracked_boss.global_position

	for _i: int in range(count):
		_cleanup_invalid_flares()
		if _active_flares.size() >= max_cap:
			break
		var spawn_pos: Vector3 = _pick_flare_spawn_position(boss_pos)
		var initial_speed: float = _roll_flare_initial_speed()
		_next_flare_net_id += 1
		var net_id: int = _next_flare_net_id
		if multiplayer.has_multiplayer_peer():
			_rpc_spawn_arcane_flare.rpc(spawn_pos, net_id, initial_speed)
		else:
			_rpc_spawn_arcane_flare(spawn_pos, net_id, initial_speed)


@rpc("authority", "call_local", "reliable")
func _rpc_spawn_arcane_flare(spawn_pos: Vector3, flare_net_id: int, initial_speed: float = -1.0) -> void:
	if not is_field_active or get_tree() == null:
		return
	var flare_scene: PackedScene = _get_flare_scene()
	if flare_scene == null:
		return

	var flare: Node3D = flare_scene.instantiate() as Node3D
	if flare == null:
		return

	flare.name = "%s_ArcaneFlare_%d" % [name, flare_net_id]
	flare.set_multiplayer_authority(1)
	_active_flares.append(flare)
	var flare_ref: WeakRef = weakref(flare)
	var remove_cb := func() -> void:
		var resolved: Variant = flare_ref.get_ref()
		if resolved != null:
			_active_flares.erase(resolved)
		_cleanup_invalid_flares()
	if flare.has_signal("flare_popped"):
		flare.connect("flare_popped", remove_cb)
	flare.tree_exited.connect(remove_cb)

	var scene_root: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	scene_root.add_child(flare)
	flare.global_position = spawn_pos
	flare.reset_physics_interpolation()

	var resolved_speed: float = initial_speed if initial_speed > 0.0 else minf(flare_speed_min, flare_speed_max)
	if flare.has_method("setup_flare"):
		flare.call(
			"setup_flare",
			resolved_speed,
			flare_damage,
			flare_lifetime,
			flare_turn_speed,
			flare_knockback,
			flare_acceleration,
			flare_max_speed
		)


# --- Géométrie de l'arène (Path3D) & Sélection des positions de spawn dans toute l'arène ---

func _ensure_arena_polygon_up_to_date() -> void:
	var path_node: Path3D = _find_arena_path_3d()
	if path_node == null:
		return
	if _arena_polygon_2d.size() < 3 or not _has_arena_path_transform or not path_node.global_transform.is_equal_approx(_arena_path_last_transform):
		_rebuild_arena_polygon()


func _rebuild_arena_polygon() -> void:
	_arena_polygon_2d = PackedVector2Array()
	_arena_centroid_2d = Vector2.ZERO
	_arena_bounds_2d = Rect2()
	_has_arena_path_transform = false

	var path_node: Path3D = _find_arena_path_3d()
	if path_node == null or path_node.curve == null or path_node.curve.point_count < 3:
		return

	var curve: Curve3D = path_node.curve
	var sampled_local: PackedVector3Array = curve.tessellate(3, 6.0)
	if sampled_local.size() < 3:
		sampled_local = PackedVector3Array()
		for i: int in range(curve.point_count):
			sampled_local.append(curve.get_point_position(i))

	var poly: PackedVector2Array = PackedVector2Array()
	for local_pt: Vector3 in sampled_local:
		var world_pt: Vector3 = path_node.to_global(local_pt)
		var pt_2d: Vector2 = Vector2(world_pt.x, world_pt.z)
		if poly.is_empty() or poly[poly.size() - 1].distance_squared_to(pt_2d) > 0.0025:
			poly.append(pt_2d)

	if poly.size() >= 2 and poly[0].distance_squared_to(poly[poly.size() - 1]) <= 0.0025:
		poly.remove_at(poly.size() - 1)

	if poly.size() < 3:
		return

	_arena_polygon_2d = poly
	var sum: Vector2 = Vector2.ZERO
	var min_pt: Vector2 = _arena_polygon_2d[0]
	var max_pt: Vector2 = _arena_polygon_2d[0]
	for v: Vector2 in _arena_polygon_2d:
		sum += v
		min_pt.x = minf(min_pt.x, v.x)
		min_pt.y = minf(min_pt.y, v.y)
		max_pt.x = maxf(max_pt.x, v.x)
		max_pt.y = maxf(max_pt.y, v.y)
	_arena_centroid_2d = sum / float(_arena_polygon_2d.size())
	_arena_bounds_2d = Rect2(min_pt, max_pt - min_pt)
	_arena_path_last_transform = path_node.global_transform
	_has_arena_path_transform = true


func _find_arena_path_3d() -> Path3D:
	if custom_arena_path != null and is_instance_valid(custom_arena_path):
		return custom_arena_path

	var arena: Node = get_parent()
	if arena == null:
		return null

	var spawner: Node = arena.get_node_or_null("MarkerTreeSpawnerComponent")
	if spawner != null:
		var wp: Variant = spawner.get("wall_path_3d")
		if wp != null and wp is Object and is_instance_valid(wp) and wp is Path3D:
			var wp_path: Path3D = wp as Path3D
			if wp_path != null and wp_path.curve != null and wp_path.curve.point_count >= 3:
				return wp_path
		var direct_path: Path3D = spawner.get_node_or_null("Path3D") as Path3D
		if direct_path != null and direct_path.curve != null and direct_path.curve.point_count >= 3:
			return direct_path

	var descendants: Array[Node] = arena.find_children("*", "Path3D", true, false)
	for n: Node in descendants:
		if n == null or not is_instance_valid(n):
			continue
		var p3d: Path3D = n as Path3D
		if p3d != null and p3d.curve != null and p3d.curve.point_count >= 3:
			return p3d

	return null


func _is_point_valid_in_arena(pt_xz: Vector2) -> bool:
	var poly_size: int = _arena_polygon_2d.size()
	if poly_size < 3:
		return true
	if not Geometry2D.is_point_in_polygon(pt_xz, _arena_polygon_2d):
		return false
	if arena_wall_margin <= 0.0:
		return true

	var margin_sq: float = arena_wall_margin * arena_wall_margin
	for i: int in range(poly_size):
		var a: Vector2 = _arena_polygon_2d[i]
		var b: Vector2 = _arena_polygon_2d[(i + 1) % poly_size]
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(pt_xz, a, b)
		if pt_xz.distance_squared_to(closest) < margin_sq:
			return false
	return true


func _pick_flare_spawn_position(boss_pos: Vector3) -> Vector3:
	var min_boss_r: float = minf(min_radius_around_boss, maxf(0.5, max_radius_around_boss - 1.0))
	var max_boss_r: float = maxf(max_radius_around_boss, min_boss_r + 1.0)
	var min_boss_r_sq: float = min_boss_r * min_boss_r
	var max_boss_r_sq: float = max_boss_r * max_boss_r

	var boss_xz: Vector2 = Vector2(boss_pos.x, boss_pos.z)
	var player_positions: Array[Vector3] = _get_alive_player_positions()

	var min_pl_r: float = maxf(0.0, min_distance_from_player)
	var max_pl_r: float = maxf(min_pl_r + 6.0, max_distance_from_player)
	var min_player_dist_sq: float = min_pl_r * min_pl_r
	var max_player_dist_sq: float = max_pl_r * max_pl_r

	var has_poly: bool = _arena_polygon_2d.size() >= 3 and _arena_bounds_2d.size.x > 4.0 and _arena_bounds_2d.size.y > 4.0
	var chosen_xz: Vector2 = boss_xz
	var found_valid: bool = false

	for attempt: int in range(MAX_SPAWN_ATTEMPTS):
		var cand_xz: Vector2 = boss_xz
		var use_poly_box: bool = has_poly and attempt < 22 and _rng.randf() < arena_wide_sample_weight

		if use_poly_box:
			cand_xz = Vector2(
				_rng.randf_range(_arena_bounds_2d.position.x + arena_wall_margin, _arena_bounds_2d.end.x - arena_wall_margin),
				_rng.randf_range(_arena_bounds_2d.position.y + arena_wall_margin, _arena_bounds_2d.end.y - arena_wall_margin)
			)
		elif not player_positions.is_empty() and _rng.randf() < 0.68:
			# Anneau 360° autour d'un joueur vivant : fait surgir des orbes sur les flancs, dans le dos et en profondeur
			var anchor_pl: Vector3 = player_positions[_rng.randi_range(0, player_positions.size() - 1)]
			var angle_pl: float = _rng.randf_range(0.0, TAU)
			var r_pl_min: float = maxf(min_pl_r + 1.5, 14.0)
			var r_pl_max: float = maxf(r_pl_min + 2.0, max_pl_r)
			var r_pl: float = sqrt(_rng.randf_range(r_pl_min * r_pl_min, r_pl_max * r_pl_max))
			cand_xz = Vector2(anchor_pl.x + cos(angle_pl) * r_pl, anchor_pl.z + sin(angle_pl) * r_pl)
		else:
			# Grand anneau d'arène autour du boss
			var angle_b: float = _rng.randf_range(0.0, TAU)
			var ring_max: float = minf(max_boss_r, 78.0)
			var ring_min: float = minf(min_boss_r, maxf(1.0, ring_max - 2.0))
			var r_b: float = sqrt(_rng.randf_range(ring_min * ring_min, ring_max * ring_max))
			cand_xz = Vector2(boss_xz.x + cos(angle_b) * r_b, boss_xz.y + sin(angle_b) * r_b)

		if not _is_point_valid_in_arena(cand_xz):
			continue

		var d2_boss: float = boss_xz.distance_squared_to(cand_xz)
		if d2_boss < min_boss_r_sq or d2_boss > max_boss_r_sq:
			continue

		if not player_positions.is_empty():
			var d2_pl: float = _min_dist_sq_to_players_xz(cand_xz, player_positions)
			if min_player_dist_sq > 0.0 and d2_pl < min_player_dist_sq:
				continue
			if attempt < 26 and d2_pl > max_player_dist_sq:
				continue

		if attempt < 24 and not _is_far_from_active_flares_xz(cand_xz, MIN_FLARE_SEPARATION_SQ):
			continue

		chosen_xz = cand_xz
		found_valid = true
		break

	if not found_valid:
		chosen_xz = _pick_fallback_xz_in_arena(boss_xz, player_positions)

	var ground_y: float = _resolve_ground_y(chosen_xz.x, chosen_xz.y, boss_pos.y)
	var h_min: float = minf(spawn_height_min, spawn_height_max)
	var h_max: float = maxf(spawn_height_min, spawn_height_max)
	var float_height: float = _rng.randf_range(h_min, h_max)
	return Vector3(chosen_xz.x, ground_y + float_height, chosen_xz.y)


func _pick_fallback_xz_in_arena(boss_xz: Vector2, player_positions: Array[Vector3]) -> Vector2:
	var origin_xz: Vector2 = _arena_centroid_2d if _arena_polygon_2d.size() >= 3 else boss_xz
	if not player_positions.is_empty():
		var p0: Vector3 = player_positions[0]
		origin_xz = Vector2(p0.x, p0.z).lerp(origin_xz, 0.45)

	var base_angle: float = _rng.randf_range(0.0, TAU)
	var min_boss_sq: float = min_radius_around_boss * min_radius_around_boss
	var best_xz: Vector2 = origin_xz
	var best_score: float = -1.0
	var radii: Array[float] = [26.0, 38.0, 17.0]

	for r_cand: float in radii:
		for step: int in range(12):
			var angle: float = base_angle + float(step) * (TAU / 12.0)
			var cand: Vector2 = origin_xz + Vector2(cos(angle), sin(angle)) * r_cand
			if not _is_point_valid_in_arena(cand):
				continue
			if boss_xz.distance_squared_to(cand) < min_boss_sq * 0.65:
				continue
			var min_d2: float = _min_dist_sq_to_players_xz(cand, player_positions)
			if min_d2 > best_score:
				best_score = min_d2
				best_xz = cand
		if best_score >= min_distance_from_player * min_distance_from_player:
			return best_xz

	if best_score >= 0.0:
		return best_xz

	if _arena_polygon_2d.size() >= 3:
		return _arena_centroid_2d

	return boss_xz + Vector2(cos(base_angle), sin(base_angle)) * maxf(12.0, min_radius_around_boss)


func _get_alive_player_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	if get_tree() == null:
		return positions
	for p_node: Node in get_tree().get_nodes_in_group("Player"):
		if p_node == null or not is_instance_valid(p_node):
			continue
		var pl: Node3D = p_node as Node3D
		if pl == null or pl.is_queued_for_deletion():
			continue
		if _is_player_dead(pl):
			continue
		positions.append(pl.global_position)
	return positions


func _is_player_dead(pl: Node3D) -> bool:
	if pl.get("is_dead") == true:
		return true
	if pl.has_method("is_dead"):
		return pl.call("is_dead") == true
	var hc: HealthComponent = pl.get_node_or_null("HealthComponent") as HealthComponent
	if hc != null and hc.current_health <= 0.0:
		return true
	return false


func _min_dist_sq_to_players_xz(pt_xz: Vector2, player_positions: Array[Vector3]) -> float:
	if player_positions.is_empty():
		return INF
	var min_d2: float = INF
	for p_pos: Vector3 in player_positions:
		var dx: float = p_pos.x - pt_xz.x
		var dz: float = p_pos.z - pt_xz.y
		var d2: float = dx * dx + dz * dz
		if d2 < min_d2:
			min_d2 = d2
	return min_d2


func _is_far_from_active_flares_xz(pt_xz: Vector2, min_sep_sq: float) -> bool:
	for raw_fl: Variant in _active_flares:
		if raw_fl == null or not is_instance_valid(raw_fl):
			continue
		var fl: Node3D = raw_fl as Node3D
		if fl == null or fl.is_queued_for_deletion() or fl.get("is_dead") == true:
			continue
		var fp: Vector3 = fl.global_position
		var dx: float = fp.x - pt_xz.x
		var dz: float = fp.z - pt_xz.y
		if (dx * dx + dz * dz) < min_sep_sq:
			return false
	return true


func _resolve_ground_y(x: float, z: float, fallback_y: float) -> float:
	# 1. Raycast physique vers le sol (Layer 1 = "sol") pour épouser la collision réelle
	if is_inside_tree() and get_world_3d() != null:
		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		if space != null:
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
				Vector3(x, fallback_y + 40.0, z),
				Vector3(x, fallback_y - 45.0, z),
				1
			)
			q.collide_with_areas = false
			q.collide_with_bodies = true
			var hit: Dictionary = space.intersect_ray(q)
			if not hit.is_empty() and hit.has("position"):
				var hit_pos: Vector3 = hit["position"] as Vector3
				return hit_pos.y

	# 2. Via BossArena parent (_get_arena_ground_y)
	var arena: Node = get_parent()
	if arena != null and arena.has_method("_get_arena_ground_y"):
		var hy: float = float(arena.call("_get_arena_ground_y", x, z))
		if not is_nan(hy):
			return hy

	return fallback_y


# --- Chargement paresseux des scènes ---

func _get_flare_scene() -> PackedScene:
	if custom_flare_scene != null:
		return custom_flare_scene
	if _cached_flare_scene != null:
		return _cached_flare_scene
	if not flare_scene_path.is_empty() and ResourceLoader.exists(flare_scene_path):
		_cached_flare_scene = ResourceLoader.load(flare_scene_path) as PackedScene
	if _cached_flare_scene == null and not _flare_missing_warned:
		_flare_missing_warned = true
		push_warning("[BossArcaneField] Scène de flare introuvable : '%s'" % flare_scene_path)
	return _cached_flare_scene


func _get_boss_aura_vfx_scene() -> PackedScene:
	if custom_boss_aura_vfx_scene != null:
		return custom_boss_aura_vfx_scene
	if _cached_boss_aura_scene != null:
		return _cached_boss_aura_scene
	if not boss_aura_vfx_path.is_empty() and ResourceLoader.exists(boss_aura_vfx_path):
		_cached_boss_aura_scene = ResourceLoader.load(boss_aura_vfx_path) as PackedScene
	return _cached_boss_aura_scene
