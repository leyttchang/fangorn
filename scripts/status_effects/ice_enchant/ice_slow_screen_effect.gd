extends Node3D

## Effet visuel caméra (givre sur les bords de l'écran) pour le joueur local ralenti :
## - L'intensité du givre augmente à chaque stack supplémentaire de slow
## - Joue une brève pulsation glacée lorsqu'une nouvelle nova ajoute un stack

@onready var screen_quad: MeshInstance3D = get_node_or_null("FrostScreenQuad") as MeshInstance3D
@onready var frost_flakes: GPUParticles3D = get_node_or_null("FrostFlakes") as GPUParticles3D

var _shader_mat: ShaderMaterial = null
var _base_visibility: float = 0.28
var _pulse_bonus: float = 0.0

func _ready() -> void:
	if screen_quad != null and screen_quad.material_override is ShaderMaterial:
		_shader_mat = (screen_quad.material_override as ShaderMaterial).duplicate() as ShaderMaterial
		screen_quad.material_override = _shader_mat
		_shader_mat.set_shader_parameter("visibility", _base_visibility)

	if frost_flakes != null:
		frost_flakes.amount_ratio = 0.35

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

func set_slow_stacks(stacks: int, max_stacks: int, pulse_flash: bool = false) -> void:
	var ratio := clampf(float(stacks) / float(maxi(1, max_stacks)), 0.0, 1.0)
	_base_visibility = lerpf(0.26, 0.92, ratio)
	if pulse_flash:
		_pulse_bonus = 0.26
	else:
		_pulse_bonus = 0.14

	if frost_flakes != null:
		frost_flakes.amount_ratio = lerpf(0.30, 1.0, ratio)

	_update_shader_visibility()

func _process(delta: float) -> void:
	if _pulse_bonus > 0.0:
		_pulse_bonus = move_toward(_pulse_bonus, 0.0, delta * 0.65)
		_update_shader_visibility()

func _update_shader_visibility() -> void:
	if _shader_mat != null:
		_shader_mat.set_shader_parameter("visibility", clampf(_base_visibility + _pulse_bonus, 0.0, 1.15))
