class_name TotemVisionEffect
extends Node3D

## Effet expérimental de Vision Astrale de Totem Caché :
## - Montée progressive lente sur ~2.8-3.0s (rien ne change tout au début, puis la réalité bascule en douceur)
## - Arbres fantomatiques translucides (ALPHA_HASH_SCALE + Kuwahara : 0 coupure à t=0, silhouettes lumineuses + vue à travers)
## - Fleuve distordu de particules 3D de la forme/élément du totem caché + ÉNORME COLONNE DE LUMIÈRE céleste (460m) sur le totem
## - Forte distorsion liquide, aberration chromatique, respiration FOV et métamorphose du ciel
## - Maintien ~10s puis retour progressif à 100% à la normale (0 coût permanent).

const TREE_BASE_MAT_PATH := "res://objet/tree/tree_material.tres"
const SPECTRAL_TREE_SHADER := preload("res://objet/forest_interactables/oracle_vision/tree_spectral_vision.gdshader")
const TRAIL_PARTICLE_SHADER := preload("res://objet/forest_interactables/oracle_vision/vision_trail_particle.gdshader")
const TOTEM_PILLAR_SHADER := preload("res://objet/forest_interactables/oracle_vision/vision_totem_pillar.gdshader")
const SCREEN_DISTORT_SHADER := preload("res://objet/forest_interactables/oracle_vision/vision_screen_distortion.gdshader")

const SFX_ABSORB_SOFT := "res://assets/sound_effects/UI/wav (HD)/JDSherbert - Ultimate UI SFX Pack - Popup Open - 1.wav"
const SFX_SWELL_SWIPE := "res://assets/sound_effects/UI/wav (HD)/JDSherbert - Ultimate UI SFX Pack - Swipe - 2.wav"
const SFX_EXIT_CLOSE := "res://assets/sound_effects/UI/wav (HD)/JDSherbert - Ultimate UI SFX Pack - Popup Close - 1.wav"
const SFX_ASTRAL_WIND := "res://assets/sound_effects/weather/loops/wind_eerie_storm_loop.wav"

## Durée totale (~0.4s latence douce + ~2.6s montée progressive + ~9.6s pleine vision + ~2.2s retour = 14.8s)
@export var vision_duration: float = 14.8
@export var onset_delay: float = 0.40
@export var fade_in_duration: float = 2.65
@export var fade_out_duration: float = 2.25
@export var particle_count: int = 480
@export var pillar_height: float = 460.0

static var _cached_elem_meshes: Dictionary = {}

var _player: Node3D = null
var _camera: Camera3D = null
var _elapsed: float = 0.0
var _restored: bool = false

var _target_element: String = "arcane"
var _has_valid_totem_target: bool = true
var _origin_anchor: Vector3 = Vector3.ZERO
var _entry_world: Vector3 = Vector3.ZERO
var _totem_world: Vector3 = Vector3.ZERO
var _totem_ground_y: float = 0.0

# Sauvegardes strictes pour restauration à 100%
var _saved_fov: float = 75.0
var _has_saved_fov: bool = false
var _swapped_tree_mmis: Array[Dictionary] = []
var _spectral_tree_mat: ShaderMaterial = null

var _painterly_mat: ShaderMaterial = null
var _saved_outline_darkness: float = 0.55
var _saved_paint_radius: float = 2.5

var _world_env: Environment = null
var _saved_env_props: Dictionary = {}
var _sky_mat: PanoramaSkyMaterial = null
var _saved_sky_energy: float = 2.0

var _dir_light: DirectionalLight3D = null
var _saved_light_color: Color = Color.WHITE
var _saved_light_energy: float = 1.0

# Nœuds visuels temporaires (détruits à la fin)
var _canvas_layer: CanvasLayer = null
var _screen_mat: ShaderMaterial = null
var _trail_mmi: MultiMeshInstance3D = null
var _trail_mat: ShaderMaterial = null
var _pillar_root: Node3D = null
var _pillar_mats: Array[ShaderMaterial] = []
var _drone_player: AudioStreamPlayer = null
var _swell_sound_played: bool = false
var _fade_out_sound_played: bool = false


static func trigger_on_player(player: Node3D, duration_sec: float = 14.8) -> Node3D:
	if player == null or not is_instance_valid(player):
		return null
	if player.multiplayer != null and player.multiplayer.has_multiplayer_peer():
		if not player.is_multiplayer_authority():
			return null

	var existing: Node = player.get_node_or_null("ActiveTotemVisionEffect")
	if existing != null and is_instance_valid(existing):
		if existing.has_method("force_finish_immediately"):
			existing.call("force_finish_immediately")
		existing.free()

	var self_script: GDScript = load("res://objet/forest_interactables/oracle_vision/totem_vision_effect.gd") as GDScript
	var fx: Node3D = self_script.new() as Node3D
	fx.name = "ActiveTotemVisionEffect"
	fx.set("vision_duration", duration_sec)
	player.add_child(fx)
	return fx


func _ready() -> void:
	_player = get_parent() as Node3D
	if _player == null:
		queue_free()
		return

	_camera = _player.get_node_or_null("Camera3D") as Camera3D
	if _camera == null and get_viewport() != null:
		_camera = get_viewport().get_camera_3d()

	_origin_anchor = _player.global_position + Vector3(0.0, 1.35, 0.0)
	_resolve_hidden_totem_target()

	var palette: Dictionary = _get_element_palette(_target_element)
	_setup_screen_distortion_layer(palette)
	_capture_and_prepare_environment()
	_activate_spectral_trees(palette)
	if _has_valid_totem_target:
		_build_particle_river(palette)
		_build_totem_light_pillar(palette)
	_play_vision_audio_enter()


func _exit_tree() -> void:
	_restore_all()


func force_finish_immediately() -> void:
	_restore_all()


func _quintic_smooth(x: float) -> float:
	var c: float = clampf(x, 0.0, 1.0)
	return c * c * c * (c * (c * 6.0 - 15.0) + 10.0)


