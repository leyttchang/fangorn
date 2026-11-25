extends Node3D

const MIRROR_COUNT: int = 6

static var _mirror_frame_mesh: CylinderMesh = null
static var _mirror_core_mesh: PrismMesh = null
static var _ring_mesh: CylinderMesh = null
static var _shard_mesh: PrismMesh = null
static var _mirror_mat: StandardMaterial3D = null
static var _core_mat: StandardMaterial3D = null
static var _ring_mat: StandardMaterial3D = null
static var _shard_mat: StandardMaterial3D = null
static var _shatter_proc: ParticleProcessMaterial = null
static var _sphere_cache: Dictionary = {}

@export var aegis_duration: float = 6.5
@export var shield_max_hp_ratio: float = 0.42
@export var knockback_res_bonus: float = 50.0

@onready var attack_component: AttackComponent = $AttackComponent
@onready var scaling_component: SpellScalingComponent = $SpellScalingComponent

var _caster: Node3D = null
var _health_comp: HealthComponent = null
var _stats_comp: StatsComponent = null
var _orbit_pivot: Node3D = null
var _mirror_nodes: Array[Node3D] = []

var _is_auth: bool = true
var _active: bool = false
var _detonated: bool = false
var _cleaned_up: bool = false
var _elapsed: float = 0.0
var _post_detonation_timer: float = 0.0
var _granted_shield: float = 0.0
var _remaining_granted: float = 0.0
var _final_radius: float = 6.0


static func _ensure_shared_visuals() -> void:
	if _mirror_frame_mesh == null:
		_mirror_frame_mesh = CylinderMesh.new()
		_mirror_frame_mesh.top_radius = 0.34
		_mirror_frame_mesh.bottom_radius = 0.34
		_mirror_frame_mesh.height = 0.06
		_mirror_frame_mesh.radial_segments = 6
		_mirror_frame_mesh.rings = 0

	if _mirror_core_mesh == null:
		_mirror_core_mesh = PrismMesh.new()
		_mirror_core_mesh.size = Vector3(0.24, 0.42, 0.09)

	if _ring_mesh == null:
		_ring_mesh = CylinderMesh.new()
		_ring_mesh.top_radius = 1.0
		_ring_mesh.bottom_radius = 0.92
		_ring_mesh.height = 0.14
		_ring_mesh.radial_segments = 24
		_ring_mesh.rings = 0
		_ring_mesh.cap_top = false
		_ring_mesh.cap_bottom = false

	if _shard_mesh == null:
		_shard_mesh = PrismMesh.new()
		_shard_mesh.size = Vector3(0.18, 0.34, 0.08)

	if _mirror_mat == null:
		_mirror_mat = StandardMaterial3D.new()
		_mirror_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mirror_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mirror_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mirror_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mirror_mat.albedo_color = Color(0.52, 1.55, 2.55, 0.56)

	if _core_mat == null:
		_core_mat = StandardMaterial3D.new()
		_core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_core_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_core_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_core_mat.albedo_color = Color(0.95, 2.25, 3.4, 0.78)

	if _ring_mat == null:
		_ring_mat = StandardMaterial3D.new()
		_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ring_mat.albedo_color = Color(0.75, 2.1, 3.3, 0.88)

	if _shard_mat == null:
		_shard_mat = StandardMaterial3D.new()
		_shard_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shard_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_shard_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shard_mat.vertex_color_use_as_albedo = true
		_shard_mat.albedo_color = Color(0.85, 2.15, 3.3, 0.95)

	if _shatter_proc == null:
		var sp: ParticleProcessMaterial = ParticleProcessMaterial.new()
		sp.particle_flag_align_y = true
		sp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		sp.emission_ring_axis = Vector3(0.0, 1.0, 0.0)
		sp.emission_ring_height = 0.4
		sp.emission_ring_radius = 0.85
		sp.emission_ring_inner_radius = 0.55
		sp.direction = Vector3(0.0, 0.25, 0.0)
		sp.spread = 180.0
		sp.flatness = 0.78
		sp.initial_velocity_min = 10.0
		sp.initial_velocity_max = 17.5
		sp.damping_min = 12.0
		sp.damping_max = 20.0
		sp.gravity = Vector3(0.0, -4.0, 0.0)
		sp.scale_min = 0.75
		sp.scale_max = 1.45
		sp.color = Color(0.82, 2.05, 3.2, 0.95)
		_shatter_proc = sp


static func _get_cached_sphere(rad: float) -> SphereShape3D:
	var key: int = maxi(10, int(roundf(rad * 10.0)))
	if _sphere_cache.has(key):
		return _sphere_cache[key] as SphereShape3D
	var sph: SphereShape3D = SphereShape3D.new()
	sph.radius = float(key) / 10.0
	_sphere_cache[key] = sph
	return sph


