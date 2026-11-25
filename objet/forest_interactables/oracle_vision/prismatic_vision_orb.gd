class_name PrismaticVisionOrb
extends Node3D

## Sphère multicolore irisée libérée à la destruction du Grand Cocon d'Oracle.
## S'élève brièvement en pulsant (0.34s), puis fonce droit dans la poitrine/caméra du joueur
## et déclenche la Vision Astrale de 10 secondes vers un Totem Caché !

const PRISMATIC_ORB_SHADER := preload("res://objet/forest_interactables/oracle_vision/prismatic_orb.gdshader")
const TOTEM_VISION_EFFECT_SCRIPT := preload("res://objet/forest_interactables/oracle_vision/totem_vision_effect.gd")
const SFX_LAUNCH := "res://assets/sound_effects/UI/wav (HD)/JDSherbert - Ultimate UI SFX Pack - Select - 2.wav"

@export var vision_duration: float = 14.8
@export var hover_duration: float = 0.34
@export var max_speed: float = 34.0
@export var impact_radius: float = 1.15
@export var max_lifetime: float = 12.0

var _target_player: Node3D = null
var _elapsed: float = 0.0
var _consumed: bool = false
var _vel: Vector3 = Vector3(0.0, 3.6, 0.0)
var _visual_root: Node3D = null
var _ring_a: MeshInstance3D = null
var _ring_b: MeshInstance3D = null
var _swoop_sound_played: bool = false


func setup_seeker(start_pos: Vector3, preferred_player: Node3D = null, p_duration: float = 10.0) -> void:
	global_position = start_pos
	_target_player = preferred_player
	vision_duration = p_duration


func _ready() -> void:
	_build_visuals()


func _build_visuals() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "PrismaticVisualRoot"
	add_child(_visual_root)

	var orb_mat := ShaderMaterial.new()
	orb_mat.shader = PRISMATIC_ORB_SHADER
	orb_mat.set_shader_parameter("pulse_speed", 4.2)
	orb_mat.set_shader_parameter("brightness", 3.1)
	orb_mat.set_shader_parameter("alpha_base", 0.96)

	var core_mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.36
	sph.height = 0.72
	sph.radial_segments = 28
	sph.rings = 14
	core_mi.mesh = sph
	core_mi.material_override = orb_mat
	core_mi.layers = 2
	core_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual_root.add_child(core_mi)

	# Deux anneaux prismatiques contre-rotatifs
	var torus_mesh := TorusMesh.new()
	torus_mesh.inner_radius = 0.48
	torus_mesh.outer_radius = 0.54
	torus_mesh.rings = 24
	torus_mesh.ring_segments = 8

	_ring_a = MeshInstance3D.new()
	_ring_a.mesh = torus_mesh
	_ring_a.material_override = orb_mat
	_ring_a.layers = 2
	_ring_a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual_root.add_child(_ring_a)

	_ring_b = MeshInstance3D.new()
	_ring_b.mesh = torus_mesh
	_ring_b.scale = Vector3.ONE * 1.18
	_ring_b.material_override = orb_mat
	_ring_b.layers = 2
	_ring_b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual_root.add_child(_ring_b)

	# Lumière locale irisée
	var light := OmniLight3D.new()
	light.light_color = Color(0.85, 0.55, 1.0)
	light.light_energy = 1.65
	light.omni_range = 6.5
	_visual_root.add_child(light)

	# Sillage de poussière multicolore pendant le vol vers le joueur
	var trail := GPUParticles3D.new()
	trail.layers = 2
	trail.amount = 36
	trail.lifetime = 0.55
	trail.local_coords = false
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 0.24
	pmat.gravity = Vector3.ZERO
	pmat.initial_velocity_min = 0.4
	pmat.initial_velocity_max = 1.6
	pmat.scale_min = 0.9
	pmat.scale_max = 2.1

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 0.70, 1.0])
	grad.colors = PackedColorArray([
		Color(0.35, 1.8, 2.5, 0.95),
		Color(2.2, 0.45, 2.4, 0.85),
		Color(2.4, 1.65, 0.35, 0.55),
		Color(0.4, 0.2, 1.0, 0.0)
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	pmat.color_ramp = ramp
	trail.process_material = pmat
	trail.draw_pass_1 = ProceduralForestMeshes.get_spore_quad_mesh(0.18)
	add_child(trail)


func _process(delta: float) -> void:
	if _consumed:
		return

	_elapsed += delta
	if _elapsed >= max_lifetime:
		queue_free()
		return

	if _ring_a != null:
		_ring_a.rotate_x(delta * 4.5)
		_ring_a.rotate_z(delta * 2.8)
	if _ring_b != null:
		_ring_b.rotate_y(-delta * 5.2)
		_ring_b.rotate_x(-delta * 2.4)

	# Résolution / verrouillage du joueur cible
	if _target_player == null or not is_instance_valid(_target_player) or _target_player.get("is_dead") == true:
		_target_player = _find_nearest_alive_player()

	# Phase 1 : Éveil & lévitation brève hors du cocon brisé
	if _elapsed < hover_duration:
		var u: float = _elapsed / maxf(0.01, hover_duration)
		global_position += _vel * (1.0 - u * 0.75) * delta
		if _visual_root != null:
			_visual_root.scale = Vector3.ONE * lerpf(0.75, 1.25, u)
		return

	if not _swoop_sound_played:
		_swoop_sound_played = true
		if ResourceLoader.exists(SFX_LAUNCH):
			var sfx := AudioStreamPlayer3D.new()
			sfx.stream = load(SFX_LAUNCH)
			sfx.pitch_scale = 0.78
			sfx.volume_db = -7.0
			sfx.max_distance = 28.0
			add_child(sfx)
			sfx.play()

	if _target_player == null:
		return

	# Cible : pile vers la caméra / haut du torse du joueur pour qu'elle lui "rentre dedans" !
	var cam_node: Camera3D = _target_player.get_node_or_null("Camera3D") as Camera3D
	var target_pos: Vector3 = cam_node.global_position if cam_node != null else (_target_player.global_position + Vector3(0.0, 1.45, 0.0))

	var swoop_t: float = clampf((_elapsed - hover_duration) / 0.45, 0.0, 1.0)
	var cur_speed: float = lerpf(9.5, max_speed, swoop_t * swoop_t)

	var to_target: Vector3 = target_pos - global_position
	var dist: float = to_target.length()
	if dist <= impact_radius:
		_impact_player(_target_player)
		return

	var desired_dir: Vector3 = to_target / maxf(0.001, dist)
	# Légère courbe latérale organique au départ qui se verrouille à 100% sur le joueur
	var side_dir: Vector3 = desired_dir.cross(Vector3.UP)
	if side_dir.length_squared() > 0.001:
		side_dir = side_dir.normalized()
	var curve_push: Vector3 = side_dir * sin((1.0 - swoop_t) * PI) * 4.5 * (1.0 - swoop_t)

	global_position += (desired_dir * cur_speed + curve_push) * delta


func _find_nearest_alive_player() -> Node3D:
	var best: Node3D = null
	var best_d: float = INF
	for p: Node in get_tree().get_nodes_in_group("Player"):
		var p3: Node3D = p as Node3D
		if p3 == null or not is_instance_valid(p3) or p3.get("is_dead") == true:
			continue
		var d: float = global_position.distance_squared_to(p3.global_position)
		if d < best_d:
			best_d = d
			best = p3
	return best


func _impact_player(player: Node3D) -> void:
	if _consumed:
		return
	_consumed = true
	TOTEM_VISION_EFFECT_SCRIPT.trigger_on_player(player, vision_duration)
	queue_free()
