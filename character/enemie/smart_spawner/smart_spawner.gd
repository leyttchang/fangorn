class_name SmartSpawner
extends Node3D

# --- SIGNAUX ---
signal wave_started(wave_number: int, total_enemies: int)
signal wave_completed(wave_number: int)
signal boss_wave_incoming(wave_number: int)
signal enemy_spawned(enemy: Node3D)

# --- TYPES D'ENNEMIS ---
@export var monster_types: Array[PackedScene] = []
## Les couts des monstres (doit etre dans le meme ordre que monster_types). Par defaut = 10
@export var monster_costs: Array[int] = []
## Les poids/chances de spawn (ex: 1.0 pour standard, 0.5 pour rare, 2.0 pour trs frquent)
@export var monster_weights: Array[float] = []

# --- CONFIGURATION DES VAGUES ---
@export_group("Configuration Vagues")
@export var initial_wave_credits: int = 50
@export var credits_increase_per_wave: int = 20
@export var delay_between_waves: float = 3.0
@export var time_between_spawns: float = 0.3
@export var spawn_radius: float = 10.0
@export var wave_reward_score: int = 5
@export var auto_start: bool = true

@export_group("Systeme de Beacon")
@export var waves_before_beacon: int = 3
@export var beacon_scene: PackedScene
@export var beacon_spawn_point: Marker3D

# --- CONFIGURATION DES BOSS WAVES ---
@export_group("Boss Waves")
@export var boss_wave_numbers: Array[int] = []
@export var boss_scenes: Array[PackedScene] = []
@export var boss_costs: Array[int] = []
@export var boss_weights: Array[float] = []
@export var boss_spawn_point: Marker3D

# --- ETAT INTERNE ---
var current_wave: int = 0
var current_effective_wave: int = 0
var active_enemies: Array[Node3D] = []
var is_spawning_wave: bool = false
var credits_left_to_spawn: int = 0

var is_paused: bool = false
var _waiting_to_spawn: bool = false
var _waiting_for_next_wave: bool = false
var _waiting_for_beacon: bool = false

func _ready() -> void:
	add_to_group("SmartSpawner")
	if not multiplayer.is_server(): return
	if auto_start:
		if is_inside_tree():
			get_tree().create_timer(1.0).timeout.connect(_spawn_beacon)

@rpc("authority", "call_local", "reliable")
func rpc_wave_started(wave_number: int, total_credits: int) -> void:
	wave_started.emit(wave_number, total_credits)

@rpc("authority", "call_local", "reliable")
func rpc_wave_completed(wave_number: int) -> void:
	wave_completed.emit(wave_number)

@rpc("authority", "call_local", "reliable")
func rpc_boss_wave_incoming(wave_number: int) -> void:
	boss_wave_incoming.emit(wave_number)

func toggle_pause() -> void:
	is_paused = not is_paused
	if not is_paused:
		if _waiting_to_spawn:
			_waiting_to_spawn = false
			_spawn_next_enemy_in_wave()
		elif _waiting_for_next_wave:
			_waiting_for_next_wave = false
			start_next_wave()

func start_next_wave() -> void:
	if not is_inside_tree(): return
	if monster_types.is_empty() and boss_scenes.is_empty():
		push_warning("SmartSpawner sur " + name + " : Aucune scene d'ennemi ou de boss !")
		return
		
	current_wave += 1
	active_enemies.clear()
	is_spawning_wave = true
	
	var boss_waves_passed = 0
	var is_boss_wave = false
	var boss_idx = -1
	
	for i in range(boss_wave_numbers.size()):
		if boss_wave_numbers[i] < current_wave:
			boss_waves_passed += 1
		elif boss_wave_numbers[i] == current_wave:
			boss_waves_passed += 1
			is_boss_wave = true
			boss_idx = i
			
	current_effective_wave = current_wave - boss_waves_passed
	
	if is_boss_wave:
		credits_left_to_spawn = 0
		rpc("rpc_wave_started", current_wave, 0)
		print("--- DEBUT DE LA VAGUE BOSS " + str(current_wave) + " ---")
		
		var b_scene = boss_scenes[boss_idx] if boss_idx < boss_scenes.size() else null
		if b_scene != null:
			_spawn_boss(b_scene)
		else:
			push_error("Aucune scene assignee pour le boss de la vague ", current_wave)
			is_spawning_wave = false
			_check_wave_completion()
	else:
		var base_credits = initial_wave_credits + (current_effective_wave - 1) * credits_increase_per_wave
		
		# Calcul du multiplicateur multijoueur (1 joueur = x1.0, 2 joueurs = x1.5, 3 joueurs = x2.0...)
		var player_count = multiplayer.get_peers().size() + 1
		var multi_multiplier = 1.0 + (player_count - 1) * 0.5
		
		credits_left_to_spawn = int(base_credits * multi_multiplier)
		
		rpc("rpc_wave_started", current_wave, credits_left_to_spawn)
		print("--- DEBUT DE LA VAGUE " + str(current_wave) + " (" + str(credits_left_to_spawn) + " credits restants, scaling niv " + str(current_effective_wave) + ", multi x" + str(multi_multiplier) + ") ---")
		_spawn_next_enemy_in_wave()

