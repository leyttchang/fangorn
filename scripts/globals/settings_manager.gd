extends Node

signal mouse_sensitivity_changed(new_value: float)
signal shadow_quality_changed(quality: int)
signal render_distance_changed(distance: int)
signal vfog_changed(enabled: bool)
signal ssil_changed(enabled: bool)
signal ssao_changed(enabled: bool)
signal glow_changed(enabled: bool)
signal shader_settings_changed()
signal ui_style_changed(new_style: int)
signal audio_settings_changed()
signal keybinds_changed()

const WEATHER_BUS_NAME := "WeatherAmbience"
const SPELL_BUS_NAME := "SpellSFX"
const DEFAULT_SPELL_VOLUME: float = 0.55
const SPELL_BASE_OFFSET_DB: float = -4.5

enum UIStyle { CLASSIC = 0, MORIA_D2 = 1 }

# --- Audio (0.0 = Muet / 0%, 1.0 = 100%) ---
var master_volume: float = 1.0:
	set(value):
		master_volume = clampf(value, 0.0, 1.0)
		_apply_audio_settings()
		audio_settings_changed.emit()

var ambient_volume: float = 1.0:
	set(value):
		ambient_volume = clampf(value, 0.0, 1.0)
		_apply_audio_settings()
		audio_settings_changed.emit()

var spell_volume: float = DEFAULT_SPELL_VOLUME:
	set(value):
		spell_volume = clampf(value, 0.0, 1.0)
		_apply_audio_settings()
		audio_settings_changed.emit()

var ambient_offset_db: float = 0.0:
	set(value):
		ambient_offset_db = value
		_apply_audio_settings()

# --- Style d'Interface (UI) ---
# 0 = Classique (Ancien), 1 = Moria / Diablo 2 (Nouveau)
var ui_style: int = UIStyle.MORIA_D2:
	set(value):
		ui_style = value
		ui_style_changed.emit(ui_style)

var mouse_sensitivity: float = 0.002:
	set(value):
		mouse_sensitivity = value
		mouse_sensitivity_changed.emit(mouse_sensitivity)

var window_mode: int = 0: # 0 = Fullscreen, 1 = Windowed, 2 = Borderless
	set(value):
		window_mode = value
		_apply_window_mode()

var render_scale: float = 1.0:
	set(value):
		render_scale = value
		if get_viewport() != null:
			get_viewport().scaling_3d_scale = render_scale
		_apply_fsr_mode()

var fsr_mode: int = 1: # 0 = Bilinear, 1 = FSR 1.0, 2 = FSR 2.2
	set(value):
		fsr_mode = value
		_apply_fsr_mode()

var fps_cap: int = 0: # 0 = Uncapped
	set(value):
		fps_cap = value
		Engine.max_fps = fps_cap

var vsync: bool = true:
	set(value):
		vsync = value
		_apply_vsync()

var volumetric_fog_enabled: bool = true:
	set(value):
		volumetric_fog_enabled = value
		vfog_changed.emit(volumetric_fog_enabled)
		_apply_environment_settings()

var ssil_enabled: bool = true:
	set(value):
		ssil_enabled = value
		ssil_changed.emit(ssil_enabled)
		_apply_environment_settings()

var ssao_enabled: bool = true:
	set(value):
		ssao_enabled = value
		ssao_changed.emit(ssao_enabled)
		_apply_environment_settings()

var glow_enabled: bool = true:
	set(value):
		glow_enabled = value
		glow_changed.emit(glow_enabled)
		_apply_environment_settings()

var render_distance: int = 1:
	set(value):
		render_distance = value
		render_distance_changed.emit(render_distance)

var shadow_quality: int = 0: # 0 = High, 1 = Mid, 2 = Low, 3 = Off
	set(value):
		shadow_quality = value
		_apply_shadow_quality()

# --- Paramètres du Shader Global ---
# 0 = Painterly / Figurine (Nouveau), 1 = Toon / Outline (Ancien), 2 = Désactivé
var shader_mode: int = 0:
	set(value):
		shader_mode = value
		shader_settings_changed.emit()

# Nouveau Shader : Painterly / Figurine (3 composants)
var painterly_kuwahara_enabled: bool = true:
	set(value):
		painterly_kuwahara_enabled = value
		shader_settings_changed.emit()

var painterly_paint_radius: float = 2.5:
	set(value):
		painterly_paint_radius = value
		shader_settings_changed.emit()

var painterly_dry_brush_enabled: bool = true:
	set(value):
		painterly_dry_brush_enabled = value
		shader_settings_changed.emit()

var painterly_outline_darkness: float = 0.55:
	set(value):
		painterly_outline_darkness = value
		shader_settings_changed.emit()

