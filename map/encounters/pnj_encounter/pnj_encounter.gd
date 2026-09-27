@tool
class_name PnjEncounter
extends Node3D

signal cage_opened

@export_category("Références")
## Nœud de la cage contenant les barreaux
@export var cage_node: Node3D:
	set(val):
		cage_node = val
		_record_initial_transforms()

## Nœud du spawner de monstres
@export var spawner: MobRaycastSpawner
## Nœud du PNJ
@export var pnj: Node3D
## Nœud du plateau supérieur (toit de la cage)
@export var plateau_haut: RigidBody3D
## Nœud du raycast vers le sol
@export var ground_raycast: RayCast3D
## Nœud de l'armature / potence
@export var armature_node: Node3D
## Nœud de la chaîne
@export var chaine_node: Node3D

@export_category("Paramètres de Camp & Récompenses")
## Niveau d'objet de base associé à cette rencontre / camp (transmis au PNJ)
@export var camp_ilvl: int = 1:
	set(val):
		camp_ilvl = val
		if pnj != null and "camp_ilvl" in pnj:
			pnj.camp_ilvl = val
		if spawner != null and "encounter_level" in spawner:
			spawner.encounter_level = val

@export_category("Descente de la Cage (Glissement au Sol)")
## Durée en secondes pour faire glisser la cage jusqu'au sol
@export var fall_duration: float = 0.55
## Petit délai en secondes une fois la cage au sol avant qu'elle n'explose
@export var fall_to_explode_delay: float = 0.2

@export_category("Physique des Barreaux (En Jeu)")
## Force d'impulsion vers l'extérieur pour faire voler les barreaux à l'ouverture
@export var impulse_force: float = 3.5
## Légère impulsion vers le haut pour donner un effet d'arrachage
@export var upward_impulse: float = 1.2
## Force de rotation aléatoire pour faire tournoyer les barreaux
@export var torque_force: float = 2.5
## Délai en secondes avant de supprimer les débris au sol (0 = ne jamais supprimer)
@export var bars_despawn_delay: float = 20.0

@export_category("Physique du Toit (plateau_haut)")
## Impulsion vers le haut pour éjecter le toit en l'air
@export var roof_upward_impulse: float = 9.0
## Impulsion latérale pour envoyer le toit sur le côté
@export var roof_side_impulse: float = 5.0
## Force de rotation aléatoire pour faire culbuter le toit
@export var roof_torque_force: float = 7.0

@export_category("Actions (Inspecteur)")
## Coche cette case pour placer automatiquement le PNJ sur le plancher de la cage (préserve sa scale et sa rotation)
@export var snap_pnj_in_cage: bool = false:
	set(val):
		snap_pnj_in_cage = false
		if is_inside_tree():
			snap_pnj_to_cage_floor()

## Coche cette case pour tester l'ouverture de la cage immédiatement
@export var trigger_open_cage_now: bool = false:
	set(val):
		trigger_open_cage_now = false
		if is_inside_tree():
			open_cage()

## Coche cette case pour refermer la cage et remettre les barreaux à leur place
@export var reset_cage_now: bool = false:
	set(val):
		reset_cage_now = false
		if is_inside_tree():
			reset_cage()

var is_cage_opened: bool = false
var _initial_cage_transform: Transform3D
var _has_initial_cage_transform: bool = false
var _initial_bar_transforms: Dictionary = {}
var _pnj_saved_elevated_y: float = 0.0
var _pnj_has_fallen: bool = false
var _active_tweens: Array[Tween] = []

func _ready() -> void:
	_resolve_references()
	_record_initial_transforms()
	
	if Engine.is_editor_hint():
		return
		
	# En jeu : connexion automatique au signal du spawner
	if spawner != null:
		if not spawner.all_mobs_defeated.is_connected(open_cage):
			spawner.all_mobs_defeated.connect(open_cage)

