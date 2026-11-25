class_name LightningEnchantCoordinator
extends Node3D

## Coordinateur global léger auto-instancié par LightningEnchantEffectData :
## - Gère la liste de tous les monstres portant l'enchantement de foudre (Totem ou hors-Totem)
## - Toutes les X secondes, construit des chaînes propres (plus proche voisin non visité, façon Chain Lightning)
## - Synchronise les paires en multijoueur et inflige les dégâts de foudre aux joueurs traversant la décharge

const COORDINATOR_NODE_NAME := "LightningEnchantCoordinator"
const MAX_LINKS_PER_PULSE := 18

var effect_config: Resource
var _enchanted_mobs: Array[Node3D] = []
var _pulse_timer: float = 2.0
var _cycle_counter: int = 0
var _hit_players_cycle: Dictionary = {}
var _attack_proxy: AttackComponent
var _active_links_count: int = 0

static func get_or_create(tree: SceneTree, config_res: Resource) -> LightningEnchantCoordinator:
	if tree == null:
		return null
	var host_parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	var existing := host_parent.get_node_or_null(COORDINATOR_NODE_NAME) as LightningEnchantCoordinator
	if existing != null and is_instance_valid(existing):
		if config_res != null:
			existing.apply_config(config_res)
		return existing

	var coord := LightningEnchantCoordinator.new()
	coord.name = COORDINATOR_NODE_NAME
	coord.set_multiplayer_authority(1)
	if config_res != null:
		coord.apply_config(config_res)
	host_parent.add_child(coord)
	return coord

func _ready() -> void:
	_attack_proxy = AttackComponent.new()
	_attack_proxy.name = "LightningChainAttackProxy"
	_attack_proxy.monitoring = false
	_attack_proxy.monitorable = false
	_attack_proxy.collision_layer = 0
	_attack_proxy.collision_mask = 0
	_attack_proxy.can_headshot = false
	_attack_proxy.ignore_caster = false
	add_child(_attack_proxy)
	_sync_attack_proxy_stats()

func apply_config(config_res: Resource) -> void:
	effect_config = config_res
	_sync_attack_proxy_stats()

func _sync_attack_proxy_stats() -> void:
	if _attack_proxy == null or effect_config == null:
		return
	var dmg := float(effect_config.get("lightning_damage")) if "lightning_damage" in effect_config else 22.0
	var kb := float(effect_config.get("knockback_force")) if "knockback_force" in effect_config else 8.5
	_attack_proxy.base_damage = 0.0
	_attack_proxy.damage_physical = 0.0
	_attack_proxy.damage_lightning = dmg
	_attack_proxy.knockback_force = kb
	_attack_proxy.knockback_angle = 12.0

func register_mob(mob: Node3D) -> void:
	if mob == null or not is_instance_valid(mob):
		return
	set_process(true)
	if not _enchanted_mobs.has(mob):
		# Si c'est le tout premier monstre d'un nouveau groupe, on arme le premier pulse rapidement (~2.0s)
		if _enchanted_mobs.is_empty():
			var init_delay := float(effect_config.get("initial_pulse_delay")) if (effect_config != null and "initial_pulse_delay" in effect_config) else 2.0
			_pulse_timer = maxf(0.5, init_delay)
		_enchanted_mobs.append(mob)

func unregister_mob(mob: Node3D) -> void:
	_enchanted_mobs.erase(mob)

func _process(delta: float) -> void:
	_prune_dead_or_invalid_mobs()

	# Si plus aucun monstre enchanté et plus aucun arc en cours d'animation, on nettoie le coordinateur
	if _enchanted_mobs.is_empty():
		if get_child_count() <= 1 and _active_links_count <= 0:
			if multiplayer.has_multiplayer_peer():
				set_process(false)
			else:
				queue_free()
		return

	# Seul le serveur (ou le jeu solo) décide du timing et de la topologie des rebonds
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	_pulse_timer -= delta
	if _pulse_timer <= 0.0:
		var interval := float(effect_config.get("pulse_interval")) if (effect_config != null and "pulse_interval" in effect_config) else 4.5
		_pulse_timer = maxf(1.2, interval)
		_trigger_pulse_on_authority()

