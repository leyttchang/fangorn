@tool
class_name ProceduralForestMeshes
extends RefCounted

## Générateur et cache de meshes procéduraux organiques pour les interactables de Fangorn.
## - Champignons bioluminescents (pieds courbés, chapeaux bombés à lamelles, éclats physiques)
## - Racines tressées compatibles à 100% avec root_shader.tres (UV.x = 0..1 le long de la racine)

const ROOT_SHADER_PATH := "res://objet/forest_interactables/fangorn_root.gdshader"
const BARK_DIFF_PATH := "res://assets/texture/bark_brown_text/bark_brown_02_diff_1k.jpg"
const BARK_NOR_PATH := "res://assets/texture/bark_brown_text/bark_brown_02_nor_gl_1k.jpg"
const BARK_ROUGH_PATH := "res://assets/texture/bark_brown_text/bark_brown_02_rough_1k.jpg"
const NOISE_TEX_PATH := "res://assets/LeLu's Noise Pack/T_Noise1_tiled.png"

static var _mushroom_stems: Array[ArrayMesh] = []
static var _mushroom_caps: Array[ArrayMesh] = []
static var _mushroom_chunk_mesh: ArrayMesh = null
static var _mushroom_stem_mat: Material = null
static var _mushroom_cap_mat: ShaderMaterial = null
static var _spore_particle_mat: StandardMaterial3D = null
static var _spore_quad_mesh: QuadMesh = null

static var _cocoon_ribs_cache: Array[Dictionary] = []
static var _cocoon_core_mat: ShaderMaterial = null
static var _launcher_arches_cache: Array[Dictionary] = []
static var _launcher_coils_cache: Array[Dictionary] = []
static var _launcher_whips_cache: Array[Dictionary] = []
static var _root_profile_curve: Curve = null

static func clear_caches() -> void:
	_mushroom_stems.clear()
	_mushroom_caps.clear()
	_mushroom_chunk_mesh = null
	_mushroom_stem_mat = null
	_mushroom_cap_mat = null
	_cocoon_ribs_cache.clear()
	_cocoon_core_mat = null
	_launcher_arches_cache.clear()
	_launcher_coils_cache.clear()
	_launcher_whips_cache.clear()
	_root_profile_curve = null

static func _get_shader_radius_curve() -> Curve:
	if _root_profile_curve != null:
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
# MATÉRIAUX DE RACINES (Basés sur root_shader.tres)
# =========================================================================
static func get_base_root_material(tint: Color = Color(0.68, 0.56, 0.38, 1.0), pinch: float = 0.11, length_tiles: float = 1.6) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var sh := load(ROOT_SHADER_PATH) as Shader
	mat.shader = sh
	mat.set_shader_parameter("fin", 0.0)
	mat.set_shader_parameter("debut", 1.0)
	mat.set_shader_parameter("smoth_step", 0.008)
	mat.set_shader_parameter("smoth_step_sommet", 0.12)
	mat.set_shader_parameter("force_pincement_", pinch)
	mat.set_shader_parameter("align_bark_uv", 1.0)
	mat.set_shader_parameter("uv_scale", Vector2(1.0, length_tiles))
	mat.set_shader_parameter("ColorParameter", tint)
	mat.set_shader_parameter("normal_strength", 1.2)
	if ResourceLoader.exists(BARK_DIFF_PATH):
		mat.set_shader_parameter("root_texture", load(BARK_DIFF_PATH))
	if ResourceLoader.exists(BARK_ROUGH_PATH):
		mat.set_shader_parameter("arm_text", load(BARK_ROUGH_PATH))
	if ResourceLoader.exists(BARK_NOR_PATH):
		mat.set_shader_parameter("normal_text", load(BARK_NOR_PATH))
	return mat

