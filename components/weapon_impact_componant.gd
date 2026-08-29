class_name WeaponImpactComponent
extends Node3D

@export var raycast: RayCast3D
@export var blood_particles_scene: PackedScene
@export var main_droite: Marker3D

var _current_attack_comp: AttackComponent = null

# Dictionnaire pour attendre que le raycast touche (Cible: Temps restant)
var _pending_impacts: Dictionary = {}
const MAX_WAIT_TIME: float = 0.15 # On attend jusqu'a 0.15s que l'arme penetre

var _debug_printed_main_null: bool = false
var _debug_printed_no_attack: bool = false

var _debug_timer: float = 0.0

func _ready() -> void:
	print("[WeaponImpact] Le script est bien charge dans la scene ! main_droite = ", main_droite)

func _process(delta: float) -> void:
	_debug_timer += delta
	
	if main_droite == null:
		if _debug_timer > 2.0:
			print("[WeaponImpact] ERREUR EN BOUCLE : La case 'main_droite' est VIDE dans l'inspecteur de ton joueur !")
			_debug_timer = 0.0
		return
		
	var found_comp = _find_attack_component_recursive(main_droite)
	
	if found_comp == null:
		if _debug_timer > 2.0:
			print("[WeaponImpact] ERREUR EN BOUCLE : 'main_droite' est bien la, mais AUCUN AttackComponent n'a ete trouve a l'interieur (arme pas equipee ou mal placee).")
			_debug_timer = 0.0
	else:
		if not _debug_printed_no_attack:
			print("[WeaponImpact] SUCCES : Un AttackComponent a ete trouve et est connecte !")
			_debug_printed_no_attack = true
			
	if found_comp != _current_attack_comp:
		if _current_attack_comp != null and _current_attack_comp.attack_landed.is_connected(_on_attack_landed):
			_current_attack_comp.attack_landed.disconnect(_on_attack_landed)
		_current_attack_comp = found_comp
		if _current_attack_comp != null:
			_current_attack_comp.attack_landed.connect(_on_attack_landed)
			print("[WeaponImpact] Nouvelle arme connectée : ", _current_attack_comp.get_parent().name)

	# --- NOUVEAU : VERIFICATION DES IMPACTS EN ATTENTE ---
	if not _pending_impacts.is_empty() and raycast != null:
		raycast.force_raycast_update()
		
		var hit_target = null
		var impact_point = Vector3.ZERO
		var impact_normal = Vector3.ZERO
		
		if raycast.is_colliding():
			var collider = raycast.get_collider()
			# On ne spam le print que s'il y a des cibles en attente
			print("[WeaponImpact] Pendant l'attente, Raycast touche actuellement : ", collider.name if collider else "null")
			
			# On cherche si l'objet touche par le Raycast est l'un de nos monstres fraiches touches
			for target in _pending_impacts.keys():
				if target != null and is_instance_valid(target) and collider != null:
					if collider == target or collider == target.get_parent() or collider.owner == target.owner:
						hit_target = target
						impact_point = raycast.get_collision_point()
						impact_normal = raycast.get_collision_normal()
						
						# --- NOUVEAU : DEEP PENETRATION (Pour coller au Mesh/RigidBody) ---
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
		else:
			print("[WeaponImpact] Pendant l'attente, Raycast ne touche RIEN.")
		
		# Si on a vu le raycast toucher notre cible !
		if hit_target != null:
			print("[WeaponImpact] SUCCESS ! Le Raycast a bien trouvé la cible : ", hit_target.name, ". Spawn du sang !")
			_spawn_blood(impact_point, impact_normal)
			_pending_impacts.erase(hit_target)
			
		# Diminuer le temps des cibles et nettoyer celles qui ont expire (raycast a rate)
		var keys = _pending_impacts.keys()
		for target in keys:
			_pending_impacts[target] -= delta
			if _pending_impacts[target] <= 0.0:
				print("[WeaponImpact] ECHEC : Le temps est écoulé (0.15s) et le raycast n'a jamais touché ", target.name if is_instance_valid(target) else "cibledetruite")
				_pending_impacts.erase(target)

func _find_attack_component_recursive(node: Node) -> AttackComponent:
	if node is AttackComponent:
		return node
	for child in node.get_children():
		var result = _find_attack_component_recursive(child)
		if result != null:
			return result
	return null

func _on_attack_landed(target: Node) -> void:
	if raycast == null or blood_particles_scene == null:
		print("[WeaponImpact] ERREUR : Raycast ou BloodParticlesScene manquant dans l'inspecteur !")
		return
	print("[WeaponImpact] Signal attack_landed recu ! Ennemi touche : ", target.name, ". Mise sur liste d'attente.")
	# On met l'ennemi dans la file d'attente (le raycast a 0.15s pour le toucher physiquement)
	_pending_impacts[target] = MAX_WAIT_TIME

func _spawn_blood(impact_point: Vector3, impact_normal: Vector3) -> void:
	# On s'assure de ne l'appeler que si on est le joueur qui donne le coup
	if not is_multiplayer_authority():
		return
	
	# call_local = on l'execute sur NOUS (le tireur) ET sur tous les autres joueurs
	rpc("_rpc_spawn_blood", impact_point, impact_normal)

@rpc("authority", "call_local", "unreliable")
func _rpc_spawn_blood(impact_point: Vector3, impact_normal: Vector3) -> void:
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
		
	print("[DEBUG] Blood particle script: ", blood.get_script())
	if blood.has_method("play_effect"):
		blood.play_effect()
	else:
		print("[ERROR] Blood particle does NOT have play_effect method!")
