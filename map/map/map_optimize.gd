extends Node

func _ready() -> void:
	if get_tree().root.has_node("SettingsManager"):
		var settings = get_tree().root.get_node("SettingsManager")
		settings.shadow_quality_changed.connect(_on_shadow_quality_changed)
		settings.render_distance_changed.connect(_on_render_distance_changed)
		settings.vfog_changed.connect(_on_vfog_changed)
		_on_shadow_quality_changed(settings.shadow_quality)
		_on_render_distance_changed(settings.render_distance)
		_on_vfog_changed(settings.volumetric_fog_enabled)

func _on_shadow_quality_changed(quality: int) -> void:
	var herbe_doit_projeter_ombre = (quality == 0)
	
	var terrain = find_child("Terrain3D", true, false)
	if terrain and terrain.assets:
		for mesh_asset in terrain.assets.mesh_list:
			if "grass" in mesh_asset.name.to_lower() or "herbe" in mesh_asset.name.to_lower():
				mesh_asset.cast_shadows = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if herbe_doit_projeter_ombre else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					
	var soleils = get_tree().root.find_children("*", "DirectionalLight3D", true, false)
	for soleil in soleils:
		soleil.shadow_enabled = (quality != 2)
	
	var environnements = get_tree().root.find_children("*", "WorldEnvironment", true, false)
	for env in environnements:
		if env.environment:
			env.environment.ssao_enabled = (quality == 0)
			env.environment.ssil_enabled = (quality == 0)

func _on_render_distance_changed(distance_mode: int) -> void:
	var far_distance = 100.0
	match distance_mode:
		0: far_distance = 800.0 # Far
		1: far_distance = 100.0 # Mid
		2: far_distance = 50.0  # Close
		
	var cameras = get_tree().root.find_children("*", "Camera3D", true, false)
	for cam in cameras:
		cam.far = far_distance
		
	var environnements = get_tree().root.find_children("*", "WorldEnvironment", true, false)
	for env in environnements:
		if env.environment:
			env.environment.fog_enabled = true
			env.environment.fog_mode = Environment.FOG_MODE_DEPTH
			env.environment.fog_depth_begin = far_distance * 0.4
			env.environment.fog_depth_end = far_distance
			env.environment.fog_sky_affect = 0.0

func _on_vfog_changed(enabled: bool) -> void:
	var environnements = get_tree().root.find_children("*", "WorldEnvironment", true, false)
	for env in environnements:
		if env.environment:
			env.environment.volumetric_fog_enabled = enabled
