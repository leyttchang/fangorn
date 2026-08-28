extends Node3D

const PLAYER_SCENE = preload("res://character/player.tscn")
@onready var players_container = $Players

func _ready() -> void:
	# Si on est le Serveur (Celui qui a clique sur Heberger ou Jouer en Solo)
	if multiplayer.is_server():
		# 1. On fait spawner notre propre personnage (ID = 1)
		spawn_player(1)
		
		# 2. On fait spawner les joueurs deja dans le lobby
		for peer_id in multiplayer.get_peers():
			spawn_player(peer_id)
			
		# 3. On ecoute le reseau : si quelqu'un se connecte plus tard, on le fait spawner
		multiplayer.peer_connected.connect(spawn_player)
		# Si quelqu'un part, on efface son personnage
		multiplayer.peer_disconnected.connect(remove_player)

# Fonction appelee par le serveur pour creer un joueur
func spawn_player(peer_id: int) -> void:
	var player = PLAYER_SCENE.instantiate()
	# Le nom du noeud EST l'ID reseau du joueur (tres important !)
	player.name = str(peer_id)
	
	# On l'ajoute dans le dossier "Players". 
	# Le PlayerSpawner va le detecter et l'envoyer a tout le monde !
	players_container.add_child(player, true)

# Fonction appelee par le serveur quand quelqu'un quitte
func remove_player(peer_id: int) -> void:
	var player = players_container.get_node_or_null(str(peer_id))
	if player:
		player.queue_free()