func _process(delta: float) -> void:
	if _restored:
		return

	_elapsed += delta
	if _elapsed >= vision_duration:
		_restore_all()
		queue_free()
		return

	# Courbe de montée lente : 0 changement pendant `onset_delay` (~0.4s), puis bascule fluide en ~2.65s !
	var in_raw: float = (_elapsed - onset_delay) / maxf(0.1, fade_in_duration)
	var out_raw: float = (vision_duration - _elapsed) / maxf(0.1, fade_out_duration)
	var phase_in: float = _quintic_smooth(in_raw)
	var phase_out: float = _quintic_smooth(out_raw)
	var phase: float = minf(phase_in, phase_out)

	# Légère onde respiratoire pendant la montée entre 0.6s et 3.2s (sans flash brutal à t=0)
	var swell_wave: float = sin(clampf((_elapsed - 0.5) / 2.6, 0.0, 1.0) * PI) * phase

	# Le fleuve de particules et l'immense colonne s'élèvent à mesure que la vision s'ouvre (entre ~0.75s et ~3.4s)
	var reveal: float = _quintic_smooth((_elapsed - 0.75) / 2.45)
	var pillar_rise: float = _quintic_smooth((_elapsed - 0.85) / 2.35)

	if not _swell_sound_played and _elapsed >= 0.75:
		_swell_sound_played = true
		_play_one_shot_2d(SFX_SWELL_SWIPE, 0.50, -7.5)

	if not _fade_out_sound_played and (vision_duration - _elapsed) <= fade_out_duration * 0.75:
		_fade_out_sound_played = true
		_play_one_shot_2d(SFX_EXIT_CLOSE, 0.60, -10.5)

	# 1. Shader d'écran (distorsion + aberration chromatique progressives)
	if _screen_mat != null:
		_screen_mat.set_shader_parameter("intensity", phase)
		_screen_mat.set_shader_parameter("shockwave", swell_wave)

	# 2. Translucidité spectrale des arbres + adoucissement Kuwahara (zéro pointillé noir !)
	if _spectral_tree_mat != null:
		_spectral_tree_mat.set_shader_parameter("vision_phase", phase)
	if _painterly_mat != null:
		_painterly_mat.set_shader_parameter("outline_darkness", lerpf(_saved_outline_darkness, 0.05, phase))
		_painterly_mat.set_shader_parameter("paint_radius", lerpf(_saved_paint_radius, maxf(_saved_paint_radius, 3.2), phase))

	# 3. Fleuve de particules élémentaires
	if _trail_mat != null and _player != null and is_instance_valid(_player):
		_trail_mat.set_shader_parameter("player_pos", _player.global_position + Vector3(0.0, 1.35, 0.0))
		_trail_mat.set_shader_parameter("reveal_progress", reveal)
		_trail_mat.set_shader_parameter("master_intensity", phase * 1.2)

	# 4. Énorme colonne de lumière sur l'emplacement exact du totem caché
	for p_mat: ShaderMaterial in _pillar_mats:
		if p_mat != null:
			p_mat.set_shader_parameter("rise_progress", pillar_rise)
			p_mat.set_shader_parameter("master_intensity", phase * 1.25)

	# 5. Déformation progressive du FOV caméra
	if _camera != null and is_instance_valid(_camera) and _has_saved_fov:
		var fov_breath: float = sin(_elapsed * 2.1) * 2.0
		_camera.fov = _saved_fov + (10.5 + fov_breath) * phase

	# 6. Métamorphose chromatique progressive du ciel et du brouillard
	_update_environment_shift(phase, swell_wave)

	# 7. Drone sonore éthéré
	if _drone_player != null and is_instance_valid(_drone_player):
		_drone_player.volume_db = lerpf(-45.0, -11.0, phase)
		_drone_player.pitch_scale = 0.52 + 0.05 * sin(_elapsed * 1.6)


# =========================================================================
# 1. CIBLE : SÉLECTION D'UN TOTEM CACHÉ NON PURIFIÉ (EXCLUT 100% LES TOTEMS CLEAR)
# =========================================================================
func _is_totem_cleared(totem_node: Node) -> bool:
	if totem_node == null or not is_instance_valid(totem_node):
		return false
	if totem_node.get("is_completed") == true:
		return true
	if totem_node.get("reward_claimed_local") == true:
		return true
	if totem_node.get("is_cleared") == true:
		return true
	return false


func _find_arena_totem_node(arena_inst: Node3D) -> Node3D:
	if arena_inst == null or not is_instance_valid(arena_inst):
		return null
	var active_t: Node3D = arena_inst.get("_active_totem") as Node3D
	if active_t != null and is_instance_valid(active_t):
		return active_t
	active_t = arena_inst.get_node_or_null("SpawnedTotem") as Node3D
	if active_t != null and is_instance_valid(active_t):
		return active_t
	for ch: Node in arena_inst.get_children():
		if ch is Node3D and ch.is_in_group("EnchantTotem"):
			return ch as Node3D
	return null


