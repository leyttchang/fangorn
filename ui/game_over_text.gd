extends CanvasLayer

func _ready() -> void:
	# Par scurit, on s'assure qu'il est invisible au dbut
	hide()

func afficher_game_over() -> void:
	# On rend l'cran visible
	show()
	# Et on joue l'animation !
	$AnimationPlayer.play("spawn")
