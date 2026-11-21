@tool
class_name MoriaGateMeshes
extends RefCounted

## Générateur de géométrie 3D architecturale et organique pour la Porte du Boss (Style Moria / LOTR) :
## - Arche creuse en pierre sculptée (tympan cintré avec Couronne de Durin, 7 étoiles, runes usées et arbres jumeaux)
## - Piliers monumentaux sculptés en bas-relief sur socles à degrés, chapiteaux, corniche et murets en ruine
## - Lianes et racines noueuses ancrées à leur base (compatibles avec root_shader.tres : UV.x = 0.03 -> 0.97)

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

const ROOT_SHADER_PATH := "res://objet/forest_interactables/fangorn_root.gdshader"
const BARK_A_DIFF := "res://assets/texture/bark_brown_text/bark_brown_02_diff_1k.jpg"
const BARK_A_NOR := "res://assets/texture/bark_brown_text/bark_brown_02_nor_gl_1k.jpg"
const BARK_A_ROUGH := "res://assets/texture/bark_brown_text/bark_brown_02_rough_1k.jpg"

const BARK_B_DIFF := "res://assets/texture/tree_root_text/fever_tree_bark_diff_1k.jpg"
const BARK_B_NOR := "res://assets/texture/tree_root_text/fever_tree_bark_nor_gl_1k.jpg"
const BARK_B_ARM := "res://assets/texture/tree_root_text/fever_tree_bark_arm_1k.jpg"

static var _arch_mat: ShaderMaterial = null
static var _pillar_mat: ShaderMaterial = null
static var _slate_mat: ShaderMaterial = null
static var _slate_upper_mat: ShaderMaterial = null
static var _root_profile_curve: Curve = null


static func clear_caches() -> void:
	_arch_mat = null
	_pillar_mat = null
	_slate_mat = null
	_slate_upper_mat = null
	_root_profile_curve = null


static func _get_shader_radius_curve() -> Curve:
	if _root_profile_curve != null:
		return _root_profile_curve
	# Profil identique à Curve_radius_profile dans root_shader.tres afin que force_pincement_ referme
	# chaque racine en pointe conique pleine parfaite (0 ouverture creuse) quel que soit debut/fin.
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.0), 0.0, 4.0)
	c.add_point(Vector2(0.05, 0.28), 5.0, 6.0)
	c.add_point(Vector2(0.10, 0.82), 6.0, 2.0)
	c.add_point(Vector2(0.18, 0.96), 0.5, 0.2)
	c.add_point(Vector2(0.30, 1.0), 0.0, 0.0)
	c.add_point(Vector2(0.75, 0.90), -0.3, -0.6)
	c.add_point(Vector2(0.88, 0.75), -1.8, -3.0)
	c.add_point(Vector2(0.95, 0.36), -6.5, -6.5)
	c.add_point(Vector2(1.0, 0.0), -5.0, 0.0)
	c.bake()
	_root_profile_curve = c
	return _root_profile_curve


# =========================================================================
# MATÉRIAUX PBR PIERRE DE LA MORIA & RACINES
# =========================================================================
static func get_arch_relief_material() -> ShaderMaterial:
	if _arch_mat != null:
		return _arch_mat
	var mat := ShaderMaterial.new()
	mat.shader = load(STONE_SHADER_PATH) as Shader
	mat.set_shader_parameter("albedo_tex", load(ARCH_DIFF_PATH))
	mat.set_shader_parameter("normal_tex", load(ARCH_NOR_PATH))
	mat.set_shader_parameter("roughness_tex", load(ARCH_ROUGH_PATH))
	mat.set_shader_parameter("stone_tint", Color(1.24, 1.28, 1.35, 1.0))
	mat.set_shader_parameter("engraving_contrast", 0.76)
	mat.set_shader_parameter("normal_strength", 1.75)
	mat.set_shader_parameter("ground_moss_height", 0.4)
	mat.set_shader_parameter("ground_moss_strength", 0.12)
	mat.set_shader_parameter("ithildin_sheen", 0.085)
	_arch_mat = mat
	return _arch_mat


