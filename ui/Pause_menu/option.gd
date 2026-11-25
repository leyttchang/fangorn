extends Panel

@onready var sensitivity_slider: HSlider = find_child("Sensitivity_slider", true, false)
@onready var sensitivity_label: Label = find_child("sensitivity_text", true, false)
@onready var window_mode_btn: OptionButton = find_child("screen_option", true, false)

@onready var master_volume_slider: HSlider = find_child("MasterVolume_slider", true, false) as HSlider
@onready var master_volume_label: Label = find_child("MasterVolume_text", true, false) as Label
@onready var ambient_volume_slider: HSlider = find_child("AmbientVolume_slider", true, false) as HSlider
@onready var ambient_volume_label: Label = find_child("AmbientVolume_text", true, false) as Label
@onready var spell_volume_slider: HSlider = find_child("SpellVolume_slider", true, false) as HSlider
@onready var spell_volume_label: Label = find_child("SpellVolume_text", true, false) as Label
@onready var reset_audio_btn: Button = find_child("reset_audio_btn", true, false) as Button

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

# Contrôles de l'onglet Shader
@onready var shader_mode_btn: OptionButton = find_child("shader_mode_option", true, false)
@onready var painterly_section: Control = find_child("PainterlySection", true, false)
@onready var old_shader_section: Control = find_child("OldShaderSection", true, false)

@onready var kuwahara_toggle: CheckButton = find_child("kuwahara_toggle", true, false)
@onready var paint_radius_slider: HSlider = find_child("paint_radius_slider", true, false)
@onready var paint_radius_label: Label = find_child("paint_radius_text", true, false)

@onready var dry_brush_toggle: CheckButton = find_child("dry_brush_toggle", true, false)
@onready var outline_darkness_slider: HSlider = find_child("outline_darkness_slider", true, false)
@onready var outline_darkness_label: Label = find_child("outline_darkness_text", true, false)
@onready var edge_highlight_slider: HSlider = find_child("edge_highlight_slider", true, false)
@onready var edge_highlight_label: Label = find_child("edge_highlight_text", true, false)

@onready var split_toning_toggle: CheckButton = find_child("split_toning_toggle", true, false)
@onready var warmth_slider: HSlider = find_child("warmth_slider", true, false)
@onready var warmth_label: Label = find_child("warmth_text", true, false)
@onready var contrast_slider: HSlider = find_child("contrast_slider", true, false)
@onready var contrast_label: Label = find_child("contrast_text", true, false)

@onready var old_depth_toggle: CheckButton = find_child("old_depth_toggle", true, false)
@onready var old_depth_slider: HSlider = find_child("old_depth_slider", true, false)
@onready var old_depth_label: Label = find_child("old_depth_text", true, false)

@onready var old_normal_toggle: CheckButton = find_child("old_normal_toggle", true, false)
@onready var old_normal_slider: HSlider = find_child("old_normal_slider", true, false)
@onready var old_normal_label: Label = find_child("old_normal_text", true, false)
@onready var old_thickness_slider: HSlider = find_child("old_thickness_slider", true, false)
@onready var old_thickness_label: Label = find_child("old_thickness_text", true, false)

@onready var old_posterize_toggle: CheckButton = find_child("old_posterize_toggle", true, false)
@onready var old_posterize_slider: HSlider = find_child("old_posterize_slider", true, false)
@onready var old_posterize_label: Label = find_child("old_posterize_text", true, false)

@onready var reset_shader_btn: Button = find_child("reset_shader_btn", true, false)

@onready var keybinds_menu_btn: Button = find_child("Keybind", true, false)
@onready var keybinds_panel: Panel = $Panel
@onready var keybinds_return_btn: Button = $Panel/MarginContainer2/VBoxContainer/return

