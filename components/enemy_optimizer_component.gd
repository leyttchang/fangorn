class_name EnemyOptimizerComponent
extends Node

## Composant d'Optimisation des Performances & LOD pour Ennemis
## 1. Active le culling de distance géométrique (visibility_range_end) sur tous les MeshInstance3D.
## 2. Détecte la présence à l'écran via VisibleOnScreenNotifier3D.
## 3. Désactive l'AnimationTree, le Skeleton3D, les RayCasts et l'IK hors-écran ou à longue distance.

@export_category("Distances de Culling Visuel")
## Distance maximale à laquelle le maillage est rendu (en mètres)
@export var max_visible_distance: float = 95.0
## Marge d'hystérésis autour de max_visible_distance
@export var fade_margin: float = 12.0

@export_category("Distances d'Animation (LOD)")
## Distance maximale pour calculer les animations (au-delà, l'animation est coupée même à l'écran)
@export var max_anim_distance: float = 65.0
## Distance de sécurité absolue : à moins de cette distance, on anime TOUJOURS même hors-écran
@export var close_anim_distance: float = 16.0
## Distance au-delà de laquelle un monstre hors-combat (sans cible) met en veille sa physique et son NavMesh
@export var ai_sleep_distance: float = 95.0

@export_category("Boîte de Visibilité (AABB)")
@export var aabb_size: Vector3 = Vector3(2.4, 2.8, 2.4)
@export var aabb_offset: Vector3 = Vector3(0.0, 1.4, 0.0)

var is_on_screen: bool = true
var is_anim_culled: bool = false
var is_ai_sleeping: bool = false

var _parent_body: CharacterBody3D
var _anim_tree: AnimationTree
var _anim_player: AnimationPlayer
var _nav_agent: NavigationAgent3D
var _saved_nav_avoidance: bool = false
var _mesh_nodes: Array[MeshInstance3D] = []
var _ik_nodes: Array[SkeletonIK3D] = []
var _raycast_nodes: Array[RayCast3D] = []
var _procedural_anim_nodes: Array[Node] = []
var _notifier: VisibleOnScreenNotifier3D
var _timer: float = 0.0
var _spawn_settle_timer: float = 1.6
var _was_anim_player_paused: bool = false
var _is_shadow_culled: bool = false

func _ready() -> void:
	_parent_body = get_parent() as CharacterBody3D
	if _parent_body == null:
		return
		
	# Timer désynchronisé pour répartir la charge CPU
	_timer = randf_range(0.05, 0.25)
	
	# 1. Configuration du culling de distance pour tous les MeshInstance3D
	_setup_mesh_visibility_range()
	
	# 2. Détection de visibilité à l'écran
	_setup_visibility_notifier()
	
	# 3. Récupération des systèmes d'animation
	_anim_tree = _parent_body.find_child("AnimationTree", true, false) as AnimationTree
	_anim_player = _parent_body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	
	# Récupération spécifique des SkeletonIK3D, RayCast3D et noeuds d'IK procédurale (ex: araignées)
	for ik in _parent_body.find_children("*", "SkeletonIK3D", true, false):
		if ik is SkeletonIK3D:
			_ik_nodes.append(ik)
			
	for ray in _parent_body.find_children("*", "RayCast3D", true, false):
		if ray is RayCast3D:
			_raycast_nodes.append(ray)
			
	var step_container = _parent_body.find_child("step_target_container", true, false)
	if step_container != null:
		_procedural_anim_nodes.append(step_container)
		for child in step_container.get_children():
			_procedural_anim_nodes.append(child)
			
	var target_container = _parent_body.find_child("target_container", true, false)
	if target_container != null:
		_procedural_anim_nodes.append(target_container)
		for child in target_container.get_children():
			_procedural_anim_nodes.append(child)
			
	_parent_body.set_meta("enemy_optimizer", self)
	if "is_anim_culled" in _parent_body:
		_parent_body.is_anim_culled = false
	_nav_agent = _parent_body.find_child("NavigationAgent3D", true, false) as NavigationAgent3D
	if _nav_agent != null:
		_saved_nav_avoidance = _nav_agent.avoidance_enabled
	call_deferred("_bind_wake_signals")

