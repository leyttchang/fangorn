extends Node3D

enum OrbPhase {
	INACTIVE,
	TRAVELLING,
	COLLAPSING,
	EXPLODING
}

static var _core_sphere_mesh: SphereMesh = null
static var _halo_sphere_mesh: SphereMesh = null
static var _shockwave_sphere_mesh: SphereMesh = null
static var _ring_inner_mesh: TorusMesh = null
static var _ring_outer_mesh: TorusMesh = null
static var _particle_quad_mesh: QuadMesh = null

static var _core_black_mat: StandardMaterial3D = null
static var _halo_add_mat: StandardMaterial3D = null
static var _ring_add_mat: StandardMaterial3D = null
static var _shockwave_mat: StandardMaterial3D = null
static var _inward_particle_mat: StandardMaterial3D = null
static var _inward_proc_mat: ParticleProcessMaterial = null
static var _query_sphere_cache: Dictionary = {}

@export var speed: float = 5.8
@export var travel_duration: float = 2.4
@export var collapse_duration: float = 0.12
@export var shockwave_duration: float = 0.28
@export var pull_speed: float = 3.4
@export var tick_interval: float = 0.45
@export var tick_damage_ratio: float = 0.15

@onready var attack_component: AttackComponent = $AttackComponent
@onready var scaling_component: SpellScalingComponent = $SpellScalingComponent

var _phase: OrbPhase = OrbPhase.INACTIVE
var _caster: Node3D = null
var _is_auth: bool = true
var _direction: Vector3 = Vector3.FORWARD
var _stopped_on_surface: bool = false

var _elapsed: float = 0.0
var _tick_accum: float = 0.0
var _impact_radius: float = 5.6
var _aoe_mult: float = 1.0

var _full_dmg_phys: float = 0.0
var _full_dmg_magic: float = 46.0
var _full_dmg_fire: float = 0.0
var _full_dmg_ice: float = 0.0
var _full_dmg_lightning: float = 0.0
var _saved_status_effects: Array[StatusEffectApplication] = []
var _exclude_rids: Array[RID] = []

var _orb_visual_root: Node3D = null
var _core_mi: MeshInstance3D = null
var _halo_mi: MeshInstance3D = null
var _ring_a_mi: MeshInstance3D = null
var _ring_b_mi: MeshInstance3D = null
var _inward_particles: GPUParticles3D = null
var _shock_sphere_mi: MeshInstance3D = null
var _shock_ring_mi: MeshInstance3D = null


