@tool
class_name MobRaycastSpawner
extends Node3D


## Signals emitted during monster lifecycle
signal mob_spawned(mob: Node3D)
signal all_mobs_spawned(mobs: Array[Node3D])
signal mob_died(mob: Node3D, remaining_alive: int)
signal all_mobs_defeated

@export_category("Monster Configuration")
## List of candidate monster scenes to spawn (e.g. dumb.tscn, dumb_archer.tscn, scout.tscn, spider_enemie.tscn)
@export var monster_scenes: Array[PackedScene] = []
## Monster costs corresponding to monster_scenes index. Default fallback is 10.
@export var monster_costs: Array[int] = [10, 15, 25, 8]
## Monster spawn weights corresponding to monster_scenes index. Default fallback is 1.0.
@export var monster_weights: Array[float] = [1.5, 1.0, 0.7, 1.2]

@export_category("Credit System & Scaling")
## Encounter level / Camp item level (scales credits available for spawning)
@export var encounter_level: int = 1
## Base credits at level 1 for 1 player
@export var base_credits: int = 40
## Credits added per level above level 1
@export var credits_per_level: int = 15
## Extra multiplier per additional player (e.g. 0.5 = +50% credits per extra player: 1p = x1.0, 2p = x1.5, 3p = x2.0)
@export var player_multiplier: float = 0.5

@export_category("Spawn Area (Circle)")
## Maximum spawn radius in meters
@export_range(1.0, 100.0, 0.5) var spawn_radius: float = 15.0:
	set(val):
		spawn_radius = maxf(val, min_spawn_radius + 0.5)
		if Engine.is_editor_hint():
			_update_debug_mesh()

## Minimum spawn radius in meters (avoids spawning on the NPC or cage at center)
@export_range(0.0, 50.0, 0.5) var min_spawn_radius: float = 2.0:
	set(val):
		min_spawn_radius = clampf(val, 0.0, spawn_radius - 0.5)
		if Engine.is_editor_hint():
			_update_debug_mesh()

@export_category("Raycast & Ground")
## Height above spawner where raycast starts
@export var ray_height_above: float = 30.0
## Depth below spawner where raycast searches for ground
@export var ray_depth_below: float = 50.0
## Collision mask for ground physics (Layer 1 by default)
@export_flags_3d_physics var ground_collision_mask: int = 1
## Vertical offset above hit point (3 meters above ground raycast impact)
@export var spawn_height_offset: float = 3.0
## Maximum raycast attempts per monster if ray hits empty space
@export var max_attempts_per_mob: int = 15

@export_category("Monster Facing")
enum FacingMode {
	LOOK_AWAY_FROM_CENTER, ## Face outward (zone defense / patrol)
	LOOK_AT_CENTER,        ## Face center (watching cage / NPC)
	RANDOM,                ## Random 360 degree angle
	KEEP_SCENE_ROTATION    ## Keep default scene rotation
}
@export var facing_mode: FacingMode = FacingMode.LOOK_AWAY_FROM_CENTER

@export_category("Trigger & Containers")
## Automatically spawn monsters on ready
@export var spawn_on_ready: bool = false
## Clear old monsters from this spawner before spawning new ones
@export var clear_previous_before_spawn: bool = true
## Parent node to store spawned monsters (leave empty to child under this spawner)
@export var mobs_container: Node3D

@export_category("Aggro & Pack Behavior")
## If enabled, all monsters aggro simultaneously when a player enters the camp zone
@export var zone_aggro_enabled: bool = true
## Detection zone radius around camp center in meters
@export_range(1.0, 100.0, 0.5) var zone_aggro_radius: float = 28.0:
	set(val):
		zone_aggro_radius = val
		if Engine.is_editor_hint():
			_update_debug_mesh()
## If enabled, when any mob detects or takes damage from a player, the whole pack is alerted
@export var aggro_link: bool = true
## Extended combat pursuit range so far away mobs don't drop aggro
@export var combat_aggro_radius: float = 50.0

@export_category("Actions (Inspector)")
## Check this box to trigger spawn immediately in editor or in game
@export var trigger_spawn_now: bool = false:
	set(val):
		trigger_spawn_now = false
		if is_inside_tree():
			spawn_mobs()

## Check this box to clear all instantiated monsters
@export var clear_mobs_now: bool = false:
	set(val):
		clear_mobs_now = false
		clear_mobs()

## Show debug radius circles in editor
@export var show_debug_circle: bool = true:
	set(val):
		show_debug_circle = val
		if Engine.is_editor_hint():
			_update_debug_mesh()

