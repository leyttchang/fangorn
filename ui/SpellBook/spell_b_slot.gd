class_name SpellBSlot
extends Panel

var slot_name: String = ""
var skill_bar: SkillBarComponent

var glow_outline: ReferenceRect
var glow_tween: Tween

func _ready() -> void:
	glow_outline = ReferenceRect.new()
	glow_outline.border_color = Color(1.0, 0.9, 0.5, 1.0) # Jaune clair / Or
	glow_outline.border_width = 3.0
	glow_outline.editor_only = false
	glow_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow_outline.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow_outline.visible = false
	add_child(glow_outline)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		var drag_data = get_viewport().gui_get_drag_data()
		if typeof(drag_data) == TYPE_DICTIONARY and drag_data.has("type") and drag_data["type"] == "spell":
			if skill_bar != null:
				_start_glow()
	elif what == NOTIFICATION_DRAG_END:
		_stop_glow()

func _start_glow() -> void:
	if glow_outline == null: return
	glow_outline.visible = true
	glow_outline.modulate.a = 0.0
	
	if glow_tween:
		glow_tween.kill()
		
	glow_tween = create_tween().set_loops()
	glow_tween.tween_property(glow_outline, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	glow_tween.tween_property(glow_outline, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE)

func _stop_glow() -> void:
	if glow_tween:
		glow_tween.kill()
		glow_tween = null
	if glow_outline:
		glow_outline.visible = false

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("type") and data["type"] == "spell"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if skill_bar != null and slot_name != "":
		skill_bar.equip_spell(slot_name, data["ability"])

