@tool
class_name RootLauncher
extends Node3D

## Racine-Catapulte inspirée des propulseurs aériens de Deadlock.
## - S'active avec [E] dès qu'on court dans sa zone (sans devoir baisser la caméra vers ses pieds)
## - Propulse selon un arc équilibré (~15.5m de haut + ~14.5 m/s dans la direction visée)
## - Retour fluide à la vitesse normale dès l'atterrissage (géré par player.apply_air_launch)
## - Animation de fouet des racines via root_shader.tres + souffle d'air ascendant

@export_category("Trajectoire Aérienne (Style Deadlock)")
## Hauteur maximale atteinte au sommet de l'arc (en mètres)
@export var launch_height: float = 15.5
## Vitesse horizontale imprimée dans la direction de la caméra (en m/s)
@export var horizontal_launch_speed: float = 14.5
## Temps de réarmement de la racine après utilisation (en secondes)
@export var cooldown_duration: float = 5.0
## Rayon de détection permettant d'appuyer sur [E] en courant sans viser le sol
@export var trigger_radius: float = 2.65

@export_category("Visuel & Optimisation")
@export var prompt_text: String = "[E] Propulser"
@export var visibility_max_distance: float = 160.0

const SFX_WOOSH_PATH := "res://assets/sound_effects/UI/wav (HD)/woosh_5.wav"
const SFX_SWOOSH_PATH := "res://assets/sound_effects/UI/wav (HD)/Swoosh_3.wav"
const SFX_TWANG_PATH := "res://assets/sound_effects/Combat and Gore/bone_snap.wav"
const FONT_CINZEL_PATH := "res://assets/fonts/Cinzel.ttf"

static var _shared_arch_mat: ShaderMaterial = null

var _visual_root: Node3D = null
var _arches_holder: Node3D = null
var _whip_materials: Array[ShaderMaterial] = []
var _center_glow_mat: StandardMaterial3D = null
var _updraft_particles: GPUParticles3D = null
var _proximity_area: Area3D = null
var _prompt_label: Label3D = null

var _local_player_inside: CharacterBody3D = null
var _cooldown_timer: float = 0.0

func _ready() -> void:
	_rebuild_visuals()
	if not Engine.is_editor_hint():
		_setup_interaction_zones()