static func _emit_tri_outward(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uva: Vector2, uvb: Vector2, uvc: Vector2, outward_n: Vector3) -> void:
	var n := outward_n.normalized()
	if (c - a).cross(b - a).dot(n) >= 0.0:
		st.set_normal(n); st.set_uv(uva); st.add_vertex(a)
		st.set_normal(n); st.set_uv(uvb); st.add_vertex(b)
		st.set_normal(n); st.set_uv(uvc); st.add_vertex(c)
	else:
		st.set_normal(n); st.set_uv(uva); st.add_vertex(a)
		st.set_normal(n); st.set_uv(uvc); st.add_vertex(c)
		st.set_normal(n); st.set_uv(uvb); st.add_vertex(b)

# =========================================================================
# TUBES DE RACINES COURBÉS (UV.x = 0.02..0.98 le long de la courbe pour root_shader)
# =========================================================================
static func build_centered_root_tube(points: PackedVector3Array, base_radius: float, radial_segments: int = 8, gnarl_amp: float = 0.014, seed_val: int = 1) -> Dictionary:
	var n_pts := points.size()
	if n_pts < 2:
		return {"mesh": ArrayMesh.new(), "center": Vector3.ZERO}

	var center := Vector3.ZERO
	for p in points:
		center += p
	center /= float(n_pts)

	var local_pts := PackedVector3Array()
	local_pts.resize(n_pts)
	for i in range(n_pts):
		local_pts[i] = points[i] - center

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
	var tangents := PackedVector3Array()

	for i in range(n_pts):
		var raw_t: float = clampf(cum_len[i] / total_len, 0.0, 1.0)
		var u: float = lerpf(0.02, 0.98, raw_t)
		var tangent: Vector3
		if i == 0:
			tangent = (local_pts[1] - local_pts[0]).normalized()
		elif i == n_pts - 1:
			tangent = (local_pts[n_pts - 1] - local_pts[n_pts - 2]).normalized()
		else:
			tangent = (local_pts[i + 1] - local_pts[i - 1]).normalized()
		if tangent.length_squared() < 0.0001:
			tangent = Vector3.UP
		tangents.append(tangent)

		var ref_n := prev_normal - tangent * prev_normal.dot(tangent)
		if ref_n.length_squared() < 0.001:
			var fallback := Vector3.RIGHT if absf(tangent.dot(Vector3.UP)) > 0.9 else Vector3.UP
			ref_n = (fallback - tangent * fallback.dot(tangent)).normalized()
		else:
			ref_n = ref_n.normalized()
		prev_normal = ref_n
		var binorm := tangent.cross(ref_n).normalized()

		var prof := maxf(0.05, prof_curve.sample_baked(u))
		var r_here := base_radius * prof

		var r_v := PackedVector3Array()
		var r_n := PackedVector3Array()
		var r_uv := PackedVector2Array()
		for j in range(radial_segments + 1):
			var v_frac := float(j) / float(radial_segments)
			var ang := v_frac * TAU + raw_t * 2.2
			var ridge := 1.0 + 0.09 * sin(ang * 3.0 + float(seed_val) * 1.7 + raw_t * 8.0)
			var knot := gnarl_amp * prof * sin(raw_t * 12.0 + float(seed_val) * 2.3 + ang)
			var radial_dir := (ref_n * cos(ang) + binorm * sin(ang)).normalized()
			var pos := local_pts[i] + radial_dir * maxf(0.006, r_here * ridge + knot)
			r_v.append(pos)
			r_n.append(radial_dir)
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
			_emit_tri_outward(st, v00, v01, v11, ring_uvs[i][j], ring_uvs[i][j + 1], ring_uvs[i + 1][j + 1], avg_n)
			_emit_tri_outward(st, v00, v11, v10, ring_uvs[i][j], ring_uvs[i + 1][j + 1], ring_uvs[i + 1][j], avg_n)

	# Capuchons coniques pleins aux deux bouts
	var base_apex := local_pts[0] - tangents[0] * (base_radius * 0.25)
	for j in range(radial_segments):
		var nb := (-tangents[0] + ring_norms[0][j] * 0.35 + ring_norms[0][j + 1] * 0.35).normalized()
		_emit_tri_outward(st, base_apex, ring_verts[0][j], ring_verts[0][j + 1], Vector2(0.0, 0.5), ring_uvs[0][j], ring_uvs[0][j + 1], nb)

	var last := n_pts - 1
	var tip_apex := local_pts[last] + tangents[last] * (base_radius * 0.30)
	for j in range(radial_segments):
		var nt := (tangents[last] + ring_norms[last][j] * 0.35 + ring_norms[last][j + 1] * 0.35).normalized()
		_emit_tri_outward(st, tip_apex, ring_verts[last][j], ring_verts[last][j + 1], Vector2(1.0, 0.5), ring_uvs[last][j], ring_uvs[last][j + 1], nt)

	st.generate_tangents()
	return {"mesh": st.commit(), "center": center}

