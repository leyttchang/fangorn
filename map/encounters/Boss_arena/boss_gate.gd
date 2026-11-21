@tool
class_name BossGate
extends Node3D

## Porte monumentale d'accès à l'Arène du Boss (Style Porte de la Moria / LOTR × Fangorn) :
## - Armature creuse en pierre d'ardoise ancienne avec gravures usées (Couronne de Durin, 7 étoiles,
##   calligraphie elfique, entrelacs nains et arbres jumeaux) + remparts latéraux en ruine
## - Lianes et racines noueuses refermant l'ouverture de l'arche
## - À l'approche et interaction [E], les racines se délient et s'écartent de part et d'autre des piliers,
##   libérant le passage physique vers le Boss (synchronisé en multijoueur).

signal gate_opened(opening_player: Node3D)

@export_category("Interaction & Gameplay")
@export var prompt_text: String = "[E] Écarter les racines"
@export var open_duration: float = 1.85
## Permet de prévisualiser l'état ouvert/fermé directement dans l'éditeur 3D
@export var preview_open_in_editor: bool = false:
	set(val):
		preview_open_in_editor = val
		if is_inside_tree():
			_apply_instant_state(val)
## Curseur éditeur (0 = rétracté, 1 = complet) pour vérifier le pincement du shader en temps réel
@export_range(0.0, 1.0, 0.01) var editor_debut_preview: float = 1.0:
	set(val):
		editor_debut_preview = val
		if Engine.is_editor_hint() and is_inside_tree():
			_apply_editor_debut_preview(val)

@export_category("Dimensions des Remparts Latéraux")
## Extension gauche (mètres) pour rejoindre le mur d'arbres géants sans laisser d'interstice
@export var left_wing_span: float = 19.0
## Extension droite (mètres) pour rejoindre le mur d'arbres géants sans laisser d'interstice
@export var right_wing_span: float = 28.5

const FONT_CINZEL_PATH := "res://assets/fonts/Cinzel.ttf"
const SFX_CREAK_PATH := "res://assets/sound_effects/Combat and Gore/bone_snap.wav"
const SFX_CRUNCH_PATH := "res://assets/sound_effects/Combat and Gore/crunch.wav"
const SFX_SLIDE_PATH := "res://assets/sound_effects/UI/wav (HD)/woosh_5.wav"

const DOOR_HALF_WIDTH := 4.98
const PILLAR_WIDTH := 3.40
const PILLAR_HEIGHT := 6.09
const PILLAR_DEPTH := 2.40
const PLINTH_TOP_Y := 1.22
const ARCH_BASE_Y := 7.74
const ARCH_HEIGHT := 8.65
const ARCH_CROWN_H := 5.24

var is_open: bool = false

var _visual_root: Node3D = null
var _static_body: StaticBody3D = null
var _door_blocker_col: CollisionShape3D = null
var _interaction_comp: InteractionComponent = null
var _interaction_col: CollisionShape3D = null
var _proximity_area: Area3D = null
var _dust_particles: GPUParticles3D = null

# Données par racine/liane animée : { "node": MeshInstance3D, "mat": ShaderMaterial, "open_rot": Vector3, "target_debut": float, "delay": float }
var _vine_entries: Array[Dictionary] = []
var _local_player_near: CharacterBody3D = null
var _active_tween: Tween = null


func _ready() -> void:
	_rebuild_gate()
	if not Engine.is_editor_hint():
		_setup_runtime_interaction()
		if preview_open_in_editor:
			preview_open_in_editor = false
			_apply_instant_state(false)
	else:
		_apply_instant_state(preview_open_in_editor)


func _rebuild_gate() -> void:
	if Engine.is_editor_hint():
		MoriaGateMeshes.clear_caches()

	if _visual_root != null and is_instance_valid(_visual_root):
		remove_child(_visual_root)
		_visual_root.queue_free()
	_vine_entries.clear()

	_visual_root = Node3D.new()
	_visual_root.name = "GateVisuals"
	add_child(_visual_root)

	_build_stone_architecture()
	_build_vine_barrier()
	_build_dust_particles()
	_ensure_physics_colliders()


