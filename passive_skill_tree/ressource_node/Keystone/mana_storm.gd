extends Node

var player: CharacterBody3D
var mana_comp: ManaComponent

# --- CHEMIN DE TA SCÈNE ---
# Modifie ce chemin pour pointer vers l'endroit exact où tu as sauvegardé ta scène mana_storm.tscn
var storm_scene_path: String = "res://passive_skill_tree/ressource_node/Keystone/ks_scene/mana_storm.tscn"

var is_on_cooldown: bool = false
var cooldown_duration: float = 20.0

func _ready() -> void:
	# On retrouve le joueur (la racine)
	player = get_parent().get_parent() as CharacterBody3D
	if player == null:
		return
		
	mana_comp = player.get_node_or_null("mana_component")
	
	if mana_comp != null:
		mana_comp.mana_changed.connect(_on_mana_changed)

func _on_mana_changed(current_mana: float, max_mana: float) -> void:
	if is_on_cooldown or max_mana <= 0:
		return
		
	var mana_percent = (current_mana / max_mana) * 100.0
	
	# Si le mana descend en dessous de 25%
	if mana_percent < 25.0:
		_trigger_mana_storm()

func _trigger_mana_storm() -> void:
	print("Tempête de Mana déclenchée !")
	is_on_cooldown = true
	
	# On vérifie que ta scène existe bien
	if ResourceLoader.exists(storm_scene_path):
		var storm_scene = load(storm_scene_path) as PackedScene
		if storm_scene != null:
			var storm = storm_scene.instantiate()
			
			# Je l'attache en tant qu'enfant direct du joueur, 
			# ainsi la tempête de mana suivra le joueur quand il se déplace !
			player.add_child(storm)
			
			# Si tu préfères qu'elle reste fixe au sol là où elle a été déclenchée, 
			# décommente ces deux lignes et commente celle du dessus (player.add_child) :
			# get_tree().current_scene.add_child(storm)
			# storm.global_position = player.global_position
			
	else:
		push_error("Keystone Manastorm: La scène " + storm_scene_path + " n'a pas été trouvée !")
		
	# On lance le cooldown de 20 secondes
	var timer = get_tree().create_timer(cooldown_duration)
	timer.timeout.connect(_on_cooldown_finished)

func _on_cooldown_finished() -> void:
	print("Keystone Manastorm: Cooldown terminé, la tempête est prête !")
	is_on_cooldown = false