static func get_pillar_relief_material() -> ShaderMaterial:
	if _pillar_mat != null:
		return _pillar_mat
	var mat := ShaderMaterial.new()
	mat.shader = load(STONE_SHADER_PATH) as Shader
	mat.set_shader_parameter("albedo_tex", load(PILLAR_DIFF_PATH))
	mat.set_shader_parameter("normal_tex", load(PILLAR_NOR_PATH))
	mat.set_shader_parameter("roughness_tex", load(PILLAR_ROUGH_PATH))
	mat.set_shader_parameter("stone_tint", Color(1.24, 1.28, 1.35, 1.0))
	mat.set_shader_parameter("engraving_contrast", 0.72)
	mat.set_shader_parameter("normal_strength", 1.70)
	mat.set_shader_parameter("ground_moss_height", 1.55)
	mat.set_shader_parameter("ground_moss_strength", 0.44)
	mat.set_shader_parameter("ithildin_sheen", 0.07)
	_pillar_mat = mat
	return _pillar_mat


static func get_slate_masonry_material(upper_element: bool = false) -> ShaderMaterial:
	if upper_element and _slate_upper_mat != null:
		return _slate_upper_mat
	if not upper_element and _slate_mat != null:
		return _slate_mat
	var mat := ShaderMaterial.new()
	mat.shader = load(STONE_SHADER_PATH) as Shader
	mat.set_shader_parameter("albedo_tex", load(SLATE_DIFF_PATH))
	mat.set_shader_parameter("normal_tex", load(SLATE_NOR_PATH))
	mat.set_shader_parameter("roughness_tex", load(SLATE_ROUGH_PATH))
	mat.set_shader_parameter("stone_tint", Color(1.15, 1.19, 1.24, 1.0))
	mat.set_shader_parameter("engraving_contrast", 0.14)
	mat.set_shader_parameter("normal_strength", 1.40)
	mat.set_shader_parameter("ground_moss_height", 0.25 if upper_element else 1.85)
	mat.set_shader_parameter("ground_moss_strength", 0.08 if upper_element else 0.55)
	mat.set_shader_parameter("ithildin_sheen", 0.01)
	if upper_element:
		_slate_upper_mat = mat
	else:
		_slate_mat = mat
	return mat


static func create_vine_root_material(
	use_secondary_bark: bool = false,
	tint: Color = Color(0.50, 0.44, 0.32, 1.0),
	base_radius: float = 0.28,
	length_meters: float = 7.5
) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(ROOT_SHADER_PATH) as Shader
	mat.set_shader_parameter("fin", 0.0)
	mat.set_shader_parameter("debut", 1.0)
	mat.set_shader_parameter("smoth_step", 0.008)
	mat.set_shader_parameter("smoth_step_sommet", 0.14)
	# Pincement calé sur le rayon réel du tube => l'extrémité qui se rétracte se pince jusqu'à rayon 0 (jamais de tube ouvert)
	mat.set_shader_parameter("force_pincement_", base_radius * 1.06)
	# Alignement longitudinal des fibres d'écorce + répétition métrique naturelle (au lieu de x100)
	mat.set_shader_parameter("align_bark_uv", 1.0)
	var circ_repeats := float(maxi(1, roundi((TAU * base_radius) / 1.15)))
	var len_repeats := clampf(length_meters / 2.2, 1.2, 5.0)
	mat.set_shader_parameter("uv_scale", Vector2(circ_repeats, len_repeats))
	mat.set_shader_parameter("ColorParameter", tint)
	mat.set_shader_parameter("normal_strength", 1.25)
	if use_secondary_bark and ResourceLoader.exists(BARK_B_DIFF):
		mat.set_shader_parameter("root_texture", load(BARK_B_DIFF))
		if ResourceLoader.exists(BARK_B_ARM):
			mat.set_shader_parameter("arm_text", load(BARK_B_ARM))
		if ResourceLoader.exists(BARK_B_NOR):
			mat.set_shader_parameter("normal_text", load(BARK_B_NOR))
	else:
		if ResourceLoader.exists(BARK_A_DIFF):
			mat.set_shader_parameter("root_texture", load(BARK_A_DIFF))
		if ResourceLoader.exists(BARK_A_ROUGH):
			mat.set_shader_parameter("arm_text", load(BARK_A_ROUGH))
		if ResourceLoader.exists(BARK_A_NOR):
			mat.set_shader_parameter("normal_text", load(BARK_A_NOR))
	return mat