func _rebuild_visuals() -> void:
	if Engine.is_editor_hint():
		ProceduralForestMeshes.clear_caches()
		_shared_arch_mat = null
	if _visual_root != null and is_instance_valid(_visual_root):
		_visual_root.queue_free()
		remove_child(_visual_root)
	_whip_materials.clear()

	_visual_root = Node3D.new()
	_visual_root.name = "LauncherVisual"
	add_child(_visual_root)

	var no_limit := Engine.is_editor_hint()
	var vis_end := 0.0 if no_limit else visibility_max_distance

	if _shared_arch_mat == null:
		_shared_arch_mat = ProceduralForestMeshes.get_base_root_material(Color(0.65, 0.58, 0.36, 1.0), 0.115, 1.7)

	# 1. Petit cœur de sève sylvestre discret niché SOUS la spirale de racines (pas de disque fluo plat)
	var center_bud := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.36
	sph.height = 0.22
	sph.radial_segments = 14
	sph.rings = 6
	_center_glow_mat = StandardMaterial3D.new()
	_center_glow_mat.albedo_color = Color(0.08, 0.18, 0.10, 1.0)
	_center_glow_mat.roughness = 0.65
	_center_glow_mat.emission_enabled = true
	_center_glow_mat.emission = Color(0.28, 0.78, 0.44, 1.0)
	_center_glow_mat.emission_energy_multiplier = 0.95
	sph.material = _center_glow_mat
	center_bud.mesh = sph
	center_bud.position = Vector3(0.0, 0.06, 0.0)
	center_bud.visibility_range_end = vis_end
	center_bud.visibility_range_end_margin = 20.0 if vis_end > 0.0 else 0.0
	_visual_root.add_child(center_bud)

	# 2. Arches et spirales de racines comprimées sous tension
	_arches_holder = Node3D.new()
	_arches_holder.name = "CoiledArches"
	_visual_root.add_child(_arches_holder)

	var coils := ProceduralForestMeshes.get_launcher_coils()
	for i in range(coils.size()):
		var c_data: Dictionary = coils[i]
		var c_mi := MeshInstance3D.new()
		c_mi.name = "SpringCoil_" + str(i)
		c_mi.mesh = c_data["mesh"]
		c_mi.position = c_data["center"]
		c_mi.material_override = _shared_arch_mat
		c_mi.visibility_range_end = vis_end
		c_mi.visibility_range_end_margin = 20.0 if vis_end > 0.0 else 0.0
		_arches_holder.add_child(c_mi)

	var arches := ProceduralForestMeshes.get_launcher_arches()
	for i in range(arches.size()):
		var a_data: Dictionary = arches[i]
		var mi := MeshInstance3D.new()
		mi.name = "Arch_" + str(i)
		mi.mesh = a_data["mesh"]
		mi.position = a_data["center"]
		mi.material_override = _shared_arch_mat
		mi.visibility_range_end = vis_end
		mi.visibility_range_end_margin = 20.0 if vis_end > 0.0 else 0.0
		_arches_holder.add_child(mi)

	# 3. Racines-fouets (rétractées au repos via fin = 1.0, jaillissent vers le ciel à l'activation)
	if not Engine.is_editor_hint():
		var whips := ProceduralForestMeshes.get_launcher_whips()
		for i in range(whips.size()):
			var w_data: Dictionary = whips[i]
			var w_mi := MeshInstance3D.new()
			w_mi.name = "Whip_" + str(i)
			w_mi.mesh = w_data["mesh"]
			w_mi.position = w_data["center"]
			var w_mat := _shared_arch_mat.duplicate() as ShaderMaterial
			w_mat.set_shader_parameter("fin", 1.0)
			w_mat.set_shader_parameter("debut", 1.0)
			w_mi.material_override = w_mat
			w_mi.visibility_range_end = vis_end
			_visual_root.add_child(w_mi)
			_whip_materials.append(w_mat)

		# 4. Flux ascendant subtil de feuilles/air lumineux pour repérer le tremplin de loin
		_updraft_particles = GPUParticles3D.new()
		_updraft_particles.position = Vector3(0.0, 0.15, 0.0)
		_updraft_particles.amount = 14
		_updraft_particles.lifetime = 1.45
		_updraft_particles.visibility_range_end = 90.0
		_updraft_particles.visibility_range_end_margin = 15.0

		var pmat := ParticleProcessMaterial.new()
		pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pmat.emission_ring_axis = Vector3.UP
		pmat.emission_ring_height = 0.1
		pmat.emission_ring_radius = 0.85
		pmat.emission_ring_inner_radius = 0.25
		pmat.direction = Vector3.UP
		pmat.spread = 8.0
		pmat.initial_velocity_min = 1.4
		pmat.initial_velocity_max = 2.6
		pmat.gravity = Vector3(0.0, 0.8, 0.0)
		pmat.scale_min = 0.55
		pmat.scale_max = 1.15

		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		grad.colors = PackedColorArray([
			Color(0.35, 1.0, 0.72, 0.0),
			Color(0.45, 1.0, 0.78, 0.75),
			Color(0.75, 1.0, 0.90, 0.0)
		])
		var ramp := GradientTexture1D.new()
		ramp.gradient = grad
		pmat.color_ramp = ramp

		_updraft_particles.process_material = pmat
		_updraft_particles.draw_pass_1 = ProceduralForestMeshes.get_spore_quad_mesh(0.14)
		_visual_root.add_child(_updraft_particles)

func _setup_interaction_zones() -> void:
	_proximity_area = get_node_or_null("ProximityArea") as Area3D
	if _proximity_area == null:
		_proximity_area = Area3D.new()
		_proximity_area.name = "ProximityArea"
		_proximity_area.collision_layer = 0
		_proximity_area.collision_mask = 2 # Layer 2 = player
		var col := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = trigger_radius
		cyl.height = 3.0
		col.shape = cyl
		col.position = Vector3(0.0, 1.2, 0.0)
		_proximity_area.add_child(col)
		add_child(_proximity_area)

	if not _proximity_area.body_entered.is_connected(_on_body_entered):
		_proximity_area.body_entered.connect(_on_body_entered)
	if not _proximity_area.body_exited.is_connected(_on_body_exited):
		_proximity_area.body_exited.connect(_on_body_exited)

	# Prompt 3D lisible sans devoir baisser la caméra
	_prompt_label = Label3D.new()
	_prompt_label.name = "PromptLabel3D"
	_prompt_label.text = prompt_text
	_prompt_label.position = Vector3(0.0, 1.35, 0.0)
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.no_depth_test = true
	_prompt_label.fixed_size = false
	_prompt_label.pixel_size = 0.0042
	_prompt_label.font_size = 44
	_prompt_label.outline_size = 12
	_prompt_label.modulate = Color(0.78, 1.0, 0.86, 0.96)
	_prompt_label.outline_modulate = Color(0.04, 0.08, 0.05, 0.95)
	if ResourceLoader.exists(FONT_CINZEL_PATH):
		_prompt_label.font = load(FONT_CINZEL_PATH) as Font
	_prompt_label.visible = false
	add_child(_prompt_label)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.is_in_group("Player") and body.is_multiplayer_authority():
		_local_player_inside = body as CharacterBody3D
		_refresh_prompt_visibility()

