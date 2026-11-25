@tool
class_name TotemSculptor
extends Node3D

## Générateur et animateur 3D procédural (@tool) des 4 Totems Élémentaires de Fangorn.
## Direction artistique : pierre ancienne taillée, usée et craquelée (sans couleur élémentaire sur le mesh ;
## toute la couleur élémentaire provient des systèmes de particules de chaque scène).
## - "arcane"    : Piédestal octogonal à griffes de pierre + Boule géodésique en pierre craquelée à 80 facettes
## - "lightning" : Monolithe de pierre fendu en diapason cerclé de fer + Bipyramide de pierre taillée en lévitation
## - "ice"       : Autel cairn de pierre hérissé de 6 pointes monolithiques + Prisme de pierre & couronne d'éclats
## - "fire"      : Fût de pierre craquelée & brasero à 6 crocs de fer sombre + Noyau rocheux fracturé & anneaux de pierre

const VISUAL_VERSION := 2
const ANIM_CULL_DIST_SQ := 110.0 * 110.0
const CAM_CHECK_INTERVAL := 0.3
const TOTEM_VISIBILITY_END := 280.0
const TOTEM_VISIBILITY_MARGIN := 30.0

const SLATE_DIFF_PATH := "res://map/encounters/Boss_arena/gate_assets/moria_slate_diff.jpg"
const SLATE_NOR_PATH := "res://map/encounters/Boss_arena/gate_assets/moria_slate_nor.jpg"
const SLATE_ROUGH_PATH := "res://map/encounters/Boss_arena/gate_assets/moria_slate_rough.jpg"
const METAL_DIFF_PATH := "res://assets/texture/rusty_metal_textures/rusty_metal_04_diff_1k.jpg"
const METAL_NOR_PATH := "res://assets/texture/rusty_metal_textures/rusty_metal_04_nor_gl_1k.jpg"
const NOISE_TEX_PATH := "res://assets/LeLu's Noise Pack/T_Noise56ko.png"

@export_enum("arcane", "lightning", "ice", "fire") var element_style: String = "arcane":
	set(val):
		if element_style == val:
			return
		element_style = val
		if is_inside_tree():
			_rebuild_visuals()

@export_range(1, 2, 1) var arcane_orb_subdivisions: int = 1:
	set(val):
		var clamped := clampi(val, 1, 2)
		if arcane_orb_subdivisions == clamped:
			return
		arcane_orb_subdivisions = clamped
		_mesh_cache.erase("arcane_orb_1")
		_mesh_cache.erase("arcane_orb_2")
		if is_inside_tree() and element_style == "arcane":
			_rebuild_visuals()

static var _mesh_cache: Dictionary = {}
static var _stone_shader: Shader = null
static var _stone_mat_cache: Dictionary = {}
static var _metal_mat_cache: Dictionary = {}

var _visual_root: Node3D = null
var _floating_core: Node3D = null
var _secondary_orbit: Node3D = null
var _ring_outer: Node3D = null
var _ring_inner: Node3D = null
var _orbit_shards: Array[Node3D] = []

var _built_version: int = 0
var _anim_time: float = 0.0
var _power_level: float = 1.0
var _spin_boost: float = 1.0
var _is_activating_anim: bool = false
var _activation_elapsed: float = 0.0
var _is_spent: bool = false
var _is_blessing_ready: bool = false
var _core_base_y: float = 2.0
var _cam_check_timer: float = 0.0
var _is_far_from_camera: bool = false

func _ready() -> void:
	_rebuild_visuals()
	if not Engine.is_editor_hint():
		var parent: Node = get_parent()
		if parent != null:
			if parent.has_signal("totem_activated") and not parent.is_connected("totem_activated", _on_totem_activated):
				parent.connect("totem_activated", _on_totem_activated)
			if parent.get("is_activated") == true:
				_power_level = 0.0
				_spin_boost = 0.0
				_is_spent = true

func _on_totem_activated(_player: Node3D) -> void:
	if _is_activating_anim or _is_spent:
		return
	_is_activating_anim = true
	_activation_elapsed = 0.0

## Active ou éteint la lévitation douce post-combat signalant qu'une bénédiction peut être réclamée
func set_blessing_state(blessing_ready: bool) -> void:
	_is_activating_anim = false
	_is_spent = true
	_is_blessing_ready = blessing_ready

func _process(delta: float) -> void:
	if _built_version != VISUAL_VERSION or _visual_root == null or not is_instance_valid(_visual_root):
		_rebuild_visuals()
		if _visual_root == null:
			return

	_anim_time += delta

	# Séquence d'activation en jeu : emballement cinétique bref (0.28s) puis arrêt complet de la lévitation (1.15s)
	if _is_activating_anim and not Engine.is_editor_hint():
		_activation_elapsed += delta
		if _activation_elapsed <= 0.28:
			var t_up: float = _activation_elapsed / 0.28
			_spin_boost = lerpf(1.0, 3.6, t_up)
			_power_level = 1.0
		elif _activation_elapsed <= 1.43:
			var t_down: float = (_activation_elapsed - 0.28) / 1.15
			var smooth_d: float = t_down * t_down * (3.0 - 2.0 * t_down)
			_spin_boost = lerpf(3.6, 0.0, smooth_d)
			_power_level = lerpf(1.0, 0.0, smooth_d)
		else:
			_is_activating_anim = false
			_is_spent = true
			_spin_boost = 0.0
			_power_level = 0.0
	elif _is_spent and not Engine.is_editor_hint():
		var target_power: float = 0.55 if _is_blessing_ready else 0.0
		var target_spin: float = 0.45 if _is_blessing_ready else 0.0
		_power_level = move_toward(_power_level, target_power, delta * 0.85)
		_spin_boost = move_toward(_spin_boost, target_spin, delta * 0.75)

	if not Engine.is_editor_hint():
		_cam_check_timer -= delta
		if _cam_check_timer <= 0.0:
			_cam_check_timer = CAM_CHECK_INTERVAL
			var vp := get_viewport()
			var cam := vp.get_camera_3d() if vp != null else null
			if cam != null and is_instance_valid(cam):
				var was_far := _is_far_from_camera
				_is_far_from_camera = global_position.distance_squared_to(cam.global_position) > ANIM_CULL_DIST_SQ
				if was_far and not _is_far_from_camera:
					# Resynchronisation immédiate à l'entrée dans le rayon de 110m
					pass
			else:
				_is_far_from_camera = false
		if _is_far_from_camera:
			return

	var sink_offset := lerpf(0.0, -0.26, clampf(1.0 - _power_level, 0.0, 1.0)) if (_is_activating_anim or _is_spent) else 0.0
	var bob_amp := 0.085 * clampf(_power_level, 0.0, 1.0)

	match element_style:
		"arcane":
			if _floating_core != null:
				_floating_core.position.y = _core_base_y + sink_offset + sin(_anim_time * 1.85) * bob_amp
				if _spin_boost > 0.001:
					_floating_core.rotate_y(delta * 0.82 * _spin_boost)
					_floating_core.rotation.x = sin(_anim_time * 0.95) * 0.22 * _power_level
					_floating_core.rotation.z = cos(_anim_time * 0.75) * 0.18 * _power_level

		"lightning":
			if _floating_core != null:
				var jitter_y := sin(_anim_time * 19.0) * 0.010 * _power_level
				_floating_core.position.y = _core_base_y + sink_offset + sin(_anim_time * 2.8) * (bob_amp * 0.7) + jitter_y
				if _spin_boost > 0.001:
					_floating_core.rotate_y(delta * 1.85 * _spin_boost)
					_floating_core.rotation.z = sin(_anim_time * 3.4) * 0.11 * _power_level

		"ice":
			if _floating_core != null:
				_floating_core.position.y = _core_base_y + sink_offset + sin(_anim_time * 1.45) * bob_amp
				if _spin_boost > 0.001:
					_floating_core.rotate_y(delta * 0.45 * _spin_boost)
					_floating_core.rotation.z = sin(_anim_time * 0.8) * 0.06 * _power_level
			if _secondary_orbit != null:
				_secondary_orbit.position.y = _core_base_y + sink_offset * 0.85 + sin(_anim_time * 1.45 - 0.5) * (bob_amp * 0.6)
				if _spin_boost > 0.001:
					_secondary_orbit.rotate_y(-delta * 0.72 * _spin_boost)
				for idx in range(_orbit_shards.size()):
					var sh := _orbit_shards[idx]
					if sh != null:
						sh.position.y = sin(_anim_time * 2.2 + float(idx) * 1.25) * 0.07 * _power_level
						if _spin_boost > 0.001:
							sh.rotate_y(delta * 1.3 * _spin_boost)

		"fire":
			if _floating_core != null:
				_floating_core.position.y = _core_base_y + sink_offset + sin(_anim_time * 2.1) * (bob_amp * 0.85)
				if _spin_boost > 0.001:
					_floating_core.rotate_y(delta * 0.68 * _spin_boost)
					_floating_core.rotation.x = sin(_anim_time * 1.3) * 0.16 * _power_level
			if _ring_outer != null:
				_ring_outer.position.y = _core_base_y + sink_offset
				if _spin_boost > 0.001:
					_ring_outer.rotate_y(-delta * 0.95 * _spin_boost)
					_ring_outer.rotate_x(delta * 0.55 * _spin_boost)
			if _ring_inner != null:
				_ring_inner.position.y = _core_base_y + sink_offset
				if _spin_boost > 0.001:
					_ring_inner.rotate_z(delta * 1.25 * _spin_boost)
					_ring_inner.rotate_y(delta * 0.65 * _spin_boost)

