extends Node3D

const DASH_STREAK_SEGMENTS: int = 6
const JITTER_STEP: float = 0.032

static var _webs_by_caster: Dictionary = {}

static var _dash_cyl: CylinderMesh = null
static var _dash_mat_core: StandardMaterial3D = null
static var _dash_mat_glow: StandardMaterial3D = null

@export var dash_speed: float = 35.0
@export var dash_duration: float = 0.20
@export var dash_trail_linger: float = 0.18
@export var post_duration: float = 7.5
@export var wire_check_interval: float = 0.08
@export var wire_horiz_radius: float = 0.85
@export var per_mob_cooldown_ms: int = 850

@onready var attack_component: AttackComponent = $AttackComponent
@onready var scaling_component: SpellScalingComponent = $SpellScalingComponent
@onready var dash_col_shape: CollisionShape3D = $AttackComponent/CollisionShape3D

var _caster_body: CharacterBody3D = null
var _health_comp: HealthComponent = null
var _player_hitbox: Area3D = null
var _active_web: StormwireWeb = null

var _dash_dir: Vector3 = Vector3.FORWARD
var _dash_start_visual: Vector3 = Vector3.ZERO
var _dash_end_visual: Vector3 = Vector3.ZERO

var _elapsed: float = 0.0
var _jitter_accum: float = JITTER_STEP
var _is_dashing: bool = false
var _is_auth: bool = true

var _saved_collision_layer: int = 2
var _saved_collision_mask: int = 257
var _saved_hitbox_monitorable: bool = true
var _exception_bodies: Array[PhysicsBody3D] = []
var _state_restored: bool = false

var _dash_core_segs: Array[MeshInstance3D] = []
var _dash_glow_segs: Array[MeshInstance3D] = []


static func _ensure_dash_visuals() -> void:
	if _dash_cyl == null:
		_dash_cyl = CylinderMesh.new()
		_dash_cyl.top_radius = 1.0
		_dash_cyl.bottom_radius = 1.0
		_dash_cyl.height = 1.0
		_dash_cyl.radial_segments = 5
		_dash_cyl.rings = 0
		_dash_cyl.cap_top = false
		_dash_cyl.cap_bottom = false

	if _dash_mat_core == null:
		_dash_mat_core = StandardMaterial3D.new()
		_dash_mat_core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_dash_mat_core.albedo_color = Color(2.35, 2.95, 4.35, 1.0)

	if _dash_mat_glow == null:
		_dash_mat_glow = StandardMaterial3D.new()
		_dash_mat_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_dash_mat_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_dash_mat_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_dash_mat_glow.albedo_color = Color(0.50, 1.55, 3.85, 0.76)


static func sample_ground_y(space_state: PhysicsDirectSpaceState3D, world_pos: Vector3) -> float:
	if space_state == null:
		return world_pos.y
	var ray_from: Vector3 = world_pos + Vector3(0.0, 3.0, 0.0)
	var ray_to: Vector3 = world_pos - Vector3(0.0, 35.0, 0.0)
	var exclude_rids: Array[RID] = []

	for _attempt: int in range(6):
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1, exclude_rids)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit: Dictionary = space_state.intersect_ray(query)
		if hit.is_empty():
			break
		var col_obj: Variant = hit.get("collider")
		if col_obj is CharacterBody3D:
			var hit_rid: RID = hit.get("rid", RID()) as RID
			if hit_rid.is_valid():
				exclude_rids.append(hit_rid)
				continue
			break
		if hit.has("position"):
			var hit_pt: Vector3 = hit["position"] as Vector3
			return hit_pt.y
		break

	return world_pos.y


func _ready() -> void:
	_ensure_dash_visuals()
	for _i: int in range(DASH_STREAK_SEGMENTS):
		var c_mi: MeshInstance3D = MeshInstance3D.new()
		c_mi.mesh = _dash_cyl
		c_mi.material_override = _dash_mat_core
		c_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c_mi.visible = false
		add_child(c_mi)
		_dash_core_segs.append(c_mi)

		var g_mi: MeshInstance3D = MeshInstance3D.new()
		g_mi.mesh = _dash_cyl
		g_mi.material_override = _dash_mat_glow
		g_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g_mi.visible = false
		add_child(g_mi)
		_dash_glow_segs.append(g_mi)