# =========================================================================
# OUTILS BAS NIVEAU SURFACETOOL (GARANTIE WINDING EXTERNE CLOCKWISE GODOT 4)
# =========================================================================
static func _emit_tri_outward(
	st: SurfaceTool,
	a: Vector3, b: Vector3, c: Vector3,
	uva: Vector2, uvb: Vector2, uvc: Vector2,
	outward_n: Vector3
) -> void:
	var n := outward_n.normalized()
	# En Godot 4, l'ordre avant (cull_back) vérifie (c - a).cross(b - a).dot(n) > 0
	var test := (c - a).cross(b - a).dot(n)
	if test >= 0.0:
		st.set_normal(n); st.set_uv(uva); st.add_vertex(a)
		st.set_normal(n); st.set_uv(uvb); st.add_vertex(b)
		st.set_normal(n); st.set_uv(uvc); st.add_vertex(c)
	else:
		st.set_normal(n); st.set_uv(uva); st.add_vertex(a)
		st.set_normal(n); st.set_uv(uvc); st.add_vertex(c)
		st.set_normal(n); st.set_uv(uvb); st.add_vertex(b)


static func _emit_quad_outward(
	st: SurfaceTool,
	v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3,
	uv0: Vector2, uv1: Vector2, uv2: Vector2, uv3: Vector2,
	outward_n: Vector3
) -> void:
	_emit_tri_outward(st, v0, v1, v2, uv0, uv1, uv2, outward_n)
	_emit_tri_outward(st, v0, v2, v3, uv0, uv2, uv3, outward_n)


static func _planar_uv(p: Vector3, n: Vector3, scale_uv: float = 0.26) -> Vector2:
	var an := n.abs()
	if an.z >= an.x and an.z >= an.y:
		return Vector2(p.x * scale_uv, -p.y * scale_uv)
	elif an.x >= an.y:
		return Vector2(p.z * scale_uv, -p.y * scale_uv)
	else:
		return Vector2(p.x * scale_uv, p.z * scale_uv)


static func _emit_quad_auto_uv(
	st: SurfaceTool,
	v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3,
	outward_n: Vector3,
	scale_uv: float = 0.26
) -> void:
	_emit_quad_outward(
		st, v0, v1, v2, v3,
		_planar_uv(v0, outward_n, scale_uv),
		_planar_uv(v1, outward_n, scale_uv),
		_planar_uv(v2, outward_n, scale_uv),
		_planar_uv(v3, outward_n, scale_uv),
		outward_n
	)