# =========================================================================
# CONSTRUCTION PAR ÉLÉMENT (100% Pierre Ancienne Craquelée & Fer Terne)
# =========================================================================
func _rebuild_visuals() -> void:
	for child in get_children():
		if child == _visual_root or String(child.name).begins_with("_GeneratedTotemMesh"):
			remove_child(child)
			child.queue_free()

	_floating_core = null
	_secondary_orbit = null
	_ring_outer = null
	_ring_inner = null
	_orbit_shards.clear()

	_visual_root = Node3D.new()
	_visual_root.name = "_GeneratedTotemMesh"
	add_child(_visual_root)
	_built_version = VISUAL_VERSION

	match element_style:
		"arcane":
			_build_arcane_totem()
		"lightning":
			_build_lightning_totem()
		"ice":
			_build_ice_totem()
		"fire":
			_build_fire_totem()

# -------------------------------------------------------------------------
# 1. TOTEM ARCANIQUE : Piédestal octogonal + Sphère de pierre 80 facettes
# -------------------------------------------------------------------------
func _build_arcane_totem() -> void:
	_core_base_y = 2.02

	var ped_stone_mat := _get_stone_material(Color(0.95, 0.94, 0.92), 0.72, 0.90, 0.30, true)
	var orb_stone_mat := _get_stone_material(Color(1.03, 1.02, 0.99), 1.05, 0.94, 0.42, false)
	var collar_mat := _get_metal_material(Color(0.36, 0.35, 0.34), 0.68, 0.58)

	# Piédestal octogonal taillé à degrés + fût cintré + vasque supérieure
	var ped_mesh := _get_or_build_mesh("arcane_pedestal", func() -> ArrayMesh:
		var r := PackedFloat32Array([0.84, 0.80, 0.66, 0.62, 0.44, 0.37, 0.39, 0.56, 0.64, 0.48])
		var y := PackedFloat32Array([-0.20, 0.10, 0.16, 0.30, 0.38, 0.78, 1.08, 1.24, 1.36, 1.26])
		return _build_polygonal_lathe(r, y, 8, 0.0, 0.9)
	)
	_spawn_mesh(_visual_root, "ArcanePedestal", ped_mesh, ped_stone_mat)

	# 4 griffes de pierre arquées encadrant la sphère sans la toucher
	var claw_mesh := _get_or_build_mesh("arcane_claw", func() -> ArrayMesh:
		var pts := PackedVector3Array([
			Vector3(0.46, 1.22, 0.0),
			Vector3(0.58, 1.36, 0.0),
			Vector3(0.62, 1.54, 0.0),
			Vector3(0.52, 1.72, 0.0)
		])
		var widths := PackedFloat32Array([0.11, 0.095, 0.072, 0.025])
		return _build_tapered_horn_mesh(pts, widths, 4, 1.1)
	)
	for i in range(4):
		var claw := _spawn_mesh(_visual_root, "PedestalClaw_%d" % i, claw_mesh, ped_stone_mat)
		claw.rotation.y = (TAU / 4.0) * float(i) + (PI * 0.25)

	# Bague de fer ancien terne autour du col du piédestal
	var collar_mesh := _get_or_build_mesh("arcane_collar", func() -> ArrayMesh:
		var r := PackedFloat32Array([0.41, 0.45, 0.45, 0.41])
		var y := PackedFloat32Array([1.02, 1.05, 1.13, 1.16])
		return _build_polygonal_lathe(r, y, 8, 0.0, 1.2)
	)
	_spawn_mesh(_visual_root, "MetalCollar", collar_mesh, collar_mat)

	# Racines sylvestres naturelles à la base
	_spawn_base_roots(_visual_root, 4, 0.78, 0.46, Color(0.50, 0.43, 0.35, 1.0), 11)

	# LA BOULE À FACETTES EN PIERRE CRAQUELÉE (Icosphère géodésique 80 faces à subdivisions=1)
	var orb_key := "arcane_orb_%d" % arcane_orb_subdivisions
	var orb_mesh := _get_or_build_mesh(orb_key, func() -> ArrayMesh:
		return _build_faceted_icosphere(0.42, arcane_orb_subdivisions)
	)

	_floating_core = Node3D.new()
	_floating_core.name = "FloatingArcanePolyhedron"
	_floating_core.position = Vector3(0.0, _core_base_y, 0.0)
	_visual_root.add_child(_floating_core)
	_spawn_mesh(_floating_core, "FacetedSphereMesh", orb_mesh, orb_stone_mat)

