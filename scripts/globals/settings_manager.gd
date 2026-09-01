extends Node

signal mouse_sensitivity_changed(new_value: float)

var mouse_sensitivity: float = 0.002:
	set(value):
		mouse_sensitivity = value
		mouse_sensitivity_changed.emit(mouse_sensitivity)

var window_mode: int = 0: # 0 = Fullscreen, 1 = Windowed, 2 = Borderless
	set(value):
		window_mode = value
		_apply_window_mode()

const SETTINGS_FILE = "user://settings.cfg"
var config = ConfigFile.new()

func _ready() -> void:
	load_settings()

func _apply_window_mode() -> void:
	match window_mode:
		0: # Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		1: # Windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		2: # Borderless
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)

func save_settings() -> void:
	config.set_value("Controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("Video", "window_mode", window_mode)
	config.save(SETTINGS_FILE)

func load_settings() -> void:
	var err = config.load(SETTINGS_FILE)
	if err != OK:
		save_settings() # Create default settings file
		return
		
	# Load mouse sensitivity with a default fallback of 0.002
	mouse_sensitivity = config.get_value("Controls", "mouse_sensitivity", 0.002)
	window_mode = config.get_value("Video", "window_mode", 0)
