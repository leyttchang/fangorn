extends Node3D

var mon_lanceur: Node3D = null

# Les variables exportees pour l'inspecteur
@export var buff_data: StatusEffectData
@export var buff_duration: float = 5.0
@export var buff_radius: float = 15.0 # Le rayon d'action du buff de zone
@export var weapon_material: Material # Optionnel : un shader pour l'arme du lanceur

func execute(caster: Node3D, target_data: Dictionary) -> void:
	mon_lanceur = caster
	
	# TRES IMPORTANT : On teleporte la scene du sort sur le joueur !
	# Sinon les particules vont apparaitre au milieu de la map (0,0,0)
	global_position = caster.global_position
	
	# 1. On applique les vraies stats a TOUS les joueurs dans la zone
	# MULTIJOUEUR : Seul celui qui a lance le sort decide de qui est touche
	if buff_data != null and caster.is_multiplayer_authority():
		var all_players = get_tree().get_nodes_in_group("Player")
		for p in all_players:
			# Verification de la distance (Sphere d'effet)
			if p.global_position.distance_to(caster.global_position) <= buff_radius:
				var status_comp = p.get_node_or_null("status_effect_componant")
				if status_comp != null:
					status_comp.apply_effect(buff_data, buff_duration)
					
					# Si tu as une animation ou des particules a creer sur CHAQUE allie, tu pourrais le faire ici !
	
	# 2. On allume l'arme du lanceur visuellement ! (Optionnel)
	_set_weapon_material(weapon_material)
	
	# 3. On lance l'animation qui gere le chronometre (le VFX global)
	var anim_player = get_node_or_null("AnimationPlayer")
	if anim_player:
		anim_player.play("shout")
	else:
		# Securite si tu oublies l'AnimationPlayer
		await get_tree().create_timer(buff_duration).timeout
		queue_free()

func _exit_tree() -> void:
	# Quand l'animation se termine, on nettoie l'arme du lanceur
	_set_weapon_material(null)

func _set_weapon_material(mat: Material) -> void:
	if mon_lanceur == null or mat == null: return
	
	var main_droite = mon_lanceur.get_node_or_null("Camera3D/MainDroite")
	if main_droite:
		var meshes = main_droite.find_children("*", "MeshInstance3D", true, false)
		for mesh in meshes:
			mesh.material_overlay = mat
