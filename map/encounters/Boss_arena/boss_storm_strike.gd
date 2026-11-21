class_name BossStormStrike
extends Node3D

## Éclair individuel de la Tempête du Boss (Ogre buffé par le Totem Foudre) :
## 1. Phase Télégraphe (~1.0s) : fin filet d'éclair vertical (chain_lightning.gdshader) + fin anneau électrique au sol
## 2. Phase Impact (~0.85s) : l'éclair de Lightning Strike s'abat pile au point d'impact, inflige les dégâts aux joueurs,
##    puis tous les effets visuels disparaissent proprement.

static var _shared_cyl: CylinderMesh
static var _shared_ring: TorusMesh
static var _shared_dot: SphereMesh

@export var filament_material_1: Material
@export var filament_material_2: Material
@export var point_material: Material

@onready var telegraph_holder: Node3D = $TelegraphHolder
@onready var bolt_particles: GPUParticles3D = $ThunderBoltParticles
@onready var sparks_particles: GPUParticles3D = $SparksParticles
@onready var trails_particles: GPUParticles3D = $TrailsParticles
@onready var ground_decal: Decal = $GroundDecal
@onready var strike_light: OmniLight3D = $StrikeLight

var telegraph_duration: float = 1.0
var post_strike_duration: float = 0.85
var sky_height: float = 13.5
var strike_radius: float = 1.6
var strike_damage_callback: Callable = Callable()

const FILAMENT_SEGMENTS := 9
var _strand_a: Array[MeshInstance3D] = []
var _strand_b: Array[MeshInstance3D] = []
var _ground_ring_mesh: MeshInstance3D
var _ground_dot_mesh: MeshInstance3D

var _elapsed: float = 0.0
var _struck: bool = false
var _hit_players: Dictionary = {}

static func _ensure_shared_meshes() -> void:
	if _shared_cyl == null:
		_shared_cyl = CylinderMesh.new()
		_shared_cyl.top_radius = 1.0
		_shared_cyl.bottom_radius = 1.0
		_shared_cyl.height = 1.0
		_shared_cyl.radial_segments = 5
		_shared_cyl.rings = 1
	if _shared_ring == null:
		_shared_ring = TorusMesh.new()
		_shared_ring.inner_radius = 0.94
		_shared_ring.outer_radius = 1.0
		_shared_ring.rings = 24
		_shared_ring.ring_segments = 6
	if _shared_dot == null:
		_shared_dot = SphereMesh.new()
		_shared_dot.radius = 1.0
		_shared_dot.height = 2.0
		_shared_dot.radial_segments = 8
		_shared_dot.rings = 4

func configure(
	p_telegraph_duration: float,
	p_strike_radius: float,
	p_damage_cb: Callable = Callable(),
	p_post_duration: float = 0.85
) -> void:
	telegraph_duration = maxf(0.15, p_telegraph_duration)
	strike_radius = maxf(0.4, p_strike_radius)
	strike_damage_callback = p_damage_cb
	post_strike_duration = maxf(0.45, p_post_duration)

