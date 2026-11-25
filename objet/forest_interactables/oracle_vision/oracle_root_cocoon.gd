@tool
class_name OracleRootCocoon
extends Node3D

## Grand Cocon de Racines d'Oracle placé près du Spawn (~2x plus imposant qu'un cocon normal).
## Renferme une sphère prismatique multicolore en lévitation entre 9 côtes de racines anciennes.
## Lorsqu'il est brisé, les racines explosent en physique Jolt et la sphère multicolore fonce
## dans le joueur pour déclencher 10s de Vision Astrale vers un Totem Caché !

const PRISMATIC_ORB_SHADER := preload("res://objet/forest_interactables/oracle_vision/prismatic_orb.gdshader")
const PRISMATIC_VISION_ORB_SCRIPT := preload("res://objet/forest_interactables/oracle_vision/prismatic_vision_orb.gd")
const CHUNK_MESH_PATH := "res://assets/3D_models/VFX_spell/insect_chunk_1_mesh.tres"
const SFX_SNAP_PATH := "res://assets/sound_effects/Combat and Gore/bone_snap.wav"
const SFX_CRUNCH_PATH := "res://assets/sound_effects/Combat and Gore/crunch.wav"
const SFX_WOOD_HEAVY := "res://assets/sound_effects/Combat and Gore/impactWood_heavy_000.ogg"

@export var vision_duration: float = 14.8
@export var cocoon_scale_factor: float = 1.95
@export var shatter_horizontal_impulse: float = 7.2
@export var shatter_upward_impulse: float = 4.6
@export var shatter_torque_impulse: float = 3.2
@export var visibility_max_distance: float = 190.0

static var _cached_oracle_ribs: Array[Dictionary] = []
static var _shared_oracle_root_mat: ShaderMaterial = null

var _is_destroyed: bool = false
var _visual_root: Node3D = null
var _rib_nodes: Array[MeshInstance3D] = []
var _core_pivot: Node3D = null
var _ring_outer: MeshInstance3D = null
var _hitbox: BreakableHitbox = null
var _solid_body: StaticBody3D = null
var _idle_time: float = 0.0


func _ready() -> void:
	_rebuild_visuals()
	if not Engine.is_editor_hint():
		_setup_collisions()


func _process(delta: float) -> void:
	if _is_destroyed or _core_pivot == null or not is_instance_valid(_core_pivot):
		return
	_idle_time += delta
	_core_pivot.position.y = 1.18 + sin(_idle_time * 2.2) * 0.08
	_core_pivot.rotate_y(delta * 0.95)
	if _ring_outer != null and is_instance_valid(_ring_outer):
		_ring_outer.rotate_x(delta * 1.45)
		_ring_outer.rotate_z(-delta * 0.85)


static func _get_oracle_ribs() -> Array[Dictionary]:
	if not _cached_oracle_ribs.is_empty():
		return _cached_oracle_ribs

	var count: int = 9
	for i in range(count):
		var base_ang: float = (TAU / float(count)) * float(i)
		var rng := RandomNumberGenerator.new()
		rng.seed = 77100 + i * 37
		var pts := PackedVector3Array()
		var steps: int = 16
		var top_h: float = rng.randf_range(2.22, 2.52)
		var belly_r: float = rng.randf_range(0.82, 0.98)
		var twist_total: float = rng.randf_range(0.42, 0.72) * (1.0 if i % 2 == 0 else -1.0)

		for s in range(steps + 1):
			var u: float = float(s) / float(steps)
			var h: float = lerpf(-0.08, top_h, u)
			var arch: float = sin(u * PI)
			var r: float = lerpf(0.62, belly_r, arch) * lerpf(1.0, 0.24, u * u)
			var ang: float = base_ang + twist_total * u + sin(u * PI * 2.0) * 0.08
			pts.append(Vector3(cos(ang) * r, h, sin(ang) * r))

		var built: Dictionary = ProceduralForestMeshes.build_centered_root_tube(pts, 0.145, 8, 0.022, i + 11)
		_cached_oracle_ribs.append(built)

	return _cached_oracle_ribs


