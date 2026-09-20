class_name EnemyOptimizerComponent
extends Node

## Composant d'Optimisation des Performances & LOD pour Ennemis
## 1. Active le culling de distance géométrique (visibility_range_end) sur tous les MeshInstance3D.
## 2. Détecte la présence à l'écran via VisibleOnScreenNotifier3D.
## 3. Désactive l'AnimationTree, le Skeleton3D, les RayCasts et l'IK hors-écran ou à longue distance.

@export_category("Distances de Culling Visuel")
## Distance maximale à laquelle le maillage est rendu (en mètres)
@export var max_visible_distance: float = 85.0
## Marge de fondu progressif dithering (entre max_visible_distance - margin et max)
@export var fade_margin: float = 12.0

@export_category("Distances d'Animation (LOD)")
## Distance maximale pour calculer les animations (au-delà, l'animation est coupée)
@export var max_anim_distance: float = 65.0
## Distance de sécurité absolue : à moins de cette distance, on anime TOUJOURS même hors-écran
@export var close_anim_distance: float = 16.0

@export_category("Boîte de Visibilité (AABB)")
@export var aabb_size: Vector3 = Vector3(2.4, 2.8, 2.4)
@export var aabb_offset: Vector3 = Vector3(0.0, 1.4, 0.0)

var is_on_screen: bool = true
var is_anim_culled: bool = false

var _parent_body: CharacterBody3D
var _anim_tree: AnimationTree
var _anim_player: AnimationPlayer
var _ik_nodes: Array[SkeletonIK3D] = []
var _raycast_nodes: Array[RayCast3D] = []
var _notifier: VisibleOnScreenNotifier3D
var _timer: float = 0.0
var _was_anim_player_paused: bool = false

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
	
	# Récupération spécifique des SkeletonIK3D et RayCast3D (ex: araignées)
	for ik in _parent_body.find_children("*", "SkeletonIK3D", true, false):
		if ik is SkeletonIK3D:
			_ik_nodes.append(ik)
			
	for ray in _parent_body.find_children("*", "RayCast3D", true, false):
		if ray is RayCast3D:
			_raycast_nodes.append(ray)
			
	_parent_body.set_meta("enemy_optimizer", self)
	if "is_anim_culled" in _parent_body:
		_parent_body.is_anim_culled = false

func _setup_mesh_visibility_range() -> void:
	var meshes = _parent_body.find_children("*", "MeshInstance3D", true, false)
	for mesh in meshes:
		if mesh is MeshInstance3D:
			mesh.visibility_range_end = max_visible_distance
			mesh.visibility_range_end_margin = fade_margin
			mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

func _setup_visibility_notifier() -> void:
	if _parent_body.has_node("EnemyVisibilityNotifier"):
		_notifier = _parent_body.get_node("EnemyVisibilityNotifier") as VisibleOnScreenNotifier3D
	else:
		_notifier = VisibleOnScreenNotifier3D.new()
		_notifier.name = "EnemyVisibilityNotifier"
		_notifier.aabb = AABB(aabb_offset - aabb_size * 0.5, aabb_size)
		_notifier.screen_entered.connect(_on_screen_entered)
		_notifier.screen_exited.connect(_on_screen_exited)
		_parent_body.add_child.call_deferred(_notifier)

func _on_screen_entered() -> void:
	is_on_screen = true
	_update_culling_state()

func _on_screen_exited() -> void:
	is_on_screen = false
	_update_culling_state()

func _process(delta: float) -> void:
	if _parent_body == null or not is_instance_valid(_parent_body): return
	
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(0.18, 0.28)
		_update_culling_state()

func _update_culling_state() -> void:
	if _parent_body == null or not is_instance_valid(_parent_body): return
	
	var cam: Node3D = null
	var vp = get_viewport()
	if vp:
		cam = vp.get_camera_3d()
		
	if cam == null:
		var players = get_tree().get_nodes_in_group("Player")
		if not players.is_empty() and is_instance_valid(players[0]):
			cam = players[0] as Node3D
			
	var dist_sq = 999999.0
	if cam != null and is_instance_valid(cam):
		dist_sq = _parent_body.global_position.distance_squared_to(cam.global_position)
		
	var should_animate: bool = false
	# À moins de 16m : toujours animer (proximité / combat)
	if dist_sq <= (close_anim_distance * close_anim_distance):
		should_animate = true
	# Entre 16m et 65m : animer uniquement si à l'écran
	elif is_on_screen and dist_sq <= (max_anim_distance * max_anim_distance):
		should_animate = true
		
	set_anim_culled(not should_animate)

func set_anim_culled(culled: bool) -> void:
	if is_anim_culled == culled: return
	is_anim_culled = culled
	
	if "is_anim_culled" in _parent_body:
		_parent_body.is_anim_culled = culled
		
	if culled:
		if _anim_tree and _anim_tree.active:
			_anim_tree.active = false
		if _anim_player and _anim_tree == null and _anim_player.is_playing():
			_anim_player.pause()
			_was_anim_player_paused = true
		for ik in _ik_nodes:
			ik.stop()
		for ray in _raycast_nodes:
			ray.enabled = false
	else:
		if _anim_tree and not _anim_tree.active:
			_anim_tree.active = true
		if _anim_player and _anim_tree == null and _was_anim_player_paused:
			_was_anim_player_paused = false
			if _anim_player.current_animation != "":
				_anim_player.play()
		for ik in _ik_nodes:
			ik.start()
		for ray in _raycast_nodes:
			ray.enabled = true
