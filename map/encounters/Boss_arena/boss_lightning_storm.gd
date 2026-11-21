class_name BossLightningStorm
extends Node3D

## Contrôleur de la Tempête d'Éclairs du Boss Final (activée si au moins 1 Totem Foudre a été complété) :
## - Déclenche une tempête continue centrée autour de l'Ogre tant qu'il est en vie
## - Chaque éclair affiche d'abord un fin filet d'éclair pendant `telegraph_duration` (1.0s),
##   puis fait s'abattre le VFX de Lightning Strike avant que tous les effets ne disparaissent.

@export_category("Tempête d'Éclairs du Boss")

@export_group("Quantité d'Éclairs (Sliders)")
## Nombre d'éclairs (ou salves) qui tombent par seconde autour du boss
@export_range(0.2, 12.0, 0.1, "suffix:/s") var strikes_per_second: float = 2.2
## Nombre d'éclairs simultanés à chaque déclenchement
@export_range(1, 6, 1) var bolts_per_salvo: int = 1
## Bonus multiplicatif de fréquence par totem de foudre supplémentaire complété (ex: 0.65 = +65% pour un 2e totem)
@export_range(0.0, 2.0, 0.05) var extra_totem_rate_bonus: float = 0.65

@export_group("Zone autour de l'Ogre")
## Distance minimale autour du boss où la foudre peut tomber (en mètres)
@export_range(0.0, 25.0, 0.5, "suffix:m") var min_radius_around_boss: float = 2.5
## Rayon maximal de la tempête autour du boss (en mètres)
@export_range(4.0, 65.0, 0.5, "suffix:m") var max_radius_around_boss: float = 22.0
## Probabilité qu'un éclair tombe aux abords d'un joueur proche du boss (avec dispersion) pour maintenir la pression
@export_range(0.0, 1.0, 0.05) var player_focus_chance: float = 0.30

@export_group("Télégraphe & Dégâts")
## Durée du fin filet d'éclair d'avertissement avant que la foudre ne s'abatte (en secondes)
@export_range(0.2, 3.0, 0.05, "suffix:s") var telegraph_duration: float = 1.0
## Durée de dissipation rapide des effets après l'impact (en secondes)
@export_range(0.4, 2.5, 0.05, "suffix:s") var post_strike_duration: float = 0.85
## Dégâts de foudre infligés au joueur touché (réduits par sa lightning_resistance)
@export_range(1.0, 250.0, 1.0) var strike_damage: float = 28.0
## Rayon au sol de chaque impact d'éclair (en mètres)
@export_range(0.5, 6.0, 0.1, "suffix:m") var strike_radius: float = 1.6
## Force de projection appliquée au joueur touché
@export_range(0.0, 30.0, 0.5) var knockback_force: float = 10.0

@export_group("Buff Direct sur l'Ogre & Scènes")
## Bonus de PV max accordé à l'Ogre par totem de foudre complété (0.15 = +15% PV max / totem)
@export_range(0.0, 1.0, 0.05) var boss_hp_bonus_per_totem: float = 0.15
@export var storm_strike_scene: PackedScene = preload("res://map/encounters/Boss_arena/boss_storm_strike.tscn")
@export var boss_aura_vfx_scene: PackedScene = preload("res://scripts/status_effects/lightning_enchant/lightning_enchant_vfx.tscn")

var is_storm_active: bool = false
var active_totem_stacks: int = 0
var _tracked_boss: Node3D = null
var _spawn_timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _attack_proxy: AttackComponent
var _boss_aura_instance: Node3D = null
var _active_strikes: Array[BossStormStrike] = []

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_rng.randomize()
	_attack_proxy = AttackComponent.new()
	_attack_proxy.name = "BossStormAttackProxy"
	_attack_proxy.monitoring = false
	_attack_proxy.monitorable = false
	_attack_proxy.collision_layer = 0
	_attack_proxy.collision_mask = 0
	_attack_proxy.can_headshot = false
	_attack_proxy.ignore_caster = false
	add_child(_attack_proxy)
	_sync_attack_proxy()

func _sync_attack_proxy() -> void:
	if _attack_proxy == null:
		return
	_attack_proxy.base_damage = 0.0
	_attack_proxy.damage_physical = 0.0
	_attack_proxy.damage_lightning = strike_damage
	_attack_proxy.knockback_force = knockback_force
	_attack_proxy.knockback_angle = 18.0

