extends Node3D

## Effet visuel caméra (chaleur orangée & braises sur les bords de l'écran) pour le joueur local enflammé (burn.tres) :
## - Même architecture que ice_slow_screen_effect.gd (s'attache automatiquement à la Camera3D du joueur local)

@onready var screen_quad: MeshInstance3D = get_node_or_null("BurnScreenQuad") as MeshInstance3D

var _shader_mat: ShaderMaterial = null
var _elapsed: float = 0.0

func _ready() -> void:
	if screen_quad != null and screen_quad.material_override is ShaderMaterial:
		_shader_mat = (screen_quad.material_override as ShaderMaterial).duplicate() as ShaderMaterial
		screen_quad.material_override = _shader_mat
		_shader_mat.set_shader_parameter("visibility", 0.36)

	call_deferred("_attach_to_player_camera")

func _attach_to_player_camera() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return

	var cam: Camera3D = null
	var status_comp := get_parent()
	if status_comp != null:
		var host := status_comp.get_parent()
		if host != null and "camera" in host and host.camera is Camera3D:
			cam = host.camera as Camera3D
		elif host != null:
			cam = host.get_node_or_null("Camera3D") as Camera3D

	if cam == null and get_viewport() != null:
		cam = get_viewport().get_camera_3d()

	if cam != null and is_instance_valid(cam) and get_parent() != cam:
		var old_parent := get_parent()
		if old_parent != null:
			old_parent.remove_child(self)
		cam.add_child(self)
		position = Vector3(0.0, 0.0, -1.0)
		rotation = Vector3.ZERO
		scale = Vector3.ONE

func _process(delta: float) -> void:
	_elapsed += delta
	if _shader_mat != null:
		var flicker := 0.34 + 0.08 * sin(_elapsed * 7.5)
		_shader_mat.set_shader_parameter("visibility", flicker)
