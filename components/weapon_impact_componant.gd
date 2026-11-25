class_name WeaponImpactComponent
extends Node3D

@export var raycast: RayCast3D
@export var blood_particles_scene: PackedScene
@export var main_droite: Marker3D

var _current_attack_comp: AttackComponent = null
var _weapon_container: Node = null
var _cached_weapon_node: Node = null
var _cached_container_child_count: int = -1
var _weapon_cache_dirty: bool = true
var _expired_targets: Array = []

# Dictionnaire pour attendre que le raycast touche (Cible: Temps restant)
var _pending_impacts: Dictionary = {}
const MAX_WAIT_TIME: float = 0.15 # On attend jusqu'a 0.15s que l'arme penetre

func _ready() -> void:
	if owner != null and multiplayer.has_multiplayer_peer() and not owner.is_multiplayer_authority():
		if raycast != null:
			raycast.enabled = false
		set_process(false)
		return
	_bind_weapon_container()

func _bind_weapon_container() -> void:
	if main_droite == null:
		return
	var wrist: Node = main_droite.get_node_or_null("wrist")
	_weapon_container = wrist if wrist != null else main_droite
	if not main_droite.child_entered_tree.is_connected(_on_weapon_tree_changed):
		main_droite.child_entered_tree.connect(_on_weapon_tree_changed)
		main_droite.child_exiting_tree.connect(_on_weapon_tree_changed)
	if _weapon_container != main_droite and not _weapon_container.child_entered_tree.is_connected(_on_weapon_tree_changed):
		_weapon_container.child_entered_tree.connect(_on_weapon_tree_changed)
		_weapon_container.child_exiting_tree.connect(_on_weapon_tree_changed)
	_weapon_cache_dirty = true

func _on_weapon_tree_changed(_node: Node) -> void:
	_weapon_cache_dirty = true

func _refresh_attack_component() -> void:
	_weapon_cache_dirty = false
	if _weapon_container != null:
		_cached_container_child_count = _weapon_container.get_child_count()
	var found_comp: AttackComponent = _find_attack_component_recursive(_weapon_container if _weapon_container != null else main_droite)
	_cached_weapon_node = found_comp.get_parent() if found_comp != null else null
	if found_comp != _current_attack_comp:
		if _current_attack_comp != null and is_instance_valid(_current_attack_comp) and _current_attack_comp.attack_landed.is_connected(_on_attack_landed):
			_current_attack_comp.attack_landed.disconnect(_on_attack_landed)
		_current_attack_comp = found_comp
		if _current_attack_comp != null:
			_current_attack_comp.attack_landed.connect(_on_attack_landed)

func _process(delta: float) -> void:
	if owner != null and multiplayer.has_multiplayer_peer() and not owner.is_multiplayer_authority():
		if raycast != null:
			raycast.enabled = false
		set_process(false)
		return

	if main_droite == null:
		return

	if _weapon_container == null:
		_bind_weapon_container()

	if (
		_weapon_cache_dirty
		or (_weapon_container != null and _weapon_container.get_child_count() != _cached_container_child_count)
		or (_cached_weapon_node != null and (not is_instance_valid(_cached_weapon_node) or not _cached_weapon_node.is_inside_tree() or _cached_weapon_node.is_queued_for_deletion()))
		or (_current_attack_comp != null and not is_instance_valid(_current_attack_comp))
	):
		_refresh_attack_component()

	# --- VERIFICATION DES IMPACTS EN ATTENTE ---
	if not _pending_impacts.is_empty() and raycast != null:
		raycast.force_raycast_update()
		
		var hit_target = null
		var impact_point = Vector3.ZERO
		var impact_normal = Vector3.ZERO
		
		if raycast.is_colliding():
			var collider = raycast.get_collider()
			
			# On cherche si l'objet touche par le Raycast est l'un de nos monstres fraichement touches
			for target in _pending_impacts:
				if target != null and is_instance_valid(target) and collider != null:
					if collider == target or collider == target.get_parent() or collider.owner == target.owner:
						hit_target = target
						impact_point = raycast.get_collision_point()
						impact_normal = raycast.get_collision_normal()
						
						# --- DEEP PENETRATION (Pour coller au Mesh/RigidBody) ---
						var ray_start = raycast.global_position
						var ray_end = raycast.to_global(raycast.target_position)
						var ray_dir = (ray_end - ray_start).normalized()
						
						var space_state = get_world_3d().direct_space_state
						var query = PhysicsRayQueryParameters3D.create(
							impact_point + ray_dir * 0.01, # On decale pour traverser la hitbox
							impact_point + ray_dir * 2.0   # On cherche plus profond a l'interieur
						)
						query.collision_mask = 0xFFFFFFFF # Scan toutes les couches pour trouver le vrai corps
						query.exclude = [collider.get_rid()]
						
						var deep_hit = space_state.intersect_ray(query)
						if deep_hit and deep_hit.collider != null:
							# Si le corps interne appartient bien a ce meme monstre
							if deep_hit.collider == target.owner or deep_hit.collider.owner == target.owner or deep_hit.collider == target.get_parent() or deep_hit.collider.get_parent() == target.owner:
								impact_point = deep_hit.position
								impact_normal = deep_hit.normal
						# -----------------------------------------------------------------
						break
		
		# Si on a vu le raycast toucher notre cible !
		if hit_target != null:
			var target_path = hit_target.get_path() if is_instance_valid(hit_target) else NodePath("")
			_spawn_blood(impact_point, impact_normal, target_path)
			_pending_impacts.erase(hit_target)
			
		# Diminuer le temps des cibles et nettoyer celles qui ont expire (raycast a rate)
		if not _pending_impacts.is_empty():
			_expired_targets.clear()
			for target in _pending_impacts:
				var rem: float = float(_pending_impacts[target]) - delta
				if rem <= 0.0 or not is_instance_valid(target):
					_expired_targets.append(target)
				else:
					_pending_impacts[target] = rem
			for target in _expired_targets:
				_pending_impacts.erase(target)
			_expired_targets.clear()