func _ready() -> void:
	_ensure_shared_visuals()
	if attack_component != null:
		attack_component.monitoring = false
		attack_component.monitorable = false
		attack_component.is_active_for_network = false

	_orbit_pivot = Node3D.new()
	_orbit_pivot.name = "FrostMirrors"
	add_child(_orbit_pivot)

	for i: int in range(MIRROR_COUNT):
		var angle: float = float(i) * (TAU / float(MIRROR_COUNT))
		var holder: Node3D = Node3D.new()
		holder.position = Vector3(cos(angle) * 0.86, 0.62, sin(angle) * 0.86)
		holder.rotation = Vector3(0.0, -angle + PI * 0.5, 0.0)
		_orbit_pivot.add_child(holder)
		_mirror_nodes.append(holder)

		var glass: MeshInstance3D = MeshInstance3D.new()
		glass.mesh = _mirror_frame_mesh
		glass.material_override = _mirror_mat
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glass.rotation = Vector3(PI * 0.5 - 0.16, 0.0, 0.0)
		holder.add_child(glass)

		var facet: MeshInstance3D = MeshInstance3D.new()
		facet.mesh = _mirror_core_mesh
		facet.material_override = _core_mat
		facet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		facet.position = Vector3(0.0, 0.0, 0.02)
		facet.rotation = Vector3(-0.16, 0.0, 0.0)
		holder.add_child(facet)


func execute(caster: Node3D, target_data: Dictionary) -> void:
	_caster = caster
	if _caster == null or not is_instance_valid(_caster):
		queue_free()
		return

	_is_auth = (not multiplayer.has_multiplayer_peer() or _caster.is_multiplayer_authority())
	global_position = _caster.global_position

	# Lower mirrors slightly in local first-person view so vision stays completely clear
	if _caster.is_in_group("Player") and _caster.is_multiplayer_authority() and _orbit_pivot != null:
		_orbit_pivot.position.y = -0.35

	if attack_component != null:
		attack_component.on_execute(_caster, target_data)
		attack_component.is_active_for_network = false
	if scaling_component != null:
		scaling_component.on_execute(_caster, target_data)
		_final_radius = scaling_component.final_impact_radius

	var ab_data: AbilityData = target_data.get("ability_data") as AbilityData
	var lvl_mult: float = SpellScalingComponent.resolve_level_power_multiplier(_caster, ab_data, target_data)

	_health_comp = _caster.get_node_or_null("HealthComponent") as HealthComponent
	_stats_comp = _caster.find_child("StatsComponent", true, false) as StatsComponent

	if _is_auth and _stats_comp != null:
		_stats_comp.set_or_update_modifier("knockback_resistance", StatModifier.Type.FLAT, knockback_res_bonus, "frostmirror_aegis")

	if _health_comp != null:
		if not _health_comp.shield_changed.is_connected(_on_shield_changed):
			_health_comp.shield_changed.connect(_on_shield_changed)
		if not _health_comp.shield_damaged.is_connected(_on_shield_damaged):
			_health_comp.shield_damaged.connect(_on_shield_damaged)

		if _is_auth:
			var max_hp: float = _health_comp.get_max_health()
			_granted_shield = maxf(15.0, max_hp * shield_max_hp_ratio * lvl_mult)
			_remaining_granted = _granted_shield
			_health_comp.set_shield(_granted_shield)

	_active = true
	SpellAudioManager.play_ice_cast(self, global_position, 0.88, -1.2)


func _process(delta: float) -> void:
	if _detonated:
		_post_detonation_timer -= delta
		if _post_detonation_timer <= 0.0:
			queue_free()
		return

	if not _active or _caster == null or not is_instance_valid(_caster):
		_cleanup_effects(false)
		queue_free()
		return

	if _caster.get("is_dead") == true:
		_cleanup_effects(false)
		queue_free()
		return

	_elapsed += delta
	global_position = _caster.global_position

	if _orbit_pivot != null:
		_orbit_pivot.rotate_y(delta * 2.1)
		for i: int in range(_mirror_nodes.size()):
			var holder: Node3D = _mirror_nodes[i]
			if holder != null:
				holder.position.y = 0.62 + sin(_elapsed * 3.4 + float(i) * 1.0472) * 0.07

	if _health_comp != null and _elapsed > 0.08 and _health_comp.current_shield <= 0.001:
		_trigger_detonation(true)
		return

	if _elapsed >= aegis_duration:
		_trigger_detonation(false)


func _on_shield_damaged(absorbed: float) -> void:
	_remaining_granted = maxf(0.0, _remaining_granted - absorbed)
	if _caster != null and is_instance_valid(_caster) and _active and not _detonated:
		SpellAudioManager.play_ice_windup(self, _caster.global_position, 1.32, -4.0)


func _on_shield_changed(current_sh: float, _max_hp: float) -> void:
	if _active and not _detonated and _elapsed > 0.05 and current_sh <= 0.001:
		_trigger_detonation(true)


