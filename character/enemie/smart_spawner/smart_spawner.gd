class_name SmartSpawner
extends Node3D

# --- SIGNAUX ---
signal wave_started(wave_number: int, total_enemies: int)
signal wave_completed(wave_number: int)
signal enemy_spawned(enemy: Node3D)

# --- TYPES D'ENNEMIS ---
@export var monster_types: Array[PackedScene] = []

# --- CONFIGURATION DES VAGUES ---
@export_group("Configuration Vagues")
@export var initial_wave_count: int = 5
@export var enemies_increase_per_wave: int = 2
@export var delay_between_waves: float = 3.0
@export var time_between_spawns: float = 0.3
@export var spawn_radius: float = 10.0
@export var wave_reward_score: int = 5
@export var auto_start: bool = true

# --- ÉTAT INTERNE ---
var current_wave: int = 0
var active_enemies: Array[Node3D] = []
var is_spawning_wave: bool = false
var enemies_left_to_spawn: int = 0

func _ready() -> void:
	add_to_group("SmartSpawner")
	if auto_start:
		if is_inside_tree():
			get_tree().create_timer(1.0).timeout.connect(start_next_wave)

func start_next_wave() -> void:
	if not is_inside_tree(): return
	if monster_types.is_empty():
		push_warning("SmartSpawner sur " + name + " : Aucune scène d'ennemi dans monster_types !")
		return
		
	current_wave += 1
	active_enemies.clear()
	is_spawning_wave = true
	
	# Calcul du nombre d'ennemis pour cette vague
	enemies_left_to_spawn = initial_wave_count + (current_wave - 1) * enemies_increase_per_wave
	
	wave_started.emit(current_wave, enemies_left_to_spawn)
	print("--- DÉBUT DE LA VAGUE " + str(current_wave) + " (" + str(enemies_left_to_spawn) + " ennemis) ---")
	
	_spawn_next_enemy_in_wave()

func _spawn_next_enemy_in_wave() -> void:
	if not is_inside_tree(): return
	
	if enemies_left_to_spawn <= 0:
		is_spawning_wave = false
		_check_wave_completion()
		return
		
	_spawn_single_enemy()
	enemies_left_to_spawn -= 1
	
	if enemies_left_to_spawn > 0:
		var tree = get_tree()
		if tree != null:
			tree.create_timer(time_between_spawns).timeout.connect(_spawn_next_enemy_in_wave)
	else:
		is_spawning_wave = false
		_check_wave_completion()

func _spawn_single_enemy() -> void:
	if not is_inside_tree(): return
	if monster_types.is_empty(): return
	
	# Tirage au sort du type d'ennemi
	var enemy_scene: PackedScene = monster_types.pick_random()
	if enemy_scene == null: return
	
	var enemy_instance: Node3D = enemy_scene.instantiate() as Node3D
	get_tree().current_scene.add_child(enemy_instance)
	
	# Position aléatoire dans le rayon autour du spawner
	var random_angle: float = randf_range(0, TAU)
	var random_dist: float = sqrt(randf()) * spawn_radius
	var offset: Vector3 = Vector3(cos(random_angle) * random_dist, 0, sin(random_angle) * random_dist)
	
	enemy_instance.global_position = global_position + offset
	
	# Suivi de l'ennemi vivant
	active_enemies.append(enemy_instance)
	enemy_spawned.emit(enemy_instance)
	
	# On s'abonne à la suppression de l'ennemi
	enemy_instance.tree_exited.connect(func(): _on_enemy_removed(enemy_instance))

func _on_enemy_removed(enemy: Node3D) -> void:
	if active_enemies.has(enemy):
		active_enemies.erase(enemy)
	_check_wave_completion()

func _check_wave_completion() -> void:
	if not is_inside_tree(): return
	
	# Nettoyage des instances invalides
	active_enemies = active_enemies.filter(func(e): return is_instance_valid(e) and e.is_inside_tree())
	
	# Si la vague a fini de spawner ET qu'il n'y a plus d'ennemi actif dans cette vague
	if not is_spawning_wave and enemies_left_to_spawn <= 0 and active_enemies.is_empty():
		print("--- VAGUE " + str(current_wave) + " TERMINÉE ! ---")
		wave_completed.emit(current_wave)
		
		# Récompense de score pour la vague réussie
		var score_managers = get_tree().get_nodes_in_group("ScoreManager")
		for sm in score_managers:
			if sm.has_method("add_score_points"):
				sm.add_score_points(wave_reward_score)
		
		# Pause avant la vague suivante
		var tree = get_tree()
		if tree != null:
			tree.create_timer(delay_between_waves).timeout.connect(start_next_wave)
