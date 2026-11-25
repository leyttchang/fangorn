@tool
class_name OrcCampProps
extends RefCounted

## GÃ©nÃ©rateur procÃ©dural mis en cache pour les structures des Camps Orcs :
## - Tentes de guerre Orcs (plancher bois Ã  niveau + pilotis profonds anti-pente + rampe d'accÃ¨s + toile de peau cousue + collisions ouvertes devant)
## - Feu de camp Orc (cercle de pierres ancrÃ© dans la pente + lit de braises + bÃ»ches croisÃ©es + fire_particule.tscn)

const FIRE_PARTICLE_SCENE: PackedScene = preload("res://particule/fire/fire_particule.tscn")

const WOOD_DIFF_PATH := "res://assets/texture/medieval_wood_textures/medieval_wood_diff_1k.jpg"
const WOOD_NOR_PATH := "res://assets/texture/medieval_wood_textures/medieval_wood_nor_gl_1k.jpg"
const WOOD_ROUGH_PATH := "res://assets/texture/medieval_wood_textures/medieval_wood_rough_1k.jpg"

const BARK_DIFF_PATH := "res://assets/texture/bark_brown_text/bark_brown_02_diff_1k.jpg"
const BARK_NOR_PATH := "res://assets/texture/bark_brown_text/bark_brown_02_nor_gl_1k.jpg"
const BARK_ROUGH_PATH := "res://assets/texture/bark_brown_text/bark_brown_02_rough_1k.jpg"

const ROCK_DIFF_PATH := "res://assets/texture/stone_material/textures/marble_rock_02_diff_4k.jpg"
const ROCK_ARM_PATH := "res://assets/texture/stone_material/textures/marble_rock_02_arm_4k.jpg"
const ROCK_NOR_PATH := "res://assets/texture/stone_material/textures/marble_rock_02_nor_gl_4k.jpg"

const METAL_DIFF_PATH := "res://assets/texture/rusty_metal_textures/rusty_metal_04_diff_1k.jpg"
const METAL_ARM_PATH := "res://assets/texture/rusty_metal_textures/rusty_metal_04_arm_1k.jpg"
const METAL_NOR_PATH := "res://assets/texture/rusty_metal_textures/rusty_metal_04_nor_gl_1k.jpg"
const SMOKE_NOISE_TEX_PATH := "res://assets/LeLu's Noise Pack/T_VFX_simplex_1.png"
const SPARK_FLARE_TEX_PATH := "res://assets/LeLu's Noise Pack/T_flare8_vfx.png"

const TENT_FLOOR_TOP_Y: float = 0.06
const TENT_CHEST_LOCAL_POS := Vector3(0.0, 0.068, -0.68)

static var _mat_planks: StandardMaterial3D = null
static var _mat_poles: StandardMaterial3D = null
static var _mat_hide_a: StandardMaterial3D = null
static var _mat_hide_b: StandardMaterial3D = null
static var _mat_rock: StandardMaterial3D = null
static var _mat_iron: StandardMaterial3D = null
static var _mat_embers: StandardMaterial3D = null
static var _mat_campfire_smoke: StandardMaterial3D = null
static var _mat_campfire_sparks: StandardMaterial3D = null

static var _cached_tent_plank_mesh: ArrayMesh = null
static var _cached_tent_frame_mesh: ArrayMesh = null
static var _cached_tent_iron_mesh: ArrayMesh = null
static var _cached_tent_canopy_mesh: ArrayMesh = null

static var _cached_fire_stones_mesh: ArrayMesh = null
static var _cached_fire_logs_mesh: ArrayMesh = null
static var _cached_fire_embers_mesh: ArrayMesh = null


static func clear_caches() -> void:
	_mat_planks = null
	_mat_poles = null
	_mat_hide_a = null
	_mat_hide_b = null
	_mat_rock = null
	_mat_iron = null
	_mat_embers = null
	_mat_campfire_smoke = null
	_mat_campfire_sparks = null
	_cached_tent_plank_mesh = null
	_cached_tent_frame_mesh = null
	_cached_tent_iron_mesh = null
	_cached_tent_canopy_mesh = null
	_cached_fire_stones_mesh = null
	_cached_fire_logs_mesh = null
	_cached_fire_embers_mesh = null