## Appelé par BossArena côté serveur/solo quand le boss spawn (ou si un totem est validé en cours de route)
func activate_for_boss(boss: Node3D, totem_stacks: int) -> void:
	if boss == null or not is_instance_valid(boss) or totem_stacks <= 0:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	_tracked_boss = boss
	active_totem_stacks = totem_stacks
	is_storm_active = true
	_spawn_timer = 0.65

	# Appliquer le buff de stats sur l'Ogre (PV max par totem de foudre complété)
	if boss_hp_bonus_per_totem > 0.0:
		var stats_comp := boss.get_node_or_null("StatsComponent") as StatsComponent
		if stats_comp != null:
			var total_hp_bonus := boss_hp_bonus_per_totem * float(totem_stacks)
			stats_comp.set_or_update_modifier("max_health", StatModifierData.ModType.PERCENT, total_hp_bonus, "TOTEM_LIGHTNING_BOSS")

	# Activer l'aura électrique visuelle sur l'Ogre sur tous les pairs
	var boss_path := boss.get_path()
	if multiplayer.has_multiplayer_peer():
		_rpc_start_storm_client_state.rpc(boss_path, totem_stacks)
	else:
		_rpc_start_storm_client_state(boss_path, totem_stacks)

	print("[BossLightningStorm] Tempête d'éclairs activée autour de '%s' (totems foudre = %d, cadence = %.2f/s) !" % [
		boss.name, totem_stacks, _get_effective_rate()
	])

@rpc("authority", "call_local", "reliable")
func _rpc_start_storm_client_state(boss_path: NodePath, totem_stacks: int) -> void:
	active_totem_stacks = totem_stacks
	is_storm_active = true
	_resolve_and_attach_boss_aura(boss_path, 4)


func _resolve_and_attach_boss_aura(boss_path: NodePath, retries_left: int) -> void:
	if not is_storm_active or not is_inside_tree():
		return
	var boss := get_node_or_null(boss_path) as Node3D
	if boss != null and is_instance_valid(boss):
		_tracked_boss = boss
		_attach_boss_electric_aura(boss)
		return
	if retries_left > 0 and get_tree() != null:
		get_tree().process_frame.connect(func() -> void:
			_resolve_and_attach_boss_aura(boss_path, retries_left - 1)
		, CONNECT_ONE_SHOT)

func _attach_boss_electric_aura(boss: Node3D) -> void:
	if _boss_aura_instance != null and is_instance_valid(_boss_aura_instance):
		return
	if boss_aura_vfx_scene == null:
		return
	var aura := boss_aura_vfx_scene.instantiate() as Node3D
	if aura == null:
		return
	_boss_aura_instance = aura
	# Attacher sur status_effect_componant si présent pour bénéficier de l'alignement automatique sur le torse
	var status_comp := boss.get_node_or_null("status_effect_componant") as Node3D
	if status_comp != null:
		status_comp.add_child(aura)
	else:
		boss.add_child(aura)
		aura.position = Vector3(0.0, 1.2, 0.0)
	aura.scale = Vector3.ONE * 1.65

## Stoppe immédiatement la tempête (appelé à la mort de l'Ogre)
func stop_storm() -> void:
	if not is_storm_active:
		return
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_rpc_stop_storm.rpc()
	elif not multiplayer.has_multiplayer_peer():
		_rpc_stop_storm()

@rpc("authority", "call_local", "reliable")
func _rpc_stop_storm() -> void:
	is_storm_active = false
	_tracked_boss = null
	if _boss_aura_instance != null and is_instance_valid(_boss_aura_instance):
		_boss_aura_instance.queue_free()
	_boss_aura_instance = null

	for st: BossStormStrike in _active_strikes:
		if st != null and is_instance_valid(st):
			st.cancel_if_telegraphing()
	_active_strikes.clear()

func _get_effective_rate() -> float:
	var stacks_extra := maxi(active_totem_stacks - 1, 0)
	return maxf(0.1, strikes_per_second * (1.0 + extra_totem_rate_bonus * float(stacks_extra)))

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_storm_active:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	if _tracked_boss == null or not is_instance_valid(_tracked_boss) or _is_boss_dead(_tracked_boss):
		stop_storm()
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		var interval := 1.0 / _get_effective_rate()
		_spawn_timer = maxf(0.06, interval * _rng.randf_range(0.82, 1.18))
		_fire_storm_salvo()

func _is_boss_dead(boss: Node3D) -> bool:
	var hc := boss.get_node_or_null("HealthComponent") as HealthComponent
	if hc != null and hc.current_health <= 0.0:
		return true
	if "current_state" in boss and "State" in boss and "DEAD" in boss.State:
		if boss.current_state == boss.State.DEAD:
			return true
	return false

func _fire_storm_salvo() -> void:
	if _tracked_boss == null or storm_strike_scene == null:
		return

	var count := maxi(1, bolts_per_salvo)
	for _i in range(count):
		var impact_pos := _pick_strike_ground_position(_tracked_boss.global_position)
		if multiplayer.has_multiplayer_peer():
			_rpc_spawn_storm_strike.rpc(impact_pos)
		else:
			_rpc_spawn_storm_strike(impact_pos)