func execute(caster: Node3D, target_data: Dictionary) -> void:
	if caster == null or not is_instance_valid(caster):
		queue_free()
		return

	var is_remote: bool = bool(target_data.get("is_remote_visual", false))
	_is_auth = (not is_remote) and (not multiplayer.has_multiplayer_peer() or caster.is_multiplayer_authority())

	var depart_pos: Vector3 = caster.global_position
	global_position = depart_pos

	if attack_component != null:
		attack_component.on_execute(caster, target_data)
		if not _is_auth:
			attack_component.is_active_for_network = false
			attack_component.monitoring = false
	if scaling_component != null:
		scaling_component.on_execute(caster, target_data)
		if dash_col_shape != null and dash_col_shape.shape is SphereShape3D:
			var dup_sph: SphereShape3D = (dash_col_shape.shape as SphereShape3D).duplicate() as SphereShape3D
			if dup_sph != null:
				dup_sph.radius = scaling_component.final_impact_radius
				dash_col_shape.shape = dup_sph

	# Plante un poteau électrique fermement dans le vrai sol au point de départ et le relie à tous les poteaux actifs
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state if get_world_3d() != null else null
	var ground_y: float = sample_ground_y(space_state, depart_pos)
	var grounded_post_pos: Vector3 = Vector3(depart_pos.x, ground_y, depart_pos.z)
	_dash_start_visual = Vector3(depart_pos.x, ground_y + 0.42, depart_pos.z)
	_dash_end_visual = caster.global_position + Vector3(0.0, 0.65, 0.0)

	_active_web = _get_or_create_web(caster)
	if _active_web != null:
		_active_web.configure_params(post_duration, wire_check_interval, wire_horiz_radius, per_mob_cooldown_ms)
		_active_web.sync_attack_stats(attack_component, caster, _is_auth)
		_active_web.add_grounded_post(grounded_post_pos)

	_caster_body = caster as CharacterBody3D
	_health_comp = caster.get_node_or_null("HealthComponent") as HealthComponent
	_player_hitbox = caster.get_node_or_null("HitboxComponent") as Area3D

	if _caster_body != null and _is_auth:
		var cam: Camera3D = _caster_body.get_node_or_null("Camera3D") as Camera3D
		var raw_aim: Vector3 = -cam.global_transform.basis.z if cam != null else -_caster_body.global_transform.basis.z
		var flat_aim: Vector3 = Vector3(raw_aim.x, 0.0, raw_aim.z)
		if flat_aim.length_squared() > 0.001:
			flat_aim = flat_aim.normalized()
		else:
			flat_aim = Vector3.FORWARD

		if raw_aim.y > 0.10 or not _caster_body.is_on_floor():
			var clamped_y: float = clampf(raw_aim.y, -0.45, 0.45)
			_dash_dir = Vector3(flat_aim.x, clamped_y, flat_aim.z).normalized()
		else:
			_dash_dir = flat_aim

		_caster_body.set("external_motion_override", true)
		_saved_collision_layer = _caster_body.collision_layer
		_saved_collision_mask = _caster_body.collision_mask
		_caster_body.collision_layer = 0
		_caster_body.collision_mask = _saved_collision_mask & ~256
		_add_enemy_exceptions()

		if _health_comp != null:
			_health_comp.push_intangible()
		if _player_hitbox != null:
			_saved_hitbox_monitorable = _player_hitbox.monitorable
			_player_hitbox.set_deferred("monitorable", false)

	_is_dashing = true
	_elapsed = 0.0
	SpellAudioManager.play_lightning_cast(self, _dash_start_visual, 1.32, -1.2)


func _get_or_create_web(caster: Node3D) -> StormwireWeb:
	var cid: int = caster.get_instance_id()
	var existing_val: Variant = _webs_by_caster.get(cid)
	if existing_val != null and is_instance_valid(existing_val):
		var existing_web: StormwireWeb = existing_val as StormwireWeb
		if existing_web != null and existing_web.is_inside_tree():
			return existing_web

	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return null

	var web: StormwireWeb = StormwireWeb.new()
	web.name = "StormwireWeb_" + str(cid)
	tree.root.add_child(web)
	_webs_by_caster[cid] = web
	return web


