@tool
class_name RootCocoon
extends Node3D

## Cocon de Racines destructible d'un coup d'épée ou de sort!
## - Construit avec root_shader.tres (7 côtes tressées autour d'un noyau organique pulsant)
## - Explose en projetant les morceaux de racines en physique Jolt pendant qu'ils se rétractent via le shader
## - ~10% de chance de drop un sac d'item (item_bag.tscn)
## - ~22% de chance (si pas de sac) de faire jaillir une orbe de Vie ou de Mana

@export_category("Probabilités de Loot")
@export_range(0.0, 100.0, 0.5, "suffix:%") var item_bag_drop_chance: float = 0.0
@export_range(0.0, 100.0, 0.5, "suffix:%") var vital_orb_drop_chance: float = 30.0
@export_range(0.01, 1.0, 0.01) var health_orb_heal_percent: float = 0.15

@export_group("Raretés du Sac")
@export var weight_common: int = 52
@export var weight_magic: int = 32
@export var weight_rare: int = 13
@export var weight_legendary: int = 3

@export_category("Physique d'Explosion & Visuel")
@export var shatter_horizontal_impulse: float = 5.4
@export var shatter_upward_impulse: float = 3.4
@export var shatter_torque_impulse: float = 2.6
@export var visibility_max_distance: float = 150.0

const EGG_MESH_PATH := "res://assets/3D_models/VFX_spell/eggshape_mesh.tres"
const CHUNK_MESH_PATH := "res://assets/3D_models/VFX_spell/insect_chunk_1_mesh.tres"
const BAG_SCENE_PATH := "res://objet/item_bag/item_bag.tscn"

const SFX_SNAP_PATH := "res://assets/sound_effects/Combat and Gore/bone_snap.wav"
const SFX_CRUNCH_PATH := "res://assets/sound_effects/Combat and Gore/crunch.wav"
const SFX_SPLAT_PATH := "res://assets/sound_effects/Combat and Gore/crunch_splat.wav"

static var _shared_cocoon_root_mat: ShaderMaterial = null

var _is_destroyed: bool = false
var _visual_root: Node3D = null
var _rib_nodes: Array[MeshInstance3D] = []
var _core_mesh: MeshInstance3D = null
var _hitbox: BreakableHitbox = null
var _solid_body: StaticBody3D = null

func _ready() -> void:
	_rebuild_visuals()
	if not Engine.is_editor_hint():
		_setup_collisions()

func _rebuild_visuals() -> void:
	if Engine.is_editor_hint():
		ProceduralForestMeshes.clear_caches()
		_shared_cocoon_root_mat = null
	if _visual_root != null and is_instance_valid(_visual_root):
		_visual_root.queue_free()
		remove_child(_visual_root)
	_rib_nodes.clear()

	_visual_root = Node3D.new()
	_visual_root.name = "CocoonVisual"
	add_child(_visual_root)

	var no_limit := Engine.is_editor_hint()
	var vis_end := 0.0 if no_limit else (visibility_max_distance if visibility_max_distance > 0.0 else 150.0)

	if _shared_cocoon_root_mat == null:
		_shared_cocoon_root_mat = ProceduralForestMeshes.get_base_root_material(Color(0.72, 0.58, 0.40, 1.0), 0.105, 1.5)

	# 1. Noyau sombre organique pulsant niché À L'INTÉRIEUR de la cage de racines
	_core_mesh = MeshInstance3D.new()
	_core_mesh.name = "DarkSapCore"
	if ResourceLoader.exists(EGG_MESH_PATH):
		_core_mesh.mesh = load(EGG_MESH_PATH) as Mesh
		_core_mesh.scale = Vector3(0.28, 0.34, 0.28)
	else:
		var sph := SphereMesh.new()
		sph.radius = 0.28
		sph.height = 0.72
		_core_mesh.mesh = sph
	_core_mesh.position = Vector3(0.0, 0.56, 0.0)
	_core_mesh.material_override = ProceduralForestMeshes.get_cocoon_core_material()
	_core_mesh.visibility_range_end = vis_end
	_core_mesh.visibility_range_end_margin = 20.0 if vis_end > 0.0 else 0.0
	_visual_root.add_child(_core_mesh)

	# 2. Côtes de racines entrelacées (root_shader.tres)
	var ribs := ProceduralForestMeshes.get_cocoon_ribs()
	for i in range(ribs.size()):
		var rib_data: Dictionary = ribs[i]
		var mi := MeshInstance3D.new()
		mi.name = "RootRib_" + str(i)
		mi.mesh = rib_data["mesh"]
		mi.position = rib_data["center"]
		mi.material_override = _shared_cocoon_root_mat
		mi.visibility_range_end = vis_end
		mi.visibility_range_end_margin = 20.0 if vis_end > 0.0 else 0.0
		_visual_root.add_child(mi)
		_rib_nodes.append(mi)

