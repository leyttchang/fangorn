@tool
extends Node3D

@export_category("Environnement & Météo")
## Liste des scènes d'ambiance (Pluie, Nuit, etc.) tirées au sort par la seed
@export var weather_presets: Array[PackedScene] = []


func generate_weather(world_seed: int) -> void:
	# On nettoie la météo précédente (utile si on regénère depuis l'éditeur)
	for child in get_children():
		child.queue_free()
		
	# S'il n'y a pas de presets, on annule
	if weather_presets.is_empty():
		return
		
	# Le moment magique : RNG basé sur la seed du monde !
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed
	
	# On pioche une météo au hasard
	var random_index = rng.randi_range(0, weather_presets.size() - 1)
	var chosen_weather = weather_presets[random_index]
	
	if chosen_weather:
		var weather_instance = chosen_weather.instantiate()
		add_child(weather_instance)
		
		# Indispensable pour voir le noeud apparaitre dans l'arbre de scène de l'éditeur !
		if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
			weather_instance.owner = get_tree().edited_scene_root
			
		print("Météo instanciée (Index ", random_index, ")")
