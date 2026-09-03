extends Panel

@onready var sensitivity_slider: HSlider = $MarginContainer/VBoxContainer/sensitivity/Sensitivity_slider
@onready var sensitivity_label: Label = $MarginContainer/VBoxContainer/sensitivity/sensitivity_text
@onready var window_mode_btn: OptionButton = $MarginContainer/VBoxContainer/screen_option

@onready var render_scale_slider: HSlider = $MarginContainer/VBoxContainer/RenderScale/RenderScale_slider
@onready var render_scale_label: Label = $MarginContainer/VBoxContainer/RenderScale/RenderScale_text
@onready var fsr_mode_btn: OptionButton = $MarginContainer/VBoxContainer/RenderScale/fsr_option
@onready var fps_cap_input: LineEdit = $MarginContainer/VBoxContainer/FPs/fps_cap_text
@onready var vsync_btn: CheckButton = $MarginContainer/VBoxContainer/FPs/Vsyinc_buton
@onready var shadow_btn: OptionButton = $MarginContainer/VBoxContainer/Shadow/Shadow_selection
@onready var render_distance_btn: OptionButton = $MarginContainer/VBoxContainer/render_distance/OptionButton

func _ready() -> void:
	# Configure the sliders bounds
	sensitivity_slider.min_value = 0.0005
	sensitivity_slider.max_value = 0.01
	sensitivity_slider.step = 0.0001
	
	render_scale_slider.min_value = 0.5
	render_scale_slider.max_value = 1.0
	render_scale_slider.step = 0.05
	
	# Initialiser les valeurs depuis les parametres sauvegardes
	if Engine.has_singleton("SettingsManager"):
		var settings = Engine.get_singleton("SettingsManager")
		sensitivity_slider.value = settings.mouse_sensitivity
		_update_label(settings.mouse_sensitivity)
		window_mode_btn.select(settings.window_mode)
		
		render_scale_slider.value = settings.render_scale
		_update_render_scale_label(settings.render_scale)
		fsr_mode_btn.select(settings.fsr_mode)
		
		_update_fps_input(settings.fps_cap)
		vsync_btn.button_pressed = settings.vsync
		shadow_btn.select(settings.shadow_quality)
		render_distance_btn.select(settings.render_distance)
		
		sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
		window_mode_btn.item_selected.connect(_on_window_mode_selected)
		render_scale_slider.value_changed.connect(_on_render_scale_changed)
		fsr_mode_btn.item_selected.connect(_on_fsr_mode_selected)
		fps_cap_input.text_changed.connect(_on_fps_cap_changed)
		vsync_btn.toggled.connect(_on_vsync_toggled)
		shadow_btn.item_selected.connect(_on_shadow_quality_selected)
		render_distance_btn.item_selected.connect(_on_render_distance_selected)
		
	elif get_tree().root.has_node("SettingsManager"):
		var settings = get_tree().root.get_node("SettingsManager")
		sensitivity_slider.value = settings.mouse_sensitivity
		_update_label(settings.mouse_sensitivity)
		window_mode_btn.select(settings.window_mode)
		
		render_scale_slider.value = settings.render_scale
		_update_render_scale_label(settings.render_scale)
		fsr_mode_btn.select(settings.fsr_mode)
		
		_update_fps_input(settings.fps_cap)
		vsync_btn.button_pressed = settings.vsync
		shadow_btn.select(settings.shadow_quality)
		render_distance_btn.select(settings.render_distance)
		
		
		sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
		window_mode_btn.item_selected.connect(_on_window_mode_selected)
		render_scale_slider.value_changed.connect(_on_render_scale_changed)
		fsr_mode_btn.item_selected.connect(_on_fsr_mode_selected)
		fps_cap_input.text_changed.connect(_on_fps_cap_changed)
		vsync_btn.toggled.connect(_on_vsync_toggled)
		shadow_btn.item_selected.connect(_on_shadow_quality_selected)
		render_distance_btn.item_selected.connect(_on_render_distance_selected)
		

func _update_fps_input(cap: int) -> void:
	if cap <= 0:
		fps_cap_input.text = "0"
	else:
		fps_cap_input.text = str(cap)

func _update_label(value: float) -> void:
	# On multiplie par 1000 pour que le joueur voie "2.0" au lieu de "0.002"
	sensitivity_label.text = "%.1f" % (value * 1000.0)

func _update_render_scale_label(value: float) -> void:
	# Affiche en pourcentage, ex: "75%"
	render_scale_label.text = "%d%%" % int(value * 100)

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

func _on_render_scale_changed(value: float) -> void:
	_update_render_scale_label(value)
	
	if Engine.has_singleton("SettingsManager"):
		Engine.get_singleton("SettingsManager").render_scale = value
		Engine.get_singleton("SettingsManager").save_settings()
	elif get_tree().root.has_node("SettingsManager"):
		var settings = get_tree().root.get_node("SettingsManager")
		settings.render_scale = value
		settings.save_settings()

func _on_fsr_mode_selected(index: int) -> void:
	if Engine.has_singleton("SettingsManager"):
		Engine.get_singleton("SettingsManager").fsr_mode = index
		Engine.get_singleton("SettingsManager").save_settings()
	elif get_tree().root.has_node("SettingsManager"):
		var settings = get_tree().root.get_node("SettingsManager")
		settings.fsr_mode = index
		settings.save_settings()

func _on_fps_cap_changed(new_text: String) -> void:
	if not new_text.is_valid_int() and new_text != "":
		# Revert to last valid number if they type letters
		if Engine.has_singleton("SettingsManager"):
			_update_fps_input(Engine.get_singleton("SettingsManager").fps_cap)
		return
		
	var cap = new_text.to_int()
	if cap < 0:
		cap = 0
		
	if Engine.has_singleton("SettingsManager"):
		Engine.get_singleton("SettingsManager").fps_cap = cap
		Engine.get_singleton("SettingsManager").save_settings()
	elif get_tree().root.has_node("SettingsManager"):
		var settings = get_tree().root.get_node("SettingsManager")
		settings.fps_cap = cap
		settings.save_settings()

func _on_vsync_toggled(toggled_on: bool) -> void:
	if Engine.has_singleton("SettingsManager"):
		Engine.get_singleton("SettingsManager").vsync = toggled_on
		Engine.get_singleton("SettingsManager").save_settings()
	elif get_tree().root.has_node("SettingsManager"):
		var settings = get_tree().root.get_node("SettingsManager")
		settings.vsync = toggled_on
		settings.save_settings()

func _on_shadow_quality_selected(index: int) -> void:
	if Engine.has_singleton("SettingsManager"):
		Engine.get_singleton("SettingsManager").shadow_quality = index
		Engine.get_singleton("SettingsManager").save_settings()
	elif get_tree().root.has_node("SettingsManager"):
		var settings = get_tree().root.get_node("SettingsManager")
		settings.shadow_quality = index
		settings.save_settings()

func _on_render_distance_selected(index: int) -> void:
	if Engine.has_singleton("SettingsManager"):
		Engine.get_singleton("SettingsManager").render_distance = index
		Engine.get_singleton("SettingsManager").save_settings()
	elif get_tree().root.has_node("SettingsManager"):
		var settings = get_tree().root.get_node("SettingsManager")
		settings.render_distance = index
		settings.save_settings()

	if Engine.has_singleton("SettingsManager"):
		Engine.get_singleton("SettingsManager").save_settings()
	elif get_tree().root.has_node("SettingsManager"):
		var settings = get_tree().root.get_node("SettingsManager")
		settings.save_settings()