func _get_affordable_monsters() -> Array:
	var affordable = []
	for i in range(monster_types.size()):
		if monster_types[i] == null: continue
		
		var cost = 10
		if i < monster_costs.size():
			cost = monster_costs[i]
			
		var weight = 1.0
		if i < monster_weights.size():
			weight = monster_weights[i]
		
		if cost <= credits_left_to_spawn and weight > 0.0:
			affordable.append({"scene": monster_types[i], "cost": cost, "weight": weight})
	return affordable

func _pick_weighted_random(options: Array) -> Dictionary:
	var total_weight: float = 0.0
	for opt in options:
		total_weight += opt.weight
		
	var random_val: float = randf() * total_weight
	var current_weight: float = 0.0
	
	for opt in options:
		current_weight += opt.weight
		if random_val <= current_weight:
			return opt
			
	return options.back()

func _spawn_next_enemy_in_wave() -> void:
	if not is_inside_tree(): return
	
	if is_paused:
		_waiting_to_spawn = true
		return
	
	var affordable = _get_affordable_monsters()
	
	if credits_left_to_spawn <= 0 or affordable.is_empty():
		is_spawning_wave = false
		_check_wave_completion()
		return
		
	var choice = _pick_weighted_random(affordable)
	_spawn_single_enemy(choice.scene)
	
	credits_left_to_spawn -= choice.cost
	
	var tree = get_tree()
	if tree != null:
		tree.create_timer(time_between_spawns).timeout.connect(_spawn_next_enemy_in_wave)

func _spawn_boss(boss_scene: PackedScene) -> void:
	if not is_inside_tree() or boss_scene == null: return
	
	var boss_instance: Node3D = boss_scene.instantiate() as Node3D
	get_tree().current_scene.get_node("NetworkObjects").add_child(boss_instance, true)
	
	if boss_spawn_point != null:
		boss_instance.global_position = boss_spawn_point.global_position
	else:
		var random_angle: float = randf_range(0, TAU)
		var random_dist: float = sqrt(randf()) * spawn_radius
		var offset: Vector3 = Vector3(cos(random_angle) * random_dist, 0, sin(random_angle) * random_dist)
		boss_instance.global_position = global_position + offset
	
	active_enemies.append(boss_instance)
	enemy_spawned.emit(boss_instance)
	boss_instance.tree_exited.connect(func(): _on_enemy_removed(boss_instance))
	
	is_spawning_wave = false
	_check_wave_completion()

func _spawn_single_enemy(enemy_scene: PackedScene) -> void:
	if not is_inside_tree() or enemy_scene == null: return
	
	var is_bundle = enemy_scene.resource_path.ends_with("spider_bundle.tscn")
	var spider_scene = preload("res://character/enemie/spider/spider_enemie.tscn")
	
	if is_bundle:
		for i in range(5):
			_spawn_single_spider_from_bundle(spider_scene)
		return
		
	var enemy_instance: Node3D = enemy_scene.instantiate() as Node3D
	get_tree().current_scene.get_node("NetworkObjects").add_child(enemy_instance, true)
	
	var stats = enemy_instance.get_node_or_null("StatsComponent")
	if stats != null and current_effective_wave > 1:
		var bonus_percent_hp = (current_effective_wave - 1) * 0.10 
		stats.add_modifier("max_health", 1, bonus_percent_hp, "wave_scaling")
	
	var random_angle: float = randf_range(0, TAU)
	var random_dist: float = sqrt(randf()) * spawn_radius
	var offset: Vector3 = Vector3(cos(random_angle) * random_dist, 0, sin(random_angle) * random_dist)
	
	enemy_instance.global_position = global_position + offset
	
	active_enemies.append(enemy_instance)
	enemy_spawned.emit(enemy_instance)
	
	enemy_instance.tree_exited.connect(func(): _on_enemy_removed(enemy_instance))

