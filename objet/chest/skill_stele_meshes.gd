@tool
class_name SkillSteleMeshes
extends RefCounted

## Générateur 3D procédural mis en cache pour la Petite Stèle de Compétences (style Moria / Fangorn) :
## - Socle à degrés en ardoise moussue (ancré à -0.35m sous y=0 pour ne jamais flotter sur les pentes)
## - Monolithe sculpté de la Moria (moria_weathered_stone.gdshader + bas-reliefs d'Ithildin) couronné d'un fronton en ogive
## - Colonnettes latérales ciselées + racines anciennes enlaçant le piédestal
## - Incrustation runique d'Ithildin (étoile de Durin + lignes de runes) et lucioles runiques qui s'apaisent après lecture.

const STONE_SHADER_PATH := "res://map/encounters/Boss_arena/gate_assets/moria_weathered_stone.gdshader"

const ARCH_DIFF_PATH := "res://map/encounters/Boss_arena/gate_assets/moria_arch_diff.jpg"
const ARCH_NOR_PATH := "res://map/encounters/Boss_arena/gate_assets/moria_arch_nor.jpg"
const ARCH_ROUGH_PATH := "res://map/encounters/Boss_arena/gate_assets/moria_arch_rough.jpg"

const PILLAR_DIFF_PATH := "res://map/encounters/Boss_arena/gate_assets/moria_pillar_diff.jpg"
const PILLAR_NOR_PATH := "res://map/encounters/Boss_arena/gate_assets/moria_pillar_nor.jpg"
const PILLAR_ROUGH_PATH := "res://map/encounters/Boss_arena/gate_assets/moria_pillar_rough.jpg"

const SLATE_DIFF_PATH := "res://map/encounters/Boss_arena/gate_assets/moria_slate_diff.jpg"
const SLATE_NOR_PATH := "res://map/encounters/Boss_arena/gate_assets/moria_slate_nor.jpg"
const SLATE_ROUGH_PATH := "res://map/encounters/Boss_arena/gate_assets/moria_slate_rough.jpg"

const BARK_DIFF_PATH := "res://assets/texture/bark_brown_text/bark_brown_02_diff_1k.jpg"
const BARK_NOR_PATH := "res://assets/texture/bark_brown_text/bark_brown_02_nor_gl_1k.jpg"
const BARK_ROUGH_PATH := "res://assets/texture/bark_brown_text/bark_brown_02_rough_1k.jpg"

const FLARE_TEX_PATH := "res://assets/LeLu's Noise Pack/T_flare8_vfx.png"

static var _mat_slate_base: Material = null
static var _mat_tablet_relief: Material = null
static var _mat_colonnettes: Material = null
static var _mat_roots: StandardMaterial3D = null
static var _mat_mote_particle: StandardMaterial3D = null

static var _cached_plinth_mesh: ArrayMesh = null
static var _cached_tablet_mesh: ArrayMesh = null
static var _cached_frame_mesh: ArrayMesh = null
static var _cached_roots_mesh: ArrayMesh = null
static var _cached_rune_inlay_mesh: ArrayMesh = null

static var _cached_lesser_plinth_mesh: ArrayMesh = null
static var _cached_lesser_tablet_mesh: ArrayMesh = null
static var _cached_lesser_frame_mesh: ArrayMesh = null
static var _cached_lesser_roots_mesh: ArrayMesh = null
static var _cached_lesser_rune_mesh: ArrayMesh = null


static func clear_caches() -> void:
	_mat_slate_base = null
	_mat_tablet_relief = null
	_mat_colonnettes = null
	_mat_roots = null
	_mat_mote_particle = null
	_cached_plinth_mesh = null
	_cached_tablet_mesh = null
	_cached_frame_mesh = null
	_cached_roots_mesh = null
	_cached_rune_inlay_mesh = null
	_cached_lesser_plinth_mesh = null
	_cached_lesser_tablet_mesh = null
	_cached_lesser_frame_mesh = null
	_cached_lesser_roots_mesh = null
	_cached_lesser_rune_mesh = null


