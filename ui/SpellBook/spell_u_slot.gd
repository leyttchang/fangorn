class_name SpellUSlot
extends Control

var ability: AbilityData

# Fonction appelée par le grimoire pour remplir la case
func set_ability(new_ability: AbilityData) -> void:
	ability = new_ability
	var icon_node = $Icon
	
	if ability != null and ability.icon != null:
		icon_node.texture = ability.icon
		icon_node.visible = true
	else:
		icon_node.texture = null
		icon_node.visible = false

# LA MAGIE : Ce qui se passe quand tu cliques et glisses
func _get_drag_data(_at_position: Vector2) -> Variant:
	if ability == null:
		return null # La case est vide, on ne peut rien attraper
		
	# 1. On crée un "fantôme" visuel qui va suivre la souris
	var preview_texture = TextureRect.new()
	preview_texture.texture = ability.icon
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.custom_minimum_size = size
	preview_texture.modulate.a = 0.7 # Rendu semi-transparent
	
	var preview_control = Control.new()
	preview_control.add_child(preview_texture)
	preview_texture.position = -0.5 * size # Centre l'image sur la souris
	
	set_drag_preview(preview_control)
	
	# 2. On emballe les données (le sort) à envoyer au slot d'équipement
	return { "type": "spell", "ability": ability }