# =========================================================================
# CONSTRUCTION DE L'ARMATURE EN PIERRE DE LA MORIA
# =========================================================================
func _build_stone_architecture() -> void:
	var stone_holder := Node3D.new()
	stone_holder.name = "MoriaStoneArmature"
	_visual_root.add_child(stone_holder)

	var pillar_cx := DOOR_HALF_WIDTH + PILLAR_WIDTH * 0.5 # 6.68m

	# 1. Socles à degrés (ancrés à -0.40m sous le niveau 0 pour épouser tout relief léger)
	var base_tier_mesh := MoriaGateMeshes.build_chamfered_stone_block(Vector3(4.24, 0.92, 3.24), 0.16, 0.16, 0.26, false)
	var upper_tier_mesh := MoriaGateMeshes.build_chamfered_stone_block(Vector3(3.80, 0.72, 2.82), 0.14, 0.14, 0.26, false)
	var capital_mesh := MoriaGateMeshes.build_chamfered_stone_block(Vector3(3.86, 0.48, 2.78), 0.08, 0.10, 0.28, true)

	for side in [-1.0, 1.0]:
		var sx: float = side * pillar_cx
		var side_tag := "Left" if side < 0.0 else "Right"

		var b_inst := MeshInstance3D.new()
		b_inst.name = side_tag + "PlinthLower"
		b_inst.mesh = base_tier_mesh
		b_inst.position = Vector3(sx, -0.40, 0.0)
		stone_holder.add_child(b_inst)

		var u_inst := MeshInstance3D.new()
		u_inst.name = side_tag + "PlinthUpper"
		u_inst.mesh = upper_tier_mesh
		u_inst.position = Vector3(sx, 0.50, 0.0)
		stone_holder.add_child(u_inst)

		# Fût de pilier sculpté (Arbre de la Moria & entrelacs nains)
		var p_inst := MeshInstance3D.new()
		p_inst.name = side_tag + "CarvedPillar"
		p_inst.mesh = MoriaGateMeshes.build_carved_pillar_shaft(PILLAR_WIDTH, PILLAR_HEIGHT, PILLAR_DEPTH, side > 0.0)
		p_inst.position = Vector3(sx, PLINTH_TOP_Y, 0.0)
		stone_holder.add_child(p_inst)

		# Chapiteau mouluré sous la retombée de l'arche
		var cap_inst := MeshInstance3D.new()
		cap_inst.name = side_tag + "Capital"
		cap_inst.mesh = capital_mesh
		cap_inst.position = Vector3(sx, PLINTH_TOP_Y + PILLAR_HEIGHT - 0.02, 0.0)
		stone_holder.add_child(cap_inst)

	# 2. Dalles de seuil usées affleurantes (seulement +2 cm au-dessus du sol : aucune gêne de marche)
	var slab_positions := [-3.25, 0.0, 3.25]
	var slab_mesh := MoriaGateMeshes.build_chamfered_stone_block(Vector3(3.38, 0.36, 2.65), 0.10, 0.05, 0.28, false)
	for i in range(slab_positions.size()):
		var sl := MeshInstance3D.new()
		sl.name = "ThresholdSlab_%d" % i
		sl.mesh = slab_mesh
		sl.position = Vector3(slab_positions[i], -0.34, 0.0)
		sl.rotation.y = (-0.018 if i == 0 else (0.015 if i == 2 else 0.0))
		stone_holder.add_child(sl)

	# 3. Grande Arche Creuse Sculptée de la Moria (Couronne de Durin, 7 étoiles, runes elfiques & arbres)
	var arch_inst := MeshInstance3D.new()
	arch_inst.name = "MoriaHollowArch"
	arch_inst.mesh = MoriaGateMeshes.build_hollow_moria_arch_spandrel(
		DOOR_HALF_WIDTH * 2.0 + PILLAR_WIDTH * 2.0, # 16.76m
		ARCH_HEIGHT,
		2.44,
		DOOR_HALF_WIDTH,
		ARCH_CROWN_H,
		52
	)
	arch_inst.position = Vector3(0.0, ARCH_BASE_Y, 0.0)
	stone_holder.add_child(arch_inst)

	# 4. Corniche supérieure à ressauts & couronnement de clé de voûte
	var cornice_low := MeshInstance3D.new()
	cornice_low.name = "CorniceLower"
	cornice_low.mesh = MoriaGateMeshes.build_chamfered_stone_block(Vector3(17.50, 0.44, 2.88), 0.08, 0.10, 0.26, true)
	cornice_low.position = Vector3(0.0, ARCH_BASE_Y + ARCH_HEIGHT - 0.03, 0.0)
	stone_holder.add_child(cornice_low)

	var cornice_top := MeshInstance3D.new()
	cornice_top.name = "CorniceUpper"
	cornice_top.mesh = MoriaGateMeshes.build_chamfered_stone_block(Vector3(18.10, 0.42, 3.16), 0.18, 0.16, 0.26, true)
	cornice_top.position = Vector3(0.0, ARCH_BASE_Y + ARCH_HEIGHT + 0.39, 0.0)
	stone_holder.add_child(cornice_top)

	var crown_cap := MeshInstance3D.new()
	crown_cap.name = "KeystoneCrownCap"
	crown_cap.mesh = MoriaGateMeshes.build_chamfered_stone_block(Vector3(2.95, 0.52, 3.30), 0.22, 0.20, 0.28, true)
	crown_cap.position = Vector3(0.0, ARCH_BASE_Y + ARCH_HEIGHT + 0.76, 0.0)
	stone_holder.add_child(crown_cap)

	# 5. Remparts anciens en ruine de chaque côté pour sceller jusqu'aux arbres géants
	_build_ruin_wing(stone_holder, -1.0, left_wing_span)
	_build_ruin_wing(stone_holder, 1.0, right_wing_span)


