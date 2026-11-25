class_name CleaveWeaponTrail
extends MeshInstance3D

class TrailSample:
	var inner_pos: Vector3 = Vector3.ZERO
	var outer_pos: Vector3 = Vector3.ZERO
	var age: float = 0.0

	func _init(in_inner: Vector3, in_outer: Vector3, in_age: float = 0.0) -> void:
		inner_pos = in_inner
		outer_pos = in_outer
		age = in_age

@export var trail_lifetime: float = 0.15
@export var max_sample_spacing: float = 0.05
@export var min_sample_spacing: float = 0.004

var is_emitting: bool = false

var _ribbon_mesh: ImmediateMesh = null
var _ribbon_material: StandardMaterial3D = null
var _source_node: Node3D = null
var _inner_local: Vector3 = Vector3(0.0, 0.89, 0.0)
var _outer_local: Vector3 = Vector3(0.0, 1.32, 0.0)

var _samples: Array[TrailSample] = []
var _has_prev_sample: bool = false
var _prev_inner: Vector3 = Vector3.ZERO
var _prev_outer: Vector3 = Vector3.ZERO
var _prev_origin: Vector3 = Vector3.ZERO

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_ribbon_mesh = ImmediateMesh.new()
	mesh = _ribbon_mesh

	_ribbon_material = StandardMaterial3D.new()
	_ribbon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ribbon_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ribbon_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ribbon_material.vertex_color_use_as_albedo = true
	material_override = _ribbon_material

func start_trail(caster: Node3D) -> void:
	global_transform = Transform3D.IDENTITY
	_samples.clear()
	_has_prev_sample = false
	if _ribbon_mesh != null:
		_ribbon_mesh.clear_surfaces()

	_source_node = _resolve_trail_source(caster)
	var blade_top_y: float = _compute_blade_top_y(_source_node)
	_inner_local = Vector3(0.0, blade_top_y * 0.56, 0.0)
	_outer_local = Vector3(0.0, blade_top_y * 1.02, 0.0)

	is_emitting = _source_node != null and is_instance_valid(_source_node)
	if is_emitting:
		var p_in: Vector3 = _source_node.to_global(_inner_local)
		var p_out: Vector3 = _source_node.to_global(_outer_local)
		_append_sample(p_in, p_out, 0.0)
		_prev_inner = p_in
		_prev_outer = p_out
		_prev_origin = _source_node.global_position
		_has_prev_sample = true

func stop_trail() -> void:
	is_emitting = false
	_has_prev_sample = false

func _process(delta: float) -> void:
	if global_transform != Transform3D.IDENTITY:
		global_transform = Transform3D.IDENTITY

	var idx: int = _samples.size() - 1
	while idx >= 0:
		var s: TrailSample = _samples[idx]
		s.age += delta
		if s.age >= trail_lifetime:
			_samples.remove_at(idx)
		idx -= 1

	if is_emitting:
		if _source_node != null and is_instance_valid(_source_node):
			var p_in: Vector3 = _source_node.to_global(_inner_local)
			var p_out: Vector3 = _source_node.to_global(_outer_local)
			var origin_now: Vector3 = _source_node.global_position

			if not _has_prev_sample:
				_append_sample(p_in, p_out, 0.0)
				_prev_inner = p_in
				_prev_outer = p_out
				_prev_origin = origin_now
				_has_prev_sample = true
			else:
				var dist_out: float = p_out.distance_to(_prev_outer)
				var dist_in: float = p_in.distance_to(_prev_inner)
				var dist: float = maxf(dist_out, dist_in)

				if dist >= min_sample_spacing:
					if dist > max_sample_spacing:
						var sub_count: int = clampi(int(ceili(dist / max_sample_spacing)) - 1, 2, 4)
						var max_sub_age: float = minf(delta, trail_lifetime * 0.45)
						for step_idx: int in range(1, sub_count + 1):
							var t: float = float(step_idx) / float(sub_count + 1)
							var sub_in: Vector3 = _interp_arc_point(_prev_origin, origin_now, _prev_inner, p_in, t)
							var sub_out: Vector3 = _interp_arc_point(_prev_origin, origin_now, _prev_outer, p_out, t)
							var sub_age: float = lerpf(max_sub_age, 0.0, t)
							_append_sample(sub_in, sub_out, sub_age)

					_append_sample(p_in, p_out, 0.0)
					_prev_inner = p_in
					_prev_outer = p_out
					_prev_origin = origin_now
		else:
			is_emitting = false

	_rebuild_ribbon_mesh()

func _append_sample(p_in: Vector3, p_out: Vector3, sample_age: float) -> void:
	_samples.append(TrailSample.new(p_in, p_out, sample_age))