static func build_stele_visual_root(node_name: String = "SteleVisual") -> Dictionary:
	_ensure_materials()
	_ensure_meshes()

	var root := Node3D.new()
	root.name = node_name

	var no_limit: bool = Engine.is_editor_hint()
	var vis_end: float = 0.0 if no_limit else 185.0
	var vis_margin: float = 0.0 if no_limit else 22.0

	# 1. Socle à degrés en ardoise moussue
	var plinth_mi := MeshInstance3D.new()
	plinth_mi.name = "SlatePlinth"
	plinth_mi.mesh = _cached_plinth_mesh
	plinth_mi.material_override = _mat_slate_base
	plinth_mi.visibility_range_end = vis_end
	plinth_mi.visibility_range_end_margin = vis_margin
	root.add_child(plinth_mi)

	# 2. Dalle centrale sculptée de la Moria
	var tablet_mi := MeshInstance3D.new()
	tablet_mi.name = "MoriaTablet"
	tablet_mi.mesh = _cached_tablet_mesh
	tablet_mi.material_override = _mat_tablet_relief
	tablet_mi.visibility_range_end = vis_end
	tablet_mi.visibility_range_end_margin = vis_margin
	root.add_child(tablet_mi)

	# 3. Colonnettes et fronton en ogive
	var frame_mi := MeshInstance3D.new()
	frame_mi.name = "CarvedFrame"
	frame_mi.mesh = _cached_frame_mesh
	frame_mi.material_override = _mat_colonnettes
	frame_mi.visibility_range_end = vis_end
	frame_mi.visibility_range_end_margin = vis_margin
	root.add_child(frame_mi)

	# 4. Racines noueuses de Fangorn enlaçant le socle
	var roots_mi := MeshInstance3D.new()
	roots_mi.name = "AncientRoots"
	roots_mi.mesh = _cached_roots_mesh
	roots_mi.material_override = _mat_roots
	roots_mi.visibility_range_end = vis_end
	roots_mi.visibility_range_end_margin = vis_margin
	root.add_child(roots_mi)

	# 5. Inscriptions d'Ithildin (matériau individuel par stèle pour pouvoir s'éteindre en douceur après réclamation)
	var rune_mat := StandardMaterial3D.new()
	rune_mat.albedo_color = Color(0.76, 0.86, 0.98, 1.0)
	rune_mat.metallic = 0.35
	rune_mat.roughness = 0.32
	rune_mat.emission_enabled = true
	rune_mat.emission = Color(0.46, 0.72, 1.0, 1.0)
	rune_mat.emission_energy_multiplier = 1.45

	var runes_mi := MeshInstance3D.new()
	runes_mi.name = "IthildinRunes"
	runes_mi.mesh = _cached_rune_inlay_mesh
	runes_mi.material_override = rune_mat
	runes_mi.visibility_range_end = vis_end
	runes_mi.visibility_range_end_margin = vis_margin
	root.add_child(runes_mi)

	# 6. Lueur douce lunaire d'Ithildin
	var stele_light := OmniLight3D.new()
	stele_light.name = "IthildinLight"
	stele_light.position = Vector3(0.0, 1.08, 0.0)
	stele_light.light_color = Color(0.54, 0.76, 1.0)
	stele_light.light_energy = 1.25
	stele_light.omni_range = 3.8
	stele_light.omni_attenuation = 1.4
	root.add_child(stele_light)

	# 7. Fines lucioles runiques flottantes autour de la stèle
	var motes := GPUParticles3D.new()
	motes.name = "IthildinMotes"
	motes.position = Vector3(0.0, 0.92, 0.0)
	motes.amount = 14
	motes.lifetime = 2.6
	motes.visibility_range_end = 55.0 if not no_limit else 0.0
	motes.material_override = _mat_mote_particle

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(0.36, 0.55, 0.24)
	pmat.direction = Vector3(0.0, 1.0, 0.0)
	pmat.spread = 22.0
	pmat.initial_velocity_min = 0.08
	pmat.initial_velocity_max = 0.24
	pmat.gravity = Vector3(0.0, 0.04, 0.0)
	pmat.scale_min = 0.035
	pmat.scale_max = 0.075
	pmat.color = Color(0.75, 1.15, 1.65, 0.88)
	motes.process_material = pmat

	var qm := QuadMesh.new()
	qm.size = Vector2(0.12, 0.12)
	motes.draw_pass_1 = qm
	root.add_child(motes)

	return {
		"root": root,
		"rune_material": rune_mat,
		"light": stele_light,
		"motes": motes
	}


