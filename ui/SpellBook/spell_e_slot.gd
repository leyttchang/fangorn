class_name SpellESlot
extends Control

var slot_name: String = "" # Sera défini par le manager (ex: "slot_1")
var skill_bar: SkillBarComponent # Référence vers ton joueur

func set_ability(ability: AbilityData) -> void:
	var icon_node = $Icon
	if ability != null and ability.icon != null:
		icon_node.texture = ability.icon
		icon_node.visible = true
	else:
		icon_node.texture = null
		icon_node.visible = false

# Est-ce que ce qu'on survole avec la souris est bien un sort ?
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# On vérifie qu'on a bien reçu le dictionnaire créé par le Spell_U_Slot
	return typeof(data) == TYPE_DICTIONARY and data.has("type") and data["type"] == "spell"

# Ce qui se passe quand on relâche le clic gauche
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if skill_bar != null:
		# On utilise la fonction qu'on a créée dans le composant du joueur !
		skill_bar.equip_spell(slot_name, data["ability"])
