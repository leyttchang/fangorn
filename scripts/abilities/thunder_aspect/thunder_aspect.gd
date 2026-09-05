extends Node3D

var mon_lanceur: Node3D = null

# Tu peux glisser ton res://scripts/status_effects/shock/shock_shader.tres ici dans l'inspecteur !
@export var weapon_material: Material

# Tu peux glisser ton buff de stats (StatusEffectData) ici !
@export var buff_data: StatusEffectData
# Optionnel: on peut aussi utiliser la duree de l'animation pour la duree du buff
@export var buff_duration: float = 5.0

func execute(caster: Node3D, target_data: Dictionary) -> void:
	mon_lanceur = caster
	global_position = caster.global_position
	
	# 1. On applique les vraies stats (Le buff de degats/vitesse)
	# MULTIJOUEUR : Seul le lanceur applique l'effet pour eviter que tout le monde envoie la commande en meme temps
	if buff_data != null and caster.is_multiplayer_authority():
		var status_comp = caster.get_node_or_null("status_effect_componant")
		if status_comp != null:
			status_comp.apply_effect(buff_data, buff_duration)
	
	# 2. On allume l'arme visuellement !
	_set_weapon_material(weapon_material)
	
	# 3. On lance l'animation qui gere le chronometre (le VFX de l'arme)
	var anim_player = get_node_or_null("AnimationPlayer")
	if anim_player:
		anim_player.play("buff_duration")
	else:
		# Securite si tu oublies l'AnimationPlayer
		await get_tree().create_timer(buff_duration).timeout
		queue_free()

func _exit_tree() -> void:
	# 3. Quand l'animation se termine (et detruit la scene avec queue_free), on nettoie l'arme
	_set_weapon_material(null)

func _set_weapon_material(mat: Material) -> void:
	if mon_lanceur == null: return
	
	# On trouve la main droite
	# On trouve la main droite
	var main_droite = mon_lanceur.get_node_or_null("%MainDroite")
	if main_droite:
		var current_weapon = main_droite._get_actual_weapon()
		var meshes = []
		if current_weapon and "blade_meshes" in current_weapon and not current_weapon.blade_meshes.is_empty():
			meshes = current_weapon.blade_meshes
		else:
			meshes = main_droite.find_children("*", "MeshInstance3D", true, false)
			
		for mesh in meshes:
			if mesh != null:
				mesh.material_overlay = mat