func _prune_dead_or_invalid_mobs() -> void:
	if _enchanted_mobs.is_empty():
		return
	for i in range(_enchanted_mobs.size() - 1, -1, -1):
		var m := _enchanted_mobs[i]
		if m == null or not is_instance_valid(m) or EnchantLightningLink._is_mob_invalid_or_dead(m):
			_enchanted_mobs.remove_at(i)

func _trigger_pulse_on_authority() -> void:
	if _enchanted_mobs.size() < 2:
		return

	var pairs := _build_chain_pairs(_enchanted_mobs)
	if pairs.is_empty():
		return

	var start_paths: Array[NodePath] = []
	var end_paths: Array[NodePath] = []
	for pair in pairs:
		var a := pair[0] as Node3D
		var b := pair[1] as Node3D
		if a != null and b != null and a.is_inside_tree() and b.is_inside_tree():
			start_paths.append(a.get_path())
			end_paths.append(b.get_path())

	if start_paths.is_empty():
		return

	if multiplayer.has_multiplayer_peer():
		_rpc_spawn_chain_links.rpc(start_paths, end_paths)
	else:
		_rpc_spawn_chain_links(start_paths, end_paths)

## Algorithme inspiré de chain_lightning.gd :
## Part d'un monstre périphérique non visité et rebondit de proche en proche vers le voisin
## non visité le plus proche dans bounce_radius, pour éviter les toiles d'araignée illisibles.
func _build_chain_pairs(mobs: Array[Node3D]) -> Array:
	var bounce_radius := float(effect_config.get("bounce_radius")) if (effect_config != null and "bounce_radius" in effect_config) else 22.0
	var max_bounces := int(effect_config.get("max_bounces_per_chain")) if (effect_config != null and "max_bounces_per_chain" in effect_config) else 6
	max_bounces = maxi(1, max_bounces)
	var max_dist_sq := bounce_radius * bounce_radius

	# Calcul du barycentre pour démarrer la chaîne depuis une extrémité du groupe
	var centroid := Vector3.ZERO
	for m in mobs:
		centroid += m.global_position
	centroid /= float(mobs.size())

	var sorted_mobs: Array[Node3D] = []
	sorted_mobs.assign(mobs)
	sorted_mobs.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(centroid) > b.global_position.distance_squared_to(centroid)
	)

	var visited: Array[Node3D] = []
	var pairs: Array = []

	for candidate: Node3D in sorted_mobs:
		if visited.has(candidate):
			continue

		# Vérifier que ce point de départ a au moins un voisin non visité à portée
		var first_next: Node3D = _find_nearest_unvisited(candidate, sorted_mobs, visited, max_dist_sq)
		if first_next == null:
			continue

		visited.append(candidate)
		var current: Node3D = candidate
		var bounces: int = 0

		while bounces < max_bounces and pairs.size() < MAX_LINKS_PER_PULSE:
			var next_mob: Node3D = _find_nearest_unvisited(current, sorted_mobs, visited, max_dist_sq)
			if next_mob == null:
				break
			pairs.append([current, next_mob])
			visited.append(next_mob)
			current = next_mob
			bounces += 1
		if pairs.size() >= MAX_LINKS_PER_PULSE:
			break

	return pairs

func _find_nearest_unvisited(from_mob: Node3D, candidates: Array[Node3D], visited: Array[Node3D], max_dist_sq: float) -> Node3D:
	var best: Node3D = null
	var best_d2 := max_dist_sq
	var origin := from_mob.global_position
	for c in candidates:
		if c == from_mob or visited.has(c):
			continue
		var d2 := origin.distance_squared_to(c.global_position)
		if d2 <= best_d2:
			best_d2 = d2
			best = c
	return best