var painterly_edge_highlight: float = 0.35:
	set(value):
		painterly_edge_highlight = value
		shader_settings_changed.emit()

var painterly_split_toning_enabled: bool = true:
	set(value):
		painterly_split_toning_enabled = value
		shader_settings_changed.emit()

var painterly_warmth: float = 1.25:
	set(value):
		painterly_warmth = value
		shader_settings_changed.emit()

var painterly_contrast: float = 1.12:
	set(value):
		painterly_contrast = value
		shader_settings_changed.emit()

# Ancien Shader : Toon / Outline (3 composants)
var old_depth_outline_enabled: bool = true:
	set(value):
		old_depth_outline_enabled = value
		shader_settings_changed.emit()

var old_normal_outline_enabled: bool = true:
	set(value):
		old_normal_outline_enabled = value
		shader_settings_changed.emit()

var old_posterization_enabled: bool = true:
	set(value):
		old_posterization_enabled = value
		shader_settings_changed.emit()

var old_outline_thickness: float = 1.5:
	set(value):
		old_outline_thickness = value
		shader_settings_changed.emit()

var old_depth_threshold: float = 0.02:
	set(value):
		old_depth_threshold = value
		shader_settings_changed.emit()

var old_normal_threshold: float = 2.0:
	set(value):
		old_normal_threshold = value
		shader_settings_changed.emit()

var old_posterize_steps: float = 32.0:
	set(value):
		old_posterize_steps = value
		shader_settings_changed.emit()

const SETTINGS_FILE = "user://settings.cfg"
var config = ConfigFile.new()

func _ready() -> void:
	load_settings()
	load_keybinds()
	if get_tree() != null:
		get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node is WorldEnvironment:
		_apply_environment_settings.call_deferred(node.environment)
	elif node is Light3D:
		_apply_shadow_to_light.call_deferred(node)

func _apply_environment_settings(target_env: Environment = null) -> void:
	if target_env != null:
		_apply_to_env(target_env)
		return
	
	if not is_inside_tree():
		return
		
	var env_nodes = get_tree().root.find_children("*", "WorldEnvironment", true, false)
	for node in env_nodes:
		if node is WorldEnvironment and node.environment != null:
			_apply_to_env(node.environment)

func _apply_to_env(env: Environment) -> void:
	if env == null: return
	env.ssil_enabled = ssil_enabled
	env.ssao_enabled = ssao_enabled
	env.volumetric_fog_enabled = volumetric_fog_enabled
	env.glow_enabled = glow_enabled

func _apply_fsr_mode() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	match fsr_mode:
		0:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		1:
			if is_equal_approx(render_scale, 1.0) or (render_scale >= 0.999 and render_scale <= 1.001):
				vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			else:
				vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		2:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2

func _apply_vsync() -> void:
	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _apply_shadow_quality() -> void:
	shadow_quality_changed.emit(shadow_quality)
	match shadow_quality:
		0: # High (comme avant)
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
		1: # Mid (comme Low avant)
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
		2: # Low (beaucoup plus moche et ultra léger : atlas 1024, 2 splits, 250m)
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
		3: # Off (désactivé totalement)
			RenderingServer.directional_shadow_atlas_set_size(256, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)

	if is_inside_tree():
		var lights = get_tree().root.find_children("*", "Light3D", true, false)
		for light in lights:
			if light is Light3D:
				_apply_shadow_to_light(light)

func _apply_shadow_to_light(light: Node) -> void:
	if light == null or not is_instance_valid(light):
		return
	if light is DirectionalLight3D:
		match shadow_quality:
			0: # High
				light.shadow_enabled = true
				light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
				light.directional_shadow_max_distance = 250.0
			1: # Mid (ancien Low)
				light.shadow_enabled = true
				light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
				light.directional_shadow_max_distance = 250.0
			2: # Low (plus moche : 2 cascades étirées sur 250m, atlas 1024, rendu crénelé et léger)
				light.shadow_enabled = true
				light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
				light.directional_shadow_max_distance = 250.0
			3: # Off (aucune ombre calculée)
				light.shadow_enabled = false
	elif light is OmniLight3D or light is SpotLight3D:
		if shadow_quality == 3:
			light.shadow_enabled = false
		if not light.distance_fade_enabled:
			light.distance_fade_enabled = true
			light.distance_fade_begin = maxf(45.0, (light as OmniLight3D).omni_range * 1.8 if light is OmniLight3D else 45.0)
			light.distance_fade_length = 12.0

func _apply_window_mode() -> void:
	match window_mode:
		0: # Fullscreen (Exclusive = Meilleures perfs)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		1: # Windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		2: # Borderless
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)