func _resolve_references() -> void:
	if cage_node == null:
		cage_node = get_node_or_null("cage")
	if plateau_haut == null and cage_node != null:
		plateau_haut = cage_node.get_node_or_null("plateau_haut") as RigidBody3D
	if ground_raycast == null:
		ground_raycast = get_node_or_null("ground_raycast") as RayCast3D
	if armature_node == null:
		armature_node = get_node_or_null("armature") as Node3D
	if chaine_node == null:
		chaine_node = find_child("chaine", true, false) as Node3D
	if spawner == null:
		spawner = get_node_or_null("mob_raycast_spawner") as MobRaycastSpawner
	if spawner != null and "encounter_level" in spawner:
		spawner.encounter_level = camp_ilvl
	if pnj == null:
		pnj = find_child("Pnj_buff_choice", true, false) as Node3D
	if pnj != null and "camp_ilvl" in pnj:
		pnj.camp_ilvl = camp_ilvl

	# Exclure les éléments de la cage et le PNJ du raycast vers le sol
	if ground_raycast != null:
		if cage_node != null:
			for child in cage_node.get_children():
				if child is CollisionObject3D:
					ground_raycast.add_exception(child)
		if pnj != null:
			if pnj is CollisionObject3D:
				ground_raycast.add_exception(pnj)
			for pnj_col in pnj.find_children("*", "CollisionObject3D", true, false):
				ground_raycast.add_exception(pnj_col)

func _record_initial_transforms() -> void:
	if cage_node == null:
		cage_node = get_node_or_null("cage")
	if cage_node != null:
		if not _has_initial_cage_transform:
			_initial_cage_transform = cage_node.transform
			_has_initial_cage_transform = true
		for child in cage_node.get_children():
			if child is RigidBody3D:
				child.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
				if not _initial_bar_transforms.has(child):
					_initial_bar_transforms[child] = child.transform

## Détecte le sol sous la cage par RayCast3D ou DirectSpaceState
func _get_ground_y() -> float:
	_resolve_references()
	if ground_raycast != null:
		ground_raycast.force_raycast_update()
		if ground_raycast.is_colliding():
			var hit_point = ground_raycast.get_collision_point()
			return hit_point.y
			
	# Fallback : PhysicsRayQuery direct dans le PhysicsServer
	var space_state = get_world_3d().direct_space_state
	if space_state != null and cage_node != null:
		var from_pos = cage_node.to_global(Vector3(-13.438, 20.5, 0.0))
		var to_pos = from_pos - Vector3(0.0, 40.0, 0.0)
		var query = PhysicsRayQueryParameters3D.create(from_pos, to_pos, 1)
		
		# Exclure les colliders de la cage et du PNJ
		var exclude_rids: Array[RID] = []
		for child in cage_node.get_children():
			if child is CollisionObject3D:
				exclude_rids.append(child.get_rid())
		if pnj != null:
			if pnj is CollisionObject3D:
				exclude_rids.append(pnj.get_rid())
			for pnj_col in pnj.find_children("*", "CollisionObject3D", true, false):
				exclude_rids.append(pnj_col.get_rid())
		query.exclude = exclude_rids
		
		var hit = space_state.intersect_ray(query)
		if not hit.is_empty():
			return hit.position.y
			
	# Fallback ultime : niveau d'origine du nœud encounter
	return global_position.y

## Méthode publique : déclenche l'ouverture de la cage (synchronisée via RPC en multijoueur)
func open_cage() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		rpc("_rpc_open_cage")
	else:
		_do_open_cage()

@rpc("authority", "call_local", "reliable")
func _rpc_open_cage() -> void:
	_do_open_cage()