func _rebuild_visuals() -> void:
	if Engine.is_editor_hint():
		_cached_oracle_ribs.clear()
		_shared_oracle_root_mat = null

	if _visual_root != null and is_instance_valid(_visual_root):
		remove_child(_visual_root)
		_visual_root.queue_free()
	_rib_nodes.clear()

	_visual_root = Node3D.new()
	_visual_root.name = "OracleCocoonVisual"
	add_child(_visual_root)

	var no_limit: bool = Engine.is_editor_hint()
	var vis_end: float = 0.0 if no_limit else visibility_max_distance

	if _shared_oracle_root_mat == null:
		_shared_oracle_root_mat = ProceduralForestMeshes.get_base_root_material(Color(0.58, 0.46, 0.36, 1.0), 0.095, 2.2)

	# 1. Grande Sphère Multicolore captive au coeur de la cage de racines
	_core_pivot = Node3D.new()
	_core_pivot.name = "CaptivePrismaticSphere"
	_core_pivot.position = Vector3(0.0, 1.18, 0.0)
	_visual_root.add_child(_core_pivot)

	var orb_mat := ShaderMaterial.new()
	orb_mat.shader = PRISMATIC_ORB_SHADER
	orb_mat.set_shader_parameter("pulse_speed", 2.9)
	orb_mat.set_shader_parameter("brightness", 2.75)
	orb_mat.set_shader_parameter("alpha_base", 0.95)

	var core_mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.44
	sph.height = 0.88
	sph.radial_segments = 28
	sph.rings = 14
	core_mi.mesh = sph
	core_mi.material_override = orb_mat
	core_mi.layers = 2
	core_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core_mi.visibility_range_end = vis_end
	core_mi.visibility_range_end_margin = 25.0 if vis_end > 0.0 else 0.0
	_core_pivot.add_child(core_mi)

	_ring_outer = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.56
	torus.outer_radius = 0.61
	torus.rings = 24
	torus.ring_segments = 8
	_ring_outer.mesh = torus
	_ring_outer.material_override = orb_mat
	_ring_outer.layers = 2
	_ring_outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring_outer.visibility_range_end = vis_end
	_ring_outer.visibility_range_end_margin = 25.0 if vis_end > 0.0 else 0.0
	_core_pivot.add_child(_ring_outer)

	var glow_light := OmniLight3D.new()
	glow_light.light_color = Color(0.82, 0.58, 1.0)
	glow_light.light_energy = 1.35
	glow_light.omni_range = 7.5
	_core_pivot.add_child(glow_light)

	# Spores irisées flottant doucement autour du grand cocon pour attirer l'oeil dès le spawn
	if not Engine.is_editor_hint():
		var wisps := GPUParticles3D.new()
		wisps.layers = 2
		wisps.position = Vector3(0.0, 1.15, 0.0)
		wisps.amount = 22
		wisps.lifetime = 2.4
		wisps.visibility_range_end = 110.0
		wisps.visibility_range_end_margin = 18.0
		wisps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		var wmat := ParticleProcessMaterial.new()
		wmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		wmat.emission_sphere_radius = 0.95
		wmat.gravity = Vector3(0.0, 0.28, 0.0)
		wmat.initial_velocity_min = 0.12
		wmat.initial_velocity_max = 0.45
		wmat.scale_min = 0.8
		wmat.scale_max = 1.6

		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
		grad.colors = PackedColorArray([
			Color(0.3, 1.8, 2.4, 0.0),
			Color(2.0, 0.45, 2.3, 0.85),
			Color(2.2, 1.65, 0.35, 0.65),
			Color(0.4, 0.9, 2.2, 0.0)
		])
		var ramp := GradientTexture1D.new()
		ramp.gradient = grad
		wmat.color_ramp = ramp
		wisps.process_material = wmat
		wisps.draw_pass_1 = ProceduralForestMeshes.get_spore_quad_mesh(0.14)
		_visual_root.add_child(wisps)

	# 2. 9 Côtes géantes de racines anciennes entrelacées
	var ribs: Array[Dictionary] = _get_oracle_ribs()
	for i in range(ribs.size()):
		var rib_data: Dictionary = ribs[i]
		var mi := MeshInstance3D.new()
		mi.name = "OracleRib_" + str(i)
		mi.mesh = rib_data["mesh"]
		mi.position = rib_data["center"]
		mi.material_override = _shared_oracle_root_mat
		mi.layers = 2
		mi.visibility_range_end = vis_end
		mi.visibility_range_end_margin = 25.0 if vis_end > 0.0 else 0.0
		_visual_root.add_child(mi)
		_rib_nodes.append(mi)