# -------------------------------------------------------------------------
# 2. TOTEM DE FOUDRE : Diapason monolithique de pierre + Bipyramide rocheuse
# -------------------------------------------------------------------------
func _build_lightning_totem() -> void:
	_core_base_y = 1.78

	var mono_stone_mat := _get_stone_material(Color(0.92, 0.93, 0.93), 0.70, 0.92, 0.32, true)
	var core_stone_mat := _get_stone_material(Color(1.02, 1.02, 1.00), 1.10, 0.94, 0.42, false)
	var iron_mat := _get_metal_material(Color(0.34, 0.34, 0.35), 0.64, 0.62)

	# Socle hexagonal trapu en pierre fendue
	var base_mesh := _get_or_build_mesh("lightning_base", func() -> ArrayMesh:
		var r := PackedFloat32Array([0.88, 0.82, 0.68, 0.60, 0.54])
		var y := PackedFloat32Array([-0.20, 0.12, 0.20, 0.42, 0.52])
		return _build_polygonal_lathe(r, y, 6, 0.0, 1.0)
	)
	_spawn_mesh(_visual_root, "StormBase", base_mesh, mono_stone_mat)

	# Deux hautes lames monolithiques asymétriques formant un diapason de pierre
	var left_prong_mesh := _get_or_build_mesh("lightning_prong_l", func() -> ArrayMesh:
		var pts := PackedVector3Array([
			Vector3(-0.28, 0.40, 0.0),
			Vector3(-0.46, 1.05, 0.02),
			Vector3(-0.52, 1.75, -0.02),
			Vector3(-0.38, 2.28, 0.0),
			Vector3(-0.26, 2.48, 0.0)
		])
		var widths := PackedFloat32Array([0.23, 0.20, 0.17, 0.12, 0.045])
		return _build_tapered_horn_mesh(pts, widths, 5, 0.8)
	)
	var right_prong_mesh := _get_or_build_mesh("lightning_prong_r", func() -> ArrayMesh:
		var pts := PackedVector3Array([
			Vector3(0.28, 0.40, 0.0),
			Vector3(0.47, 1.12, -0.02),
			Vector3(0.54, 1.82, 0.02),
			Vector3(0.39, 2.42, 0.0),
			Vector3(0.25, 2.66, 0.0)
		])
		var widths := PackedFloat32Array([0.24, 0.21, 0.175, 0.125, 0.045])
		return _build_tapered_horn_mesh(pts, widths, 5, 0.8)
	)
	_spawn_mesh(_visual_root, "LeftStormProng", left_prong_mesh, mono_stone_mat)
	_spawn_mesh(_visual_root, "RightStormProng", right_prong_mesh, mono_stone_mat)

	# Anneaux et pointes en fer forgé sombre (neutres, sans teinte bleue)
	var band_mesh := _get_or_build_mesh("lightning_band", func() -> ArrayMesh:
		var r := PackedFloat32Array([0.23, 0.25, 0.25, 0.23])
		var y := PackedFloat32Array([-0.06, -0.04, 0.04, 0.06])
		return _build_polygonal_lathe(r, y, 6, 0.0, 1.0)
	)
	var b1 := _spawn_mesh(_visual_root, "IronBandL", band_mesh, iron_mat)
	b1.position = Vector3(-0.45, 1.05, 0.0)
	b1.rotation.z = 0.14
	var b2 := _spawn_mesh(_visual_root, "IronBandR", band_mesh, iron_mat)
	b2.position = Vector3(0.46, 1.12, 0.0)
	b2.rotation.z = -0.14

	var rod_mesh := _get_or_build_mesh("lightning_rod_spike", func() -> ArrayMesh:
		var r := PackedFloat32Array([0.055, 0.085, 0.035, 0.004])
		var y := PackedFloat32Array([0.0, 0.06, 0.22, 0.42])
		return _build_polygonal_lathe(r, y, 4, 0.0, 1.0)
	)
	var rod_l := _spawn_mesh(_visual_root, "RodSpikeL", rod_mesh, iron_mat)
	rod_l.position = Vector3(-0.27, 2.42, 0.0)
	rod_l.rotation.z = -0.18
	var rod_r := _spawn_mesh(_visual_root, "RodSpikeR", rod_mesh, iron_mat)
	rod_r.position = Vector3(0.26, 2.60, 0.0)
	rod_r.rotation.z = 0.18

	_spawn_base_roots(_visual_root, 5, 0.82, 0.42, Color(0.48, 0.42, 0.34, 1.0), 23)

	# Bipyramide de pierre craquelée (16 facettes) en lévitation entre les deux cornes
	var bipyramid_mesh := _get_or_build_mesh("lightning_bipyramid", func() -> ArrayMesh:
		return _build_faceted_bipyramid(0.24, 0.68, 8)
	)

	_floating_core = Node3D.new()
	_floating_core.name = "FloatingStormStone"
	_floating_core.position = Vector3(0.0, _core_base_y, 0.0)
	_visual_root.add_child(_floating_core)
	_spawn_mesh(_floating_core, "StormStoneMesh", bipyramid_mesh, core_stone_mat)

# -------------------------------------------------------------------------
# 3. TOTEM DE GLACE : Autel cairn à pointes de pierre + Prisme & Couronne
# -------------------------------------------------------------------------
func _build_ice_totem() -> void:
	_core_base_y = 1.98

	var altar_stone_mat := _get_stone_material(Color(0.97, 0.97, 0.95), 0.72, 0.88, 0.32, true)
	var prism_stone_mat := _get_stone_material(Color(1.05, 1.04, 1.02), 1.05, 0.92, 0.42, false)

	# Autel cairn hexagonal en pierre ancienne craquelée
	var altar_mesh := _get_or_build_mesh("ice_altar", func() -> ArrayMesh:
		var r := PackedFloat32Array([0.92, 0.86, 0.72, 0.66, 0.52, 0.60, 0.42])
		var y := PackedFloat32Array([-0.20, 0.14, 0.22, 0.58, 0.92, 1.08, 1.02])
		return _build_polygonal_lathe(r, y, 6, 0.05, 0.9)
	)
	_spawn_mesh(_visual_root, "StoneCairnAltar", altar_mesh, altar_stone_mat)

	# 6 aiguilles monolithiques de pierre taillée jaillissant en couronne oblique
	var spike_mesh := _get_or_build_mesh("ice_base_spike", func() -> ArrayMesh:
		return _build_hex_crystal_shard(0.115, 0.78, 0.14)
	)
	for i in range(6):
		var ang := (TAU / 6.0) * float(i) + 0.25
		var rad := 0.56 if (i % 2 == 0) else 0.46
		var sp := _spawn_mesh(_visual_root, "StoneSpire_%d" % i, spike_mesh, prism_stone_mat)
		sp.position = Vector3(cos(ang) * rad, 0.52 if (i % 2 == 0) else 0.76, sin(ang) * rad)
		var sc := 1.05 if (i % 2 == 0) else 0.82
		sp.scale = Vector3.ONE * sc
		sp.rotation.y = -ang + PI * 0.5
		sp.rotation.x = 0.36 if (i % 2 == 0) else 0.26

	_spawn_base_roots(_visual_root, 4, 0.84, 0.44, Color(0.50, 0.44, 0.36, 1.0), 37)

	# Grand prisme hexagonal de pierre craquelée à double pointe flottant au centre
	var master_shard_mesh := _get_or_build_mesh("ice_master_prism", func() -> ArrayMesh:
		return _build_hex_crystal_prism(0.26, 1.04)
	)
	_floating_core = Node3D.new()
	_floating_core.name = "FloatingMasterStonePrism"
	_floating_core.position = Vector3(0.0, _core_base_y, 0.0)
	_visual_root.add_child(_floating_core)
	_spawn_mesh(_floating_core, "MasterStonePrismMesh", master_shard_mesh, prism_stone_mat)

	# Couronne de 5 éclats de pierre taillée en orbite autour du prisme central
	var sat_mesh := _get_or_build_mesh("ice_orbit_shard", func() -> ArrayMesh:
		return _build_hex_crystal_prism(0.075, 0.34)
	)
	_secondary_orbit = Node3D.new()
	_secondary_orbit.name = "OrbitingStoneCrown"
	_secondary_orbit.position = Vector3(0.0, _core_base_y, 0.0)
	_secondary_orbit.rotation.x = 0.16
	_visual_root.add_child(_secondary_orbit)

	for i in range(5):
		var a := (TAU / 5.0) * float(i)
		var pivot := Node3D.new()
		pivot.name = "OrbitShard_%d" % i
		pivot.position = Vector3(cos(a) * 0.58, 0.0, sin(a) * 0.58)
		pivot.rotation.z = 0.22
		pivot.rotation.y = -a
		_secondary_orbit.add_child(pivot)
		_spawn_mesh(pivot, "ShardMesh", sat_mesh, prism_stone_mat)
		_orbit_shards.append(pivot)