static func _ensure_shared_visuals() -> void:
	if _core_sphere_mesh == null:
		_core_sphere_mesh = SphereMesh.new()
		_core_sphere_mesh.radius = 0.42
		_core_sphere_mesh.height = 0.84
		_core_sphere_mesh.radial_segments = 16
		_core_sphere_mesh.rings = 8

	if _halo_sphere_mesh == null:
		_halo_sphere_mesh = SphereMesh.new()
		_halo_sphere_mesh.radius = 0.68
		_halo_sphere_mesh.height = 1.36
		_halo_sphere_mesh.radial_segments = 16
		_halo_sphere_mesh.rings = 8

	if _shockwave_sphere_mesh == null:
		_shockwave_sphere_mesh = SphereMesh.new()
		_shockwave_sphere_mesh.radius = 1.0
		_shockwave_sphere_mesh.height = 2.0
		_shockwave_sphere_mesh.radial_segments = 18
		_shockwave_sphere_mesh.rings = 10

	if _ring_inner_mesh == null:
		_ring_inner_mesh = TorusMesh.new()
		_ring_inner_mesh.inner_radius = 0.66
		_ring_inner_mesh.outer_radius = 0.84
		_ring_inner_mesh.rings = 20
		_ring_inner_mesh.ring_segments = 6

	if _ring_outer_mesh == null:
		_ring_outer_mesh = TorusMesh.new()
		_ring_outer_mesh.inner_radius = 0.88
		_ring_outer_mesh.outer_radius = 1.04
		_ring_outer_mesh.rings = 22
		_ring_outer_mesh.ring_segments = 6

	if _particle_quad_mesh == null:
		_particle_quad_mesh = QuadMesh.new()
		_particle_quad_mesh.size = Vector2(0.18, 0.18)

	if _core_black_mat == null:
		_core_black_mat = StandardMaterial3D.new()
		_core_black_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_core_black_mat.albedo_color = Color(0.015, 0.005, 0.03, 1.0)

	if _halo_add_mat == null:
		_halo_add_mat = StandardMaterial3D.new()
		_halo_add_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_halo_add_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_halo_add_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_halo_add_mat.albedo_color = Color(1.65, 0.38, 2.85, 0.42)

	if _ring_add_mat == null:
		_ring_add_mat = StandardMaterial3D.new()
		_ring_add_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_add_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_ring_add_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_add_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ring_add_mat.albedo_color = Color(2.25, 0.58, 3.45, 0.82)

	if _shockwave_mat == null:
		_shockwave_mat = StandardMaterial3D.new()
		_shockwave_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shockwave_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_shockwave_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shockwave_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_shockwave_mat.albedo_color = Color(2.1, 0.55, 3.35, 0.55)

	if _inward_particle_mat == null:
		_inward_particle_mat = StandardMaterial3D.new()
		_inward_particle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_inward_particle_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_inward_particle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_inward_particle_mat.vertex_color_use_as_albedo = true
		_inward_particle_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_inward_particle_mat.billboard_keep_scale = true

	if _inward_proc_mat == null:
		var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_radius = 2.55
		pm.emission_ring_inner_radius = 1.75
		pm.emission_ring_height = 1.65
		pm.gravity = Vector3.ZERO
		pm.initial_velocity_min = 0.05
		pm.initial_velocity_max = 0.35
		pm.radial_accel_min = -12.0
		pm.radial_accel_max = -15.5
		pm.tangential_accel_min = 3.2
		pm.tangential_accel_max = 5.4
		pm.scale_min = 0.45
		pm.scale_max = 1.05

		var grad: Gradient = Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		grad.colors = PackedColorArray([
			Color(1.4, 0.35, 2.4, 0.0),
			Color(2.2, 0.62, 3.4, 0.92),
			Color(2.8, 1.15, 3.9, 0.15)
		])
		var ramp: GradientTexture1D = GradientTexture1D.new()
		ramp.gradient = grad
		pm.color_ramp = ramp
		_inward_proc_mat = pm


static func _get_query_sphere(rad: float) -> SphereShape3D:
	var key: int = maxi(8, int(roundf(rad * 20.0)))
	if _query_sphere_cache.has(key):
		return _query_sphere_cache[key] as SphereShape3D
	var sph: SphereShape3D = SphereShape3D.new()
	sph.radius = float(key) / 20.0
	_query_sphere_cache[key] = sph
	return sph


static func _find_mob_hitbox(mob: Node3D) -> HitboxComponent:
	if mob == null:
		return null
	var hb: HitboxComponent = mob.get_node_or_null("HitboxComponent") as HitboxComponent
	if hb == null:
		for cand: Node in mob.find_children("*", "Area3D", true, false):
			var cand_hb: HitboxComponent = cand as HitboxComponent
			if cand_hb != null:
				hb = cand_hb
				if cand_hb.body_part_multiplier <= 1.05:
					break
	return hb


