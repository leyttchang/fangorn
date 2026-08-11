extends Node

var player: CharacterBody3D
var has_double_jumped: bool = false

func _ready() -> void:
	# Notre architecture : Joueur -> KeystoneModifiers -> Ce script
	player = get_parent().get_parent() as CharacterBody3D

func _physics_process(delta: float) -> void:
	if player == null:
		return
		
	# On réinitialise le double saut si le joueur touche le sol
	if player.is_on_floor():
		if has_double_jumped:
			print("Keystone: Touché le sol, double saut rechargé !")
		has_double_jumped = false
		
	# Si on appuie sur saut, qu'on est en l'air, et qu'on n'a pas encore double sauté :
	if Input.is_action_just_pressed("jump") and not player.is_on_floor() and not has_double_jumped:
		# Sécurité : On vérifie qu'on ne vient pas TOUT JUSTE de sauter ce quart de seconde !
		# (Sinon ça consomme le double saut à la frame exacte où on quitte le sol)
		if player.velocity.y < (player.JUMP_VELOCITY - 0.1):
			print("Keystone: DOUBLE SAUT DÉCLENCHÉ !")
			player.velocity.y = player.JUMP_VELOCITY
			has_double_jumped = true
		else:
			print("Keystone: Tentative de double saut trop proche du saut initial, ignorée.")