func _trigger_detonation(shattered_by_damage: bool) -> void:
	if _detonated:
		return
	_detonated = true
	_active = false

	_cleanup_effects(not shattered_by_damage)

	if _orbit_pivot != null:
		_orbit_pivot.visible = false

	if _caster == null or not is_instance_valid(_caster):
		queue_free()
		return

	var center: Vector3 = _caster.global_position
	global_position = center

	SpellAudioManager.play_ice_cast(self, center, 0.90, 1.2)
	_spawn_freezing_nova_vfx()

	if _is_auth and attack_component != null:
		_apply_freezing_explosion(center, _final_radius)

	_post_detonation_timer = 0.48


func _spawn_freezing_nova_vfx() -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.mesh = _ring_mesh
	ring.material_override = _ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(0.0, -0.55, 0.0)
	ring.scale = Vector3(0.4, 1.0, 0.4)
	add_child(ring)

	var tw: Tween = create_tween()
	tw.tween_property(ring, "scale", Vector3(_final_radius, 0.35, _final_radius), 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if is_instance_valid(ring):
			ring.visible = false
	)

	var shards: GPUParticles3D = GPUParticles3D.new()
	shards.material_override = _shard_mat
	shards.process_material = _shatter_proc
	shards.draw_pass_1 = _shard_mesh
	shards.amount = 32
	shards.lifetime = 0.40
	shards.one_shot = true
	shards.explosiveness = 0.96
	shards.fixed_fps = 30
	shards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shards.position = Vector3(0.0, 0.15, 0.0)
	var radial_mult: float = clampf(_final_radius / 6.0, 0.7, 2.2)
	shards.scale = Vector3.ONE * radial_mult
	add_child(shards)
	shards.emitting = true


func _apply_freezing_explosion(center: Vector3, radius: float) -> void:
	attack_component.global_position = center
	var seen: Dictionary = {}

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state != null:
		var params: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		params.shape = _get_cached_sphere(radius)
		params.transform = Transform3D(Basis.IDENTITY, center + Vector3(0.0, 0.5, 0.0))
		params.collision_mask = 8
		params.collide_with_areas = true
		params.collide_with_bodies = false

		var hits: Array[Dictionary] = space_state.intersect_shape(params, 32)
		for entry: Dictionary in hits:
			var hb: HitboxComponent = entry.get("collider") as HitboxComponent
			if hb == null:
				continue
			var entity: Node = hb.owner if hb.owner != null else hb.get_parent()
			if entity == null or entity == _caster or entity.is_in_group("Player"):
				continue
			var eid: int = entity.get_instance_id()
			if seen.has(eid):
				continue
			seen[eid] = true
			hb.receive_hit(attack_component)

	if get_tree() != null:
		var max_r: float = radius + 0.45
		var max_r_sq: float = max_r * max_r
		for node: Node in get_tree().get_nodes_in_group("Enemie"):
			var mob: Node3D = node as Node3D
			if mob == null or not is_instance_valid(mob) or mob == _caster:
				continue
			var eid_m: int = mob.get_instance_id()
			if seen.has(eid_m):
				continue
			var diff: Vector3 = mob.global_position - center
			if absf(diff.y) > 3.2:
				continue
			if (diff.x * diff.x + diff.z * diff.z) > max_r_sq:
				continue
			var mob_hb: HitboxComponent = _find_mob_hitbox(mob)
			if mob_hb != null:
				seen[eid_m] = true
				mob_hb.receive_hit(attack_component)


func _find_mob_hitbox(mob: Node3D) -> HitboxComponent:
	var hb: HitboxComponent = mob.get_node_or_null("HitboxComponent") as HitboxComponent
	if hb == null:
		for cand: Node in mob.find_children("*", "Area3D", true, false):
			var cand_hb: HitboxComponent = cand as HitboxComponent
			if cand_hb != null:
				hb = cand_hb
				if cand_hb.body_part_multiplier <= 1.05:
					break
	return hb


func _cleanup_effects(remove_leftover_shield: bool) -> void:
	if _cleaned_up:
		return
	_cleaned_up = true

	if _health_comp != null and is_instance_valid(_health_comp):
		if _health_comp.shield_changed.is_connected(_on_shield_changed):
			_health_comp.shield_changed.disconnect(_on_shield_changed)
		if _health_comp.shield_damaged.is_connected(_on_shield_damaged):
			_health_comp.shield_damaged.disconnect(_on_shield_damaged)
		if _is_auth and remove_leftover_shield and _remaining_granted > 0.0 and _health_comp.current_shield > 0.0:
			_health_comp.set_shield(maxf(0.0, _health_comp.current_shield - _remaining_granted))
		_remaining_granted = 0.0

	if _is_auth and _stats_comp != null and is_instance_valid(_stats_comp):
		_stats_comp.remove_modifier_by_source("frostmirror_aegis")


func _exit_tree() -> void:
	_cleanup_effects(true)