## Variante plus compacte ("Petite Stèle" de bord de chemin, hauteur ~1.14m) dédiée au choix
## précoce entre 1 Attaque Tier I et 1 Sort Tier I, ornée de 2 runes Khuzdul jumelles.
static func build_lesser_stele_visual_root(node_name: String = "LesserSteleVisual") -> Dictionary:
	_ensure_materials()
	_ensure_lesser_meshes()

	var root := Node3D.new()
	root.name = node_name

	var no_limit: bool = Engine.is_editor_hint()
	var vis_end: float = 0.0 if no_limit else 165.0
	var vis_margin: float = 0.0 if no_limit else 20.0

	var plinth_mi := MeshInstance3D.new()
	plinth_mi.name = "LesserSlatePlinth"
	plinth_mi.mesh = _cached_lesser_plinth_mesh
	plinth_mi.material_override = _mat_slate_base
	plinth_mi.visibility_range_end = vis_end
	plinth_mi.visibility_range_end_margin = vis_margin
	root.add_child(plinth_mi)

	var tablet_mi := MeshInstance3D.new()
	tablet_mi.name = "LesserMoriaTablet"
	tablet_mi.mesh = _cached_lesser_tablet_mesh
	tablet_mi.material_override = _mat_tablet_relief
	tablet_mi.visibility_range_end = vis_end
	tablet_mi.visibility_range_end_margin = vis_margin
	root.add_child(tablet_mi)

	var frame_mi := MeshInstance3D.new()
	frame_mi.name = "LesserCarvedFrame"
	frame_mi.mesh = _cached_lesser_frame_mesh
	frame_mi.material_override = _mat_colonnettes
	frame_mi.visibility_range_end = vis_end
	frame_mi.visibility_range_end_margin = vis_margin
	root.add_child(frame_mi)

	var roots_mi := MeshInstance3D.new()
	roots_mi.name = "LesserAncientRoots"
	roots_mi.mesh = _cached_lesser_roots_mesh
	roots_mi.material_override = _mat_roots
	roots_mi.visibility_range_end = vis_end
	roots_mi.visibility_range_end_margin = vis_margin
	root.add_child(roots_mi)

	var rune_mat := StandardMaterial3D.new()
	rune_mat.albedo_color = Color(0.95, 0.88, 0.72, 1.0)
	rune_mat.metallic = 0.35
	rune_mat.roughness = 0.30
	rune_mat.emission_enabled = true
	rune_mat.emission = Color(0.96, 0.74, 0.38, 1.0)
	rune_mat.emission_energy_multiplier = 1.35

	var runes_mi := MeshInstance3D.new()
	runes_mi.name = "TwinRunes"
	runes_mi.mesh = _cached_lesser_rune_mesh
	runes_mi.material_override = rune_mat
	runes_mi.visibility_range_end = vis_end
	runes_mi.visibility_range_end_margin = vis_margin
	root.add_child(runes_mi)

	var stele_light := OmniLight3D.new()
	stele_light.name = "LesserSteleLight"
	stele_light.position = Vector3(0.0, 0.78, 0.0)
	stele_light.light_color = Color(0.96, 0.80, 0.50)
	stele_light.light_energy = 1.05
	stele_light.omni_range = 3.2
	stele_light.omni_attenuation = 1.4
	root.add_child(stele_light)

	var motes := GPUParticles3D.new()
	motes.name = "LesserSteleMotes"
	motes.position = Vector3(0.0, 0.68, 0.0)
	motes.amount = 10
	motes.lifetime = 2.4
	motes.visibility_range_end = 48.0 if not no_limit else 0.0
	motes.material_override = _mat_mote_particle

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(0.28, 0.38, 0.20)
	pmat.direction = Vector3(0.0, 1.0, 0.0)
	pmat.spread = 22.0
	pmat.initial_velocity_min = 0.07
	pmat.initial_velocity_max = 0.20
	pmat.gravity = Vector3(0.0, 0.04, 0.0)
	pmat.scale_min = 0.032
	pmat.scale_max = 0.068
	pmat.color = Color(1.45, 1.18, 0.72, 0.85)
	motes.process_material = pmat

	var qm := QuadMesh.new()
	qm.size = Vector2(0.11, 0.11)
	motes.draw_pass_1 = qm
	root.add_child(motes)

	return {
		"root": root,
		"rune_material": rune_mat,
		"light": stele_light,
		"motes": motes
	}


