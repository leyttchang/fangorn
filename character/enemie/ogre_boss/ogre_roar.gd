extends Node3D

func _process(delta: float) -> void:
	var wind = get_node_or_null("wind")
	if wind != null:
		# Force la rotation globale à zéro pour que le vent aille toujours tout droit vers le haut, 
		# peu importe l'orientation du boss.
		wind.global_rotation = Vector3.ZERO