func _build_ruin_wing(parent: Node3D, dir_sign: float, total_span: float) -> void:
	if total_span <= 0.5:
		return
	var start_x: float = dir_sign * (DOOR_HALF_WIDTH + PILLAR_WIDTH) # ±8.38m
	var seg_len := 4.35
	var count := maxi(1, ceili(total_span / seg_len))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7319 if dir_sign < 0.0 else 9157
	var root_mat := MoriaGateMeshes.create_vine_root_material(false, Color(0.55, 0.49, 0.37, 1.0), 0.30, 8.5)
	var tag := "Left" if dir_sign < 0.0 else "Right"

	for i in range(count):
		var frac := float(i) / float(maxi(1, count - 1))
		# Silhouette de ruine organique irrégulière (pics brisés, brèches anciennes, stèles penchées)
		var base_h := lerpf(9.6, 5.8, pow(frac, 0.82))
		var h_variation := (1.15 if i % 3 == 1 else (-0.85 if i % 3 == 2 else 0.35)) + rng.randf_range(-0.35, 0.35)
		var h := maxf(4.8, base_h + h_variation)
		var d := lerpf(2.25, 1.85, frac) + rng.randf_range(-0.15, 0.22)
		var w := seg_len + 0.65
		var cx := start_x + dir_sign * (float(i) * seg_len + seg_len * 0.44)
		var cz := sin(float(i) * 1.15) * 0.38 + rng.randf_range(-0.16, 0.16)

		# Soubassement lourd en degrés
		var plinth_blk := MeshInstance3D.new()
		plinth_blk.name = "%sRuinPlinth_%d" % [tag, i]
		plinth_blk.mesh = MoriaGateMeshes.build_chamfered_stone_block(Vector3(w + 0.35, 1.35, d + 0.65), 0.18, 0.18, 0.25, false)
		plinth_blk.position = Vector3(cx, -0.50, cz)
		plinth_blk.rotation.y = rng.randf_range(-0.05, 0.05)
		parent.add_child(plinth_blk)

		# Pan de mur principal fissuré/incliné
		var wall_blk := MeshInstance3D.new()
		wall_blk.name = "%sRuinSegment_%d" % [tag, i]
		wall_blk.mesh = MoriaGateMeshes.build_chamfered_stone_block(Vector3(w, h, d), 0.24, 0.34, 0.25, false)
		wall_blk.position = Vector3(cx, -0.45, cz)
		wall_blk.rotation.y = rng.randf_range(-0.09, 0.09)
		wall_blk.rotation.z = dir_sign * rng.randf_range(-0.045, 0.035)
		parent.add_child(wall_blk)

		# Créneau brisé / monolithe dressé au sommet pour casser toute ligne d'escalier artificielle
		var merlon_w := rng.randf_range(1.45, 2.35)
		var merlon_h := rng.randf_range(1.1, 2.4)
		var merlon := MeshInstance3D.new()
		merlon.name = "%sRuinMerlon_%d" % [tag, i]
		merlon.mesh = MoriaGateMeshes.build_chamfered_stone_block(Vector3(merlon_w, merlon_h, d * 0.86), 0.26, 0.32, 0.27, true)
		merlon.position = Vector3(cx + rng.randf_range(-0.85, 0.85), h - 0.85, cz)
		merlon.rotation = Vector3(rng.randf_range(-0.06, 0.06), rng.randf_range(-0.14, 0.14), rng.randf_range(-0.09, 0.09))
		parent.add_child(merlon)

		# Blocs éboulés au pied du rempart + grosses racines sylvestres enjambant la ruine
		if i % 2 == 0:
			var rubble := MeshInstance3D.new()
			rubble.name = "%sRuinRubble_%d" % [tag, i]
			rubble.mesh = MoriaGateMeshes.build_chamfered_stone_block(
				Vector3(rng.randf_range(1.6, 2.4), rng.randf_range(1.1, 1.9), rng.randf_range(1.4, 2.1)),
				0.28, 0.35, 0.28, false
			)
			rubble.position = Vector3(cx - dir_sign * 0.55, -0.45, cz + 1.15)
			rubble.rotation = Vector3(rng.randf_range(-0.18, 0.18), rng.randf_range(-0.45, 0.45), rng.randf_range(-0.22, 0.22))
			parent.add_child(rubble)

			var front_z := cz + d * 0.5 + 0.16
			var r_pts := PackedVector3Array()
			for s in range(14):
				var rt := float(s) / 13.0
				var rx := cx + sin(rt * PI * 1.4 + float(i)) * 0.75 * dir_sign
				var ry := (h + 0.18 - rt * (h + 0.42)) + sin(rt * PI) * 0.35
				var rz := lerpf(cz - 0.25, front_z, clampf(rt * 4.2, 0.0, 1.0)) + sin(rt * PI) * 0.18
				r_pts.append(Vector3(rx, ry, rz))
			var w_root := MeshInstance3D.new()
			w_root.name = "%sRuinRoot_%d" % [tag, i]
			w_root.mesh = MoriaGateMeshes.build_anchored_root_tube(r_pts, 0.30, 0.32, 7, 0.03, 900 + i + (0 if dir_sign < 0.0 else 50))
			w_root.position = r_pts[0]
			w_root.material_override = root_mat
			parent.add_child(w_root)


