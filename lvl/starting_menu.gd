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

const PORT = 8910

func _ready() -> void:
	# Connexion des boutons du menu principal
	btn_singleplayer.pressed.connect(_on_singleplayer_pressed)
	btn_multiplayer.pressed.connect(_on_multiplayer_pressed)
	
	# Connexion des boutons du menu multijoueur
	btn_host.pressed.connect(_on_host_pressed)
	btn_join.pressed.connect(_on_join_pressed)
	btn_back.pressed.connect(_on_back_pressed)

# --- MENU PRINCIPAL ---

func _on_singleplayer_pressed() -> void:
	# Lance la scne de jeu standard en solo
	get_tree().change_scene_to_file("res://lvl/game.tscn")

func _on_multiplayer_pressed() -> void:
	# Cache le menu principal, affiche le menu multijoueur
	main_menu.hide()
	multiplayer_panel.show()
	anim_player.play("multi_open")

# --- MENU MULTIJOUEUR ---

func _on_back_pressed() -> void:
	# Joue l'animation à l'envers et attend qu'elle se termine
	anim_player.play_backwards("multi_open")
	await anim_player.animation_finished
	
	# Retour au menu principal
	multiplayer_panel.hide()
	main_menu.show()

func _on_host_pressed() -> void:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 4) # Port 8910, 4 joueurs max
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("Serveur cree avec succes !")
		get_tree().change_scene_to_file("res://lvl/game.tscn")
	else:
		print("Erreur lors de la creation du serveur : ", error)

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
		print("Tentative de connexion au serveur ", ip, ":", target_port)
		get_tree().change_scene_to_file("res://lvl/game.tscn")
	else:
		print("Erreur lors de la connexion : ", error)