# =========================================================================
# 1. BLOCS DE MAÇONNERIE CHANFREINÉS (SOCLES, CHAPITEAUX, CORNICHE, MURETS)
# =========================================================================
static func build_chamfered_stone_block(
	size: Vector3,
	top_inset: float = 0.14,
	bevel_h: float = 0.14,
	uv_scale: float = 0.26,
	upper_element: bool = false
) -> ArrayMesh:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var y0 := 0.0
	var y_mid := maxf(0.02, size.y - bevel_h)
	var y1 := size.y
	var tx := maxf(0.05, hx - top_inset)
	var tz := maxf(0.05, hz - top_inset)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 4 faces verticales basses
	var b_fl := Vector3(-hx, y0, hz)
	var b_fr := Vector3(hx, y0, hz)
	var b_br := Vector3(hx, y0, -hz)
	var b_bl := Vector3(-hx, y0, -hz)

	var m_fl := Vector3(-hx, y_mid, hz)
	var m_fr := Vector3(hx, y_mid, hz)
	var m_br := Vector3(hx, y_mid, -hz)
	var m_bl := Vector3(-hx, y_mid, -hz)

	var t_fl := Vector3(-tx, y1, tz)
	var t_fr := Vector3(tx, y1, tz)
	var t_br := Vector3(tx, y1, -tz)
	var t_bl := Vector3(-tx, y1, -tz)

	_emit_quad_auto_uv(st, m_fl, m_fr, b_fr, b_fl, Vector3(0, 0, 1), uv_scale)
	_emit_quad_auto_uv(st, m_br, m_bl, b_bl, b_br, Vector3(0, 0, -1), uv_scale)
	_emit_quad_auto_uv(st, m_bl, m_fl, b_fl, b_bl, Vector3(-1, 0, 0), uv_scale)
	_emit_quad_auto_uv(st, m_fr, m_br, b_br, b_fr, Vector3(1, 0, 0), uv_scale)

	# 4 chanfreins supérieurs
	var n_front := Vector3(0, top_inset, bevel_h).normalized()
	var n_back := Vector3(0, top_inset, -bevel_h).normalized()
	var n_left := Vector3(-bevel_h, top_inset, 0).normalized()
	var n_right := Vector3(bevel_h, top_inset, 0).normalized()

	_emit_quad_auto_uv(st, t_fl, t_fr, m_fr, m_fl, n_front, uv_scale)
	_emit_quad_auto_uv(st, t_br, t_bl, m_bl, m_br, n_back, uv_scale)
	_emit_quad_auto_uv(st, t_bl, t_fl, m_fl, m_bl, n_left, uv_scale)
	_emit_quad_auto_uv(st, t_fr, t_br, m_br, m_fr, n_right, uv_scale)

	# Dessus & dessous
	_emit_quad_auto_uv(st, t_bl, t_br, t_fr, t_fl, Vector3(0, 1, 0), uv_scale)
	_emit_quad_auto_uv(st, b_fl, b_fr, b_br, b_bl, Vector3(0, -1, 0), uv_scale)

	st.generate_tangents()
	st.set_material(get_slate_masonry_material(upper_element))
	return st.commit()