# =========================================================================
# JEU DE RACINES DU COCON (10 grosses racines croisées formant une vraie cage ovoïde)
# =========================================================================
static func get_cocoon_ribs() -> Array[Dictionary]:
	if not _cocoon_ribs_cache.is_empty():
		return _cocoon_ribs_cache

	var rib_count := 10
	var steps := 18
	for r_idx in range(rib_count):
		var base_angle := (TAU / float(rib_count)) * float(r_idx)
		var twist_dir := 1.0 if (r_idx % 2 == 0) else -1.0
		var twist_amount := lerpf(2.1, 3.1, float(r_idx % 3) / 2.0) * twist_dir
		var height_top := lerpf(1.26, 1.42, float((r_idx * 3) % 5) / 4.0)
		var waist_rad := lerpf(0.42, 0.52, float((r_idx * 2) % 4) / 3.0)

		var pts := PackedVector3Array()
		for s in range(steps):
			var t := float(s) / float(steps - 1)
			# Part des racines étalées au sol (-0.12m), bombe autour du cœur puis se referme en dôme au sommet
			var y: float
			if t < 0.88:
				y = lerpf(-0.12, height_top, pow(t / 0.88, 0.86))
			else:
				var crown_t := (t - 0.88) / 0.12
				y = lerpf(height_top, height_top - 0.14, crown_t)

			var belly := sin(clampf(t * 0.92 + 0.05, 0.0, 1.0) * PI)
			var root_foot_flare := (1.0 - smoothstep(0.0, 0.20, t)) * 0.34
			var rad := maxf(0.06, waist_rad * pow(belly, 0.58) + root_foot_flare)
			var ang := base_angle + t * twist_amount + 0.14 * sin(t * 10.0 + float(r_idx))
			pts.append(Vector3(cos(ang) * rad, y, sin(ang) * rad))

		var thickness := lerpf(0.082, 0.115, float(r_idx % 3) / 2.0)
		var built := build_centered_root_tube(pts, thickness, 8, 0.018, r_idx + 10)
		_cocoon_ribs_cache.append(built)

	return _cocoon_ribs_cache

static func get_cocoon_core_material() -> ShaderMaterial:
	if _cocoon_core_mat != null:
		return _cocoon_core_mat

	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 base_dark : source_color = vec3(0.06, 0.04, 0.02);
uniform vec3 glow_color : source_color = vec3(0.95, 0.48, 0.10);
uniform float pulse_speed = 2.4;
uniform sampler2D noise_tex : source_color, repeat_enable;