func _add_enemy_exceptions() -> void:
	if _caster_body == null or get_tree() == null:
		return
	var cpos: Vector3 = _caster_body.global_position
	for node: Node in get_tree().get_nodes_in_group("Enemie"):
		var pb: PhysicsBody3D = node as PhysicsBody3D
		if pb != null and is_instance_valid(pb) and not _exception_bodies.has(pb):
			if pb.global_position.distance_squared_to(cpos) <= 1225.0:
				_caster_body.add_collision_exception_with(pb)
				_exception_bodies.append(pb)
	for boss_node: Node in get_tree().get_nodes_in_group("Boss"):
		var b_pb: PhysicsBody3D = boss_node as PhysicsBody3D
		if b_pb != null and is_instance_valid(b_pb) and not _exception_bodies.has(b_pb):
			_caster_body.add_collision_exception_with(b_pb)
			_exception_bodies.append(b_pb)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_jitter_accum += delta

	if _is_dashing:
		if _caster_body != null and is_instance_valid(_caster_body):
			if _is_auth:
				if _elapsed < dash_duration and _caster_body.get("is_dead") != true:
					_add_enemy_exceptions()
					if _dash_dir.y == 0.0 and _caster_body.is_on_floor():
						_caster_body.velocity = Vector3(_dash_dir.x * dash_speed, -6.0, _dash_dir.z * dash_speed)
					else:
						_caster_body.velocity = _dash_dir * dash_speed
					_caster_body.move_and_slide()
				else:
					_finish_dash()
			global_position = _caster_body.global_position
			_dash_end_visual = _caster_body.global_position + Vector3(0.0, 0.65, 0.0)
			if _jitter_accum >= JITTER_STEP:
				_jitter_accum = 0.0
				_update_dash_streak(_dash_start_visual, _dash_end_visual, 1.0)
			if not _is_auth and _elapsed >= dash_duration:
				_finish_dash()
		else:
			_finish_dash()
	else:
		var fade_t: float = (_elapsed - dash_duration) / maxf(0.05, dash_trail_linger)
		if fade_t >= 1.0:
			queue_free()
			return
		if _jitter_accum >= JITTER_STEP:
			_jitter_accum = 0.0
			_update_dash_streak(_dash_start_visual, _dash_end_visual, maxf(0.05, 1.0 - fade_t))


func _finish_dash() -> void:
	if not _is_dashing:
		return
	_is_dashing = false
	_restore_player_state()

	if attack_component != null and is_instance_valid(attack_component):
		if _is_auth and _active_web != null and is_instance_valid(_active_web):
			for hit_node: Node in attack_component.hit_entities:
				if hit_node != null and is_instance_valid(hit_node):
					_active_web.register_dash_grace(hit_node.get_instance_id(), 360)
		attack_component.set_deferred("monitoring", false)
		attack_component.set_deferred("monitorable", false)
		attack_component.is_active_for_network = false


func _restore_player_state() -> void:
	if _state_restored:
		return
	_state_restored = true

	if _caster_body != null and is_instance_valid(_caster_body) and _is_auth:
		for pb: PhysicsBody3D in _exception_bodies:
			if pb != null and is_instance_valid(pb):
				_caster_body.remove_collision_exception_with(pb)
		_exception_bodies.clear()

		_caster_body.collision_layer = _saved_collision_layer
		_caster_body.collision_mask = _saved_collision_mask
		_caster_body.velocity = Vector3(_dash_dir.x * 4.5, minf(0.0, _caster_body.velocity.y), _dash_dir.z * 4.5)
		_caster_body.set("external_motion_override", false)

	if _health_comp != null and is_instance_valid(_health_comp) and _is_auth:
		_health_comp.pop_intangible()

	if _player_hitbox != null and is_instance_valid(_player_hitbox) and _is_auth:
		_player_hitbox.set_deferred("monitorable", _saved_hitbox_monitorable)


func _exit_tree() -> void:
	_restore_player_state()


