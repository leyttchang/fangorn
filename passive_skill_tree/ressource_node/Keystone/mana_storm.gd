extends Node

var player: CharacterBody3D
var mana_comp: ManaComponent

# --- CHEMIN DE TA SCÈNE ---
# Modifie ce chemin pour pointer vers l'endroit exact où tu as sauvegardé ta scène mana_storm.tscn
var storm_scene_path: String = "res://passive_skill_tree/ressource_node/Keystone/ks_scene/mana_storm.tscn"

var is_on_cooldown: bool = false
var cooldown_duration: float = 20.0
var _active_storms: Array[Node] = []
var _cooldown_timer: SceneTreeTimer = null

func _ready() -> void:
	# On retrouve le joueur (la racine)
	player = get_parent().get_parent() as CharacterBody3D
	if player == null:
		return

	mana_comp = player.get_node_or_null("mana_component") as ManaComponent
	if mana_comp == null:
		mana_comp = player.get_node_or_null("ManaComponent") as ManaComponent

	if mana_comp != null:
		mana_comp.mana_changed.connect(_on_mana_changed)

func _on_mana_changed(current_mana: float, max_mana: float) -> void:
	if is_on_cooldown or max_mana <= 0.0:
		return

	var mana_percent: float = (current_mana / max_mana) * 100.0

	# Si le mana descend en dessous de 25%
	if mana_percent < 25.0:
		_trigger_mana_storm()

func _trigger_mana_storm() -> void:
	print("Tempête de Mana déclenchée !")
	is_on_cooldown = true

	# Nettoyer les références vers d'anciennes tempêtes déjà détruites
	for i: int in range(_active_storms.size() - 1, -1, -1):
		if not is_instance_valid(_active_storms[i]):
			_active_storms.remove_at(i)

	# On vérifie que ta scène existe bien
	if ResourceLoader.exists(storm_scene_path):
		var storm_scene: PackedScene = load(storm_scene_path) as PackedScene
		if storm_scene != null and player != null:
			var storm: Node = storm_scene.instantiate()

			# Attaché en tant qu'enfant direct du joueur pour le suivre
			player.add_child(storm)
			_active_storms.append(storm)
	else:
		push_error("Keystone Manastorm: La scène " + storm_scene_path + " n'a pas été trouvée !")

	# On lance le cooldown de 20 secondes
	_cooldown_timer = get_tree().create_timer(cooldown_duration)
	_cooldown_timer.timeout.connect(_on_cooldown_finished)

func _on_cooldown_finished() -> void:
	print("Keystone Manastorm: Cooldown terminé, la tempête est prête !")
	is_on_cooldown = false
	_cooldown_timer = null

func _exit_tree() -> void:
	if mana_comp != null and mana_comp.mana_changed.is_connected(_on_mana_changed):
		mana_comp.mana_changed.disconnect(_on_mana_changed)

	if _cooldown_timer != null and _cooldown_timer.timeout.is_connected(_on_cooldown_finished):
		_cooldown_timer.timeout.disconnect(_on_cooldown_finished)
	_cooldown_timer = null

	for storm: Node in _active_storms:
		if is_instance_valid(storm):
			if storm.get_parent() != null:
				storm.get_parent().remove_child(storm)
			storm.queue_free()
	_active_storms.clear()
	is_on_cooldown = false

