extends VBoxContainer

var keybind_file_path = "user://keybinds.cfg"
var waiting_for_input: bool = false
var button_waiting: Button = null
var action_waiting: String = ""

# Liste de toutes les actions qu'on veut rendre modifiables
var actions_to_map = {
	"forward": "Forward",
	"backward": "Backward",
	"left": "Left",
	"right": "Right",
	"jump": "Jump",
	"r_click": "Attack",
	"switch_weapons": "Switch Weapons",
	"toggle_inventory": "Inventory",
	"toggle_spellbook": "Spellbook",
	"toggle_passive_tree": "Passive Tree",
	"slot_1": "Skill 1",
	"slot_2": "Skill 2",
	"slot_3": "Skill 3",
	"slot_4": "Skill 4",
	"slot_5": "Skill 5",
	"slot_6": "Skill 6"
}

func _ready() -> void:
	# Charger les touches sauvegardées au lancement
	load_keybinds()
	
	# Vider le conteneur s'il y a des vieux trucs dedans
	for child in get_children():
		if child.name != "return":
			child.queue_free()
		
	# Générer le menu dynamiquement !
	for action_name in actions_to_map.keys():
		var display_name = actions_to_map[action_name]
		
		# Créer la ligne
		var hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		# Créer le texte
		var label = Label.new()
		label.text = display_name
		label.custom_minimum_size = Vector2(150, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		
		# Espacement
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(20, 0)
		
		# Créer le bouton
		var button = Button.new()
		button.name = action_name # On lui donne le nom de l'action
		button.custom_minimum_size = Vector2(150, 0)
		
		# Lier le bouton
		button.pressed.connect(_on_button_pressed.bind(button, action_name))
		_update_button_text(button, action_name)
		
		# Ajouter à la ligne, puis au VBox
		hbox.add_child(label)
		hbox.add_child(spacer)
		hbox.add_child(button)
		add_child(hbox)
		
	# Mettre le bouton return tout à la fin s'il existe
	var return_btn = get_node_or_null("return")
	if return_btn != null:
		move_child(return_btn, -1)

func _on_button_pressed(button: Button, action_name: String) -> void:
	if waiting_for_input: return
	
	waiting_for_input = true
	button_waiting = button
	action_waiting = action_name
	
	button.text = "Press any key..."

func _input(event: InputEvent) -> void:
	if not waiting_for_input:
		return
		
	# On accepte uniquement les touches clavier ou les boutons de souris
	if event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed():
			# On efface l'ancienne touche
			InputMap.action_erase_events(action_waiting)
			# On ajoute la nouvelle touche
			InputMap.action_add_event(action_waiting, event)
			
			_update_button_text(button_waiting, action_waiting)
			save_keybinds()
			
			waiting_for_input = false
			button_waiting = null
			action_waiting = ""
			
			# Indique à Godot que l'input a été consommé
			get_viewport().set_input_as_handled()

func _update_button_text(button: Button, action_name: String) -> void:
	var events = InputMap.action_get_events(action_name)
	if events.size() > 0:
		var event = events[0]
		if event is InputEventKey:
			var text = event.as_text_physical_keycode()
			if text == "": text = OS.get_keycode_string(event.keycode)
			button.text = text.replace("Physical", "").replace("Key", "").strip_edges()
		elif event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT: button.text = "Left Click"
			elif event.button_index == MOUSE_BUTTON_RIGHT: button.text = "Right Click"
			elif event.button_index == MOUSE_BUTTON_MIDDLE: button.text = "Middle Click"
			else: button.text = "Mouse " + str(event.button_index)
	else:
		button.text = "Unassigned"

# --- SYSTÈME DE SAUVEGARDE ---

func save_keybinds() -> void:
	var config = ConfigFile.new()
	for action in InputMap.get_actions():
		if not action.begins_with("ui_"):
			var events = InputMap.action_get_events(action)
			if events.size() > 0:
				config.set_value("Keybinds", action, events[0])
	config.save(keybind_file_path)

func load_keybinds() -> void:
	var config = ConfigFile.new()
	if config.load(keybind_file_path) == OK:
		for action in config.get_section_keys("Keybinds"):
			var event = config.get_value("Keybinds", action)
			if InputMap.has_action(action):
				InputMap.action_erase_events(action)
				InputMap.action_add_event(action, event)

