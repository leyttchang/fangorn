class_name VitalOrb
extends Node3D

## Orbe de Vie ou de Mana pouvant jaillir d'un Cocon de Racines.
## Rebondit légèrement au sol, flotte doucement puis est attirée magnétiquement vers le joueur proche.

enum OrbType { HEALTH = 1, MANA = 2 }

@export var orb_type: OrbType = OrbType.HEALTH
@export var heal_percent: float = 0.18
@export var mana_percent: float = 0.25
@export var magnet_radius: float = 4.2
@export var pickup_radius: float = 0.95
@export var lifetime: float = 25.0

var _vel: Vector3 = Vector3.ZERO
var _ground_y: float = 0.0
var _landed: bool = false
var _time: float = 0.0
var _consumed: bool = false
var _visual_root: Node3D = null

const PICKUP_SFX_PATH := "res://assets/sound_effects/UI/wav (HD)/JDSherbert - Ultimate UI SFX Pack - Select - 2.wav"

func setup_orb(p_type: OrbType, start_pos: Vector3, ground_y: float, initial_vel: Vector3) -> void:
	orb_type = p_type
	global_position = start_pos
	_ground_y = ground_y
	_vel = initial_vel

func _ready() -> void:
	if _ground_y == 0.0:
		_ground_y = global_position.y
	_build_visuals()

func _build_visuals() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "OrbVisual"
	add_child(_visual_root)

	var is_hp := (orb_type == OrbType.HEALTH)
	var core_col := Color(1.0, 0.22, 0.18, 1.0) if is_hp else Color(0.18, 0.62, 1.0, 1.0)
	var glow_col := Color(1.0, 0.45, 0.25, 1.0) if is_hp else Color(0.32, 0.82, 1.0, 1.0)

	var mesh_inst := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.17
	sph.height = 0.34
	sph.radial_segments = 16
	sph.rings = 8

	var mat := StandardMaterial3D.new()
	mat.albedo_color = core_col
	mat.roughness = 0.15
	mat.emission_enabled = true
	mat.emission = glow_col
	mat.emission_energy_multiplier = 2.6
	sph.material = mat
	mesh_inst.mesh = sph
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual_root.add_child(mesh_inst)

	# Halo externe translucide
	var halo_inst := MeshInstance3D.new()
	var halo_mesh := QuadMesh.new()
	halo_mesh.size = Vector2(0.65, 0.65)
	var halo_mat := ProceduralForestMeshes.get_spore_particle_material().duplicate() as StandardMaterial3D
	halo_mat.albedo_color = Color(glow_col.r, glow_col.g, glow_col.b, 0.72)
	halo_mesh.material = halo_mat
	halo_inst.mesh = halo_mesh
	halo_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual_root.add_child(halo_inst)

	# Quelques étincelles douces
	var particles := GPUParticles3D.new()
	particles.amount = 10
	particles.lifetime = 0.9
	particles.local_coords = false
	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 0.18
	pmat.direction = Vector3.UP
	pmat.spread = 35.0
	pmat.initial_velocity_min = 0.35
	pmat.initial_velocity_max = 0.85
	pmat.gravity = Vector3.ZERO
	pmat.scale_min = 0.45
	pmat.scale_max = 0.9
	pmat.color = Color(glow_col.r, glow_col.g, glow_col.b, 0.85)
	particles.process_material = pmat
	particles.draw_pass_1 = ProceduralForestMeshes.get_spore_quad_mesh(0.10)
	_visual_root.add_child(particles)

func _process(delta: float) -> void:
	if _consumed:
		return

	_time += delta
	if _time >= lifetime:
		queue_free()
		return

	# Phase 1 : Petit rebond parabolique jusqu'au sol
	if not _landed:
		_vel.y -= 14.0 * delta
		global_position += _vel * delta
		if global_position.y <= _ground_y + 0.38 and _vel.y < 0.0:
			global_position.y = _ground_y + 0.38
			if absf(_vel.y) > 1.8:
				_vel.y = -_vel.y * 0.35
				_vel.x *= 0.45
				_vel.z *= 0.45
			else:
				_landed = true
				_vel = Vector3.ZERO
	else:
		if _visual_root != null:
			_visual_root.position.y = sin(_time * 3.6) * 0.09

	# Phase 2 : Attraction magnétique vers le joueur le plus proche (après 0.35s d'éjection)
	if _time < 0.35:
		return

	var best_player: Node3D = null
	var best_dist := magnet_radius
	for p in get_tree().get_nodes_in_group("Player"):
		if not (p is Node3D) or not is_instance_valid(p):
			continue
		if p.get("is_dead") == true:
			continue
		var target_pos: Vector3 = p.global_position + Vector3(0.0, 1.0, 0.0)
		var d := global_position.distance_to(target_pos)
		if d < best_dist:
			best_dist = d
			best_player = p

	if best_player != null:
		_landed = true
		var target_pos: Vector3 = best_player.global_position + Vector3(0.0, 1.0, 0.0)
		var speed := lerpf(6.5, 18.0, clampf(1.0 - (best_dist / magnet_radius), 0.0, 1.0))
		global_position = global_position.move_toward(target_pos, speed * delta)
		if global_position.distance_to(target_pos) <= pickup_radius:
			_collect_for_player(best_player)

func _collect_for_player(player: Node3D) -> void:
	if _consumed:
		return
	_consumed = true

	# Appliquer le soin ou le mana sur l'autorité du joueur concerné
	if not multiplayer.has_multiplayer_peer() or player.is_multiplayer_authority():
		_apply_restore(player)

	# Petit son cristallin local
	if ResourceLoader.exists(PICKUP_SFX_PATH) and get_tree().current_scene != null:
		var sfx := AudioStreamPlayer3D.new()
		sfx.stream = load(PICKUP_SFX_PATH)
		sfx.pitch_scale = 1.35 if orb_type == OrbType.HEALTH else 1.55
		sfx.volume_db = -13.0
		sfx.max_distance = 14.0
		get_tree().current_scene.add_child(sfx)
		sfx.global_position = global_position
		sfx.finished.connect(sfx.queue_free)
		sfx.play()

	queue_free()

func _apply_restore(player: Node3D) -> void:
	var stats := player.get_node_or_null("StatsComponent") as StatsComponent
	if orb_type == OrbType.HEALTH:
		var hc := player.get_node_or_null("HealthComponent") as HealthComponent
		if hc != null and stats != null:
			var amount := maxf(10.0, stats.get_stat_value("max_health") * heal_percent)
			hc.heal(amount)
	else:
		var mc := player.get_node_or_null("ManaComponent") as ManaComponent
		if mc == null:
			mc = player.find_child("ManaComponent*", true, false) as ManaComponent
		if mc != null and stats != null:
			var amount := maxf(10.0, stats.get_stat_value("max_mana") * mana_percent)
			mc.add_mana(amount)