var _updating_shader_ui: bool = false
var _updating_audio_ui: bool = false

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

	if master_volume_slider:
		master_volume_slider.min_value = 0.0
		master_volume_slider.max_value = 1.0
		master_volume_slider.step = 0.01

	if ambient_volume_slider:
		ambient_volume_slider.min_value = 0.0
		ambient_volume_slider.max_value = 1.0
		ambient_volume_slider.step = 0.01

	if spell_volume_slider:
		spell_volume_slider.min_value = 0.0
		spell_volume_slider.max_value = 1.0
		spell_volume_slider.step = 0.01

	_setup_shader_sliders()
	
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
			_setup_ui_style_option(window_mode_btn.get_parent(), settings)
			
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

		_sync_audio_ui_from_settings(settings)
		if master_volume_slider:
			master_volume_slider.value_changed.connect(_on_master_volume_changed)
		if ambient_volume_slider:
			ambient_volume_slider.value_changed.connect(_on_ambient_volume_changed)
		if spell_volume_slider:
			spell_volume_slider.value_changed.connect(_on_spell_volume_changed)
		if reset_audio_btn:
			reset_audio_btn.pressed.connect(_on_reset_audio_pressed)
		if settings.has_signal("audio_settings_changed") and not settings.audio_settings_changed.is_connected(_on_external_audio_settings_changed):
			settings.audio_settings_changed.connect(_on_external_audio_settings_changed)

		_sync_shader_ui_from_settings(settings)
		_connect_shader_signals()
		if not settings.shader_settings_changed.is_connected(_on_external_shader_settings_changed):
			settings.shader_settings_changed.connect(_on_external_shader_settings_changed)

func _setup_shader_sliders() -> void:
	if paint_radius_slider:
		paint_radius_slider.min_value = 0.0
		paint_radius_slider.max_value = 5.0
		paint_radius_slider.step = 0.1
	if outline_darkness_slider:
		outline_darkness_slider.min_value = 0.0
		outline_darkness_slider.max_value = 1.0
		outline_darkness_slider.step = 0.05
	if edge_highlight_slider:
		edge_highlight_slider.min_value = 0.0
		edge_highlight_slider.max_value = 1.0
		edge_highlight_slider.step = 0.02
	if warmth_slider:
		warmth_slider.min_value = 0.0
		warmth_slider.max_value = 2.0
		warmth_slider.step = 0.05
	if contrast_slider:
		contrast_slider.min_value = 0.6
		contrast_slider.max_value = 1.8
		contrast_slider.step = 0.05
	if old_depth_slider:
		old_depth_slider.min_value = 0.002
		old_depth_slider.max_value = 0.15
		old_depth_slider.step = 0.002
	if old_normal_slider:
		old_normal_slider.min_value = 0.2
		old_normal_slider.max_value = 4.0
		old_normal_slider.step = 0.1
	if old_thickness_slider:
		old_thickness_slider.min_value = 0.5
		old_thickness_slider.max_value = 4.0
		old_thickness_slider.step = 0.1
	if old_posterize_slider:
		old_posterize_slider.min_value = 4.0
		old_posterize_slider.max_value = 64.0
		old_posterize_slider.step = 2.0

func _sync_shader_ui_from_settings(settings: Node) -> void:
	_updating_shader_ui = true
	if shader_mode_btn:
		shader_mode_btn.select(settings.shader_mode)
	_update_shader_sections_visibility(settings.shader_mode)

	if kuwahara_toggle:
		kuwahara_toggle.button_pressed = settings.painterly_kuwahara_enabled
	if paint_radius_slider:
		paint_radius_slider.value = settings.painterly_paint_radius
	if paint_radius_label:
		paint_radius_label.text = "%.1f" % settings.painterly_paint_radius

	if dry_brush_toggle:
		dry_brush_toggle.button_pressed = settings.painterly_dry_brush_enabled
	if outline_darkness_slider:
		outline_darkness_slider.value = settings.painterly_outline_darkness
	if outline_darkness_label:
		outline_darkness_label.text = "%.2f" % settings.painterly_outline_darkness
	if edge_highlight_slider:
		edge_highlight_slider.value = settings.painterly_edge_highlight
	if edge_highlight_label:
		edge_highlight_label.text = "%.2f" % settings.painterly_edge_highlight

	if split_toning_toggle:
		split_toning_toggle.button_pressed = settings.painterly_split_toning_enabled
	if warmth_slider:
		warmth_slider.value = settings.painterly_warmth
	if warmth_label:
		warmth_label.text = "%.2f" % settings.painterly_warmth
	if contrast_slider:
		contrast_slider.value = settings.painterly_contrast
	if contrast_label:
		contrast_label.text = "%.2f" % settings.painterly_contrast

	if old_depth_toggle:
		old_depth_toggle.button_pressed = settings.old_depth_outline_enabled
	if old_depth_slider:
		old_depth_slider.value = settings.old_depth_threshold
	if old_depth_label:
		old_depth_label.text = "%.3f" % settings.old_depth_threshold

	if old_normal_toggle:
		old_normal_toggle.button_pressed = settings.old_normal_outline_enabled
	if old_normal_slider:
		old_normal_slider.value = settings.old_normal_threshold
	if old_normal_label:
		old_normal_label.text = "%.1f" % settings.old_normal_threshold
	if old_thickness_slider:
		old_thickness_slider.value = settings.old_outline_thickness
	if old_thickness_label:
		old_thickness_label.text = "%.1f" % settings.old_outline_thickness

	if old_posterize_toggle:
		old_posterize_toggle.button_pressed = settings.old_posterization_enabled
	if old_posterize_slider:
		old_posterize_slider.value = settings.old_posterize_steps
	if old_posterize_label:
		old_posterize_label.text = "%d" % int(settings.old_posterize_steps)
	_updating_shader_ui = false