# =========================================================================
# CONSTRUCTION DES LIANES & RACINES REBOUCHANT L'ENTRÉE
# =========================================================================
func _build_vine_barrier() -> void:
	var vines_holder := Node3D.new()
	vines_holder.name = "LivingVinesBarrier"
	_visual_root.add_child(vines_holder)

	var rng := RandomNumberGenerator.new()
	rng.seed = 40921

	# --- Couche 1 : 18 grosses racines transversales entrelacées du sol jusqu'au cintre (9 gauche, 9 droite) ---
	var side_heights := [0.60, 1.65, 2.75, 3.90, 5.15, 6.45, 7.80, 9.25, 10.65]
	for idx in range(side_heights.size()):
		for side_i in range(2):
			var dir_s: float = -1.0 if side_i == 0 else 1.0 # -1 = ancré à gauche, +1 = ancré à droite
			var base_y: float = side_heights[idx] + (0.24 if side_i == 1 else -0.16)
			var base_z: float = (-0.28 if (idx + side_i) % 2 == 0 else 0.28) + rng.randf_range(-0.08, 0.08)
			# Socle enfoui à 1.45m au cœur du pilier en pierre (3.4m de large) => la racine sort pleine épaisseur de la roche sans aucun jour
			var max_x_at_y := DOOR_HALF_WIDTH + 1.45
			if base_y > ARCH_BASE_Y:
				var dy_norm := clampf((base_y - ARCH_BASE_Y) / ARCH_CROWN_H, 0.0, 0.96)
				max_x_at_y = DOOR_HALF_WIDTH * sqrt(maxf(0.04, 1.0 - dy_norm * dy_norm)) + 1.35
			var anchor := Vector3(dir_s * max_x_at_y, base_y, base_z)

			# Chaque racine traverse largement le milieu pour tresser une vraie barrière dense
			var span_scale := max_x_at_y / (DOOR_HALF_WIDTH + 1.45)
			var reach := rng.randf_range(8.35, 9.65) * lerpf(0.72, 1.0, span_scale)
			var end_y := clampf(base_y + rng.randf_range(-1.95, 1.45), 0.25, 12.1)
			var wave_y := rng.randf_range(0.38, 0.78) * (1.0 if idx % 2 == 0 else -1.0)
			var wave_z := rng.randf_range(0.24, 0.44) * (-1.0 if side_i == 0 else 1.0)

			var pts := PackedVector3Array()
			var steps := 26
			for s in range(steps):
				var t := float(s) / float(steps - 1)
				var x := anchor.x - dir_s * (reach * t)
				var y := lerpf(anchor.y, end_y, t) + sin(t * PI * 1.65) * wave_y * smoothstep(0.0, 0.22, t)
				var z := anchor.z + sin(t * PI * 2.0) * wave_z * sin(t * PI)
				pts.append(Vector3(x, y, z))

			var rad := lerpf(0.36, 0.22, float(idx) / 8.0)
			var warm_variant := ((idx + side_i) % 2 == 0)
			var tint := Color(0.68, 0.60, 0.46, 1.0) if warm_variant else Color(0.52, 0.47, 0.35, 1.0)

			# Léger mouvement d'écartement pendant que le shader rétracte intégralement la racine dans la pierre (debut: 1.0 -> 0.0)
			var yaw_sign := -dir_s * (1.0 if base_z >= 0.0 else -1.0)
			var open_rot := Vector3(
				rng.randf_range(-0.04, 0.04),
				yaw_sign * rng.randf_range(0.14, 0.24),
				-dir_s * rng.randf_range(0.08, 0.16)
			)
			var delay := clampf((1.0 - absf(base_y - 3.8) / 6.0) * 0.18 + rng.randf_range(0.0, 0.08), 0.0, 0.28)
			_spawn_animated_vine(
				vines_holder,
				pts,
				rad,
				0.22,
				false,
				tint,
				open_rot,
				0.0,
				delay,
				100 + idx * 2 + side_i
			)

	# --- Couche 2 : 12 lianes pendantes sous la voûte cintrée de l'arche (6 gauche, 6 droite) ---
	var arch_angles_left := [2.82, 2.58, 2.34, 2.08, 1.84, 1.63]
	var arch_angles_right := [0.32, 0.56, 0.80, 1.06, 1.30, 1.51]
	for group_i in range(2):
		var dir_s := -1.0 if group_i == 0 else 1.0
		var ang_list: Array = arch_angles_left if group_i == 0 else arch_angles_right
		for k in range(ang_list.size()):
			var theta: float = ang_list[k]
			var ax := cos(theta) * (DOOR_HALF_WIDTH + 0.42)
			var ay := ARCH_BASE_Y + sin(theta) * (ARCH_CROWN_H + 0.52)
			var az := rng.randf_range(-0.34, 0.34)
			var anchor := Vector3(ax, ay, az)

			# Les lianes tombent en rideau souple et croisent légèrement le centre
			var drop_len := lerpf(7.2, 11.8, sin(theta)) * rng.randf_range(0.88, 1.05)
			var drift_x := -dir_s * rng.randf_range(1.2, 2.8)
			var pts := PackedVector3Array()
			var steps := 18
			for s in range(steps):
				var t := float(s) / float(steps - 1)
				var x := anchor.x + drift_x * pow(t, 0.85) + sin(t * PI * 2.2 + float(k)) * 0.38
				var y := maxf(0.15, anchor.y - drop_len * t)
				var z := anchor.z + cos(t * PI * 1.8 + float(k)) * 0.26 * sin(t * PI)
				pts.append(Vector3(x, y, z))

			var rad := rng.randf_range(0.15, 0.23)
			var open_rot := Vector3(
				rng.randf_range(-0.08, 0.08),
				rng.randf_range(-0.18, 0.18),
				dir_s * rng.randf_range(0.24, 0.40)
			)
			var delay := rng.randf_range(0.04, 0.26)
			_spawn_animated_vine(
				vines_holder,
				pts,
				rad,
				0.18,
				false,
				Color(0.64, 0.57, 0.43, 1.0) if k % 2 == 0 else Color(0.49, 0.46, 0.34, 1.0),
				open_rot,
				0.0,
				delay,
				300 + group_i * 10 + k
			)

	# --- Couche 3 : 6 souches basses surgissant du seuil de pierre vers le centre ---
	for b_idx in range(6):
		var dir_s := -1.0 if b_idx < 3 else 1.0
		var local_i := b_idx % 3
		var ax := dir_s * lerpf(4.65, 3.15, float(local_i) / 2.0)
		var az := (-0.32 if local_i % 2 == 0 else 0.32)
		var anchor := Vector3(ax, -0.45, az)
		var pts := PackedVector3Array()
		var steps := 14
		for s in range(steps):
			var t := float(s) / float(steps - 1)
			var x := anchor.x - dir_s * (lerpf(3.9, 5.3, float(local_i) / 2.0) * t)
			var y := -0.45 + sin(t * PI * 0.88) * rng.randf_range(1.95, 3.15)
			var z := anchor.z + sin(t * PI * 1.5) * 0.25 * dir_s
			pts.append(Vector3(x, y, z))

		var open_rot := Vector3(0.0, -dir_s * 0.24, dir_s * 0.18)
		_spawn_animated_vine(
			vines_holder,
			pts,
			rng.randf_range(0.22, 0.31),
			0.24,
			false,
			Color(0.54, 0.48, 0.36, 1.0),
			open_rot,
			0.0,
			rng.randf_range(0.02, 0.18),
			500 + b_idx
		)

	# --- Couche 4 : Racines d'encadrement permanentes courant à la jonction pilier / rempart ---
	var perm_mat := MoriaGateMeshes.create_vine_root_material(false, Color(0.52, 0.47, 0.35, 1.0), 0.26, 10.2)
	for side_s in [-1.0, 1.0]:
		var side_f: float = float(side_s)
		var pts := PackedVector3Array()
		for s in range(20):
			var t := float(s) / 19.0
			var x: float = side_f * (8.55 + 0.25 * sin(t * PI * 1.6))
			var y: float = -0.45 + t * 9.8
			var z: float = 0.85 * sin(t * PI * 0.9)
			pts.append(Vector3(x, y, z))
		var pm := MeshInstance3D.new()
		pm.name = ("Left" if side_f < 0.0 else "Right") + "PillarCreeper"
		pm.mesh = MoriaGateMeshes.build_anchored_root_tube(pts, 0.26, 0.25, 10, 0.016, 700 + int(side_f + 2.0))
		pm.position = pts[0]
		pm.material_override = perm_mat
		vines_holder.add_child(pm)


