extends Panel

@onready var sensitivity_slider: HSlider = $MarginContainer/VBoxContainer/sensitivity/Sensitivity_slider
@onready var sensitivity_label: Label = $MarginContainer/VBoxContainer/sensitivity/sensitivity_text
@onready var window_mode_btn: OptionButton = $MarginContainer/VBoxContainer/screen_option

func _ready() -> void:
	# Configure the slider bounds
	sensitivity_slider.min_value = 0.0005
	sensitivity_slider.max_value = 0.01
	sensitivity_slider.step = 0.0001
	
	# Initialiser les valeurs depuis les parametres sauvegardes
	if Engine.has_singleton("SettingsManager"):
		var settings = Engine.get_singleton("SettingsManager")
		sensitivity_slider.value = settings.mouse_sensitivity
		_update_label(settings.mouse_sensitivity)
		window_mode_btn.select(settings.window_mode)
		
		sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
		window_mode_btn.item_selected.connect(_on_window_mode_selected)
	elif get_tree().root.has_node("SettingsManager"):
		var settings = get_tree().root.get_node("SettingsManager")
		sensitivity_slider.value = settings.mouse_sensitivity
		_update_label(settings.mouse_sensitivity)
		window_mode_btn.select(settings.window_mode)
		
		sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
		window_mode_btn.item_selected.connect(_on_window_mode_selected)

func _update_label(value: float) -> void:
	# On multiplie par 1000 pour que le joueur voie "2.0" au lieu de "0.002"
	sensitivity_label.text = "%.1f" % (value * 1000.0)

func _on_sensitivity_changed(value: float) -> void:
	_update_label(value)
	
	if Engine.has_singleton("SettingsManager"):
		Engine.get_singleton("SettingsManager").mouse_sensitivity = value
		Engine.get_singleton("SettingsManager").save_settings()
	elif get_tree().root.has_node("SettingsManager"):
		var settings = get_tree().root.get_node("SettingsManager")
		settings.mouse_sensitivity = value
		settings.save_settings()

func _on_window_mode_selected(index: int) -> void:
	if Engine.has_singleton("SettingsManager"):
		Engine.get_singleton("SettingsManager").window_mode = index
		Engine.get_singleton("SettingsManager").save_settings()
	elif get_tree().root.has_node("SettingsManager"):
		var settings = get_tree().root.get_node("SettingsManager")
		settings.window_mode = index
		settings.save_settings()
