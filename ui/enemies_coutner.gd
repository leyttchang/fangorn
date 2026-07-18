extends CanvasLayer

@onready var label: Label = $Label

# Un petit compteur de temps interne
var update_timer: float = 0.0

func _process(delta: float) -> void:
	update_timer += delta
	
	# On met à jour le texte uniquement toutes les 0.3 secondes
	if update_timer >= 0.3:
		update_timer = 0.0 # On remet le compteur à zéro
		
		var enemies_count = get_tree().get_nodes_in_group("Enemie").size()
		label.text = "Ennemis restants : " + str(enemies_count)