func _setup_collisions() -> void:
	_solid_body = get_node_or_null("StaticBody3D") as StaticBody3D
	_hitbox = get_node_or_null("BreakableHitbox") as BreakableHitbox
	if _hitbox == null:
		_hitbox = BreakableHitbox.new()
		_hitbox.name = "BreakableHitbox"
		var col := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 1.05
		col.shape = sph
		col.position = Vector3(0.0, 0.65, 0.0)
		_hitbox.add_child(col)
		add_child(_hitbox)
	if not _hitbox.breakable_struck.is_connected(_on_struck):
		_hitbox.breakable_struck.connect(_on_struck)

func _on_struck(_attacker: Node3D, hit_dir: Vector3, _attack: AttackComponent) -> void:
	if _is_destroyed:
		return

	if not multiplayer.has_multiplayer_peer():
		_server_handle_shatter(hit_dir)
	elif multiplayer.is_server():
		_server_handle_shatter(hit_dir)
	else:
		_rpc_request_shatter.rpc_id(1, hit_dir)

@rpc("any_peer", "call_local", "reliable")
func _rpc_request_shatter(hit_dir: Vector3) -> void:
	if not multiplayer.is_server() or _is_destroyed:
		return
	_server_handle_shatter(hit_dir)

func _server_handle_shatter(hit_dir: Vector3) -> void:
	if _is_destroyed:
		return

	var orb_type_to_spawn: int = 0
	var orb_angle: float = randf() * TAU

	# 30% de chance d'obtenir une petite orbe de vie (15% PV régénérés), aucun drop d'item
	var roll_orb: float = randf() * 100.0
	if roll_orb < vital_orb_drop_chance:
		orb_type_to_spawn = VitalOrb.OrbType.HEALTH

	if multiplayer.has_multiplayer_peer():
		_rpc_explode_cocoon.rpc(hit_dir, orb_type_to_spawn, orb_angle)
	else:
		_rpc_explode_cocoon(hit_dir, orb_type_to_spawn, orb_angle)

@rpc("authority", "call_local", "reliable")
func _rpc_explode_cocoon(hit_dir: Vector3, orb_type: int, orb_angle: float) -> void:
	if _is_destroyed:
		return
	_is_destroyed = true

	# Retrait immédiat des collisions pour ne jamais bloquer le mouvement du joueur
	if _solid_body != null and is_instance_valid(_solid_body):
		_solid_body.collision_layer = 0
		_solid_body.collision_mask = 0
		_solid_body.queue_free()
	if _hitbox != null and is_instance_valid(_hitbox):
		_hitbox.collision_layer = 0
		_hitbox.collision_mask = 0

	# Masquer le visuel statique
	if _core_mesh != null and is_instance_valid(_core_mesh):
		_core_mesh.visible = false

	# 1. Éjection physique Jolt des 7 côtes de racines + rétraction animée de root_shader.tres
	_shatter_roots_jolt(hit_dir)

	# 2. Particules d'éclats organiques + poussière de sève dorée
	_spawn_shatter_particles(hit_dir)

	# 3. Audio craquant multicouche
	_play_shatter_audio()

	# 4. Apparition éventuelle d'une Orbe de Vie / Mana
	if orb_type > 0:
		_spawn_vital_orb(orb_type, orb_angle)

	var cleanup := get_tree().create_timer(1.85)
	cleanup.timeout.connect(queue_free)