var alive_mobs: Array[Node3D] = []
var _is_spawning: bool = false
var _scan_timer: float = 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		_update_debug_mesh()
		return
		
	# In-game: hide debug mesh
	_remove_debug_mesh()
	
	if spawn_on_ready:
		call_deferred("spawn_mobs")

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if alive_mobs.is_empty():
		return

	_scan_timer += delta
	if _scan_timer < 0.15:
		return
	_scan_timer = 0.0

	# 1. Pack Mind: Check if any alive monster already has a valid target
	if aggro_link:
		var active_target: Node3D = null
		for mob in alive_mobs:
			if not is_instance_valid(mob):
				continue
			if "target" in mob and mob.target != null and is_instance_valid(mob.target):
				var is_dead_target = false
				if mob.target.has_method("is_dead") and mob.target.is_dead():
					is_dead_target = true
				elif mob.target.get("is_dead") == true:
					is_dead_target = true
				if not is_dead_target:
					active_target = mob.target
					break
		if active_target != null:
			alert_all_mobs(active_target)
			return

	# 2. Zone Aggro: Detect if a player enters the camp area
	if zone_aggro_enabled:
		var players = get_tree().get_nodes_in_group("Player")
		var my_pos = global_position
		var zone_sq = zone_aggro_radius * zone_aggro_radius
		for p in players:
			if not is_instance_valid(p):
				continue
			if p.has_method("is_dead") and p.is_dead():
				continue
			if p.get("is_dead") == true:
				continue
			var d_sq = my_pos.distance_squared_to(p.global_position)
			if d_sq <= zone_sq:
				alert_all_mobs(p)
				break

## Triggers spawning of all monsters for this encounter using the credit system
func spawn_mobs() -> Array[Node3D]:
	if _is_spawning:
		return []
	_is_spawning = true
	
	# Multiplayer check: only server or singleplayer client spawns monsters
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_is_spawning = false
		return []
		
	var valid_scenes: Array[PackedScene] = []
	for scn in monster_scenes:
		if scn != null:
			valid_scenes.append(scn)
			
	if valid_scenes.is_empty():
		push_warning("MobRaycastSpawner (" + name + ") : No monster scenes configured in 'monster_scenes'!")
		_is_spawning = false
		return []
		
	if clear_previous_before_spawn:
		clear_mobs()
		
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var total_credits = _calculate_total_credits()
	var credits_left = total_credits
	var spawned: Array[Node3D] = []
	var target_container = mobs_container if mobs_container != null else self
	
	var consecutive_failures = 0
	const MAX_CONSECUTIVE_FAILURES = 10
	
	while credits_left > 0:
		var affordable = _get_affordable_monsters(credits_left)
		if affordable.is_empty():
			break
			
		var chosen_entry = _pick_weighted_random(affordable, rng)
		var chosen_scene: PackedScene = chosen_entry.get("scene") as PackedScene
		var cost: int = chosen_entry.get("cost", 10)
		
		if chosen_scene == null:
			break
			
		var ground_info = _find_valid_ground_position(rng)
		if not ground_info.success:
			consecutive_failures += 1
			push_warning("MobRaycastSpawner (" + name + ") : Ground raycast failed (attempt " + str(consecutive_failures) + ").")
			if consecutive_failures >= MAX_CONSECUTIVE_FAILURES:
				push_error("MobRaycastSpawner (" + name + ") : Aborting spawn loop after multiple consecutive raycast failures.")
				break
			continue
			
		consecutive_failures = 0
		
		var mob_instance = chosen_scene.instantiate() as Node3D
		if mob_instance == null:
			continue
			
		target_container.add_child(mob_instance)
		mob_instance.global_position = ground_info.position
		
		_apply_facing(mob_instance, rng)
		_track_mob(mob_instance)
		
		spawned.append(mob_instance)
		credits_left -= cost
		mob_spawned.emit(mob_instance)
		
	_is_spawning = false
	all_mobs_spawned.emit(spawned)
	print("MobRaycastSpawner (", name, ") : ", spawned.size(), " mobs spawned (credits spent: ", total_credits - credits_left, "/", total_credits, ", level: ", encounter_level, ").")
	
	return spawned

## Removes all currently alive monsters instantiated by this spawner
func clear_mobs() -> void:
	for mob in alive_mobs:
		if is_instance_valid(mob) and not mob.is_queued_for_deletion():
			mob.queue_free()
	alive_mobs.clear()

## Returns current list of alive monsters
func get_alive_mobs() -> Array[Node3D]:
	var valid_list: Array[Node3D] = []
	for m in alive_mobs:
		if is_instance_valid(m) and not m.is_queued_for_deletion():
			valid_list.append(m)
	alive_mobs = valid_list
	return alive_mobs

## Returns remaining alive monsters count
func get_alive_mobs_count() -> int:
	return get_alive_mobs().size()

