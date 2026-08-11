extends Node

@export var inventory_ui: CanvasLayer
@export var spellbook_ui: CanvasLayer
@export var skill_tree_comp: Node

enum UIState { NONE, INVENTORY, SPELLBOOK, SKILL_TREE }
var current_state: UIState = UIState.NONE

func _ready() -> void:
	pass

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_toggle_ui(UIState.INVENTORY)
	elif event.is_action_pressed("toggle_spellbook") or (event is InputEventKey and event.physical_keycode == KEY_TAB and event.pressed):
		_toggle_ui(UIState.SPELLBOOK)
	elif event.is_action_pressed("toggle_passive_tree"):
		_toggle_ui(UIState.SKILL_TREE)
	elif event.is_action_pressed("ui_cancel"):
		if current_state != UIState.NONE:
			close_all_ui()
			get_viewport().set_input_as_handled()

func _toggle_ui(target_state: UIState) -> void:
	if current_state == target_state:
		# Si on réappuie sur la même touche, on ferme
		close_all_ui()
	else:
		# Sinon on ferme ce qui est ouvert et on ouvre le nouveau
		close_all_ui()
		_open_ui(target_state)

func _open_ui(state: UIState) -> void:
	current_state = state
	
	if state == UIState.INVENTORY and inventory_ui:
		inventory_ui.open_inventory()
	elif state == UIState.SPELLBOOK and spellbook_ui:
		spellbook_ui.open_spellbook()
	elif state == UIState.SKILL_TREE and skill_tree_comp:
		skill_tree_comp.open_tree()
		
	# On libère la souris pour tous les menus
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func open_inventory_with_chest(chest_inv: Node) -> void:
	if current_state != UIState.NONE:
		close_all_ui()
		
	current_state = UIState.INVENTORY
	if inventory_ui:
		inventory_ui.open_with_chest(chest_inv)
		
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_all_ui() -> void:
	if inventory_ui:
		inventory_ui.close_inventory()
	if spellbook_ui:
		spellbook_ui.close_spellbook()
	if skill_tree_comp:
		skill_tree_comp.close_tree()
		
	current_state = UIState.NONE
	# On recapture la souris pour le jeu
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