func _ready() -> void:
	_ensure_shared_visuals()
	if attack_component != null:
		attack_component.monitoring = false
		attack_component.monitorable = false
		attack_component.is_active_for_network = false

	_orb_visual_root = Node3D.new()
	_orb_visual_root.name = "OrbVisualRoot"
	add_child(_orb_visual_root)

	_core_mi = MeshInstance3D.new()
	_core_mi.mesh = _core_sphere_mesh
	_core_mi.material_override = _core_black_mat
	_core_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_orb_visual_root.add_child(_core_mi)

	_halo_mi = MeshInstance3D.new()
	_halo_mi.mesh = _halo_sphere_mesh
	_halo_mi.material_override = _halo_add_mat
	_halo_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_orb_visual_root.add_child(_halo_mi)

	_ring_a_mi = MeshInstance3D.new()
	_ring_a_mi.mesh = _ring_inner_mesh
	_ring_a_mi.material_override = _ring_add_mat
	_ring_a_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring_a_mi.rotation = Vector3(0.66, 0.0, 0.42)
	_orb_visual_root.add_child(_ring_a_mi)

	_ring_b_mi = MeshInstance3D.new()
	_ring_b_mi.mesh = _ring_outer_mesh
	_ring_b_mi.material_override = _ring_add_mat
	_ring_b_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring_b_mi.rotation = Vector3(-0.88, 0.35, -0.52)
	_orb_visual_root.add_child(_ring_b_mi)

	_inward_particles = GPUParticles3D.new()
	_inward_particles.material_override = _inward_particle_mat
	_inward_particles.process_material = _inward_proc_mat
	_inward_particles.draw_pass_1 = _particle_quad_mesh
	_inward_particles.amount = 28
	_inward_particles.lifetime = 0.62
	_inward_particles.fixed_fps = 30
	_inward_particles.local_coords = true
	_inward_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_orb_visual_root.add_child(_inward_particles)

	_shock_sphere_mi = MeshInstance3D.new()
	_shock_sphere_mi.mesh = _shockwave_sphere_mesh
	_shock_sphere_mi.material_override = _shockwave_mat
	_shock_sphere_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shock_sphere_mi.visible = false
	add_child(_shock_sphere_mi)

	_shock_ring_mi = MeshInstance3D.new()
	_shock_ring_mi.mesh = _ring_outer_mesh
	_shock_ring_mi.material_override = _ring_add_mat
	_shock_ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shock_ring_mi.visible = false
	add_child(_shock_ring_mi)


func execute(caster: Node3D, target_data: Dictionary) -> void:
	if caster == null or not is_instance_valid(caster):
		queue_free()
		return

	_caster = caster
	var is_remote: bool = bool(target_data.get("is_remote_visual", false))
	_is_auth = (not is_remote) and (not multiplayer.has_multiplayer_peer() or caster.is_multiplayer_authority())

	_exclude_rids.clear()
	var root_co: CollisionObject3D = caster as CollisionObject3D
	if root_co != null:
		_exclude_rids.append(root_co.get_rid())
	for child_co: Node in caster.find_children("*", "CollisionObject3D", true, false):
		var co: CollisionObject3D = child_co as CollisionObject3D
		if co != null:
			_exclude_rids.append(co.get_rid())

	var cam: Camera3D = caster.get_node_or_null("Camera3D") as Camera3D
	var cast_pt: Node3D = caster.find_child("CastPoint", true, false) as Node3D
	var cam_fwd: Vector3 = -cam.global_transform.basis.z.normalized() if cam != null else -caster.global_transform.basis.z.normalized()

	if cast_pt != null:
		global_position = cast_pt.global_position
	else:
		global_position = caster.global_position + Vector3(0.0, 1.45, 0.0) + cam_fwd * 0.7

	_direction = cam_fwd
	if target_data.has("impact_point"):
		var imp: Vector3 = target_data["impact_point"] as Vector3
		var to_imp: Vector3 = imp - global_position
		if to_imp.length() > 1.5 and to_imp.normalized().dot(cam_fwd) > 0.70:
			_direction = to_imp.normalized()

	# Assure une hauteur minimale au-dessus du sol dès le spawn si le joueur regarde vers ses pieds
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state != null:
		var q_floor: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			global_position + Vector3(0.0, 1.5, 0.0),
			global_position - Vector3(0.0, 2.0, 0.0),
			1,
			_exclude_rids
		)
		var res_floor: Dictionary = space_state.intersect_ray(q_floor)
		if not res_floor.is_empty():
			var fn: Vector3 = res_floor.get("normal", Vector3.UP) as Vector3
			if fn.y > 0.52:
				var fp: Vector3 = res_floor.get("position", global_position) as Vector3
				if global_position.y < fp.y + 1.15:
					global_position.y = fp.y + 1.15

	if attack_component != null:
		attack_component.on_execute(caster, target_data)
		attack_component.is_active_for_network = false
	if scaling_component != null:
		scaling_component.on_execute(caster, target_data)
		_impact_radius = scaling_component.final_impact_radius
		_aoe_mult = scaling_component.final_aoe_multiplier

	if attack_component != null:
		_full_dmg_phys = attack_component.damage_physical
		_full_dmg_magic = attack_component.damage_magic
		_full_dmg_fire = attack_component.damage_fire
		_full_dmg_ice = attack_component.damage_ice
		_full_dmg_lightning = attack_component.damage_lightning
		_saved_status_effects = attack_component.status_effects_to_apply.duplicate()

	if _orb_visual_root != null:
		_orb_visual_root.scale = Vector3.ONE * _aoe_mult

	_elapsed = 0.0
	_tick_accum = 0.0
	_stopped_on_surface = false
	_phase = OrbPhase.TRAVELLING

	SpellAudioManager.play_ice_cast(self, global_position, 0.74, -1.5)


