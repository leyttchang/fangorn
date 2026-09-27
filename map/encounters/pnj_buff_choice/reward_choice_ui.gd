class_name RewardChoiceUI
extends CanvasLayer

signal choice_made(reward_dict: Dictionary)

@export_category("Labels Principaux")
@export var title_label: Label
@export var subtitle_label: Label
@export var close_button: Button

@export_category("Carte Récompense 1")
@export var card_1_panel: PanelContainer
@export var card_1_title: Label
@export var card_1_desc: Label
@export var card_1_button: Button

@export_category("Carte Récompense 2")
@export var card_2_panel: PanelContainer
@export var card_2_title: Label
@export var card_2_desc: Label
@export var card_2_button: Button

@export_category("Carte Récompense 3")
@export var card_3_panel: PanelContainer
@export var card_3_title: Label
@export var card_3_desc: Label
@export var card_3_button: Button

var current_choices: Array = []
var target_player: CharacterBody3D = null
var source_pnj: Node = null
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	if close_button != null:
		close_button.pressed.connect(close_ui)
		
	if card_1_button != null:
		card_1_button.pressed.connect(_on_card_button_pressed.bind(0))
	if card_2_button != null:
		card_2_button.pressed.connect(_on_card_button_pressed.bind(1))
	if card_3_button != null:
		card_3_button.pressed.connect(_on_card_button_pressed.bind(2))

## Ouvre l'interface en affichant les 3 récompenses tirées
func open_rewards(choices: Array, player: CharacterBody3D, pnj: Node) -> void:
	current_choices = choices
	target_player = player
	source_pnj = pnj
	
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	_setup_card(card_1_panel, card_1_title, card_1_desc, card_1_button, 0)
	_setup_card(card_2_panel, card_2_title, card_2_desc, card_2_button, 1)
	_setup_card(card_3_panel, card_3_title, card_3_desc, card_3_button, 2)

func _setup_card(panel: PanelContainer, title_lbl: Label, desc_lbl: Label, btn: Button, index: int) -> void:
	if index >= current_choices.size():
		if panel != null:
			panel.visible = false
		return
		
	var choice = current_choices[index]
	if panel != null:
		panel.visible = true
		
	var title_str = ""
	var desc_str = ""
	var btn_str = "Choose"
	var col = Color.WHITE
	
	if choice is RewardData:
		var rd = choice as RewardData
		title_str = rd.title
		desc_str = rd.description
		btn_str = rd.button_text
		col = rd.card_color
	elif typeof(choice) == TYPE_DICTIONARY:
		title_str = choice.get("title", "Reward")
		desc_str = choice.get("desc", "")
		btn_str = choice.get("button_text", "Choose")
		col = choice.get("color", Color.WHITE)
		
	if title_lbl != null:
		title_lbl.text = title_str
		title_lbl.modulate = col
	if desc_lbl != null:
		desc_lbl.text = desc_str
	if btn != null:
		btn.text = btn_str

func _on_card_button_pressed(index: int) -> void:
	if index >= current_choices.size():
		return
		
	var chosen_reward = current_choices[index]
	var title_str = chosen_reward.title if chosen_reward is RewardData else chosen_reward.get("title", "")
	print("RewardChoiceUI: Récompense sélectionnée -> ", title_str)
	
	var pnj_ref = source_pnj
	var player_ref = target_player
	
	close_ui()
	
	if pnj_ref != null and pnj_ref.has_method("apply_reward"):
		pnj_ref.apply_reward(chosen_reward, player_ref)
		
	var signal_data = chosen_reward if typeof(chosen_reward) == TYPE_DICTIONARY else { "id": chosen_reward.id, "title": chosen_reward.title }
	choice_made.emit(signal_data)

## Ferme l'interface et réactive la capture de la souris en jeu
func close_ui() -> void:
	Input.mouse_mode = _previous_mouse_mode
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.physical_keycode == KEY_ESCAPE and event.pressed):
		close_ui()
		get_viewport().set_input_as_handled()
