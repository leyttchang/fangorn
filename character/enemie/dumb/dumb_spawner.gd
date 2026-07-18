extends Node3D

@export var Dumb : PackedScene

# --- PARAMÈTRES DE DIFFICULTÉ ---
@export var start_spawn_time: float = 4.0   
@export var minimum_spawn_time: float = 0.5 
@export var decrease_step: float = 0.1      
@export var max_scaling_duration: float = 30.0 

# --- GESTION DE LA POPULATION ---
@export var max_enemies_on_map: int = 60
var can_spawn: bool = true

var spawn_timer: Timer
var check_timer: Timer
var current_spawn_time: float
var can_scale_difficulty: bool = true 

func _ready() -> void:
	current_spawn_time = start_spawn_time
	
	# 1. Le Chronomètre de Spawn
	spawn_timer = Timer.new()
	spawn_timer.wait_time = current_spawn_time
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_on_timeout) 
	add_child(spawn_timer)
	
	# 2. Le Chronomètre de Vérification (Toutes les 3 secondes)
	check_timer = Timer.new()
	check_timer.wait_time = 3.0
	check_timer.autostart = true
	check_timer.timeout.connect(_check_enemy_count)
	add_child(check_timer)

	# 3. La sécurité des 30 secondes
	get_tree().create_timer(max_scaling_duration).timeout.connect(_stop_scaling)


func _stop_scaling() -> void:
	can_scale_difficulty = false


# ==========================================================
# VÉRIFICATION DE LA LIMITE D'ENNEMIS
# ==========================================================
func _check_enemy_count() -> void:
	var enemies_count = get_tree().get_nodes_in_group("Enemie").size()
	
	if enemies_count >= max_enemies_on_map:
		can_spawn = false
	else:
		can_spawn = true


# ==========================================================
# APPARITION ET DIFFICULTÉ
# ==========================================================
func _on_timeout() -> void:
	# La sécurité est ici : on ne spawn que si le flag l'autorise
	if can_spawn:
		spawn_dumb()
	
	# OPTIMISATION DE LA DIFFICULTÉ (Continue de tourner même si ça ne spawn pas)
	if can_scale_difficulty and current_spawn_time > minimum_spawn_time:
		current_spawn_time -= decrease_step
		
		if current_spawn_time < minimum_spawn_time:
			current_spawn_time = minimum_spawn_time
			
		spawn_timer.wait_time = current_spawn_time


func spawn_dumb() -> void:
	if Dumb == null:
		return
		
	var new_dumb = Dumb.instantiate()
	get_tree().current_scene.add_child(new_dumb)
	new_dumb.global_position = global_position