func _process(delta: float) -> void:
	if _phase == OrbPhase.INACTIVE:
		return

	if _phase == OrbPhase.TRAVELLING or _phase == OrbPhase.COLLAPSING:
		var spin_boost: float = 2.4 if _phase == OrbPhase.COLLAPSING else 1.0
		if _ring_a_mi != null:
			_ring_a_mi.rotate_object_local(Vector3.UP, delta * 5.8 * spin_boost)
			_ring_a_mi.rotate_object_local(Vector3.RIGHT, delta * 1.9 * spin_boost)
		if _ring_b_mi != null:
			_ring_b_mi.rotate_object_local(Vector3.UP, -delta * 4.6 * spin_boost)
			_ring_b_mi.rotate_object_local(Vector3.FORWARD, delta * 2.2 * spin_boost)
		if _halo_mi != null and _phase == OrbPhase.TRAVELLING:
			var pulse: float = 1.0 + 0.09 * sin(_elapsed * 11.0)
			_halo_mi.scale = Vector3.ONE * pulse


func _physics_process(delta: float) -> void:
	if _phase == OrbPhase.INACTIVE:
		return

	_elapsed += delta

	match _phase:
		OrbPhase.TRAVELLING:
			_step_travel(delta)
			if _is_auth:
				_pull_nearby_enemies(delta, pull_speed)
				_tick_accum += delta
				if _tick_accum >= tick_interval:
					_tick_accum -= tick_interval
					_deal_aoe_damage(_impact_radius, tick_damage_ratio, false)
					SpellAudioManager.play_ice_windup(self, global_position, 0.85, -6.0)
			if _elapsed >= travel_duration:
				_begin_collapse()

		OrbPhase.COLLAPSING:
			var c_time: float = _elapsed - travel_duration
			var u_col: float = clampf(c_time / maxf(0.03, collapse_duration), 0.0, 1.0)
			if _orb_visual_root != null:
				var shrink_s: float = lerpf(1.0, 0.16, u_col * u_col) * _aoe_mult
				_orb_visual_root.scale = Vector3.ONE * shrink_s
			if _is_auth:
				_pull_nearby_enemies(delta, pull_speed * 1.45)
			if u_col >= 1.0:
				_trigger_implosion()

		OrbPhase.EXPLODING:
			var e_time: float = _elapsed - (travel_duration + collapse_duration)
			var u_exp: float = clampf(e_time / maxf(0.05, shockwave_duration), 0.0, 1.0)
			var eased_exp: float = 1.0 - pow(1.0 - u_exp, 2.5)
			var cur_r: float = lerpf(0.35, _impact_radius, eased_exp)
			if _shock_sphere_mi != null:
				_shock_sphere_mi.scale = Vector3.ONE * cur_r
			if _shock_ring_mi != null:
				var ring_y: float = maxf(0.05, 1.0 - u_exp)
				_shock_ring_mi.scale = Vector3(cur_r, ring_y, cur_r)
			if u_exp >= 1.0:
				_phase = OrbPhase.INACTIVE
				queue_free()


