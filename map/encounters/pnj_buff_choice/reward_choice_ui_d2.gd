class_name RewardChoiceUID2
extends CanvasLayer

signal choice_made(reward_dict: Dictionary)

@export_category("Labels & Contrôles Principaux")
@export var title_label: Label
@export var subtitle_label: Label
@export var close_button: BaseButton

@export_category("Stèle Récompense 1")
@export var card_1_root: Control
@export var card_1_hover_tex: CanvasItem
@export var card_1_glyph: TextureRect
@export var card_1_title: Label
@export var card_1_desc: Label
@export var card_1_button: BaseButton

@export_category("Stèle Récompense 2")
@export var card_2_root: Control
@export var card_2_hover_tex: CanvasItem
@export var card_2_glyph: TextureRect
@export var card_2_title: Label
@export var card_2_desc: Label
@export var card_2_button: BaseButton

@export_category("Stèle Récompense 3")
@export var card_3_root: Control
@export var card_3_hover_tex: CanvasItem
@export var card_3_glyph: TextureRect
@export var card_3_title: Label
@export var card_3_desc: Label
@export var card_3_button: BaseButton

const GLYPHS_BY_ID: Dictionary = {
	"skill_point_2": preload("res://assets/UI/moria_d2/glyphs/glyph_skill_points.png"),
	"random_spell": preload("res://assets/UI/moria_d2/glyphs/glyph_random_spell.png"),
	"heal_25_percent": preload("res://assets/UI/moria_d2/glyphs/glyph_heal.png"),
	"weapon_ilvl_camp": preload("res://assets/UI/moria_d2/glyphs/glyph_weapon_temper.png"),
	"upgrade_item_rarity": preload("res://assets/UI/moria_d2/glyphs/glyph_rarity_upgrade.png"),
	"random_item_above_rare": preload("res://assets/UI/moria_d2/glyphs/glyph_chest.png"),
	"random_weapon_above_rare": preload("res://assets/UI/moria_d2/glyphs/glyph_weapon.png"),
	"random_helmet_above_rare": preload("res://assets/UI/moria_d2/glyphs/glyph_helmet.png"),
	"random_chest_above_rare": preload("res://assets/UI/moria_d2/glyphs/glyph_chest.png"),
	"random_pants_above_rare": preload("res://assets/UI/moria_d2/glyphs/glyph_pants.png"),
	"random_boots_above_rare": preload("res://assets/UI/moria_d2/glyphs/glyph_boots.png"),
	"random_gloves_above_rare": preload("res://assets/UI/moria_d2/glyphs/glyph_gloves.png"),
}

# Palette authentique Diablo II / Moria (sobre, vieil or, argent terni, ambre forgé - zéro néon)
const COLOR_ANTIQUE_GOLD := Color(0.78, 0.70, 0.47, 1.0)     # #c7b377 Unique / Rare D2
const COLOR_TARNISHED_SILVER := Color(0.72, 0.76, 0.82, 1.0) # Argent de la Moria
const COLOR_RUNIC_SLATE_BLUE := Color(0.60, 0.68, 0.90, 1.0) # Bleu runique sourd D2
const COLOR_FORGED_AMBER := Color(0.82, 0.60, 0.40, 1.0)     # Bronze / Forge
const COLOR_ATHELAS_SAGE := Color(0.62, 0.75, 0.60, 1.0)     # Sauge / Élixir sobre
const COLOR_ITHILDIN_HOVER := Color(0.84, 0.92, 1.0, 1.0)    # Lueur lunaire Ithildin au survol

var current_choices: Array = []
var target_player: CharacterBody3D = null
var source_pnj: Node = null
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _hover_tweens: Array[Tween] = [null, null, null]
var _base_title_colors: Array[Color] = [COLOR_ANTIQUE_GOLD, COLOR_ANTIQUE_GOLD, COLOR_ANTIQUE_GOLD]

func _ready() -> void:
	if close_button != null:
		close_button.pressed.connect(close_ui)
		
	_bind_stele_interactions(card_1_root, card_1_button, 0)
	_bind_stele_interactions(card_2_root, card_2_button, 1)
	_bind_stele_interactions(card_3_root, card_3_button, 2)