# =========================================================================
# INTERNAL CALCULATIONS (Credits, Selection, Raycast, Facing, Tracking)
# =========================================================================

func _get_player_count() -> int:
	var count = 0
	if is_inside_tree():
		var players = get_tree().get_nodes_in_group("Player")
		for p in players:
			if is_instance_valid(p) and not p.is_queued_for_deletion():
				count += 1
		if count == 0 and multiplayer.has_multiplayer_peer():
			count = multiplayer.get_peers().size() + 1
	return maxi(count, 1)

func _calculate_total_credits() -> int:
	var raw_credits = base_credits + (maxi(encounter_level, 1) - 1) * credits_per_level
	var player_count = _get_player_count()
	var multi_multiplier = 1.0 + float(maxi(player_count - 1, 0)) * player_multiplier
	return maxi(int(float(raw_credits) * multi_multiplier), 1)

func _get_affordable_monsters(credits_left: int) -> Array[Dictionary]:
	var affordable: Array[Dictionary] = []
	for i in range(monster_scenes.size()):
		var scn = monster_scenes[i]
		if scn == null:
			continue
			
		var cost = 10
		if i < monster_costs.size():
			cost = monster_costs[i]
			
		var weight = 1.0
		if i < monster_weights.size():
			weight = monster_weights[i]
			
		if cost <= credits_left and weight > 0.0:
			affordable.append({"scene": scn, "cost": cost, "weight": weight})
	return affordable

func _pick_weighted_random(options: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	if options.is_empty():
		return {}
	var total_weight: float = 0.0
	for opt in options:
		total_weight += float(opt.get("weight", 1.0))
		
	if total_weight <= 0.0:
		return options[0]
		
	var random_val: float = rng.randf() * total_weight
	var current_weight: float = 0.0
	
	for opt in options:
		current_weight += float(opt.get("weight", 1.0))
		if random_val <= current_weight:
			return opt
			
	return options.back()

func _find_valid_ground_position(rng: RandomNumberGenerator) -> Dictionary:
	var space_state = get_world_3d().direct_space_state
	if space_state == null:
		return {"success": false, "position": Vector3.ZERO}
		
	var min_r_sq = min_spawn_radius * min_spawn_radius
	var max_r_sq = spawn_radius * spawn_radius
	if max_r_sq < min_r_sq:
		max_r_sq = min_r_sq
		
	for attempt in range(max_attempts_per_mob):
		var angle = rng.randf_range(0.0, TAU)
		# Distribution radiale uniforme dans l'anneau
		var r = sqrt(rng.randf_range(min_r_sq, max_r_sq))
		var offset_x = cos(angle) * r
		var offset_z = sin(angle) * r
		
		var ray_origin = global_position + Vector3(offset_x, ray_height_above, offset_z)
		var ray_target = global_position + Vector3(offset_x, -ray_depth_below, offset_z)
		
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_target, ground_collision_mask)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		
		var result = space_state.intersect_ray(query)
		if not result.is_empty():
			var hit_pos = result.position + Vector3(0.0, spawn_height_offset, 0.0)
			return {"success": true, "position": hit_pos, "normal": result.normal}
			
	return {"success": false, "position": Vector3.ZERO}

func _apply_facing(mob: Node3D, rng: RandomNumberGenerator) -> void:
	match facing_mode:
		FacingMode.LOOK_AWAY_FROM_CENTER:
			var dir = mob.global_position - global_position
			dir.y = 0.0
			if dir.length_squared() > 0.01:
				mob.look_at(mob.global_position + dir.normalized(), Vector3.UP)
		FacingMode.LOOK_AT_CENTER:
			var center_at_mob_height = Vector3(global_position.x, mob.global_position.y, global_position.z)
			if (center_at_mob_height - mob.global_position).length_squared() > 0.01:
				mob.look_at(center_at_mob_height, Vector3.UP)
		FacingMode.RANDOM:
			mob.rotation.y = rng.randf_range(0.0, TAU)
		FacingMode.KEEP_SCENE_ROTATION:
			pass

func _track_mob(mob: Node3D) -> void:
	alive_mobs.append(mob)
	
	# Find HealthComponent on the monster
	var health_comp: HealthComponent = mob.get_node_or_null("HealthComponent") as HealthComponent
	if health_comp == null:
		health_comp = mob.find_child("HealthComponent", true, false) as HealthComponent
		
	if health_comp != null:
		health_comp.died.connect(_on_mob_died.bind(mob))
		
	# Fallback if node is freed directly without emitting died
	mob.tree_exiting.connect(_on_mob_tree_exiting.bind(mob))

	# Listen for aggro if monster is hit from a distance
	var hitbox = mob.find_child("HitboxComponent*", true, false)
	if hitbox != null and hitbox.has_signal("aggro_requested"):
		hitbox.aggro_requested.connect(_on_mob_aggro_requested)

