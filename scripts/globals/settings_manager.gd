extends Node

signal mouse_sensitivity_changed(new_value: float)
signal shadow_quality_changed(quality: int)
signal render_distance_changed(distance: int)
signal vfog_changed(enabled: bool)
signal ssil_changed(enabled: bool)
signal ssao_changed(enabled: bool)
signal glow_changed(enabled: bool)

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
	match shadow_quality:
		0: # High
			light.shadow_enabled = true
			if light is DirectionalLight3D:
				light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
				light.directional_shadow_max_distance = 250.0
		1: # Mid (ancien Low)
			light.shadow_enabled = true
			if light is DirectionalLight3D:
				light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
				light.directional_shadow_max_distance = 250.0
		2: # Low (plus moche : 2 cascades étirées sur 250m, atlas 1024, rendu crénelé et léger)
			light.shadow_enabled = true
			if light is DirectionalLight3D:
				light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
				light.directional_shadow_max_distance = 250.0
		3: # Off (aucune ombre calculée)
			light.shadow_enabled = false

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
	config.set_value("Video", "render_distance", render_distance)
	config.set_value("Video", "volumetric_fog", volumetric_fog_enabled)
	config.set_value("Video", "ssil", ssil_enabled)
	config.set_value("Video", "ssao", ssao_enabled)
	config.set_value("Video", "glow", glow_enabled)
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
	var loaded_shadow = config.get_value("Video", "shadow_quality", 0)
	shadow_quality = loaded_shadow
	render_distance = config.get_value("Video", "render_distance", 1)
	volumetric_fog_enabled = config.get_value("Video", "volumetric_fog", true)
	ssil_enabled = config.get_value("Video", "ssil", true)
	ssao_enabled = config.get_value("Video", "ssao", true)
	glow_enabled = config.get_value("Video", "glow", true)
	_apply_environment_settings()

func load_keybinds() -> void:
	var keybind_config = ConfigFile.new()
	if keybind_config.load("user://keybinds.cfg") == OK:
		for action in keybind_config.get_section_keys("Keybinds"):
			var event = keybind_config.get_value("Keybinds", action)
			if InputMap.has_action(action):
				InputMap.action_erase_events(action)
				InputMap.action_add_event(action, event)