static func build_orc_tent_node(tent_name: String = "OrcTent", variant_index: int = 0) -> Node3D:
	_ensure_materials()
	_ensure_tent_meshes()

	var root := Node3D.new()
	root.name = tent_name

	var no_limit: bool = Engine.is_editor_hint()
	var vis_end: float = 0.0 if no_limit else 220.0
	var vis_margin: float = 0.0 if no_limit else 25.0

	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "PlankFloorAndRamp"
	floor_mi.mesh = _cached_tent_plank_mesh
	floor_mi.material_override = _mat_planks
	floor_mi.visibility_range_end = vis_end
	floor_mi.visibility_range_end_margin = vis_margin
	root.add_child(floor_mi)

	var frame_mi := MeshInstance3D.new()
	frame_mi.name = "TimberFrame"
	frame_mi.mesh = _cached_tent_frame_mesh
	frame_mi.material_override = _mat_poles
	frame_mi.visibility_range_end = vis_end
	frame_mi.visibility_range_end_margin = vis_margin
	root.add_child(frame_mi)

	var iron_mi := MeshInstance3D.new()
	iron_mi.name = "IronLashings"
	iron_mi.mesh = _cached_tent_iron_mesh
	iron_mi.material_override = _mat_iron
	iron_mi.visibility_range_end = vis_end
	iron_mi.visibility_range_end_margin = vis_margin
	root.add_child(iron_mi)

	var canopy_mi := MeshInstance3D.new()
	canopy_mi.name = "HideCanopy"
	canopy_mi.mesh = _cached_tent_canopy_mesh
	canopy_mi.material_override = _mat_hide_b if (variant_index % 2 == 1) else _mat_hide_a
	canopy_mi.visibility_range_end = vis_end
	canopy_mi.visibility_range_end_margin = vis_margin
	root.add_child(canopy_mi)

	# Petite lanterne/torche chaude sous le faÃ®tage pour bien Ã©clairer le coffre dans la tente la nuit
	var tent_light := OmniLight3D.new()
	tent_light.name = "TentWarmLight"
	tent_light.position = Vector3(0.0, 2.05, 0.35)
	tent_light.light_color = Color(0.96, 0.56, 0.22)
	tent_light.light_energy = 1.35
	tent_light.omni_range = 5.4
	tent_light.omni_attenuation = 1.35
	root.add_child(tent_light)

	# Marqueur exact oÃ¹ poser le coffre Ã  plat sur le plancher
	var chest_anchor := Marker3D.new()
	chest_anchor.name = "ChestAnchor"
	chest_anchor.position = TENT_CHEST_LOCAL_POS
	root.add_child(chest_anchor)

	# Collisions physiques : plancher + rampe d'entrÃ©e + murs latÃ©raux/arriÃ¨re (entrÃ©e +Z grande ouverte !)
	var body := StaticBody3D.new()
	body.name = "TentStaticBody"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)

	var floor_col := CollisionShape3D.new()
	floor_col.name = "FloorShape"
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(3.64, 1.80, 4.12)
	floor_col.shape = floor_box
	floor_col.position = Vector3(0.0, TENT_FLOOR_TOP_Y - 0.90, 0.0)
	body.add_child(floor_col)

	# Rampe douce devant l'entrÃ©e (+Z) prolongÃ©e jusqu'Ã  y = -1.56m pour rejoindre le sol mÃªme Ã  flanc de colline raide
	var ramp_col := CollisionShape3D.new()
	ramp_col.name = "EntranceRampShape"
	var ramp_box := BoxShape3D.new()
	ramp_box.size = Vector3(2.72, 0.22, 3.08)
	ramp_col.shape = ramp_box
	ramp_col.position = Vector3(0.0, -0.84, 3.315)
	ramp_col.rotation.x = 0.5589
	body.add_child(ramp_col)

	var left_col := CollisionShape3D.new()
	left_col.name = "LeftWallShape"
	var side_box := BoxShape3D.new()
	side_box.size = Vector3(0.22, 2.55, 3.96)
	left_col.shape = side_box
	left_col.position = Vector3(-1.46, 1.24, 0.0)
	left_col.rotation.z = deg_to_rad(-26.0)
	body.add_child(left_col)

	var right_col := CollisionShape3D.new()
	right_col.name = "RightWallShape"
	right_col.shape = side_box
	right_col.position = Vector3(1.46, 1.24, 0.0)
	right_col.rotation.z = deg_to_rad(26.0)
	body.add_child(right_col)

	var back_col := CollisionShape3D.new()
	back_col.name = "BackWallShape"
	var back_box := BoxShape3D.new()
	back_box.size = Vector3(3.30, 2.55, 0.24)
	back_col.shape = back_box
	back_col.position = Vector3(0.0, 1.28, -1.96)
	body.add_child(back_col)

	return root


static func build_campfire_pit_node(node_name: String = "CampfirePit") -> Node3D:
	_ensure_materials()
	_ensure_campfire_meshes()

	var root := Node3D.new()
	root.name = node_name

	var no_limit: bool = Engine.is_editor_hint()
	var vis_end: float = 0.0 if no_limit else 200.0
	var vis_margin: float = 0.0 if no_limit else 25.0

	var stones_mi := MeshInstance3D.new()
	stones_mi.name = "StoneRing"
	stones_mi.mesh = _cached_fire_stones_mesh
	stones_mi.material_override = _mat_rock
	stones_mi.visibility_range_end = vis_end
	stones_mi.visibility_range_end_margin = vis_margin
	root.add_child(stones_mi)

	var logs_mi := MeshInstance3D.new()
	logs_mi.name = "FirewoodLogs"
	logs_mi.mesh = _cached_fire_logs_mesh
	logs_mi.material_override = _mat_poles
	logs_mi.visibility_range_end = vis_end
	logs_mi.visibility_range_end_margin = vis_margin
	root.add_child(logs_mi)

	var embers_mi := MeshInstance3D.new()
	embers_mi.name = "GlowingEmbers"
	embers_mi.mesh = _cached_fire_embers_mesh
	embers_mi.material_override = _mat_embers
	embers_mi.visibility_range_end = vis_end
	embers_mi.visibility_range_end_margin = vis_margin
	root.add_child(embers_mi)

	if FIRE_PARTICLE_SCENE != null:
		var fx: Node3D = FIRE_PARTICLE_SCENE.instantiate() as Node3D
		if fx != null:
			fx.name = "CampfireFlames"
			fx.position = Vector3(0.0, 0.20, 0.0)
			root.add_child(fx)

	var body := StaticBody3D.new()
	body.name = "CampfireBody"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.72
	cyl.height = 0.95
	col.shape = cyl
	col.position = Vector3(0.0, 0.05, 0.0)
	body.add_child(col)

	return root