func _on_mob_aggro_requested(attacker: Node3D) -> void:
	if aggro_link and attacker != null and is_instance_valid(attacker):
		alert_all_mobs(attacker)

## Instantly alerts all camp monsters and directs them towards the target player
func alert_all_mobs(target_player: Node3D) -> void:
	if target_player == null or not is_instance_valid(target_player):
		return
	if target_player.has_method("is_dead") and target_player.is_dead():
		return
	if target_player.get("is_dead") == true:
		return

	for mob in alive_mobs:
		if not is_instance_valid(mob) or mob.is_queued_for_deletion():
			continue
		
		# Extend chase range of EnemyNavigationComponent
		var nav_comp = mob.get_node_or_null("EnemyNavigationComponent") as EnemyNavigationComponent
		if nav_comp == null:
			nav_comp = mob.find_child("EnemyNavigationComponent", true, false) as EnemyNavigationComponent
		if nav_comp != null:
			nav_comp.detection_range_override = combat_aggro_radius
			nav_comp.lose_aggro_override = combat_aggro_radius

		# Assign target if monster doesn't have one or current target is dead/invalid
		if "target" in mob:
			var needs_target = false
			if mob.target == null or not is_instance_valid(mob.target):
				needs_target = true
			elif mob.target.has_method("is_dead") and mob.target.is_dead():
				needs_target = true
			elif mob.target.get("is_dead") == true:
				needs_target = true
				
			if needs_target:
				mob.target = target_player
				if mob.has_method("change_state"):
					var chase_state = 1
					if "State" in mob and "CHASE" in mob.State:
						chase_state = mob.State.CHASE
					mob.change_state(chase_state)

func _on_mob_died(mob: Node3D) -> void:
	if mob in alive_mobs:
		alive_mobs.erase(mob)
		var remaining = get_alive_mobs_count()
		mob_died.emit(mob, remaining)
		print("MobRaycastSpawner (", name, ") : Mob defeated! Remaining alive: ", remaining)
		if remaining == 0:
			all_mobs_defeated.emit.call_deferred()
			print("MobRaycastSpawner (", name, ") : >>> ALL MOBS DEFEATED! <<<")

func _on_mob_tree_exiting(mob: Node3D) -> void:
	if mob in alive_mobs:
		alive_mobs.erase(mob)
		var remaining = get_alive_mobs_count()
		mob_died.emit(mob, remaining)
		if remaining == 0:
			all_mobs_defeated.emit.call_deferred()

# =========================================================================
# GIZMO / DEBUG IN GODOT EDITOR
# =========================================================================

func _update_debug_mesh() -> void:
	if not Engine.is_editor_hint():
		return
		
	var existing = get_node_or_null("_DebugCircleVisual")
	if not show_debug_circle:
		if existing:
			existing.queue_free()
		return
		
	var mesh_inst: MeshInstance3D = existing as MeshInstance3D
	if mesh_inst == null:
		mesh_inst = MeshInstance3D.new()
		mesh_inst.name = "_DebugCircleVisual"
		add_child(mesh_inst)
		
	var imm = ImmediateMesh.new()
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.45, 0.1, 0.85) # Bright orange
	
	var segments = 48
	# 1. Outer spawn circle
	imm.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
	for i in range(segments + 1):
		var a = (float(i) / float(segments)) * TAU
		imm.surface_add_vertex(Vector3(cos(a) * spawn_radius, 0.1, sin(a) * spawn_radius))
	imm.surface_end()
	
	# 2. Inner circle (forbidden zone in the center)
	if min_spawn_radius > 0.1:
		imm.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
		for i in range(segments + 1):
			var a = (float(i) / float(segments)) * TAU
			imm.surface_add_vertex(Vector3(cos(a) * min_spawn_radius, 0.1, sin(a) * min_spawn_radius))
		imm.surface_end()
		
	# 3. Aggro detection zone circle (alert red)
	if zone_aggro_enabled and zone_aggro_radius > 0.1:
		var aggro_mat = StandardMaterial3D.new()
		aggro_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		aggro_mat.albedo_color = Color(1.0, 0.15, 0.15, 0.75) # Bright red
		imm.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, aggro_mat)
		for i in range(segments + 1):
			var a = (float(i) / float(segments)) * TAU
			imm.surface_add_vertex(Vector3(cos(a) * zone_aggro_radius, 0.15, sin(a) * zone_aggro_radius))
		imm.surface_end()

	mesh_inst.mesh = imm

func _remove_debug_mesh() -> void:
	var existing = get_node_or_null("_DebugCircleVisual")
	if existing != null:
		existing.queue_free()