func ensure_weather_ambience_bus() -> int:
	var idx := AudioServer.get_bus_index(WEATHER_BUS_NAME)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, WEATHER_BUS_NAME)
		AudioServer.set_bus_send(idx, "Master")
		var comp := AudioEffectCompressor.new()
		comp.threshold = -8.0
		comp.ratio = 2.5
		comp.attack_us = 15000.0
		comp.release_ms = 280.0
		AudioServer.add_bus_effect(idx, comp)
	return idx

func ensure_spell_sfx_bus() -> int:
	var idx: int = AudioServer.get_bus_index(SPELL_BUS_NAME)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, SPELL_BUS_NAME)
		AudioServer.set_bus_send(idx, "Master")

		# 1. EQ anti-fatigue (creuse légèrement la zone agressive 3.2 kHz et réchauffe le bas-médium)
		var eq := AudioEffectEQ6.new()
		eq.set("band_db/100_hz", 1.2)
		eq.set("band_db/320_hz", 0.8)
		eq.set("band_db/3200_hz", -3.5)
		eq.set("band_db/10000_hz", -1.5)
		AudioServer.add_bus_effect(idx, eq)

		# 2. Réverbération spatiale de forêt (donne de la profondeur naturelle aux sorts sans noyer l'attaque)
		var rev := AudioEffectReverb.new()
		rev.room_size = 0.58
		rev.damping = 0.68
		rev.spread = 0.85
		rev.predelay_msec = 26.0
		rev.predelay_feedback = 0.22
		rev.hipass = 0.15
		rev.dry = 0.92
		rev.wet = 0.18
		AudioServer.add_bus_effect(idx, rev)

		# 3. Compresseur doux de sécurité (préserve la dynamique sans jamais saturer)
		var comp := AudioEffectCompressor.new()
		comp.threshold = -7.5
		comp.ratio = 3.0
		comp.attack_us = 6000.0
		comp.release_ms = 140.0
		AudioServer.add_bus_effect(idx, comp)
	return idx

func _apply_audio_settings() -> void:
	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx == -1:
		master_idx = 0
	if AudioServer.bus_count > master_idx:
		AudioServer.set_bus_mute(master_idx, master_volume <= 0.001)
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(maxf(0.0001, master_volume)))

	var amb_idx: int = ensure_weather_ambience_bus()
	if amb_idx != -1:
		AudioServer.set_bus_mute(amb_idx, ambient_volume <= 0.001)
		AudioServer.set_bus_volume_db(amb_idx, linear_to_db(maxf(0.0001, ambient_volume)) + ambient_offset_db)

	var spell_idx: int = ensure_spell_sfx_bus()
	if spell_idx != -1:
		AudioServer.set_bus_mute(spell_idx, spell_volume <= 0.001)
		AudioServer.set_bus_volume_db(spell_idx, linear_to_db(maxf(0.0001, spell_volume)) + SPELL_BASE_OFFSET_DB)