func _bind_wake_signals() -> void:
	if _parent_body == null or not is_instance_valid(_parent_body):
		return
	for hb_node: Node in _parent_body.find_children("*HitboxComponent*", "", true, false):
		if hb_node.has_signal("hit_received") and not hb_node.is_connected("hit_received", _on_wake_hit):
			hb_node.connect("hit_received", _on_wake_hit)
		if hb_node.has_signal("aggro_requested") and not hb_node.is_connected("aggro_requested", _on_wake_aggro):
			hb_node.connect("aggro_requested", _on_wake_aggro)

func _on_wake_hit(_attack: Variant) -> void:
	set_ai_sleeping(false)

func _on_wake_aggro(_attacker: Variant) -> void:
	set_ai_sleeping(false)

func _setup_mesh_visibility_range() -> void:
	_mesh_nodes.clear()
	var meshes = _parent_body.find_children("*", "MeshInstance3D", true, false)
	for mesh in meshes:
		if mesh is MeshInstance3D:
			mesh.visibility_range_end = max_visible_distance
			mesh.visibility_range_end_margin = fade_margin
			mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			if mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				_mesh_nodes.append(mesh)

func _setup_visibility_notifier() -> void:
	if _parent_body.has_node("EnemyVisibilityNotifier"):
		_notifier = _parent_body.get_node("EnemyVisibilityNotifier") as VisibleOnScreenNotifier3D
	else:
		_notifier = VisibleOnScreenNotifier3D.new()
		_notifier.name = "EnemyVisibilityNotifier"
		_notifier.aabb = AABB(aabb_offset - aabb_size * 0.5, aabb_size)
		_parent_body.add_child.call_deferred(_notifier)
	if not _notifier.screen_entered.is_connected(_on_screen_entered):
		_notifier.screen_entered.connect(_on_screen_entered)
	if not _notifier.screen_exited.is_connected(_on_screen_exited):
		_notifier.screen_exited.connect(_on_screen_exited)

func _on_screen_entered() -> void:
	is_on_screen = true
	_update_culling_state()

func _on_screen_exited() -> void:
	is_on_screen = false
	_update_culling_state()

func _process(delta: float) -> void:
	if _parent_body == null or not is_instance_valid(_parent_body): return
	if _spawn_settle_timer > 0.0:
		_spawn_settle_timer = maxf(0.0, _spawn_settle_timer - delta)
	
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(0.18, 0.28)
		_update_culling_state()

static var _cached_cam: Node3D = null
static var _cached_frame: int = -1
static var _cached_player_positions: PackedVector3Array = PackedVector3Array()
static var _cached_players_frame: int = -1

func _get_active_camera() -> Node3D:
	var current_frame = Engine.get_process_frames()
	if current_frame == _cached_frame and is_instance_valid(_cached_cam):
		return _cached_cam
		
	_cached_frame = current_frame
	_cached_cam = null
	
	var vp = get_viewport()
	if vp:
		_cached_cam = vp.get_camera_3d()
		
	if _cached_cam == null and is_inside_tree() and get_tree() != null:
		var players = get_tree().get_nodes_in_group("Player")
		if not players.is_empty() and is_instance_valid(players[0]):
			_cached_cam = players[0] as Node3D
			
	return _cached_cam

func _get_active_player_positions() -> PackedVector3Array:
	var current_frame := Engine.get_process_frames()
	if current_frame == _cached_players_frame:
		return _cached_player_positions
		
	_cached_players_frame = current_frame
	_cached_player_positions.clear()
	
	if is_inside_tree() and get_tree() != null:
		var players := get_tree().get_nodes_in_group("Player")
		for p in players:
			if p is Node3D and is_instance_valid(p) and p.is_inside_tree() and p.get("is_dead") != true:
				_cached_player_positions.append((p as Node3D).global_position)
				
	return _cached_player_positions