## Petit feu de camp balise conÃ§u pour accompagner les Petites StÃ¨les Tier I :
## Plus compact au sol (~0.84x) mais dotÃ© d'une lueur chaude longue portÃ©e (16m),
## de flammes visibles Ã  210m, d'escarbilles montantes et d'une fine colonne de fumÃ©e pour repÃ©rer la stÃ¨le de loin.
static func build_stele_beacon_campfire_node(node_name: String = "SteleCampfire") -> Node3D:
	var pit: Node3D = build_campfire_pit_node(node_name)
	pit.scale = Vector3(0.84, 0.88, 0.84)

	var no_limit: bool = Engine.is_editor_hint()
	var vis_far: float = 0.0 if no_limit else 220.0
	var vis_margin: float = 0.0 if no_limit else 28.0

	var flames_root: Node3D = pit.get_node_or_null("CampfireFlames") as Node3D
	if flames_root != null:
		flames_root.scale = Vector3(1.18, 1.38, 1.18)
		for ch: Node in flames_root.get_children():
			if ch is GPUParticles3D:
				var gp := ch as GPUParticles3D
				gp.visibility_range_end = vis_far
				gp.visibility_range_end_margin = vis_margin
			elif ch is OmniLight3D:
				var ol := ch as OmniLight3D
				ol.omni_range = 16.5
				ol.omni_attenuation = 1.12
				ol.distance_fade_enabled = not no_limit
				ol.distance_fade_begin = 165.0
				ol.distance_fade_length = 45.0

	# Halo constant d'appoint pour qu'entre deux battements d'AnimationPlayer la clairiÃ¨re et la stÃ¨le restent bien Ã©clairÃ©es de loin
	var steady_glow := OmniLight3D.new()
	steady_glow.name = "BeaconWarmGlow"
	steady_glow.position = Vector3(0.0, 0.95, 0.0)
	steady_glow.light_color = Color(1.0, 0.54, 0.16)
	steady_glow.light_energy = 1.85
	steady_glow.omni_range = 15.0
	steady_glow.omni_attenuation = 1.18
	if not no_limit:
		steady_glow.distance_fade_enabled = true
		steady_glow.distance_fade_begin = 165.0
		steady_glow.distance_fade_length = 45.0
	pit.add_child(steady_glow)

	# Escarbilles lumineuses s'Ã©levant jusqu'Ã  ~5.5m au-dessus du feu (trÃ¨s lisibles Ã  travers les sous-bois)
	var high_sparks := GPUParticles3D.new()
	high_sparks.name = "HighEmberSparks"
	high_sparks.position = Vector3(0.0, 0.42, 0.0)
	high_sparks.amount = 18
	high_sparks.lifetime = 2.7
	high_sparks.visibility_range_end = vis_far
	high_sparks.visibility_range_end_margin = vis_margin
	high_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	high_sparks.material_override = _mat_campfire_sparks

	var sp_mat := ParticleProcessMaterial.new()
	sp_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sp_mat.emission_sphere_radius = 0.24
	sp_mat.direction = Vector3(0.0, 1.0, 0.0)
	sp_mat.spread = 16.0
	sp_mat.initial_velocity_min = 1.35
	sp_mat.initial_velocity_max = 2.45
	sp_mat.gravity = Vector3(0.18, 0.45, -0.12)
	sp_mat.turbulence_enabled = true
	sp_mat.turbulence_noise_strength = 0.65
	sp_mat.turbulence_noise_scale = 2.5
	sp_mat.scale_min = 0.07
	sp_mat.scale_max = 0.16

	var sp_grad := Gradient.new()
	sp_grad.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	sp_grad.colors = PackedColorArray([
		Color(3.2, 2.1, 0.85, 0.0),
		Color(3.0, 1.35, 0.30, 0.95),
		Color(2.4, 0.65, 0.12, 0.70),
		Color(1.2, 0.20, 0.04, 0.0)
	])
	var sp_ramp := GradientTexture1D.new()
	sp_ramp.gradient = sp_grad
	sp_mat.color_ramp = sp_ramp
	high_sparks.process_material = sp_mat

	var sp_qm := QuadMesh.new()
	sp_qm.size = Vector2(0.22, 0.22)
	high_sparks.draw_pass_1 = sp_qm
	pit.add_child(high_sparks)

	# Panache lÃ©ger de fumÃ©e chaude montant Ã  ~7-9m dans la clairiÃ¨re pour guider le regard de loin
	var smoke := GPUParticles3D.new()
	smoke.name = "BeaconSmokePlume"
	smoke.position = Vector3(0.0, 0.85, 0.0)
	smoke.amount = 20
	smoke.lifetime = 4.2
	smoke.visibility_range_end = vis_far
	smoke.visibility_range_end_margin = vis_margin
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smoke.material_override = _mat_campfire_smoke

	var sm_mat := ParticleProcessMaterial.new()
	sm_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sm_mat.emission_sphere_radius = 0.22
	sm_mat.direction = Vector3(0.05, 1.0, 0.0)
	sm_mat.spread = 11.0
	sm_mat.initial_velocity_min = 1.25
	sm_mat.initial_velocity_max = 1.95
	sm_mat.gravity = Vector3(0.12, 0.22, 0.04)
	sm_mat.damping_min = 0.12
	sm_mat.damping_max = 0.28
	sm_mat.scale_min = 0.65
	sm_mat.scale_max = 1.45

	var sm_scale_curve := Curve.new()
	sm_scale_curve.add_point(Vector2(0.0, 0.38))
	sm_scale_curve.add_point(Vector2(0.45, 0.85))
	sm_scale_curve.add_point(Vector2(1.0, 1.65))
	sm_scale_curve.bake()
	var sm_scale_tex := CurveTexture.new()
	sm_scale_tex.curve = sm_scale_curve
	sm_mat.scale_curve = sm_scale_tex

	var sm_grad := Gradient.new()
	sm_grad.offsets = PackedFloat32Array([0.0, 0.18, 0.55, 1.0])
	sm_grad.colors = PackedColorArray([
		Color(0.95, 0.62, 0.34, 0.0),
		Color(0.72, 0.58, 0.48, 0.34),
		Color(0.52, 0.50, 0.52, 0.22),
		Color(0.42, 0.42, 0.45, 0.0)
	])
	var sm_ramp := GradientTexture1D.new()
	sm_ramp.gradient = sm_grad
	sm_mat.color_ramp = sm_ramp
	smoke.process_material = sm_mat

	var sm_qm := QuadMesh.new()
	sm_qm.size = Vector2(1.15, 1.15)
	smoke.draw_pass_1 = sm_qm
	pit.add_child(smoke)

	return pit


