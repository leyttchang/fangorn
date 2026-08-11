extends Node3D

@onready var destroy_timer: Timer = $destroy_timer

func _ready() -> void:
	if destroy_timer != null:
		# On s'abonne au signal timeout du timer
		destroy_timer.timeout.connect(_on_timeout)
		
		# On lance le timer au cas où tu n'aurais pas coché "Autostart" dans l'inspecteur
		if not destroy_timer.autostart:
			destroy_timer.start()
	else:
		push_warning("ManaStorm: Le nœud 'destroy_timer' est introuvable ! Vérifie l'orthographe.")

	# NOUVEAU : On s'assure que si tu as mis un SpellScalingComponent, il est exécuté !
	# get_parent() est le joueur, car le script manastorm.gd attache cette scène au joueur.
	var player = get_parent()
	for child in get_children():
		if child.has_method("on_execute"):
			child.on_execute(player, {}) # On passe un dictionnaire vide, le scaling magique s'en chargera

func _on_timeout() -> void:
	# Dès que le timer est fini, on détruit la scène
	queue_free()