static func _ensure_lesser_meshes() -> void:
	if _cached_lesser_plinth_mesh != null and _cached_lesser_tablet_mesh != null and _cached_lesser_frame_mesh != null and _cached_lesser_roots_mesh != null and _cached_lesser_rune_mesh != null:
		return

	# 1. Socle bas biseauté avec jupe -0.38m sous y=0 (ne flotte jamais même sur pente forestière)
	var st_plinth := SurfaceTool.new()
	st_plinth.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_tapered_slab(st_plinth, -0.38, 0.10, Vector2(0.70, 0.44), Vector2(0.64, 0.39))
	_append_tapered_slab(st_plinth, 0.10, 0.21, Vector2(0.56, 0.34), Vector2(0.50, 0.29))
	st_plinth.generate_normals()
	st_plinth.generate_tangents()
	_cached_lesser_plinth_mesh = st_plinth.commit()

	# 2. Borne centrale trapue à double pan nain (hauteur ~1.12m)
	var st_tab := SurfaceTool.new()
	st_tab.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_tapered_slab(st_tab, 0.20, 0.90, Vector2(0.42, 0.18), Vector2(0.38, 0.16))
	_append_tapered_slab(st_tab, 0.90, 1.04, Vector2(0.38, 0.16), Vector2(0.24, 0.13))
	_append_tapered_slab(st_tab, 1.04, 1.12, Vector2(0.24, 0.13), Vector2(0.06, 0.09))
	st_tab.generate_normals()
	st_tab.generate_tangents()
	_cached_lesser_tablet_mesh = st_tab.commit()

	# 3. Contreforts latéraux bas et chapiteau nain
	var st_frame := SurfaceTool.new()
	st_frame.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side_s in [-1.0, 1.0]:
		_append_tube_segment(st_frame, Vector3(0.215 * side_s, 0.20, 0.0), Vector3(0.195 * side_s, 0.89, 0.0), 0.048, 0.040, 6)
		_append_oriented_box(st_frame, Vector3(0.215 * side_s, 0.23, 0.0), Basis.IDENTITY, Vector3(0.11, 0.06, 0.21))
		_append_oriented_box(st_frame, Vector3(0.195 * side_s, 0.90, 0.0), Basis.IDENTITY, Vector3(0.11, 0.06, 0.19))
		_append_tube_segment(st_frame, Vector3(0.205 * side_s, 0.91, 0.0), Vector3(0.0, 1.14, 0.0), 0.042, 0.034, 6)
	_append_oriented_box(st_frame, Vector3(0.0, 0.89, 0.0), Basis.IDENTITY, Vector3(0.45, 0.04, 0.19))
	var crest_basis := Basis(Vector3.FORWARD, PI * 0.25)
	_append_oriented_box(st_frame, Vector3(0.0, 1.15, 0.0), crest_basis, Vector3(0.075, 0.075, 0.10))
	st_frame.generate_normals()
	st_frame.generate_tangents()
	_cached_lesser_frame_mesh = st_frame.commit()

	# 4. Racines moussues enlaçant la petite stèle
	var st_roots := SurfaceTool.new()
	st_roots.begin(Mesh.PRIMITIVE_TRIANGLES)
	var root_paths: Array[Array] = [
		[Vector3(-0.36, -0.10, 0.22), Vector3(-0.28, 0.09, 0.18), Vector3(-0.22, 0.24, 0.10), Vector3(-0.19, 0.37, 0.04)],
		[Vector3(0.35, -0.10, 0.20), Vector3(0.27, 0.10, 0.17), Vector3(0.21, 0.26, 0.10), Vector3(0.18, 0.39, 0.03)],
		[Vector3(-0.33, -0.10, -0.21), Vector3(-0.26, 0.10, -0.17), Vector3(-0.20, 0.22, -0.10), Vector3(-0.17, 0.33, -0.04)],
		[Vector3(0.34, -0.10, -0.19), Vector3(0.26, 0.09, -0.16), Vector3(0.21, 0.21, -0.09), Vector3(0.18, 0.31, -0.03)]
	]
	for r_pts: Array in root_paths:
		for s_idx in range(r_pts.size() - 1):
			var r0: float = lerpf(0.046, 0.014, float(s_idx) / float(r_pts.size() - 1))
			var r1: float = lerpf(0.046, 0.010, float(s_idx + 1) / float(r_pts.size() - 1))
			_append_tube_segment(st_roots, r_pts[s_idx] as Vector3, r_pts[s_idx + 1] as Vector3, r0, r1, 6)
	st_roots.generate_normals()
	st_roots.generate_tangents()
	_cached_lesser_roots_mesh = st_roots.commit()

	# 5. Double gravure Khuzdul (Voie de l'Attaque à gauche + Voie du Sort à droite) sur les deux faces
	var st_runes := SurfaceTool.new()
	st_runes.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z_sign in [-1.0, 1.0]:
		var z_face: float = 0.088 * z_sign
		var z_r: float = z_face + 0.004 * z_sign
		var seal_center := Vector3(0.0, 0.74, z_r)

		# Petit sceau losange supérieur à 4 rayons
		var ring_r: float = 0.095
		var d_pts: Array[Vector3] = [
			seal_center + Vector3(0.0, ring_r, 0.0),
			seal_center + Vector3(ring_r, 0.0, 0.0),
			seal_center + Vector3(0.0, -ring_r, 0.0),
			seal_center + Vector3(-ring_r, 0.0, 0.0)
		]
		for di in range(4):
			_append_tube_segment(st_runes, d_pts[di], d_pts[(di + 1) % 4], 0.0065, 0.0065, 4)
		_append_oriented_box(st_runes, seal_center, Basis.IDENTITY, Vector3(0.13, 0.012, 0.012))
		_append_oriented_box(st_runes, seal_center, Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.13, 0.012, 0.012))

		# Rune gauche : glyphe martial (lame/hallebarde croisée)
		var lx: float = -0.078
		_append_tube_segment(st_runes, Vector3(lx, 0.36, z_r), Vector3(lx, 0.58, z_r), 0.006, 0.006, 4)
		_append_tube_segment(st_runes, Vector3(lx - 0.036, 0.51, z_r), Vector3(lx + 0.036, 0.56, z_r), 0.005, 0.005, 4)
		_append_tube_segment(st_runes, Vector3(lx - 0.032, 0.44, z_r), Vector3(lx + 0.032, 0.44, z_r), 0.005, 0.005, 4)

		# Rune droite : glyphe arcanique (foyer runique ouvert)
		var rx: float = 0.078
		_append_tube_segment(st_runes, Vector3(rx, 0.36, z_r), Vector3(rx, 0.58, z_r), 0.006, 0.006, 4)
		_append_tube_segment(st_runes, Vector3(rx - 0.035, 0.53, z_r), Vector3(rx, 0.58, z_r), 0.005, 0.005, 4)
		_append_tube_segment(st_runes, Vector3(rx + 0.035, 0.53, z_r), Vector3(rx, 0.58, z_r), 0.005, 0.005, 4)
		_append_tube_segment(st_runes, Vector3(rx, 0.46, z_r), Vector3(rx + 0.034, 0.41, z_r), 0.005, 0.005, 4)

	st_runes.generate_normals()
	st_runes.generate_tangents()
	_cached_lesser_rune_mesh = st_runes.commit()