# =========================================================================
# MATÃ‰RIAUX PBR & TEXTURE DE PEAU COUSUE ORC (CACHÃ‰S STATIQUEMENT)
# =========================================================================
static func _ensure_materials() -> void:
	if _mat_planks == null:
		_mat_planks = StandardMaterial3D.new()
		_mat_planks.albedo_color = Color(0.68, 0.56, 0.44)
		if ResourceLoader.exists(WOOD_DIFF_PATH):
			_mat_planks.albedo_texture = load(WOOD_DIFF_PATH) as Texture2D
		if ResourceLoader.exists(WOOD_NOR_PATH):
			_mat_planks.normal_enabled = true
			_mat_planks.normal_scale = 1.25
			_mat_planks.normal_texture = load(WOOD_NOR_PATH) as Texture2D
		if ResourceLoader.exists(WOOD_ROUGH_PATH):
			_mat_planks.roughness_texture = load(WOOD_ROUGH_PATH) as Texture2D
		else:
			_mat_planks.roughness = 0.88
		_mat_planks.uv1_scale = Vector3(1.6, 1.6, 1.0)

	if _mat_poles == null:
		_mat_poles = StandardMaterial3D.new()
		_mat_poles.albedo_color = Color(0.62, 0.50, 0.38)
		if ResourceLoader.exists(BARK_DIFF_PATH):
			_mat_poles.albedo_texture = load(BARK_DIFF_PATH) as Texture2D
		if ResourceLoader.exists(BARK_NOR_PATH):
			_mat_poles.normal_enabled = true
			_mat_poles.normal_scale = 1.35
			_mat_poles.normal_texture = load(BARK_NOR_PATH) as Texture2D
		if ResourceLoader.exists(BARK_ROUGH_PATH):
			_mat_poles.roughness_texture = load(BARK_ROUGH_PATH) as Texture2D
		else:
			_mat_poles.roughness = 0.92

	if _mat_rock == null:
		_mat_rock = StandardMaterial3D.new()
		_mat_rock.albedo_color = Color(0.42, 0.40, 0.38)
		if ResourceLoader.exists(ROCK_DIFF_PATH):
			_mat_rock.albedo_texture = load(ROCK_DIFF_PATH) as Texture2D
		if ResourceLoader.exists(ROCK_ARM_PATH):
			var arm := load(ROCK_ARM_PATH) as Texture2D
			_mat_rock.roughness_texture = arm
			_mat_rock.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
			_mat_rock.ao_enabled = true
			_mat_rock.ao_texture = arm
		else:
			_mat_rock.roughness = 0.92
		if ResourceLoader.exists(ROCK_NOR_PATH):
			_mat_rock.normal_enabled = true
			_mat_rock.normal_scale = 1.4
			_mat_rock.normal_texture = load(ROCK_NOR_PATH) as Texture2D

	if _mat_iron == null:
		_mat_iron = StandardMaterial3D.new()
		_mat_iron.albedo_color = Color(0.55, 0.48, 0.44)
		_mat_iron.metallic = 0.75
		_mat_iron.roughness = 0.68
		if ResourceLoader.exists(METAL_DIFF_PATH):
			_mat_iron.albedo_texture = load(METAL_DIFF_PATH) as Texture2D
		if ResourceLoader.exists(METAL_ARM_PATH):
			var m_arm := load(METAL_ARM_PATH) as Texture2D
			_mat_iron.roughness_texture = m_arm
			_mat_iron.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		if ResourceLoader.exists(METAL_NOR_PATH):
			_mat_iron.normal_enabled = true
			_mat_iron.normal_texture = load(METAL_NOR_PATH) as Texture2D

	if _mat_hide_a == null or _mat_hide_b == null:
		var hide_tex_a: ImageTexture = _build_orc_hide_texture(Color(0.50, 0.36, 0.23), Color(0.48, 0.14, 0.10), 901)
		var hide_tex_b: ImageTexture = _build_orc_hide_texture(Color(0.44, 0.34, 0.25), Color(0.54, 0.30, 0.10), 1907)

		_mat_hide_a = StandardMaterial3D.new()
		_mat_hide_a.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat_hide_a.albedo_texture = hide_tex_a
		_mat_hide_a.roughness = 0.90
		if ResourceLoader.exists(WOOD_NOR_PATH):
			_mat_hide_a.normal_enabled = true
			_mat_hide_a.normal_scale = 0.42
			_mat_hide_a.normal_texture = load(WOOD_NOR_PATH) as Texture2D

		_mat_hide_b = _mat_hide_a.duplicate() as StandardMaterial3D
		_mat_hide_b.albedo_texture = hide_tex_b

	if _mat_embers == null:
		_mat_embers = StandardMaterial3D.new()
		_mat_embers.albedo_color = Color(0.18, 0.10, 0.07)
		_mat_embers.roughness = 0.96
		_mat_embers.emission_enabled = true
		_mat_embers.emission = Color(1.85, 0.45, 0.06)
		_mat_embers.emission_energy_multiplier = 1.65

	if _mat_campfire_sparks == null:
		_mat_campfire_sparks = StandardMaterial3D.new()
		_mat_campfire_sparks.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_campfire_sparks.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mat_campfire_sparks.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_campfire_sparks.vertex_color_use_as_albedo = true
		_mat_campfire_sparks.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_mat_campfire_sparks.billboard_keep_scale = true
		if ResourceLoader.exists(SPARK_FLARE_TEX_PATH):
			_mat_campfire_sparks.albedo_texture = load(SPARK_FLARE_TEX_PATH) as Texture2D

	if _mat_campfire_smoke == null:
		_mat_campfire_smoke = StandardMaterial3D.new()
		_mat_campfire_smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_campfire_smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_campfire_smoke.vertex_color_use_as_albedo = true
		_mat_campfire_smoke.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_mat_campfire_smoke.billboard_keep_scale = true
		_mat_campfire_smoke.proximity_fade_enabled = true
		_mat_campfire_smoke.proximity_fade_distance = 0.65
		if ResourceLoader.exists(SMOKE_NOISE_TEX_PATH):
			_mat_campfire_smoke.albedo_texture = load(SMOKE_NOISE_TEX_PATH) as Texture2D


