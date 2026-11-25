extends CanvasLayer

@onready var label: Label = $Label

# Un petit compteur de temps interne
var update_timer: float = 0.0
var _last_enemies_count: int = -1

func _process(delta: float) -> void:
	update_timer += delta
	
	# On met à jour le texte uniquement toutes les 0.3 secondes
	if update_timer >= 0.3:
		update_timer = 0.0 # On remet le compteur à zéro
		
		var enemies_count: int = get_tree().get_node_count_in_group(&"Enemie")
		if enemies_count != _last_enemies_count:
			_last_enemies_count = enemies_count
			label.text = "Enemies remaining: " + str(enemies_count)