static func _ensure_materials() -> void:
	var stone_shader: Shader = load(STONE_SHADER_PATH) as Shader if ResourceLoader.exists(STONE_SHADER_PATH) else null

	if _mat_slate_base == null:
		if stone_shader != null and ResourceLoader.exists(SLATE_DIFF_PATH):
			var sm := ShaderMaterial.new()
			sm.shader = stone_shader
			sm.set_shader_parameter("albedo_tex", load(SLATE_DIFF_PATH))
			sm.set_shader_parameter("normal_tex", load(SLATE_NOR_PATH))
			sm.set_shader_parameter("roughness_tex", load(SLATE_ROUGH_PATH))
			sm.set_shader_parameter("stone_tint", Color(1.12, 1.16, 1.22, 1.0))
			sm.set_shader_parameter("engraving_contrast", 0.22)
			sm.set_shader_parameter("normal_strength", 1.45)
			sm.set_shader_parameter("ground_moss_height", 0.34)
			sm.set_shader_parameter("ground_moss_strength", 0.62)
			sm.set_shader_parameter("ithildin_sheen", 0.04)
			_mat_slate_base = sm
		else:
			var std := StandardMaterial3D.new()
			std.albedo_color = Color(0.26, 0.28, 0.32)
			std.roughness = 0.90
			_mat_slate_base = std

	if _mat_tablet_relief == null:
		if stone_shader != null and ResourceLoader.exists(ARCH_DIFF_PATH):
			var tm := ShaderMaterial.new()
			tm.shader = stone_shader
			tm.set_shader_parameter("albedo_tex", load(ARCH_DIFF_PATH))
			tm.set_shader_parameter("normal_tex", load(ARCH_NOR_PATH))
			tm.set_shader_parameter("roughness_tex", load(ARCH_ROUGH_PATH))
			tm.set_shader_parameter("stone_tint", Color(1.20, 1.25, 1.34, 1.0))
			tm.set_shader_parameter("engraving_contrast", 0.85)
			tm.set_shader_parameter("normal_strength", 1.75)
			tm.set_shader_parameter("ground_moss_height", 0.42)
			tm.set_shader_parameter("ground_moss_strength", 0.28)
			tm.set_shader_parameter("ithildin_sheen", 0.14)
			_mat_tablet_relief = tm
		else:
			var std_t := StandardMaterial3D.new()
			std_t.albedo_color = Color(0.36, 0.40, 0.46)
			std_t.roughness = 0.82
			_mat_tablet_relief = std_t

	if _mat_colonnettes == null:
		if stone_shader != null and ResourceLoader.exists(PILLAR_DIFF_PATH):
			var pm := ShaderMaterial.new()
			pm.shader = stone_shader
			pm.set_shader_parameter("albedo_tex", load(PILLAR_DIFF_PATH))
			pm.set_shader_parameter("normal_tex", load(PILLAR_NOR_PATH))
			pm.set_shader_parameter("roughness_tex", load(PILLAR_ROUGH_PATH))
			pm.set_shader_parameter("stone_tint", Color(1.18, 1.22, 1.30, 1.0))
			pm.set_shader_parameter("engraving_contrast", 0.74)
			pm.set_shader_parameter("normal_strength", 1.65)
			pm.set_shader_parameter("ground_moss_height", 0.46)
			pm.set_shader_parameter("ground_moss_strength", 0.35)
			pm.set_shader_parameter("ithildin_sheen", 0.09)
			_mat_colonnettes = pm
		else:
			_mat_colonnettes = _mat_slate_base

	if _mat_roots == null:
		_mat_roots = StandardMaterial3D.new()
		_mat_roots.albedo_color = Color(0.50, 0.40, 0.30)
		if ResourceLoader.exists(BARK_DIFF_PATH):
			_mat_roots.albedo_texture = load(BARK_DIFF_PATH) as Texture2D
		if ResourceLoader.exists(BARK_NOR_PATH):
			_mat_roots.normal_enabled = true
			_mat_roots.normal_scale = 1.35
			_mat_roots.normal_texture = load(BARK_NOR_PATH) as Texture2D
		if ResourceLoader.exists(BARK_ROUGH_PATH):
			_mat_roots.roughness_texture = load(BARK_ROUGH_PATH) as Texture2D
		else:
			_mat_roots.roughness = 0.92

	if _mat_mote_particle == null:
		_mat_mote_particle = StandardMaterial3D.new()
		_mat_mote_particle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_mote_particle.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mat_mote_particle.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_mote_particle.vertex_color_use_as_albedo = true
		_mat_mote_particle.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_mat_mote_particle.billboard_keep_scale = true
		if ResourceLoader.exists(FLARE_TEX_PATH):
			_mat_mote_particle.albedo_texture = load(FLARE_TEX_PATH) as Texture2D