func _pick_closest_candidate(candidates: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	var best_dist_sq: float = INF
	for cand: Dictionary in candidates:
		var d_sq: float = float(cand.get("dist_sq", INF))
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best = cand
	return best


func _resolve_hidden_totem_target() -> void:
	_has_valid_totem_target = true
	var map_gen: Node = _find_map_generator()
	var player_2d := Vector2(_origin_anchor.x, _origin_anchor.z)
	var hidden_uncleared: Array[Dictionary] = []
	var road_uncleared: Array[Dictionary] = []
	var had_any_totem_on_map: bool = false

	if map_gen != null and map_gen.has_method("get_arena_generator"):
		var arena_gen: Node = map_gen.get_arena_generator()
		if arena_gen != null and arena_gen.has_method("get_zones"):
			var zones: Array = arena_gen.get_zones()
			for z_var in zones:
				var z: Dictionary = z_var as Dictionary
				if not bool(z.get("has_totem", false)):
					continue
				had_any_totem_on_map = true
				var z_name: String = str(z.get("name", ""))
				var is_extra: bool = bool(z.get("is_extra", false))
				var hole_2d: Vector2 = z.get("pos", Vector2.ZERO)
				var totem_2d: Vector2 = z.get("totem_pos", Vector2.ZERO)

				var elem: String = "arcane"
				var is_cleared: bool = false
				var totem_3d := Vector3.ZERO
				var ground_y_val: float = _origin_anchor.y - 1.35
				var has_3d: bool = false

				var arena_inst: Node3D = arena_gen.get_node_or_null(z_name) as Node3D
				var active_t: Node3D = _find_arena_totem_node(arena_inst)
				if arena_inst != null and active_t == null:
					# Arène d'enchantement sans totem actif (ex: plafond des 4 éléments uniques déjà atteint)
					continue
				if active_t != null:
					var raw_e: String = str(active_t.get("totem_element")).strip_edges().to_lower()
					if raw_e in ["arcane", "lightning", "ice", "fire"]:
						elem = raw_e
					is_cleared = _is_totem_cleared(active_t)
					ground_y_val = active_t.global_position.y
					totem_3d = active_t.global_position + Vector3(0.0, 1.85, 0.0)
					has_3d = true

				# Règle absolue : un totem clear ne peut PLUS JAMAIS être traqué par une graine !
				if is_cleared:
					continue

				var entry_h: float = float(z.get("height", ground_y_val))
				if is_nan(entry_h) and map_gen.has_method("get_terrain_height_at"):
					entry_h = float(map_gen.call("get_terrain_height_at", hole_2d.x, hole_2d.y))
				if is_nan(entry_h):
					entry_h = ground_y_val

				var entry_3d := Vector3(hole_2d.x, entry_h + 1.85, hole_2d.y)
				if not has_3d:
					ground_y_val = entry_h
					totem_3d = Vector3(totem_2d.x, entry_h + 1.85, totem_2d.y)

				var dist_sq: float = player_2d.distance_squared_to(Vector2(totem_3d.x, totem_3d.z))
				var item: Dictionary = {
					"element": elem,
					"entry_3d": entry_3d,
					"totem_3d": totem_3d,
					"ground_y": ground_y_val,
					"dist_sq": dist_sq
				}
				if is_extra:
					hidden_uncleared.append(item)
				else:
					road_uncleared.append(item)

	var chosen: Dictionary = {}
	if not hidden_uncleared.is_empty():
		chosen = _pick_closest_candidate(hidden_uncleared)
	elif not road_uncleared.is_empty():
		chosen = _pick_closest_candidate(road_uncleared)
	else:
		var standalone_uncleared: Array[Dictionary] = []
		for t_node: Node in get_tree().get_nodes_in_group("EnchantTotem"):
			if t_node is Node3D and is_instance_valid(t_node):
				had_any_totem_on_map = true
				if _is_totem_cleared(t_node):
					continue
				var te: String = str(t_node.get("totem_element")).strip_edges().to_lower()
				var gp: Vector3 = (t_node as Node3D).global_position
				var d_sq_st: float = player_2d.distance_squared_to(Vector2(gp.x, gp.z))
				standalone_uncleared.append({
					"element": te if te in ["arcane", "lightning", "ice", "fire"] else "arcane",
					"entry_3d": _origin_anchor.lerp(gp, 0.75),
					"totem_3d": gp + Vector3(0.0, 1.85, 0.0),
					"ground_y": gp.y,
					"dist_sq": d_sq_st
				})
		if not standalone_uncleared.is_empty():
			chosen = _pick_closest_candidate(standalone_uncleared)

	if chosen.is_empty():
		# Tous les totems de la carte sont terminés -> orienter la Vision Astrale vers l'Arène du Boss !
		var boss_target: Dictionary = _resolve_closest_boss_arena(map_gen, player_2d)
		if not boss_target.is_empty():
			chosen = boss_target

	if chosen.is_empty():
		if had_any_totem_on_map:
			# Aucun totem restant et aucune arène de boss trouvée
			_has_valid_totem_target = false
			_target_element = "arcane"
			print("[TotemVisionEffect] Tous les totems sont purifiés et aucune BossArena n'est présente.")
			return
		# Uniquement pour une scène bac-à-sable isolée sans aucun totem ni boss dans l'arbre
		_target_element = "arcane"
		_totem_ground_y = _origin_anchor.y - 1.35
		_entry_world = _origin_anchor + Vector3(0.0, 0.0, -140.0)
		_totem_world = _origin_anchor + Vector3(0.0, 0.0, -210.0)
	else:
		_target_element = str(chosen["element"])
		_entry_world = chosen["entry_3d"] as Vector3
		_totem_world = chosen["totem_3d"] as Vector3
		_totem_ground_y = float(chosen["ground_y"])

	var final_dist_m: float = sqrt(player_2d.distance_squared_to(Vector2(_totem_world.x, _totem_world.z)))
	if _target_element == "boss":
		print("[TotemVisionEffect] Tous les totems sont terminés -> Vision dirigée vers l'Arène du Boss (%.1f m) -> %v" % [final_dist_m, _totem_world])
	else:
		print("[TotemVisionEffect] Vision vers le totem le plus proche '%s' (%.1f m) -> totem=%v" % [_target_element, final_dist_m, _totem_world])


func _resolve_closest_boss_arena(map_gen: Node, player_2d: Vector2) -> Dictionary:
	var undefeated_candidates: Array[Dictionary] = []
	var all_candidates: Array[Dictionary] = []

	if map_gen != null and map_gen.has_method("get_arena_generator"):
		var arena_gen: Node = map_gen.get_arena_generator()
		if arena_gen != null and arena_gen.has_method("get_zones"):
			for z_var in arena_gen.get_zones():
				var z: Dictionary = z_var as Dictionary
				if bool(z.get("has_totem", false)):
					continue
				var z_name: String = str(z.get("name", ""))
				var hole_2d: Vector2 = z.get("pos", Vector2.ZERO)
				var center_2d: Vector2 = z.get("center", hole_2d)
				var arena_inst: Node3D = arena_gen.get_node_or_null(z_name) as Node3D
				if arena_inst != null and arena_inst.is_in_group("EnchantArena"):
					continue

				var ground_y_val: float = float(z.get("height", NAN))
				if is_nan(ground_y_val) and map_gen.has_method("get_terrain_height_at"):
					ground_y_val = float(map_gen.call("get_terrain_height_at", hole_2d.x, hole_2d.y))
				if is_nan(ground_y_val):
					ground_y_val = arena_inst.global_position.y if arena_inst != null else (_origin_anchor.y - 1.35)

				var entry_3d := Vector3(hole_2d.x, ground_y_val + 1.85, hole_2d.y)
				var boss_3d := Vector3(center_2d.x, ground_y_val + 2.0, center_2d.y)
				var boss_ground_y: float = ground_y_val
				var is_defeated: bool = false

				if arena_inst != null:
					is_defeated = bool(arena_inst.get("_reward_spawned"))
					var entry_m: Node3D = arena_inst.get_node_or_null("entry") as Node3D
					if entry_m != null:
						entry_3d = Vector3(entry_m.global_position.x, ground_y_val + 1.85, entry_m.global_position.z)

					var live_boss: Node3D = arena_inst.get("_active_boss") as Node3D
					var spawn_m: Node3D = arena_inst.get_node_or_null("Boss_spawn_position") as Node3D
					if live_boss != null and is_instance_valid(live_boss):
						boss_ground_y = live_boss.global_position.y
						boss_3d = live_boss.global_position + Vector3(0.0, 2.0, 0.0)
					elif spawn_m != null:
						var sp_gp: Vector3 = spawn_m.global_position
						var sp_h: float = ground_y_val
						if map_gen.has_method("get_terrain_height_at"):
							var sampled_sp_h: float = float(map_gen.call("get_terrain_height_at", sp_gp.x, sp_gp.z))
							if not is_nan(sampled_sp_h):
								sp_h = sampled_sp_h
						boss_ground_y = sp_h
						boss_3d = Vector3(sp_gp.x, sp_h + 2.0, sp_gp.z)

				var dist_sq: float = player_2d.distance_squared_to(Vector2(boss_3d.x, boss_3d.z))
				var cand: Dictionary = {
					"element": "boss",
					"entry_3d": entry_3d,
					"totem_3d": boss_3d,
					"ground_y": boss_ground_y,
					"dist_sq": dist_sq
				}
				all_candidates.append(cand)
				if not is_defeated:
					undefeated_candidates.append(cand)

	if all_candidates.is_empty() and get_tree() != null:
		for node_b: Node in get_tree().get_nodes_in_group("BossArena"):
			if not (node_b is BossArena) or not is_instance_valid(node_b):
				continue
			var ba := node_b as BossArena
			var gy_b: float = ba.global_position.y
			var entry_m2: Node3D = ba.get_node_or_null("entry") as Node3D
			var spawn_m2: Node3D = ba.get_node_or_null("Boss_spawn_position") as Node3D
			var boss_pos_3d: Vector3 = (spawn_m2.global_position if spawn_m2 != null else ba.global_position) + Vector3(0.0, 2.0, 0.0)
			if spawn_m2 != null:
				gy_b = spawn_m2.global_position.y
			var entry_pos_3d: Vector3 = (
				Vector3(entry_m2.global_position.x, gy_b + 1.85, entry_m2.global_position.z)
				if entry_m2 != null
				else _origin_anchor.lerp(boss_pos_3d, 0.72)
			)
			var d_sq_b: float = player_2d.distance_squared_to(Vector2(boss_pos_3d.x, boss_pos_3d.z))
			var cand_b: Dictionary = {
				"element": "boss",
				"entry_3d": entry_pos_3d,
				"totem_3d": boss_pos_3d,
				"ground_y": gy_b,
				"dist_sq": d_sq_b
			}
			all_candidates.append(cand_b)
			if not bool(ba.get("_reward_spawned")):
				undefeated_candidates.append(cand_b)

	if not undefeated_candidates.is_empty():
		return _pick_closest_candidate(undefeated_candidates)
	if not all_candidates.is_empty():
		return _pick_closest_candidate(all_candidates)
	return {}


func _find_map_generator() -> Node:
	if get_tree() == null or get_tree().root == null:
		return null
	var mg: Node = get_tree().root.find_child("Map_generator", true, false)
	if mg != null:
		return mg
	for n: Node in get_tree().root.find_children("*", "Node3D", true, false):
		if n.has_method("get_arena_generator") and n.has_method("get_terrain_height_at"):
			return n
	return null


# =========================================================================
# 2. PALETTES ÉLÉMENTAIRES & MAILLAGES 3D DES 4 TOTEMS
# =========================================================================
func _get_element_palette(elem: String) -> Dictionary:
	match elem:
		"lightning":
			return {
				"mode": 1,
				"primary": Color(0.15, 1.45, 3.1),
				"secondary": Color(0.35, 0.55, 2.5),
				"core": Color(1.9, 2.45, 3.5),
				"tree_a": Color(0.28, 0.92, 1.35),
				"tree_b": Color(0.65, 0.38, 1.30),
				"sky_fog": Color(0.05, 0.16, 0.34),
				"sky_ambient": Color(0.30, 0.58, 0.95),
				"screen_tint": Color(0.32, 0.82, 1.0)
			}
		"ice":
			return {
				"mode": 2,
				"primary": Color(0.32, 1.85, 2.65),
				"secondary": Color(0.55, 1.05, 2.35),
				"core": Color(1.85, 2.45, 2.95),
				"tree_a": Color(0.42, 0.98, 1.25),
				"tree_b": Color(0.52, 0.58, 1.32),
				"sky_fog": Color(0.04, 0.19, 0.28),
				"sky_ambient": Color(0.38, 0.78, 0.95),
				"screen_tint": Color(0.42, 0.92, 1.0)
			}
		"fire":
			return {
				"mode": 3,
				"primary": Color(2.85, 0.85, 0.14),
				"secondary": Color(2.35, 0.20, 0.38),
				"core": Color(3.2, 2.1, 0.65),
				"tree_a": Color(1.20, 0.42, 0.22),
				"tree_b": Color(0.95, 0.22, 0.85),
				"sky_fog": Color(0.26, 0.05, 0.14),
				"sky_ambient": Color(0.88, 0.36, 0.48),
				"screen_tint": Color(1.0, 0.44, 0.28)
			}
		"boss":
			return {
				"mode": 3,
				"primary": Color(3.15, 0.22, 0.18),
				"secondary": Color(2.85, 1.55, 0.24),
				"core": Color(3.55, 2.70, 1.50),
				"tree_a": Color(1.30, 0.24, 0.24),
				"tree_b": Color(1.18, 0.76, 0.22),
				"sky_fog": Color(0.28, 0.03, 0.06),
				"sky_ambient": Color(0.92, 0.30, 0.24),
				"screen_tint": Color(1.0, 0.30, 0.22)
			}
		_: # "arcane"
			return {
				"mode": 0,
				"primary": Color(1.75, 0.28, 2.75),
				"secondary": Color(0.48, 0.78, 2.85),
				"core": Color(2.35, 1.75, 3.10),
				"tree_a": Color(0.88, 0.32, 1.35),
				"tree_b": Color(0.35, 0.82, 1.30),
				"sky_fog": Color(0.19, 0.04, 0.30),
				"sky_ambient": Color(0.68, 0.34, 0.95),
				"screen_tint": Color(0.82, 0.36, 1.0)
			}


static func _get_element_particle_mesh(elem: String) -> ArrayMesh:
	if _cached_elem_meshes.has(elem):
		return _cached_elem_meshes[elem]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	match elem:
		"lightning":
			_append_bipyramid(st, 0.22, 0.78, 4, Transform3D.IDENTITY)
			var zig_t := Transform3D(Basis(Vector3(0.0, 0.0, 1.0), 0.42), Vector3.ZERO)
			_append_bipyramid(st, 0.10, 0.96, 4, zig_t)
		"ice":
			_append_bipyramid(st, 0.24, 0.68, 6, Transform3D.IDENTITY)
			var shard1 := Transform3D(Basis(Vector3(1.0, 0.0, 0.0), 1.05), Vector3.ZERO)
			var shard2 := Transform3D(Basis(Vector3(0.0, 0.0, 1.0), -1.05), Vector3.ZERO)
			_append_bipyramid(st, 0.11, 0.56, 4, shard1)
			_append_bipyramid(st, 0.11, 0.56, 4, shard2)
		"fire":
			_append_bipyramid(st, 0.32, 0.36, 5, Transform3D(Basis(Vector3(1.0, 0.4, 0.0).normalized(), 0.5), Vector3.ZERO))
			_append_flat_ring(st, 0.46, 0.56, 8, Transform3D(Basis(Vector3(1.0, 0.0, 0.0), 0.65), Vector3.ZERO))
			_append_flat_ring(st, 0.40, 0.49, 8, Transform3D(Basis(Vector3(0.0, 0.0, 1.0), -0.75), Vector3.ZERO))
		"boss":
			_append_bipyramid(st, 0.30, 0.62, 8, Transform3D.IDENTITY)
			_append_flat_ring(st, 0.52, 0.64, 8, Transform3D(Basis(Vector3(1.0, 0.0, 0.0), 0.72), Vector3.ZERO))
			_append_flat_ring(st, 0.52, 0.64, 8, Transform3D(Basis(Vector3(0.0, 0.0, 1.0), -0.72), Vector3.ZERO))
		_:
			_append_icosahedron(st, 0.34)
			_append_flat_ring(st, 0.46, 0.54, 8, Transform3D(Basis(Vector3(1.0, 0.0, 0.35).normalized(), 0.55), Vector3.ZERO))

	st.generate_normals()
	var built: ArrayMesh = st.commit()
	_cached_elem_meshes[elem] = built
	return built


static func _emit_face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n: Vector3 = (b - a).cross(c - a).normalized()
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
	st.add_vertex(c)


static func _append_bipyramid(st: SurfaceTool, radius: float, half_height: float, sides: int, xf: Transform3D) -> void:
	var top: Vector3 = xf * Vector3(0.0, half_height, 0.0)
	var bot: Vector3 = xf * Vector3(0.0, -half_height, 0.0)
	for i in range(sides):
		var a0: float = TAU * float(i) / float(sides)
		var a1: float = TAU * float(i + 1) / float(sides)
		var p0: Vector3 = xf * Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1: Vector3 = xf * Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		_emit_face(st, top, p1, p0)
		_emit_face(st, bot, p0, p1)


static func _append_flat_ring(st: SurfaceTool, r_in: float, r_out: float, sides: int, xf: Transform3D) -> void:
	for i in range(sides):
		var a0: float = TAU * float(i) / float(sides)
		var a1: float = TAU * float(i + 1) / float(sides)
		var i0: Vector3 = xf * Vector3(cos(a0) * r_in, 0.0, sin(a0) * r_in)
		var i1: Vector3 = xf * Vector3(cos(a1) * r_in, 0.0, sin(a1) * r_in)
		var o0: Vector3 = xf * Vector3(cos(a0) * r_out, 0.0, sin(a0) * r_out)
		var o1: Vector3 = xf * Vector3(cos(a1) * r_out, 0.0, sin(a1) * r_out)
		_emit_face(st, i0, o0, o1)
		_emit_face(st, i0, o1, i1)


static func _append_icosahedron(st: SurfaceTool, radius: float) -> void:
	var t: float = (1.0 + sqrt(5.0)) * 0.5
	var raw_v: Array[Vector3] = [
		Vector3(-1,  t,  0), Vector3( 1,  t,  0), Vector3(-1, -t,  0), Vector3( 1, -t,  0),
		Vector3( 0, -1,  t), Vector3( 0,  1,  t), Vector3( 0, -1, -t), Vector3( 0,  1, -t),
		Vector3( t,  0, -1), Vector3( t,  0,  1), Vector3(-t,  0, -1), Vector3(-t,  0,  1)
	]
	var v: Array[Vector3] = []
	for rv in raw_v:
		v.append(rv.normalized() * radius)
	var faces: Array = [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]
	]
	for f in faces:
		_emit_face(st, v[f[0]], v[f[2]], v[f[1]])