# -------------------------------------------------------------------------
# 4. TOTEM DE FEU : Brasero de pierre craquelée & fer + Noyau & Anneaux
# -------------------------------------------------------------------------
func _build_fire_totem() -> void:
	_core_base_y = 1.96

	var pillar_stone_mat := _get_stone_material(Color(0.88, 0.87, 0.85), 0.72, 0.94, 0.30, true)
	var ash_stone_mat := _get_stone_material(Color(0.68, 0.67, 0.65), 1.35, 0.96, 0.20, false)
	var core_stone_mat := _get_stone_material(Color(0.96, 0.95, 0.92), 1.05, 0.95, 0.38, false)
	var ring_stone_mat := _get_stone_material(Color(0.90, 0.89, 0.87), 1.25, 0.92, 0.40, false)
	var forged_iron_mat := _get_metal_material(Color(0.30, 0.29, 0.28), 0.66, 0.64)

	# Fût massif en pierre sombre craquelée
	var pillar_mesh := _get_or_build_mesh("fire_pillar", func() -> ArrayMesh:
		var r := PackedFloat32Array([0.90, 0.84, 0.66, 0.50, 0.46, 0.68, 0.76])
		var y := PackedFloat32Array([-0.20, 0.12, 0.22, 0.56, 0.92, 1.16, 1.28])
		return _build_polygonal_lathe(r, y, 6, 0.0, 0.95)
	)
	_spawn_mesh(_visual_root, "CrackedStonePillar", pillar_mesh, pillar_stone_mat)

	# Vasque de fer forgé terne + 6 grands crocs recourbés vers le ciel
	var bowl_mesh := _get_or_build_mesh("fire_iron_bowl", func() -> ArrayMesh:
		var r := PackedFloat32Array([0.52, 0.78, 0.84, 0.72, 0.58])
		var y := PackedFloat32Array([1.08, 1.22, 1.38, 1.38, 1.24])
		return _build_polygonal_lathe(r, y, 6, 0.0, 1.2)
	)
	_spawn_mesh(_visual_root, "IronBrazierBowl", bowl_mesh, forged_iron_mat)

	var fang_mesh := _get_or_build_mesh("fire_iron_fang", func() -> ArrayMesh:
		var pts := PackedVector3Array([
			Vector3(0.72, 1.20, 0.0),
			Vector3(0.84, 1.42, 0.0),
			Vector3(0.80, 1.66, 0.0),
			Vector3(0.66, 1.84, 0.0)
		])
		var widths := PackedFloat32Array([0.095, 0.075, 0.050, 0.015])
		return _build_tapered_horn_mesh(pts, widths, 4, 1.2)
	)
	for i in range(6):
		var fang := _spawn_mesh(_visual_root, "BrazierFang_%d" % i, fang_mesh, forged_iron_mat)
		fang.rotation.y = (TAU / 6.0) * float(i)

	# Lit de pierre calcinée et fendillée au creux de la vasque (sans lueur artificielle)
	var ash_bed_mesh := _get_or_build_mesh("fire_ember_bed", func() -> ArrayMesh:
		var r := PackedFloat32Array([0.001, 0.28, 0.52, 0.64])
		var y := PackedFloat32Array([1.42, 1.39, 1.33, 1.25])
		return _build_polygonal_lathe(r, y, 10, 0.12, 1.5)
	)
	_spawn_mesh(_visual_root, "CrackedAshStoneBed", ash_bed_mesh, ash_stone_mat)

	_spawn_base_roots(_visual_root, 5, 0.84, 0.44, Color(0.44, 0.38, 0.31, 1.0), 51)

	# Noyau rocheux fracturé flottant au-dessus du brasero
	var rock_core_mesh := _get_or_build_mesh("fire_magma_core", func() -> ArrayMesh:
		return _build_fractured_magma_core(0.31)
	)
	_floating_core = Node3D.new()
	_floating_core.name = "FloatingFracturedStoneCore"
	_floating_core.position = Vector3(0.0, _core_base_y, 0.0)
	_visual_root.add_child(_floating_core)
	_spawn_mesh(_floating_core, "FracturedStoneCoreMesh", rock_core_mesh, core_stone_mat)

	# 2 anneaux gyroscopiques en pierre taillée et craquelée autour du noyau
	var ring_outer_mesh := _get_or_build_mesh("fire_gyro_outer", func() -> ArrayMesh:
		return _build_faceted_ring_mesh(0.50, 0.036, 12)
	)
	var ring_inner_mesh := _get_or_build_mesh("fire_gyro_inner", func() -> ArrayMesh:
		return _build_faceted_ring_mesh(0.41, 0.030, 10)
	)

	_ring_outer = Node3D.new()
	_ring_outer.name = "StoneGyroRingOuter"
	_ring_outer.position = Vector3(0.0, _core_base_y, 0.0)
	_ring_outer.rotation = Vector3(0.45, 0.0, 0.25)
	_visual_root.add_child(_ring_outer)
	_spawn_mesh(_ring_outer, "OuterRingMesh", ring_outer_mesh, ring_stone_mat)

	_ring_inner = Node3D.new()
	_ring_inner.name = "StoneGyroRingInner"
	_ring_inner.position = Vector3(0.0, _core_base_y, 0.0)
	_ring_inner.rotation = Vector3(-0.35, 0.4, -0.5)
	_visual_root.add_child(_ring_inner)
	_spawn_mesh(_ring_inner, "InnerRingMesh", ring_inner_mesh, ring_stone_mat)