func save_settings() -> void:
	config.set_value("Audio", "master_volume", master_volume)
	config.set_value("Audio", "ambient_volume", ambient_volume)
	config.set_value("Audio", "spell_volume", spell_volume)
	config.set_value("Controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("Video", "window_mode", window_mode)
	config.set_value("Video", "render_scale", render_scale)
	config.set_value("Video", "fsr_mode", fsr_mode)
	config.set_value("Video", "fps_cap", fps_cap)
	config.set_value("Video", "vsync", vsync)
	config.set_value("Video", "shadow_quality", shadow_quality)
	config.set_value("Video", "render_distance", render_distance)
	config.set_value("Video", "volumetric_fog", volumetric_fog_enabled)
	config.set_value("Video", "ssil", ssil_enabled)
	config.set_value("Video", "ssao", ssao_enabled)
	config.set_value("Video", "glow", glow_enabled)
	config.set_value("UI", "ui_style", ui_style)
	config.set_value("Shader", "shader_mode", shader_mode)
	config.set_value("Shader", "painterly_kuwahara_enabled", painterly_kuwahara_enabled)
	config.set_value("Shader", "painterly_paint_radius", painterly_paint_radius)
	config.set_value("Shader", "painterly_dry_brush_enabled", painterly_dry_brush_enabled)
	config.set_value("Shader", "painterly_outline_darkness", painterly_outline_darkness)
	config.set_value("Shader", "painterly_edge_highlight", painterly_edge_highlight)
	config.set_value("Shader", "painterly_split_toning_enabled", painterly_split_toning_enabled)
	config.set_value("Shader", "painterly_warmth", painterly_warmth)
	config.set_value("Shader", "painterly_contrast", painterly_contrast)
	config.set_value("Shader", "old_depth_outline_enabled", old_depth_outline_enabled)
	config.set_value("Shader", "old_normal_outline_enabled", old_normal_outline_enabled)
	config.set_value("Shader", "old_posterization_enabled", old_posterization_enabled)
	config.set_value("Shader", "old_outline_thickness", old_outline_thickness)
	config.set_value("Shader", "old_depth_threshold", old_depth_threshold)
	config.set_value("Shader", "old_normal_threshold", old_normal_threshold)
	config.set_value("Shader", "old_posterize_steps", old_posterize_steps)
	config.save(SETTINGS_FILE)

func load_settings() -> void:
	var err = config.load(SETTINGS_FILE)
	if err != OK:
		save_settings() # Create default settings file
		_apply_audio_settings()
		_apply_window_mode()
		_apply_fsr_mode()
		_apply_vsync()
		_apply_shadow_quality()
		_apply_environment_settings()
		return
		
	# Load settings with fallback
	master_volume = clampf(float(config.get_value("Audio", "master_volume", 1.0)), 0.0, 1.0)
	ambient_volume = clampf(float(config.get_value("Audio", "ambient_volume", 1.0)), 0.0, 1.0)
	spell_volume = clampf(float(config.get_value("Audio", "spell_volume", DEFAULT_SPELL_VOLUME)), 0.0, 1.0)
	_apply_audio_settings()
	mouse_sensitivity = config.get_value("Controls", "mouse_sensitivity", 0.002)
	window_mode = config.get_value("Video", "window_mode", 0)
	render_scale = config.get_value("Video", "render_scale", 1.0)
	fsr_mode = config.get_value("Video", "fsr_mode", 1)
	fps_cap = config.get_value("Video", "fps_cap", 0)
	vsync = config.get_value("Video", "vsync", true)
	var loaded_shadow = config.get_value("Video", "shadow_quality", 0)
	shadow_quality = loaded_shadow
	render_distance = config.get_value("Video", "render_distance", 1)
	volumetric_fog_enabled = config.get_value("Video", "volumetric_fog", true)
	ssil_enabled = config.get_value("Video", "ssil", true)
	ssao_enabled = config.get_value("Video", "ssao", true)
	glow_enabled = config.get_value("Video", "glow", true)
	ui_style = config.get_value("UI", "ui_style", UIStyle.MORIA_D2)
	shader_mode = config.get_value("Shader", "shader_mode", 0)
	painterly_kuwahara_enabled = config.get_value("Shader", "painterly_kuwahara_enabled", true)
	painterly_paint_radius = config.get_value("Shader", "painterly_paint_radius", 2.5)
	painterly_dry_brush_enabled = config.get_value("Shader", "painterly_dry_brush_enabled", true)
	painterly_outline_darkness = config.get_value("Shader", "painterly_outline_darkness", 0.55)
	painterly_edge_highlight = config.get_value("Shader", "painterly_edge_highlight", 0.35)
	painterly_split_toning_enabled = config.get_value("Shader", "painterly_split_toning_enabled", true)
	painterly_warmth = config.get_value("Shader", "painterly_warmth", 1.25)
	painterly_contrast = config.get_value("Shader", "painterly_contrast", 1.12)
	old_depth_outline_enabled = config.get_value("Shader", "old_depth_outline_enabled", true)
	old_normal_outline_enabled = config.get_value("Shader", "old_normal_outline_enabled", true)
	old_posterization_enabled = config.get_value("Shader", "old_posterization_enabled", true)
	old_outline_thickness = config.get_value("Shader", "old_outline_thickness", 1.5)
	old_depth_threshold = config.get_value("Shader", "old_depth_threshold", 0.02)
	old_normal_threshold = config.get_value("Shader", "old_normal_threshold", 2.0)
	old_posterize_steps = config.get_value("Shader", "old_posterize_steps", 32.0)
	_apply_environment_settings()

func load_keybinds() -> void:
	var keybind_config := ConfigFile.new()
	if keybind_config.load("user://keybinds.cfg") == OK:
		for action: String in keybind_config.get_section_keys("Keybinds"):
			var event: Variant = keybind_config.get_value("Keybinds", action)
			if InputMap.has_action(action) and event is InputEvent:
				InputMap.action_erase_events(action)
				InputMap.action_add_event(action, event as InputEvent)
	keybinds_changed.emit()


func get_action_key_label(action_name: StringName = &"interact", fallback: String = "F") -> String:
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


func format_interact_prompt(raw_text: String, action_name: StringName = &"interact") -> String:
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