# =========================================================================
# 3. FLEUVE DE PARTICULES 3D + ÉNORME COLONNE DE LUMIÈRE SUR LE TOTEM
# =========================================================================
func _build_particle_river(palette: Dictionary) -> void:
	var map_gen: Node = _find_map_generator()
	var curve_points: int = 96

	var start_2d := Vector2(_origin_anchor.x, _origin_anchor.z)
	var entry_2d := Vector2(_entry_world.x, _entry_world.z)
	var totem_2d := Vector2(_totem_world.x, _totem_world.z)

	var to_entry: Vector2 = entry_2d - start_2d
	var dist_entry: float = maxf(1.0, to_entry.length())
	var dir_to_entry: Vector2 = to_entry / dist_entry
	var perp_entry := Vector2(-dir_to_entry.y, dir_to_entry.x)

	var arena_in_dir: Vector2 = (totem_2d - entry_2d).normalized()
	if arena_in_dir.length_squared() < 0.01:
		arena_in_dir = dir_to_entry
	var approach_2d: Vector2 = entry_2d - arena_in_dir * minf(34.0, dist_entry * 0.25)
	var mid_2d: Vector2 = start_2d.lerp(approach_2d, 0.48) + perp_entry * clampf(dist_entry * 0.07, 8.0, 28.0)

	var curve := Curve3D.new()
	curve.add_point(_origin_anchor)
	curve.add_point(Vector3(mid_2d.x, _origin_anchor.y, mid_2d.y))
	curve.add_point(Vector3(approach_2d.x, _entry_world.y, approach_2d.y))
	curve.add_point(_entry_world)
	curve.add_point(_totem_world)
	curve.bake_interval = 4.0

	var baked_len: float = maxf(1.0, curve.get_baked_length())
	var img: Image = Image.create(curve_points, 1, false, Image.FORMAT_RGBF)

	for i in range(curve_points):
		var u: float = float(i) / float(curve_points - 1)
		var pt: Vector3 = curve.sample_baked(u * baked_len)
		var ground_y: float = pt.y - 1.85
		if map_gen != null and map_gen.has_method("get_terrain_height_at"):
			var sampled_h: float = float(map_gen.call("get_terrain_height_at", pt.x, pt.z))
			if not is_nan(sampled_h):
				ground_y = sampled_h
		var hover_y: float = lerpf(1.75, 2.35, 0.5 + 0.5 * sin(u * 16.0))
		var final_y: float = ground_y + hover_y
		if u > 0.94:
			final_y = lerpf(final_y, _totem_world.y + 0.35, (u - 0.94) / 0.06)
		img.set_pixel(i, 0, Color(pt.x, final_y, pt.z, 1.0))

	var curve_tex: ImageTexture = ImageTexture.create_from_image(img)

	_trail_mat = ShaderMaterial.new()
	_trail_mat.render_priority = 6
	_trail_mat.shader = TRAIL_PARTICLE_SHADER
	_trail_mat.set_shader_parameter("curve_tex", curve_tex)
	_trail_mat.set_shader_parameter("elem_mode", int(palette["mode"]))
	_trail_mat.set_shader_parameter("color_primary", palette["primary"])
	_trail_mat.set_shader_parameter("color_secondary", palette["secondary"])
	_trail_mat.set_shader_parameter("color_core", palette["core"])
	_trail_mat.set_shader_parameter("origin_anchor", _origin_anchor)
	_trail_mat.set_shader_parameter("player_pos", _origin_anchor)
	_trail_mat.set_shader_parameter("reveal_progress", 0.0)
	_trail_mat.set_shader_parameter("master_intensity", 0.0)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _get_element_particle_mesh(_target_element)
	mm.instance_count = particle_count

	var rng := RandomNumberGenerator.new()
	rng.seed = 9876543
	for idx in range(particle_count):
		mm.set_instance_transform(idx, Transform3D.IDENTITY)
		var u_seed: float = float(idx) / float(particle_count)
		var rad_seed: float = rng.randf()
		var phase_seed: float = rng.randf()
		var scale_m: float = rng.randf_range(0.65, 1.65)
		mm.set_instance_custom_data(idx, Color(u_seed, rad_seed, phase_seed, scale_m))

	_trail_mmi = MultiMeshInstance3D.new()
	_trail_mmi.name = "VisionTotemTrailMultiMesh"
	_trail_mmi.top_level = true
	_trail_mmi.global_transform = Transform3D.IDENTITY
	_trail_mmi.layers = 2
	_trail_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail_mmi.ignore_occlusion_culling = true
	_trail_mmi.extra_cull_margin = 4096.0
	_trail_mmi.custom_aabb = AABB(Vector3(-4096.0, -512.0, -4096.0), Vector3(8192.0, 1536.0, 8192.0))
	_trail_mmi.material_override = _trail_mat
	_trail_mmi.multimesh = mm
	add_child(_trail_mmi)


