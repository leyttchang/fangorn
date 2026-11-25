class_name SpellESlot
extends Control

var slot_name: String = ""
var skill_bar: SkillBarComponent = null


func set_ability(ability: AbilityData) -> void:
	var icon_node: TextureRect = get_node_or_null("Icon") as TextureRect
	if icon_node == null:
		return
	if ability != null and ability.icon != null:
		icon_node.texture = ability.icon
		icon_node.visible = true
	else:
		icon_node.texture = null
		icon_node.visible = false


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var dict: Dictionary = data as Dictionary
	return dict.get("type", "") == "spell" and (dict.get("ability") is AbilityData)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if skill_bar != null and slot_name != "" and _can_drop_data(_at_position, data):
		var dict: Dictionary = data as Dictionary
		var dropped_ability: AbilityData = dict.get("ability") as AbilityData
		if dropped_ability != null:
			skill_bar.equip_spell(slot_name, dropped_ability)