func _bind_stele_interactions(root_ctrl: Control, btn: BaseButton, idx: int) -> void:
	if btn != null:
		btn.pressed.connect(_on_card_button_pressed.bind(idx))
		btn.mouse_entered.connect(_set_stele_hovered.bind(idx, true))
		btn.mouse_exited.connect(_on_stele_part_mouse_exited.bind(idx))
	if root_ctrl != null:
		root_ctrl.mouse_entered.connect(_set_stele_hovered.bind(idx, true))
		root_ctrl.mouse_exited.connect(_on_stele_part_mouse_exited.bind(idx))
		root_ctrl.gui_input.connect(_on_stele_gui_input.bind(idx))

func _on_stele_gui_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		_on_card_button_pressed(idx)

func _on_stele_part_mouse_exited(idx: int) -> void:
	var root_ctrl := _get_stele_root(idx)
	if root_ctrl != null and root_ctrl.get_global_rect().has_point(root_ctrl.get_global_mouse_position()):
		return
	_set_stele_hovered(idx, false)

func _get_stele_root(idx: int) -> Control:
	match idx:
		0: return card_1_root
		1: return card_2_root
		2: return card_3_root
	return null

func _get_stele_hover_item(idx: int) -> CanvasItem:
	match idx:
		0: return card_1_hover_tex
		1: return card_2_hover_tex
		2: return card_3_hover_tex
	return null

func _get_stele_title(idx: int) -> Label:
	match idx:
		0: return card_1_title
		1: return card_2_title
		2: return card_3_title
	return null

func _set_stele_hovered(idx: int, hovered: bool) -> void:
	var hover_item := _get_stele_hover_item(idx)
	var title_lbl := _get_stele_title(idx)
	if _hover_tweens[idx] != null and _hover_tweens[idx].is_valid():
		_hover_tweens[idx].kill()
		
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hover_tweens[idx] = tw
	if hover_item != null:
		tw.tween_property(hover_item, "modulate:a", 1.0 if hovered else 0.0, 0.18)
	if title_lbl != null:
		var target_col := COLOR_ITHILDIN_HOVER if hovered else _base_title_colors[idx]
		tw.tween_property(title_lbl, "self_modulate", target_col, 0.18)

## Ouvre l'interface en affichant les 3 récompenses tirées
func open_rewards(choices: Array, player: CharacterBody3D, pnj: Node) -> void:
	current_choices = choices
	target_player = player
	source_pnj = pnj
	
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	_setup_stele(card_1_root, card_1_hover_tex, card_1_glyph, card_1_title, card_1_desc, card_1_button, 0)
	_setup_stele(card_2_root, card_2_hover_tex, card_2_glyph, card_2_title, card_2_desc, card_2_button, 1)
	_setup_stele(card_3_root, card_3_hover_tex, card_3_glyph, card_3_title, card_3_desc, card_3_button, 2)

func _setup_stele(root_ctrl: Control, hover_item: CanvasItem, glyph_rect: TextureRect, title_lbl: Label, desc_lbl: Label, btn: BaseButton, index: int) -> void:
	if index >= current_choices.size():
		if root_ctrl != null:
			root_ctrl.visible = false
		return
		
	var choice = current_choices[index]
	if root_ctrl != null:
		root_ctrl.visible = true
	if hover_item != null:
		hover_item.modulate.a = 0.0
		
	var title_str := ""
	var desc_str := ""
	var btn_tooltip := "Claim Blessing"
	var base_col := COLOR_ANTIQUE_GOLD
	var glyph_tex: Texture2D = null
	
	if choice is RewardData:
		var rd := choice as RewardData
		title_str = rd.title.to_upper()
		desc_str = rd.description
		btn_tooltip = rd.button_text
		base_col = _resolve_d2_title_color(rd)
		glyph_tex = _resolve_glyph_texture(rd)
	elif typeof(choice) == TYPE_DICTIONARY:
		title_str = str(choice.get("title", "Reward")).to_upper()
		desc_str = str(choice.get("desc", ""))
		btn_tooltip = str(choice.get("button_text", "Choose"))
		glyph_tex = GLYPHS_BY_ID.get(str(choice.get("id", "")), GLYPHS_BY_ID["random_item_above_rare"])
		
	_base_title_colors[index] = base_col
	
	if glyph_rect != null:
		glyph_rect.texture = glyph_tex
	if title_lbl != null:
		title_lbl.text = title_str
		title_lbl.self_modulate = base_col
	if desc_lbl != null:
		desc_lbl.text = desc_str
	if btn != null:
		btn.tooltip_text = btn_tooltip