void fragment() {
	float n1 = texture(noise_tex, UV * 2.5 + vec2(TIME * 0.03, -TIME * 0.04)).r;
	float n2 = texture(noise_tex, UV * 5.0 - vec2(TIME * 0.02, TIME * 0.05)).r;
	float veins = smoothstep(0.45, 0.78, n1 * 0.65 + n2 * 0.55);
	float pulse = 0.68 + 0.32 * sin(TIME * pulse_speed);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	ALBEDO = mix(base_dark, glow_color * 0.4, veins * 0.55);
	ROUGHNESS = mix(0.85, 0.35, veins);
	EMISSION = glow_color * (veins * 1.9 * pulse + fresnel * 0.55 * pulse);
}
"""
	_cocoon_core_mat = ShaderMaterial.new()
	_cocoon_core_mat.shader = sh
	if ResourceLoader.exists(NOISE_TEX_PATH):
		_cocoon_core_mat.set_shader_parameter("noise_tex", load(NOISE_TEX_PATH))
	return _cocoon_core_mat

# =========================================================================
# JEU DE RACINES DE LA CATAPULTE (Nid spiralé au sol + 8 arches épaisses + 4 fouets)
# =========================================================================
static func get_launcher_coils() -> Array[Dictionary]:
	if not _launcher_coils_cache.is_empty():
		return _launcher_coils_cache

	# 3 grosses racines enroulées en ressort au centre (remplace tout disque plat artificiel !)
	for c_idx in range(3):
		var start_a := (TAU / 3.0) * float(c_idx)
		var pts := PackedVector3Array()
		var steps := 22
		for s in range(steps):
			var t := float(s) / float(steps - 1)
			var ang := start_a + t * TAU * 1.35
			var r := lerpf(0.92, 0.16, t)
			var y := 0.04 + t * 0.18 + 0.03 * sin(t * 12.0)
			pts.append(Vector3(cos(ang) * r, y, sin(ang) * r))
		_launcher_coils_cache.append(build_centered_root_tube(pts, 0.105, 8, 0.015, c_idx + 200))

	return _launcher_coils_cache

static func get_launcher_arches() -> Array[Dictionary]:
	if not _launcher_arches_cache.is_empty():
		return _launcher_arches_cache

	var arch_count := 8
	var steps := 16
	for a_idx in range(arch_count):
		var base_ang := (TAU / float(arch_count)) * float(a_idx)
		var pts := PackedVector3Array()
		for s in range(steps):
			var t := float(s) / float(steps - 1)
			var r := lerpf(1.38, 0.24, pow(t, 0.85))
			var arch_y := sin(t * PI) * 0.56 - 0.08 * (1.0 - sin(t * PI))
			var ang := base_ang + t * 0.72 * (1.0 if a_idx % 2 == 0 else -1.0)
			pts.append(Vector3(cos(ang) * r, arch_y, sin(ang) * r))
		var built := build_centered_root_tube(pts, 0.115, 8, 0.020, a_idx + 40)
		_launcher_arches_cache.append(built)

	return _launcher_arches_cache

static func get_launcher_whips() -> Array[Dictionary]:
	if not _launcher_whips_cache.is_empty():
		return _launcher_whips_cache

	var whip_count := 4
	var steps := 15
	for w_idx in range(whip_count):
		var base_ang := (TAU / float(whip_count)) * float(w_idx) + 0.38
		var pts := PackedVector3Array()
		for s in range(steps):
			var t := float(s) / float(steps - 1)
			var r := lerpf(0.28, 1.05, pow(t, 1.35))
			var y := lerpf(0.0, 2.45, pow(t, 0.82))
			var ang := base_ang + sin(t * PI * 1.2) * 0.48
			pts.append(Vector3(cos(ang) * r, y, sin(ang) * r))
		var built := build_centered_root_tube(pts, 0.085, 7, 0.016, w_idx + 80)
		_launcher_whips_cache.append(built)

	return _launcher_whips_cache

# =========================================================================
# CHAMPIGNONS BIOLUMINESCENTS PROCÉDURAUX (Topologie 100% pleine & organique)
# =========================================================================
static func get_mushroom_stem_mesh(variant: int = 0) -> ArrayMesh:
	_ensure_mushroom_meshes()
	return _mushroom_stems[posmod(variant, _mushroom_stems.size())]

static func get_mushroom_cap_mesh(variant: int = 0) -> ArrayMesh:
	_ensure_mushroom_meshes()
	return _mushroom_caps[posmod(variant, _mushroom_caps.size())]

static func get_mushroom_chunk_mesh() -> ArrayMesh:
	_ensure_mushroom_meshes()
	return _mushroom_chunk_mesh

static func get_mushroom_stem_material() -> Material:
	if _mushroom_stem_mat != null:
		return _mushroom_stem_mat
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.68, 0.56, 1.0)
	if ResourceLoader.exists(BARK_DIFF_PATH):
		mat.albedo_texture = load(BARK_DIFF_PATH)
	if ResourceLoader.exists(BARK_NOR_PATH):
		mat.normal_enabled = true
		mat.normal_scale = 0.5
		mat.normal_texture = load(BARK_NOR_PATH)
	mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
	mat.roughness = 0.88
	mat.emission_enabled = true
	mat.emission = Color(0.05, 0.22, 0.18)
	mat.emission_energy_multiplier = 0.28
	_mushroom_stem_mat = mat
	return _mushroom_stem_mat

static func get_mushroom_cap_material() -> ShaderMaterial:
	if _mushroom_cap_mat != null:
		return _mushroom_cap_mat
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 cap_top_dark : source_color = vec3(0.06, 0.16, 0.19);
uniform vec3 cap_mid_tone : source_color = vec3(0.09, 0.44, 0.42);
uniform vec3 cap_rim_glow : source_color = vec3(0.16, 0.92, 0.74);
uniform vec3 gill_glow : source_color = vec3(0.42, 1.0, 0.82);
uniform vec3 spot_color : source_color = vec3(0.68, 1.0, 0.88);
uniform sampler2D noise_tex : source_color, repeat_enable;

void fragment() {
	float glow_mask = COLOR.r;
	float gill_ridge = COLOR.g;
	float n = texture(noise_tex, UV * vec2(4.0, 2.5)).r;
	float spots = smoothstep(0.66, 0.76, texture(noise_tex, UV * vec2(7.0, 5.0) + vec2(0.17, 0.31)).r) * (1.0 - smoothstep(0.45, 0.85, glow_mask));
	float pulse = 0.84 + 0.16 * sin(TIME * 2.5);

	vec3 top_grad = mix(cap_top_dark * (0.75 + 0.55 * n), cap_mid_tone, smoothstep(0.08, 0.55, glow_mask));
	vec3 base_col = mix(top_grad, cap_rim_glow, smoothstep(0.45, 0.88, glow_mask));
	base_col = mix(base_col, spot_color, spots * 0.82);
	base_col = mix(base_col, gill_glow * (0.55 + 0.45 * gill_ridge), smoothstep(0.75, 1.0, glow_mask));

	float fresnel = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.3);
	ALBEDO = base_col;
	ROUGHNESS = mix(0.45, 0.78, glow_mask);
	EMISSION = (cap_rim_glow * (pow(glow_mask, 1.4) * 1.35 + spots * 1.45 + fresnel * 0.48) + gill_glow * gill_ridge * smoothstep(0.7, 1.0, glow_mask) * 0.9) * pulse;
}
"""
	_mushroom_cap_mat = ShaderMaterial.new()
	_mushroom_cap_mat.shader = sh
	if ResourceLoader.exists(NOISE_TEX_PATH):
		_mushroom_cap_mat.set_shader_parameter("noise_tex", load(NOISE_TEX_PATH))
	return _mushroom_cap_mat