func _shatter_roots_jolt(hit_dir: Vector3) -> void:
	var cocoon_center := global_position + Vector3(0.0, 0.55, 0.0)
	var impulse_list: Array[Dictionary] = []

	for i in range(_rib_nodes.size()):
		var src_mi := _rib_nodes[i]
		if src_mi == null or not is_instance_valid(src_mi):
			continue
		src_mi.visible = false

		var rb := RigidBody3D.new()
		rb.collision_layer = 0
		rb.collision_mask = 1 # Touche uniquement le sol
		rb.mass = 0.65
		rb.position = src_mi.position
		rb.rotation = src_mi.rotation

		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.18, 0.45, 0.18)
		col.shape = box
		rb.add_child(col)

		var flying_mi := MeshInstance3D.new()
		flying_mi.mesh = src_mi.mesh
		var unique_mat := _shared_cocoon_root_mat.duplicate() as ShaderMaterial
		unique_mat.set_shader_parameter("fin", 0.0)
		unique_mat.set_shader_parameter("debut", 1.0)
		flying_mi.material_override = unique_mat
		flying_mi.visibility_range_end = 150.0
		flying_mi.visibility_range_end_margin = 20.0
		rb.add_child(flying_mi)
		add_child(rb)

		var radial := (rb.global_position - cocoon_center)
		radial.y = 0.0
		if radial.length_squared() < 0.001:
			var ang := (TAU / 7.0) * float(i)
			radial = Vector3(cos(ang), 0.0, sin(ang))
		else:
			radial = radial.normalized()

		var burst_dir := (radial * 0.72 + hit_dir * 0.68).normalized()
		var central_imp := burst_dir * (shatter_horizontal_impulse * randf_range(0.8, 1.25)) + Vector3.UP * (shatter_upward_impulse * randf_range(0.75, 1.25))
		var torque_imp := Vector3(randf_range(-1.0, 1.0), randf_range(-0.8, 0.8), randf_range(-1.0, 1.0)).normalized() * shatter_torque_impulse

		impulse_list.append({
			"rb": rb,
			"central": central_imp,
			"torque": torque_imp,
			"mat": unique_mat
		})

	_apply_root_impulses_deferred(impulse_list)

func _apply_root_impulses_deferred(impulse_list: Array[Dictionary]) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	await get_tree().physics_frame
	for item in impulse_list:
		var rb: RigidBody3D = item["rb"]
		var mat: ShaderMaterial = item["mat"]
		if is_instance_valid(rb) and rb.is_inside_tree():
			rb.apply_central_impulse(item["central"])
			rb.apply_torque_impulse(item["torque"])
			# Rétraction organique de la racine pendant qu'elle vole et roule au sol !
			var tw := create_tween()
			tw.tween_interval(randf_range(0.16, 0.30))
			tw.tween_method(func(val: float):
				if mat != null:
					mat.set_shader_parameter("fin", val)
			, 0.0, 1.0, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _spawn_shatter_particles(hit_dir: Vector3) -> void:
	# 1. Éclats sombres 3D (insect_chunk_1_mesh.tres)
	if ResourceLoader.exists(CHUNK_MESH_PATH):
		var splinters := GPUParticles3D.new()
		splinters.position = Vector3(0.0, 0.62, 0.0)
		splinters.amount = 18
		splinters.lifetime = 1.05
		splinters.one_shot = true
		splinters.explosiveness = 0.96
		splinters.visibility_range_end = 90.0
		splinters.visibility_range_end_margin = 15.0

		var smat := ParticleProcessMaterial.new()
		smat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		smat.emission_sphere_radius = 0.28
		smat.direction = (hit_dir + Vector3(0.0, 0.9, 0.0)).normalized()
		smat.spread = 75.0
		smat.initial_velocity_min = 3.8
		smat.initial_velocity_max = 8.5
		smat.angular_velocity_min = -360.0
		smat.angular_velocity_max = 360.0
		smat.gravity = Vector3(0.0, -14.0, 0.0)
		smat.scale_min = 0.14
		smat.scale_max = 0.32
		splinters.process_material = smat
		splinters.draw_pass_1 = load(CHUNK_MESH_PATH) as Mesh
		add_child(splinters)
		splinters.emitting = true

	# 2. Nuage ambré de sève et poussière d'écorce
	var sap_cloud := GPUParticles3D.new()
	sap_cloud.position = Vector3(0.0, 0.60, 0.0)
	sap_cloud.amount = 26
	sap_cloud.lifetime = 0.78
	sap_cloud.one_shot = true
	sap_cloud.explosiveness = 0.95
	sap_cloud.visibility_range_end = 90.0
	sap_cloud.visibility_range_end_margin = 15.0

	var cmat := ParticleProcessMaterial.new()
	cmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	cmat.emission_sphere_radius = 0.25
	cmat.direction = (hit_dir + Vector3(0.0, 0.6, 0.0)).normalized()
	cmat.spread = 80.0
	cmat.initial_velocity_min = 2.0
	cmat.initial_velocity_max = 5.5
	cmat.damping_min = 4.0
	cmat.damping_max = 6.5
	cmat.gravity = Vector3(0.0, -1.5, 0.0)
	cmat.scale_min = 1.0
	cmat.scale_max = 2.4

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.68, 0.22, 0.95),
		Color(0.55, 0.38, 0.12, 0.55),
		Color(0.18, 0.14, 0.06, 0.0)
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	cmat.color_ramp = ramp
	sap_cloud.process_material = cmat
	sap_cloud.draw_pass_1 = ProceduralForestMeshes.get_spore_quad_mesh(0.24)
	add_child(sap_cloud)
	sap_cloud.emitting = true

