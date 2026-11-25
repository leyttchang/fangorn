class_name SpellUSlot
extends Panel

signal slot_selected(slot_ability: AbilityData)

var ability: AbilityData = null
var spellbook_ref: Node = null
var is_selected_in_book: bool = false

var _tier_label: Label = null
var _lvl_label: Label = null
var _evo_badge: Label = null
var _xp_bg: ColorRect = null
var _xp_fill: ColorRect = null
var _sel_border: ReferenceRect = null


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_ensure_overlay_nodes()


func _ensure_overlay_nodes() -> void:
	if _sel_border == null:
		_sel_border = ReferenceRect.new()
		_sel_border.name = "SelectedBorder"
		_sel_border.set_anchors_preset(Control.PRESET_FULL_RECT)
		_sel_border.editor_only = false
		_sel_border.border_width = 2.0
		_sel_border.border_color = Color(0.95, 0.78, 0.35, 1.0)
		_sel_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sel_border.visible = false
		add_child(_sel_border)

	if _tier_label == null:
		_tier_label = Label.new()
		_tier_label.name = "TierBadge"
		_tier_label.position = Vector2(4.0, 2.0)
		_tier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tier_label.add_theme_font_size_override("font_size", 11)
		_tier_label.add_theme_color_override("font_color", Color(0.86, 0.80, 0.64, 0.95))
		_tier_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.96))
		_tier_label.add_theme_constant_override("outline_size", 3)
		_tier_label.visible = false
		add_child(_tier_label)

	if _evo_badge == null:
		_evo_badge = Label.new()
		_evo_badge.name = "EvoReadyBadge"
		_evo_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_evo_badge.offset_left = -22.0
		_evo_badge.offset_right = -4.0
		_evo_badge.offset_top = 1.0
		_evo_badge.offset_bottom = 20.0
		_evo_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_evo_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_evo_badge.text = "▲"
		_evo_badge.add_theme_font_size_override("font_size", 13)
		_evo_badge.add_theme_color_override("font_color", Color(1.0, 0.84, 0.25, 1.0))
		_evo_badge.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.01, 0.98))
		_evo_badge.add_theme_constant_override("outline_size", 4)
		_evo_badge.visible = false
		add_child(_evo_badge)

	if _lvl_label == null:
		_lvl_label = Label.new()
		_lvl_label.name = "LvlBadge"
		_lvl_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_lvl_label.offset_left = 4.0
		_lvl_label.offset_right = 56.0
		_lvl_label.offset_top = -22.0
		_lvl_label.offset_bottom = -6.0
		_lvl_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lvl_label.add_theme_font_size_override("font_size", 11)
		_lvl_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.78, 0.96))
		_lvl_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.96))
		_lvl_label.add_theme_constant_override("outline_size", 3)
		_lvl_label.visible = false
		add_child(_lvl_label)

	if _xp_bg == null:
		_xp_bg = ColorRect.new()
		_xp_bg.name = "XPBarBG"
		_xp_bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_xp_bg.offset_left = 3.0
		_xp_bg.offset_right = -3.0
		_xp_bg.offset_top = -5.0
		_xp_bg.offset_bottom = -2.0
		_xp_bg.color = Color(0.06, 0.07, 0.10, 0.88)
		_xp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_xp_bg.visible = false
		add_child(_xp_bg)

		_xp_fill = ColorRect.new()
		_xp_fill.name = "XPBarFill"
		_xp_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		_xp_fill.anchor_right = 0.0
		_xp_fill.offset_right = 0.0
		_xp_fill.color = Color(0.88, 0.70, 0.28, 0.95)
		_xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_xp_bg.add_child(_xp_fill)


func set_selected_visual(selected: bool) -> void:
	is_selected_in_book = selected
	_ensure_overlay_nodes()
	if _sel_border != null:
		_sel_border.visible = selected and (ability != null)