static func get_spore_particle_material() -> StandardMaterial3D:
	if _spore_particle_mat != null:
		return _spore_particle_mat
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.6, 1.0, 0.9, 0.55), Color(0.2, 0.9, 0.8, 0.0)])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(0.5, 0.0)
	gtex.width = 64
	gtex.height = 64
	mat.albedo_texture = gtex
	_spore_particle_mat = mat
	return _spore_particle_mat

static func get_spore_quad_mesh(size: float = 0.14) -> QuadMesh:
	if _spore_quad_mesh == null:
		_spore_quad_mesh = QuadMesh.new()
		_spore_quad_mesh.size = Vector2(size, size)
		_spore_quad_mesh.material = get_spore_particle_material()
	return _spore_quad_mesh

static func _ensure_mushroom_meshes() -> void:
	if not _mushroom_stems.is_empty():
		return

	var stem_configs := [
		{"height": 0.62, "lean": 0.10, "base_r": 0.092, "top_r": 0.052},
		{"height": 0.44, "lean": -0.08, "base_r": 0.076, "top_r": 0.044},
		{"height": 0.30, "lean": 0.05, "base_r": 0.065, "top_r": 0.038}
	]
	var cap_configs := [
		{"radius": 0.38, "height": 0.24, "wave": 0.024, "seed": 1.0},
		{"radius": 0.28, "height": 0.18, "wave": 0.019, "seed": 2.7},
		{"radius": 0.20, "height": 0.14, "wave": 0.014, "seed": 4.3}
	]

	for sc in stem_configs:
		_mushroom_stems.append(_build_stem_mesh(sc["height"], sc["lean"], sc["base_r"], sc["top_r"]))
	for cc in cap_configs:
		_mushroom_caps.append(_build_cap_mesh(cc["radius"], cc["height"], cc["wave"], cc["seed"]))

	_mushroom_chunk_mesh = _build_cap_chunk_mesh()

