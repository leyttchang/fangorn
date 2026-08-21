extends Node3D

const PLAYER_SCENE = preload("res://character/player.tscn")
@onready var players_container = $Players

func _ready() -> void:
	# Si on est le Serveur (Celui qui a cliqué sur Héberger ou Jouer en Solo)
	if multiplayer.is_server():
		# 1. On fait spawner notre propre personnage (ID = 1)
		spawn_player(1)
		
		# 2. On écoute le réseau : si quelqu'un se connecte, on le fait spawner
		multiplayer.peer_connected.connect(spawn_player)
		# Si quelqu'un part, on efface son personnage
		multiplayer.peer_disconnected.connect(remove_player)

# Fonction appelée par le serveur pour créer un joueur
func spawn_player(peer_id: int) -> void:
	var player = PLAYER_SCENE.instantiate()
	# Le nom du nœud EST l'ID réseau du joueur (très important !)
	player.name = str(peer_id)
	
	# On l'ajoute dans le dossier "Players". 
	# Le PlayerSpawner va le détecter et l'envoyer à tout le monde !
	players_container.add_child(player, true)

# Fonction appelée par le serveur quand quelqu'un quitte
func remove_player(peer_id: int) -> void:
	var player = players_container.get_node_or_null(str(peer_id))
	if player:
		player.queue_free()