# =========================================================================
# HELPERS GÉOMÉTRIQUES PROCÉDURAUX (100% Flat-Shaded & Normales Sortantes)
# =========================================================================
static func _get_or_build_mesh(key: String, builder: Callable) -> ArrayMesh:
	if _mesh_cache.has(key) and _mesh_cache[key] != null:
		return _mesh_cache[key] as ArrayMesh
	var m: ArrayMesh = builder.call()
	_mesh_cache[key] = m
	return m

func _spawn_mesh(parent: Node3D, node_name: String, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	if not Engine.is_editor_hint():
		mi.visibility_range_end = TOTEM_VISIBILITY_END
		mi.visibility_range_end_margin = TOTEM_VISIBILITY_MARGIN
	parent.add_child(mi)
	return mi

func _spawn_base_roots(parent: Node3D, count: int, outer_r: float, climb_h: float, tint: Color, seed_base: int) -> void:
	var root_mat := ProceduralForestMeshes.get_base_root_material(tint, 0.04)
	for i in range(count):
		var key := "totem_root_%d_%d" % [seed_base, i]
		var built: Dictionary
		if _mesh_cache.has(key):
			built = _mesh_cache[key]
		else:
			var base_a := (TAU / float(count)) * float(i) + 0.35
			var pts := PackedVector3Array()
			var steps := 10
			for s in range(steps):
				var t := float(s) / float(steps - 1)
				var r := lerpf(outer_r + 0.32, outer_r * 0.62, pow(t, 0.8))
				var y := lerpf(-0.14, climb_h, pow(t, 0.72)) - sin(t * PI) * 0.04
				var a := base_a + t * 0.42 * (1.0 if i % 2 == 0 else -1.0)
				pts.append(Vector3(cos(a) * r, y, sin(a) * r))
			built = ProceduralForestMeshes.build_centered_root_tube(pts, 0.085, 7, 0.015, seed_base + i)
			_mesh_cache[key] = built

		var mi := MeshInstance3D.new()
		mi.name = "AnchorRoot_%d" % i
		mi.mesh = built["mesh"]
		mi.position = built["center"]
		mi.material_override = root_mat
		if not Engine.is_editor_hint():
			mi.visibility_range_end = TOTEM_VISIBILITY_END
			mi.visibility_range_end_margin = TOTEM_VISIBILITY_MARGIN
		parent.add_child(mi)

## Icosphère géodésique exacte à facettes triangulaires plates (subdivisions=1 -> 80 facettes nettes !)
static func _build_faceted_icosphere(radius: float, subdivisions: int) -> ArrayMesh:
	var phi := (1.0 + sqrt(5.0)) * 0.5
	var raw_verts := [
		Vector3(-1.0,  phi, 0.0).normalized(),
		Vector3( 1.0,  phi, 0.0).normalized(),
		Vector3(-1.0, -phi, 0.0).normalized(),
		Vector3( 1.0, -phi, 0.0).normalized(),
		Vector3(0.0, -1.0,  phi).normalized(),
		Vector3(0.0,  1.0,  phi).normalized(),
		Vector3(0.0, -1.0, -phi).normalized(),
		Vector3(0.0,  1.0, -phi).normalized(),
		Vector3( phi, 0.0, -1.0).normalized(),
		Vector3( phi, 0.0,  1.0).normalized(),
		Vector3(-phi, 0.0, -1.0).normalized(),
		Vector3(-phi, 0.0,  1.0).normalized()
	]

	var faces := [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]
	]

	var tris: Array = []
	for f in faces:
		tris.append([raw_verts[f[0]], raw_verts[f[1]], raw_verts[f[2]]])

	for _sub in range(subdivisions):
		var next_tris: Array = []
		for tri in tris:
			var a: Vector3 = tri[0]
			var b: Vector3 = tri[1]
			var c: Vector3 = tri[2]
			var ab := ((a + b) * 0.5).normalized()
			var bc := ((b + c) * 0.5).normalized()
			var ca := ((c + a) * 0.5).normalized()
			next_tris.append([a, ab, ca])
			next_tris.append([b, bc, ab])
			next_tris.append([c, ca, bc])
			next_tris.append([ab, bc, ca])
		tris = next_tris

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for idx in range(tris.size()):
		var t: Array = tris[idx]
		var va: Vector3 = (t[0] as Vector3) * radius
		var vb: Vector3 = (t[1] as Vector3) * radius
		var vc: Vector3 = (t[2] as Vector3) * radius
		var center_dir := (va + vb + vc).normalized()
		_add_faceted_tri(st, va, vb, vc, center_dir, float(idx) + 1.0, 2.2)

	st.generate_tangents()
	return st.commit()