func _update_dash_streak(p_start: Vector3, p_end: Vector3, width_mult: float) -> void:
	var dist: float = p_start.distance_to(p_end)
	if dist < 0.15:
		for c_hide: MeshInstance3D in _dash_core_segs:
			c_hide.visible = false
		for g_hide: MeshInstance3D in _dash_glow_segs:
			g_hide.visible = false
		return

	var dir: Vector3 = (p_end - p_start) / dist
	var seg_len: float = dist / float(DASH_STREAK_SEGMENTS)
	var pts: PackedVector3Array = PackedVector3Array()
	pts.resize(DASH_STREAK_SEGMENTS + 1)
	pts[0] = p_start
	pts[DASH_STREAK_SEGMENTS] = p_end

	for i: int in range(1, DASH_STREAK_SEGMENTS):
		var base_p: Vector3 = p_start + dir * (seg_len * float(i))
		var arch: float = sin((float(i) / float(DASH_STREAK_SEGMENTS)) * PI)
		var rnd: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5), randf_range(-1.0, 1.0))
		if rnd.length_squared() > 0.001:
			rnd = rnd.normalized() * 0.24 * arch * width_mult
		pts[i] = base_p + rnd

	var core_r: float = 0.052 * width_mult
	var glow_r: float = 0.118 * width_mult

	for i: int in range(DASH_STREAK_SEGMENTS):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var d: Vector3 = b - a
		var l: float = d.length()
		var c_mi: MeshInstance3D = _dash_core_segs[i]
		var g_mi: MeshInstance3D = _dash_glow_segs[i]
		if l < 0.002:
			c_mi.visible = false
			g_mi.visible = false
			continue
		c_mi.visible = true
		g_mi.visible = true
		var y_ax: Vector3 = d / l
		var up_ref: Vector3 = Vector3.UP if absf(y_ax.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		var x_ax: Vector3 = up_ref.cross(y_ax).normalized()
		var z_ax: Vector3 = x_ax.cross(y_ax).normalized()
		var mid: Vector3 = a.lerp(b, 0.5)
		c_mi.global_transform = Transform3D(Basis(x_ax * core_r, y_ax * l, z_ax * core_r), mid)
		g_mi.global_transform = Transform3D(Basis(x_ax * glow_r, y_ax * l, z_ax * glow_r), mid)


# ==============================================================================
# RÉSEAU PERSISTANT DE POTEAUX ÉLECTRIQUES AU SOL (Tous reliés deux à deux)
# ==============================================================================
class StormwireWeb:
	extends Node3D

	const MAX_POSTS: int = 4
	const MAX_LINKS: int = 6 # C(4, 2) = 6 liaisons max (3 pour 3 poteaux en triangle complet)
	const LINK_SEGMENTS: int = 8
	const WIRE_HEIGHT_ABOVE_GROUND: float = 0.35
	const WEB_JITTER_STEP: float = 0.032

	static var _w_cyl: CylinderMesh = null
	static var _w_capped_cyl: CylinderMesh = null
	static var _w_sph: SphereMesh = null
	static var _w_mat_shaft: StandardMaterial3D = null
	static var _w_mat_base: StandardMaterial3D = null
	static var _w_mat_core: StandardMaterial3D = null
	static var _w_mat_glow: StandardMaterial3D = null

	var _post_lifetime: float = 7.5
	var _check_interval: float = 0.08
	var _horiz_radius: float = 0.85
	var _mob_cd_ms: int = 850

	var _caster: Node3D = null
	var _is_auth: bool = true
	var _web_attack: AttackComponent = null

	# Chaque entrée de _posts : Dictionary { "ground_pos": Vector3, "remaining": float, "root": Node3D, "orb": MeshInstance3D }
	var _posts: Array[Dictionary] = []
	# Chaque entrée de _links : Dictionary { "waypoints": PackedVector3Array, "ground_ys": PackedFloat32Array, "idx_a": int, "idx_b": int }
	var _links: Array[Dictionary] = []

	var _link_core_pool: Array = []
	var _link_glow_pool: Array = []

	var _check_accum: float = 0.0
	var _jitter_accum: float = WEB_JITTER_STEP
	var _hum_accum: float = 0.0
	var _pulse_time: float = 0.0
	var _zap_flare: float = 0.0

	var _mob_hit_cooldown_ms: Dictionary = {}
	var _hitbox_cache: Dictionary = {}


	static func _ensure_web_visuals() -> void:
		if _w_cyl == null:
			_w_cyl = CylinderMesh.new()
			_w_cyl.top_radius = 1.0
			_w_cyl.bottom_radius = 1.0
			_w_cyl.height = 1.0
			_w_cyl.radial_segments = 5
			_w_cyl.rings = 0
			_w_cyl.cap_top = false
			_w_cyl.cap_bottom = false

		if _w_capped_cyl == null:
			_w_capped_cyl = CylinderMesh.new()
			_w_capped_cyl.top_radius = 1.0
			_w_capped_cyl.bottom_radius = 1.0
			_w_capped_cyl.height = 1.0
			_w_capped_cyl.radial_segments = 8
			_w_capped_cyl.rings = 0
			_w_capped_cyl.cap_top = true
			_w_capped_cyl.cap_bottom = true

		if _w_sph == null:
			_w_sph = SphereMesh.new()
			_w_sph.radius = 1.0
			_w_sph.height = 2.0
			_w_sph.radial_segments = 8
			_w_sph.rings = 4

		if _w_mat_shaft == null:
			_w_mat_shaft = StandardMaterial3D.new()
			_w_mat_shaft.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_w_mat_shaft.albedo_color = Color(0.55, 0.95, 1.75, 1.0)

		if _w_mat_base == null:
			_w_mat_base = StandardMaterial3D.new()
			_w_mat_base.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_w_mat_base.albedo_color = Color(1.15, 2.05, 3.60, 1.0)

		if _w_mat_core == null:
			_w_mat_core = StandardMaterial3D.new()
			_w_mat_core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_w_mat_core.albedo_color = Color(2.45, 3.05, 4.45, 1.0)

		if _w_mat_glow == null:
			_w_mat_glow = StandardMaterial3D.new()
			_w_mat_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_w_mat_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			_w_mat_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_w_mat_glow.albedo_color = Color(0.50, 1.60, 3.95, 0.82)


	func _ready() -> void:
		_ensure_web_visuals()

		_web_attack = AttackComponent.new()
		_web_attack.name = "WebAttackComponent"
		_web_attack.collision_layer = 0
		_web_attack.collision_mask = 0
		_web_attack.monitoring = false
		_web_attack.monitorable = false
		_web_attack.is_active_for_network = false
		add_child(_web_attack)

		for _l: int in range(MAX_LINKS):
			var core_arr: Array = []
			var glow_arr: Array = []
			for _s: int in range(LINK_SEGMENTS):
				var c_mi: MeshInstance3D = MeshInstance3D.new()
				c_mi.mesh = _w_cyl
				c_mi.material_override = _w_mat_core
				c_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				c_mi.visible = false
				add_child(c_mi)
				core_arr.append(c_mi)

				var g_mi: MeshInstance3D = MeshInstance3D.new()
				g_mi.mesh = _w_cyl
				g_mi.material_override = _w_mat_glow
				g_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				g_mi.visible = false
				add_child(g_mi)
				glow_arr.append(g_mi)
			_link_core_pool.append(core_arr)
			_link_glow_pool.append(glow_arr)


	func configure_params(post_dur: float, check_int: float, horiz_r: float, cd_ms: int) -> void:
		_post_lifetime = maxf(1.0, post_dur)
		_check_interval = maxf(0.03, check_int)
		_horiz_radius = maxf(0.3, horiz_r)
		_mob_cd_ms = maxi(150, cd_ms)


	func sync_attack_stats(src_attack: AttackComponent, caster_node: Node3D, auth: bool) -> void:
		_caster = caster_node
		_is_auth = auth
		if _web_attack == null or src_attack == null:
			return

		_web_attack.caster = caster_node
		_web_attack.is_active_for_network = false
		_web_attack.base_damage = src_attack.base_damage
		_web_attack.damage_physical = src_attack.damage_physical
		_web_attack.damage_magic = src_attack.damage_magic
		_web_attack.damage_fire = src_attack.damage_fire
		_web_attack.damage_ice = src_attack.damage_ice
		_web_attack.damage_lightning = src_attack.damage_lightning
		_web_attack.knockback_force = src_attack.knockback_force
		_web_attack.knockback_angle = src_attack.knockback_angle
		_web_attack.can_headshot = false
		_web_attack.status_effects_to_apply = src_attack.status_effects_to_apply.duplicate()
		if caster_node != null and is_instance_valid(caster_node):
			_web_attack.set_meta("caster_authority", caster_node.get_multiplayer_authority())


	func register_dash_grace(mob_instance_id: int, grace_ms: int) -> void:
		var now_ms: int = Time.get_ticks_msec()
		_mob_hit_cooldown_ms[mob_instance_id] = now_ms - (_mob_cd_ms - grace_ms)


	func add_grounded_post(ground_pos: Vector3) -> void:
		while _posts.size() >= MAX_POSTS:
			_remove_post_at(0)

		var post_root: Node3D = Node3D.new()
		add_child(post_root)
		post_root.global_position = ground_pos

		# Tige métallique plantée fermement dans le sol : de ground_y - 0.15 à ground_y + 1.05 (hauteur 1.20m, centre +0.45m)
		var shaft_mi: MeshInstance3D = MeshInstance3D.new()
		shaft_mi.mesh = _w_capped_cyl
		shaft_mi.material_override = _w_mat_shaft
		shaft_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shaft_mi.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(0.052, 1.20, 0.052)), Vector3(0.0, 0.45, 0.0))
		post_root.add_child(shaft_mi)

		# Socle / collerette lumineuse plaquée au ras du sol
		var base_plate: MeshInstance3D = MeshInstance3D.new()
		base_plate.mesh = _w_capped_cyl
		base_plate.material_override = _w_mat_base
		base_plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		base_plate.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(0.22, 0.06, 0.22)), Vector3(0.0, 0.03, 0.0))
		post_root.add_child(base_plate)

		# Anneau isolateur bas à la hauteur exacte des câbles (+0.35m)
		var wire_collar: MeshInstance3D = MeshInstance3D.new()
		wire_collar.mesh = _w_capped_cyl
		wire_collar.material_override = _w_mat_base
		wire_collar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wire_collar.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(0.095, 0.08, 0.095)), Vector3(0.0, 0.35, 0.0))
		post_root.add_child(wire_collar)

		# Orbe conducteur principal bas (ground_y + 0.42m)
		var cond_orb: MeshInstance3D = MeshInstance3D.new()
		cond_orb.mesh = _w_sph
		cond_orb.material_override = _w_mat_core
		cond_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cond_orb.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.125), Vector3(0.0, 0.42, 0.0))
		post_root.add_child(cond_orb)

		# Petite pointe terminale au sommet du poteau (ground_y + 1.05m)
		var top_cap: MeshInstance3D = MeshInstance3D.new()
		top_cap.mesh = _w_sph
		top_cap.material_override = _w_mat_glow
		top_cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		top_cap.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.075), Vector3(0.0, 1.05, 0.0))
		post_root.add_child(top_cap)

		var entry: Dictionary = {
			"ground_pos": ground_pos,
			"remaining": _post_lifetime,
			"root": post_root,
			"orb": cond_orb
		}
		_posts.append(entry)

		SpellAudioManager.play_lightning_cast(self, ground_pos + Vector3(0.0, 0.42, 0.0), 1.16, -2.5)
		_rebuild_links_cache()
		_render_all_links()


	func _remove_post_at(idx: int) -> void:
		if idx < 0 or idx >= _posts.size():
			return
		var entry: Dictionary = _posts[idx]
		var post_root: Node3D = entry.get("root") as Node3D
		if post_root != null and is_instance_valid(post_root):
			post_root.queue_free()
		_posts.remove_at(idx)


	func _rebuild_links_cache() -> void:
		_links.clear()
		var n: int = _posts.size()
		if n < 2:
			_hide_unused_links(0)
			return

		var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state if get_world_3d() != null else null

		for i: int in range(n):
			var pos_a: Vector3 = _posts[i]["ground_pos"] as Vector3
			for j: int in range(i + 1, n):
				if _links.size() >= MAX_LINKS:
					break
				var pos_b: Vector3 = _posts[j]["ground_pos"] as Vector3
				var horiz_d: float = Vector2(pos_a.x, pos_a.z).distance_to(Vector2(pos_b.x, pos_b.z))
				if horiz_d < 0.20:
					continue

				var waypoints: PackedVector3Array = PackedVector3Array()
				var ground_ys: PackedFloat32Array = PackedFloat32Array()
				waypoints.resize(LINK_SEGMENTS + 1)
				ground_ys.resize(LINK_SEGMENTS + 1)

				for k: int in range(LINK_SEGMENTS + 1):
					var t: float = float(k) / float(LINK_SEGMENTS)
					var sample_x: float = lerpf(pos_a.x, pos_b.x, t)
					var sample_z: float = lerpf(pos_a.z, pos_b.z, t)
					var approx_y: float = lerpf(pos_a.y, pos_b.y, t)
					var gy: float = approx_y
					if k == 0:
						gy = pos_a.y
					elif k == LINK_SEGMENTS:
						gy = pos_b.y
					else:
						gy = _sample_link_ground_y(space_state, Vector3(sample_x, approx_y, sample_z))
					ground_ys[k] = gy
					waypoints[k] = Vector3(sample_x, gy + WIRE_HEIGHT_ABOVE_GROUND, sample_z)

				var link_dict: Dictionary = {
					"waypoints": waypoints,
					"ground_ys": ground_ys,
					"idx_a": i,
					"idx_b": j
				}
				_links.append(link_dict)

		_hide_unused_links(_links.size())


	func _sample_link_ground_y(space_state: PhysicsDirectSpaceState3D, hint_pos: Vector3) -> float:
		if space_state == null:
			return hint_pos.y
		var ray_from: Vector3 = hint_pos + Vector3(0.0, 10.0, 0.0)
		var ray_to: Vector3 = hint_pos - Vector3(0.0, 35.0, 0.0)
		var exclude_rids: Array[RID] = []

		for _attempt: int in range(6):
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1, exclude_rids)
			query.collide_with_areas = false
			query.collide_with_bodies = true
			var hit: Dictionary = space_state.intersect_ray(query)
			if hit.is_empty():
				break
			var col_obj: Variant = hit.get("collider")
			if col_obj is CharacterBody3D:
				var hit_rid: RID = hit.get("rid", RID()) as RID
				if hit_rid.is_valid():
					exclude_rids.append(hit_rid)
					continue
				break
			if hit.has("position"):
				var hit_pt: Vector3 = hit["position"] as Vector3
				return hit_pt.y
			break

		return hint_pos.y


	func _physics_process(delta: float) -> void:
		_pulse_time += delta
		_jitter_accum += delta
		if _zap_flare > 0.0:
			_zap_flare = maxf(0.0, _zap_flare - delta * 4.5)

		var removed_any: bool = false
		var idx: int = _posts.size() - 1
		while idx >= 0:
			var entry: Dictionary = _posts[idx]
			var rem: float = float(entry["remaining"]) - delta
			entry["remaining"] = rem
			if rem <= 0.0:
				_remove_post_at(idx)
				removed_any = true
			else:
				_animate_post(entry, rem, idx)
			idx -= 1

		if _posts.is_empty():
			queue_free()
			return

		if removed_any:
			_rebuild_links_cache()

		if _is_auth and not _links.is_empty():
			_check_accum += delta
			if _check_accum >= _check_interval:
				_check_accum = fmod(_check_accum, _check_interval)
				_check_grounded_wire_hits()

		if not _links.is_empty():
			_hum_accum += delta
			if _hum_accum >= 0.78:
				_hum_accum = 0.0
				var first_wps: PackedVector3Array = _links[0]["waypoints"] as PackedVector3Array
				if first_wps.size() > 4:
					SpellAudioManager.play_lightning_cast(self, first_wps[4], 1.44, -7.2)

		if _jitter_accum >= WEB_JITTER_STEP:
			_jitter_accum = 0.0
			_render_all_links()


	func _animate_post(entry: Dictionary, rem: float, idx_seed: int) -> void:
		var fade: float = clampf(rem / 0.35, 0.12, 1.0)
		var post_root: Node3D = entry.get("root") as Node3D
		if post_root != null and is_instance_valid(post_root):
			post_root.scale = Vector3.ONE * fade

		var orb: MeshInstance3D = entry.get("orb") as MeshInstance3D
		if orb != null and is_instance_valid(orb):
			var pulse: float = 0.125 * (1.0 + 0.16 * sin(_pulse_time * 12.0 + float(idx_seed) * 1.7) + _zap_flare * 0.25)
			orb.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * pulse), Vector3(0.0, 0.42, 0.0))


	func _render_all_links() -> void:
		var link_count: int = _links.size()
		_hide_unused_links(link_count)

		for l_idx: int in range(link_count):
			var link_dict: Dictionary = _links[l_idx]
			var wps: PackedVector3Array = link_dict["waypoints"] as PackedVector3Array
			var gys: PackedFloat32Array = link_dict["ground_ys"] as PackedFloat32Array
			var idx_a: int = int(link_dict["idx_a"])
			var idx_b: int = int(link_dict["idx_b"])

			var fade_a: float = clampf(float(_posts[idx_a]["remaining"]) / 0.35, 0.10, 1.0) if idx_a < _posts.size() else 1.0
			var fade_b: float = clampf(float(_posts[idx_b]["remaining"]) / 0.35, 0.10, 1.0) if idx_b < _posts.size() else 1.0
			var width_mult: float = minf(fade_a, fade_b) * (1.0 + _zap_flare * 0.65)

			var core_segs: Array = _link_core_pool[l_idx]
			var glow_segs: Array = _link_glow_pool[l_idx]

			var core_pts: PackedVector3Array = PackedVector3Array()
			var glow_pts: PackedVector3Array = PackedVector3Array()
			core_pts.resize(LINK_SEGMENTS + 1)
			glow_pts.resize(LINK_SEGMENTS + 1)

			core_pts[0] = wps[0]
			core_pts[LINK_SEGMENTS] = wps[LINK_SEGMENTS]
			glow_pts[0] = wps[0]
			glow_pts[LINK_SEGMENTS] = wps[LINK_SEGMENTS]

			for k: int in range(1, LINK_SEGMENTS):
				var base_pt: Vector3 = wps[k]
				var min_y: float = gys[k] + 0.12
				var c_jit: Vector3 = Vector3(
					randf_range(-0.025, 0.025),
					randf_range(-0.025, 0.025),
					randf_range(-0.025, 0.025)
				) * width_mult
				var cp: Vector3 = base_pt + c_jit
				cp.y = maxf(min_y, cp.y)
				core_pts[k] = cp

				var g_jit: Vector3 = Vector3(
					randf_range(-0.08, 0.08),
					randf_range(-0.08, 0.08),
					randf_range(-0.08, 0.08)
				) * width_mult
				var gp: Vector3 = base_pt + g_jit
				gp.y = maxf(min_y, gp.y)
				glow_pts[k] = gp

			var core_r: float = 0.032 * width_mult
			var glow_r: float = 0.088 * width_mult

			for s: int in range(LINK_SEGMENTS):
				_place_seg(core_segs[s] as MeshInstance3D, core_pts[s], core_pts[s + 1], core_r)
				_place_seg(glow_segs[s] as MeshInstance3D, glow_pts[s], glow_pts[s + 1], glow_r)


	func _place_seg(mi: MeshInstance3D, p1: Vector3, p2: Vector3, radius: float) -> void:
		if mi == null:
			return
		var d: Vector3 = p2 - p1
		var l: float = d.length()
		if l < 0.002:
			mi.visible = false
			return
		mi.visible = true
		var y_ax: Vector3 = d / l
		var up_ref: Vector3 = Vector3.UP if absf(y_ax.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		var x_ax: Vector3 = up_ref.cross(y_ax).normalized()
		var z_ax: Vector3 = x_ax.cross(y_ax).normalized()
		mi.global_transform = Transform3D(Basis(x_ax * radius, y_ax * l, z_ax * radius), p1.lerp(p2, 0.5))


	func _hide_unused_links(active_count: int) -> void:
		for l_idx: int in range(active_count, MAX_LINKS):
			var core_segs: Array = _link_core_pool[l_idx]
			var glow_segs: Array = _link_glow_pool[l_idx]
			for s: int in range(LINK_SEGMENTS):
				var c_mi: MeshInstance3D = core_segs[s] as MeshInstance3D
				var g_mi: MeshInstance3D = glow_segs[s] as MeshInstance3D
				if c_mi != null:
					c_mi.visible = false
				if g_mi != null:
					g_mi.visible = false


	func _check_grounded_wire_hits() -> void:
		if _web_attack == null or not is_instance_valid(_web_attack):
			return

		var now_ms: int = Time.get_ticks_msec()
		var r_sq: float = _horiz_radius * _horiz_radius
		var any_tripped: bool = false
		var last_trip_pt: Vector3 = Vector3.ZERO

		for node: Node in get_tree().get_nodes_in_group("Enemie"):
			var mob: Node3D = node as Node3D
			if mob == null or _is_mob_dead(mob):
				continue

			var mid: int = mob.get_instance_id()
			var prev_ms: int = int(_mob_hit_cooldown_ms.get(mid, -10000))
			if (now_ms - prev_ms) < _mob_cd_ms:
				continue

			var mob_pos: Vector3 = mob.global_position
			var mob_2d: Vector2 = Vector2(mob_pos.x, mob_pos.z)
			var hit_found: bool = false
			var hit_wire_pt: Vector3 = Vector3.ZERO

			for l_idx: int in range(_links.size()):
				var wps: PackedVector3Array = _links[l_idx]["waypoints"] as PackedVector3Array
				for s: int in range(LINK_SEGMENTS):
					var wa: Vector3 = wps[s]
					var wb: Vector3 = wps[s + 1]
					var closest_2d: Vector2 = Geometry2D.get_closest_point_to_segment(
						mob_2d,
						Vector2(wa.x, wa.z),
						Vector2(wb.x, wb.z)
					)
					if mob_2d.distance_squared_to(closest_2d) > r_sq:
						continue

					var seg_2d_len: float = Vector2(wa.x, wa.z).distance_to(Vector2(wb.x, wb.z))
					var seg_t: float = Vector2(wa.x, wa.z).distance_to(closest_2d) / seg_2d_len if seg_2d_len > 0.001 else 0.5
					var wire_y: float = lerpf(wa.y, wb.y, clampf(seg_t, 0.0, 1.0))
					if absf(mob_pos.y - wire_y) <= 1.40:
						hit_found = true
						hit_wire_pt = Vector3(closest_2d.x, wire_y, closest_2d.y)
						break
				if hit_found:
					break

			if not hit_found:
				continue

			var hb: HitboxComponent = _resolve_hitbox(mob)
			if hb != null:
				_mob_hit_cooldown_ms[mid] = now_ms
				_web_attack.global_position = hit_wire_pt
				hb.receive_hit(_web_attack)
				any_tripped = true
				last_trip_pt = hit_wire_pt

		if any_tripped:
			_zap_flare = 1.0
			SpellAudioManager.play_lightning_strike_thunder(self, last_trip_pt, 1.38, -3.5)


	func _resolve_hitbox(mob: Node3D) -> HitboxComponent:
		var mid: int = mob.get_instance_id()
		var cached_val: Variant = _hitbox_cache.get(mid)
		var hb: HitboxComponent = null
		if cached_val != null and is_instance_valid(cached_val):
			hb = cached_val as HitboxComponent
		if hb != null:
			return hb

		hb = mob.get_node_or_null("HitboxComponent") as HitboxComponent
		if hb == null:
			var found_areas: Array[Node] = mob.find_children("*", "Area3D", true, false)
			for cand: Node in found_areas:
				var cand_hb: HitboxComponent = cand as HitboxComponent
				if cand_hb != null:
					hb = cand_hb
					if cand_hb.body_part_multiplier <= 1.05:
						break
		if hb != null:
			_hitbox_cache[mid] = hb
		return hb


	static func _is_mob_dead(mob: Node3D) -> bool:
		if mob == null or not is_instance_valid(mob) or mob.is_queued_for_deletion():
			return true
		if mob.get("is_dead") == true:
			return true
		var hc: HealthComponent = mob.get_node_or_null("HealthComponent") as HealthComponent
		if hc != null and hc.current_health <= 0.0:
			return true
		return false