func _on_body_exited(body: Node3D) -> void:
	if body == _local_player_inside:
		_local_player_inside = null
		_refresh_prompt_visibility()

func _refresh_prompt_visibility() -> void:
	if _prompt_label == null or not is_instance_valid(_prompt_label):
		return
	if _local_player_inside != null and is_instance_valid(_local_player_inside) and _local_player_inside.get("is_dead") != true:
		_prompt_label.visible = true
		if _cooldown_timer > 0.0:
			_prompt_label.text = "%.1fs" % _cooldown_timer
			_prompt_label.modulate = Color(0.62, 0.66, 0.62, 0.78)
		else:
			_prompt_label.text = prompt_text
			_prompt_label.modulate = Color(0.78, 1.0, 0.86, 0.96)
	else:
		_prompt_label.visible = false

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _cooldown_timer > 0.0:
		_cooldown_timer = maxf(0.0, _cooldown_timer - delta)
		if _cooldown_timer == 0.0:
			_on_rearmed()
		if _local_player_inside != null:
			_refresh_prompt_visibility()

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if _local_player_inside == null or not is_instance_valid(_local_player_inside):
		return
	if _cooldown_timer > 0.0:
		return
	# Ne déclencher que lorsque le joueur contrôle la caméra (aucun menu UI ouvert)
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		use(_local_player_inside)
		# Bloque la propagation vers _unhandled_input pour éviter de lancer le sort slot_2 (touche E) !
		get_viewport().set_input_as_handled()

## Compatible aussi avec InteractionComponent / loot_cast.gd si le joueur vise directement la racine
func use(player: Node3D) -> void:
	if _cooldown_timer > 0.0 or player == null or not is_instance_valid(player):
		return
	if player.get("is_dead") == true:
		return

	# Calcul de la direction horizontale visée par la caméra du joueur
	var forward_xz := -player.global_transform.basis.z
	var cam := player.get_node_or_null("Camera3D") as Camera3D
	if cam == null and "camera" in player and player.camera is Camera3D:
		cam = player.camera
	if cam != null and is_instance_valid(cam):
		forward_xz = -cam.global_transform.basis.z

	forward_xz.y = 0.0
	if forward_xz.length_squared() < 0.0001:
		forward_xz = -player.global_transform.basis.z
		forward_xz.y = 0.0
	forward_xz = forward_xz.normalized() if forward_xz.length_squared() > 0.0001 else Vector3.FORWARD

	# Vitesse verticale exacte pour atteindre launch_height : vy = sqrt(2 * g * h)
	var gravity_mag: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var vy := sqrt(maxf(1.0, 2.0 * gravity_mag * launch_height))
	var launch_vel := forward_xz * horizontal_launch_speed + Vector3.UP * vy

	if player.has_method("apply_air_launch"):
		player.apply_air_launch(launch_vel)
	elif player is CharacterBody3D:
		player.velocity = launch_vel

	# Déclenchement visuel et sonore synchronisé sur tous les pairs
	if multiplayer.has_multiplayer_peer():
		_rpc_trigger_launch_vfx.rpc()
	else:
		_rpc_trigger_launch_vfx()