# =========================================================================
# 2. FÛT DE PILIER SCULPTÉ (BAS-RELIEF ARBRE DE MORIA AVANT & ARRIÈRE)
# =========================================================================
static func build_carved_pillar_shaft(
	width: float = 3.40,
	height: float = 6.09,
	depth: float = 2.40,
	mirror_u: bool = false
) -> ArrayMesh:
	var hx := width * 0.5
	var hz := depth * 0.5
	var cham := 0.18 # Chanfrein d'angle architectural

	var mesh := ArrayMesh.new()

	# --- Surface 0 : Corps en pierre d'ardoise chanfreiné ---
	var st_stone := SurfaceTool.new()
	st_stone.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Profil octogonal irrégulier (8 sommets au sol et 8 au sommet)
	var ring := [
		Vector2(-hx + cham, hz),
		Vector2(hx - cham, hz),
		Vector2(hx, hz - cham),
		Vector2(hx, -hz + cham),
		Vector2(hx - cham, -hz),
		Vector2(-hx + cham, -hz),
		Vector2(-hx, -hz + cham),
		Vector2(-hx, hz - cham)
	]
	for i in range(8):
		var p0: Vector2 = ring[i]
		var p1: Vector2 = ring[(i + 1) % 8]
		# Évite de doubler les grandes faces avant (i=0) et arrière (i=4) qui portent les bas-reliefs
		if i == 0 or i == 4:
			continue
		var edge := p1 - p0
		var out2d := Vector2(edge.y, -edge.x).normalized()
		# Corrige le sens sortant par produit scalaire avec le centre du segment
		var mid := (p0 + p1) * 0.5
		if out2d.dot(mid) < 0.0:
			out2d = -out2d
		var out3 := Vector3(out2d.x, 0.0, out2d.y)
		var v_tl := Vector3(p0.x, height, p0.y)
		var v_tr := Vector3(p1.x, height, p1.y)
		var v_br := Vector3(p1.x, 0.0, p1.y)
		var v_bl := Vector3(p0.x, 0.0, p0.y)
		_emit_quad_auto_uv(st_stone, v_tl, v_tr, v_br, v_bl, out3, 0.28)

	# Capots haut et bas simplifiés
	_emit_quad_auto_uv(
		st_stone,
		Vector3(-hx, height, -hz), Vector3(hx, height, -hz),
		Vector3(hx, height, hz), Vector3(-hx, height, hz),
		Vector3.UP, 0.28
	)
	_emit_quad_auto_uv(
		st_stone,
		Vector3(-hx, 0.0, hz), Vector3(hx, 0.0, hz),
		Vector3(hx, 0.0, -hz), Vector3(-hx, 0.0, -hz),
		Vector3.DOWN, 0.28
	)
	st_stone.generate_tangents()
	st_stone.set_material(get_slate_masonry_material(false))
	st_stone.commit(mesh)

	# --- Surface 1 : Stèles sculptées de l'Arbre de la Moria (faces +Z et -Z) ---
	var st_rel := SurfaceTool.new()
	st_rel.begin(Mesh.PRIMITIVE_TRIANGLES)
	var u0 := 1.0 if mirror_u else 0.0
	var u1 := 0.0 if mirror_u else 1.0
	var rx := hx - cham

	# Face avant (+Z)
	_emit_quad_outward(
		st_rel,
		Vector3(-rx, height, hz), Vector3(rx, height, hz),
		Vector3(rx, 0.0, hz), Vector3(-rx, 0.0, hz),
		Vector2(u0, 0.0), Vector2(u1, 0.0),
		Vector2(u1, 1.0), Vector2(u0, 1.0),
		Vector3(0, 0, 1)
	)
	# Face arrière (-Z, visible depuis l'intérieur de l'arène)
	_emit_quad_outward(
		st_rel,
		Vector3(rx, height, -hz), Vector3(-rx, height, -hz),
		Vector3(-rx, 0.0, -hz), Vector3(rx, 0.0, -hz),
		Vector2(u0, 0.0), Vector2(u1, 0.0),
		Vector2(u1, 1.0), Vector2(u0, 1.0),
		Vector3(0, 0, -1)
	)
	st_rel.generate_tangents()
	st_rel.set_material(get_pillar_relief_material())
	st_rel.commit(mesh)

	return mesh


