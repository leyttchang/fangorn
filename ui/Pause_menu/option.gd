extends Panel

@onready var sensitivity_slider: HSlider = find_child("Sensitivity_slider", true, false)
@onready var sensitivity_label: Label = find_child("sensitivity_text", true, false)
@onready var window_mode_btn: OptionButton = find_child("screen_option", true, false)

@onready var render_scale_slider: HSlider = find_child("RenderScale_slider", true, false)
@onready var render_scale_label: Label = find_child("RenderScale_text", true, false)
@onready var fsr_mode_btn: OptionButton = find_child("fsr_option", true, false)
@onready var fps_cap_input: LineEdit = find_child("fps_cap_text", true, false)
@onready var vsync_btn: CheckButton = find_child("Vsyinc_buton", true, false)
@onready var shadow_btn: OptionButton = find_child("Shadow_selection", true, false)
@onready var render_distance_btn: OptionButton = find_child("render_distance", true, false).find_child("OptionButton", true, false)

# Boutons d'effets graphiques
@onready var ssil_btn: CheckButton = find_child("ssil_button", true, false)
@onready var ssao_btn: CheckButton = find_child("ssao_button", true, false)
@onready var vfog_btn: CheckButton = find_child("vfog_button", true, false)
@onready var glow_btn: CheckButton = find_child("glow_button", true, false)

@onready var keybinds_menu_btn: Button = find_child("Keybind", true, false)
@onready var keybinds_panel: Panel = $Panel
@onready var keybinds_return_btn: Button = $Panel/MarginContainer2/VBoxContainer/return

func _ready() -> void:
	# Masquer le panel de keybinds par défaut
	if keybinds_panel:
		keybinds_panel.hide()
		
	if keybinds_menu_btn:
		keybinds_menu_btn.pressed.connect(func(): keybinds_panel.show())
		
	if keybinds_return_btn:
		keybinds_return_btn.pressed.connect(func(): keybinds_panel.hide())
		
	# Configure the sliders bounds
	if sensitivity_slider:
		sensitivity_slider.min_value = 0.0005
		sensitivity_slider.max_value = 0.01
		sensitivity_slider.step = 0.0001
	
	if render_scale_slider:
		render_scale_slider.min_value = 0.5
		render_scale_slider.max_value = 1.0
		render_scale_slider.step = 0.05
	
	# Initialiser les valeurs depuis les paramètres sauvegardés
	var settings = _get_settings()
	if settings != null:
		if sensitivity_slider:
			sensitivity_slider.value = settings.mouse_sensitivity
			_update_label(settings.mouse_sensitivity)
			sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
			
		if window_mode_btn:
			window_mode_btn.select(settings.window_mode)
			window_mode_btn.item_selected.connect(_on_window_mode_selected)
			
		if render_scale_slider:
			render_scale_slider.value = settings.render_scale
			_update_render_scale_label(settings.render_scale)
			render_scale_slider.value_changed.connect(_on_render_scale_changed)
			
		if fsr_mode_btn:
			fsr_mode_btn.select(settings.fsr_mode)
			fsr_mode_btn.item_selected.connect(_on_fsr_mode_selected)
			
		if fps_cap_input:
			_update_fps_input(settings.fps_cap)
			fps_cap_input.text_changed.connect(_on_fps_cap_changed)
			
		if vsync_btn:
			vsync_btn.button_pressed = settings.vsync
			vsync_btn.toggled.connect(_on_vsync_toggled)
			
		if shadow_btn:
			shadow_btn.select(settings.shadow_quality)
			shadow_btn.item_selected.connect(_on_shadow_quality_selected)
			
		if render_distance_btn:
			render_distance_btn.select(settings.render_distance)
			render_distance_btn.item_selected.connect(_on_render_distance_selected)
			
		# Effets Graphiques
		if ssil_btn:
			ssil_btn.button_pressed = settings.ssil_enabled
			ssil_btn.toggled.connect(_on_ssil_toggled)
			
		if ssao_btn:
			ssao_btn.button_pressed = settings.ssao_enabled
			ssao_btn.toggled.connect(_on_ssao_toggled)
			
		if vfog_btn:
			vfog_btn.button_pressed = settings.volumetric_fog_enabled
			vfog_btn.toggled.connect(_on_vfog_toggled)
			
		if glow_btn:
			glow_btn.button_pressed = settings.glow_enabled
			glow_btn.toggled.connect(_on_glow_toggled)

func _get_settings() -> Node:
	if Engine.has_singleton("SettingsManager"):
		return Engine.get_singleton("SettingsManager")
	elif get_tree() != null and get_tree().root.has_node("SettingsManager"):
		return get_tree().root.get_node("SettingsManager")
	return null

func _update_fps_input(cap: int) -> void:
	if fps_cap_input == null: return
	if cap <= 0:
		fps_cap_input.text = "0"
	else:
		fps_cap_input.text = str(cap)

func _update_label(value: float) -> void:
	if sensitivity_label == null: return
	sensitivity_label.text = "%.1f" % (value * 1000.0)

func _update_render_scale_label(value: float) -> void:
	if render_scale_label == null: return
	render_scale_label.text = "%d%%" % int(value * 100)

func _on_sensitivity_changed(value: float) -> void:
	_update_label(value)
	var settings = _get_settings()
	if settings:
		settings.mouse_sensitivity = value
		settings.save_settings()

func _on_window_mode_selected(index: int) -> void:
	var settings = _get_settings()
	if settings:
		settings.window_mode = index
		settings.save_settings()

func _on_render_scale_changed(value: float) -> void:
	_update_render_scale_label(value)
	var settings = _get_settings()
	if settings:
		settings.render_scale = value
		settings.save_settings()

func _on_fsr_mode_selected(index: int) -> void:
	var settings = _get_settings()
	if settings:
		settings.fsr_mode = index
		settings.save_settings()

func _on_fps_cap_changed(new_text: String) -> void:
	var settings = _get_settings()
	if not new_text.is_valid_int() and new_text != "":
		if settings:
			_update_fps_input(settings.fps_cap)
		return
		
	var cap = new_text.to_int()
	if cap < 0:
		cap = 0
		
	if settings:
		settings.fps_cap = cap
		settings.save_settings()

func _on_vsync_toggled(toggled_on: bool) -> void:
	var settings = _get_settings()
	if settings:
		settings.vsync = toggled_on
		settings.save_settings()

func _on_shadow_quality_selected(index: int) -> void:
	var settings = _get_settings()
	if settings:
		settings.shadow_quality = index
		settings.save_settings()

func _on_render_distance_selected(index: int) -> void:
	var settings = _get_settings()
	if settings:
		settings.render_distance = index
		settings.save_settings()

# Callbacks des effets graphiques
func _on_ssil_toggled(toggled_on: bool) -> void:
	var settings = _get_settings()
	if settings:
		settings.ssil_enabled = toggled_on
		settings.save_settings()

func _on_ssao_toggled(toggled_on: bool) -> void:
	var settings = _get_settings()
	if settings:
		settings.ssao_enabled = toggled_on
		settings.save_settings()

func _on_vfog_toggled(toggled_on: bool) -> void:
	var settings = _get_settings()
	if settings:
		settings.volumetric_fog_enabled = toggled_on
		settings.save_settings()

func _on_glow_toggled(toggled_on: bool) -> void:
	var settings = _get_settings()
	if settings:
		settings.glow_enabled = toggled_on
		settings.save_settings()
