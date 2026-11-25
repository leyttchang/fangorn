extends Node3D

static var _shard_mesh: PrismMesh = null
static var _shard_mat: StandardMaterial3D = null
static var _query_sphere: SphereShape3D = null

@export var shell_duration: float = 6.0
@export var shield_max_hp_ratio: float = 0.24
@export var retaliation_radius: float = 4.5
@export var retaliation_icd: float = 0.35

@onready var attack_component: AttackComponent = $AttackComponent
@onready var scaling_component: SpellScalingComponent = $SpellScalingComponent

var _caster: Node3D = null
var _health_comp: HealthComponent = null
var _hitbox_comp: HitboxComponent = null
var _orbit_pivot: Node3D = null
var _elapsed: float = 0.0
var _icd_timer: float = 0.0
var _active: bool = false
var _is_auth: bool = true
var _granted_shield: float = 0.0


static func _ensure_shared_visuals() -> void:
	if _shard_mesh == null:
		_shard_mesh = PrismMesh.new()
		_shard_mesh.size = Vector3(0.26, 0.48, 0.08)

	if _shard_mat == null:
		_shard_mat = StandardMaterial3D.new()
		_shard_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shard_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_shard_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shard_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_shard_mat.albedo_color = Color(0.55, 1.45, 2.25, 0.52)

	if _query_sphere == null:
		_query_sphere = SphereShape3D.new()
		_query_sphere.radius = 4.5


func _ready() -> void:
	_ensure_shared_visuals()
	if attack_component != null:
		attack_component.monitoring = false
		attack_component.monitorable = false
		attack_component.is_active_for_network = false

	_orbit_pivot = Node3D.new()
	_orbit_pivot.name = "FrostPlates"
	add_child(_orbit_pivot)

	for i: int in range(3):
		var angle: float = float(i) * (TAU / 3.0)
		var plate: MeshInstance3D = MeshInstance3D.new()
		plate.mesh = _shard_mesh
		plate.material_override = _shard_mat
		plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		plate.position = Vector3(cos(angle) * 0.68, 0.68, sin(angle) * 0.68)
		plate.rotation = Vector3(0.18, -angle + PI * 0.5, 0.0)
		_orbit_pivot.add_child(plate)


func execute(caster: Node3D, target_data: Dictionary) -> void:
	_caster = caster
	if _caster == null or not is_instance_valid(_caster):
		queue_free()
		return

	_is_auth = (not multiplayer.has_multiplayer_peer() or _caster.is_multiplayer_authority())
	global_position = _caster.global_position

	# En vue subjective locale, on baisse légèrement les plaques pour ne jamais gêner la caméra
	if _caster.is_in_group("Player") and _caster.is_multiplayer_authority() and _orbit_pivot != null:
		_orbit_pivot.position.y = -0.35

	if attack_component != null:
		attack_component.on_execute(_caster, target_data)
		attack_component.is_active_for_network = false
	if scaling_component != null:
		scaling_component.on_execute(_caster, target_data)

	var ab_data: AbilityData = target_data.get("ability_data") as AbilityData
	var lvl_mult: float = SpellScalingComponent.resolve_level_power_multiplier(_caster, ab_data, target_data)

	_health_comp = _caster.get_node_or_null("HealthComponent") as HealthComponent
	_hitbox_comp = _caster.get_node_or_null("HitboxComponent") as HitboxComponent

	if _is_auth and _health_comp != null:
		var max_hp: float = _health_comp.get_max_health()
		_granted_shield = maxf(10.0, max_hp * shield_max_hp_ratio * lvl_mult)
		_health_comp.set_shield(_granted_shield)
		_health_comp.shield_damaged.connect(_on_shield_damaged)

	if _is_auth and _hitbox_comp != null:
		_hitbox_comp.hit_received.connect(_on_caster_hit)

	_active = true
	SpellAudioManager.play_ice_cast(self, global_position, 0.94, -1.8)


func _process(delta: float) -> void:
	if not _active or _caster == null or not is_instance_valid(_caster) or _caster.get("is_dead") == true:
		_expire_shell(false)
		return

	if _icd_timer > 0.0:
		_icd_timer -= delta

	_elapsed += delta
	global_position = _caster.global_position
	if _orbit_pivot != null:
		_orbit_pivot.rotate_y(delta * 2.4)

	if _is_auth and _health_comp != null and _health_comp.current_shield <= 0.01 and _elapsed > 0.1:
		_expire_shell(true)
		return

	if _elapsed >= shell_duration:
		_expire_shell(false)


func _on_shield_damaged(_absorbed: float) -> void:
	_trigger_chill_retaliation()


func _on_caster_hit(_attack: AttackComponent) -> void:
	_trigger_chill_retaliation()


func _trigger_chill_retaliation() -> void:
	if not _active or not _is_auth or _icd_timer > 0.0 or _caster == null:
		return
	_icd_timer = retaliation_icd

	SpellAudioManager.play_ice_windup(self, _caster.global_position, 1.25, -3.5)
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state == null or attack_component == null:
		return

	var params: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	params.shape = _query_sphere
	params.transform = Transform3D(Basis.IDENTITY, _caster.global_position + Vector3(0.0, 0.9, 0.0))
	params.collision_mask = 8
	params.collide_with_areas = true
	params.collide_with_bodies = false

	var hits: Array[Dictionary] = space_state.intersect_shape(params, 16)
	attack_component.global_position = _caster.global_position
	var seen: Dictionary = {}
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


func _expire_shell(shattered: bool) -> void:
	if not _active:
		queue_free()
		return
	_active = false

	if _health_comp != null and is_instance_valid(_health_comp):
		if _health_comp.shield_damaged.is_connected(_on_shield_damaged):
			_health_comp.shield_damaged.disconnect(_on_shield_damaged)
		if _is_auth and not shattered and _health_comp.current_shield > 0.0:
			_health_comp.clear_shield()

	if _hitbox_comp != null and is_instance_valid(_hitbox_comp):
		if _hitbox_comp.hit_received.is_connected(_on_caster_hit):
			_hitbox_comp.hit_received.disconnect(_on_caster_hit)

	if shattered and _caster != null and is_instance_valid(_caster):
		SpellAudioManager.play_ice_cast(self, _caster.global_position, 1.35, -2.5)

	queue_free()