func _update_shader_sections_visibility(mode: int) -> void:
	if painterly_section:
		painterly_section.visible = (mode == 0)
	if old_shader_section:
		old_shader_section.visible = (mode == 1)

func _connect_shader_signals() -> void:
	if shader_mode_btn:
		shader_mode_btn.item_selected.connect(_on_shader_mode_selected)
	if kuwahara_toggle:
		kuwahara_toggle.toggled.connect(_on_kuwahara_toggled)
	if paint_radius_slider:
		paint_radius_slider.value_changed.connect(_on_paint_radius_changed)
	if dry_brush_toggle:
		dry_brush_toggle.toggled.connect(_on_dry_brush_toggled)
	if outline_darkness_slider:
		outline_darkness_slider.value_changed.connect(_on_outline_darkness_changed)
	if edge_highlight_slider:
		edge_highlight_slider.value_changed.connect(_on_edge_highlight_changed)
	if split_toning_toggle:
		split_toning_toggle.toggled.connect(_on_split_toning_toggled)
	if warmth_slider:
		warmth_slider.value_changed.connect(_on_warmth_changed)
	if contrast_slider:
		contrast_slider.value_changed.connect(_on_contrast_changed)

	if old_depth_toggle:
		old_depth_toggle.toggled.connect(_on_old_depth_toggled)
	if old_depth_slider:
		old_depth_slider.value_changed.connect(_on_old_depth_changed)
	if old_normal_toggle:
		old_normal_toggle.toggled.connect(_on_old_normal_toggled)
	if old_normal_slider:
		old_normal_slider.value_changed.connect(_on_old_normal_changed)
	if old_thickness_slider:
		old_thickness_slider.value_changed.connect(_on_old_thickness_changed)
	if old_posterize_toggle:
		old_posterize_toggle.toggled.connect(_on_old_posterize_toggled)
	if old_posterize_slider:
		old_posterize_slider.value_changed.connect(_on_old_posterize_changed)

	if reset_shader_btn:
		reset_shader_btn.pressed.connect(_on_reset_shader_pressed)

func _on_external_shader_settings_changed() -> void:
	if _updating_shader_ui:
		return
	var settings = _get_settings()
	if settings != null:
		_sync_shader_ui_from_settings(settings)

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

func _sync_audio_ui_from_settings(settings: Node) -> void:
	_updating_audio_ui = true
	var mv: float = float(settings.master_volume) if "master_volume" in settings else 1.0
	var av: float = float(settings.ambient_volume) if "ambient_volume" in settings else 1.0
	var sv: float = float(settings.spell_volume) if "spell_volume" in settings else 0.55
	if master_volume_slider:
		master_volume_slider.value = mv
	if master_volume_label:
		master_volume_label.text = "%d%%" % int(round(mv * 100.0))
	if ambient_volume_slider:
		ambient_volume_slider.value = av
	if ambient_volume_label:
		ambient_volume_label.text = "%d%%" % int(round(av * 100.0))
	if spell_volume_slider:
		spell_volume_slider.value = sv
	if spell_volume_label:
		spell_volume_label.text = "%d%%" % int(round(sv * 100.0))
	_updating_audio_ui = false