@rpc("any_peer", "call_local", "reliable")
func _rpc_trigger_launch_vfx() -> void:
	if _cooldown_timer > 0.0:
		return
	_cooldown_timer = cooldown_duration
	_refresh_prompt_visibility()

	# 1. Détente violente des arches + jaillissement des racines-fouets
	if _arches_holder != null and is_instance_valid(_arches_holder):
		var tw_arch := create_tween()
		tw_arch.tween_property(_arches_holder, "scale", Vector3(1.12, 2.25, 1.12), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_arch.tween_property(_arches_holder, "scale", Vector3(0.96, 0.65, 0.96), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_arch.tween_property(_arches_holder, "scale", Vector3.ONE, maxf(0.2, cooldown_duration - 0.50)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	for w_mat in _whip_materials:
		if w_mat != null:
			var tw_w := create_tween()
			tw_w.tween_method(func(v: float): w_mat.set_shader_parameter("fin", v), 1.0, 0.0, 0.11).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			tw_w.tween_interval(0.18)
			tw_w.tween_method(func(v: float): w_mat.set_shader_parameter("fin", v), 0.0, 1.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if _center_glow_mat != null:
		_center_glow_mat.emission_energy_multiplier = 0.25
	if _updraft_particles != null:
		_updraft_particles.emitting = false

	# 2. Bourrasque de particules ascendantes au décollage
	_spawn_launch_gust()

	# 3. Son nerveux de détente de racine + souffle d'air
	_play_launch_audio()

func _on_rearmed() -> void:
	if _center_glow_mat != null:
		_center_glow_mat.emission_energy_multiplier = 1.65
	if _updraft_particles != null:
		_updraft_particles.emitting = true
	if _arches_holder != null and is_instance_valid(_arches_holder):
		var tw := create_tween()
		tw.tween_property(_arches_holder, "scale", Vector3(1.06, 1.15, 1.06), 0.12)
		tw.tween_property(_arches_holder, "scale", Vector3.ONE, 0.16)
	_refresh_prompt_visibility()

func _spawn_launch_gust() -> void:
	var gust := GPUParticles3D.new()
	gust.position = Vector3(0.0, 0.2, 0.0)
	gust.amount = 32
	gust.lifetime = 0.75
	gust.one_shot = true
	gust.explosiveness = 0.95

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pmat.emission_ring_axis = Vector3.UP
	pmat.emission_ring_height = 0.15
	pmat.emission_ring_radius = 1.05
	pmat.emission_ring_inner_radius = 0.2
	pmat.direction = Vector3.UP
	pmat.spread = 22.0
	pmat.initial_velocity_min = 7.5
	pmat.initial_velocity_max = 15.0
	pmat.damping_min = 6.0
	pmat.damping_max = 10.0
	pmat.gravity = Vector3.ZERO
	pmat.scale_min = 0.9
	pmat.scale_max = 2.2

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	grad.colors = PackedColorArray([
		Color(0.55, 1.0, 0.82, 0.95),
		Color(0.25, 0.95, 0.70, 0.55),
		Color(0.15, 0.65, 0.50, 0.0)
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	pmat.color_ramp = ramp

	gust.process_material = pmat
	gust.draw_pass_1 = ProceduralForestMeshes.get_spore_quad_mesh(0.24)
	add_child(gust)
	gust.emitting = true
	var t := get_tree().create_timer(1.2)
	t.timeout.connect(gust.queue_free)

func _play_launch_audio() -> void:
	if ResourceLoader.exists(SFX_WOOSH_PATH):
		var s1 := AudioStreamPlayer3D.new()
		s1.stream = load(SFX_WOOSH_PATH)
		s1.pitch_scale = randf_range(0.88, 1.02)
		s1.volume_db = -8.0
		s1.max_distance = 22.0
		add_child(s1)
		s1.finished.connect(s1.queue_free)
		s1.play()
	if ResourceLoader.exists(SFX_SWOOSH_PATH):
		var s2 := AudioStreamPlayer3D.new()
		s2.stream = load(SFX_SWOOSH_PATH)
		s2.pitch_scale = randf_range(0.75, 0.88)
		s2.volume_db = -9.5
		s2.max_distance = 20.0
		add_child(s2)
		s2.finished.connect(s2.queue_free)
		s2.play()
	if ResourceLoader.exists(SFX_TWANG_PATH):
		var s3 := AudioStreamPlayer3D.new()
		s3.stream = load(SFX_TWANG_PATH)
		s3.pitch_scale = randf_range(0.58, 0.68)
		s3.volume_db = -12.0
		s3.max_distance = 18.0
		add_child(s3)
		s3.finished.connect(s3.queue_free)
		s3.play()