func _on_enemy_removed(enemy: Node3D) -> void:
	if active_enemies.has(enemy):
		active_enemies.erase(enemy)
	_check_wave_completion()

func _spawn_single_spider_from_bundle(spider_scene: PackedScene) -> void:
	if not is_inside_tree() or spider_scene == null: return
	var enemy_instance: Node3D = spider_scene.instantiate() as Node3D
	get_tree().current_scene.get_node("NetworkObjects").add_child(enemy_instance, true)
	
	var stats = enemy_instance.get_node_or_null("StatsComponent")
	if stats != null and current_effective_wave > 1:
		var bonus_percent_hp = (current_effective_wave - 1) * 0.10 
		stats.add_modifier("max_health", 1, bonus_percent_hp, "wave_scaling")
	
	var random_angle: float = randf_range(0, TAU)
	var random_dist: float = sqrt(randf()) * spawn_radius
	var offset: Vector3 = Vector3(cos(random_angle) * random_dist, 0, sin(random_angle) * random_dist)
	enemy_instance.global_position = global_position + offset
	
	active_enemies.append(enemy_instance)
	enemy_spawned.emit(enemy_instance)
	enemy_instance.tree_exited.connect(func(): _on_enemy_removed(enemy_instance))

func _check_wave_completion() -> void:
	if not is_inside_tree(): return
	
	active_enemies = active_enemies.filter(func(e): return is_instance_valid(e) and e.is_inside_tree())
	
	if not is_spawning_wave and active_enemies.is_empty():
		print("--- VAGUE " + str(current_wave) + " TERMINEE ! ---")
		rpc("rpc_wave_completed", current_wave)
		
		var boss_idx = boss_wave_numbers.find(current_wave)
		if boss_idx != -1:
			var b_scene = boss_scenes[boss_idx] if boss_idx < boss_scenes.size() else null
			if b_scene != null and not monster_types.has(b_scene):
				monster_types.append(b_scene)
				monster_costs.append(boss_costs[boss_idx] if boss_idx < boss_costs.size() else 50)
				monster_weights.append(boss_weights[boss_idx] if boss_idx < boss_weights.size() else 0.5)
				print("--- Boss ajoute au pool des monstres spawnables ! ---")
		
		var score_managers = get_tree().get_nodes_in_group("ScoreManager")
		for sm in score_managers:
			if sm.has_method("add_score_points"):
				sm.add_score_points(wave_reward_score)
		
		var tree = get_tree()
		if tree != null:
			tree.create_timer(delay_between_waves).timeout.connect(_on_delay_between_waves_finished)

func _on_delay_between_waves_finished() -> void:
	var next_wave = current_wave + 1
	var is_next_wave_boss = boss_wave_numbers.has(next_wave)
	
	if is_next_wave_boss:
		rpc("rpc_boss_wave_incoming", next_wave)
		_spawn_beacon()
	elif current_wave > 0 and waves_before_beacon > 0 and current_wave % waves_before_beacon == 0:
		_spawn_beacon()
	elif is_paused:
		_waiting_for_next_wave = true
	else:
		start_next_wave()

func _spawn_beacon() -> void:
	_waiting_for_beacon = true
	print("--- APPARITION DU BEACON (En attente d'interaction) ---")
	
	if beacon_scene != null and beacon_spawn_point != null:
		var beacon = beacon_scene.instantiate() as Node3D
		get_tree().current_scene.get_node("NetworkObjects").add_child(beacon, true)
		beacon.global_position = beacon_spawn_point.global_position
		
		if beacon.has_signal("interacted"):
			beacon.interacted.connect(trigger_beacon)
	else:
		push_warning("SmartSpawner : Pas de beacon_scene ou de beacon_spawn_point configure ! Lancement immediat de la vague.")
		trigger_beacon()

func trigger_beacon() -> void:
	if _waiting_for_beacon:
		_waiting_for_beacon = false
		start_next_wave()