## Bipyramide à facettes (losange 3D de pierre taillée pour le Totem de Foudre)
static func _build_faceted_bipyramid(radius: float, height: float, sides: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(0.0, height * 0.5, 0.0)
	var bot := Vector3(0.0, -height * 0.5, 0.0)

	for i in range(sides):
		var a0 := (TAU / float(sides)) * float(i)
		var a1 := (TAU / float(sides)) * float(i + 1)
		var r0 := radius * (1.0 if i % 2 == 0 else 0.88)
		var r1 := radius * (1.0 if (i + 1) % 2 == 0 else 0.88)
		var p0 := Vector3(cos(a0) * r0, 0.03 * sin(a0 * 2.0), sin(a0) * r0)
		var p1 := Vector3(cos(a1) * r1, 0.03 * sin(a1 * 2.0), sin(a1) * r1)

		_add_faceted_tri(st, p0, p1, top, (p0 + p1 + top).normalized(), float(i * 2 + 1), 2.5)
		_add_faceted_tri(st, p1, p0, bot, (p0 + p1 + bot).normalized(), float(i * 2 + 2), 2.5)

	st.generate_tangents()
	return st.commit()

## Prisme hexagonal de pierre à double pointe asymétrique (Glace)
static func _build_hex_crystal_prism(radius: float, total_height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 6
	var body_h := total_height * 0.26
	var top_pt := Vector3(0.02 * radius, total_height * 0.54, -0.02 * radius)
	var bot_pt := Vector3(-0.02 * radius, -total_height * 0.46, 0.02 * radius)

	var ring_top: Array[Vector3] = []
	var ring_bot: Array[Vector3] = []
	for i in range(sides):
		var a := (TAU / float(sides)) * float(i)
		var asym := 1.0 + 0.10 * sin(float(i) * 2.1)
		var r := radius * asym
		ring_top.append(Vector3(cos(a) * r, body_h + 0.03 * cos(float(i) * 1.7), sin(a) * r))
		ring_bot.append(Vector3(cos(a) * r * 0.92, -body_h + 0.02 * sin(float(i) * 2.3), sin(a) * r * 0.92))

	for i in range(sides):
		var ni := (i + 1) % sides
		var b0 := ring_bot[i]
		var b1 := ring_bot[ni]
		var t0 := ring_top[i]
		var t1 := ring_top[ni]
		var side_out := Vector3((b0.x + b1.x) * 0.5, 0.0, (b0.z + b1.z) * 0.5).normalized()

		_add_faceted_quad(st, b0, b1, t1, t0, side_out, float(i + 10), 2.0)
		_add_faceted_tri(st, t0, t1, top_pt, (t0 + t1 + top_pt).normalized(), float(i + 30), 2.2)
		_add_faceted_tri(st, b1, b0, bot_pt, (b0 + b1 + bot_pt).normalized(), float(i + 50), 2.2)

	st.generate_tangents()
	return st.commit()

## Pointe monolithique hexagonale biseautée ancrée à la base
static func _build_hex_crystal_shard(radius: float, height: float, lean: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 6
	var shoulder_y := height * 0.64
	var tip := Vector3(lean, height, 0.0)

	var ring_bot: Array[Vector3] = []
	var ring_mid: Array[Vector3] = []
	for i in range(sides):
		var a := (TAU / float(sides)) * float(i)
		var r := radius * (1.0 + 0.12 * cos(float(i) * 2.0))
		ring_bot.append(Vector3(cos(a) * r, -0.08, sin(a) * r))
		ring_mid.append(Vector3(lean * 0.6 + cos(a) * r * 0.72, shoulder_y + 0.04 * sin(float(i)), sin(a) * r * 0.72))

	for i in range(sides):
		var ni := (i + 1) % sides
		var out_dir := Vector3(cos((TAU / 6.0) * (float(i) + 0.5)), 0.15, sin((TAU / 6.0) * (float(i) + 0.5))).normalized()
		_add_faceted_quad(st, ring_bot[i], ring_bot[ni], ring_mid[ni], ring_mid[i], out_dir, float(i + 1), 2.0)
		_add_faceted_tri(st, ring_mid[i], ring_mid[ni], tip, (ring_mid[i] + ring_mid[ni] - Vector3(0.0, shoulder_y * 0.5, 0.0)).normalized(), float(i + 20), 2.2)

	st.generate_tangents()
	return st.commit()

## Noyau rocheux fracturé (polyèdre de pierre irrégulier)
static func _build_fractured_magma_core(radius: float) -> ArrayMesh:
	var base_ico := _build_faceted_icosphere(1.0, 1)
	var mdt_arrays := base_ico.surface_get_arrays(0)
	var src_verts: PackedVector3Array = mdt_arrays[Mesh.ARRAY_VERTEX]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri_count := src_verts.size() / 3
	for t_idx in range(tri_count):
		var pts: Array[Vector3] = []
		for k in range(3):
			var v := src_verts[t_idx * 3 + k].normalized()
			var crag := 1.0 + 0.16 * sin(v.x * 5.2 + v.y * 3.7) + 0.10 * cos(v.z * 6.1 - v.y * 4.0)
			v.y *= 1.18
			pts.append(v * (radius * crag))
		var out_d := (pts[0] + pts[1] + pts[2]).normalized()
		_add_faceted_tri(st, pts[0], pts[1], pts[2], out_d, float(t_idx) + 7.0, 2.4)

	st.generate_tangents()
	return st.commit()

## Anneau polygonal biseauté en pierre taillée (Totem de Feu)
static func _build_faceted_ring_mesh(ring_radius: float, tube_radius: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tube_sides := 4
	var rings: Array = []

	for i in range(segments):
		var a := (TAU / float(segments)) * float(i)
		var center := Vector3(cos(a) * ring_radius, 0.0, sin(a) * ring_radius)
		var radial := Vector3(cos(a), 0.0, sin(a))
		var loop_pts: Array[Vector3] = []
		for j in range(tube_sides):
			var b := (TAU / float(tube_sides)) * float(j) + PI * 0.25
			var offset := radial * (cos(b) * tube_radius) + Vector3.UP * (sin(b) * tube_radius * 1.25)
			loop_pts.append(center + offset)
		rings.append({"center": center, "pts": loop_pts})

	for i in range(segments):
		var ni := (i + 1) % segments
		var r0: Array = rings[i]["pts"]
		var r1: Array = rings[ni]["pts"]
		var seg_mid: Vector3 = ((rings[i]["center"] as Vector3) + (rings[ni]["center"] as Vector3)) * 0.5
		for j in range(tube_sides):
			var nj := (j + 1) % tube_sides
			var face_mid: Vector3 = (r0[j] + r1[j] + r1[nj] + r0[nj]) * 0.25
			var out_d := (face_mid - seg_mid).normalized()
			_add_faceted_quad(st, r0[j], r1[j], r1[nj], r0[nj], out_d, float(i * 4 + j), 3.0)

	st.generate_tangents()
	return st.commit()

## Révolution polygonale à facettes nettes (piédestaux, autels, vasques, colliers)
static func _build_polygonal_lathe(radii: PackedFloat32Array, heights: PackedFloat32Array, sides: int, twist_step: float, uv_scale: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_rings := mini(radii.size(), heights.size())
	if n_rings < 2:
		return ArrayMesh.new()

	var rings: Array = []
	for i in range(n_rings):
		var r := maxf(0.001, radii[i])
		var y := heights[i]
		var twist := float(i) * twist_step
		var pts: Array[Vector3] = []
		for j in range(sides):
			var a := (TAU / float(sides)) * float(j) + twist
			pts.append(Vector3(cos(a) * r, y, sin(a) * r))
		rings.append(pts)

	for i in range(n_rings - 1):
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		var dy := heights[i + 1] - heights[i]
		var dr := radii[i + 1] - radii[i]
		for j in range(sides):
			var nj := (j + 1) % sides
			var mid: Vector3 = (r0[j] + r0[nj] + r1[nj] + r1[j]) * 0.25
			var horiz := Vector3(mid.x, 0.0, mid.z)
			if horiz.length_squared() < 1e-6:
				horiz = Vector3.RIGHT
			else:
				horiz = horiz.normalized()
			var slope_out := (horiz * absf(dy) + Vector3.UP * (-dr if dy >= 0.0 else absf(dr))).normalized()
			if slope_out.length_squared() < 1e-4:
				slope_out = horiz
			_add_faceted_quad(st, r0[j], r0[nj], r1[nj], r1[j], slope_out, float(i * sides + j), uv_scale)

	var top_ring: Array = rings[n_rings - 1]
	var top_center := Vector3(0.0, heights[n_rings - 1], 0.0)
	if radii[n_rings - 1] > 0.005:
		for j in range(sides):
			var nj := (j + 1) % sides
			_add_faceted_tri(st, top_ring[j], top_ring[nj], top_center, Vector3.UP, float(j + 200), uv_scale)

	var bot_ring: Array = rings[0]
	var bot_center := Vector3(0.0, heights[0], 0.0)
	if radii[0] > 0.005:
		for j in range(sides):
			var nj := (j + 1) % sides
			_add_faceted_tri(st, bot_ring[nj], bot_ring[j], bot_center, Vector3.DOWN, float(j + 300), uv_scale)

	st.generate_tangents()
	return st.commit()

## Corne / griffe / lame monolithique effilée le long d'une courbe 3D
static func _build_tapered_horn_mesh(spine: PackedVector3Array, widths: PackedFloat32Array, sides: int, uv_scale: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := mini(spine.size(), widths.size())
	if n < 2:
		return ArrayMesh.new()

	var rings: Array = []
	var prev_ref := Vector3.FORWARD
	for i in range(n):
		var tang: Vector3
		if i == 0:
			tang = (spine[1] - spine[0]).normalized()
		elif i == n - 1:
			tang = (spine[n - 1] - spine[n - 2]).normalized()
		else:
			tang = (spine[i + 1] - spine[i - 1]).normalized()
		if tang.length_squared() < 1e-5:
			tang = Vector3.UP

		var ref := prev_ref - tang * prev_ref.dot(tang)
		if ref.length_squared() < 1e-4:
			var fb := Vector3.RIGHT if absf(tang.dot(Vector3.FORWARD)) > 0.9 else Vector3.FORWARD
			ref = (fb - tang * fb.dot(tang)).normalized()
		else:
			ref = ref.normalized()
		prev_ref = ref
		var binorm := tang.cross(ref).normalized()

		var w := maxf(0.004, widths[i])
		var pts: Array[Vector3] = []
		for j in range(sides):
			var a := (TAU / float(sides)) * float(j) + PI * 0.25
			var dir := ref * (cos(a) * w * 0.82) + binorm * (sin(a) * w * 1.18)
			pts.append(spine[i] + dir)
		rings.append(pts)

	for i in range(n - 1):
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		var seg_center := spine[i].lerp(spine[i + 1], 0.5)
		for j in range(sides):
			var nj := (j + 1) % sides
			var f_mid: Vector3 = (r0[j] + r0[nj] + r1[nj] + r1[j]) * 0.25
			var out_d := (f_mid - seg_center).normalized()
			_add_faceted_quad(st, r0[j], r0[nj], r1[nj], r1[j], out_d, float(i * sides + j + 50), uv_scale)

	var top_r: Array = rings[n - 1]
	var tip_dir := (spine[n - 1] - spine[n - 2]).normalized()
	for j in range(1, sides - 1):
		_add_faceted_tri(st, top_r[0], top_r[j], top_r[j + 1], tip_dir, float(j + 400), uv_scale)

	st.generate_tangents()
	return st.commit()

static func _add_faceted_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out_dir: Vector3, facet_seed: float, uv_scale: float) -> void:
	var n := (c - a).cross(b - a)
	if n.length_squared() < 1e-10:
		return
	if n.dot(out_dir) < 0.0:
		var tmp := b
		b = c
		c = tmp
		n = -n
	n = n.normalized()

	var tang := (b - a).normalized()
	var bitang := n.cross(tang).normalized()
	var h := fposmod(sin(facet_seed * 12.9898 + 78.233) * 43758.5453, 1.0)

	var verts := [a, b, c]
	var bary := [Color(1.0, 0.0, 0.0, h), Color(0.0, 1.0, 0.0, h), Color(0.0, 0.0, 1.0, h)]
	for k in range(3):
		var v: Vector3 = verts[k]
		st.set_color(bary[k])
		st.set_normal(n)
		st.set_uv(Vector2(v.dot(tang), v.dot(bitang)) * uv_scale)
		st.set_uv2(Vector2(-1.0, -1.0))
		st.add_vertex(v)

static func _add_faceted_quad(st: SurfaceTool, v00: Vector3, v10: Vector3, v11: Vector3, v01: Vector3, out_dir: Vector3, facet_seed: float, uv_scale: float) -> void:
	var n := (v11 - v00).cross(v10 - v00)
	if n.length_squared() < 1e-10:
		n = (v01 - v00).cross(v11 - v00)
	if n.length_squared() < 1e-10:
		return

	var a := v00
	var b := v10
	var c := v11
	var d := v01
	if n.dot(out_dir) < 0.0:
		a = v10
		b = v00
		c = v01
		d = v11
		n = -n
	n = n.normalized()

	var tang := (b - a).normalized()
	if tang.length_squared() < 1e-6:
		tang = (c - a).normalized()
	var bitang := n.cross(tang).normalized()
	var h := fposmod(sin(facet_seed * 12.9898 + 78.233) * 43758.5453, 1.0)
	var col := Color(1.0, 1.0, 1.0, h)

	var quad_pts := [a, b, c, a, c, d]
	var quad_uv2 := [
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0),
		Vector2(0.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)
	]
	for k in range(6):
		var v: Vector3 = quad_pts[k]
		st.set_color(col)
		st.set_normal(n)
		st.set_uv(Vector2(v.dot(tang), v.dot(bitang)) * uv_scale)
		st.set_uv2(quad_uv2[k])
		st.add_vertex(v)

# =========================================================================
# SHADER DE PIERRE ANCIENNE CRAQUELÉE (Neutre, 0 Émission, Style Fangorn)
# =========================================================================
static func _ensure_shaders() -> void:
	if _stone_shader == null:
		_stone_shader = Shader.new()
		_stone_shader.code = """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 stone_tint : source_color = vec4(0.95, 0.94, 0.92, 1.0);
uniform float triplanar_scale = 0.75;
uniform float crack_darkness : hint_range(0.0, 1.0) = 0.90;
uniform float edge_wear_strength : hint_range(0.0, 1.0) = 0.34;
uniform float normal_depth : hint_range(0.0, 1.5) = 0.62;
uniform float ground_moss_enabled : hint_range(0.0, 1.0) = 1.0;

uniform sampler2D stone_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec3 v_local_pos;
varying vec3 v_local_nrm;

void vertex() {
	v_local_pos = VERTEX;
	v_local_nrm = NORMAL;
}

void fragment() {
	vec3 n_obj = normalize(v_local_nrm);
	vec3 w = pow(abs(n_obj), vec3(4.0));
	w /= max(w.x + w.y + w.z, 0.0001);

	vec2 uv_x = v_local_pos.zy * triplanar_scale;
	vec2 uv_y = v_local_pos.xz * triplanar_scale;
	vec2 uv_z = v_local_pos.xy * triplanar_scale;

	// Échantillonnage triplanaire continu (les craquelures traversent naturellement les facettes)
	vec3 col_x = texture(stone_albedo, uv_x).rgb;
	vec3 col_y = texture(stone_albedo, uv_y).rgb;
	vec3 col_z = texture(stone_albedo, uv_z).rgb;
	vec3 raw_tex = col_x * w.x + col_y * w.y + col_z * w.z;

	// Seconde octave décalée pour densifier le réseau de fines fissures minérales
	vec3 fine_x = texture(stone_albedo, uv_x * 1.75 + vec2(0.37, 0.61)).rgb;
	vec3 fine_y = texture(stone_albedo, uv_y * 1.75 + vec2(0.37, 0.61)).rgb;
	vec3 fine_z = texture(stone_albedo, uv_z * 1.75 + vec2(0.37, 0.61)).rgb;
	vec3 fine_tex = fine_x * w.x + fine_y * w.y + fine_z * w.z;

	float lum_main = dot(raw_tex, vec3(0.299, 0.587, 0.114));
	float lum_fine = dot(fine_tex, vec3(0.299, 0.587, 0.114));

	// Désaturation franche vers une vraie teinte de pierre grise minérale neutre
	vec3 mineral_base = mix(raw_tex, vec3(lum_main), 0.78) * stone_tint.rgb;

	// Légère variation de teinte minérale d'une facette taillée à l'autre
	float facet_id = COLOR.a;
	mineral_base *= (0.91 + 0.18 * facet_id);

	// Usure sèche et ébréchée sur les arêtes géométriques des facettes (sans aucune lueur)
	float chip_noise = (
		texture(noise_tex, uv_x * 1.6).r * w.x +
		texture(noise_tex, uv_y * 1.6).r * w.y +
		texture(noise_tex, uv_z * 1.6).r * w.z
	);
	float edge_d = (UV2.x >= 0.0)
		? min(min(UV2.x, 1.0 - UV2.x), min(UV2.y, 1.0 - UV2.y))
		: min(COLOR.r, min(COLOR.g, COLOR.b));
	float chipped_edge = 1.0 - smoothstep(0.0, 0.075, edge_d + (chip_noise - 0.48) * 0.055);
	vec3 worn_edge_col = mineral_base * 1.38 + vec3(0.05, 0.048, 0.045);
	vec3 stone_col = mix(mineral_base, worn_edge_col, chipped_edge * edge_wear_strength);

	// Réseau de craquelures sombres creusées dans la roche + léger rebord sec
	float min_crack_lum = min(lum_main, lum_fine * 1.08);
	float crack_mask = smoothstep(0.23, 0.065, min_crack_lum);
	float crack_lip = smoothstep(0.18, 0.27, lum_main) * smoothstep(0.37, 0.26, lum_main);
	stone_col *= (1.0 + crack_lip * 0.12);
	stone_col = mix(stone_col, vec3(0.038, 0.038, 0.040), crack_mask * crack_darkness);

	// Patine moussue forestière très discrète uniquement tout en bas des socles
	float moss_h = (1.0 - smoothstep(-0.15, 0.42, v_local_pos.y)) * ground_moss_enabled;
	float moss_mask = clamp(moss_h * (0.35 + 0.65 * chip_noise) * 0.45, 0.0, 0.55);
	stone_col = mix(stone_col, vec3(0.12, 0.15, 0.09), moss_mask);

	// Rugosité minérale mate + creux des fissures ultra-mats
	float rgh_x = texture(stone_roughness, uv_x).r;
	float rgh_y = texture(stone_roughness, uv_y).r;
	float rgh_z = texture(stone_roughness, uv_z).r;
	float base_rough = rgh_x * w.x + rgh_y * w.y + rgh_z * w.z;

	// Relief normal-map triplanaire combiné aux normales plates des facettes
	vec2 nrm_x = (texture(stone_normal, uv_x).rg * 2.0 - 1.0) * normal_depth;
	vec2 nrm_y = (texture(stone_normal, uv_y).rg * 2.0 - 1.0) * normal_depth;
	vec2 nrm_z = (texture(stone_normal, uv_z).rg * 2.0 - 1.0) * normal_depth;
	vec2 fnrm_x = (texture(stone_normal, uv_x * 1.75 + vec2(0.37, 0.61)).rg * 2.0 - 1.0) * (normal_depth * 0.45);
	vec2 fnrm_y = (texture(stone_normal, uv_y * 1.75 + vec2(0.37, 0.61)).rg * 2.0 - 1.0) * (normal_depth * 0.45);
	vec2 fnrm_z = (texture(stone_normal, uv_z * 1.75 + vec2(0.37, 0.61)).rg * 2.0 - 1.0) * (normal_depth * 0.45);

	vec3 bump_obj = vec3(0.0, nrm_x.y + fnrm_x.y, nrm_x.x + fnrm_x.x) * w.x
		+ vec3(nrm_y.x + fnrm_y.x, 0.0, nrm_y.y + fnrm_y.y) * w.y
		+ vec3(nrm_z.x + fnrm_z.x, nrm_z.y + fnrm_z.y, 0.0) * w.z;

	vec3 perturbed_obj = normalize(n_obj + bump_obj);
	vec3 world_nrm = normalize((MODEL_MATRIX * vec4(perturbed_obj, 0.0)).xyz);
	NORMAL = normalize((VIEW_MATRIX * vec4(world_nrm, 0.0)).xyz);

	ALBEDO = stone_col;
	ROUGHNESS = clamp(mix(base_rough * 0.96, 0.99, max(crack_mask, moss_mask)), 0.58, 0.99);
	METALLIC = 0.0;
	SPECULAR = 0.22;
}
"""

static func _get_stone_material(stone_tint: Color, scale_uv: float, crack_dark: float, edge_wear: float, ground_moss: bool) -> ShaderMaterial:
	_ensure_shaders()
	var key := "%s_%.2f_%.2f_%.2f_%d" % [stone_tint.to_html(), scale_uv, crack_dark, edge_wear, 1 if ground_moss else 0]
	if _stone_mat_cache.has(key) and _stone_mat_cache[key] != null:
		return _stone_mat_cache[key] as ShaderMaterial

	var mat := ShaderMaterial.new()
	mat.shader = _stone_shader
	mat.set_shader_parameter("stone_tint", stone_tint)
	mat.set_shader_parameter("triplanar_scale", scale_uv)
	mat.set_shader_parameter("crack_darkness", crack_dark)
	mat.set_shader_parameter("edge_wear_strength", edge_wear)
	mat.set_shader_parameter("normal_depth", 0.62)
	mat.set_shader_parameter("ground_moss_enabled", 1.0 if ground_moss else 0.0)
	if ResourceLoader.exists(SLATE_DIFF_PATH):
		mat.set_shader_parameter("stone_albedo", load(SLATE_DIFF_PATH))
	if ResourceLoader.exists(SLATE_NOR_PATH):
		mat.set_shader_parameter("stone_normal", load(SLATE_NOR_PATH))
	if ResourceLoader.exists(SLATE_ROUGH_PATH):
		mat.set_shader_parameter("stone_roughness", load(SLATE_ROUGH_PATH))
	if ResourceLoader.exists(NOISE_TEX_PATH):
		mat.set_shader_parameter("noise_tex", load(NOISE_TEX_PATH))
	_stone_mat_cache[key] = mat
	return mat

static func _get_metal_material(tint: Color, rough: float, metal: float) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f" % [tint.to_html(), rough, metal]
	if _metal_mat_cache.has(key) and _metal_mat_cache[key] != null:
		return _metal_mat_cache[key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	if ResourceLoader.exists(METAL_DIFF_PATH):
		mat.albedo_texture = load(METAL_DIFF_PATH)
	if ResourceLoader.exists(METAL_NOR_PATH):
		mat.normal_enabled = true
		mat.normal_scale = 1.0
		mat.normal_texture = load(METAL_NOR_PATH)
	mat.roughness = rough
	mat.metallic = metal
	mat.uv1_scale = Vector3(1.5, 1.5, 1.5)
	_metal_mat_cache[key] = mat
	return mat