func _step_travel(delta: float) -> void:
	if _stopped_on_surface:
		return

	var step_dist: float = speed * delta
	var cur_pos: Vector3 = global_position
	var probe_end: Vector3 = cur_pos + _direction * (step_dist + 0.9)
	var min_hover_y: float = -99999.0

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state != null:
		var local_exclude: Array[RID] = _exclude_rids.duplicate()
		for _attempt: int in range(4):
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
				cur_pos,
				probe_end,
				129,
				local_exclude
			)
			var hit: Dictionary = space_state.intersect_ray(q)
			if hit.is_empty():
				break

			var col_obj: Object = hit.get("collider") as Object
			var col_node: Node = col_obj as Node
			if col_node != null and (col_node.is_in_group("Enemie") or col_node.is_in_group("Player") or col_node is CharacterBody3D):
				var co_skip: CollisionObject3D = col_obj as CollisionObject3D
				if co_skip != null:
					local_exclude.append(co_skip.get_rid())
					continue

			var hit_pos: Vector3 = hit.get("position", probe_end) as Vector3
			var hit_normal: Vector3 = hit.get("normal", -_direction) as Vector3
			if hit_normal.length_squared() < 0.01:
				hit_normal = -_direction
			else:
				hit_normal = hit_normal.normalized()

			# Sol ou colline en pente (hit_normal.y > 0.52) : l'orbe survole sans jamais se bloquer !
			if hit_normal.y > 0.52:
				min_hover_y = maxf(min_hover_y, hit_pos.y + 1.15)
				var into_ground: float = _direction.dot(hit_normal)
				if into_ground < 0.0:
					var slide_dir: Vector3 = _direction - hit_normal * into_ground
					if slide_dir.length_squared() > 0.001:
						_direction = slide_dir.normalized()
					else:
						var flat_fallback: Vector3 = Vector3(_direction.x, 0.0, _direction.z)
						if flat_fallback.length_squared() > 0.001:
							_direction = flat_fallback.normalized()
				break

			# Vrai mur ou tronc vertical (absf(hit_normal.y) <= 0.52) : s'immobilise à 0.9m de la surface
			if absf(hit_normal.y) <= 0.52:
				var dist_to_wall: float = cur_pos.distance_to(hit_pos)
				if dist_to_wall <= 0.9:
					global_position = hit_pos + hit_normal * 0.9
				else:
					var allowed: float = maxf(0.0, dist_to_wall - 0.9)
					global_position = cur_pos + _direction * minf(step_dist, allowed)
				_stopped_on_surface = true
				return

			# Plafond incliné : glisse le long du plafond sans s'arrêter
			var into_ceil: float = _direction.dot(hit_normal)
			if into_ceil < 0.0:
				var ceil_slide: Vector3 = _direction - hit_normal * into_ceil
				if ceil_slide.length_squared() > 0.001:
					_direction = ceil_slide.normalized()
			break

	var next_pos: Vector3 = cur_pos + _direction * step_dist
	if space_state != null:
		var q_down: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			next_pos + Vector3(0.0, 1.5, 0.0),
			next_pos - Vector3(0.0, 1.3, 0.0),
			1,
			_exclude_rids
		)
		var g_hit: Dictionary = space_state.intersect_ray(q_down)
		if not g_hit.is_empty():
			var gn: Vector3 = g_hit.get("normal", Vector3.UP) as Vector3
			if gn.y > 0.52:
				var gp: Vector3 = g_hit.get("position", next_pos) as Vector3
				min_hover_y = maxf(min_hover_y, gp.y + 1.15)

	if next_pos.y < min_hover_y:
		next_pos.y = min_hover_y
		if _direction.y < 0.0:
			var flat_d: Vector3 = Vector3(_direction.x, 0.0, _direction.z)
			if flat_d.length_squared() > 0.001:
				_direction = flat_d.normalized()

	global_position = next_pos