func _build_totem_light_pillar(palette: Dictionary) -> void:
	_pillar_root = Node3D.new()
	_pillar_root.name = "VisionTotemLightPillar"
	_pillar_root.top_level = true
	add_child(_pillar_root)
	_pillar_root.global_position = Vector3(_totem_world.x, _totem_ground_y - 1.5, _totem_world.z)

	_pillar_mats.clear()
	# 3 couches concentriques (Coeur incandescent + Vortex élémentaire animé + Large Halo céleste)
	var specs: Array[Dictionary] = [
		{"kind": 0, "r_bot": 2.8,  "r_top": 4.4,  "prio": 8, "rings": 20},
		{"kind": 1, "r_bot": 7.8,  "r_top": 12.0, "prio": 7, "rings": 28},
		{"kind": 2, "r_bot": 18.5, "r_top": 30.0, "prio": 5, "rings": 16}
	]

	for sp: Dictionary in specs:
		var cyl := CylinderMesh.new()
		cyl.bottom_radius = float(sp["r_bot"])
		cyl.top_radius = float(sp["r_top"])
		cyl.height = pillar_height
		cyl.radial_segments = 28
		cyl.rings = int(sp["rings"])
		cyl.cap_top = false
		cyl.cap_bottom = false

		var pmat := ShaderMaterial.new()
		pmat.render_priority = int(sp["prio"])
		pmat.shader = TOTEM_PILLAR_SHADER
		pmat.set_shader_parameter("elem_mode", int(palette["mode"]))
		pmat.set_shader_parameter("color_primary", palette["primary"])
		pmat.set_shader_parameter("color_secondary", palette["secondary"])
		pmat.set_shader_parameter("color_core", palette["core"])
		pmat.set_shader_parameter("layer_kind", int(sp["kind"]))
		pmat.set_shader_parameter("rise_progress", 0.0)
		pmat.set_shader_parameter("master_intensity", 0.0)
		_pillar_mats.append(pmat)

		var mi := MeshInstance3D.new()
		mi.name = "PillarLayer_" + str(sp["kind"])
		mi.position = Vector3(0.0, pillar_height * 0.5, 0.0)
		mi.mesh = cyl
		mi.material_override = pmat
		mi.layers = 2
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.ignore_occlusion_culling = true
		mi.extra_cull_margin = 4096.0
		_pillar_root.add_child(mi)