static func _build_orc_hide_texture(base_leather: Color, warpaint_col: Color, tex_seed: int) -> ImageTexture:
	var sz: int = 128
	var img := Image.create(sz, sz, true, Image.FORMAT_RGBA8)
	var fn := FastNoiseLite.new()
	fn.seed = tex_seed
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.065
	fn.fractal_octaves = 3

	for py in range(sz):
		var v: float = float(py) / float(sz - 1)
		for px in range(sz):
			var u: float = float(px) / float(sz - 1)
			var n: float = fn.get_noise_2d(float(px), float(py)) * 0.5 + 0.5
			var n2: float = fn.get_noise_2d(float(px) * 2.7 + 41.0, float(py) * 2.7 - 19.0) * 0.5 + 0.5

			var col: Color = base_leather.lerp(base_leather.darkened(0.32), n * 0.65)
			col = col.lerp(base_leather.lightened(0.14), n2 * 0.35)

			# Coutures de peaux rapiÃ©cÃ©es
			var seam_u: float = absf(fmod(u * 3.0 + sin(v * 7.0) * 0.03, 1.0) - 0.5)
			var seam_v: float = absf(fmod(v * 2.0 + cos(u * 5.0) * 0.03, 1.0) - 0.5)
			if seam_u < 0.022 or seam_v < 0.024:
				col = col.darkened(0.45)

			# Marquages tribaux Orcs en dents de scie prÃ¨s des bords
			var jag: float = absf(fmod(u * 9.0, 1.0) - 0.5) * 0.16
			if v > 0.72 - jag and v < 0.84 - jag * 0.5:
				col = col.lerp(warpaint_col, 0.78)

			# Salissure / suie en bas de toile
			if v > 0.85:
				col = col.darkened((v - 0.85) * 2.4)

			img.set_pixel(px, py, Color(col.r, col.g, col.b, 1.0))

	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# =========================================================================
