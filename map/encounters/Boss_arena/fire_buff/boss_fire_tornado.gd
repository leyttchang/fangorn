class_name BossFireTornado
extends Node3D

## Tornade de feu (~4.4m de haut) générée lors des attaques Slam et Jump Slam de l'Ogre Boss
## lorsqu'au moins un Totem Feu a été complété.
## - Inflige des dégâts de feu et projette fortement les joueurs radialement ET vers le haut (`knockback_angle`).
## - Balaye le sol de l'arène avec une courbure organique, suit le relief (raycast Layer 1 cadencé à 0.08s)
##   et se dissipe proprement contre les murs d'arbres (Layer 8) ou en fin de durée.
## - Intègre un `PlaceholderVFX` léger et sans fumée, remplaçable par `custom_vfx_scene`.

const GROUND_COLLISION_MASK: int = 1
const TREE_WALL_COLLISION_MASK: int = 128
const RAYCAST_INTERVAL_SEC: float = 0.08

@export_category("Tornade de Feu du Boss")

@export_group("Dégâts & Knockback vers le haut")
@export_range(0.0, 300.0, 1.0) var damage_fire: float = 24.0
@export_range(0.0, 60.0, 0.5) var knockback_force: float = 24.0
@export_range(0.0, 85.0, 1.0, "suffix:°") var knockback_angle: float = 62.0
@export_range(0.2, 4.0, 0.05, "suffix:s") var rehit_cooldown: float = 0.85

@export_group("Brûlure (Status Effect)")
@export_range(0.0, 1.0, 0.05) var burn_chance: float = 0.5
@export_range(0.5, 15.0, 0.25, "suffix:s") var burn_duration: float = 4.5
@export var burn_status_effect: StatusEffectData = preload("res://scripts/status_effects/burn/burn.tres")

@export_group("Mouvement & Durée")
@export_range(1.0, 24.0, 0.2, "suffix:m/s") var move_speed: float = 6.2
@export_range(1.0, 15.0, 0.2, "suffix:s") var duration: float = 4.8
@export_range(-3.0, 3.0, 0.05) var swirl_curve_rate: float = 0.45
@export_range(0.0, 1.5, 0.05) var wave_wobble_amplitude: float = 0.26
@export_range(0.5, 8.0, 0.1) var wave_wobble_frequency: float = 2.3
@export_range(0.05, 0.8, 0.02, "suffix:s") var fade_in_duration: float = 0.2
@export_range(0.1, 1.5, 0.05, "suffix:s") var fade_out_duration: float = 0.45

@export_group("Visuel (Placeholder remplaçable)")
## Si assigné, supprime `PlaceholderVFX` et instancie cette scène personnalisée à la place.
@export var custom_vfx_scene: PackedScene = null

@onready var attack_component: AttackComponent = get_node_or_null("AttackComponent") as AttackComponent
@onready var attack_shape: CollisionShape3D = get_node_or_null("AttackComponent/CollisionShape3D") as CollisionShape3D
@onready var vfx_container: Node3D = get_node_or_null("VFXContainer") as Node3D
@onready var placeholder_vfx: Node3D = get_node_or_null("VFXContainer/PlaceholderVFX") as Node3D

var move_dir: Vector3 = Vector3.FORWARD

var _caster: Node3D = null
var _elapsed: float = 0.0
var _dissipate_elapsed: float = 0.0
var _is_dissipating: bool = false
var _stopped_by_obstacle: bool = false
var _raycast_timer: float = 0.0
var _target_ground_y: float = 0.0
var _ground_initialized: bool = false
var _dissipate_start_scale: Vector3 = Vector3.ONE
var _visual_phase_seed: float = 0.0

# instance_id (int) -> { "entity": Node, "time_left": float }
var _rehit_timers: Dictionary = {}
var _shader_materials: Array[ShaderMaterial] = []
var _particle_nodes: Array[GPUParticles3D] = []