func _play_shatter_audio() -> void:
	if ResourceLoader.exists(SFX_SNAP_PATH):
		var s1 := AudioStreamPlayer3D.new()
		s1.stream = load(SFX_SNAP_PATH)
		s1.pitch_scale = randf_range(0.82, 1.02)
		s1.volume_db = -9.0
		s1.max_distance = 20.0
		add_child(s1)
		s1.play()
	if ResourceLoader.exists(SFX_CRUNCH_PATH):
		var s2 := AudioStreamPlayer3D.new()
		s2.stream = load(SFX_CRUNCH_PATH)
		s2.pitch_scale = randf_range(0.90, 1.12)
		s2.volume_db = -10.5
		s2.max_distance = 18.0
		add_child(s2)
		s2.play()
	if ResourceLoader.exists(SFX_SPLAT_PATH):
		var s3 := AudioStreamPlayer3D.new()
		s3.stream = load(SFX_SPLAT_PATH)
		s3.pitch_scale = randf_range(0.85, 1.05)
		s3.volume_db = -13.5
		s3.max_distance = 16.0
		add_child(s3)
		s3.play()

func _spawn_vital_orb(orb_type: int, orb_angle: float) -> void:
	var parent_target: Node = get_parent() if get_parent() != null else get_tree().current_scene
	if parent_target == null:
		return
	var orb: VitalOrb = VitalOrb.new()
	orb.scale = Vector3.ONE * 0.82
	var init_vel: Vector3 = Vector3(cos(orb_angle) * 2.2, 4.6, sin(orb_angle) * 2.2)
	parent_target.add_child(orb)
	orb.setup_orb(orb_type as VitalOrb.OrbType, global_position + Vector3(0.0, 0.72, 0.0), global_position.y, init_vel, health_orb_heal_percent)

func _spawn_item_bag_server(hit_dir: Vector3) -> void:
	if not ResourceLoader.exists(BAG_SCENE_PATH):
		return
	var bases: Array[EquipmentItem] = GameData.get_all_bases()
	var affixes: Array[AffixData] = GameData.get_all_affixes()
	if bases.is_empty():
		return

	var base_item: EquipmentItem = bases.pick_random()
	if base_item == null:
		return

	var ilvl := _resolve_cocoon_ilvl()
	var rarity := _roll_rarity()
	var generated_item: EquipmentItem = ItemGenerator.generate_equipment(base_item, ilvl, rarity, affixes)

	var bag_scn := load(BAG_SCENE_PATH) as PackedScene
	var bag := bag_scn.instantiate()
	bag.item_data = generated_item
	bag.item_amount = 1
	if "rarity" in bag:
		bag.rarity = generated_item.rarity

	var net_obj := _find_network_objects()
	if net_obj != null:
		net_obj.add_child(bag, true)
	elif get_tree().current_scene != null:
		get_tree().current_scene.add_child(bag, true)
	else:
		get_parent().add_child(bag, true)

	bag.global_position = global_position + Vector3(0.0, 0.95, 0.0)
	var out_dir := (-hit_dir + Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4))).normalized()
	if bag is RigidBody3D:
		bag.linear_velocity = out_dir * randf_range(1.8, 3.2) + Vector3.UP * randf_range(3.8, 5.2)
		bag.angular_velocity = Vector3(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))

func _resolve_cocoon_ilvl() -> int:
	return WorldLevelScaler.resolve_context_ilvl(self, global_position)

func _roll_rarity() -> ItemData.Rarity:
	var total := maxi(1, weight_common + weight_magic + weight_rare + weight_legendary)
	var r := randi_range(1, total)
	if r <= weight_common:
		return ItemData.Rarity.COMMON
	r -= weight_common
	if r <= weight_magic:
		return ItemData.Rarity.MAGIC
	r -= weight_magic
	if r <= weight_rare:
		return ItemData.Rarity.RARE
	return ItemData.Rarity.LEGENDARY

func _find_network_objects() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n.has_node("NetworkObjects"):
			return n.get_node("NetworkObjects")
		n = n.get_parent()
	var cur := get_tree().current_scene
	if cur != null and cur.has_node("NetworkObjects"):
		return cur.get_node("NetworkObjects")
	return null
