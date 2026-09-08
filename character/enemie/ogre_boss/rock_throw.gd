extends RigidBody3D

@export var throw_speed: float = 40.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func throw_at(target_pos: Vector3) -> void:
	freeze = false
	var dir_to_target = target_pos - global_position
	var dist_2d = Vector2(dir_to_target.x, dir_to_target.z).length()
	var height_diff = target_pos.y - global_position.y # Positif si cible plus haute
	
	var total_gravity = gravity * gravity_scale
	
	var v = throw_speed
	var v2 = v * v
	var v4 = v2 * v2
	var g = total_gravity
	var x = dist_2d
	var y = height_diff
	
	# Formule pour trouver l'angle avec une vitesse fixe
	var root = v4 - g * (g * x * x + 2.0 * y * v2)
	
	var angle_rad: float
	if x < 0.01:
		angle_rad = deg_to_rad(90) if y > 0 else deg_to_rad(-90)
	elif root < 0.0:
		# La cible est trop loin pour cette vitesse !
		# On utilise l'angle optimal (proche de 45°) pour l'envoyer le plus loin possible
		angle_rad = atan2(v2, g * x)
		print("RockThrow: Cible hors de portée maximale, tir à l'angle optimal.")
	else:
		# Tir tendu (soustraire la racine = tir bas et rapide, ajouter la racine = tir en cloche)
		angle_rad = atan2(v2 - sqrt(root), g * x)
		
	var vertical_vel = v * sin(angle_rad)
	var forward_vel = v * cos(angle_rad)
	
	var throw_dir = Vector3(dir_to_target.x, 0, dir_to_target.z).normalized()
	if throw_dir == Vector3.ZERO:
		throw_dir = -global_transform.basis.z.normalized()
		
	var impulse_vel = Vector3(
		throw_dir.x * forward_vel,
		vertical_vel,
		throw_dir.z * forward_vel
	)
	
	linear_velocity = impulse_vel
	print("RockThrow: Lancé à ", snapped(rad_to_deg(angle_rad), 0.1), "° avec vélocité ", impulse_vel)
	# Désactiver l'AttackComponent après 2 secondes
	get_tree().create_timer(2.0).timeout.connect(_disable_attack)
	
	# Détruire le rocher après 5 secondes pour nettoyer la scène
	get_tree().create_timer(5.0).timeout.connect(queue_free)

func _disable_attack() -> void:
	if not is_inside_tree(): return
	var atk = find_child("AttackComponent*", true, false)
	if atk != null:
		atk.set_deferred("monitoring", false)
		atk.set_deferred("monitorable", false)
		var col = atk.get_node_or_null("CollisionShape3D")
		if col != null:
			col.set_deferred("disabled", true)
		print("RockThrow: AttackComponent désactivé.")

@rpc("authority", "call_remote", "reliable")
func rpc_set_position(pos: Vector3) -> void:
	global_position = pos
@rpc("authority", "call_local", "reliable")
func rpc_throw_at(target_pos: Vector3) -> void:
	throw_at(target_pos)