func _resolve_glyph_texture(rd: RewardData) -> Texture2D:
	# 1. Bas-relief dédié par identifiant (les 12 rewards ont chacune leur propre sculpture !)
	if GLYPHS_BY_ID.has(rd.id):
		return GLYPHS_BY_ID[rd.id]
	# 2. Icône custom si ajoutée manuellement sur une nouvelle ressource RewardData
	if rd.icon != null:
		return rd.icon
	# 3. Fallback intelligent par type de mécanique et d'équipement
	match rd.reward_type:
		RewardData.RewardType.SKILL_POINTS:
			return GLYPHS_BY_ID["skill_point_2"]
		RewardData.RewardType.RANDOM_SPELL:
			return GLYPHS_BY_ID["random_spell"]
		RewardData.RewardType.HEAL_PERCENT:
			return GLYPHS_BY_ID["heal_25_percent"]
		RewardData.RewardType.UPGRADE_WEAPON_ILVL:
			return GLYPHS_BY_ID["weapon_ilvl_camp"]
		RewardData.RewardType.UPGRADE_ITEM_RARITY:
			return GLYPHS_BY_ID["upgrade_item_rarity"]
		RewardData.RewardType.RANDOM_EQUIPMENT:
			match rd.target_item_type:
				0: return GLYPHS_BY_ID["random_weapon_above_rare"]
				1: return GLYPHS_BY_ID["random_chest_above_rare"]
				2: return GLYPHS_BY_ID["random_pants_above_rare"]
				3: return GLYPHS_BY_ID["random_boots_above_rare"]
				4: return GLYPHS_BY_ID["random_helmet_above_rare"]
				5: return GLYPHS_BY_ID["random_gloves_above_rare"]
				_: return GLYPHS_BY_ID["random_item_above_rare"]
	return GLYPHS_BY_ID["random_item_above_rare"]

func _resolve_d2_title_color(rd: RewardData) -> Color:
	match rd.reward_type:
		RewardData.RewardType.SKILL_POINTS:
			return COLOR_TARNISHED_SILVER
		RewardData.RewardType.RANDOM_SPELL, RewardData.RewardType.UPGRADE_ITEM_RARITY:
			return COLOR_RUNIC_SLATE_BLUE
		RewardData.RewardType.HEAL_PERCENT:
			return COLOR_ATHELAS_SAGE
		RewardData.RewardType.UPGRADE_WEAPON_ILVL:
			return COLOR_FORGED_AMBER
		_:
			return COLOR_ANTIQUE_GOLD

func _on_card_button_pressed(index: int) -> void:
	if index >= current_choices.size():
		return
		
	var chosen_reward = current_choices[index]
	var title_str = chosen_reward.title if chosen_reward is RewardData else chosen_reward.get("title", "")
	print("RewardChoiceUID2: Récompense sélectionnée -> ", title_str)
	
	var pnj_ref = source_pnj
	var player_ref = target_player
	
	close_ui()
	
	if pnj_ref != null and pnj_ref.has_method("apply_reward"):
		pnj_ref.apply_reward(chosen_reward, player_ref)
		
	var signal_data = chosen_reward if typeof(chosen_reward) == TYPE_DICTIONARY else { "id": chosen_reward.id, "title": chosen_reward.title }
	choice_made.emit(signal_data)

func close_ui() -> void:
	Input.mouse_mode = _previous_mouse_mode
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.physical_keycode == KEY_ESCAPE and event.pressed):
		close_ui()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.physical_keycode == KEY_E and event.pressed:
		get_viewport().set_input_as_handled()
