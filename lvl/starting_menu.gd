extends Node3D

@onready var main_menu = $CanvasLayer/VBoxContainer
@onready var anim_player = $AnimationPlayer

@onready var btn_singleplayer: Button = $CanvasLayer/VBoxContainer/singleplayer
@onready var btn_multiplayer: Button = $CanvasLayer/VBoxContainer/multiplayer

@onready var multiplayer_panel = $CanvasLayer/Host_menu
@onready var btn_host: Button = $CanvasLayer/Host_menu.find_child("btnHost", true, false)
@onready var btn_join: Button = $CanvasLayer/Host_menu.find_child("btnJoin", true, false)
@onready var btn_back: Button = $CanvasLayer/Host_menu.find_child("btnBack", true, false)
@onready var ip_input: LineEdit = $CanvasLayer/Host_menu.find_child("IPInput", true, false)

@export_group("Lobby")
@export var pseudo_input: LineEdit
@export var lobby_panel: Control
@export var btn_launch: Button
@export var btn_leave: Button
@export var player_labels: Array[Label]

const PORT = 8910

func _ready() -> void:
	# Connexion des boutons du menu principal
	btn_singleplayer.pressed.connect(_on_singleplayer_pressed)
	btn_multiplayer.pressed.connect(_on_multiplayer_pressed)
	
	# Connexion des boutons du menu multijoueur
	btn_host.pressed.connect(_on_host_pressed)
	btn_join.pressed.connect(_on_join_pressed)
	btn_back.pressed.connect(_on_back_pressed)
	
	# Boutons du lobby
	if btn_launch != null:
		btn_launch.pressed.connect(_on_launch_pressed)
	if btn_leave != null:
		btn_leave.pressed.connect(_on_leave_lobby_pressed)
		
	# Reseau
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	
	if lobby_panel != null:
		lobby_panel.hide()

	# Si on revient d'une partie et qu'on est deja en reseau, on ouvre le lobby direct !
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
			call_deferred("_open_lobby")

# --- GESTION DU LOBBY ---

func _open_lobby() -> void:
	multiplayer_panel.hide()
	main_menu.hide() # On cache le menu principal (boutons solo/multi)
	if lobby_panel != null:
		lobby_panel.show()
		
	if btn_launch != null:
		# Seul le serveur peut lancer la partie
		btn_launch.visible = multiplayer.is_server()
		
	# Rafraichir l'UI
	if multiplayer.is_server():
		_update_lobby_ui()

func _on_peer_connected(id: int) -> void:
	# On ne met pas a jour le lobby tout de suite, on attend que le joueur envoie son pseudo
	pass

func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server() and lobby_panel != null and lobby_panel.visible:
		GameData.player_pseudos.erase(id)
		_update_lobby_ui()

func _on_connected_to_server() -> void:
	# Le client vient de se connecter, il envoie son pseudo au serveur
	var my_pseudo = "Joueur " + str(multiplayer.get_unique_id())
	if pseudo_input != null and pseudo_input.text.strip_edges() != "":
		my_pseudo = pseudo_input.text.strip_edges()
	rpc_id(1, "rpc_register_player", my_pseudo)

@rpc("any_peer", "call_remote", "reliable")
func rpc_register_player(pseudo: String) -> void:
	if multiplayer.is_server():
		var sender_id = multiplayer.get_remote_sender_id()
		GameData.player_pseudos[sender_id] = pseudo
		_update_lobby_ui()

func _update_lobby_ui() -> void:
	rpc("rpc_sync_lobby", GameData.player_pseudos)

@rpc("authority", "call_local", "reliable")
func rpc_sync_lobby(players_dict: Dictionary) -> void:
	GameData.player_pseudos = players_dict # on met a jour la copie locale
	if player_labels.is_empty(): return
	
	var ids = players_dict.keys()
	for i in range(player_labels.size()):
		var label = player_labels[i]
		if label == null: continue
		
		if i < ids.size():
			var id = ids[i]
			var pseudo = players_dict[id]
			label.text = pseudo
			if id == multiplayer.get_unique_id():
				label.text += " (Toi)"
			label.show()
		else:
			label.text = "---"
			label.hide()

func _on_leave_lobby_pressed() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	GameData.player_pseudos.clear()
	if lobby_panel != null:
		lobby_panel.hide()
	multiplayer_panel.show()

func _on_launch_pressed() -> void:
	if multiplayer.is_server():
		rpc("rpc_launch_game")

@rpc("authority", "call_local", "reliable")
func rpc_launch_game() -> void:
	# TOUS les joueurs changent de scene en meme temps
	get_tree().change_scene_to_file("res://lvl/game.tscn")

# --- MENU PRINCIPAL ---

func _on_singleplayer_pressed() -> void:
	get_tree().change_scene_to_file("res://lvl/game.tscn")

func _on_multiplayer_pressed() -> void:
	main_menu.hide()
	multiplayer_panel.show()
	anim_player.play("multi_open")

# --- MENU MULTIJOUEUR ---

func _on_back_pressed() -> void:
	anim_player.play_backwards("multi_open")
	await anim_player.animation_finished
	multiplayer_panel.hide()
	main_menu.show()

func _on_host_pressed() -> void:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 7)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("Serveur cree, ouverture du lobby...")
		
		# Le Host s'enregistre lui-meme
		GameData.player_pseudos.clear()
		var my_pseudo = "Host"
		if pseudo_input != null and pseudo_input.text.strip_edges() != "":
			my_pseudo = pseudo_input.text.strip_edges()
		GameData.player_pseudos[1] = my_pseudo
		
		_open_lobby()
	else:
		print("Erreur : ", error)

func _on_join_pressed() -> void:
	var peer = ENetMultiplayerPeer.new()
	var input_text = ip_input.text.strip_edges()
	var ip = input_text
	var target_port = PORT

	if input_text == "":
		ip = "127.0.0.1"
	elif ":" in input_text:
		var parts = input_text.split(":")
		ip = parts[0]
		target_port = parts[1].to_int()

	if not ip.is_valid_ip_address():
		ip = IP.resolve_hostname(ip)

	var error = peer.create_client(ip, target_port)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("Connexion au lobby...")
		_open_lobby()
	else:
		print("Erreur lors de la connexion : ", error)