# CONSTRUCTION DES MAILLAGES 3D DE LA TENTE ORC
# =========================================================================
static func _ensure_tent_meshes() -> void:
	if _cached_tent_plank_mesh != null and _cached_tent_frame_mesh != null and _cached_tent_canopy_mesh != null and _cached_tent_iron_mesh != null:
		return

	# 1. Plancher en planches rustiques + jupe/pilotis anti-pente + rampe d'accÃ¨s avant
	var st_planks := SurfaceTool.new()
	st_planks.begin(Mesh.PRIMITIVE_TRIANGLES)

	var plank_count: int = 8
	var total_w: float = 3.64
	var plank_w: float = (total_w / float(plank_count)) - 0.022
	for i in range(plank_count):
		var cx: float = -total_w * 0.5 + (float(i) + 0.5) * (total_w / float(plank_count))
		var len_jit: float = 0.05 * sin(float(i) * 2.3)
		_append_oriented_box(
			st_planks,
			Vector3(cx, TENT_FLOOR_TOP_Y - 0.055, len_jit * 0.5),
			Basis.IDENTITY,
			Vector3(plank_w, 0.11, 4.10 + len_jit)
		)

	# Traverses et jupe de soutÃ¨nement profonde (jusqu'Ã  y = -1.75m pour ne jamais flotter sur les collines)
	_append_oriented_box(st_planks, Vector3(0.0, -0.88, 0.0), Basis.IDENTITY, Vector3(3.42, 1.72, 3.88))

	# Rampe d'entrÃ©e (+Z) en planches transversales prolongÃ©e jusqu'Ã  y = -1.56m (s'enfouit proprement sur le plat comme sur les pentes)
	var ramp_basis := Basis.from_euler(Vector3(0.5589, 0.0, 0.0))
	var ramp_planks: int = 11
	for r_i in range(ramp_planks):
		var t_r: float = (float(r_i) + 0.5) / float(ramp_planks)
		var local_along: float = lerpf(-1.50, 1.50, t_r)
		var r_center: Vector3 = Vector3(0.0, -0.80, 3.315) + ramp_basis * Vector3(0.0, 0.0, local_along)
		_append_oriented_box(st_planks, r_center, ramp_basis, Vector3(2.68, 0.10, 0.25))

	st_planks.generate_normals()
	st_planks.generate_tangents()
	_cached_tent_plank_mesh = st_planks.commit()

	# 2. Charpente de rondins Orcs (A-frame croisÃ©s formant des cornes au sommet + faÃ®tiÃ¨re + pieux)
	var st_frame := SurfaceTool.new()
	st_frame.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Rondins avant (+Z) croisÃ©s au sommet
	_append_tapered_pole(st_frame, Vector3(-1.90, -1.55, 1.98), Vector3(0.36, 3.38, 2.08), 0.105, 0.055, 7)
	_append_tapered_pole(st_frame, Vector3(1.90, -1.55, 1.98), Vector3(-0.36, 3.38, 2.08), 0.105, 0.055, 7)
	# Rondins arriÃ¨re (-Z) croisÃ©s au sommet
	_append_tapered_pole(st_frame, Vector3(-1.90, -1.55, -1.98), Vector3(0.32, 3.24, -2.06), 0.105, 0.055, 7)
	_append_tapered_pole(st_frame, Vector3(1.90, -1.55, -1.98), Vector3(-0.32, 3.24, -2.06), 0.105, 0.055, 7)
	# Poutre faÃ®tiÃ¨re centrale
	_append_tapered_pole(st_frame, Vector3(0.0, 2.74, -2.38), Vector3(0.0, 2.84, 2.48), 0.095, 0.082, 7)
	# Pannes latÃ©rales
	_append_tapered_pole(st_frame, Vector3(-1.74, 0.96, -2.16), Vector3(-1.74, 0.96, 2.16), 0.068, 0.068, 6)
	_append_tapered_pole(st_frame, Vector3(1.74, 0.96, -2.16), Vector3(1.74, 0.96, 2.16), 0.068, 0.068, 6)

	# 4 Pieux de coin + 6 piquets d'ancrage obliques
	for sx in [-1.80, 1.80]:
		for sz in [-1.96, 1.96]:
			_append_tapered_pole(st_frame, Vector3(sx, -1.78, sz), Vector3(sx, 0.98, sz), 0.088, 0.075, 6)
	for sz_stake in [-1.45, 0.0, 1.45]:
		_append_tapered_pole(st_frame, Vector3(-2.18, -0.95, sz_stake), Vector3(-1.86, 0.42, sz_stake), 0.055, 0.032, 5)
		_append_tapered_pole(st_frame, Vector3(2.18, -0.95, sz_stake), Vector3(1.86, 0.42, sz_stake), 0.055, 0.032, 5)

	st_frame.generate_normals()
	st_frame.generate_tangents()
	_cached_tent_frame_mesh = st_frame.commit()

	# 3. Anneaux/ligatures mÃ©talliques aux croisements de rondins
	var st_iron := SurfaceTool.new()
	st_iron.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_tapered_pole(st_iron, Vector3(0.0, 2.74, 1.88), Vector3(0.0, 2.86, 2.10), 0.145, 0.145, 8)
	_append_tapered_pole(st_iron, Vector3(0.0, 2.68, -2.10), Vector3(0.0, 2.78, -1.88), 0.145, 0.145, 8)
	st_iron.generate_normals()
	st_iron.generate_tangents()
	_cached_tent_iron_mesh = st_iron.commit()

	# 4. Toile de peaux cousues lÃ©gÃ¨rement incurvÃ©e (toit + bas-cÃ´tÃ©s + pignon arriÃ¨re + pans d'entrÃ©e relevÃ©s)
	var st_hide := SurfaceTool.new()
	st_hide.begin(Mesh.PRIMITIVE_TRIANGLES)

	var z_segs: int = 8
	var profile_segs: int = 6
	for side_s in [-1.0, 1.0]:
		for iz in range(z_segs):
			var tz0: float = float(iz) / float(z_segs)
			var tz1: float = float(iz + 1) / float(z_segs)
			var z0: float = lerpf(-2.04, 2.04, tz0)
			var z1: float = lerpf(-2.04, 2.04, tz1)
			var ridge_y0: float = lerpf(2.74, 2.82, tz0) - sin(tz0 * PI) * 0.09
			var ridge_y1: float = lerpf(2.74, 2.82, tz1) - sin(tz1 * PI) * 0.09

			for ip in range(profile_segs):
				var tp0: float = float(ip) / float(profile_segs)
				var tp1: float = float(ip + 1) / float(profile_segs)

				var p00: Vector3 = _eval_tent_canopy_point(side_s, tp0, z0, ridge_y0)
				var p10: Vector3 = _eval_tent_canopy_point(side_s, tp1, z0, ridge_y0)
				var p01: Vector3 = _eval_tent_canopy_point(side_s, tp0, z1, ridge_y1)
				var p11: Vector3 = _eval_tent_canopy_point(side_s, tp1, z1, ridge_y1)

				_append_quad(
					st_hide, p00, p10, p11, p01,
					Vector2(tz0 * 2.0, tp0),
					Vector2(tz0 * 2.0, tp1),
					Vector2(tz1 * 2.0, tp1),
					Vector2(tz1 * 2.0, tp0)
				)

	# Pignon arriÃ¨re fermÃ© (-Z)
	var back_z: float = -2.02
	var back_peak := Vector3(0.0, 2.74, back_z)
	for side_b in [-1.0, 1.0]:
		var eave_b := Vector3(1.74 * side_b, 0.96, back_z)
		var base_b := Vector3(1.88 * side_b, -0.04, back_z)
		var center_mid := Vector3(0.0, 0.96, back_z - 0.05)
		var center_bot := Vector3(0.0, -0.04, back_z - 0.04)
		_append_tri(st_hide, back_peak, eave_b, center_mid, Vector2(0.5, 0.0), Vector2(1.0, 0.55), Vector2(0.5, 0.55))
		_append_quad(st_hide, center_mid, eave_b, base_b, center_bot, Vector2(0.5, 0.55), Vector2(1.0, 0.55), Vector2(1.0, 1.0), Vector2(0.5, 1.0))

	# Pans d'entrÃ©e avant (+Z) Ã©cartÃ©s sur les cÃ´tÃ©s pour laisser une grande ouverture centrale vers le coffre
	var front_z: float = 2.01
	var front_peak := Vector3(0.0, 2.82, front_z)
	for side_f in [-1.0, 1.0]:
		var eave_f := Vector3(1.74 * side_f, 0.96, front_z)
		var tie_mid := Vector3(1.34 * side_f, 1.48, front_z + 0.08)
		var tie_bot := Vector3(1.62 * side_f, 0.04, front_z + 0.04)
		var base_f := Vector3(1.88 * side_f, 0.02, front_z)
		_append_tri(st_hide, front_peak, eave_f, tie_mid, Vector2(0.5, 0.0), Vector2(1.0, 0.55), Vector2(0.72, 0.42))
		_append_quad(st_hide, tie_mid, eave_f, base_f, tie_bot, Vector2(0.72, 0.42), Vector2(1.0, 0.55), Vector2(1.0, 0.98), Vector2(0.78, 0.98))

	st_hide.generate_normals()
	st_hide.generate_tangents()
	_cached_tent_canopy_mesh = st_hide.commit()