static func _ensure_meshes() -> void:
	if _cached_plinth_mesh != null and _cached_tablet_mesh != null and _cached_frame_mesh != null and _cached_roots_mesh != null and _cached_rune_inlay_mesh != null:
		return

	# 1. Socle à 2 degrés biseautés (avec jupe -0.35m sous terre)
	var st_plinth := SurfaceTool.new()
	st_plinth.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_tapered_slab(st_plinth, -0.35, 0.13, Vector2(0.92, 0.56), Vector2(0.86, 0.50))
	_append_tapered_slab(st_plinth, 0.13, 0.27, Vector2(0.76, 0.44), Vector2(0.68, 0.38))
	st_plinth.generate_normals()
	st_plinth.generate_tangents()
	_cached_plinth_mesh = st_plinth.commit()

	# 2. Monolithe central sculpté + couronnement en arche brisée de la Moria (hauteur 1.62m)
	var st_tab := SurfaceTool.new()
	st_tab.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_tapered_slab(st_tab, 0.26, 1.32, Vector2(0.56, 0.22), Vector2(0.50, 0.19))
	_append_tapered_slab(st_tab, 1.32, 1.50, Vector2(0.50, 0.19), Vector2(0.32, 0.16))
	_append_tapered_slab(st_tab, 1.50, 1.62, Vector2(0.32, 0.16), Vector2(0.07, 0.11))
	st_tab.generate_normals()
	st_tab.generate_tangents()
	_cached_tablet_mesh = st_tab.commit()

	# 3. Colonnettes latérales ciselées, chapiteaux nains & bordures de fronton
	var st_frame := SurfaceTool.new()
	st_frame.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side_s in [-1.0, 1.0]:
		# Colonnette octogonale
		_append_tube_segment(st_frame, Vector3(0.285 * side_s, 0.26, 0.0), Vector3(0.260 * side_s, 1.31, 0.0), 0.064, 0.054, 8)
		# Base et chapiteau taillés
		_append_oriented_box(st_frame, Vector3(0.285 * side_s, 0.30, 0.0), Basis.IDENTITY, Vector3(0.15, 0.08, 0.27))
		_append_oriented_box(st_frame, Vector3(0.260 * side_s, 1.32, 0.0), Basis.IDENTITY, Vector3(0.15, 0.08, 0.25))
		# Rampant d'ogive jusqu'au sommet (y = 1.64m)
		_append_tube_segment(st_frame, Vector3(0.275 * side_s, 1.33, 0.0), Vector3(0.0, 1.64, 0.0), 0.056, 0.046, 6)

	# Linteau horizontal fin et fleuron sommital nain en losange
	_append_oriented_box(st_frame, Vector3(0.0, 1.31, 0.0), Basis.IDENTITY, Vector3(0.60, 0.05, 0.24))
	var diamond_basis := Basis(Vector3.FORWARD, PI * 0.25)
	_append_oriented_box(st_frame, Vector3(0.0, 1.66, 0.0), diamond_basis, Vector3(0.10, 0.10, 0.13))
	st_frame.generate_normals()
	st_frame.generate_tangents()
	_cached_frame_mesh = st_frame.commit()

	# 4. 4 Racines noueuses enlaçant la base de pierre
	var st_roots := SurfaceTool.new()
	st_roots.begin(Mesh.PRIMITIVE_TRIANGLES)
	var root_paths: Array[Array] = [
		[Vector3(-0.48, -0.10, 0.28), Vector3(-0.38, 0.12, 0.24), Vector3(-0.30, 0.32, 0.14), Vector3(-0.27, 0.50, 0.06)],
		[Vector3(0.47, -0.10, 0.26), Vector3(0.37, 0.14, 0.22), Vector3(0.29, 0.35, 0.13), Vector3(0.25, 0.54, 0.04)],
		[Vector3(-0.44, -0.10, -0.27), Vector3(-0.35, 0.13, -0.22), Vector3(-0.28, 0.30, -0.13), Vector3(-0.24, 0.44, -0.05)],
		[Vector3(0.45, -0.10, -0.25), Vector3(0.36, 0.11, -0.21), Vector3(0.29, 0.28, -0.12), Vector3(0.26, 0.42, -0.04)]
	]
	for r_pts: Array in root_paths:
		for s_idx in range(r_pts.size() - 1):
			var r0: float = lerpf(0.058, 0.016, float(s_idx) / float(r_pts.size() - 1))
			var r1: float = lerpf(0.058, 0.012, float(s_idx + 1) / float(r_pts.size() - 1))
			_append_tube_segment(st_roots, r_pts[s_idx] as Vector3, r_pts[s_idx + 1] as Vector3, r0, r1, 6)
	st_roots.generate_normals()
	st_roots.generate_tangents()
	_cached_roots_mesh = st_roots.commit()

	# 5. Gravures lumineuses d'Ithildin sur les deux faces (+Z et -Z) : Étoile de Durin + Losange sacré + 3 stèles/lignes runiques
	var st_runes := SurfaceTool.new()
	st_runes.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z_sign in [-1.0, 1.0]:
		var z_face: float = 0.106 * z_sign
		var star_center := Vector3(0.0, 1.06, z_face)

		# Étoile à 8 branches d'Ithildin
		for ray_i in range(4):
			var ang: float = float(ray_i) * (PI * 0.25)
			var b_ray := Basis(Vector3.FORWARD, ang)
			var ray_len: float = 0.25 if (ray_i % 2 == 0) else 0.17
			_append_oriented_box(st_runes, star_center, b_ray, Vector3(ray_len, 0.015, 0.014))

		# Cadre losange nain autour de l'étoile
		var ring_r: float = 0.155
		var d_pts: Array[Vector3] = [
			star_center + Vector3(0.0, ring_r, 0.0),
			star_center + Vector3(ring_r, 0.0, 0.0),
			star_center + Vector3(0.0, -ring_r, 0.0),
			star_center + Vector3(-ring_r, 0.0, 0.0)
		]
		for di in range(4):
			_append_tube_segment(st_runes, d_pts[di], d_pts[(di + 1) % 4], 0.008, 0.008, 4)

		# 3 Fines silhouettes runiques Khuzdul (traits fins ciselés d'Ithildin évoquant les 3 choix de compétences)
		for col_i in [-1, 0, 1]:
			var gx: float = float(col_i) * 0.135
			var gy_bot: float = 0.54 + (0.025 if col_i == 0 else 0.0)
			var gy_top: float = gy_bot + 0.23
			var z_r: float = z_face + 0.004 * z_sign
			# Hampe verticale runique
			_append_tube_segment(st_runes, Vector3(gx, gy_bot, z_r), Vector3(gx, gy_top, z_r), 0.0065, 0.0065, 4)
			# Branches angulaires Khuzdul distinctes sur chacune des 3 runes
			if col_i == -1:
				_append_tube_segment(st_runes, Vector3(gx, gy_top - 0.03, z_r), Vector3(gx + 0.042, gy_top - 0.085, z_r), 0.0055, 0.0055, 4)
				_append_tube_segment(st_runes, Vector3(gx, gy_bot + 0.10, z_r), Vector3(gx - 0.040, gy_bot + 0.045, z_r), 0.0055, 0.0055, 4)
			elif col_i == 0:
				_append_tube_segment(st_runes, Vector3(gx - 0.044, gy_top - 0.055, z_r), Vector3(gx, gy_top, z_r), 0.0055, 0.0055, 4)
				_append_tube_segment(st_runes, Vector3(gx + 0.044, gy_top - 0.055, z_r), Vector3(gx, gy_top, z_r), 0.0055, 0.0055, 4)
				_append_tube_segment(st_runes, Vector3(gx - 0.036, gy_bot + 0.08, z_r), Vector3(gx + 0.036, gy_bot + 0.13, z_r), 0.0055, 0.0055, 4)
			else:
				_append_tube_segment(st_runes, Vector3(gx, gy_top - 0.02, z_r), Vector3(gx - 0.042, gy_top - 0.075, z_r), 0.0055, 0.0055, 4)
				_append_tube_segment(st_runes, Vector3(gx - 0.042, gy_top - 0.075, z_r), Vector3(gx, gy_bot + 0.085, z_r), 0.0055, 0.0055, 4)

	st_runes.generate_normals()
	st_runes.generate_tangents()
	_cached_rune_inlay_mesh = st_runes.commit()