## Configure la tornade juste après instanciation (ou à chaud).
func setup_tornado(
	p_move_dir: Vector3,
	p_speed: float = 6.2,
	p_duration: float = 4.8,
	p_damage_fire: float = 24.0,
	p_knockback_force: float = 24.0,
	p_knockback_angle: float = 62.0,
	p_curve_rate: float = 0.45,
	p_caster: Node3D = null
) -> void:
	var flat_dir := Vector3(p_move_dir.x, 0.0, p_move_dir.z)
	if flat_dir.length_squared() > 0.0001:
		move_dir = flat_dir.normalized()
	else:
		move_dir = Vector3.FORWARD

	move_speed = maxf(0.0, p_speed)
	duration = maxf(0.6, p_duration)
	damage_fire = maxf(0.0, p_damage_fire)
	knockback_force = maxf(0.0, p_knockback_force)
	knockback_angle = clampf(p_knockback_angle, 0.0, 85.0)
	swirl_curve_rate = p_curve_rate
	_caster = p_caster

	# Graine visuelle déterministe dérivée de la direction initiale
	_visual_phase_seed = absf( atan2(move_dir.x, move_dir.z) * 2.37 + swirl_curve_rate * 4.13 )

	if is_node_ready():
		_sync_attack_component()
		_apply_shader_phase_seed()


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	var flat_dir := Vector3(move_dir.x, 0.0, move_dir.z)
	if flat_dir.length_squared() > 0.0001:
		move_dir = flat_dir.normalized()
	else:
		move_dir = Vector3.FORWARD

	if _visual_phase_seed == 0.0:
		_visual_phase_seed = randf_range(0.0, TAU)

	_setup_visuals()
	_sync_attack_component()

	if attack_component != null and not attack_component.attack_landed.is_connected(_on_attack_landed):
		attack_component.attack_landed.connect(_on_attack_landed)

	if vfx_container != null:
		vfx_container.scale = Vector3(0.22, 0.06, 0.22)
	_set_vfx_opacity(0.0)


func _setup_visuals() -> void:
	_shader_materials.clear()
	_particle_nodes.clear()

	if vfx_container == null:
		return

	if custom_vfx_scene != null:
		if placeholder_vfx != null and is_instance_valid(placeholder_vfx):
			placeholder_vfx.visible = false
			placeholder_vfx.queue_free()
			placeholder_vfx = null
		var custom_inst: Node3D = custom_vfx_scene.instantiate() as Node3D
		if custom_inst != null:
			custom_inst.name = "CustomTornadoVFX"
			vfx_container.add_child(custom_inst)
			_collect_vfx_nodes_recursive(custom_inst, false)
	elif placeholder_vfx != null and is_instance_valid(placeholder_vfx):
		_collect_vfx_nodes_recursive(placeholder_vfx, true)

	_apply_shader_phase_seed()


func _collect_vfx_nodes_recursive(root_node: Node, duplicate_shader_mats: bool) -> void:
	if root_node is MeshInstance3D:
		var mi: MeshInstance3D = root_node as MeshInstance3D
		var mat: Material = mi.material_override
		if mat == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
			mat = mi.get_active_material(0)
		if mat is ShaderMaterial:
			var sm: ShaderMaterial = mat as ShaderMaterial
			if duplicate_shader_mats:
				sm = sm.duplicate() as ShaderMaterial
				mi.material_override = sm
			if sm != null and not _shader_materials.has(sm):
				_shader_materials.append(sm)
	elif root_node is GPUParticles3D:
		var gpu: GPUParticles3D = root_node as GPUParticles3D
		gpu.emitting = true
		_particle_nodes.append(gpu)

	for child: Node in root_node.get_children():
		_collect_vfx_nodes_recursive(child, duplicate_shader_mats)


func _apply_shader_phase_seed() -> void:
	for i: int in range(_shader_materials.size()):
		var sm: ShaderMaterial = _shader_materials[i]
		if sm != null:
			sm.set_shader_parameter("phase_offset", _visual_phase_seed + float(i) * 1.57)