static func _eval_tent_canopy_point(side_sign: float, t_prof: float, z_val: float, ridge_y: float) -> Vector3:
	if t_prof <= 0.68:
		var u: float = t_prof / 0.68
		var x_top: float = lerpf(0.0, 1.74, u) * side_sign
		var sag: float = sin(u * PI) * 0.14
		var y_top: float = lerpf(ridge_y, 0.96, u) - sag
		return Vector3(x_top, y_top, z_val)
	var w: float = (t_prof - 0.68) / 0.32
	var x_wall: float = lerpf(1.74, 1.90, w) * side_sign
	var y_wall: float = lerpf(0.96, -0.06, w)
	return Vector3(x_wall, y_wall, z_val)


# =========================================================================
# CONSTRUCTION DES MAILLAGES 3D DU FEU DE CAMP ORC
# =========================================================================
static func _ensure_campfire_meshes() -> void:
	if _cached_fire_stones_mesh != null and _cached_fire_logs_mesh != null and _cached_fire_embers_mesh != null:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 40821

	# 1. Cercle de 10 pierres brutes avec base prolongÃ©e (-0.52m) pour Ã©pouser les pentes
	var st_stones := SurfaceTool.new()
	st_stones.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stone_count: int = 10
	for i in range(stone_count):
		var ang: float = (TAU / float(stone_count)) * float(i) + rng.randf_range(-0.08, 0.08)
		var rad: float = rng.randf_range(0.58, 0.68)
		var sx: float = cos(ang) * rad
		var sz: float = sin(ang) * rad
		var w_stone: float = rng.randf_range(0.28, 0.38)
		var h_top: float = rng.randf_range(0.18, 0.30)
		var stone_basis := Basis(Vector3.UP, -ang + rng.randf_range(-0.25, 0.25))
		_append_oriented_box(
			st_stones,
			Vector3(sx, (h_top - 0.52) * 0.5, sz),
			stone_basis,
			Vector3(w_stone, h_top + 0.52, w_stone * 0.82)
		)
	st_stones.generate_normals()
	st_stones.generate_tangents()
	_cached_fire_stones_mesh = st_stones.commit()

	# 2. BÃ»ches de bois croisÃ©es en tipi au-dessus des braises
	var st_logs := SurfaceTool.new()
	st_logs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var log_count: int = 5
	for i in range(log_count):
		var l_ang: float = (TAU / float(log_count)) * float(i) + 0.22
		var p_base := Vector3(cos(l_ang) * 0.52, -0.02, sin(l_ang) * 0.52)
		var p_tip := Vector3(-cos(l_ang) * 0.14, 0.44 + float(i % 2) * 0.05, -sin(l_ang) * 0.14)
		_append_tapered_pole(st_logs, p_base, p_tip, 0.072, 0.048, 6)
	st_logs.generate_normals()
	st_logs.generate_tangents()
	_cached_fire_logs_mesh = st_logs.commit()

	# 3. Lit de cendres et braises ardentes au centre
	var st_emb := SurfaceTool.new()
	st_emb.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_tapered_pole(st_emb, Vector3(0.0, -0.45, 0.0), Vector3(0.0, 0.11, 0.0), 0.54, 0.34, 9)
	st_emb.generate_normals()
	st_emb.generate_tangents()
	_cached_fire_embers_mesh = st_emb.commit()