# =========================================================================
# 3. ARCHE CREUSE DE LA MORIA (TYMPAN AJOURÉ EN VRAIE 3D + VOÛTE INTRADOS)
# =========================================================================
static func build_hollow_moria_arch_spandrel(
	width: float = 16.80,
	height: float = 8.65,
	depth: float = 2.44,
	arch_half_w: float = 4.98,
	arch_crown_h: float = 5.24,
	segments: int = 52
) -> ArrayMesh:
	var hx := width * 0.5
	var hz := depth * 0.5
	var full_img_h := width / (1376.0 / 768.0) # Ratio natif exact 1376x768 => zéro étirement UV

	var in_pts: Array[Vector2] = []
	var out_pts: Array[Vector2] = []
	var key_protrude: PackedFloat32Array = PackedFloat32Array()

	for i in range(segments + 1):
		var frac := float(i) / float(segments)
		# Angle de PI (gauche) vers 0 (droite) en passant par PI/2 (sommet clé de voûte)
		var theta := lerpf(PI, 0.0, frac)
		var c := cos(theta)
		var s := sin(theta)

		var p_in := Vector2(c * arch_half_w, s * arch_crown_h)
		in_pts.append(p_in)

		# Projection radiale depuis (0, 0) jusqu'au bord rectangulaire [-hx..+hx] x [0..height]
		var dir := Vector2(c, s)
		var t_x := INF
		if absf(dir.x) > 0.0001:
			t_x = hx / absf(dir.x)
		var t_y := INF
		if dir.y > 0.0001:
			t_y = height / dir.y
		var t_hit := minf(t_x, t_y)
		var p_out := dir * t_hit
		p_out.x = clampf(p_out.x, -hx, hx)
		p_out.y = clampf(p_out.y, 0.0, height)
		out_pts.append(p_out)

		# Légère avancée sculpturale 3D (+9 cm) sur la clé de voûte centrale (Couronne & 7 étoiles)
		var dist_apex := absf(theta - PI * 0.5)
		var k_bump := smoothstep_scalar(0.20, 0.06, dist_apex) * 0.09
		key_protrude.append(k_bump)

	var mesh := ArrayMesh.new()

	# --- Surface 0 : Tympan sculpté avant (+Z) et arrière (-Z) ---
	var st_frieze := SurfaceTool.new()
	st_frieze.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(segments):
		var pi0 := in_pts[i]
		var pi1 := in_pts[i + 1]
		var po0 := out_pts[i]
		var po1 := out_pts[i + 1]
		var kb0 := key_protrude[i]
		var kb1 := key_protrude[i + 1]

		var uv_i0 := Vector2((pi0.x + hx) / width, clampf((height - pi0.y) / full_img_h, 0.0, 0.922))
		var uv_i1 := Vector2((pi1.x + hx) / width, clampf((height - pi1.y) / full_img_h, 0.0, 0.922))
		var uv_o0 := Vector2((po0.x + hx) / width, clampf((height - po0.y) / full_img_h, 0.0, 0.922))
		var uv_o1 := Vector2((po1.x + hx) / width, clampf((height - po1.y) / full_img_h, 0.0, 0.922))

		# Face avant (+Z)
		_emit_quad_outward(
			st_frieze,
			Vector3(po0.x, po0.y, hz + kb0),
			Vector3(po1.x, po1.y, hz + kb1),
			Vector3(pi1.x, pi1.y, hz + kb1),
			Vector3(pi0.x, pi0.y, hz + kb0),
			uv_o0, uv_o1, uv_i1, uv_i0,
			Vector3(0, 0, 1)
		)

		# Face arrière (-Z, symétrique)
		_emit_quad_outward(
			st_frieze,
			Vector3(po1.x, po1.y, -hz - kb1),
			Vector3(po0.x, po0.y, -hz - kb0),
			Vector3(pi0.x, pi0.y, -hz - kb0),
			Vector3(pi1.x, pi1.y, -hz - kb1),
			uv_o1, uv_o0, uv_i0, uv_i1,
			Vector3(0, 0, -1)
		)

	st_frieze.generate_tangents()
	st_frieze.set_material(get_arch_relief_material())
	st_frieze.commit(mesh)

	# --- Surface 1 : Voûte cintrée intérieure (intrados) + chants extérieurs ---
	var st_vault := SurfaceTool.new()
	st_vault.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(segments):
		var pi0 := in_pts[i]
		var pi1 := in_pts[i + 1]
		var kb0 := key_protrude[i]
		var kb1 := key_protrude[i + 1]

		# Normale de l'intrados dirigée vers le centre (0, 0) de l'ouverture !
		var mid_in := (pi0 + pi1) * 0.5
		var n_intrados := Vector3(-mid_in.x, -mid_in.y, 0.0).normalized()

		_emit_quad_auto_uv(
			st_vault,
			Vector3(pi0.x, pi0.y, hz + kb0),
			Vector3(pi1.x, pi1.y, hz + kb1),
			Vector3(pi1.x, pi1.y, -hz - kb1),
			Vector3(pi0.x, pi0.y, -hz - kb0),
			n_intrados,
			0.30
		)

		# Chants extérieurs segmentés (suivant aussi le léger décroché de la clé de voûte)
		var po0 := out_pts[i]
		var po1 := out_pts[i + 1]
		if po0.distance_squared_to(po1) > 0.0001:
			var edge := po1 - po0
			var n2 := Vector2(edge.y, -edge.x).normalized()
			if n2.dot((po0 + po1) * 0.5 - Vector2(0.0, height * 0.45)) < 0.0:
				n2 = -n2
			var n_ext := Vector3(n2.x, n2.y, 0.0)
			_emit_quad_auto_uv(
				st_vault,
				Vector3(po0.x, po0.y, -hz - kb0),
				Vector3(po1.x, po1.y, -hz - kb1),
				Vector3(po1.x, po1.y, hz + kb1),
				Vector3(po0.x, po0.y, hz + kb0),
				n_ext,
				0.28
			)

	# Assises basses gauche et droite reposant sur les chapiteaux des deux piliers
	_emit_quad_auto_uv(
		st_vault,
		Vector3(-hx, 0.0, hz), Vector3(-arch_half_w, 0.0, hz),
		Vector3(-arch_half_w, 0.0, -hz), Vector3(-hx, 0.0, -hz),
		Vector3.DOWN, 0.28
	)
	_emit_quad_auto_uv(
		st_vault,
		Vector3(arch_half_w, 0.0, hz), Vector3(hx, 0.0, hz),
		Vector3(hx, 0.0, -hz), Vector3(arch_half_w, 0.0, -hz),
		Vector3.DOWN, 0.28
	)

	st_vault.generate_tangents()
	st_vault.set_material(get_slate_masonry_material(true))
	st_vault.commit(mesh)

	return mesh