func _update_culling_state() -> void:
	if _parent_body == null or not is_instance_valid(_parent_body): return
	
	if _notifier != null and _notifier.is_inside_tree():
		is_on_screen = _notifier.is_on_screen()
	
	var cam: Node3D = _get_active_camera()
	var dist_sq = 999999.0
	if cam != null and is_instance_valid(cam):
		dist_sq = _parent_body.global_position.distance_squared_to(cam.global_position)
		
	if not _is_shadow_culled and dist_sq > (48.0 * 48.0):
		_is_shadow_culled = true
		for mesh in _mesh_nodes:
			if is_instance_valid(mesh):
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	elif _is_shadow_culled and dist_sq <= (44.0 * 44.0):
		_is_shadow_culled = false
		for mesh in _mesh_nodes:
			if is_instance_valid(mesh):
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		
	var should_animate: bool = false
	if close_anim_distance > 0.0 and dist_sq <= (close_anim_distance * close_anim_distance):
		should_animate = true
	elif is_on_screen and dist_sq <= (max_anim_distance * max_anim_distance):
		should_animate = true
		
	if not should_animate and is_inside_tree() and multiplayer.has_multiplayer_peer() and _parent_body.is_multiplayer_authority():
		var auth_anim_dist: float = close_anim_distance + 12.0
		var auth_anim_dist_sq: float = auth_anim_dist * auth_anim_dist
		var body_pos: Vector3 = _parent_body.global_position
		for p_pos in _get_active_player_positions():
			if body_pos.distance_squared_to(p_pos) <= auth_anim_dist_sq:
				should_animate = true
				break
		
	set_anim_culled(not should_animate)
	_update_ai_sleep_state(dist_sq)

func _update_ai_sleep_state(cam_dist_sq: float) -> void:
	if ai_sleep_distance <= 0.0:
		return
	if _spawn_settle_timer > 0.0 or _parent_body.is_in_group("Boss") or _parent_body.is_in_group("ArcaneFlare"):
		set_ai_sleeping(false)
		return
	if _parent_body.get("is_dead") == true:
		set_ai_sleeping(false)
		return
	if _parent_body.get("target") != null and is_instance_valid(_parent_body.get("target")):
		set_ai_sleeping(false)
		return

	var min_player_d2: float = cam_dist_sq
	var body_pos: Vector3 = _parent_body.global_position
	for p_pos: Vector3 in _get_active_player_positions():
		var d2: float = body_pos.distance_squared_to(p_pos)
		if d2 < min_player_d2:
			min_player_d2 = d2

	var wake_dist: float = maxf(25.0, ai_sleep_distance - 6.0)
	if is_ai_sleeping:
		if min_player_d2 <= wake_dist * wake_dist:
			set_ai_sleeping(false)
	else:
		if min_player_d2 > ai_sleep_distance * ai_sleep_distance:
			set_ai_sleeping(true)

func set_ai_sleeping(sleeping: bool) -> void:
	if is_ai_sleeping == sleeping:
		return
	is_ai_sleeping = sleeping
	if _parent_body == null or not is_instance_valid(_parent_body):
		return
	if sleeping:
		_parent_body.set_physics_process(false)
		_parent_body.set_process(false)
		if _nav_agent != null and is_instance_valid(_nav_agent):
			_nav_agent.avoidance_enabled = false
	else:
		_parent_body.set_physics_process(true)
		_parent_body.set_process(true)
		if _nav_agent != null and is_instance_valid(_nav_agent) and _saved_nav_avoidance:
			_nav_agent.avoidance_enabled = true

func set_anim_culled(culled: bool) -> void:
	if is_anim_culled == culled: return
	is_anim_culled = culled
	
	if "is_anim_culled" in _parent_body:
		_parent_body.is_anim_culled = culled
		
	if culled:
		_parent_body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		if _anim_tree and _anim_tree.active:
			_anim_tree.active = false
		if _anim_player and _anim_tree == null and _anim_player.is_playing():
			_anim_player.pause()
			_was_anim_player_paused = true
		for ik in _ik_nodes:
			ik.stop()
		for ray in _raycast_nodes:
			ray.enabled = false
		for node in _procedural_anim_nodes:
			if is_instance_valid(node):
				node.set_process(false)
				node.set_physics_process(false)
	else:
		_parent_body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
		if _anim_tree and not _anim_tree.active:
			_anim_tree.active = true
			if _parent_body.has_method("_sync_animation_state"):
				_parent_body._sync_animation_state()
		if _anim_player and _anim_tree == null and _was_anim_player_paused:
			_was_anim_player_paused = false
			if _anim_player.current_animation != "":
				_anim_player.play()
		for ik in _ik_nodes:
			ik.start()
		for ray in _raycast_nodes:
			ray.enabled = true
		for node in _procedural_anim_nodes:
			if is_instance_valid(node):
				node.set_process(true)
				node.set_physics_process(true)