func _sync_attack_component() -> void:
	if attack_component == null:
		return

	attack_component.collision_layer = 16
	attack_component.collision_mask = 2
	attack_component.base_damage = 0.0
	attack_component.damage_physical = 0.0
	attack_component.damage_magic = 0.0
	attack_component.damage_fire = damage_fire
	attack_component.damage_ice = 0.0
	attack_component.damage_lightning = 0.0
	attack_component.knockback_force = knockback_force
	attack_component.knockback_angle = knockback_angle
	attack_component.is_projectile = false
	attack_component.can_headshot = false
	attack_component.ignore_caster = false
	if _caster != null and is_instance_valid(_caster):
		attack_component.caster = _caster

	var effects: Array[StatusEffectApplication] = []
	if burn_chance > 0.0 and burn_status_effect != null:
		var burn_app := StatusEffectApplication.new()
		burn_app.effect = burn_status_effect
		burn_app.duration = burn_duration
		burn_app.apply_chance = clampf(burn_chance, 0.0, 1.0)
		effects.append(burn_app)
	attack_component.status_effects_to_apply = effects

	# Seul le serveur (ou le jeu solo) évalue les collisions d'attaque ; les clients n'affichent que le VFX
	var is_server_or_solo: bool = (not multiplayer.has_multiplayer_peer()) or multiplayer.is_server()
	attack_component.is_active_for_network = is_server_or_solo
	if not is_server_or_solo:
		attack_component.monitoring = false
		attack_component.monitorable = false


func _on_attack_landed(target: Variant) -> void:
	if _is_dissipating or rehit_cooldown <= 0.0:
		return

	var entity: Node = null
	if target is Area3D:
		var area_node: Area3D = target as Area3D
		entity = area_node.owner if area_node.owner != null else area_node.get_parent()
	elif target is Node:
		entity = target as Node

	if entity == null or not is_instance_valid(entity):
		return

	_rehit_timers[entity.get_instance_id()] = {
		"entity": entity,
		"time_left": rehit_cooldown
	}


func _update_rehit_timers(delta: float) -> void:
	if _rehit_timers.is_empty():
		return

	var expired_ids: Array[int] = []
	for key: Variant in _rehit_timers.keys():
		var inst_id: int = int(key)
		var entry: Dictionary = _rehit_timers[inst_id] as Dictionary
		var remaining: float = float(entry.get("time_left", 0.0)) - delta
		if remaining <= 0.0:
			expired_ids.append(inst_id)
		else:
			entry["time_left"] = remaining

	for inst_id: int in expired_ids:
		var entry: Dictionary = _rehit_timers[inst_id] as Dictionary
		_rehit_timers.erase(inst_id)
		if attack_component == null or _is_dissipating:
			continue
		var entity_var: Variant = entry.get("entity", null)
		if entity_var is Node:
			var entity_node: Node = entity_var as Node
			if is_instance_valid(entity_node):
				attack_component.hit_entities.erase(entity_node)
				# Si le joueur est encore dans le cylindre à la fin du cooldown, ré-appliquer proprement
				if attack_component.is_active_for_network and attack_component.monitoring:
					for ov_area: Area3D in attack_component.get_overlapping_areas():
						var ov_owner: Node = ov_area.owner if ov_area.owner != null else ov_area.get_parent()
						if ov_owner == entity_node:
							attack_component._on_area_entered(ov_area)
							break


## Déclenche immédiatement la dissipation propre de la tornade (mur d'arbres, fin de durée ou mort du boss).
func begin_dissipate(hit_obstacle: bool = false) -> void:
	if _is_dissipating:
		if hit_obstacle:
			_stopped_by_obstacle = true
		return

	_is_dissipating = true
	_stopped_by_obstacle = hit_obstacle
	_dissipate_elapsed = 0.0
	_rehit_timers.clear()

	if vfx_container != null:
		_dissipate_start_scale = vfx_container.scale
	else:
		_dissipate_start_scale = Vector3.ONE

	if attack_component != null:
		attack_component.monitoring = false
		attack_component.monitorable = false
	if attack_shape != null:
		attack_shape.set_deferred("disabled", true)

	for gpu: GPUParticles3D in _particle_nodes:
		if gpu != null and is_instance_valid(gpu):
			gpu.emitting = false


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not _ground_initialized:
		_ground_initialized = true
		_target_ground_y = global_position.y
		_perform_environment_raycasts()
		global_position.y = _target_ground_y
		reset_physics_interpolation()

	_elapsed += delta

	if not _is_dissipating:
		_update_rehit_timers(delta)

		var active_limit: float = maxf(0.1, duration - fade_out_duration)
		if _elapsed >= active_limit:
			begin_dissipate(false)
		else:
			_update_appear_visuals()

	if _is_dissipating:
		_dissipate_elapsed += delta
		var out_dur: float = maxf(0.08, fade_out_duration)
		var u_out: float = clampf(_dissipate_elapsed / out_dur, 0.0, 1.0)
		var ease_out: float = 1.0 - (u_out * u_out)

		if vfx_container != null:
			var target_end := Vector3(
				_dissipate_start_scale.x * 0.14,
				_dissipate_start_scale.y * 1.12,
				_dissipate_start_scale.z * 0.14
			)
			vfx_container.scale = _dissipate_start_scale.lerp(target_end, u_out)
		_set_vfx_opacity(ease_out)

		if not _stopped_by_obstacle:
			_step_ground_movement(delta, ease_out * 0.65)

		if _dissipate_elapsed >= out_dur:
			queue_free()
			return
	else:
		_step_ground_movement(delta, 1.0)