static func smoothstep_scalar(edge0: float, edge1: float, x: float) -> float:
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# =========================================================================
# 4. RACINES & LIANES FERMÉES ET COMPATIBLES SHADER (PINCEMENT CONIQUE 100% PLEIN)
# =========================================================================
static func build_anchored_root_tube(
	points: PackedVector3Array,
	base_radius: float,
	_tip_radius_ratio: float = 0.26,
	radial_segments: int = 10,
	gnarl_amp: float = 0.016,
	seed_val: int = 1
) -> ArrayMesh:
	var n_pts := points.size()
	if n_pts < 2:
		return ArrayMesh.new()

	var origin := points[0]
	var local_pts := PackedVector3Array()
	local_pts.resize(n_pts)
	for i in range(n_pts):
		local_pts[i] = points[i] - origin

	var cum_len := PackedFloat32Array()
	cum_len.resize(n_pts)
	cum_len[0] = 0.0
	var total_len := 0.0
	for i in range(1, n_pts):
		total_len += local_pts[i - 1].distance_to(local_pts[i])
		cum_len[i] = total_len
	if total_len < 0.0001:
		total_len = 1.0

	var prof_curve := _get_shader_radius_curve()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var prev_normal := Vector3.UP
	var ring_verts: Array[PackedVector3Array] = []
	var ring_norms: Array[PackedVector3Array] = []
	var ring_uvs: Array[PackedVector2Array] = []
	var tangents: PackedVector3Array = PackedVector3Array()

	for i in range(n_pts):
		var raw_t := clampf(cum_len[i] / total_len, 0.0, 1.0)
		# Plage 0.02..0.98 calée sur Curve_radius_profile du shader pour un pincement exact à 0
		var u := lerpf(0.02, 0.98, raw_t)

		var tangent: Vector3
		if i == 0:
			tangent = (local_pts[1] - local_pts[0]).normalized()
		elif i == n_pts - 1:
			tangent = (local_pts[n_pts - 1] - local_pts[n_pts - 2]).normalized()
		else:
			tangent = (local_pts[i + 1] - local_pts[i - 1]).normalized()
		if tangent.length_squared() < 0.0001:
			tangent = Vector3.RIGHT
		tangents.append(tangent)

		var ref_n := prev_normal - tangent * prev_normal.dot(tangent)
		if ref_n.length_squared() < 0.001:
			var fallback := Vector3.FORWARD if absf(tangent.dot(Vector3.UP)) > 0.9 else Vector3.UP
			ref_n = (fallback - tangent * fallback.dot(tangent)).normalized()
		else:
			ref_n = ref_n.normalized()
		prev_normal = ref_n
		var binorm := tangent.cross(ref_n).normalized()

		# Rayon calé sur Curve_radius_profile(u) pour que VERTEX - NORMAL * force_pincement_ * profile(u) = 0 à la pointe
		var prof := maxf(0.04, prof_curve.sample_baked(u))
		var r_here := base_radius * prof

		var r_v := PackedVector3Array()
		var r_n := PackedVector3Array()
		var r_uv := PackedVector2Array()
		for j in range(radial_segments + 1):
			var v_frac := float(j) / float(radial_segments)
			var ang := v_frac * TAU + raw_t * 2.2
			var ridge := 1.0 + 0.08 * sin(ang * 3.0 + float(seed_val) * 1.7 + raw_t * 7.0)
			var knot := gnarl_amp * prof * sin(raw_t * 11.0 + float(seed_val) * 2.1 + ang)
			var radial_dir := (ref_n * cos(ang) + binorm * sin(ang)).normalized()
			var pos := local_pts[i] + radial_dir * maxf(0.008, r_here * ridge + knot)
			r_v.append(pos)
			r_n.append(radial_dir)
			# v_frac dans [0..1] (sans x2 artificiel)
			r_uv.append(Vector2(u, v_frac))

		ring_verts.append(r_v)
		ring_norms.append(r_n)
		ring_uvs.append(r_uv)

	for i in range(n_pts - 1):
		for j in range(radial_segments):
			var v00 := ring_verts[i][j]
			var v01 := ring_verts[i][j + 1]
			var v10 := ring_verts[i + 1][j]
			var v11 := ring_verts[i + 1][j + 1]
			var avg_n := (ring_norms[i][j] + ring_norms[i][j + 1] + ring_norms[i + 1][j] + ring_norms[i + 1][j + 1]).normalized()
			_emit_quad_outward(
				st,
				v00, v01, v11, v10,
				ring_uvs[i][j], ring_uvs[i][j + 1], ring_uvs[i + 1][j + 1], ring_uvs[i + 1][j],
				avg_n
			)

	# Capuchons coniques fermés aux deux extrémités (maillage 100% étanche / fermé)
	var base_apex := local_pts[0] - tangents[0] * (base_radius * 0.25)
	for j in range(radial_segments):
		var vb0 := ring_verts[0][j]
		var vb1 := ring_verts[0][j + 1]
		var nb := (-tangents[0] + ring_norms[0][j] * 0.35 + ring_norms[0][j + 1] * 0.35).normalized()
		_emit_tri_outward(
			st,
			base_apex, vb0, vb1,
			Vector2(0.0, (float(j) + 0.5) / float(radial_segments)), ring_uvs[0][j], ring_uvs[0][j + 1],
			nb
		)

	var last := n_pts - 1
	var tip_apex := local_pts[last] + tangents[last] * (base_radius * 0.35)
	for j in range(radial_segments):
		var vt0 := ring_verts[last][j]
		var vt1 := ring_verts[last][j + 1]
		var nt := (tangents[last] + ring_norms[last][j] * 0.35 + ring_norms[last][j + 1] * 0.35).normalized()
		_emit_tri_outward(
			st,
			tip_apex, vt0, vt1,
			Vector2(1.0, (float(j) + 0.5) / float(radial_segments)), ring_uvs[last][j], ring_uvs[last][j + 1],
			nt
		)

	st.generate_tangents()
	return st.commit()
