extends CanvasLayer

@export var mob_spawner: SmartSpawner
@export var debug_spawners: Array[Node] = []

@onready var resume_btn: Button = $Panel/VBoxContainer/Button
@onready var options_btn: Button = $Panel/VBoxContainer/Button2
@onready var spawn_btn: Button = $Panel/VBoxContainer/Button3
@onready var quit_btn: Button = $Panel/VBoxContainer/Button4
@onready var debug_btn: Button = $Panel/VBoxContainer/Button5
@onready var create_items_btn: Button = $Panel/VBoxContainer/Button6
@onready var god_mode_btn: Button = $Panel/VBoxContainer/Button7

@export var return_lobby_btn: Button

func _ready() -> void:
	# Très important : le menu de pause doit pouvoir tourner même quand le jeu est en pause
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	resume_btn.pressed.connect(_on_resume_pressed)
	spawn_btn.pressed.connect(_on_spawn_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	debug_btn.pressed.connect(_on_debug_pressed)
	create_items_btn.pressed.connect(_on_create_items_pressed)
	god_mode_btn.pressed.connect(_on_god_mode_pressed)
	
	if return_lobby_btn != null:
		return_lobby_btn.pressed.connect(_on_return_lobby_pressed)
		# Seul le serveur peut décider de ramener tout le monde au lobby
		return_lobby_btn.visible = multiplayer.is_server()
	
	visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause() -> void:
	var new_pause_state = not get_tree().paused
	get_tree().paused = new_pause_state
	visible = new_pause_state
	
	if new_pause_state:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_spawn_pressed() -> void:
	if mob_spawner != null:
		mob_spawner.toggle_pause()
		# Optionnel : changer le texte du bouton pour savoir si c'est en pause ou non
		if mob_spawner.is_paused:
			spawn_btn.text = "Resume spawn"
		else:
			spawn_btn.text = "Pause spawn"
	else:
		print("Aucun spawner n'a été assigné dans l'inspecteur du Pause Menu !")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_return_lobby_pressed() -> void:
	if multiplayer.is_server():
		rpc("rpc_return_to_lobby")

@rpc("authority", "call_local", "reliable")
func rpc_return_to_lobby() -> void:
	# Enlever la pause si on l'avait mise
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://lvl/starting_menu.tscn")

func _on_debug_pressed() -> void:
	if debug_spawners.is_empty():
		print("Aucun debug spawner assigné !")
		return
		
	# On cherche l'état actuel du premier spawner valide pour inverser la tendance
	var is_currently_disabled: bool = true
	for spawner in debug_spawners:
		if spawner != null and "is_disabled" in spawner:
			is_currently_disabled = spawner.is_disabled
			break
			
	# On inverse l'état pour tout le monde
	var new_state = not is_currently_disabled
	for spawner in debug_spawners:
		if spawner != null and "is_disabled" in spawner:
			spawner.is_disabled = new_state
			
	# On met à jour le texte du bouton
	if new_state:
		debug_btn.text = "Enable debugSpawner"
	else:
		debug_btn.text = "Disable debugSpawner"

func _on_create_items_pressed() -> void:
	# Trouver l'inventaire du joueur
	var inv_component: InventoryComponent = null
	if get_tree().current_scene:
		inv_component = get_tree().current_scene.find_child("InventoryComponent", true, false)
		
	if inv_component == null:
		print("Impossible de trouver l'inventaire du joueur !")
		return
		
	var possible_bases: Array[EquipmentItem] = GameData.get_all_bases()
	
	var all_possible_affixes: Array[AffixData] = GameData.get_all_affixes()
	
	for i in range(10):
		var ilvl = randi_range(1, 15) # ilvl au pif entre 1 et 15
		var rarity = _get_random_rarity()
		var base_item = possible_bases.pick_random()
		var new_item = ItemGenerator.generate_equipment(base_item, ilvl, rarity, all_possible_affixes)
		inv_component.add_item(new_item, 1)
		
	print("10 items ont été créés et ajoutés à l'inventaire !")

func _get_random_rarity() -> ItemData.Rarity:
	var weight_common = 25
	var weight_magic = 35
	var weight_rare = 30
	var weight_legendary = 10
	
	var total_weight = weight_common + weight_magic + weight_rare + weight_legendary
	var roll = randi_range(1, total_weight)
	
	if roll <= weight_common: return ItemData.Rarity.COMMON
	roll -= weight_common
	if roll <= weight_magic: return ItemData.Rarity.MAGIC
	roll -= weight_magic
	if roll <= weight_rare: return ItemData.Rarity.RARE
	return ItemData.Rarity.LEGENDARY

func _on_god_mode_pressed() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	# Fallback si le groupe n'est pas bien défini :
	if player == null and get_tree().current_scene:
		player = get_tree().current_scene.find_child("player", true, false)
		if player == null:
			player = get_tree().current_scene.find_child("Player", true, false)
		
	if player == null:
		print("Joueur introuvable pour le God Mode !")
		return
		
	var stats = player.find_child("StatsComponent", true, false)
	if stats:
		stats.add_modifier("max_health", 0, 10000.0, "god_mode")
		stats.add_modifier("max_mana", 0, 10000.0, "god_mode")
		stats.add_modifier("mana_regen", 0, 100.0, "god_mode")
		stats.add_modifier("cd_red", 0, 10000.0, "god_mode")
		
	var health = player.find_child("HealthComponent", true, false)
	if health and health.has_method("heal"):
		health.heal(10000.0)
		
	var mana = player.find_child("ManaComponent", true, false)
	if mana and mana.has_method("restore_mana"):
		mana.restore_mana(10000.0)
		
	var skill_tree = player.find_child("Skill_tree_comp", true, false)
	if skill_tree:
		skill_tree.available_skill_points += 1000
		
	print("God Mode activé : +10000 Vie/Mana, +100 Regen, +1000 Points de compétence !")