func _setup_collisions() -> void:
	_solid_body = get_node_or_null("StaticBody3D") as StaticBody3D
	_hitbox = get_node_or_null("BreakableHitbox") as BreakableHitbox
	if _hitbox != null and not _hitbox.breakable_struck.is_connected(_on_struck):
		_hitbox.breakable_struck.connect(_on_struck)


func _on_struck(attacker: Node3D, hit_dir: Vector3, _attack: AttackComponent) -> void:
	if _is_destroyed:
		return

	var attacker_id: int = 1
	if attacker != null and is_instance_valid(attacker) and str(attacker.name).is_valid_int():
		attacker_id = int(str(attacker.name))

	if not multiplayer.has_multiplayer_peer():
		_rpc_explode_oracle_cocoon(hit_dir, attacker_id)
	elif multiplayer.is_server():
		_rpc_explode_oracle_cocoon.rpc(hit_dir, attacker_id)
	else:
		_rpc_request_shatter.rpc_id(1, hit_dir, attacker_id)


@rpc("any_peer", "call_local", "reliable")
func _rpc_request_shatter(hit_dir: Vector3, attacker_id: int) -> void:
	if not multiplayer.is_server() or _is_destroyed:
		return
	_rpc_explode_oracle_cocoon.rpc(hit_dir, attacker_id)


@rpc("authority", "call_local", "reliable")
func _rpc_explode_oracle_cocoon(hit_dir: Vector3, attacker_id: int) -> void:
	if _is_destroyed:
		return
	_is_destroyed = true

	if _solid_body != null and is_instance_valid(_solid_body):
		_solid_body.collision_layer = 0
		_solid_body.collision_mask = 0
		_solid_body.queue_free()
	if _hitbox != null and is_instance_valid(_hitbox):
		_hitbox.collision_layer = 0
		_hitbox.collision_mask = 0

	var orb_spawn_pos: Vector3 = global_position + Vector3(0.0, 1.18, 0.0)
	if _core_pivot != null and is_instance_valid(_core_pivot):
		orb_spawn_pos = _core_pivot.global_position
		_core_pivot.visible = false

	_shatter_roots_jolt(hit_dir)
	_spawn_burst_particles(hit_dir)
	_play_shatter_audio()
	_spawn_homing_prismatic_orb(orb_spawn_pos, attacker_id)

	var cleanup := get_tree().create_timer(2.1)
	cleanup.timeout.connect(queue_free)


func _spawn_homing_prismatic_orb(spawn_pos: Vector3, attacker_id: int) -> void:
	var target_player: Node3D = null
	for p: Node in get_tree().get_nodes_in_group("Player"):
		if p is Node3D and str(p.name) == str(attacker_id):
			target_player = p as Node3D
			break

	var host: Node = get_parent() if get_parent() != null else get_tree().current_scene
	if host == null:
		return
	var seeker: Node3D = PRISMATIC_VISION_ORB_SCRIPT.new()
	host.add_child(seeker)
	seeker.call("setup_seeker", spawn_pos, target_player, vision_duration)


func _shatter_roots_jolt(hit_dir: Vector3) -> void:
	var cocoon_center: Vector3 = global_position + Vector3(0.0, 1.15, 0.0)
	var impulse_list: Array[Dictionary] = []

	for i in range(_rib_nodes.size()):
		var src_mi: MeshInstance3D = _rib_nodes[i]
		if src_mi == null or not is_instance_valid(src_mi):
			continue
		src_mi.visible = false

		var rb := RigidBody3D.new()
		rb.collision_layer = 0
		rb.collision_mask = 1
		rb.mass = 0.95
		rb.position = src_mi.position
		rb.rotation = src_mi.rotation

		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.26, 0.72, 0.26)
		col.shape = box
		rb.add_child(col)

		var flying_mi := MeshInstance3D.new()
		flying_mi.layers = 2
		flying_mi.mesh = src_mi.mesh
		var unique_mat: ShaderMaterial = _shared_oracle_root_mat.duplicate() as ShaderMaterial
		unique_mat.set_shader_parameter("fin", 0.0)
		unique_mat.set_shader_parameter("debut", 1.0)
		flying_mi.material_override = unique_mat
		flying_mi.visibility_range_end = 160.0
		flying_mi.visibility_range_end_margin = 20.0
		rb.add_child(flying_mi)
		add_child(rb)

		var radial: Vector3 = rb.global_position - cocoon_center
		radial.y = 0.0
		if radial.length_squared() < 0.001:
			var ang: float = (TAU / 9.0) * float(i)
			radial = Vector3(cos(ang), 0.0, sin(ang))
		else:
			radial = radial.normalized()

		var burst_dir: Vector3 = (radial * 0.75 + hit_dir * 0.65).normalized()
		var central_imp: Vector3 = burst_dir * (shatter_horizontal_impulse * randf_range(0.85, 1.25)) + Vector3.UP * (shatter_upward_impulse * randf_range(0.8, 1.25))
		var torque_imp: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(-0.8, 0.8), randf_range(-1.0, 1.0)).normalized() * shatter_torque_impulse

		impulse_list.append({
			"rb": rb,
			"central": central_imp,
			"torque": torque_imp,
			"mat": unique_mat
		})

	_apply_impulses_deferred(impulse_list)