func set_ability(new_ability: AbilityData, book: Node = null) -> void:
	if book != null:
		spellbook_ref = book
	ability = new_ability
	_ensure_overlay_nodes()

	var icon_node: TextureRect = get_node_or_null("Icon") as TextureRect
	var cd_lbl: Label = get_node_or_null("cd") as Label
	if cd_lbl != null:
		cd_lbl.visible = false

	if ability != null and ability.icon != null:
		if icon_node != null:
			icon_node.texture = ability.icon
			icon_node.visible = true
			icon_node.offset_left = 6.0
			icon_node.offset_top = 6.0
			icon_node.offset_right = -6.0
			icon_node.offset_bottom = -8.0
		tooltip_text = " "
		_refresh_progression_badges()
	else:
		if icon_node != null:
			icon_node.texture = null
			icon_node.visible = false
		tooltip_text = ""
		_tier_label.visible = false
		_lvl_label.visible = false
		_evo_badge.visible = false
		_xp_bg.visible = false
		if _sel_border != null:
			_sel_border.visible = false


func _refresh_progression_badges() -> void:
	if ability == null:
		return

	if ability.category == AbilityData.AbilityCategory.WEAPON_ATTACK:
		_tier_label.text = "ATK"
		_tier_label.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62, 0.92))
		_tier_label.visible = true
		_lvl_label.visible = false
		_evo_badge.visible = false
		_xp_bg.visible = false
		return

	var roman: String = "I"
	if ability.tier == 2:
		roman = "II"
	elif ability.tier >= 3:
		roman = "III"
	_tier_label.text = "T-" + roman
	_tier_label.add_theme_color_override("font_color", _get_element_accent(ability.element))
	_tier_label.visible = true

	var cur_lvl: int = 1
	var cur_xp: int = 0
	var evo_ready: bool = false
	if spellbook_ref != null:
		if spellbook_ref.has_method("get_spell_level"):
			cur_lvl = int(spellbook_ref.call("get_spell_level", ability))
		if spellbook_ref.has_method("get_spell_xp"):
			cur_xp = int(spellbook_ref.call("get_spell_xp", ability))
		if spellbook_ref.has_method("has_ready_evolution"):
			evo_ready = bool(spellbook_ref.call("has_ready_evolution", ability))

	var is_max: bool = cur_lvl >= ability.max_spell_level
	_lvl_label.text = "MAX" if is_max else ("Lv.%d/%d" % [cur_lvl, ability.max_spell_level])
	_lvl_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.86, 0.36, 1.0) if is_max else Color(0.92, 0.90, 0.84, 0.95)
	)
	_lvl_label.visible = true
	_evo_badge.visible = evo_ready

	_xp_bg.visible = true
	var ratio: float = 1.0
	if not is_max:
		var req: int = maxi(1, ability.get_xp_for_next_level(cur_lvl))
		ratio = clampf(float(cur_xp) / float(req), 0.0, 1.0)
	_xp_fill.anchor_right = ratio
	_xp_fill.color = Color(0.38, 0.92, 0.65, 0.95) if is_max else Color(0.90, 0.72, 0.28, 0.95)

	if _sel_border != null:
		_sel_border.visible = is_selected_in_book


static func _get_element_accent(elem: String) -> Color:
	match elem.to_lower():
		"fire":
			return Color(1.0, 0.52, 0.24, 1.0)
		"arcane":
			return Color(0.82, 0.52, 1.0, 1.0)
		"ice":
			return Color(0.48, 0.88, 1.0, 1.0)
		"lightning":
			return Color(0.98, 0.88, 0.32, 1.0)
		_:
			return Color(0.85, 0.80, 0.66, 1.0)


func _gui_input(event: InputEvent) -> void:
	if ability == null:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			slot_selected.emit(ability)


func _make_custom_tooltip(_for_text: String) -> Object:
	if ability == null:
		return null

	var tooltip_scene: PackedScene = preload("res://ui/inventaire/Spell_tooltip.tscn")
	var tooltip: Node = tooltip_scene.instantiate()
	if tooltip.has_method("setup"):
		tooltip.call("setup", ability)
	return tooltip


func _get_drag_data(_at_position: Vector2) -> Variant:
	if ability == null:
		return null

	slot_selected.emit(ability)

	var preview_texture: TextureRect = TextureRect.new()
	preview_texture.texture = ability.icon
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.custom_minimum_size = Vector2(64.0, 64.0)
	preview_texture.modulate.a = 0.75

	var preview_control: Control = Control.new()
	preview_control.add_child(preview_texture)
	preview_texture.position = -0.5 * Vector2(64.0, 64.0)

	set_drag_preview(preview_control)
	return { "type": "spell", "ability": ability }