@rpc("authority", "call_local", "reliable")
func _rpc_spawn_chain_links(start_paths: Array, end_paths: Array) -> void:
	if start_paths.size() != end_paths.size() or start_paths.is_empty():
		return

	_cycle_counter += 1
	var cycle_id := _cycle_counter
	_sync_attack_proxy_stats()

	# Nettoyage des anciens cycles dans le dictionnaire anti-double-hit
	_hit_players_cycle.clear()

	var is_auth := (not multiplayer.has_multiplayer_peer() or multiplayer.is_server())
	var cfg := _build_link_config_dict()
	var mat1: Material = effect_config.get("line_material_1") if (effect_config != null and "line_material_1" in effect_config) else null
	var mat2: Material = effect_config.get("line_material_2") if (effect_config != null and "line_material_2" in effect_config) else null
	var mat3: Material = effect_config.get("line_material_3") if (effect_config != null and "line_material_3" in effect_config) else null
	var smat: Material = effect_config.get("sphere_material") if (effect_config != null and "sphere_material" in effect_config) else null
	var spk: PackedScene = effect_config.get("strike_sparks_scene") if (effect_config != null and "strike_sparks_scene" in effect_config) else null

	var dmg_cb := Callable()
	if is_auth:
		dmg_cb = func(pos_a: Vector3, pos_b: Vector3) -> void:
			_check_segment_player_hits(pos_a, pos_b, cycle_id)

	var scene_root: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root

	for idx in range(start_paths.size()):
		var node_a := get_node_or_null(start_paths[idx] as NodePath) as Node3D
		var node_b := get_node_or_null(end_paths[idx] as NodePath) as Node3D
		if node_a == null or node_b == null:
			continue

		var link := EnchantLightningLink.new()
		link.setup(node_a, node_b, cfg, mat1, mat2, mat3, smat, spk, dmg_cb)
		_active_links_count += 1
		link.tree_exited.connect(func() -> void:
			_active_links_count = maxi(0, _active_links_count - 1)
		)
		scene_root.add_child(link)

func _build_link_config_dict() -> Dictionary:
	if effect_config == null:
		return {}
	return {
		"telegraph_duration": effect_config.get("telegraph_duration"),
		"strike_duration": effect_config.get("strike_duration"),
		"telegraph_thickness": effect_config.get("telegraph_thickness"),
		"strike_thickness": effect_config.get("strike_thickness"),
		"telegraph_spread": effect_config.get("telegraph_spread"),
		"strike_spread": effect_config.get("strike_spread"),
		"segments_count": effect_config.get("segments_count")
	}

func _check_segment_player_hits(pos_a: Vector3, pos_b: Vector3, cycle_id: int) -> void:
	if _attack_proxy == null or get_tree() == null:
		return

	var hit_radius := float(effect_config.get("strike_hit_radius")) if (effect_config != null and "strike_hit_radius" in effect_config) else 0.45
	var combined_radius := hit_radius + 0.45

	var players := get_tree().get_nodes_in_group("Player")
	for p_node in players:
		var player := p_node as Node3D
		if player == null or not is_instance_valid(player) or player.is_queued_for_deletion():
			continue
		if player.get("is_dead") == true or (player.has_method("is_dead") and player.is_dead()):
			continue

		var pid := player.get_instance_id()
		if _hit_players_cycle.get(pid, -1) == cycle_id:
			continue

		# Segment vertical de la capsule du joueur (pieds -> tête autour de global_position)
		var p_center := player.global_position
		var p_bottom := p_center - Vector3(0.0, 0.60, 0.0)
		var p_top := p_center + Vector3(0.0, 0.65, 0.0)

		var closest: PackedVector3Array = Geometry3D.get_closest_points_between_segments(pos_a, pos_b, p_bottom, p_top)
		if closest.size() < 2:
			continue

		var dist: float = closest[0].distance_to(closest[1])
		if dist <= combined_radius:
			var hitbox := player.get_node_or_null("HitboxComponent") as HitboxComponent
			if hitbox == null:
				hitbox = player.find_child("HitboxComponent*", true, false) as HitboxComponent
			if hitbox != null and hitbox.has_method("receive_hit"):
				_hit_players_cycle[pid] = cycle_id
				# Placer le proxy sur le point de contact de l'arc pour pousser le joueur perpendiculairement hors du fil
				_attack_proxy.global_position = closest[0]
				_sync_attack_proxy_stats()
				hitbox.receive_hit(_attack_proxy)