func _on_external_audio_settings_changed() -> void:
	if _updating_audio_ui:
		return
	var settings = _get_settings()
	if settings != null:
		_sync_audio_ui_from_settings(settings)

func _on_master_volume_changed(value: float) -> void:
	if master_volume_label:
		master_volume_label.text = "%d%%" % int(round(value * 100.0))
	if _updating_audio_ui:
		return
	var settings = _get_settings()
	if settings != null:
		_updating_audio_ui = true
		settings.master_volume = value
		settings.save_settings()
		_updating_audio_ui = false

func _on_ambient_volume_changed(value: float) -> void:
	if ambient_volume_label:
		ambient_volume_label.text = "%d%%" % int(round(value * 100.0))
	if _updating_audio_ui:
		return
	var settings = _get_settings()
	if settings != null:
		_updating_audio_ui = true
		settings.ambient_volume = value
		settings.save_settings()
		_updating_audio_ui = false

func _on_spell_volume_changed(value: float) -> void:
	if spell_volume_label:
		spell_volume_label.text = "%d%%" % int(round(value * 100.0))
	if _updating_audio_ui:
		return
	var settings: Node = _get_settings()
	if settings != null:
		_updating_audio_ui = true
		settings.set("spell_volume", value)
		settings.call("save_settings")
		_updating_audio_ui = false

func _on_reset_audio_pressed() -> void:
	var settings: Node = _get_settings()
	if settings == null:
		return
	_updating_audio_ui = true
	settings.set("master_volume", 1.0)
	settings.set("ambient_volume", 1.0)
	settings.set("spell_volume", 0.55)
	settings.call("save_settings")
	_sync_audio_ui_from_settings(settings)

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

# Callbacks de l'onglet Shader
func _on_shader_mode_selected(index: int) -> void:
	if _updating_shader_ui: return
	_update_shader_sections_visibility(index)
	var settings = _get_settings()
	if settings:
		_updating_shader_ui = true
		settings.shader_mode = index
		settings.save_settings()
		_updating_shader_ui = false

func _on_kuwahara_toggled(toggled_on: bool) -> void:
	if _updating_shader_ui: return
	var settings = _get_settings()
	if settings:
		_updating_shader_ui = true
		settings.painterly_kuwahara_enabled = toggled_on
		settings.save_settings()
		_updating_shader_ui = false

func _on_paint_radius_changed(value: float) -> void:
	if paint_radius_label:
		paint_radius_label.text = "%.1f" % value
	if _updating_shader_ui: return
	var settings = _get_settings()
	if settings:
		_updating_shader_ui = true
		settings.painterly_paint_radius = value
		settings.save_settings()
		_updating_shader_ui = false

func _on_dry_brush_toggled(toggled_on: bool) -> void:
	if _updating_shader_ui: return
	var settings = _get_settings()
	if settings:
		_updating_shader_ui = true
		settings.painterly_dry_brush_enabled = toggled_on
		settings.save_settings()
		_updating_shader_ui = false

func _on_outline_darkness_changed(value: float) -> void:
	if outline_darkness_label:
		outline_darkness_label.text = "%.2f" % value
	if _updating_shader_ui: return
	var settings = _get_settings()
	if settings:
		_updating_shader_ui = true
		settings.painterly_outline_darkness = value
		settings.save_settings()
		_updating_shader_ui = false

func _on_edge_highlight_changed(value: float) -> void:
	if edge_highlight_label:
		edge_highlight_label.text = "%.2f" % value
	if _updating_shader_ui: return
	var settings = _get_settings()
	if settings:
		_updating_shader_ui = true
		settings.painterly_edge_highlight = value
		settings.save_settings()
		_updating_shader_ui = false

func _on_split_toning_toggled(toggled_on: bool) -> void:
	if _updating_shader_ui: return
	var settings = _get_settings()
	if settings:
		_updating_shader_ui = true
		settings.painterly_split_toning_enabled = toggled_on
		settings.save_settings()
		_updating_shader_ui = false

func _on_warmth_changed(value: float) -> void:
	if warmth_label:
		warmth_label.text = "%.2f" % value
	if _updating_shader_ui: return
	var settings = _get_settings()
	if settings:
		_updating_shader_ui = true
		settings.painterly_warmth = value
		settings.save_settings()
		_updating_shader_ui = false

