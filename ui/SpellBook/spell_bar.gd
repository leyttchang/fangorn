class_name SpellBarUI
extends Control

@export var skill_bar: SkillBarComponent

@onready var grid: Control = %inv_grid

class SlotCache:
	var slot_node: Node
	var slot_key: String
	var slot_action: StringName
	var outline: ReferenceRect
	var overlay: TextureProgressBar
	var cd_label: Label
	var icon_rect: TextureRect
	var hotkey_label: Label
	var lvl_label: Label
	var charge_label: Label
	var last_cd_tenths: int = -1
	var last_charges_shown: int = -1

var _slot_cache: Array[SlotCache] = []
var _cached_child_count: int = -1
var _spellbook_ui: Node = null


func _ready() -> void:
	if skill_bar == null:
		var p: Node = owner
		while p != null:
			if p is CharacterBody3D and p.is_in_group("Player"):
				skill_bar = p.get_node_or_null("SkillBarComponent") as SkillBarComponent
				break
			p = p.owner if p.owner != null else p.get_parent()

	if skill_bar == null:
		push_error("SpellBarUI : Le composant SkillBarComponent n'est pas assigné dans l'inspecteur.")
		return

	skill_bar.spells_updated.connect(update_all_slots)

	call_deferred("_bind_spellbook_signals")
	update_all_slots()


func _bind_spellbook_signals() -> void:
	if skill_bar == null or skill_bar.get_parent() == null:
		return
	_spellbook_ui = skill_bar.get_parent().get_node_or_null("SpellBook_UI")
	if _spellbook_ui != null:
		if _spellbook_ui.has_signal("spell_leveled_up"):
			var cb: Callable = Callable(self, "_on_spell_leveled_up")
			if not _spellbook_ui.is_connected("spell_leveled_up", cb):
				_spellbook_ui.connect("spell_leveled_up", cb)


func _on_spell_leveled_up(_ability: AbilityData, _new_lvl: int) -> void:
	update_all_slots()


func _rebuild_slot_cache() -> void:
	_slot_cache.clear()
	if grid == null:
		_cached_child_count = -1
		return
	_cached_child_count = grid.get_child_count()
	for i: int in range(_cached_child_count):
		var slot_node: Node = grid.get_child(i)
		var entry: SlotCache = SlotCache.new()
		entry.slot_node = slot_node
		entry.slot_key = "slot_" + str(i + 1)
		entry.slot_action = StringName(entry.slot_key)

		var outline: ReferenceRect = slot_node.get_node_or_null("SelectionOutline") as ReferenceRect
		if outline == null:
			outline = ReferenceRect.new()
			outline.name = "SelectionOutline"
			outline.border_color = Color.WHITE
			outline.border_width = 2.0
			outline.editor_only = false
			outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
			outline.set_anchors_preset(Control.PRESET_FULL_RECT)
			slot_node.add_child(outline)
		entry.outline = outline
		entry.overlay = slot_node.get_node_or_null("CooldownOverlay") as TextureProgressBar
		entry.cd_label = slot_node.get_node_or_null("cd") as Label
		entry.icon_rect = slot_node.get_node_or_null("Icon") as TextureRect
		var hk: Label = slot_node.get_node_or_null("Hotkey") as Label
		if hk == null:
			hk = slot_node.get_node_or_null("hotkey") as Label
		entry.hotkey_label = hk

		var lvl_lbl: Label = slot_node.get_node_or_null("SpellLvlBadge") as Label
		if lvl_lbl == null:
			lvl_lbl = Label.new()
			lvl_lbl.name = "SpellLvlBadge"
			lvl_lbl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
			lvl_lbl.offset_left = 3.0
			lvl_lbl.offset_bottom = -2.0
			lvl_lbl.offset_top = -17.0
			lvl_lbl.offset_right = 38.0
			lvl_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lvl_lbl.add_theme_font_size_override("font_size", 11)
			lvl_lbl.add_theme_color_override("font_color", Color(0.95, 0.84, 0.48, 0.96))
			lvl_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06, 0.96))
			lvl_lbl.add_theme_constant_override("outline_size", 3)
			lvl_lbl.visible = false
			slot_node.add_child(lvl_lbl)
		entry.lvl_label = lvl_lbl

		var chg_lbl: Label = slot_node.get_node_or_null("SpellChargeBadge") as Label
		if chg_lbl == null:
			chg_lbl = Label.new()
			chg_lbl.name = "SpellChargeBadge"
			chg_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			chg_lbl.offset_left = -26.0
			chg_lbl.offset_right = -3.0
			chg_lbl.offset_top = -20.0
			chg_lbl.offset_bottom = -2.0
			chg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			chg_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chg_lbl.add_theme_font_size_override("font_size", 13)
			chg_lbl.add_theme_color_override("font_color", Color(0.55, 0.94, 1.0, 0.98))
			chg_lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.08, 0.98))
			chg_lbl.add_theme_constant_override("outline_size", 4)
			chg_lbl.visible = false
			slot_node.add_child(chg_lbl)
		entry.charge_label = chg_lbl

		_slot_cache.append(entry)


