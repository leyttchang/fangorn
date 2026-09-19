extends Node3D

@onready var main_menu = $CanvasLayer/VBoxContainer
@onready var anim_player = $AnimationPlayer

@onready var btn_singleplayer: Button = $CanvasLayer/VBoxContainer/singleplayer
@onready var btn_multiplayer: Button = $CanvasLayer/VBoxContainer/multiplayer
@onready var btn_option: Button = $CanvasLayer/VBoxContainer/option

@onready var option_panel: MarginContainer = $CanvasLayer/option

@onready var singleplayer_panel = $CanvasLayer/Singleplayer
@onready var btn_solo_normal: Button = %S_normal
@onready var btn_solo_wave: Button = %S_wave
@onready var btn_solo_retour: Button = %S_retour
@onready var solo_seed_input: LineEdit = %S_seed_input
@onready var btn_solo_seed_rand: Button = %S_seed_rand

@onready var multiplayer_panel = $CanvasLayer/Host_menu
@onready var btn_host: Button = $CanvasLayer/Host_menu.find_child("btnHost", true, false)
@onready var btn_join: Button = $CanvasLayer/Host_menu.find_child("btnJoin", true, false)
@onready var btn_back: Button = $CanvasLayer/Host_menu.find_child("btnBack", true, false)
@onready var ip_input: LineEdit = $CanvasLayer/Host_menu.find_child("IPInput", true, false)
@onready var m_mode_select: OptionButton = $CanvasLayer/Host_menu.find_child("M_mode_select", true, false)
@onready var host_seed_input: LineEdit = %H_seed_input
@onready var btn_host_seed_rand: Button = %H_seed_rand

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
	btn_option.pressed.connect(_on_option_pressed)
	
	# Connexion des boutons Solo
	btn_solo_normal.pressed.connect(_on_solo_normal_pressed)
	btn_solo_wave.pressed.connect(_on_solo_wave_pressed)
	btn_solo_retour.pressed.connect(_on_solo_retour_pressed)
	if btn_solo_seed_rand:
		btn_solo_seed_rand.pressed.connect(func():
			if solo_seed_input:
				solo_seed_input.text = str(randi() % 1000000)
		)
	
	# Connexion des boutons du menu multijoueur
	if btn_host: btn_host.pressed.connect(_on_host_pressed)
	if btn_join: btn_join.pressed.connect(_on_join_pressed)
	if btn_back: btn_back.pressed.connect(_on_back_pressed)
	if btn_host_seed_rand:
		btn_host_seed_rand.pressed.connect(func():
			if host_seed_input:
				host_seed_input.text = str(randi() % 1000000)
		)
	
	# Boutons du lobby
	if btn_launch != null:
		btn_launch.pressed.connect(_on_launch_pressed)
	if btn_leave != null:
		btn_leave.pressed.connect(_on_leave_lobby_pressed)
		
	# Options
	var btn_fs = option_panel.find_child("Button", true, false)
	if btn_fs: btn_fs.pressed.connect(_on_fullscreen_pressed)
	
	var btn_ret = option_panel.find_child("return", true, false)
	if btn_ret: btn_ret.pressed.connect(_on_option_return_pressed)
		
	# Reseau
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	
	if lobby_panel != null:
		lobby_panel.hide()
	singleplayer_panel.hide()

	# Si on revient d'une partie et qu'on est deja en reseau, on ouvre le lobby direct !
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
			call_deferred("_open_lobby")

# --- GESTION DU LOBBY ---

func _open_lobby() -> void:
	multiplayer_panel.hide()
	main_menu.hide() # On cache le menu principal (boutons solo/multi)
	singleplayer_panel.hide()
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
		rpc("rpc_launch_game", GameData.current_game_mode, GameData.current_seed)

@rpc("authority", "call_local", "reliable")
func rpc_launch_game(mode: int, seed_val: int) -> void:
	# TOUS les joueurs mettent à jour leur mode de jeu et la graine
	GameData.current_game_mode = mode as GameData.GameMode
	GameData.current_seed = seed_val
	# TOUS les joueurs changent de scene en meme temps
	get_tree().change_scene_to_file("res://lvl/game.tscn")


# --- MENU PRINCIPAL ---

func _on_singleplayer_pressed() -> void:
	main_menu.hide()
	singleplayer_panel.show()

func _on_solo_normal_pressed() -> void:
	GameData.current_game_mode = GameData.GameMode.NORMAL
	var s_text = solo_seed_input.text.strip_edges() if solo_seed_input else ""
	if s_text != "" and s_text.is_valid_int():
		GameData.current_seed = s_text.to_int()
	else:
		GameData.current_seed = randi() % 1000000
	print("Menu: Mode Normal Solo lancé avec seed = ", GameData.current_seed)
	get_tree().change_scene_to_file("res://lvl/game.tscn")

func _on_solo_wave_pressed() -> void:
	GameData.current_game_mode = GameData.GameMode.WAVE
	get_tree().change_scene_to_file("res://lvl/game.tscn")

func _on_solo_retour_pressed() -> void:
	singleplayer_panel.hide()
	main_menu.show()

func _on_multiplayer_pressed() -> void:
	main_menu.hide()
	singleplayer_panel.hide()
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
		
		# On recupere le mode choisi par l'hote
		if m_mode_select:
			GameData.current_game_mode = m_mode_select.selected as GameData.GameMode
			var h_text = host_seed_input.text.strip_edges() if host_seed_input else ""
			if h_text != "" and h_text.is_valid_int():
				GameData.current_seed = h_text.to_int()
			else:
				GameData.current_seed = randi() % 1000000
			print("Menu Host: Mode choisi = ", GameData.current_game_mode, " | Seed = ", GameData.current_seed)
		
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

func _on_option_pressed() -> void:
	option_panel.visible = true
	anim_player.play("option_open")

func _on_option_return_pressed() -> void:
	anim_player.play_backwards("option_open")
	await anim_player.animation_finished
	option_panel.visible = false

func _on_fullscreen_pressed() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