# =========================================================================
# 4. ARBRES FANTOMATIQUES TRANSLUCIDES (TRANSITION 100% CONTINUE)
# =========================================================================
func _activate_spectral_trees(palette: Dictionary) -> void:
	var base_mat: ShaderMaterial = load(TREE_BASE_MAT_PATH) as ShaderMaterial
	_spectral_tree_mat = ShaderMaterial.new()
	_spectral_tree_mat.shader = SPECTRAL_TREE_SHADER

	if base_mat != null:
		for param_name: String in [
			"albedo", "texture_albedo", "texture_normal", "normal_scale",
			"texture_ambient_occlusion", "ao_texture_channel", "ao_light_affect", "ao_strength",
			"uv1_scale", "uv1_offset",
			"wind_direction", "wind_speed", "wind_strength",
			"max_sway_distance", "calm_amplitude_ratio", "sway_frequency",
			"gust_frequency", "trunk_tension", "rebound_amount",
			"storm_base_lean", "lateral_amount", "vertical_dip", "wind_max_distance"
		]:
			var val: Variant = base_mat.get_shader_parameter(param_name)
			if val != null:
				_spectral_tree_mat.set_shader_parameter(param_name, val)

	_spectral_tree_mat.set_shader_parameter("vision_phase", 0.0)
	_spectral_tree_mat.set_shader_parameter("vision_tint_primary", palette["tree_a"])
	_spectral_tree_mat.set_shader_parameter("vision_tint_secondary", palette["tree_b"])

	var wind_singleton: Node = get_node_or_null("/root/Wind")
	if wind_singleton != null and wind_singleton.has_method("register_grass_material"):
		wind_singleton.call("register_grass_material", _spectral_tree_mat)

	# Adoucissement temporaire des contours profonds du painterly_shader sur le joueur local
	if _camera != null and is_instance_valid(_camera):
		var g_quad: MeshInstance3D = _camera.get_node_or_null("global_shader/quad_mesh") as MeshInstance3D
		if g_quad != null and g_quad.material_override is ShaderMaterial:
			var sm: ShaderMaterial = g_quad.material_override as ShaderMaterial
			var od: Variant = sm.get_shader_parameter("outline_darkness")
			if od != null:
				_painterly_mat = sm
				_saved_outline_darkness = float(od)
				var pr: Variant = sm.get_shader_parameter("paint_radius")
				if pr != null:
					_saved_paint_radius = float(pr)

	_swapped_tree_mmis.clear()
	var map_gen: Node = _find_map_generator()
	if map_gen != null:
		for container_name: String in ["MeshSpawner", "BorderTreeWall", "ArenaGenerator"]:
			var container: Node = map_gen.get_node_or_null(container_name)
			if container == null:
				continue
			for mmi_node: Node in container.find_children("*", "MultiMeshInstance3D", true, false):
				var mmi: MultiMeshInstance3D = mmi_node as MultiMeshInstance3D
				if mmi != null and is_instance_valid(mmi):
					_swapped_tree_mmis.append({
						"ref": weakref(mmi),
						"orig_mat": mmi.material_override
					})
					mmi.material_override = _spectral_tree_mat