func _process(_delta: float) -> void:
	if skill_bar == null or grid == null:
		return

	if grid.get_child_count() != _cached_child_count:
		_rebuild_slot_cache()

	var is_channeling: bool = skill_bar.current_state == SkillBarComponent.State.CHANNELING
	var is_spell_selected: bool = (
		skill_bar.current_state == SkillBarComponent.State.SELECTED
		or skill_bar.current_state == SkillBarComponent.State.CASTING
		or is_channeling
	)
	var selected_action: String = skill_bar.casting_action

	for entry: SlotCache in _slot_cache:
		var want_outline: bool = is_spell_selected and selected_action == entry.slot_key
		if entry.outline.visible != want_outline:
			entry.outline.visible = want_outline
		if want_outline:
			entry.outline.border_color = Color(0.45, 0.92, 1.0, 1.0) if is_channeling else Color.WHITE

		var overlay: TextureProgressBar = entry.overlay
		if overlay == null:
			continue
		var cd_label: Label = entry.cd_label
		var ability: AbilityData = skill_bar.slots.get(entry.slot_key)
		if entry.charge_label != null:
			if ability != null and ability.max_charges > 1:
				var chg: int = skill_bar.get_charges_for(ability)
				if not entry.charge_label.visible:
					entry.charge_label.visible = true
				if chg != entry.last_charges_shown:
					entry.last_charges_shown = chg
					entry.charge_label.text = "x" + str(chg)
			elif entry.charge_label.visible:
				entry.charge_label.visible = false
				entry.last_charges_shown = -1

		if ability != null:
			var timer: Timer = skill_bar.cooldown_timers.get(ability.ability_name) as Timer
			if timer != null and is_instance_valid(timer):
				if not overlay.visible:
					overlay.visible = true
				overlay.max_value = timer.wait_time
				overlay.value = timer.time_left

				if cd_label != null:
					if not cd_label.visible:
						cd_label.visible = true
					var tenths: int = int(roundf(timer.time_left * 10.0))
					if tenths != entry.last_cd_tenths:
						entry.last_cd_tenths = tenths
						cd_label.text = "%.1f" % timer.time_left
				continue

		if overlay.visible:
			overlay.visible = false
		if cd_label != null and cd_label.visible:
			cd_label.visible = false
		entry.last_cd_tenths = -1


func update_all_slots() -> void:
	if grid == null:
		return
	if grid.get_child_count() != _cached_child_count:
		_rebuild_slot_cache()

	for i: int in range(_slot_cache.size()):
		var entry: SlotCache = _slot_cache[i]
		var slot_key: String = entry.slot_key
		var slot_node: Node = entry.slot_node

		slot_node.set("slot_name", slot_key)
		slot_node.set("skill_bar", skill_bar)

		if entry.hotkey_label != null:
			var key_text: String = _get_action_key_text(entry.slot_action, i + 1)
			entry.hotkey_label.text = key_text
			entry.hotkey_label.visible = true

		if not skill_bar.slots.has(slot_key):
			continue

		var ability: AbilityData = skill_bar.slots[slot_key]
		_update_single_slot(slot_node, ability, entry.icon_rect, entry.lvl_label)


func _update_single_slot(slot_node: Node, ability: AbilityData, cached_icon: TextureRect = null, lvl_lbl: Label = null) -> void:
	var icon_rect: TextureRect = cached_icon if cached_icon != null else slot_node.get_node_or_null("Icon") as TextureRect
	if icon_rect == null:
		push_warning("SpellBarUI : Le nœud TextureRect 'Icon' est introuvable dans " + slot_node.name)
		return

	slot_node.set("ability", ability)
	if ability != null and ability.icon != null:
		icon_rect.texture = ability.icon
		icon_rect.visible = true
		slot_node.set("tooltip_text", " ")
		if lvl_lbl != null:
			if ability.category == AbilityData.AbilityCategory.MAGIC and skill_bar != null:
				var lvl: int = skill_bar.get_spell_level_for(ability)
				lvl_lbl.text = "MAX" if lvl >= ability.max_spell_level else ("Lv.%d" % lvl)
				lvl_lbl.visible = true
			else:
				lvl_lbl.visible = false
	else:
		icon_rect.texture = null
		icon_rect.visible = false
		slot_node.set("tooltip_text", "")
		if lvl_lbl != null:
			lvl_lbl.visible = false


func _get_action_key_text(action_name: StringName, fallback_number: int) -> String:
	if InputMap.has_action(action_name):
		var events: Array[InputEvent] = InputMap.action_get_events(action_name)
		for event: InputEvent in events:
			if event is InputEventKey:
				var key_ev: InputEventKey = event as InputEventKey
				var text: String = key_ev.as_text_physical_keycode()
				if text == "":
					text = OS.get_keycode_string(key_ev.keycode)
				text = text.replace("Physical", "").replace("Key", "").strip_edges()
				if text != "":
					return text
			elif event is InputEventMouseButton:
				var mb_ev: InputEventMouseButton = event as InputEventMouseButton
				return "M" + str(mb_ev.button_index)
	return str(fallback_number)
