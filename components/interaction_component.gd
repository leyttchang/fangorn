class_name InteractionComponent
extends Area3D

## Le texte d'interaction affiché au-dessus de l'objet (le jeton [F] suit automatiquement le bind de l'action)
@export var prompt_text: String = "Press [F] to interact":
	set(value):
		prompt_text = value
		_refresh_label_text()

## Action InputMap utilisée pour déclencher l'interaction (par défaut "interact" = F)
@export var interaction_action: StringName = &"interact"

@onready var prompt_label: Label3D = $Label3D if has_node("Label3D") else null

func _ready() -> void:
	if not Engine.is_editor_hint() and is_inside_tree() and get_tree() != null:
		var sm: Node = get_tree().root.get_node_or_null("SettingsManager")
		if sm != null and sm.has_signal("keybinds_changed"):
			if not sm.is_connected("keybinds_changed", _refresh_label_text):
				sm.connect("keybinds_changed", _refresh_label_text)
	if prompt_label != null:
		prompt_label.text = get_formatted_prompt()
		prompt_label.hide()
		prompt_label.top_level = true # Détache le label pour ignorer la rotation du parent (RigidBody)

func _process(_delta: float) -> void:
	if prompt_label != null and prompt_label.visible:
		# On le maintient toujours strictement au-dessus, peu importe comment le parent tourne
		prompt_label.global_position = global_position + Vector3(0, 1.5 * scale.y, 0)

func get_formatted_prompt() -> String:
	if Engine.is_editor_hint():
		return prompt_text
	var act: StringName = interaction_action if not interaction_action.is_empty() else &"interact"
	return InteractionComponent.format_action_prompt(prompt_text, act)

static func get_action_key_label(action_name: StringName = &"interact", fallback: String = "F") -> String:
	if not InputMap.has_action(action_name):
		return fallback
	var events: Array[InputEvent] = InputMap.action_get_events(action_name)
	if events.is_empty():
		return fallback
	var ev: InputEvent = events[0]
	if ev is InputEventKey:
		var key_ev: InputEventKey = ev as InputEventKey
		var text: String = key_ev.as_text_physical_keycode()
		if text.is_empty():
			text = OS.get_keycode_string(key_ev.keycode)
		text = text.replace("Physical", "").replace("Key", "").strip_edges()
		if not text.is_empty():
			return text
	elif ev is InputEventMouseButton:
		var mb_ev: InputEventMouseButton = ev as InputEventMouseButton
		match mb_ev.button_index:
			MOUSE_BUTTON_LEFT:
				return "LMB"
			MOUSE_BUTTON_RIGHT:
				return "RMB"
			MOUSE_BUTTON_MIDDLE:
				return "MMB"
			_:
				return "Mouse %d" % int(mb_ev.button_index)
	return fallback

static func format_action_prompt(raw_text: String, action_name: StringName = &"interact") -> String:
	if raw_text.is_empty():
		return raw_text
	var key_txt: String = get_action_key_label(action_name, "F")
	var bracket_key: String = "[%s]" % key_txt
	var formatted: String = raw_text
	formatted = formatted.replace("{interact}", bracket_key)
	formatted = formatted.replace("[F]", bracket_key).replace("[E]", bracket_key)
	if formatted.find("Press F ") >= 0:
		formatted = formatted.replace("Press F ", "Press %s " % bracket_key)
	if formatted.find("Press E ") >= 0:
		formatted = formatted.replace("Press E ", "Press %s " % bracket_key)
	if formatted.find("Hold F ") >= 0:
		formatted = formatted.replace("Hold F ", "Hold %s " % bracket_key)
	if formatted.find("Hold E ") >= 0:
		formatted = formatted.replace("Hold E ", "Hold %s " % bracket_key)
	return formatted

func _refresh_label_text() -> void:
	if prompt_label != null and is_instance_valid(prompt_label):
		prompt_label.text = get_formatted_prompt()

func show_prompt() -> void:
	if prompt_label != null:
		prompt_label.text = get_formatted_prompt()
		prompt_label.show()

func hide_prompt() -> void:
	if prompt_label != null:
		prompt_label.hide()

func trigger_interaction(player: Node3D) -> void:
	var parent: Node = get_parent()
	if parent != null:
		if parent.has_method("use"):
			parent.use(player)
		elif parent.has_method("interact"):
			parent.interact(player)
		elif parent.has_method("open_chest"):
			parent.player_in_range = player
			parent.open_chest()
