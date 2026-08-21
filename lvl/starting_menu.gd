extends Node3D

@onready var main_menu = $CanvasLayer/VBoxContainer
@onready var anim_player = $AnimationPlayer

@onready var btn_singleplayer: Button = $CanvasLayer/VBoxContainer/singleplayer
@onready var btn_multiplayer: Button = $CanvasLayer/VBoxContainer/multiplayer

@onready var multiplayer_panel = $CanvasLayer/Host_menu
@onready var btn_host: Button = $CanvasLayer/Host_menu/btnHost
@onready var btn_join: Button = $CanvasLayer/Host_menu/btnJoin
@onready var btn_back: Button = $CanvasLayer/Host_menu/btnBack
@onready var ip_input: LineEdit = $CanvasLayer/Host_menu/IPInput

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
	# Lance la scÃ¨ne de jeu standard en solo
	get_tree().change_scene_to_file("res://lvl/game.tscn")

func _on_multiplayer_pressed() -> void:
	# Cache le menu principal, affiche le menu multijoueur
	main_menu.hide()
	multiplayer_panel.show()

# --- MENU MULTIJOUEUR ---

func _on_back_pressed() -> void:
	# Retour au menu principal
	multiplayer_panel.hide()
	main_menu.show()

func _on_host_pressed() -> void:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 4) # Port 8910, 4 joueurs max
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("Serveur crÃ©Ã© avec succÃ¨s !")
		get_tree().change_scene_to_file("res://lvl/game.tscn")
	else:
		print("Erreur lors de la crÃ©ation du serveur : ", error)

func _on_join_pressed() -> void:
	var peer = ENetMultiplayerPeer.new()
	var ip = ip_input.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1" # Si vide, on se connecte Ã  soi-mÃªme (pour tester)
		
	var error = peer.create_client(ip, PORT)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("Tentative de connexion au serveur ", ip, "...")
		get_tree().change_scene_to_file("res://lvl/game.tscn")
	else:
		print("Erreur lors de la connexion : ", error)