func _spawn_animated_vine(
	parent: Node3D,
	world_pts: PackedVector3Array,
	radius: float,
	tip_ratio: float,
	alt_bark: bool,
	tint: Color,
	open_rot: Vector3,
	target_debut: float,
	delay: float,
	seed_val: int
) -> void:
	var curve_len := 0.0
	for i in range(1, world_pts.size()):
		curve_len += world_pts[i - 1].distance_to(world_pts[i])
	var inst := MeshInstance3D.new()
	inst.name = "GateVine_%d" % seed_val
	inst.mesh = MoriaGateMeshes.build_anchored_root_tube(world_pts, radius, tip_ratio, 10, 0.018, seed_val)
	inst.position = world_pts[0]
	var mat := MoriaGateMeshes.create_vine_root_material(alt_bark, tint, radius, maxf(1.5, curve_len))
	inst.material_override = mat
	parent.add_child(inst)

	_vine_entries.append({
		"node": inst,
		"mat": mat,
		"open_rot": open_rot,
		"target_debut": target_debut,
		"delay": delay
	})


# =========================================================================
# PARTICULES DE POUSSIÈRE DE PIERRE & D'ÉCORCE À L'OUVERTURE
# =========================================================================
func _build_dust_particles() -> void:
	_dust_particles = GPUParticles3D.new()
	_dust_particles.name = "OpeningDustParticles"
	_dust_particles.position = Vector3(0.0, 6.8, 0.0)
	_dust_particles.emitting = false
	_dust_particles.one_shot = true
	_dust_particles.amount = 48
	_dust_particles.lifetime = 2.1
	_dust_particles.explosiveness = 0.35

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(4.6, 4.8, 0.8)
	pmat.direction = Vector3(0.0, -1.0, 0.0)
	pmat.spread = 32.0
	pmat.initial_velocity_min = 0.5
	pmat.initial_velocity_max = 2.1
	pmat.gravity = Vector3(0.0, -3.6, 0.0)
	pmat.damping_min = 0.6
	pmat.damping_max = 1.4
	pmat.scale_min = 0.65
	pmat.scale_max = 1.45

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	grad.colors = PackedColorArray([
		Color(0.36, 0.34, 0.28, 0.0),
		Color(0.42, 0.39, 0.32, 0.55),
		Color(0.30, 0.28, 0.24, 0.0)
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	pmat.color_ramp = ramp
	_dust_particles.process_material = pmat

	var qm := QuadMesh.new()
	qm.size = Vector2(0.16, 0.16)
	var dmat := StandardMaterial3D.new()
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.vertex_color_use_as_albedo = true
	dmat.albedo_color = Color(0.52, 0.48, 0.38, 0.65)
	dmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	dmat.roughness = 0.95
	qm.material = dmat
	_dust_particles.draw_pass_1 = qm

	_visual_root.add_child(_dust_particles)


# =========================================================================
# COLLISIONS PHYSIQUES & INTERACTION JOUEUR (LOOT_CAST + PROXIMITÉ)
# =========================================================================
func _ensure_physics_colliders() -> void:
	_static_body = get_node_or_null("GateStaticBody") as StaticBody3D
	if _static_body != null and is_instance_valid(_static_body):
		remove_child(_static_body)
		_static_body.queue_free()

	_static_body = StaticBody3D.new()
	_static_body.name = "GateStaticBody"
	_static_body.collision_layer = 1
	_static_body.collision_mask = 0
	add_child(_static_body)

	# 1. Pilier gauche + rempart gauche (toujours solide)
	var left_total_w := PILLAR_WIDTH + maxf(left_wing_span, 1.0) + 1.0
	var left_col := CollisionShape3D.new()
	left_col.name = "LeftPillarWingCollider"
	var left_box := BoxShape3D.new()
	left_box.size = Vector3(left_total_w, 17.5, 3.0)
	left_col.shape = left_box
	left_col.position = Vector3(-(DOOR_HALF_WIDTH + left_total_w * 0.5), 7.8, 0.0)
	_static_body.add_child(left_col)

	# 2. Pilier droit + rempart droit (toujours solide)
	var right_total_w := PILLAR_WIDTH + maxf(right_wing_span, 1.0) + 1.0
	var right_col := CollisionShape3D.new()
	right_col.name = "RightPillarWingCollider"
	var right_box := BoxShape3D.new()
	right_box.size = Vector3(right_total_w, 17.5, 3.0)
	right_col.shape = right_box
	right_col.position = Vector3(DOOR_HALF_WIDTH + right_total_w * 0.5, 7.8, 0.0)
	_static_body.add_child(right_col)

	# 3. Linteau / arche haute (toujours solide au-dessus de Y = 11.8m)
	var lintel_col := CollisionShape3D.new()
	lintel_col.name = "ArchUpperCollider"
	var lintel_box := BoxShape3D.new()
	lintel_box.size = Vector3(DOOR_HALF_WIDTH * 2.0, 6.0, 2.8)
	lintel_col.shape = lintel_box
	lintel_col.position = Vector3(0.0, 14.8, 0.0)
	_static_body.add_child(lintel_col)

	# 4. Barrière centrale des lianes (solide quand fermée, désactivée dès que les racines s'écartent !)
	_door_blocker_col = CollisionShape3D.new()
	_door_blocker_col.name = "DoorwayVinesBlocker"
	var door_box := BoxShape3D.new()
	door_box.size = Vector3(DOOR_HALF_WIDTH * 2.0 + 0.3, 12.2, 1.35)
	_door_blocker_col.shape = door_box
	_door_blocker_col.position = Vector3(0.0, 5.8, 0.0)
	_door_blocker_col.disabled = is_open
	_static_body.add_child(_door_blocker_col)


func _setup_runtime_interaction() -> void:
	_interaction_comp = get_node_or_null("InteractionComponent") as InteractionComponent
	if _interaction_comp == null:
		var ic_scene := load("res://components/interaction_component.tscn") as PackedScene
		if ic_scene != null:
			_interaction_comp = ic_scene.instantiate() as InteractionComponent
			_interaction_comp.name = "InteractionComponent"
			add_child(_interaction_comp)

	if _interaction_comp != null:
		_interaction_comp.prompt_text = prompt_text
		# Positionné légèrement côté route (+Z) pour que le Label3D flotte bien devant les lianes à hauteur des yeux
		_interaction_comp.position = Vector3(0.0, 0.85, 1.15)
		_interaction_col = _interaction_comp.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if _interaction_col != null:
			var ibox := BoxShape3D.new()
			# Déborde largement devant DoorwayVinesBlocker pour que loot_cast (RayCast3D) touche toujours InteractionComponent en premier
			ibox.size = Vector3(DOOR_HALF_WIDTH * 2.0, 7.6, 4.4)
			_interaction_col.shape = ibox
			_interaction_col.position = Vector3(0.0, 2.8, -0.85)

		var lbl := _interaction_comp.get_node_or_null("Label3D") as Label3D
		if lbl != null:
			lbl.text = prompt_text
			lbl.pixel_size = 0.0075
			lbl.font_size = 48
			lbl.outline_size = 12
			lbl.modulate = Color(0.90, 0.89, 0.83, 0.96)
			lbl.outline_modulate = Color(0.06, 0.07, 0.06, 0.96)
			lbl.no_depth_test = true
			if ResourceLoader.exists(FONT_CINZEL_PATH):
				lbl.font = load(FONT_CINZEL_PATH) as Font

	# Zone de proximité complémentaire devant l'arche : permet d'interagir avec [E] dès qu'on s'approche
	# des racines même si la caméra regarde la couronne de la Moria en hauteur ou vers le bas
	_proximity_area = get_node_or_null("ApproachProximityArea") as Area3D
	if _proximity_area == null:
		_proximity_area = Area3D.new()
		_proximity_area.name = "ApproachProximityArea"
		_proximity_area.collision_layer = 0
		_proximity_area.collision_mask = 2 # Joueurs
		var pcol := CollisionShape3D.new()
		var pbox := BoxShape3D.new()
		pbox.size = Vector3(DOOR_HALF_WIDTH * 2.0, 4.8, 6.2)
		pcol.shape = pbox
		pcol.position = Vector3(0.0, 2.2, 2.2)
		_proximity_area.add_child(pcol)
		add_child(_proximity_area)

	if not _proximity_area.body_entered.is_connected(_on_proximity_body_entered):
		_proximity_area.body_entered.connect(_on_proximity_body_entered)
	if not _proximity_area.body_exited.is_connected(_on_proximity_body_exited):
		_proximity_area.body_exited.connect(_on_proximity_body_exited)


func _on_proximity_body_entered(body: Node3D) -> void:
	if is_open:
		return
	if body is CharacterBody3D and body.is_in_group("Player") and body.is_multiplayer_authority():
		_local_player_near = body as CharacterBody3D
		if _interaction_comp != null:
			_interaction_comp.show_prompt()


func _on_proximity_body_exited(body: Node3D) -> void:
	if body == _local_player_near:
		_local_player_near = null
		if _interaction_comp != null:
			_interaction_comp.hide_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or is_open:
		return
	if _local_player_near == null or not is_instance_valid(_local_player_near):
		return
	if _local_player_near.get("is_dead") == true:
		return
	var key_target: Key = _interaction_comp.interaction_key if _interaction_comp != null else KEY_E
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == key_target:
		interact(_local_player_near)
		get_viewport().set_input_as_handled()


# =========================================================================
# OUVERTURE & SYNCHRONISATION MULTIJOUEUR
# =========================================================================
func use(player: Node3D) -> void:
	interact(player)


func interact(player: Node3D = null) -> void:
	if is_open:
		return
	if multiplayer.has_multiplayer_peer():
		var pid: int = player.get_multiplayer_authority() if (player != null and is_instance_valid(player)) else multiplayer.get_unique_id()
		_request_open_gate.rpc_id(1, pid)
	else:
		_open_gate_internal(player)


@rpc("any_peer", "call_local", "reliable")
func _request_open_gate(requester_peer_id: int = 1) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if is_open:
		return
	_sync_open_gate.rpc(requester_peer_id)


@rpc("authority", "call_local", "reliable")
func _sync_open_gate(requester_peer_id: int = 1) -> void:
	var opener: Node3D = _find_player_by_peer(requester_peer_id)
	_open_gate_internal(opener)


func _find_player_by_peer(peer_id: int) -> Node3D:
	if not is_inside_tree() or get_tree() == null:
		return null
	for p in get_tree().get_nodes_in_group("Player"):
		if p is Node3D and p.get_multiplayer_authority() == peer_id:
			return p as Node3D
	return null


func _open_gate_internal(opening_player: Node3D = null) -> void:
	if is_open:
		return
	is_open = true
	_local_player_near = null

	# Désactiver immédiatement l'invite d'interaction pour que le RayCast ne la capte plus
	if _interaction_comp != null:
		_interaction_comp.hide_prompt()
		_interaction_comp.set_deferred("monitoring", false)
		_interaction_comp.set_deferred("monitorable", false)
	if _interaction_col != null:
		_interaction_col.set_deferred("disabled", true)
	if _proximity_area != null:
		_proximity_area.set_deferred("monitoring", false)

	_play_open_animation()
	_play_open_sfx()
	gate_opened.emit(opening_player)


func _play_open_animation() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	if _dust_particles != null and is_instance_valid(_dust_particles):
		_dust_particles.restart()
		_dust_particles.emitting = true

	var dur := maxf(0.4, open_duration)
	_active_tween = create_tween()
	_active_tween.set_parallel(true)

	for entry in _vine_entries:
		var v_node: MeshInstance3D = entry["node"]
		var v_mat: ShaderMaterial = entry["mat"]
		var target_rot: Vector3 = entry["open_rot"]
		var target_debut: float = entry["target_debut"]
		var delay: float = entry["delay"]

		if v_node != null and is_instance_valid(v_node):
			v_node.visible = true
			_active_tween.tween_property(v_node, "rotation", target_rot, dur).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			if target_debut <= 0.01:
				_active_tween.tween_callback(func() -> void:
					if v_node != null and is_instance_valid(v_node):
						v_node.visible = false
				).set_delay(delay + dur)
		if v_mat != null:
			_active_tween.tween_property(v_mat, "shader_parameter/debut", target_debut, dur * 0.96).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Libère la collision centrale dès que le cœur de l'arche s'entrouvre (~42% de l'animation)
	if _door_blocker_col != null and is_instance_valid(_door_blocker_col):
		_active_tween.tween_callback(func() -> void:
			if _door_blocker_col != null and is_instance_valid(_door_blocker_col):
				_door_blocker_col.set_deferred("disabled", true)
		).set_delay(dur * 0.42)


func _apply_instant_state(opened: bool) -> void:
	is_open = opened
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	for entry in _vine_entries:
		var v_node: MeshInstance3D = entry["node"]
		var v_mat: ShaderMaterial = entry["mat"]
		var t_debut: float = float(entry["target_debut"]) if opened else 1.0
		if v_node != null and is_instance_valid(v_node):
			v_node.rotation = entry["open_rot"] if opened else Vector3.ZERO
			v_node.visible = (t_debut > 0.01)
		if v_mat != null:
			v_mat.set_shader_parameter("debut", t_debut)
	if _door_blocker_col != null and is_instance_valid(_door_blocker_col):
		_door_blocker_col.disabled = opened


func _apply_editor_debut_preview(d_val: float) -> void:
	for entry in _vine_entries:
		var v_node: MeshInstance3D = entry["node"]
		var v_mat: ShaderMaterial = entry["mat"]
		if v_node != null and is_instance_valid(v_node):
			v_node.visible = (d_val > 0.005)
			v_node.rotation = entry["open_rot"] * (1.0 - d_val)
		if v_mat != null:
			v_mat.set_shader_parameter("debut", d_val)


# =========================================================================
# EFFETS SONORES DOUX ET ORGANIQUES (VOLUME CONFORTABLE <= -12 dB)
# =========================================================================
func _play_open_sfx() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	# Craquement grave de vieilles racines qui se délient
	_spawn_3d_one_shot_sfx(SFX_CREAK_PATH, -12.5, 0.44, 0.0)
	_spawn_3d_one_shot_sfx(SFX_CRUNCH_PATH, -14.0, 0.52, 0.22)
	# Froissement sourd des lianes glissant contre la pierre
	_spawn_3d_one_shot_sfx(SFX_SLIDE_PATH, -13.5, 0.50, 0.14)


func _spawn_3d_one_shot_sfx(path: String, vol_db: float, pitch: float, delay: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = vol_db
	p.max_db = -10.0
	p.pitch_scale = pitch
	p.unit_size = 6.0
	p.max_distance = 24.0
	p.position = Vector3(0.0, 3.5, 0.0)
	add_child(p)
	if delay > 0.001:
		var tw := create_tween()
		tw.tween_callback(p.play).set_delay(delay)
	else:
		p.play()
	p.finished.connect(p.queue_free)
