@tool
class_name SpeedMushroom
extends Node3D

## Bouquet de champignons bioluminescents destructible d'un coup d'épée ou de sort!
## - Donne un buff de vitesse (+30% pendant 5s, rafraîchi sans cumul infini)
## - Donne un petit gain d'XP
## - Éclate en nuage de spores lumineuses et quartiers de chapeau physiques

@export_category("Récompenses")
@export var speed_buff_duration: float = 5.0
@export var speed_buff_resource: StatusEffectData = preload("res://scripts/status_effects/mushroom_speed_buff.tres")
@export var xp_reward: int = 12

@export_category("Visuel & Optimisation")
## Optionnel : glisser une scène .glb / .tscn Blender ici remplacera automatiquement le bouquet procédural !
@export var custom_visual_scene: PackedScene:
	set(value):
		custom_visual_scene = value
		if is_inside_tree():
			_rebuild_visuals()
@export var visibility_max_distance: float = 135.0

const SFX_POP_PATH := "res://assets/sound_effects/Combat and Gore/splat_quick.wav"
const SFX_CRUNCH_PATH := "res://assets/sound_effects/Combat and Gore/crunch_quick.wav"

var _is_destroyed: bool = false
var _visual_root: Node3D = null
var _hitbox: BreakableHitbox = null

func _ready() -> void:
	_rebuild_visuals()
	if not Engine.is_editor_hint():
		_setup_hitbox()

func _rebuild_visuals() -> void:
	if Engine.is_editor_hint():
		ProceduralForestMeshes.clear_caches()
	if _visual_root != null and is_instance_valid(_visual_root):
		_visual_root.queue_free()
		remove_child(_visual_root)

	_visual_root = Node3D.new()
	_visual_root.name = "VisualCluster"
	add_child(_visual_root)

	var no_limit := Engine.is_editor_hint()
	var vis_end := 0.0 if no_limit else visibility_max_distance

	if custom_visual_scene != null:
		var inst := custom_visual_scene.instantiate()
		_visual_root.add_child(inst)
		return

	# Bouquet organique de 3 champignons bioluminescents
	var layout := [
		{"pos": Vector3(0.0, -0.02, 0.0), "rot": Vector3(0.05, 0.2, -0.06), "scale": 1.15, "variant": 0, "cap_y": 0.60, "cap_x": 0.09},
		{"pos": Vector3(-0.26, -0.03, 0.16), "rot": Vector3(0.14, 2.1, 0.18), "scale": 0.95, "variant": 1, "cap_y": 0.42, "cap_x": -0.07},
		{"pos": Vector3(0.23, -0.03, -0.17), "rot": Vector3(-0.16, 4.3, -0.14), "scale": 0.85, "variant": 2, "cap_y": 0.29, "cap_x": 0.05}
	]

	var stem_mat := ProceduralForestMeshes.get_mushroom_stem_material()
	var cap_mat := ProceduralForestMeshes.get_mushroom_cap_material()

	for item in layout:
		var holder := Node3D.new()
		holder.position = item["pos"]
		holder.rotation = item["rot"]
		holder.scale = Vector3.ONE * float(item["scale"])
		_visual_root.add_child(holder)

		var stem_mi := MeshInstance3D.new()
		stem_mi.mesh = ProceduralForestMeshes.get_mushroom_stem_mesh(item["variant"])
		stem_mi.material_override = stem_mat
		stem_mi.visibility_range_end = vis_end
		stem_mi.visibility_range_end_margin = 20.0 if vis_end > 0.0 else 0.0
		holder.add_child(stem_mi)

		var cap_mi := MeshInstance3D.new()
		cap_mi.mesh = ProceduralForestMeshes.get_mushroom_cap_mesh(item["variant"])
		cap_mi.material_override = cap_mat
		cap_mi.position = Vector3(item["cap_x"], item["cap_y"], 0.0)
		cap_mi.rotation = Vector3(0.08, 0.0, -0.10)
		cap_mi.visibility_range_end = vis_end
		cap_mi.visibility_range_end_margin = 20.0 if vis_end > 0.0 else 0.0
		holder.add_child(cap_mi)

	# Spores flottantes ambiantes légères (visibles à courte/moyenne portée)
	if not Engine.is_editor_hint():
		var ambient_spores := GPUParticles3D.new()
		ambient_spores.position = Vector3(0.0, 0.45, 0.0)
		ambient_spores.amount = 8
		ambient_spores.lifetime = 2.4
		ambient_spores.visibility_range_end = 55.0
		ambient_spores.visibility_range_end_margin = 10.0
		var pmat := ParticleProcessMaterial.new()
		pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pmat.emission_sphere_radius = 0.42
		pmat.direction = Vector3.UP
		pmat.spread = 35.0
		pmat.initial_velocity_min = 0.12
		pmat.initial_velocity_max = 0.32
		pmat.gravity = Vector3(0.0, 0.06, 0.0)
		pmat.scale_min = 0.45
		pmat.scale_max = 0.95
		pmat.color = Color(0.28, 1.0, 0.82, 0.72)
		ambient_spores.process_material = pmat
		ambient_spores.draw_pass_1 = ProceduralForestMeshes.get_spore_quad_mesh(0.11)
		_visual_root.add_child(ambient_spores)

