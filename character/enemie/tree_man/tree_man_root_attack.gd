class_name TreeManRootAttack
extends Node3D

## Contrôleur de l'attaque de racines du Tree Man (mode "aller-retour" / LOOP_PINGPONG) :
## - L'animation "grow" démarre toute seule (0 -> length : sortie, length -> 0 : rétraction)
## - Coupe net l'animation dès que les racines sont complètement rentrées sous terre et détruit l'instance
## - Isole les matériaux/shapes par instance pour que plusieurs Tree Man puissent attaquer en même temps

signal roots_retracted

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var attack_component: AttackComponent = $AttackComponent
@onready var attack_shape: CollisionShape3D = $AttackComponent/CollisionShape3D

var _has_extended: bool = false
var _saw_retracting: bool = false
var _finished: bool = false
var _elapsed: float = 0.0
var _anim_len: float = 2.0

func _ready() -> void:
	# En Godot, _ready() de l'enfant AnimationPlayer (autoplay = "grow") s'exécute AVANT celui du parent
	# et met en cache les références vers les ressources d'origine. On stoppe, on duplique, puis on
	# vide le cache (clear_caches) avant de relancer "grow" sur les matériaux/shapes dupliqués !
	if anim_player != null:
		anim_player.stop()

	_make_resources_unique()

	if anim_player != null:
		anim_player.clear_caches()
		if anim_player.has_animation("grow"):
			var anim := anim_player.get_animation("grow")
			if anim != null:
				_anim_len = maxf(0.1, anim.length)
			anim_player.play("grow")

func _make_resources_unique() -> void:
	# Dupliquer le BoxShape3D pour ne pas partager sa taille animée entre deux Tree Man
	if attack_shape != null and attack_shape.shape != null:
		attack_shape.shape = attack_shape.shape.duplicate()

	# Dupliquer chaque mesh + ShaderMaterial de surface_0 pour isoler shader_parameter/debut
	var roots_holder := get_node_or_null("root_attacj")
	if roots_holder != null:
		for child in roots_holder.get_children():
			if child is MeshInstance3D and child.mesh != null:
				var dup_mesh: Mesh = child.mesh.duplicate()
				var surf_mat: Material = dup_mesh.surface_get_material(0)
				if surf_mat != null:
					var dup_mat: Material = surf_mat.duplicate()
					if dup_mat is ShaderMaterial:
						dup_mat.set_shader_parameter("debut", 0.0)
					dup_mesh.surface_set_material(0, dup_mat)
				child.mesh = dup_mesh

func set_speed_scale(scale_val: float) -> void:
	if anim_player != null:
		anim_player.speed_scale = maxf(0.0, scale_val)

func _process(delta: float) -> void:
	if _finished or anim_player == null:
		return

	var spd_scale := anim_player.speed_scale
	if spd_scale <= 0.0:
		return

	_elapsed += delta * spd_scale
	var pos := anim_player.current_animation_position
	var play_spd := anim_player.get_playing_speed()

	if pos >= _anim_len * 0.55:
		_has_extended = true

	if _has_extended and play_spd < 0.0:
		_saw_retracting = true
		# Pendant la rétraction, on peut couper la hitbox en fin de course pour être fair-play
		if pos <= _anim_len * 0.18 and attack_shape != null and not attack_shape.disabled:
			attack_shape.disabled = true

	# Coupe l'animation dès que l'aller-retour revient à 0 (ou si le ping-pong vient tout juste de rebondir)
	var back_to_zero := (_saw_retracting and pos <= 0.045)
	var bounced_past_zero := (_saw_retracting and play_spd > 0.0)
	var time_completed := (_elapsed >= (_anim_len * 2.0) - 0.025)

	if back_to_zero or bounced_past_zero or time_completed:
		_cut_and_finish()

func _cut_and_finish() -> void:
	if _finished:
		return
	_finished = true

	if attack_shape != null:
		attack_shape.disabled = true

	if anim_player != null:
		if anim_player.has_animation("RESET"):
			anim_player.play("RESET")
			anim_player.advance(0.0)
		anim_player.stop()

	visible = false
	roots_retracted.emit()
	queue_free()
