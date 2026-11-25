extends Node3D

static var _bolt_mesh: CapsuleMesh = null
static var _bolt_mat: StandardMaterial3D = null
static var _ring_mesh: TorusMesh = null
static var _ring_mat: StandardMaterial3D = null
static var _trail_mat: StandardMaterial3D = null
static var _trail_proc: ParticleProcessMaterial = null
static var _trail_quad: QuadMesh = null

@export var projectile_speed: float = 42.0
@export var max_distance: float = 46.0
@export var max_bounces: int = 1
@export var max_pierces: int = 2

@onready var attack_component: AttackComponent = $AttackComponent
@onready var scaling_component: SpellScalingComponent = $SpellScalingComponent

var _direction: Vector3 = Vector3.FORWARD
var _distance_travelled: float = 0.0
var _bounces_left: int = 1
var _pierces_left: int = 2
var _active: bool = false
var _visual_lance: MeshInstance3D = null
var _particles: GPUParticles3D = null


static func _ensure_shared_visuals() -> void:
	if _bolt_mesh == null:
		_bolt_mesh = CapsuleMesh.new()
		_bolt_mesh.radius = 0.11
		_bolt_mesh.height = 0.72
		_bolt_mesh.radial_segments = 8
		_bolt_mesh.rings = 2

	if _bolt_mat == null:
		_bolt_mat = StandardMaterial3D.new()
		_bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_bolt_mat.albedo_color = Color(2.35, 0.85, 3.6, 1.0)

	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.25
		_ring_mesh.outer_radius = 0.34
		_ring_mesh.rings = 12
		_ring_mesh.ring_segments = 6

	if _ring_mat == null:
		_ring_mat = StandardMaterial3D.new()
		_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_mat.albedo_color = Color(1.9, 0.7, 3.2, 0.85)

	if _trail_quad == null:
		_trail_quad = QuadMesh.new()
		_trail_quad.size = Vector2(0.18, 0.18)

	if _trail_mat == null:
		_trail_mat = StandardMaterial3D.new()
		_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_trail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_trail_mat.vertex_color_use_as_albedo = true
		_trail_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_trail_mat.billboard_keep_scale = true

	if _trail_proc == null:
		var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
		pm.direction = Vector3(0.0, 0.0, 1.0)
		pm.spread = 15.0
		pm.initial_velocity_min = 0.5
		pm.initial_velocity_max = 1.8
		pm.gravity = Vector3.ZERO
		pm.scale_min = 0.4
		pm.scale_max = 0.9
		pm.color = Color(1.85, 0.65, 3.1, 0.9)
		_trail_proc = pm


func _ready() -> void:
	_ensure_shared_visuals()
	_bounces_left = max_bounces
	_pierces_left = max_pierces

	_visual_lance = MeshInstance3D.new()
	_visual_lance.mesh = _bolt_mesh
	_visual_lance.material_override = _bolt_mat
	_visual_lance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual_lance.rotation.x = PI * 0.5
	add_child(_visual_lance)

	_particles = GPUParticles3D.new()
	_particles.material_override = _trail_mat
	_particles.process_material = _trail_proc
	_particles.draw_pass_1 = _trail_quad
	_particles.amount = 14
	_particles.lifetime = 0.22
	_particles.fixed_fps = 30
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_particles)

	if attack_component != null:
		attack_component.attack_landed.connect(_on_attack_landed)


func execute(caster: Node3D, target_data: Dictionary) -> void:
	if caster == null or not is_instance_valid(caster):
		queue_free()
		return

	var cast_pt: Node3D = caster.find_child("CastPoint", true, false) as Node3D
	if cast_pt != null:
		global_transform = cast_pt.global_transform
		_direction = -cast_pt.global_transform.basis.z.normalized()
	else:
		global_position = caster.global_position + Vector3(0.0, 1.45, 0.0)
		_direction = -caster.global_transform.basis.z.normalized()

	if attack_component != null:
		attack_component.on_execute(caster, target_data)
	if scaling_component != null:
		scaling_component.on_execute(caster, target_data)

	_orient_to_direction()
	_active = true
	SpellAudioManager.play_ice_cast(self, global_position, 1.38, -2.5)


func _physics_process(delta: float) -> void:
	if not _active:
		return

	var step_dist: float = projectile_speed * delta
	var cur_pos: Vector3 = global_position
	var next_pos: Vector3 = cur_pos + _direction * step_dist

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state != null:
		# Masque 129 = sol/murs (1) + arbres (128)
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(cur_pos, next_pos, 129)
		var hit: Dictionary = space_state.intersect_ray(query)
		if not hit.is_empty():
			var hit_pos: Vector3 = hit["position"] as Vector3
			var hit_normal: Vector3 = hit["normal"] as Vector3
			if _bounces_left > 0 and hit_normal.length_squared() > 0.01:
				_bounces_left -= 1
				_direction = _direction.bounce(hit_normal.normalized()).normalized()
				global_position = hit_pos + _direction * 0.12
				_orient_to_direction()
				if attack_component != null:
					attack_component.reset_hit_entities()
				_spawn_ricochet_ring(hit_pos, hit_normal)
				SpellAudioManager.play_ice_cast(self, hit_pos, 1.52, -3.5)
				_distance_travelled += cur_pos.distance_to(hit_pos)
				return
			else:
				global_position = hit_pos
				_dissipate()
				return

	global_position = next_pos
	_distance_travelled += step_dist
	if _distance_travelled >= max_distance:
		_dissipate()


func _orient_to_direction() -> void:
	if _direction.length_squared() > 0.001:
		var up_vec: Vector3 = Vector3.UP if absf(_direction.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		look_at(global_position + _direction, up_vec)


func _on_attack_landed(target: Variant) -> void:
	if not _active:
		return
	if target is HitboxComponent:
		if _pierces_left > 0:
			_pierces_left -= 1
		else:
			_dissipate()


func _spawn_ricochet_ring(pos: Vector3, normal: Vector3) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.mesh = _ring_mesh
	ring.material_override = _ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().root.add_child(ring)
	ring.global_position = pos
	var up_ref: Vector3 = Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	ring.look_at(pos + normal, up_ref)
	ring.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	ring.scale = Vector3.ONE * 0.35
	var tw: Tween = ring.create_tween()
	tw.tween_property(ring, "scale", Vector3.ONE * 1.45, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(ring.queue_free)


func _dissipate() -> void:
	if not _active:
		return
	_active = false
	if attack_component != null and is_instance_valid(attack_component):
		attack_component.set_deferred("monitoring", false)
	if _visual_lance != null:
		_visual_lance.visible = false
	if _particles != null:
		_particles.emitting = false
	get_tree().create_timer(0.24).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)