func _on_contrast_changed(value: float) -> void:
	if contrast_label:
		contrast_label.text = "%.2f" % value
	if _updating_shader_ui: return
	var settings = _get_settings()
	if settings:
		_updating_shader_ui = true
		settings.painterly_contrast = value
		settings.save_settings()
		_updating_shader_ui = false

func _on_old_depth_toggled(toggled_on: bool) -> void:
	if _updating_shader_ui: return
	var settings = _get_settings()
	if settings:
		_updating_shader_ui = true
		settings.old_depth_outline_enabled = toggled_on
		settings.save_settings()
		_updating_shader_ui = false

func _on_old_depth_changed(value: float) -> void:
	if old_depth_label:
		old_depth_label.text = "%.3f" % value
	if _updating_shader_ui: return
	var settings = _get_settings()
	if settings:
		_updating_shader_ui = true
		settings.old_depth_threshold = value
		settings.save_settings()
		_updating_shader_ui = false

func _on_old_normal_toggled(toggled_on: bool) -> void:
	if _updating_shader_ui: return
	var settings = _get_settings()
	if settings:
		_updating_shader_ui = true
		settings.old_normal_outline_enabled = toggled_on
		settings.save_settings()
		_updating_shader_ui = false

func _on_old_normal_changed(value: float) -> void:
	if old_normal_label:
		old_normal_label.text = "%.1f" % value
	if _updating_shader_ui: return
	var settings = _get_settings()
	if settings:
		_updating_shader_ui = true
		settings.old_normal_threshold = value
		settings.save_settings()
		_updating_shader_ui = false

func _on_old_thickness_changed(value: float) -> void:
	if old_thickness_label:
		old_thickness_label.text = "%.1f" % value
	if _updating_shader_ui: return
	var settings = _get_settings()
	if settings:
		_updating_shader_ui = true
		settings.old_outline_thickness = value
		settings.save_settings()
		_updating_shader_ui = false

func _on_old_posterize_toggled(toggled_on: bool) -> void:
	if _updating_shader_ui: return
	var settings = _get_settings()
	if settings:
		_updating_shader_ui = true
		settings.old_posterization_enabled = toggled_on
		settings.save_settings()
		_updating_shader_ui = false

func _on_old_posterize_changed(value: float) -> void:
	if old_posterize_label:
		old_posterize_label.text = "%d" % int(value)
	if _updating_shader_ui: return
	var settings = _get_settings()
	if settings:
		_updating_shader_ui = true
		settings.old_posterize_steps = value
		settings.save_settings()
		_updating_shader_ui = false

func _on_reset_shader_pressed() -> void:
	var settings = _get_settings()
	if settings == null: return
	_updating_shader_ui = true
	if settings.shader_mode == 0:
		settings.painterly_kuwahara_enabled = true
		settings.painterly_paint_radius = 2.5
		settings.painterly_dry_brush_enabled = true
		settings.painterly_outline_darkness = 0.55
		settings.painterly_edge_highlight = 0.35
		settings.painterly_split_toning_enabled = true
		settings.painterly_warmth = 1.25
		settings.painterly_contrast = 1.12
	elif settings.shader_mode == 1:
		settings.old_depth_outline_enabled = true
		settings.old_normal_outline_enabled = true
		settings.old_posterization_enabled = true
		settings.old_outline_thickness = 1.5
		settings.old_depth_threshold = 0.02
		settings.old_normal_threshold = 2.0
		settings.old_posterize_steps = 32.0
	settings.save_settings()
	_sync_shader_ui_from_settings(settings)

func _setup_ui_style_option(container: Node, settings: Node) -> void:
	if container == null or container.has_node("UIStyleOption"):
		return
	var lbl := Label.new()
	lbl.name = "UIStyleLabel"
	lbl.text = "UI Style"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var opt := OptionButton.new()
	opt.name = "UIStyleOption"
	opt.add_item("Classic (Original)", 0)
	opt.add_item("Moria / Diablo II", 1)
	opt.select(int(settings.ui_style) if "ui_style" in settings else 1)
	opt.item_selected.connect(func(idx: int):
		var s = _get_settings()
		if s != null and "ui_style" in s:
			s.ui_style = idx
			s.save_settings()
	)
	container.add_child(lbl)
	container.move_child(lbl, 1)
	container.add_child(opt)
	container.move_child(opt, 2)