# =========================================================================
# PRIMITIVES GÉOMÉTRIQUES
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


static func _append_tapered_slab(st: SurfaceTool, y0: float, y1: float, size_bot: Vector2, size_top: Vector2) -> void:
	var bx: float = size_bot.x * 0.5
	var bz: float = size_bot.y * 0.5
	var tx: float = size_top.x * 0.5
	var tz: float = size_top.y * 0.5

	var b00 := Vector3(-bx, y0, -bz)
	var b10 := Vector3(bx, y0, -bz)
	var b11 := Vector3(bx, y0, bz)
	var b01 := Vector3(-bx, y0, bz)

	var t00 := Vector3(-tx, y1, -tz)
	var t10 := Vector3(tx, y1, -tz)
	var t11 := Vector3(tx, y1, tz)
	var t01 := Vector3(-tx, y1, tz)

	var v0: float = 1.0 - clampf(y0 / 1.65, 0.0, 1.0)
	var v1: float = 1.0 - clampf(y1 / 1.65, 0.0, 1.0)

	# Avant (+Z) & Arrière (-Z)
	_append_quad(st, t01, t11, b11, b01, Vector2(0.15, v1), Vector2(0.85, v1), Vector2(0.85, v0), Vector2(0.15, v0))
	_append_quad(st, t10, t00, b00, b10, Vector2(0.15, v1), Vector2(0.85, v1), Vector2(0.85, v0), Vector2(0.15, v0))
	# Droite (+X) & Gauche (-X)
	_append_quad(st, t11, t10, b10, b11, Vector2(0.0, v1), Vector2(0.35, v1), Vector2(0.35, v0), Vector2(0.0, v0))
	_append_quad(st, t00, t01, b01, b00, Vector2(0.0, v1), Vector2(0.35, v1), Vector2(0.35, v0), Vector2(0.0, v0))
	# Dessus (+Y) & Dessous (-Y)
	_append_quad(st, t00, t10, t11, t01, Vector2(0.2, 0.2), Vector2(0.8, 0.2), Vector2(0.8, 0.8), Vector2(0.2, 0.8))
	_append_quad(st, b01, b11, b10, b00, Vector2(0.2, 0.2), Vector2(0.8, 0.2), Vector2(0.8, 0.8), Vector2(0.2, 0.8))


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

	_append_quad(st, v010, v110, v111, v011, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	_append_quad(st, v001, v101, v100, v000, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	_append_quad(st, v011, v111, v101, v001, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	_append_quad(st, v110, v010, v000, v100, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	_append_quad(st, v111, v110, v100, v101, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	_append_quad(st, v010, v011, v001, v000, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))


static func _append_tube_segment(st: SurfaceTool, p0: Vector3, p1: Vector3, r0: float, r1: float, radial_segs: int) -> void:
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