static func _build_stem_mesh(height: float, lean_x: float, base_r: float, top_r: float) -> ArrayMesh:
	var rings := 9
	var segs := 12
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var verts: Array[PackedVector3Array] = []
	var norms: Array[PackedVector3Array] = []
	var uvs: Array[PackedVector2Array] = []

	for i in range(rings):
		var t := float(i) / float(rings - 1)
		var y := t * height
		var cx := sin(t * PI * 0.85) * lean_x
		var cz := sin(t * PI) * (lean_x * 0.45)
		var bulb := (1.0 - smoothstep(0.0, 0.35, t)) * (base_r * 0.45)
		var r := lerpf(base_r, top_r, pow(t, 0.7)) + bulb

		var rv := PackedVector3Array()
		var rn := PackedVector3Array()
		var ruv := PackedVector2Array()
		for j in range(segs + 1):
			var vf := float(j) / float(segs)
			var ang := vf * TAU
			var dir := Vector3(cos(ang), 0.0, sin(ang))
			rv.append(Vector3(cx, y, cz) + dir * r)
			rn.append((dir + Vector3(0.0, 0.12, 0.0)).normalized())
			ruv.append(Vector2(vf, t))
		verts.append(rv)
		norms.append(rn)
		uvs.append(ruv)

	for i in range(rings - 1):
		for j in range(segs):
			st.set_normal(norms[i][j]); st.set_uv(uvs[i][j]); st.add_vertex(verts[i][j])
			st.set_normal(norms[i][j + 1]); st.set_uv(uvs[i][j + 1]); st.add_vertex(verts[i][j + 1])
			st.set_normal(norms[i + 1][j + 1]); st.set_uv(uvs[i + 1][j + 1]); st.add_vertex(verts[i + 1][j + 1])

			st.set_normal(norms[i][j]); st.set_uv(uvs[i][j]); st.add_vertex(verts[i][j])
			st.set_normal(norms[i + 1][j + 1]); st.set_uv(uvs[i + 1][j + 1]); st.add_vertex(verts[i + 1][j + 1])
			st.set_normal(norms[i + 1][j]); st.set_uv(uvs[i + 1][j]); st.add_vertex(verts[i + 1][j])

	st.generate_tangents()
	return st.commit()

