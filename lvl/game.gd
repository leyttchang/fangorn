extends Node3D

const PLAYER_SCENE = preload("res://character/player.tscn")
const PROCEDURAL_MAP_SCENE = preload("res://map/map_generator/map_generator.tscn")

@onready var players_container = $Players

func _ready() -> void:
	if GameData.current_game_mode == GameData.GameMode.NORMAL:
		# On supprime la carte de test / vagues
		if has_node("Wave_mode"):
			$Wave_mode.queue_free()
		
		# On instancie la carte procédurale
		var map_gen = PROCEDURAL_MAP_SCENE.instantiate()
		map_gen.world_seed = GameData.current_seed
		add_child(map_gen)
		
		# On attend que la carte soit générée avant de continuer
		await map_gen.terrain_ready
		
		# On positionne le conteneur des joueurs au point de départ du chemin
		if map_gen.has_method("get_spawn_point"):
			players_container.global_position = map_gen.get_spawn_point() + Vector3(0, 30.0, 0)
		else:
			players_container.global_position = Vector3(0, 100, 0)
	else:
		# En mode Vague, on ne touche à rien, la map est déjà là.
		players_container.global_position = Vector3(0, 26, 2)

	# Si on est le Serveur (Celui qui a cliqué sur Héberger ou Jouer en Solo)
	if multiplayer.is_server():
		# 1. On fait spawner notre propre personnage (ID = 1)
		spawn_player(1)
		
		# 2. On écoute la déconnexion.
		multiplayer.peer_disconnected.connect(remove_player)
	else:
		# Si on est un client, on vient de finir de charger l'écran. 
		# On dit au serveur "C'est bon, je suis là, fais-moi spawner !"
		rpc_id(1, "_rpc_client_ready")

@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_ready() -> void:
	if multiplayer.is_server():
		var sender_id = multiplayer.get_remote_sender_id()
		if not players_container.has_node(str(sender_id)):
			spawn_player(sender_id)

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