func _pull_nearby_enemies(delta: float, eff_pull_speed: float) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return

	var max_pull_r: float = _impact_radius * 1.1
	for mob_node: Node in tree.get_nodes_in_group("Enemie"):
		var mob: Node3D = mob_node as Node3D
		if mob == null or not is_instance_valid(mob) or mob.get("is_dead") == true:
			continue
		var hc: HealthComponent = mob.get_node_or_null("HealthComponent") as HealthComponent
		if hc != null and (hc.is_intangible or hc.current_health <= 0.0):
			continue

		var to_orb_flat: Vector3 = Vector3(
			global_position.x - mob.global_position.x,
			0.0,
			global_position.z - mob.global_position.z
		)
		var horiz_dist: float = to_orb_flat.length()
		if horiz_dist > max_pull_r or horiz_dist < 0.75:
			continue
		if absf(global_position.y - (mob.global_position.y + 0.9)) > 4.6:
			continue

		var kc: KnockbackComponent = mob.get_node_or_null("knockback_componant") as KnockbackComponent
		if kc == null:
			kc = mob.get_node_or_null("KnockbackComponent") as KnockbackComponent
		if kc == null:
			continue

		var step_len: float = minf(eff_pull_speed * delta, horiz_dist - 0.75)
		if step_len > 0.001:
			var pull_step: Vector3 = (to_orb_flat / horiz_dist) * step_len
			kc.apply_pull_displacement(pull_step)


func _begin_collapse() -> void:
	_phase = OrbPhase.COLLAPSING
	SpellAudioManager.play_ice_windup(self, global_position, 0.66, -1.2)


func _trigger_implosion() -> void:
	_phase = OrbPhase.EXPLODING

	if _orb_visual_root != null:
		_orb_visual_root.visible = false
	if _inward_particles != null:
		_inward_particles.emitting = false

	if _shock_sphere_mi != null:
		_shock_sphere_mi.visible = true
		_shock_sphere_mi.scale = Vector3.ONE * 0.35
	if _shock_ring_mi != null:
		_shock_ring_mi.visible = true
		_shock_ring_mi.scale = Vector3.ONE * 0.35

	SpellAudioManager.play_fire_impact(self, global_position, 0.72, -0.4)
	SpellAudioManager.play_lightning_cast(self, global_position, 0.68, -2.0)

	if _is_auth:
		_deal_aoe_damage(_impact_radius, 1.0, true)


func _deal_aoe_damage(radius: float, damage_scale: float, apply_status: bool) -> void:
	if attack_component == null:
		return

	attack_component.global_position = global_position
	attack_component.damage_physical = _full_dmg_phys * damage_scale
	attack_component.damage_magic = _full_dmg_magic * damage_scale
	attack_component.damage_fire = _full_dmg_fire * damage_scale
	attack_component.damage_ice = _full_dmg_ice * damage_scale
	attack_component.damage_lightning = _full_dmg_lightning * damage_scale

	if apply_status:
		attack_component.status_effects_to_apply = _saved_status_effects
	else:
		var empty_effects: Array[StatusEffectApplication] = []
		attack_component.status_effects_to_apply = empty_effects

	var hit_ids: Dictionary = {}

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state != null:
		var params: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		params.shape = _get_query_sphere(radius)
		params.transform = Transform3D(Basis.IDENTITY, global_position)
		params.collision_mask = 8
		params.collide_with_areas = true
		params.collide_with_bodies = false

		var hits: Array[Dictionary] = space_state.intersect_shape(params, 24)
		for entry: Dictionary in hits:
			var hb: HitboxComponent = entry.get("collider") as HitboxComponent
			if hb == null:
				continue
			var entity: Node = hb.owner if hb.owner != null else hb.get_parent()
			if entity == null or entity == _caster or entity.is_in_group("Player"):
				continue
			var eid: int = entity.get_instance_id()
			if hit_ids.has(eid):
				continue
			hit_ids[eid] = true
			hb.receive_hit(attack_component)

	var tree: SceneTree = get_tree()
	if tree != null:
		for mob_node: Node in tree.get_nodes_in_group("Enemie"):
			var mob: Node3D = mob_node as Node3D
			if mob == null or not is_instance_valid(mob) or mob.get("is_dead") == true:
				continue
			var eid_m: int = mob.get_instance_id()
			if hit_ids.has(eid_m):
				continue
			var d_flat: float = Vector2(
				mob.global_position.x - global_position.x,
				mob.global_position.z - global_position.z
			).length()
			if d_flat <= radius and absf(global_position.y - (mob.global_position.y + 0.9)) <= 4.2:
				var mob_hb: HitboxComponent = _find_mob_hitbox(mob)
				if mob_hb != null:
					hit_ids[eid_m] = true
					mob_hb.receive_hit(attack_component)

	attack_component.status_effects_to_apply = _saved_status_effects