static func _build_cap_mesh(radius: float, cap_h: float, wave_amp: float, seed_f: float) -> ArrayMesh:
	# Sans generate_tangents() sur le pôle et avec UV cylindriques propres -> surface 100% continue et lisse !
	var profile_t := [0.001, 0.24, 0.50, 0.76, 0.94, 1.0, 0.84, 0.48, 0.14]
	var profile_y := [1.0, 0.93, 0.74, 0.42, 0.14, 0.0, -0.04, 0.09, 0.15]
	var profile_glow := [0.02, 0.08, 0.20, 0.42, 0.72, 0.92, 1.0, 0.96, 0.88]
	var segs := 24
	var rings := profile_t.size()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var verts: Array[PackedVector3Array] = []
	var norms: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	var uvs: Array[PackedVector2Array] = []

	for i in range(rings):
		var r_frac: float = profile_t[i]
		var y_base: float = profile_y[i] * cap_h
		var g_mask: float = profile_glow[i]
		var is_underside := (i >= 6)
		var v_coord := float(i) / float(rings - 1)

		var rv := PackedVector3Array()
		var rn := PackedVector3Array()
		var rc := PackedColorArray()
		var ruv := PackedVector2Array()

		for j in range(segs + 1):
			var vf := float(j) / float(segs)
			var ang := vf * TAU
			var rim_wave := wave_amp * sin(ang * 5.0 + seed_f) * smoothstep(0.35, 1.0, r_frac)
			var gill := 0.5 + 0.5 * sin(ang * 20.0)
			var gill_offset := (-0.014 * gill) if is_underside else 0.0
			var r := radius * r_frac + rim_wave * 0.40
			var pos := Vector3(cos(ang) * r, y_base + rim_wave + gill_offset, sin(ang) * r)

			var n_dir: Vector3
			if i == 0:
				n_dir = Vector3.UP
			elif is_underside:
				n_dir = Vector3(cos(ang) * 0.18, -1.0, sin(ang) * 0.18).normalized()
			else:
				n_dir = Vector3(cos(ang) * r_frac * 0.85, 1.0 - r_frac * 0.55, sin(ang) * r_frac * 0.85).normalized()

			rv.append(pos)
			rn.append(n_dir)
			rc.append(Color(g_mask, gill if is_underside else 0.15, 0.0, 1.0))
			ruv.append(Vector2(vf, v_coord))

		verts.append(rv)
		norms.append(rn)
		cols.append(rc)
		uvs.append(ruv)

	for i in range(rings - 1):
		for j in range(segs):
			st.set_color(cols[i][j]); st.set_normal(norms[i][j]); st.set_uv(uvs[i][j]); st.add_vertex(verts[i][j])
			st.set_color(cols[i + 1][j]); st.set_normal(norms[i + 1][j]); st.set_uv(uvs[i + 1][j]); st.add_vertex(verts[i + 1][j])
			st.set_color(cols[i + 1][j + 1]); st.set_normal(norms[i + 1][j + 1]); st.set_uv(uvs[i + 1][j + 1]); st.add_vertex(verts[i + 1][j + 1])

			st.set_color(cols[i][j]); st.set_normal(norms[i][j]); st.set_uv(uvs[i][j]); st.add_vertex(verts[i][j])
			st.set_color(cols[i + 1][j + 1]); st.set_normal(norms[i + 1][j + 1]); st.set_uv(uvs[i + 1][j + 1]); st.add_vertex(verts[i + 1][j + 1])
			st.set_color(cols[i][j + 1]); st.set_normal(norms[i][j + 1]); st.set_uv(uvs[i][j + 1]); st.add_vertex(verts[i][j + 1])

	return st.commit()

static func _build_cap_chunk_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p0 := Vector3(0.0, 0.05, 0.0)
	var p1 := Vector3(0.14, -0.02, 0.05)
	var p2 := Vector3(0.06, -0.02, 0.15)
	var p3 := Vector3(0.04, -0.05, 0.04)

	var faces := [
		[p0, p2, p1, Color(0.35, 0.2, 0, 1)],
		[p0, p1, p3, Color(0.95, 0.8, 0, 1)],
		[p0, p3, p2, Color(0.95, 0.8, 0, 1)],
		[p1, p2, p3, Color(1.0, 1.0, 0, 1)]
	]
	for f in faces:
		var n: Vector3 = (f[2] - f[0]).cross(f[1] - f[0]).normalized()
		for k in range(3):
			st.set_color(f[3])
			st.set_normal(n)
			st.set_uv(Vector2(float(k) * 0.4, float(k) * 0.3))
			st.add_vertex(f[k])
	return st.commit()