func _apply_impulses_deferred(impulse_list: Array[Dictionary]) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	await get_tree().physics_frame
	for item: Dictionary in impulse_list:
		var rb: RigidBody3D = item["rb"]
		var mat: ShaderMaterial = item["mat"]
		if is_instance_valid(rb) and rb.is_inside_tree():
			rb.apply_central_impulse(item["central"])
			rb.apply_torque_impulse(item["torque"])
			var tw: Tween = create_tween()
			tw.tween_interval(randf_range(0.18, 0.34))
			tw.tween_method(func(val: float) -> void:
				if mat != null:
					mat.set_shader_parameter("fin", val)
			, 0.0, 1.0, 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _spawn_burst_particles(hit_dir: Vector3) -> void:
	if ResourceLoader.exists(CHUNK_MESH_PATH):
		var splinters := GPUParticles3D.new()
		splinters.layers = 2
		splinters.position = Vector3(0.0, 1.15, 0.0)
		splinters.amount = 26
		splinters.lifetime = 1.15
		splinters.one_shot = true
		splinters.explosiveness = 0.96

		var smat := ParticleProcessMaterial.new()
		smat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		smat.emission_sphere_radius = 0.45
		smat.direction = (hit_dir + Vector3(0.0, 0.9, 0.0)).normalized()
		smat.spread = 80.0
		smat.initial_velocity_min = 4.8
		smat.initial_velocity_max = 10.5
		smat.angular_velocity_min = -360.0
		smat.angular_velocity_max = 360.0
		smat.gravity = Vector3(0.0, -14.0, 0.0)
		smat.scale_min = 0.22
		smat.scale_max = 0.48
		splinters.process_material = smat
		splinters.draw_pass_1 = load(CHUNK_MESH_PATH) as Mesh
		add_child(splinters)
		splinters.emitting = true

	var prism_burst := GPUParticles3D.new()
	prism_burst.layers = 2
	prism_burst.position = Vector3(0.0, 1.18, 0.0)
	prism_burst.amount = 40
	prism_burst.lifetime = 0.95
	prism_burst.one_shot = true
	prism_burst.explosiveness = 0.96

	var cmat := ParticleProcessMaterial.new()
	cmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	cmat.emission_sphere_radius = 0.38
	cmat.spread = 180.0
	cmat.initial_velocity_min = 3.0
	cmat.initial_velocity_max = 8.2
	cmat.damping_min = 4.5
	cmat.damping_max = 7.5
	cmat.gravity = Vector3.ZERO
	cmat.scale_min = 1.4
	cmat.scale_max = 3.0

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	grad.colors = PackedColorArray([
		Color(0.4, 2.2, 2.8, 1.0),
		Color(2.4, 0.45, 2.6, 0.9),
		Color(2.5, 1.8, 0.35, 0.6),
		Color(0.3, 0.1, 0.8, 0.0)
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	cmat.color_ramp = ramp
	prism_burst.process_material = cmat
	prism_burst.draw_pass_1 = ProceduralForestMeshes.get_spore_quad_mesh(0.28)
	add_child(prism_burst)
	prism_burst.emitting = true


func _play_shatter_audio() -> void:
	for entry: Array in [
		[SFX_SNAP_PATH, 0.72, -6.5],
		[SFX_CRUNCH_PATH, 0.78, -7.5],
		[SFX_WOOD_HEAVY, 0.82, -6.0]
	]:
		var p_str: String = entry[0]
		if ResourceLoader.exists(p_str):
			var s := AudioStreamPlayer3D.new()
			s.stream = load(p_str)
			s.pitch_scale = float(entry[1]) * randf_range(0.94, 1.06)
			s.volume_db = float(entry[2])
			s.max_distance = 30.0
			add_child(s)
			s.play()