## Méthode interne : fait glisser la cage jusqu'au sol puis la fait exploser après un court délai
func _do_open_cage() -> void:
	if is_cage_opened or not is_inside_tree() or is_queued_for_deletion():
		return
	is_cage_opened = true
	_resolve_references()
	_record_initial_transforms()
	
	if cage_node == null:
		call_deferred("_explode_cage")
		return
		
	var current_bottom_y = cage_node.to_global(Vector3(-13.438, 20.8999, 0.0)).y
	var ground_y = _get_ground_y()
	var fall_distance = maxf(0.0, current_bottom_y - ground_y)
	
	# Si la cage est déjà au niveau du sol, explosion différée
	if fall_distance < 0.05:
		call_deferred("_explode_cage")
		return
		
	# Détacher visuellement la chaîne
	if chaine_node != null:
		chaine_node.visible = false
		
	# Animation non-physique : la cage glisse vers le sol
	var fall_tw = create_tween()
	_active_tweens.append(fall_tw)
	
	var target_cage_pos = cage_node.position - Vector3(0.0, fall_distance, 0.0)
	fall_tw.tween_property(cage_node, "position", target_cage_pos, fall_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Si le PNJ est un nœud extérieur mais sous l'encounter, on le fait descendre en même temps
	if pnj != null and pnj.get_parent() != cage_node and is_ancestor_of(pnj):
		_pnj_saved_elevated_y = pnj.position.y
		_pnj_has_fallen = true
		var target_pnj_y = pnj.position.y - fall_distance
		fall_tw.parallel().tween_property(pnj, "position:y", target_pnj_y, fall_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
	# Une fois au sol : petit délai puis explosion !
	fall_tw.chain().tween_interval(fall_to_explode_delay)
	fall_tw.tween_callback(_explode_cage)

## Déclenche l'explosion des barreaux et du toit une fois la cage au sol
func _explode_cage() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	print("PnjEncounter: Cage exploding!")
	var debris_to_free: Array[RigidBody3D] = []
	
	if cage_node != null:
		var cage_center = cage_node.to_global(Vector3(-13.438, 20.9, 0.0))
		
		# Disparaître le plancher / plateau du bas de la cage
		var plateau_bas = cage_node.get_node_or_null("plateau_bas") as Node3D
		if plateau_bas != null:
			plateau_bas.visible = false
			
		if chaine_node != null:
			chaine_node.visible = false
		
		# =====================================================================
		# 1. MODE ÉDITEUR : Animation visuelle immédiate (le moteur physique Jolt
		#    ne simule pas la gravité dans le viewport de l'éditeur sans F6)
		# =====================================================================
		if Engine.is_editor_hint():
			for child in cage_node.get_children():
				if child is RigidBody3D:
					debris_to_free.append(child)
					
					# Traitement spécifique pour le plateau du haut (éjecté vers le haut et le côté)
					if child == plateau_haut or child.name == "plateau_haut":
						var angle = randf() * TAU
						var side_dir = Vector3(cos(angle), 0.0, sin(angle))
						var peak_pos = child.position + Vector3(side_dir.x * 8.0, 16.0, side_dir.z * 8.0)
						var ground_pos = child.position + Vector3(side_dir.x * 22.0, -14.0, side_dir.z * 22.0)
						var target_rot = child.rotation + Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
						
						var tw_up = create_tween()
						_active_tweens.append(tw_up)
						tw_up.tween_property(child, "position", peak_pos, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
						tw_up.chain().tween_property(child, "position", ground_pos, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
						
						var tw_rot = create_tween()
						_active_tweens.append(tw_rot)
						tw_rot.tween_property(child, "rotation", target_rot, 1.0)
					else:
						var push_dir = (child.global_position - cage_center)
						push_dir.y = 0.0
						push_dir = push_dir.normalized() if push_dir.length_squared() > 0.001 else Vector3.FORWARD
						
						var target_pos = child.position + (push_dir * 14.0) - Vector3(0, 5.0, 0)
						var target_rot = child.rotation + Vector3(randf_range(-1.2, 1.2), randf_range(-1.2, 1.2), randf_range(-1.2, 1.2))
						
						var tw = create_tween().set_parallel(true)
						_active_tweens.append(tw)
						tw.tween_property(child, "position", target_pos, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
						tw.tween_property(child, "rotation", target_rot, 0.55)
		# =====================================================================
		# 2. EN JEU RÉEL : Simulation physique Jolt complète
		# =====================================================================
		else:
			var impulse_targets: Array[Dictionary] = []
			for child in cage_node.get_children():
				if child is RigidBody3D:
					debris_to_free.append(child)
					# Dégèle le corps pour que la gravité et les collisions s'activent
					child.freeze = false
					
					# Traitement spécifique pour le plateau du haut (éjecté vers le haut et le côté)
					if child == plateau_haut or child.name == "plateau_haut":
						var angle = randf() * TAU
						var side_dir = Vector3(cos(angle), 0.0, sin(angle))
						var central_imp = Vector3.UP * roof_upward_impulse + side_dir * roof_side_impulse
						var torque_imp = Vector3(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5), randf_range(-1.0, 1.0)).normalized() * roof_torque_force
						impulse_targets.append({
							"body": child,
							"central": central_imp,
							"torque": torque_imp
						})
					else:
						var push_dir = child.global_position - cage_center
						push_dir.y = 0.0
						push_dir = push_dir.normalized() if push_dir.length_squared() > 0.001 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
						var central_imp = push_dir * impulse_force + Vector3.UP * upward_impulse
						var torque_imp = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * torque_force
						impulse_targets.append({
							"body": child,
							"central": central_imp,
							"torque": torque_imp
						})
			
			if not impulse_targets.is_empty() and is_inside_tree() and get_tree() != null:
				await get_tree().physics_frame
				for item in impulse_targets:
					var b: RigidBody3D = item["body"]
					if is_instance_valid(b) and b.is_inside_tree() and not b.is_queued_for_deletion():
						var direct_state = PhysicsServer3D.body_get_direct_state(b.get_rid())
						if direct_state != null:
							b.apply_central_impulse(item["central"])
							b.apply_torque_impulse(item["torque"])
						
	# 3. Libération du PNJ (en jeu uniquement)
	if not Engine.is_editor_hint():
		if pnj != null and pnj.has_method("unlock_pnj"):
			pnj.unlock_pnj()
		else:
			var found_pnj = find_child("Pnj_buff_choice", true, false)
			if found_pnj != null and found_pnj.has_method("unlock_pnj"):
				found_pnj.unlock_pnj()
			
	cage_opened.emit()
	
	# 4. Nettoyage différé des débris en jeu
	if not Engine.is_editor_hint() and bars_despawn_delay > 0.0 and not debris_to_free.is_empty():
		_schedule_bars_cleanup(debris_to_free, bars_despawn_delay)

## Referme la cage et replace tous les débris (barreaux, plateau et cage en hauteur) dans leur position initiale
func reset_cage() -> void:
	_resolve_references()
	is_cage_opened = false
	
	# Arrêter toutes les animations en cours en mode éditeur
	for tw in _active_tweens:
		if is_instance_valid(tw) and tw.is_valid():
			tw.kill()
	_active_tweens.clear()
	
	# Restaurer la position d'origine de la cage en hauteur
	if cage_node != null and _has_initial_cage_transform:
		cage_node.transform = _initial_cage_transform
		
	# Restaurer tous les débris à leur place dans la cage
	if cage_node != null and not _initial_bar_transforms.is_empty():
		for child in cage_node.get_children():
			if child is RigidBody3D and _initial_bar_transforms.has(child):
				child.freeze = true
				child.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
				if not Engine.is_editor_hint():
					child.linear_velocity = Vector3.ZERO
					child.angular_velocity = Vector3.ZERO
				child.transform = _initial_bar_transforms[child]
				
	# Réafficher la chaîne
	if chaine_node != null:
		chaine_node.visible = true
		
	# Réafficher le plateau du bas
	if cage_node != null:
		var plateau_bas = cage_node.get_node_or_null("plateau_bas") as Node3D
		if plateau_bas != null:
			plateau_bas.visible = true
		
	# Restaurer uniquement la hauteur Y du PNJ s'il était descendu (scale et rotation 100% préservées)
	if pnj != null:
		if _pnj_has_fallen and pnj.get_parent() != cage_node:
			pnj.position.y = _pnj_saved_elevated_y
			_pnj_has_fallen = false
		if not Engine.is_editor_hint():
			if "is_freed" in pnj:
				pnj.is_freed = false
			if "reward_claimed" in pnj:
				pnj.reward_claimed = false
	else:
		var found_pnj = find_child("Pnj_buff_choice", true, false)
		if found_pnj != null:
			if _pnj_has_fallen and found_pnj.get_parent() != cage_node:
				found_pnj.position.y = _pnj_saved_elevated_y
				_pnj_has_fallen = false
			if not Engine.is_editor_hint():
				if "is_freed" in found_pnj:
					found_pnj.is_freed = false
				if "reward_claimed" in found_pnj:
					found_pnj.reward_claimed = false
			
	print("PnjEncounter: Cage reset and closed elevated.")

## Place le PNJ sur le plancher de la cage sans modifier son échelle (scale) ni sa rotation
func snap_pnj_to_cage_floor() -> void:
	_resolve_references()
	if pnj == null or cage_node == null:
		push_warning("PnjEncounter: Missing PNJ or cage_node for snapping.")
		return
	var floor_global_pos = cage_node.to_global(Vector3(-13.438246, 20.8999, 0.0))
	if pnj.get_parent() == self:
		pnj.position = to_local(floor_global_pos)
	elif pnj.get_parent() == cage_node:
		pnj.position = Vector3(-13.438246, 20.8999, 0.0)
	else:
		pnj.global_position = floor_global_pos
	print("PnjEncounter: PNJ aligned to cage floor (position=", pnj.position, "). Scale and rotation preserved.")

func _schedule_bars_cleanup(bars: Array[RigidBody3D], delay: float) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	await get_tree().create_timer(delay).timeout
	for bar in bars:
		if is_instance_valid(bar) and not bar.is_queued_for_deletion():
			bar.queue_free()
	if cage_node != null:
		var plateau_bas = cage_node.get_node_or_null("plateau_bas")
		if is_instance_valid(plateau_bas) and not plateau_bas.is_queued_for_deletion():
			plateau_bas.queue_free()
	print("PnjEncounter: Debris cleaned up.")
