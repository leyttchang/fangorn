extends RigidBody3D

const FIRE_TEX_PATH: String = "res://assets/LeLu's Noise Pack/T_fire01.png"

static var _core_mesh: SphereMesh = null
static var _core_mat: StandardMaterial3D = null
static var _trail_mat: StandardMaterial3D = null
static var _trail_proc: ParticleProcessMaterial = null
static var _trail_quad: QuadMesh = null

@export var lifespan: float = 0.52

@onready var attack_component: AttackComponent = $AttackComponent
@onready var scaling_component: SpellScalingComponent = $SpellScalingComponent
@onready var movement_component: ProjectileMovementComponent = $ProjectileMovementComponent

var _impacted: bool = false
var _trail_particles: GPUParticles3D = null
var _core_visual: MeshInstance3D = null


static func _ensure_visuals() -> void:
	if _core_mesh == null:
		_core_mesh = SphereMesh.new()
		_core_mesh.radius = 0.16
		_core_mesh.height = 0.42
		_core_mesh.radial_segments = 8
		_core_mesh.rings = 4

	if _core_mat == null:
		_core_mat = StandardMaterial3D.new()
		_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_core_mat.albedo_color = Color(3.2, 1.35, 0.22, 1.0)

	if _trail_quad == null:
		_trail_quad = QuadMesh.new()
		_trail_quad.size = Vector2(0.32, 0.32)

	if _trail_mat == null:
		_trail_mat = StandardMaterial3D.new()
		_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_trail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_trail_mat.vertex_color_use_as_albedo = true
		_trail_mat.vertex_color_is_srgb = true
		if ResourceLoader.exists(FIRE_TEX_PATH):
			_trail_mat.albedo_texture = load(FIRE_TEX_PATH) as Texture2D
		_trail_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_trail_mat.billboard_keep_scale = true

	if _trail_proc == null:
		var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
		pm.direction = Vector3(0.0, 0.0, 1.0)
		pm.spread = 22.0
		pm.initial_velocity_min = 0.8
		pm.initial_velocity_max = 2.4
		pm.gravity = Vector3(0.0, 0.6, 0.0)
		pm.scale_min = 0.35
		pm.scale_max = 0.85
		pm.color = Color(2.6, 1.05, 0.2, 1.0)
		var grad: Gradient = Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		grad.colors = PackedColorArray([
			Color(1.0, 0.92, 0.55, 1.0),
			Color(1.0, 0.38, 0.05, 0.85),
			Color(0.6, 0.08, 0.01, 0.0)
		])
		var ramp: GradientTexture1D = GradientTexture1D.new()
		ramp.gradient = grad
		pm.color_ramp = ramp
		_trail_proc = pm


func _ready() -> void:
	gravity_scale = 0.0
	_ensure_visuals()

	_core_visual = MeshInstance3D.new()
	_core_visual.mesh = _core_mesh
	_core_visual.material_override = _core_mat
	_core_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_core_visual.rotation.x = PI * 0.5
	add_child(_core_visual)

	_trail_particles = GPUParticles3D.new()
	_trail_particles.material_override = _trail_mat
	_trail_particles.process_material = _trail_proc
	_trail_particles.draw_pass_1 = _trail_quad
	_trail_particles.amount = 14
	_trail_particles.lifetime = 0.26
	_trail_particles.fixed_fps = 30
	_trail_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail_particles)

	if attack_component != null:
		attack_component.attack_landed.connect(_on_attack_landed)

	get_tree().create_timer(lifespan).timeout.connect(_dissipate)


func execute(caster: Node3D, target_data: Dictionary) -> void:
	for child: Node in get_children():
		if child.has_method("on_execute"):
			child.call("on_execute", caster, target_data)
	var cast_pos: Vector3 = global_position if global_position != Vector3.ZERO else (caster.global_position if is_instance_valid(caster) else Vector3.ZERO)
	SpellAudioManager.play_fire_cast(self, cast_pos, 1.28, -2.8)


func _on_attack_landed(_target: Variant) -> void:
	if _impacted:
		return
	SpellAudioManager.play_fire_impact(self, global_position, 1.38, -4.2)
	_dissipate()


func _dissipate() -> void:
	if _impacted or not is_instance_valid(self):
		return
	_impacted = true
	linear_velocity = Vector3.ZERO
	freeze = true
	if attack_component != null and is_instance_valid(attack_component):
		attack_component.set_deferred("monitoring", false)
	if _core_visual != null:
		_core_visual.visible = false
	if _trail_particles != null:
		_trail_particles.emitting = false
	get_tree().create_timer(0.28).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)
