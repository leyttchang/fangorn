extends Label3D

func animate(damage_amount: float) -> void:
	# On affiche le nombre de dégâts (avec 1 seul chiffre après la virgule)
	text = "%.1f" % damage_amount
	
	# On crée une animation
	var tween = create_tween()
	
	# set_parallel(true) permet de faire les deux animations en même temps
	tween.set_parallel(true)
	
	# 1. Le texte monte de 1.5 mètres vers le haut en 1 seconde
	tween.tween_property(self, "position:y", position.y + 1.5, 1).set_ease(Tween.EASE_OUT)
	
	# 2. Le texte devient transparent (modulate:a = alpha = 0) en 1 seconde
	tween.tween_property(self, "modulate:a", 0.0, 1)
	
	# 3. Quand c'est fini, on supprime le texte de la mémoire !
	tween.chain().tween_callback(queue_free)