func _setup_hitbox() -> void:
	_hitbox = get_node_or_null("BreakableHitbox") as BreakableHitbox
	if _hitbox == null:
		_hitbox = BreakableHitbox.new()
		_hitbox.name = "BreakableHitbox"
		var col := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.95
		col.shape = sph
		col.position = Vector3(0.0, 0.48, 0.0)
		_hitbox.add_child(col)
		add_child(_hitbox)
	if not _hitbox.breakable_struck.is_connected(_on_struck):
		_hitbox.breakable_struck.connect(_on_struck)

func _on_struck(attacker: Node3D, hit_dir: Vector3, _attack: AttackComponent) -> void:
	if _is_destroyed:
		return

	var peer_id: int = 1
	if attacker != null and is_instance_valid(attacker):
		peer_id = attacker.get_multiplayer_authority()

	if multiplayer.has_multiplayer_peer():
		_rpc_shatter_mushroom.rpc(peer_id, hit_dir)
	else:
		_rpc_shatter_mushroom(peer_id, hit_dir)

@rpc("any_peer", "call_local", "reliable")
func _rpc_shatter_mushroom(attacker_peer_id: int, hit_dir: Vector3) -> void:
	if _is_destroyed:
		return
	_is_destroyed = true

	if _hitbox != null and is_instance_valid(_hitbox):
		_hitbox.collision_layer = 0
		_hitbox.collision_mask = 0

	# 1. Récompenses (Buff de vitesse 5s + XP) appliquées au joueur qui a cassé le champignon
	_grant_rewards_to_peer(attacker_peer_id)

	# 2. Masquer le bouquet intact
	if _visual_root != null and is_instance_valid(_visual_root):
		_visual_root.visible = false

	# 3. Explosion satisfaisante : nuage de spores + éclats physiques + audio
	_spawn_spore_explosion(hit_dir)
	_spawn_cap_chunks(hit_dir)
	_play_pop_sound()

	# Nettoyage différé une fois l'explosion terminée
	var timer := get_tree().create_timer(1.65)
	timer.timeout.connect(queue_free)

func _grant_rewards_to_peer(attacker_peer_id: int) -> void:
	var target_player: Node3D = null
	for p in get_tree().get_nodes_in_group("Player"):
		if p is Node3D and is_instance_valid(p) and p.get_multiplayer_authority() == attacker_peer_id:
			target_player = p as Node3D
			break

	if target_player == null and not get_tree().get_nodes_in_group("Player").is_empty():
		target_player = get_tree().get_nodes_in_group("Player")[0] as Node3D

	if target_player == null:
		return

	# Seule l'autorité du joueur cible applique ses buffs et son XP (StatusEffectComponent synchronise le reste)
	if not multiplayer.has_multiplayer_peer() or target_player.is_multiplayer_authority():
		# Buff de vitesse (rafraîchit à 5s sans empiler au-delà de +30%)
		if speed_buff_resource != null:
			var status_comp: StatusEffectComponent = null
			for child in target_player.get_children():
				if child is StatusEffectComponent:
					status_comp = child
					break
			if status_comp != null:
				status_comp.apply_effect(speed_buff_resource, speed_buff_duration)

		# Gain d'XP
		if xp_reward > 0:
			var lvl_comp := target_player.get_node_or_null("lvl_component") as LevelComponent
			if lvl_comp == null:
				lvl_comp = target_player.find_child("lvl_component*", true, false) as LevelComponent
			if lvl_comp != null:
				lvl_comp.add_xp(xp_reward)

