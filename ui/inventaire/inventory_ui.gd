class_name InventoryUI
extends CanvasLayer

@export var inventory_component: InventoryComponent 
@export var equipment_component: EquipmentComponent 
@export var stats_component: StatsComponent # <-- NOUVEAU
@export var level_component: LevelComponent # <-- NOUVEAU
@export var slot_scene: PackedScene 

@onready var inv_grid: GridContainer = %inv_grid
@onready var stats_container: VBoxContainer = %StatsContainer # <-- NOUVEAU

var stat_labels: Dictionary = {}
@onready var loot_panel: ColorRect = %LootPanel
@onready var loot_grid: GridContainer = %LootGrid
var current_chest_inventory: InventoryComponent = null

signal inventory_closed

func _ready() -> void:
	visible = false
	if inventory_component != null:
		inventory_component.inventory_changed.connect(update_ui)
		update_ui()
	else:
		push_error("InventoryUI : Il manque le InventoryComponent !")
		
	# Initialisation du panneau de stats
	if level_component == null and owner != null:
		level_component = owner.get_node_or_null("lvl_component") as LevelComponent
		
	if level_component != null:
		level_component.level_up.connect(_on_level_up)
		
	if stats_component != null and stats_container != null:
		stats_component.stat_changed.connect(_on_stat_changed)
		_build_stats_ui()
	else:
		push_warning("InventoryUI : Pas de StatsComponent ou de StatsContainer trouvé.")
		
	# --- NOUVEAU : Bouton de triche pour tuer les monstres ---
	var kill_btn = Button.new()
	kill_btn.text = "KILL ALL"
	kill_btn.custom_minimum_size = Vector2(0, 40)
	kill_btn.add_theme_color_override("font_color", Color.RED)
	kill_btn.pressed.connect(_on_kill_all_pressed)
	if stats_container != null:
		stats_container.add_child(kill_btn)
	else:
		add_child(kill_btn)

func _on_kill_all_pressed() -> void:
	var enemies = get_tree().get_nodes_in_group("Enemie")
	var kill_count = 0
	for e in enemies:
		var health = e.get_node_or_null("HealthComponent")
		if health != null and health.has_method("take_damage"):
			health.take_damage(999999)
			kill_count += 1
	print("Bouton magique utilisé : ", kill_count, " monstres tués !")

func _build_stats_ui() -> void:
	# On supprime les vieux labels si existants
	for child in stats_container.get_children():
		if child is Label:
			child.queue_free()
			
	# Ajout du Niveau en haut de la liste
	if level_component != null:
		var lvl_label = Label.new()
		lvl_label.text = "Level : " + str(level_component.current_level)
		lvl_label.add_theme_color_override("font_color", Color.GOLD) # En doré pour que ça ressorte !
		stats_container.add_child(lvl_label)
		stat_labels["current_level"] = lvl_label
			
	# On crée un label pour chaque stat
	for stat_name in stats_component._stats.keys():
		var label = Label.new()
		label.text = _format_stat(stat_name, stats_component.get_stat_value(stat_name))
		stats_container.add_child(label)
		stat_labels[stat_name] = label

func _on_stat_changed(stat_name: String, new_value: float) -> void:
	if stat_labels.has(stat_name):
		stat_labels[stat_name].text = _format_stat(stat_name, new_value)

func _on_level_up(new_level: int) -> void:
	if stat_labels.has("current_level"):
		stat_labels["current_level"].text = "Level : " + str(new_level)

func _format_stat(stat_name: String, value: float) -> String:
	var clean_name = stat_name.capitalize().replace("_", " ")
	var percent_stats = GameData.PERCENT_STATS
	
	if stat_name in percent_stats:
		var pct = round(value * 100.0)
		return clean_name + " : " + str(pct) + "%"
	else:
		return clean_name + " : " + str(round(value))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		if visible:
			close_inventory()
		else:
			open_inventory()

func open_inventory() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
func close_inventory() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if loot_panel:
		loot_panel.visible = false
	if current_chest_inventory != null:
		if current_chest_inventory.inventory_changed.is_connected(_update_loot_ui):
			current_chest_inventory.inventory_changed.disconnect(_update_loot_ui)
		current_chest_inventory = null
	inventory_closed.emit()

func open_with_chest(chest_inv: InventoryComponent) -> void:
	# Si on ouvrait déjà un autre coffre juste avant (ou en même temps à cause d'une superposition)
	if current_chest_inventory != null and current_chest_inventory != chest_inv:
		if current_chest_inventory.inventory_changed.is_connected(_update_loot_ui):
			current_chest_inventory.inventory_changed.disconnect(_update_loot_ui)
			
	current_chest_inventory = chest_inv
	
	if not current_chest_inventory.inventory_changed.is_connected(_update_loot_ui):
		current_chest_inventory.inventory_changed.connect(_update_loot_ui)
	if loot_panel:
		loot_panel.visible = true
	_update_loot_ui()
	open_inventory()

func update_ui() -> void:
	for child in inv_grid.get_children():
		child.queue_free()
		
	var index = 0
	for slot_data in inventory_component.slots:
		var slot_instance = slot_scene.instantiate() as InventorySlot
		slot_instance.target_inventory = inventory_component
		slot_instance.is_loot_container = false
		inv_grid.add_child(slot_instance)
		
		# Le drag and drop est géré tout seul dans InventorySlot et EquipmentSlot !
		slot_instance.update_slot(slot_data["item"], slot_data["quantity"], index)
		index += 1

func _update_loot_ui() -> void:
	if current_chest_inventory == null or loot_grid == null: return
	
	for child in loot_grid.get_children():
		child.queue_free()
		
	var index = 0
	for slot_data in current_chest_inventory.slots:
		var slot_instance = slot_scene.instantiate() as InventorySlot
		slot_instance.target_inventory = current_chest_inventory
		slot_instance.is_loot_container = true
		loot_grid.add_child(slot_instance)
		
		slot_instance.update_slot(slot_data["item"], slot_data["quantity"], index)
		index += 1
