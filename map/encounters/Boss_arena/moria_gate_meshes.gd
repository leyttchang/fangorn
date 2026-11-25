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

const ROOT_SHADER_PATH := "res://assets/3D_models/VFX_spell/root_shader.tres"
const BARK_A_DIFF := "res://assets/texture/bark_brown_text/bark_brown_02_diff_1k.jpg"
const BARK_A_NOR := "res://assets/texture/bark_brown_text/bark_brown_02_nor_gl_1k.jpg"
const BARK_A_ROUGH := "res://assets/texture/bark_brown_text/bark_brown_02_rough_1k.jpg"

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
	# Lit directement Curve_radius_profile depuis root_shader.tres (nœud vertex 24)
	var vs: VisualShader = load(ROOT_SHADER_PATH) as VisualShader
	if vs != null:
		var c_node: VisualShaderNodeCurveTexture = vs.get_node(VisualShader.TYPE_VERTEX, 24) as VisualShaderNodeCurveTexture
		if c_node != null and c_node.texture != null and c_node.texture.curve != null:
			_root_profile_curve = c_node.texture.curve
			_root_profile_curve.bake()
			return _root_profile_curve
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
	_use_secondary_bark: bool = false,
	tint: Color = Color(0.28, 0.22, 0.15, 1.0),
	base_radius: float = 0.28,
	length_meters: float = 7.5
) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(ROOT_SHADER_PATH) as Shader
	mat.set_shader_parameter("fin", -0.09)
	mat.set_shader_parameter("debut", 1.08)
	mat.set_shader_parameter("smoth_step", 0.002)
	mat.set_shader_parameter("smoth_step_sommet", 0.08)
	# Pincement conique exact à rayon 0 sur toute la course de debut
	mat.set_shader_parameter("force_pincement_", base_radius * 1.00)
	# Fibres d'écorce orientées dans le sens de la racine + répétition entière sans couture
	mat.set_shader_parameter("align_bark_uv", 1.0)
	var circ_repeats: float = float(maxi(1, roundi((TAU * base_radius) / 1.35)))
	var len_repeats: float = snappedf(clampf(length_meters / 2.0, 1.5, 6.0), 0.5)
	mat.set_shader_parameter("uv_scale", Vector2(circ_repeats, len_repeats))
	mat.set_shader_parameter("ColorParameter", tint)
	mat.set_shader_parameter("normal_strength", 1.0)
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

	var arch_arc_accum: float = 0.0
	for i in range(segments):
		var pi0 := in_pts[i]
		var pi1 := in_pts[i + 1]
		var kb0 := key_protrude[i]
		var kb1 := key_protrude[i + 1]
		var seg_arc: float = pi0.distance_to(pi1)
		var u_arc0: float = arch_arc_accum * 0.30
		var u_arc1: float = (arch_arc_accum + seg_arc) * 0.30
		arch_arc_accum += seg_arc

		# Normale de l'intrados dirigée vers le centre (0, 0) de l'ouverture, UV curviligne continu sans cassure
		var mid_in := (pi0 + pi1) * 0.5
		var n_intrados := Vector3(-mid_in.x, -mid_in.y, 0.0).normalized()

		_emit_quad_outward(
			st_vault,
			Vector3(pi0.x, pi0.y, hz + kb0),
			Vector3(pi1.x, pi1.y, hz + kb1),
			Vector3(pi1.x, pi1.y, -hz - kb1),
			Vector3(pi0.x, pi0.y, -hz - kb0),
			Vector2(u_arc0, (hz + kb0) * 0.30),
			Vector2(u_arc1, (hz + kb1) * 0.30),
			Vector2(u_arc1, (-hz - kb1) * 0.30),
			Vector2(u_arc0, (-hz - kb0) * 0.30),
			n_intrados
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
# 4. RACINES LISSES INDEXÉES 100% COMPATIBLES AVEC root_shader.tres
# =========================================================================
static func _resample_catmull_rom(src_pts: PackedVector3Array, target_count: int) -> PackedVector3Array:
	var n: int = src_pts.size()
	if n < 2 or target_count <= 2:
		return src_pts
	var out := PackedVector3Array()
	out.resize(target_count)
	for k in range(target_count):
		var t_glob: float = float(k) / float(target_count - 1)
		var seg_f: float = t_glob * float(n - 1)
		var i1: int = clampi(int(floor(seg_f)), 0, n - 2)
		var lt: float = seg_f - float(i1)
		var lt2: float = lt * lt
		var lt3: float = lt2 * lt
		var p0: Vector3 = src_pts[maxi(0, i1 - 1)]
		var p1: Vector3 = src_pts[i1]
		var p2: Vector3 = src_pts[i1 + 1]
		var p3: Vector3 = src_pts[mini(n - 1, i1 + 2)]
		out[k] = 0.5 * (
			(2.0 * p1)
			+ (-p0 + p2) * lt
			+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * lt2
			+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * lt3
		)
	return out


static func build_anchored_root_tube(
	points: PackedVector3Array,
	base_radius: float,
	_tip_radius_ratio: float = 0.26,
	radial_segments: int = 14,
	gnarl_amp: float = 0.016,
	seed_val: int = 1,
	use_custom_pivot: bool = false,
	custom_pivot: Vector3 = Vector3.ZERO
) -> ArrayMesh:
	var src_n: int = points.size()
	if src_n < 2:
		return ArrayMesh.new()

	var origin: Vector3 = custom_pivot if use_custom_pivot else points[0]
	var rel_pts := PackedVector3Array()
	rel_pts.resize(src_n)
	for i in range(src_n):
		rel_pts[i] = points[i] - origin

	# Densification Catmull-Rom à 72 anneaux longitudinaux : garantit que l'interpolation linéaire GPU
	# entre deux anneaux reste < 2 mm pendant la rétraction de root_shader.tres (zéro ouverture creuse)
	var n_rings: int = 72
	var local_pts: PackedVector3Array = _resample_catmull_rom(rel_pts, n_rings)

	# Légère ondulation organique appliquée à la ligne centrale (et NON au rayon), pour que chaque section
	# reste un cercle parfait centré sur local_pts[i] qui se pince exactement en 1 point sous root_shader.tres
	if gnarl_amp > 0.0005:
		var init_prev_n := Vector3.UP
		var warped := PackedVector3Array()
		warped.resize(n_rings)
		for i in range(n_rings):
			var tf: float = float(i) / float(n_rings - 1)
			var tan_i: Vector3
			if i == 0:
				tan_i = (local_pts[1] - local_pts[0]).normalized()
			elif i == n_rings - 1:
				tan_i = (local_pts[n_rings - 1] - local_pts[n_rings - 2]).normalized()
			else:
				tan_i = (local_pts[i + 1] - local_pts[i - 1]).normalized()
			if tan_i.length_squared() < 0.0001:
				tan_i = Vector3.RIGHT
			var rn: Vector3 = init_prev_n - tan_i * init_prev_n.dot(tan_i)
			if rn.length_squared() < 0.001:
				var fb := Vector3.FORWARD if absf(tan_i.dot(Vector3.UP)) > 0.9 else Vector3.UP
				rn = (fb - tan_i * fb.dot(tan_i)).normalized()
			else:
				rn = rn.normalized()
			init_prev_n = rn
			var bn: Vector3 = tan_i.cross(rn).normalized()
			var env: float = sin(tf * PI)
			var w1: float = sin(tf * 13.0 + float(seed_val) * 1.9) * gnarl_amp * 1.35 * env
			var w2: float = cos(tf * 9.5 + float(seed_val) * 2.7) * gnarl_amp * 1.15 * env
			warped[i] = local_pts[i] + rn * w1 + bn * w2
		local_pts = warped

	var cum_len := PackedFloat32Array()
	cum_len.resize(n_rings)
	cum_len[0] = 0.0
	var total_len: float = 0.0
	for i in range(1, n_rings):
		total_len += local_pts[i - 1].distance_to(local_pts[i])
		cum_len[i] = total_len
	if total_len < 0.0001:
		total_len = 1.0

	var rad_segs: int = maxi(12, radial_segments)
	var stride: int = rad_segs + 1
	var prof_curve: Curve = _get_shader_radius_curve()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var prev_normal := Vector3.UP
	var ring_zero_pos := PackedVector3Array()
	var ring_zero_nrm := PackedVector3Array()

	for i in range(n_rings):
		var raw_t: float = clampf(cum_len[i] / total_len, 0.0, 1.0)
		var u: float = lerpf(0.004, 0.996, raw_t)

		var tangent: Vector3
		if i == 0:
			tangent = (local_pts[1] - local_pts[0]).normalized()
		elif i == n_rings - 1:
			tangent = (local_pts[n_rings - 1] - local_pts[n_rings - 2]).normalized()
		else:
			tangent = (local_pts[i + 1] - local_pts[i - 1]).normalized()
		if tangent.length_squared() < 0.0001:
			tangent = Vector3.RIGHT

		var ref_n: Vector3 = prev_normal - tangent * prev_normal.dot(tangent)
		if ref_n.length_squared() < 0.001:
			var fallback := Vector3.FORWARD if absf(tangent.dot(Vector3.UP)) > 0.9 else Vector3.UP
			ref_n = (fallback - tangent * fallback.dot(tangent)).normalized()
		else:
			ref_n = ref_n.normalized()
		prev_normal = ref_n
		var binorm: Vector3 = tangent.cross(ref_n).normalized()

		# Rayon exact base_radius * Curve_radius_profile(u) (comme l'export BézierCurve Blender)
		var prof: float = maxf(0.008, prof_curve.sample_baked(u))
		var r_here: float = base_radius * prof

		var first_dir: Vector3 = ref_n
		var first_pos: Vector3 = local_pts[i] + first_dir * r_here

		for j in range(stride):
			var v_frac: float = float(j) / float(rad_segs)
			var radial_dir: Vector3
			var pos: Vector3
			if j == 0 or j == rad_segs:
				# Couture j=0 / j=rad_segs strictement identique bit à bit (zéro fissure au pincement)
				radial_dir = first_dir
				pos = first_pos
			else:
				var ang: float = v_frac * TAU
				radial_dir = (ref_n * cos(ang) + binorm * sin(ang)).normalized()
				pos = local_pts[i] + radial_dir * r_here

			if i <= 1 and j <= 1:
				ring_zero_pos.append(pos)
				ring_zero_nrm.append(radial_dir)

			st.set_normal(radial_dir)
			st.set_uv(Vector2(u, v_frac))
			st.add_vertex(pos)

	# Vérification automatique du sens extérieur des triangles indexés pour cull_back
	var p00: Vector3 = ring_zero_pos[0]
	var p10: Vector3 = ring_zero_pos[2]
	var p11: Vector3 = ring_zero_pos[3]
	var n00: Vector3 = ring_zero_nrm[0]
	var flip_winding: bool = ((p11 - p00).cross(p10 - p00).dot(n00) < 0.0)

	for i in range(n_rings - 1):
		var row0: int = i * stride
		var row1: int = (i + 1) * stride
		for j in range(rad_segs):
			var i00: int = row0 + j
			var i01: int = row0 + j + 1
			var i10: int = row1 + j
			var i11: int = row1 + j + 1
			if not flip_winding:
				st.add_index(i00); st.add_index(i10); st.add_index(i11)
				st.add_index(i00); st.add_index(i11); st.add_index(i01)
			else:
				st.add_index(i00); st.add_index(i11); st.add_index(i10)
				st.add_index(i00); st.add_index(i01); st.add_index(i11)

	st.generate_tangents()
	return st.commit()