func _pick_strike_ground_position(boss_pos: Vector3) -> Vector3:
	var min_r := minf(min_radius_around_boss, max_radius_around_boss - 0.5)
	var max_r := maxf(max_radius_around_boss, min_r + 0.5)

	var target_xz := Vector2(boss_pos.x, boss_pos.z)
	var used_player_focus := false

	if _rng.randf() < player_focus_chance and get_tree() != null:
		var nearby_players: Array[Node3D] = []
		var max_focus_sq := (max_r * 1.35) * (max_r * 1.35)
		for p_node in get_tree().get_nodes_in_group("Player"):
			var pl := p_node as Node3D
			if pl == null or not is_instance_valid(pl):
				continue
			if pl.get("is_dead") == true or (pl.has_method("is_dead") and pl.is_dead()):
				continue
			var dx := pl.global_position.x - boss_pos.x
			var dz := pl.global_position.z - boss_pos.z
			if (dx * dx + dz * dz) <= max_focus_sq:
				nearby_players.append(pl)

		if not nearby_players.is_empty():
			var chosen: Node3D = nearby_players[_rng.randi_range(0, nearby_players.size() - 1)]
			var jitter_a := _rng.randf_range(0.0, TAU)
			var jitter_r := _rng.randf_range(0.8, 3.4)
			var px := chosen.global_position.x + cos(jitter_a) * jitter_r
			var pz := chosen.global_position.z + sin(jitter_a) * jitter_r
			# Garder l'éclair dans l'emprise max autour du boss
			var offset := Vector2(px - boss_pos.x, pz - boss_pos.z)
			if offset.length() > max_r:
				offset = offset.normalized() * max_r
			target_xz = Vector2(boss_pos.x, boss_pos.z) + offset
			used_player_focus = true

	if not used_player_focus:
		var angle := _rng.randf_range(0.0, TAU)
		var r := sqrt(_rng.randf_range(min_r * min_r, max_r * max_r))
		target_xz = Vector2(boss_pos.x + cos(angle) * r, boss_pos.z + sin(angle) * r)

	var ground_y := _resolve_ground_y(target_xz.x, target_xz.y, boss_pos.y)
	return Vector3(target_xz.x, ground_y, target_xz.y)

func _resolve_ground_y(x: float, z: float, fallback_y: float) -> float:
	# 1. Raycast physique vers le sol (Layer 1) pour épouser parfaitement la collision réelle
	if is_inside_tree() and get_world_3d() != null:
		var space := get_world_3d().direct_space_state
		if space != null:
			var q := PhysicsRayQueryParameters3D.create(
				Vector3(x, fallback_y + 40.0, z),
				Vector3(x, fallback_y - 45.0, z),
				1
			)
			q.collide_with_areas = false
			q.collide_with_bodies = true
			var hit := space.intersect_ray(q)
			if not hit.is_empty() and hit.has("position"):
				return (hit["position"] as Vector3).y

	# 2. Via BossArena parent
	var arena := get_parent()
	if arena != null and arena.has_method("_get_arena_ground_y"):
		var hy: float = float(arena.call("_get_arena_ground_y", x, z))
		if not is_nan(hy):
			return hy

	return fallback_y

@rpc("authority", "call_local", "reliable")
func _rpc_spawn_storm_strike(impact_pos: Vector3) -> void:
	if storm_strike_scene == null or get_tree() == null:
		return

	var strike := storm_strike_scene.instantiate() as BossStormStrike
	if strike == null:
		return

	var is_auth := (not multiplayer.has_multiplayer_peer() or multiplayer.is_server())
	var dmg_cb := Callable()
	if is_auth:
		dmg_cb = _apply_strike_damage_to_players

	strike.configure(telegraph_duration, strike_radius, dmg_cb, post_strike_duration)
	_active_strikes.append(strike)
	strike.tree_exited.connect(func() -> void:
		_active_strikes.erase(strike)
	)

	var scene_root: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	scene_root.add_child(strike)
	strike.global_position = impact_pos

func _apply_strike_damage_to_players(impact_pos: Vector3, radius: float, hit_dict: Dictionary) -> void:
	if _attack_proxy == null or get_tree() == null:
		return

	var effective_r_sq := (radius + 0.38) * (radius + 0.38)
	for p_node in get_tree().get_nodes_in_group("Player"):
		var player := p_node as Node3D
		if player == null or not is_instance_valid(player) or player.is_queued_for_deletion():
			continue
		if player.get("is_dead") == true or (player.has_method("is_dead") and player.is_dead()):
			continue

		var pid := player.get_instance_id()
		if hit_dict.has(pid):
			continue

		var p_pos := player.global_position
		var dx := p_pos.x - impact_pos.x
		var dz := p_pos.z - impact_pos.z
		var horiz_d2 := dx * dx + dz * dz
		var dy := p_pos.y - impact_pos.y

		# Colonne de foudre du sol jusqu'à +6m de haut
		if horiz_d2 <= effective_r_sq and dy >= -1.2 and dy <= 6.5:
			var hitbox := player.get_node_or_null("HitboxComponent") as HitboxComponent
			if hitbox == null:
				hitbox = player.find_child("HitboxComponent*", true, false) as HitboxComponent
			if hitbox != null and hitbox.has_method("receive_hit"):
				hit_dict[pid] = true
				_attack_proxy.global_position = impact_pos
				_sync_attack_proxy()
				hitbox.receive_hit(_attack_proxy)
