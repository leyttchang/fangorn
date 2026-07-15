extends Marker3D

@onready var player_stats: StatsComponent = owner.get_node("StatsComponent")

# N'oublie pas de vérifier que ce chemin pointe bien vers ton nœud AnimationPlayer !
@onready var anim_player: AnimationPlayer =  %attack_animation
@onready var equipment: EquipmentComponent = owner.get_node("EquipmentComponent")
var is_attacking = false
var current_weapon: Node3D = null

func _input(event):
	# SÉCURITÉ : Si la souris est libre sur l'écran (inventaire ouvert), on bloque l'attaque
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		return
		
	if event.is_action_pressed("r_click") and not is_attacking:
		attack()

func attack():
	# 1. SÉCURITÉ : Si la main est vide, on annule
	if get_child_count() == 0:
		return
		
	# 2. On récupère l'arme dynamiquement
	current_weapon = get_child(0)
	
	# 3. On vérifie que l'arme possède bien une hitbox
	var attack_shape = current_weapon.get_node_or_null("AttackComponent/CollisionShape3D")
	if attack_shape == null:
		return
		
	is_attacking = true
	
	# 4. On prépare l'arme pour le nouveau coup
	current_weapon.attack_component.reset_hit_entities() 
	current_weapon.update_damage_from_stats(player_stats)
	
	# 5. On calcule la vitesse d'attaque finale
	var total_atk_speed = current_weapon.get_combined_attack_speed(player_stats)
	
	# 6. On demande à l'EquipmentComponent quel fichier .tres est dans la main droite
	var equipped_item = equipment.equipped_items["main_hand"] as WeaponItem
	var anim_name
	if equipped_item != null:
		var style_enum = equipped_item.weapon_style
		var style_string = WeaponItem.WeaponStyle.keys()[style_enum].to_lower()
		anim_name = "attack_" + style_string 
		

	
	# 7. On joue l'animation correspondante
	if anim_player.has_animation(anim_name):
		
		# CORRECTION 1 : On force le nettoyage de l'AnimationPlayer avant de jouer
		anim_player.stop() 
		
		anim_player.play(anim_name, -1.0, total_atk_speed)
		await anim_player.animation_finished
	else:
		push_warning("Animation introuvable : ", anim_name)
	
	# 8. SÉCURITÉ : On s'assure que la hitbox est désactivée
	disable_current_hitbox()
	
	# CORRECTION 2 : On ajoute un minuscule délai (0.1 seconde) avant de libérer le joueur.
	# Ça empêche le jeu de détecter un double-clic involontaire quand l'attaque est trop rapide !
	await get_tree().create_timer(0.1).timeout 
	
	is_attacking = false

# --- FONCTIONS APPELÉES PAR L'ANIMATION PLAYER ---

# À insérer (Call Method Track) au moment de l'impact dans l'animation
func enable_current_hitbox():
	if is_instance_valid(current_weapon):
		var shape = current_weapon.get_node_or_null("AttackComponent/CollisionShape3D")
		if is_instance_valid(shape):
			shape.set_deferred("disabled", false)

# À insérer (Call Method Track) à la fin du mouvement dans l'animation
func disable_current_hitbox():
	if is_instance_valid(current_weapon):
		var shape = current_weapon.get_node_or_null("AttackComponent/CollisionShape3D")
		if is_instance_valid(shape):
			shape.set_deferred("disabled", true)