# =========================================================================
# PRIMITIVES GÃ‰OMÃ‰TRIQUES BAS NIVEAU
# =========================================================================
static func _append_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uva: Vector2, uvb: Vector2, uvc: Vector2) -> void:
	st.set_uv(uva)
	st.add_vertex(a)
	st.set_uv(uvb)
	st.add_vertex(b)
	st.set_uv(uvc)
	st.add_vertex(c)


static func _append_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uva: Vector2, uvb: Vector2, uvc: Vector2, uvd: Vector2) -> void:
	_append_tri(st, a, b, c, uva, uvb, uvc)
	_append_tri(st, a, c, d, uva, uvc, uvd)


static func _append_oriented_box(st: SurfaceTool, center: Vector3, basis: Basis, size: Vector3) -> void:
	var hx: float = size.x * 0.5
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var v000: Vector3 = center + basis * Vector3(-hx, -hy, -hz)
	var v100: Vector3 = center + basis * Vector3(hx, -hy, -hz)
	var v110: Vector3 = center + basis * Vector3(hx, hy, -hz)
	var v010: Vector3 = center + basis * Vector3(-hx, hy, -hz)
	var v001: Vector3 = center + basis * Vector3(-hx, -hy, hz)
	var v101: Vector3 = center + basis * Vector3(hx, -hy, hz)
	var v111: Vector3 = center + basis * Vector3(hx, hy, hz)
	var v011: Vector3 = center + basis * Vector3(-hx, hy, hz)

	# Dessus (+Y)
	_append_quad(st, v010, v110, v111, v011, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	# Dessous (-Y)
	_append_quad(st, v001, v101, v100, v000, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	# Avant (+Z)
	_append_quad(st, v011, v111, v101, v001, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	# ArriÃ¨re (-Z)
	_append_quad(st, v110, v010, v000, v100, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	# Droite (+X)
	_append_quad(st, v111, v110, v100, v101, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	# Gauche (-X)
	_append_quad(st, v010, v011, v001, v000, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))


static func _append_tapered_pole(st: SurfaceTool, p0: Vector3, p1: Vector3, r0: float, r1: float, radial_segs: int) -> void:
	var axis: Vector3 = p1 - p0
	var len_val: float = axis.length()
	if len_val < 0.001:
		return
	var dir: Vector3 = axis / len_val
	var up_ref: Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.92 else Vector3.RIGHT
	var side_x: Vector3 = dir.cross(up_ref).normalized()
	var side_z: Vector3 = side_x.cross(dir).normalized()

	for i in range(radial_segs):
		var t0: float = float(i) / float(radial_segs)
		var t1: float = float(i + 1) / float(radial_segs)
		var a0: float = t0 * TAU
		var a1: float = t1 * TAU
		var n0: Vector3 = side_x * cos(a0) + side_z * sin(a0)
		var n1: Vector3 = side_x * cos(a1) + side_z * sin(a1)

		var b0: Vector3 = p0 + n0 * r0
		var b1: Vector3 = p0 + n1 * r0
		var q0: Vector3 = p1 + n0 * r1
		var q1: Vector3 = p1 + n1 * r1

		_append_quad(st, q0, q1, b1, b0, Vector2(t0, 0.0), Vector2(t1, 0.0), Vector2(t1, len_val), Vector2(t0, len_val))
		_append_tri(st, p1, q1, q0, Vector2(0.5, 0.5), Vector2(t1, 0.0), Vector2(t0, 0.0))
		_append_tri(st, p0, b0, b1, Vector2(0.5, 0.5), Vector2(t0, 1.0), Vector2(t1, 1.0))
