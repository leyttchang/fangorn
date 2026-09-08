extends Node3D

const PLAYER_SCENE = preload("res://character/player.tscn")
@onready var players_container = $Players

func _ready() -> void:
	# Si on est le Serveur (Celui qui a clique sur Heberger ou Jouer en Solo)
	if multiplayer.is_server():
		# 1. On fait spawner notre propre personnage (ID = 1)
		spawn_player(1)
		
		# 2. On n'utilise plus peer_connected pour faire spawner direct, car le client
		# n'a pas encore eu le temps de charger la map (écran gris) !
		# On ecoute juste la deconnexion.
		multiplayer.peer_disconnected.connect(remove_player)
	else:
		# Si on est un client, on vient de finir de charger l'ecran. 
		# On dit au serveur "C'est bon, je suis la, fais-moi spawner !"
		rpc_id(1, "_rpc_client_ready")

@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_ready() -> void:
	if multiplayer.is_server():
		var sender_id = multiplayer.get_remote_sender_id()
		if not players_container.has_node(str(sender_id)):
			spawn_player(sender_id)

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