func _ready() -> void:
	_ensure_shared_meshes()
	_build_telegraph_meshes()

	if ground_decal != null:
		ground_decal.visible = false
		var d_size := strike_radius * 2.15
		ground_decal.size = Vector3(d_size, 2.5, d_size)

	# Adapter l'échelle radiale du mesh d'éclair par rapport au rayon de référence 1.5m de LightningStrike
	var scale_ratio := clampf(strike_radius / 1.5, 0.55, 2.5)
	if bolt_particles != null and bolt_particles.process_material is ParticleProcessMaterial:
		var pm := (bolt_particles.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
		pm.scale_min = 0.3 * scale_ratio
		pm.scale_max = 0.3 * scale_ratio
		bolt_particles.process_material = pm
		bolt_particles.position.y = 4.4784245 * scale_ratio

func _build_telegraph_meshes() -> void:
	if telegraph_holder == null:
		return

	for _i in range(FILAMENT_SEGMENTS):
		var ma := MeshInstance3D.new()
		ma.mesh = _shared_cyl
		ma.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if filament_material_1 != null:
			ma.material_override = filament_material_1
		telegraph_holder.add_child(ma)
		_strand_a.append(ma)

		var mb := MeshInstance3D.new()
		mb.mesh = _shared_cyl
		mb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if filament_material_2 != null:
			mb.material_override = filament_material_2
		telegraph_holder.add_child(mb)
		_strand_b.append(mb)

	_ground_ring_mesh = MeshInstance3D.new()
	_ground_ring_mesh.mesh = _shared_ring
	_ground_ring_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if filament_material_2 != null:
		_ground_ring_mesh.material_override = filament_material_2
	_ground_ring_mesh.position = Vector3(0.0, 0.06, 0.0)
	telegraph_holder.add_child(_ground_ring_mesh)

	_ground_dot_mesh = MeshInstance3D.new()
	_ground_dot_mesh.mesh = _shared_dot
	_ground_dot_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if point_material != null:
		_ground_dot_mesh.material_override = point_material
	_ground_dot_mesh.position = Vector3(0.0, 0.09, 0.0)
	telegraph_holder.add_child(_ground_dot_mesh)

func cancel_if_telegraphing() -> void:
	if not _struck:
		queue_free()

func _process(delta: float) -> void:
	_elapsed += delta

	if not _struck:
		if _elapsed < telegraph_duration:
			_update_telegraph_visuals(_elapsed / telegraph_duration)
			return
		else:
			_trigger_lightning_strike()

	# Phase post-impact : dissipation rapide de tous les effets puis suppression complète
	var post_t := _elapsed - telegraph_duration
	var s := clampf(post_t / post_strike_duration, 0.0, 1.0)

	# Fenêtre active de dégâts pendant le claquement de l'éclair (0.14s)
	if post_t <= 0.14 and strike_damage_callback.is_valid():
		strike_damage_callback.call(global_position, strike_radius, _hit_players)

	if strike_light != null:
		strike_light.light_energy = 3.4 * pow(1.0 - s, 2.2)

	if ground_decal != null:
		var alpha := clampf(1.0 - smoothstep(0.18, 0.92, s), 0.0, 1.0)
		ground_decal.modulate = Color(0.20, 0.48, 0.78, 0.85 * alpha)

	if post_t >= post_strike_duration:
		queue_free()

func _update_telegraph_visuals(u: float) -> void:
	var pulse := 0.5 + 0.5 * sin(u * TAU * (3.0 + u * 3.0))
	var thick_a := lerpf(0.014, 0.038, pulse) * lerpf(0.85, 1.45, u)
	var thick_b := thick_a * 0.72
	var jitter_amp := lerpf(0.06, 0.19, u) * (0.65 + 0.35 * pulse)

	var top_local := Vector3(0.0, sky_height, 0.0)
	var bot_local := Vector3(0.0, 0.04, 0.0)

	_layout_filament(_strand_a, top_local, bot_local, thick_a, jitter_amp)
	_layout_filament(_strand_b, top_local, bot_local, thick_b, jitter_amp * 1.25)

	if _ground_ring_mesh != null:
		var ring_y_scale := lerpf(0.45, 1.25, pulse)
		_ground_ring_mesh.scale = Vector3(strike_radius, ring_y_scale, strike_radius)

	if _ground_dot_mesh != null:
		var dot_s := lerpf(0.08, 0.19, pulse * u + 0.25)
		_ground_dot_mesh.scale = Vector3.ONE * dot_s

	if strike_light != null:
		strike_light.position = Vector3(0.0, 0.6, 0.0)
		strike_light.light_energy = lerpf(0.15, 0.75, u * pulse)

func _layout_filament(segs: Array[MeshInstance3D], p_top: Vector3, p_bot: Vector3, radius: float, spread: float) -> void:
	var count := segs.size()
	if count == 0:
		return

	var pts := PackedVector3Array()
	pts.resize(count + 1)
	pts[0] = p_top
	pts[count] = p_bot

	for i in range(1, count):
		var f := float(i) / float(count)
		var base_p := p_top.lerp(p_bot, f)
		# Moins d'écart tout en bas pour que le filet pointe exactement le centre d'impact au sol
		var env := sin(f * PI) * lerpf(1.0, 0.35, f)
		var off := Vector3(randf_range(-1.0, 1.0), randf_range(-0.2, 0.2), randf_range(-1.0, 1.0))
		if off.length_squared() > 0.001:
			off = off.normalized() * randf_range(0.2, 1.0) * spread * env
		pts[i] = base_p + off

	for i in range(count):
		var a := pts[i]
		var b := pts[i + 1]
		var d := b - a
		var seg_len := d.length()
		var mi := segs[i]
		if seg_len < 0.002:
			mi.visible = false
			continue
		mi.visible = true
		var y_ax := d / seg_len
		var ref := Vector3.FORWARD if absf(y_ax.dot(Vector3.UP)) > 0.95 else Vector3.UP
		var x_ax := ref.cross(y_ax).normalized()
		var z_ax := x_ax.cross(y_ax).normalized()
		mi.transform = Transform3D(Basis(x_ax * radius, y_ax * seg_len, z_ax * radius), a.lerp(b, 0.5))

func _trigger_lightning_strike() -> void:
	_struck = true
	if telegraph_holder != null:
		telegraph_holder.visible = false

	if ground_decal != null:
		ground_decal.visible = true
		ground_decal.modulate = Color(0.20, 0.48, 0.78, 0.85)

	if bolt_particles != null:
		bolt_particles.restart()
		bolt_particles.emitting = true
	if sparks_particles != null:
		sparks_particles.restart()
		sparks_particles.emitting = true
	if trails_particles != null:
		trails_particles.restart()
		trails_particles.emitting = true

	if strike_light != null:
		strike_light.position = Vector3(0.0, 1.5, 0.0)
		strike_light.light_energy = 3.4

	if strike_damage_callback.is_valid():
		strike_damage_callback.call(global_position, strike_radius, _hit_players)