func _interp_arc_point(orig_a: Vector3, orig_b: Vector3, pt_a: Vector3, pt_b: Vector3, t: float) -> Vector3:
	var orig_t: Vector3 = orig_a.lerp(orig_b, t)
	var rel_a: Vector3 = pt_a - orig_a
	var rel_b: Vector3 = pt_b - orig_b
	var len_a: float = rel_a.length()
	var len_b: float = rel_b.length()
	if len_a < 0.001 or len_b < 0.001:
		return pt_a.lerp(pt_b, t)

	var dir_a: Vector3 = rel_a / len_a
	var dir_b: Vector3 = rel_b / len_b
	var dot_ab: float = clampf(dir_a.dot(dir_b), -1.0, 1.0)
	if absf(dot_ab) > 0.9995:
		return pt_a.lerp(pt_b, t)

	var dir_t: Vector3 = dir_a.slerp(dir_b, t)
	return orig_t + dir_t * lerpf(len_a, len_b, t)

func _rebuild_ribbon_mesh() -> void:
	if _ribbon_mesh == null:
		return

	_ribbon_mesh.clear_surfaces()
	var count: int = _samples.size()
	if count < 2:
		return

	_ribbon_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _ribbon_material)
	var inv_last: float = 1.0 / float(count - 1)
	var safe_lifetime: float = maxf(trail_lifetime, 0.001)

	for i: int in range(count):
		var sample: TrailSample = _samples[i]
		var u: float = float(i) * inv_last
		var life_left: float = clampf(1.0 - (sample.age / safe_lifetime), 0.0, 1.0)
		var tail_fade: float = smoothstep(0.0, 0.28, u)
		var life_fade: float = life_left * life_left * tail_fade
		var head_taper: float = 1.0 - 0.35 * smoothstep(0.86, 1.0, u)

		var width_taper: float = lerpf(0.45, 1.0, smoothstep(0.0, 0.4, u))
		var pos_out: Vector3 = sample.outer_pos
		var pos_in: Vector3 = pos_out.lerp(sample.inner_pos, width_taper)

		var outer_color := Color(0.93, 0.96, 1.0, 0.52 * life_fade * head_taper)
		var inner_color := Color(0.86, 0.91, 0.98, 0.11 * life_fade * head_taper)

		_ribbon_mesh.surface_set_color(outer_color)
		_ribbon_mesh.surface_set_uv(Vector2(u, 0.0))
		_ribbon_mesh.surface_add_vertex(pos_out)

		_ribbon_mesh.surface_set_color(inner_color)
		_ribbon_mesh.surface_set_uv(Vector2(u, 1.0))
		_ribbon_mesh.surface_add_vertex(pos_in)

	_ribbon_mesh.surface_end()

func _resolve_trail_source(caster: Node3D) -> Node3D:
	if caster == null or not is_instance_valid(caster):
		return null

	var wrist: Node3D = caster.get_node_or_null("Camera3D/MainDroite/wrist") as Node3D
	if wrist == null:
		wrist = caster.find_child("wrist", true, false) as Node3D

	if wrist != null:
		var fallback_weapon: Node3D = null
		for child: Node in wrist.get_children():
			var child_3d: Node3D = child as Node3D
			if child_3d == null:
				continue
			var child_name: StringName = child_3d.name
			if child_name == &"weapon_impact_componant" or child_name == &"WeaponImpactComponent":
				continue
			if child_3d.visible:
				return child_3d
			if fallback_weapon == null:
				fallback_weapon = child_3d
		if fallback_weapon != null:
			return fallback_weapon
		return wrist

	var main_droite: Node3D = caster.get_node_or_null("Camera3D/MainDroite") as Node3D
	if main_droite == null:
		main_droite = caster.find_child("MainDroite", true, false) as Node3D
	if main_droite != null:
		return main_droite

	return caster

func _compute_blade_top_y(source: Node3D) -> float:
	var default_top_y: float = 1.35
	if source == null or not is_instance_valid(source):
		return default_top_y

	var attack_node: Node3D = source.get_node_or_null("AttackComponent") as Node3D
	if attack_node == null:
		attack_node = source.find_child("AttackComponent*", true, false) as Node3D
	if attack_node == null:
		return default_top_y

	var col_shape: CollisionShape3D = attack_node.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_shape == null:
		col_shape = attack_node.find_child("CollisionShape3D", true, false) as CollisionShape3D
	if col_shape == null or col_shape.shape == null:
		return default_top_y

	var half_h: float = 0.0
	var shape_res: Shape3D = col_shape.shape
	if shape_res is BoxShape3D:
		half_h = (shape_res as BoxShape3D).size.y * 0.5
	elif shape_res is CapsuleShape3D:
		half_h = (shape_res as CapsuleShape3D).height * 0.5
	elif shape_res is CylinderShape3D:
		half_h = (shape_res as CylinderShape3D).height * 0.5
	elif shape_res is SphereShape3D:
		half_h = (shape_res as SphereShape3D).radius
	else:
		return default_top_y

	var top_y: float = attack_node.position.y + col_shape.position.y + half_h
	return clampf(top_y, 1.05, 2.05)
