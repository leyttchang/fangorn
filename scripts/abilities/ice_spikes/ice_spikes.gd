extends Node3D

const ICE_CRASH_SCENE_PATH: String = "res://scripts/abilities/Ice Crash/ice_crash.tscn"

static var _ice_crash_packed: PackedScene = null
static var _sphere_cache: Dictionary = {}

@export var spikes_linger_duration: float = 3.0
@export var retract_duration: float = 0.55

@onready var attack_component: AttackComponent = $AttackComponent
@onready var scaling_component: SpellScalingComponent = $SpellScalingComponent

var _caster: Node3D = null
var _vfx_root: Node3D = null
var _instance_shader_mat: ShaderMaterial = null
var _decal_node: Decal = null
var _smoke_particles: GPUParticles3D = null
var _is_auth: bool = true
var _scale_factor: float = 0.7


static func _get_ice_crash_scene() -> PackedScene:
	if _ice_crash_packed == null and ResourceLoader.exists(ICE_CRASH_SCENE_PATH):
		_ice_crash_packed = load(ICE_CRASH_SCENE_PATH) as PackedScene
	return _ice_crash_packed


static func _get_cached_sphere(rad: float) -> SphereShape3D:
	var key: int = maxi(10, int(roundf(rad * 10.0)))
	if _sphere_cache.has(key):
		return _sphere_cache[key] as SphereShape3D
	var sph: SphereShape3D = SphereShape3D.new()
	sph.radius = float(key) / 10.0
	_sphere_cache[key] = sph
	return sph


func _ready() -> void:
	if attack_component != null:
		attack_component.monitoring = false
		attack_component.monitorable = false
		attack_component.is_active_for_network = false


func execute(caster: Node3D, target_data: Dictionary) -> void:
	_caster = caster
	if target_data.has("impact_point"):
		global_position = target_data["impact_point"] as Vector3

	_is_auth = (not multiplayer.has_multiplayer_peer() or (_caster != null and is_instance_valid(_caster) and _caster.is_multiplayer_authority()))

	if attack_component != null and _caster != null:
		attack_component.on_execute(_caster, target_data)
		attack_component.is_active_for_network = false

	var final_radius: float = 4.2
	if scaling_component != null:
		scaling_component.on_execute(_caster, target_data)
		final_radius = scaling_component.final_impact_radius

	_scale_factor = maxf(0.25, final_radius / 6.0)
	_spawn_ice_crash_vfx(_scale_factor)

	SpellAudioManager.play_ice_cast(self, global_position, 0.96, 0.8)

	if _is_auth and attack_component != null:
		_impale_enemies_in_zone(global_position, final_radius)

	get_tree().create_timer(spikes_linger_duration).timeout.connect(_retract_and_free)


func _spawn_ice_crash_vfx(scale_factor: float) -> void:
	var packed: PackedScene = _get_ice_crash_scene()
	if packed == null:
		return

	var temp_wrapper: Node = packed.instantiate()
	if temp_wrapper == null:
		return

	var extracted_vfx: Node3D = temp_wrapper.get_node_or_null("Ice_crash_effect") as Node3D
	if extracted_vfx != null:
		temp_wrapper.remove_child(extracted_vfx)
	temp_wrapper.queue_free()

	if extracted_vfx == null:
		return

	extracted_vfx.owner = null
	for desc: Node in extracted_vfx.find_children("*", "", true, false):
		desc.owner = null

	_vfx_root = extracted_vfx
	_vfx_root.position = Vector3(0.0, -0.7 * scale_factor, 0.0)
	_vfx_root.rotation = Vector3(0.0, randf_range(0.0, TAU), 0.0)
	_vfx_root.scale = Vector3.ONE * scale_factor
	add_child(_vfx_root)

	var inner_anim: AnimationPlayer = _vfx_root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if inner_anim != null and inner_anim.has_animation("cast"):
		inner_anim.play("cast")

	var erupt_tween: Tween = create_tween()
	erupt_tween.set_parallel(true)

	for child: Node in _vfx_root.get_children():
		var mi: MeshInstance3D = child as MeshInstance3D
		if mi != null:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var surf_mat: ShaderMaterial = mi.get_surface_override_material(0) as ShaderMaterial
			if surf_mat != null:
				if _instance_shader_mat == null:
					_instance_shader_mat = surf_mat.duplicate() as ShaderMaterial
					if _instance_shader_mat != null:
						_instance_shader_mat.set_shader_parameter("stepp", 0.651)
				if _instance_shader_mat != null:
					mi.set_surface_override_material(0, _instance_shader_mat)

			var rest_pos: Vector3 = mi.position
			var radial_dist: float = Vector2(rest_pos.x, rest_pos.z).length()
			var delay: float = clampf((radial_dist / 5.2) * 0.08, 0.0, 0.08)
			mi.position = Vector3(rest_pos.x, rest_pos.y - 3.4, rest_pos.z)
			erupt_tween.tween_property(mi, "position", rest_pos, 0.19).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			continue

		var gp: GPUParticles3D = child as GPUParticles3D
		if gp != null:
			gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if gp.name == "sparks":
				gp.emitting = true
			elif gp.name == "smoke":
				_smoke_particles = gp
				gp.amount_ratio = 1.0
				gp.emitting = true
			continue

		var dec: Decal = child as Decal
		if dec != null:
			_decal_node = dec


func _impale_enemies_in_zone(center: Vector3, radius: float) -> void:
	attack_component.global_position = center
	var seen: Dictionary = {}

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state != null:
		var params: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		params.shape = _get_cached_sphere(radius)
		params.transform = Transform3D(Basis.IDENTITY, center + Vector3(0.0, 0.65, 0.0))
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
		var max_r: float = radius + 0.40
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


func _retract_and_free() -> void:
	if not is_instance_valid(self):
		return

	if _smoke_particles != null and is_instance_valid(_smoke_particles):
		_smoke_particles.emitting = false

	if _vfx_root == null or not is_instance_valid(_vfx_root):
		queue_free()
		return

	var sink_tween: Tween = create_tween()
	sink_tween.set_parallel(true)

	var target_y: float = _vfx_root.position.y - 3.6 * _scale_factor
	sink_tween.tween_property(_vfx_root, "position:y", target_y, retract_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if _instance_shader_mat != null:
		sink_tween.tween_method(_set_shader_stepp, 0.651, 0.0, retract_duration)

	if _decal_node != null and is_instance_valid(_decal_node):
		var target_mod: Color = _decal_node.modulate
		target_mod.a = 0.0
		sink_tween.tween_property(_decal_node, "modulate", target_mod, retract_duration)

	sink_tween.chain().tween_callback(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)


func _set_shader_stepp(val: float) -> void:
	if _instance_shader_mat != null:
		_instance_shader_mat.set_shader_parameter("stepp", val)
