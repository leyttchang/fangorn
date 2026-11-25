class_name CombatFeedbackComponent
extends Node

@export var damage_text_scene: PackedScene # Tu glisseras damage_text.tscn ici
@export var health_component: HealthComponent
@export var spawn_height: float = 1.0 # La hauteur d'apparition
@export var play_impact_sound: bool = true ## Décocher si un HurtSoundComponent gère déjà les sons de dégâts

## Liste de sons d'impact personnalisés. Un son sera choisi au hasard à chaque coup reçu.
@export var hit_sounds: Array[AudioStream] = []

## Optionnel : Un fichier son d'impact unique (conservation pour rétrocompatibilité)
@export var custom_hit_sound: AudioStream

## Volume sonore des bruits d'impact (en dB)
@export_range(-80.0, 24.0, 0.5) var volume_db: float = 0.0

## Variation aléatoire de la hauteur/pitch du son (min et max)
@export_range(0.1, 3.0, 0.05) var pitch_min: float = 0.88
@export_range(0.1, 3.0, 0.05) var pitch_max: float = 1.12

## Distance maximale d'écoute du son en 3D (en mètres)
@export var max_distance: float = 40.0

@export_group("Flash Effect")
@export var enable_flash: bool = true
## Glisse ici un StandardMaterial3D (coche Unshaded, couleur Blanche)
@export var flash_material: Material 
@export var flash_duration: float = 0.1

# Limite stricte de textes instancies par frame pour les AoE (Bloqueur de perf)
static var _texts_spawned_this_frame: int = 0
static var _frame_reset_active: bool = false

# NOUVEAU : Limite stricte de textes par frame pour les AoE
var _active_text: Label3D = null

func _ready() -> void:
	if health_component != null:
		health_component.damage_taken.connect(_on_damage_taken)
	else:
		push_warning("CombatFeedbackComponent sur " + get_parent().name + " : Pas de HealthComponent assigné !")

func _on_damage_taken(amount: float, is_critical: bool = false) -> void:
	# Joue le son d'impact 3D uniquement si active
	if play_impact_sound and get_parent() is Node3D:
		var sound_to_play: AudioStream = null
		if not hit_sounds.is_empty():
			sound_to_play = hit_sounds.pick_random()
		elif custom_hit_sound != null:
			sound_to_play = custom_hit_sound
			
		SoundManager.play_hit_sound(self, get_parent().global_position, sound_to_play, volume_db, pitch_min, pitch_max, max_distance)

	if damage_text_scene != null:
		if is_instance_valid(_active_text):
			var pos = get_parent().global_position + Vector3(0, spawn_height, 0)
			_active_text.add_damage(amount, pos, is_critical)
		else:
			if CombatFeedbackComponent._texts_spawned_this_frame < 5:
				CombatFeedbackComponent._texts_spawned_this_frame += 1
				
				_active_text = damage_text_scene.instantiate()
				get_tree().root.add_child(_active_text)
				_active_text.global_position = get_parent().global_position + Vector3(0, spawn_height, 0)
				_active_text.start_animation(amount, is_critical)
				
				if not CombatFeedbackComponent._frame_reset_active and get_tree() != null:
					CombatFeedbackComponent._reset_counter_next_frame(get_tree())

	if enable_flash and flash_material != null:
		_flash_meshes()

var _current_flash_id: int = 0
var _cached_meshes: Array[MeshInstance3D] = []
var _meshes_cached: bool = false
var _flash_mat_instance: Material = null
var _cached_status_comp: Node = null
var _status_comp_searched: bool = false

func _flash_meshes() -> void:
	if not is_inside_tree():
		return
	var parent = get_parent()
	if parent == null:
		return

	_current_flash_id += 1
	var expected_id = _current_flash_id
	
	if not _meshes_cached:
		_cached_meshes = _get_all_meshes(parent)
		_meshes_cached = true
	
	# On regarde SI on a un effet de statut actif (pour le fusionner avec le flash)
	if not _status_comp_searched:
		_status_comp_searched = true
		_cached_status_comp = parent.get_node_or_null("status_effect_componant")
	var target_overlay: Material = null
	if _cached_status_comp != null and is_instance_valid(_cached_status_comp) and _cached_status_comp.has_method("get_current_overlay_material"):
		target_overlay = _cached_status_comp.get_current_overlay_material()
		
	if _flash_mat_instance == null:
		_flash_mat_instance = flash_material.duplicate()
		_flash_mat_instance.resource_name = "HitFlash"
	
	# Met à jour (ou réinitialise à null) le next_pass sur l'instance réutilisée
	_flash_mat_instance.next_pass = target_overlay

	# Appliquer le flash en OVERLAY (permet de garder la transparence et l'effet en meme temps)
	for mesh in _cached_meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = _flash_mat_instance
		
	# Attendre la duree du flash
	await get_tree().create_timer(flash_duration).timeout
	
	if not is_inside_tree():
		return

	# Retirer le materiel UNIQUEMENT si aucune autre attaque n'a eu lieu entre temps
	if _current_flash_id == expected_id:
		# On cherche si un composant d'effet de statut a un overlay a remettre
		var restore_overlay: Material = null
		if _cached_status_comp != null and is_instance_valid(_cached_status_comp) and _cached_status_comp.has_method("get_current_overlay_material"):
			restore_overlay = _cached_status_comp.get_current_overlay_material()
			
		for mesh in _cached_meshes:
			if is_instance_valid(mesh):
				mesh.material_overlay = restore_overlay

func _get_all_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_get_all_meshes(child))
	return result

static func _reset_counter_next_frame(tree: SceneTree) -> void:
	_frame_reset_active = true
	await tree.process_frame
	_texts_spawned_this_frame = 0
	_frame_reset_active = false
