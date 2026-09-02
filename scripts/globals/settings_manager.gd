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

var render_scale: float = 1.0:
	set(value):
		render_scale = value
		get_viewport().scaling_3d_scale = render_scale

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

var shadow_quality: int = 0: # 0 = High, 1 = Low, 2 = Off
	set(value):
		shadow_quality = value
		_apply_shadow_quality()

const SETTINGS_FILE = "user://settings.cfg"
var config = ConfigFile.new()

func _ready() -> void:
	load_settings()

func _apply_fsr_mode() -> void:
	match fsr_mode:
		0: get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		1: get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		2: get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2

func _apply_vsync() -> void:
	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _apply_shadow_quality() -> void:
	match shadow_quality:
		0: # High
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
		1: # Low
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
		2: # Off (Minimum size to avoid D3D12/Vulkan crash, effectively disables them visually)
			RenderingServer.directional_shadow_atlas_set_size(256, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)

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

func save_settings() -> void:
	config.set_value("Controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("Video", "window_mode", window_mode)
	config.set_value("Video", "render_scale", render_scale)
	config.set_value("Video", "fsr_mode", fsr_mode)
	config.set_value("Video", "fps_cap", fps_cap)
	config.set_value("Video", "vsync", vsync)
	config.set_value("Video", "shadow_quality", shadow_quality)
	config.save(SETTINGS_FILE)

func load_settings() -> void:
	var err = config.load(SETTINGS_FILE)
	if err != OK:
		save_settings() # Create default settings file
		return
		
	# Load settings with fallback
	mouse_sensitivity = config.get_value("Controls", "mouse_sensitivity", 0.002)
	window_mode = config.get_value("Video", "window_mode", 0)
	render_scale = config.get_value("Video", "render_scale", 1.0)
	fsr_mode = config.get_value("Video", "fsr_mode", 1)
	fps_cap = config.get_value("Video", "fps_cap", 0)
	vsync = config.get_value("Video", "vsync", true)
	shadow_quality = config.get_value("Video", "shadow_quality", 0)
