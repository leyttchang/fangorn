extends Node3D

const PAINTERLY_SHADER: Shader = preload("res://ui/global_shader/painterly_shader.gdshader")
const OLD_SHADER: Shader = preload("res://ui/global_shader/global_shader.gdshader")

var _mat: ShaderMaterial

func _ready() -> void:
	if has_node("quad_mesh"):
		var quad: MeshInstance3D = $quad_mesh
		if quad.material_override is ShaderMaterial:
			_mat = quad.material_override.duplicate() as ShaderMaterial
		else:
			_mat = ShaderMaterial.new()
			_mat.render_priority = -10
		quad.material_override = _mat

	var settings = _get_settings()
	if settings != null:
		if not settings.shader_settings_changed.is_connected(_apply_shader_settings):
			settings.shader_settings_changed.connect(_apply_shader_settings)
	_apply_shader_settings()

func _get_settings() -> Node:
	if Engine.has_singleton("SettingsManager"):
		return Engine.get_singleton("SettingsManager")
	elif get_tree() != null and get_tree().root.has_node("SettingsManager"):
		return get_tree().root.get_node("SettingsManager")
	return null

func _apply_shader_settings() -> void:
	if not has_node("quad_mesh"):
		return
	var quad: MeshInstance3D = $quad_mesh
	var settings = _get_settings()
	if settings == null or _mat == null:
		return

	match settings.shader_mode:
		0: # Nouveau : Painterly / Figurine
			quad.visible = true
			if _mat.shader != PAINTERLY_SHADER:
				_mat.shader = PAINTERLY_SHADER
			_mat.set_shader_parameter("enable_kuwahara", settings.painterly_kuwahara_enabled)
			_mat.set_shader_parameter("paint_radius", settings.painterly_paint_radius)
			_mat.set_shader_parameter("enable_dry_brush", settings.painterly_dry_brush_enabled)
			_mat.set_shader_parameter("outline_darkness", settings.painterly_outline_darkness)
			_mat.set_shader_parameter("edge_highlight", settings.painterly_edge_highlight)
			_mat.set_shader_parameter("enable_split_toning", settings.painterly_split_toning_enabled)
			_mat.set_shader_parameter("warmth", settings.painterly_warmth)
			_mat.set_shader_parameter("contrast", settings.painterly_contrast)
		1: # Ancien : Toon / Outline
			quad.visible = true
			if _mat.shader != OLD_SHADER:
				_mat.shader = OLD_SHADER
			_mat.set_shader_parameter("outline_color", Color(0.0, 0.0, 0.0, 1.0))
			_mat.set_shader_parameter("enable_depth_outline", settings.old_depth_outline_enabled)
			_mat.set_shader_parameter("enable_normal_outline", settings.old_normal_outline_enabled)
			_mat.set_shader_parameter("enable_posterization", settings.old_posterization_enabled)
			_mat.set_shader_parameter("outline_thickness", settings.old_outline_thickness)
			_mat.set_shader_parameter("depth_threshold", settings.old_depth_threshold)
			_mat.set_shader_parameter("normal_threshold", settings.old_normal_threshold)
			_mat.set_shader_parameter("posterize_steps", settings.old_posterize_steps)
		2: # Désactivé
			quad.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		var settings = _get_settings()
		if settings != null:
			settings.shader_mode = (settings.shader_mode + 1) % 3
			settings.save_settings()
		elif has_node("quad_mesh"):
			var quad = $quad_mesh
			quad.visible = !quad.visible