func _find_attack_component_recursive(node: Node) -> AttackComponent:
	if node == null or node == self or node is WeaponImpactComponent or node.is_queued_for_deletion():
		return null
	if node is AttackComponent:
		return node
	for child in node.get_children():
		var result = _find_attack_component_recursive(child)
		if result != null:
			return result
	return null

func _should_spawn_blood_for(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target.get("enable_blood_vfx") == false:
		return false
	if target.is_in_group("ArcaneFlare"):
		return false
	var p: Node = target.get_parent()
	if p != null and (p.is_in_group("ArcaneFlare") or p.get("enable_blood_vfx") == false):
		return false
	if target.owner != null and target.owner.is_in_group("ArcaneFlare"):
		return false
	return true

func _on_attack_landed(target: Node) -> void:
	if raycast == null or blood_particles_scene == null:
		return
	if not _should_spawn_blood_for(target):
		return
	# On met l'ennemi dans la file d'attente (le raycast a 0.15s pour le toucher physiquement)
	_pending_impacts[target] = MAX_WAIT_TIME

func _spawn_blood(impact_point: Vector3, impact_normal: Vector3, target_path: NodePath) -> void:
	# On s'assure de ne l'appeler que si on est le joueur qui donne le coup
	if not is_multiplayer_authority():
		return
	
	# call_local = on l'execute sur NOUS (le tireur) ET sur tous les autres joueurs
	rpc("_rpc_spawn_blood", impact_point, impact_normal, target_path)

@rpc("authority", "call_local", "unreliable")
func _rpc_spawn_blood(impact_point: Vector3, impact_normal: Vector3, target_path: NodePath = NodePath("")) -> void:
	# OPTIMISATION MAJEURE : On utilise le nouveau systeme de Pooling !
	var pool = get_tree().root.get_node_or_null("VFXPool")
	if pool == null:
		# Fallback au cas ou l'autoload n'est pas charge
		if blood_particles_scene == null: return
		var fallback_blood = blood_particles_scene.instantiate()
		get_tree().current_scene.add_child(fallback_blood)
		fallback_blood.global_position = impact_point
		if fallback_blood.has_method("play_effect"): fallback_blood.play_effect()
		return
		
	var blood = pool.get_blood()
	if blood == null:
		return
		
	blood.global_position = impact_point
	
	if impact_normal.length_squared() > 0.001:
		var up_dir = Vector3.UP
		if abs(impact_normal.dot(Vector3.UP)) > 0.99:
			up_dir = Vector3.RIGHT
		blood.look_at(impact_point + impact_normal, up_dir)
		
	if blood.has_method("set_follow_target") and not target_path.is_empty():
		var target_node = get_node_or_null(target_path)
		blood.set_follow_target(target_node)
		
	if blood.has_method("play_effect"):
		blood.play_effect()