# =========================================================================
# 5. DISTORSION ÉCRAN, ABERRATION CHROMATIQUE & CIEL ALTÉRÉ
# =========================================================================
func _setup_screen_distortion_layer(palette: Dictionary) -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "TotemVisionScreenLayer"
	_canvas_layer.layer = 0

	var rect := ColorRect.new()
	rect.name = "DistortionQuad"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_screen_mat = ShaderMaterial.new()
	_screen_mat.shader = SCREEN_DISTORT_SHADER
	_screen_mat.set_shader_parameter("intensity", 0.0)
	_screen_mat.set_shader_parameter("shockwave", 0.0)
	_screen_mat.set_shader_parameter("elem_tint", palette["screen_tint"])
	rect.material = _screen_mat

	_canvas_layer.add_child(rect)
	add_child(_canvas_layer)


func _capture_and_prepare_environment() -> void:
	if _camera != null and is_instance_valid(_camera):
		_saved_fov = _camera.fov
		_has_saved_fov = true

	if get_tree() == null or get_tree().root == null:
		return

	var we_list: Array[Node] = get_tree().root.find_children("*", "WorldEnvironment", true, false)
	for we_node: Node in we_list:
		var we: WorldEnvironment = we_node as WorldEnvironment
		if we != null and we.environment != null:
			_world_env = we.environment
			break

	if _world_env != null:
		_saved_env_props = {
			"ambient_light_color": _world_env.ambient_light_color,
			"ambient_light_energy": _world_env.ambient_light_energy,
			"fog_light_color": _world_env.fog_light_color,
			"fog_sky_affect": _world_env.fog_sky_affect,
			"volumetric_fog_albedo": _world_env.volumetric_fog_albedo,
			"volumetric_fog_emission": _world_env.volumetric_fog_emission,
			"volumetric_fog_emission_energy": _world_env.volumetric_fog_emission_energy,
			"volumetric_fog_sky_affect": _world_env.volumetric_fog_sky_affect,
			"glow_intensity": _world_env.glow_intensity,
			"glow_bloom": _world_env.glow_bloom,
			"background_energy_multiplier": _world_env.background_energy_multiplier
		}
		if _world_env.sky != null and _world_env.sky.sky_material is PanoramaSkyMaterial:
			_sky_mat = _world_env.sky.sky_material as PanoramaSkyMaterial
			_saved_sky_energy = _sky_mat.energy_multiplier

	var dl_list: Array[Node] = get_tree().root.find_children("*", "DirectionalLight3D", true, false)
	for dl_node: Node in dl_list:
		var dl: DirectionalLight3D = dl_node as DirectionalLight3D
		if dl != null and dl.visible:
			_dir_light = dl
			_saved_light_color = dl.light_color
			_saved_light_energy = dl.light_energy
			break


