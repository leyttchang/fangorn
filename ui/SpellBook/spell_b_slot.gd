class_name SpellBSlot
extends Panel

var slot_name: String = ""
var skill_bar: SkillBarComponent = null
var ability: AbilityData = null

var glow_outline: ReferenceRect = null
var glow_tween: Tween = null


func _ready() -> void:
	glow_outline = ReferenceRect.new()
	glow_outline.border_color = Color(1.0, 0.9, 0.5, 1.0)
	glow_outline.border_width = 3.0
	glow_outline.editor_only = false
	glow_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow_outline.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow_outline.visible = false
	add_child(glow_outline)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		var drag_data: Variant = get_viewport().gui_get_drag_data()
		if _is_valid_spell_drag(drag_data) and skill_bar != null:
			_start_glow()
	elif what == NOTIFICATION_DRAG_END:
		_stop_glow()


static func _is_valid_spell_drag(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var dict: Dictionary = data as Dictionary
	return dict.get("type", "") == "spell" and (dict.get("ability") is AbilityData)


func _start_glow() -> void:
	if glow_outline == null:
		return
	glow_outline.visible = true
	glow_outline.modulate.a = 0.0

	if glow_tween != null:
		glow_tween.kill()

	glow_tween = create_tween().set_loops()
	glow_tween.tween_property(glow_outline, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	glow_tween.tween_property(glow_outline, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE)


func _stop_glow() -> void:
	if glow_tween != null:
		glow_tween.kill()
		glow_tween = null
	if glow_outline != null:
		glow_outline.visible = false


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return _is_valid_spell_drag(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if skill_bar != null and slot_name != "" and _is_valid_spell_drag(data):
		var dict: Dictionary = data as Dictionary
		var dropped_ability: AbilityData = dict.get("ability") as AbilityData
		if dropped_ability != null:
			skill_bar.equip_spell(slot_name, dropped_ability)


func _make_custom_tooltip(_for_text: String) -> Object:
	if ability == null:
		return null

	var tooltip_scene: PackedScene = preload("res://ui/inventaire/Spell_tooltip.tscn")
	var tooltip: Node = tooltip_scene.instantiate()
	if tooltip.has_method("setup"):
		tooltip.call("setup", ability)
	return tooltip