func _spawn_spore_explosion(hit_dir: Vector3) -> void:
	var burst := GPUParticles3D.new()
	burst.position = Vector3(0.0, 0.42, 0.0)
	burst.amount = 34
	burst.lifetime = 0.95
	burst.one_shot = true
	burst.explosiveness = 0.94

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 0.22
	pmat.direction = (hit_dir + Vector3(0.0, 0.85, 0.0)).normalized()
	pmat.spread = 68.0
	pmat.initial_velocity_min = 2.4
	pmat.initial_velocity_max = 6.2
	pmat.damping_min = 3.5
	pmat.damping_max = 5.5
	pmat.gravity = Vector3(0.0, -2.2, 0.0)
	pmat.scale_min = 0.8
	pmat.scale_max = 1.9

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	grad.colors = PackedColorArray([
		Color(0.65, 1.0, 0.92, 1.0),
		Color(0.18, 0.95, 0.76, 0.78),
		Color(0.08, 0.55, 0.50, 0.0)
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	pmat.color_ramp = ramp

	burst.process_material = pmat
	burst.draw_pass_1 = ProceduralForestMeshes.get_spore_quad_mesh(0.20)
	add_child(burst)
	burst.emitting = true

func _spawn_cap_chunks(hit_dir: Vector3) -> void:
	var chunk_mesh := ProceduralForestMeshes.get_mushroom_chunk_mesh()
	var cap_mat := ProceduralForestMeshes.get_mushroom_cap_material()
	var impulses: Array[Dictionary] = []

	for i in range(5):
		var rb := RigidBody3D.new()
		rb.collision_layer = 0
		rb.collision_mask = 1 # Rebondit sur le sol sans gêner le joueur
		rb.mass = 0.25
		rb.position = Vector3(randf_range(-0.18, 0.18), randf_range(0.32, 0.58), randf_range(-0.18, 0.18))

		var col := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.08
		col.shape = sph
		rb.add_child(col)

		var mi := MeshInstance3D.new()
		mi.mesh = chunk_mesh
		mi.material_override = cap_mat
		mi.scale = Vector3.ONE * randf_range(0.9, 1.45)
		rb.add_child(mi)
		add_child(rb)

		var spread_ang := (TAU / 5.0) * float(i) + randf_range(-0.3, 0.3)
		var out_dir := (Vector3(cos(spread_ang), 0.0, sin(spread_ang)) * 0.65 + hit_dir * 0.85).normalized()
		var imp := out_dir * randf_range(1.4, 2.8) + Vector3.UP * randf_range(1.2, 2.3)
		var torq := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 0.5
		impulses.append({"rb": rb, "imp": imp, "torq": torq, "mi": mi})

	_apply_chunk_impulses_deferred(impulses)

func _apply_chunk_impulses_deferred(impulses: Array[Dictionary]) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	await get_tree().physics_frame
	for entry in impulses:
		var rb: RigidBody3D = entry["rb"]
		var mi: MeshInstance3D = entry["mi"]
		if is_instance_valid(rb) and rb.is_inside_tree():
			rb.apply_central_impulse(entry["imp"])
			rb.apply_torque_impulse(entry["torq"])
			var tw := create_tween()
			tw.tween_interval(0.75)
			tw.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

func _play_pop_sound() -> void:
	if ResourceLoader.exists(SFX_POP_PATH):
		var sfx1 := AudioStreamPlayer3D.new()
		sfx1.stream = load(SFX_POP_PATH)
		sfx1.pitch_scale = randf_range(1.22, 1.42)
		sfx1.volume_db = -10.5
		sfx1.max_distance = 18.0
		add_child(sfx1)
		sfx1.play()
	if ResourceLoader.exists(SFX_CRUNCH_PATH):
		var sfx2 := AudioStreamPlayer3D.new()
		sfx2.stream = load(SFX_CRUNCH_PATH)
		sfx2.pitch_scale = randf_range(1.35, 1.55)
		sfx2.volume_db = -14.0
		sfx2.max_distance = 16.0
		add_child(sfx2)
		sfx2.play()