func _update_environment_shift(phase: float, swell_wave: float) -> void:
	var palette: Dictionary = _get_element_palette(_target_element)
	var pulse: float = 0.5 + 0.5 * sin(_elapsed * 2.4)
	var astral_violet := Color(0.22, 0.04, 0.32)
	var target_fog_col: Color = (palette["sky_fog"] as Color).lerp(astral_violet, 0.40 * pulse)
	var target_amb_col: Color = (palette["sky_ambient"] as Color).lerp(Color(0.75, 0.30, 0.95), 0.35 * (1.0 - pulse))

	if _world_env != null and not _saved_env_props.is_empty():
		_world_env.ambient_light_color = (_saved_env_props["ambient_light_color"] as Color).lerp(target_amb_col, phase * 0.85)
		_world_env.ambient_light_energy = lerpf(float(_saved_env_props["ambient_light_energy"]), 1.85, phase)
		_world_env.fog_light_color = (_saved_env_props["fog_light_color"] as Color).lerp(target_fog_col, phase * 0.92)
		_world_env.fog_sky_affect = lerpf(float(_saved_env_props["fog_sky_affect"]), 0.94, phase)
		_world_env.volumetric_fog_albedo = (_saved_env_props["volumetric_fog_albedo"] as Color).lerp(target_fog_col * 1.4, phase * 0.88)
		_world_env.volumetric_fog_emission = (_saved_env_props["volumetric_fog_emission"] as Color).lerp(target_fog_col * 0.48, phase * 0.92)
		_world_env.volumetric_fog_emission_energy = lerpf(float(_saved_env_props["volumetric_fog_emission_energy"]), 7.5, phase)
		_world_env.volumetric_fog_sky_affect = lerpf(float(_saved_env_props["volumetric_fog_sky_affect"]), 0.99, phase)
		_world_env.glow_intensity = lerpf(float(_saved_env_props["glow_intensity"]), 1.42 + swell_wave * 0.22, phase)
		_world_env.glow_bloom = lerpf(float(_saved_env_props["glow_bloom"]), 0.30 + swell_wave * 0.08, phase)
		_world_env.background_energy_multiplier = lerpf(float(_saved_env_props["background_energy_multiplier"]), 1.25, phase)

	if _sky_mat != null:
		_sky_mat.energy_multiplier = lerpf(_saved_sky_energy, 3.2, phase)

	if _dir_light != null and is_instance_valid(_dir_light):
		_dir_light.light_color = _saved_light_color.lerp(target_amb_col, phase * 0.80)
		_dir_light.light_energy = lerpf(_saved_light_energy, _saved_light_energy * 1.18, phase)


# =========================================================================
# 6. AUDIO & RESTAURATION GARANTIE À 100%
# =========================================================================
func _play_vision_audio_enter() -> void:
	# Murmure cristallin discret à l'absorption, puis le vrai souffle monte 0.75s plus tard !
	_play_one_shot_2d(SFX_ABSORB_SOFT, 0.85, -11.5)

	if ResourceLoader.exists(SFX_ASTRAL_WIND):
		_drone_player = AudioStreamPlayer.new()
		_drone_player.stream = load(SFX_ASTRAL_WIND)
		_drone_player.pitch_scale = 0.52
		_drone_player.volume_db = -45.0
		if AudioServer.get_bus_index("WeatherAmbience") != -1:
			_drone_player.bus = &"WeatherAmbience"
		add_child(_drone_player)
		_drone_player.play()


func _play_one_shot_2d(res_path: String, pitch: float, vol_db: float) -> void:
	if not ResourceLoader.exists(res_path) or get_tree() == null or get_tree().current_scene == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(res_path)
	p.pitch_scale = pitch
	p.volume_db = vol_db
	get_tree().current_scene.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _restore_all() -> void:
	if _restored:
		return
	_restored = true

	for entry: Dictionary in _swapped_tree_mmis:
		var ref: WeakRef = entry["ref"]
		var mmi: MultiMeshInstance3D = ref.get_ref() as MultiMeshInstance3D
		if mmi != null and is_instance_valid(mmi):
			mmi.material_override = entry["orig_mat"]
	_swapped_tree_mmis.clear()
	_spectral_tree_mat = null

	if _painterly_mat != null:
		_painterly_mat.set_shader_parameter("outline_darkness", _saved_outline_darkness)
		_painterly_mat.set_shader_parameter("paint_radius", _saved_paint_radius)
		_painterly_mat = null

	if _camera != null and is_instance_valid(_camera) and _has_saved_fov:
		_camera.fov = _saved_fov

	if _world_env != null and not _saved_env_props.is_empty():
		for prop_key: String in _saved_env_props.keys():
			_world_env.set(prop_key, _saved_env_props[prop_key])
		_saved_env_props.clear()

	if _sky_mat != null:
		_sky_mat.energy_multiplier = _saved_sky_energy
		_sky_mat = null

	if _dir_light != null and is_instance_valid(_dir_light):
		_dir_light.light_color = _saved_light_color
		_dir_light.light_energy = _saved_light_energy
		_dir_light = null