func _update_appear_visuals() -> void:
	var in_dur: float = maxf(0.04, fade_in_duration)
	if _elapsed < in_dur:
		var u_in: float = clampf(_elapsed / in_dur, 0.0, 1.0)
		var smooth_in: float = 1.0 - pow(1.0 - u_in, 2.4)
		if vfx_container != null:
			vfx_container.scale = Vector3(
				lerpf(0.22, 1.0, smooth_in),
				lerpf(0.06, 1.0, smooth_in),
				lerpf(0.22, 1.0, smooth_in)
			)
		_set_vfx_opacity(smooth_in)
	else:
		if vfx_container != null:
			# Légère pulsation vivante sans toucher au CollisionShape3D
			var pulse_xz: float = 1.0 + 0.035 * sin(_elapsed * 7.5 + _visual_phase_seed)
			vfx_container.scale = Vector3(pulse_xz, 1.0, pulse_xz)
		_set_vfx_opacity(1.0)


func _step_ground_movement(delta: float, speed_factor: float) -> void:
	var wobble_sign: float = -1.0 if swirl_curve_rate < 0.0 else 1.0
	var angular_rate: float = swirl_curve_rate + sin(_elapsed * wave_wobble_frequency + _visual_phase_seed) * wave_wobble_amplitude * wobble_sign
	if absf(angular_rate) > 0.0001:
		move_dir = move_dir.rotated(Vector3.UP, angular_rate * delta).normalized()

	var current_speed: float = move_speed * speed_factor
	global_position.x += move_dir.x * current_speed * delta
	global_position.z += move_dir.z * current_speed * delta

	_raycast_timer -= delta
	if _raycast_timer <= 0.0:
		_raycast_timer = RAYCAST_INTERVAL_SEC
		_perform_environment_raycasts()

	global_position.y = lerpf(global_position.y, _target_ground_y, minf(1.0, delta * 18.0))


func _perform_environment_raycasts() -> void:
	if not is_inside_tree() or get_world_3d() == null:
		return

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space == null:
		return

	# 1. Détection du mur d'arbres (Layer 8 = masque 128) dans la direction d'avancée
	if not _is_dissipating:
		var check_origin := Vector3(global_position.x, global_position.y + 1.25, global_position.z)
		var lookahead_dist: float = maxf(1.35, move_speed * RAYCAST_INTERVAL_SEC * 2.2)
		var tree_query := PhysicsRayQueryParameters3D.create(
			check_origin,
			check_origin + move_dir * lookahead_dist,
			TREE_WALL_COLLISION_MASK
		)
		tree_query.collide_with_bodies = true
		tree_query.collide_with_areas = false
		var tree_hit: Dictionary = space.intersect_ray(tree_query)
		if not tree_hit.is_empty():
			begin_dissipate(true)
			return

	# 2. Suivi de la hauteur du sol (Layer 1 = masque 1)
	var ground_query := PhysicsRayQueryParameters3D.create(
		Vector3(global_position.x, _target_ground_y + 12.0, global_position.z),
		Vector3(global_position.x, _target_ground_y - 16.0, global_position.z),
		GROUND_COLLISION_MASK
	)
	ground_query.collide_with_bodies = true
	ground_query.collide_with_areas = false
	var ground_hit: Dictionary = space.intersect_ray(ground_query)
	if not ground_hit.is_empty() and ground_hit.has("position"):
		var hit_pos: Vector3 = ground_hit["position"] as Vector3
		_target_ground_y = hit_pos.y


func _set_vfx_opacity(alpha: float) -> void:
	var clamped: float = clampf(alpha, 0.0, 1.0)
	for sm: ShaderMaterial in _shader_materials:
		if sm != null:
			sm.set_shader_parameter("opacity", clamped)
