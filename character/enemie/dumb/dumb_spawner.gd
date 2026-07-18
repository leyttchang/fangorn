extends Node3D

@export var Dumb : PackedScene

# --- PARAMÈTRES DE DIFFICULTÉ ---
@export var start_spawn_time: float = 4.0   # Temps de départ (ex: 1 monstre toutes les 4s)
@export var minimum_spawn_time: float = 0.5 # Limite max de vitesse (ex: 2 monstres par seconde)
@export var decrease_step: float = 0.1      # Combien de secondes on enlève à chaque apparition

var spawn_timer: Timer
var current_spawn_time: float

func _ready() -> void:
	# On initialise le temps de départ
	current_spawn_time = start_spawn_time
	
	# Création du Chronomètre (Timer) 100% par le code
	spawn_timer = Timer.new()
	spawn_timer.wait_time = current_spawn_time
	spawn_timer.autostart = true
	# On connecte le signal de fin du timer à notre fonction d'apparition
	spawn_timer.timeout.connect(_on_timeout) 
	
	# On ajoute le Timer comme enfant du Spawner pour qu'il existe dans le jeu
	add_child(spawn_timer)


func _on_timeout() -> void:
	# 1. On fait apparaître un Orc
	spawn_dumb()
	
	# 2. OPTIMISATION DE LA DIFFICULTÉ : On accélère la cadence !
	if current_spawn_time > minimum_spawn_time:
		current_spawn_time -= decrease_step
		
		# Sécurité : on s'assure de ne jamais descendre en dessous de la limite absolue
		if current_spawn_time < minimum_spawn_time:
			current_spawn_time = minimum_spawn_time
			
		# On met à jour le Timer avec la nouvelle vitesse plus rapide
		spawn_timer.wait_time = current_spawn_time


func spawn_dumb() -> void:
	if Dumb == null:
		print("Erreur : La scène Dumb n'est pas glissée dans l'inspecteur du Spawner !")
		return
		
	# On crée une copie de la scène de l'Orc
	var new_dumb = Dumb.instantiate()
	
	# IMPORTANT : On ajoute l'Orc à la racine du jeu, pas à l'intérieur du Spawner.
	# Comme ça, si ton Spawner bouge ou est détruit, l'Orc reste indépendant dans le monde.
	get_tree().current_scene.add_child(new_dumb)
	
	# On place le monstre exactement aux coordonnées du Spawner
	new_dumb.global_position = global_position
