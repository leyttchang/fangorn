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
@onready var loot_panel: Panel = %LootPanel
@onready var loot_grid: GridContainer = %LootGrid
@onready var loot_all_btn: Button = %LootPanel.get_node_or_null("HBoxContainer/loot_all")
var current_chest_inventory: InventoryComponent = null

signal inventory_closed

func _ready() -> void:
	# Suppression du fond gris moche des tooltips par défaut de Godot
	var main_panel = $MainPanel
	if main_panel != null:
		var clean_theme = main_panel.theme
		if clean_theme == null:
			clean_theme = Theme.new()
		var empty_style = StyleBoxEmpty.new()
		clean_theme.set_stylebox("panel", "TooltipPanel", empty_style)
		main_panel.theme = clean_theme

	visible = false
	if inventory_component != null:
		inventory_component.inventory_changed.connect(update_ui)
		update_ui()
	else:
		push_error("InventoryUI : Il manque le InventoryComponent !")
		
	if loot_all_btn != null:
		loot_all_btn.pressed.connect(_on_loot_all_pressed)
		
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



var stat_categories = {
	"Offense": ["physical_damage", "magic_damage", "fire_damage", "ice_damage", "lightning_damage", "attack_speed", "casting_speed", "area_of_effect", "knockback_power", "flat_physical_damage", "flat_magic_damage", "flat_fire_damage", "flat_ice_damage", "flat_lightning_damage"],
	"Defense": ["max_health", "armor", "physical_resistance", "fire_resistance", "ice_resistance", "lightning_resistance", "knockback_resistance"],
	"Misc": ["max_mana", "mana_regen", "movement_speed", "cd_red", "luck"]
}

@onready var offense_vbox: VBoxContainer = get_node_or_null("%OffenseVBox")
@onready var defense_vbox: VBoxContainer = get_node_or_null("%DefenseVBox")
@onready var misc_vbox: VBoxContainer = get_node_or_null("%MiscVBox")
@onready var level_label: Label = get_node_or_null("%LevelLabel")

func _build_stats_ui() -> void:
	# Nettoyage des anciennes stats
	if offense_vbox:
		for c in offense_vbox.get_children(): c.queue_free()
	if defense_vbox:
		for c in defense_vbox.get_children(): c.queue_free()
	if misc_vbox:
		for c in misc_vbox.get_children(): c.queue_free()
		
	# Mise à jour du niveau (si le label existe dans la scène)
	if level_label != null and level_component != null:
		level_label.text = "Level : " + str(level_component.current_level)
		stat_labels["current_level"] = level_label

	var stats_added = []

	# Connexion automatique des boutons pour déplier/replier (s'ils existent)
	var off_btn = get_node_or_null("%OffenseBtn")
	if off_btn and offense_vbox and not off_btn.pressed.is_connected(offense_vbox.set_visible):
		off_btn.pressed.connect(func(): offense_vbox.visible = not offense_vbox.visible)
		
	var def_btn = get_node_or_null("%DefenseBtn")
	if def_btn and defense_vbox and not def_btn.pressed.is_connected(defense_vbox.set_visible):
		def_btn.pressed.connect(func(): defense_vbox.visible = not defense_vbox.visible)
		
	var misc_btn = get_node_or_null("%MiscBtn")
	if misc_btn and misc_vbox and not misc_btn.pressed.is_connected(misc_vbox.set_visible):
		misc_btn.pressed.connect(func(): misc_vbox.visible = not misc_vbox.visible)

	# Remplissage par catégorie
	for category_name in stat_categories.keys():
		var target_vbox: VBoxContainer = null
		if category_name == "Offense": target_vbox = offense_vbox
		elif category_name == "Defense": target_vbox = defense_vbox
		elif category_name == "Misc": target_vbox = misc_vbox
		
		if target_vbox == null: continue
		
		for stat_name in stat_categories[category_name]:
			if stats_component._stats.has(stat_name):
				stats_added.append(stat_name)
				var label = Label.new()
				label.text = _format_stat(stat_name, stats_component.get_stat_value(stat_name))
				target_vbox.add_child(label)
				stat_labels[stat_name] = label

	# Les stats restantes (non classées) vont dans Misc par défaut (ou StatsContainer si Misc n'existe pas)
	var fallback_vbox = misc_vbox if misc_vbox else stats_container
	for stat_name in stats_component._stats.keys():
		if not stats_added.has(stat_name):
			var label = Label.new()
			label.text = _format_stat(stat_name, stats_component.get_stat_value(stat_name))
			if fallback_vbox: fallback_vbox.add_child(label)
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
		var pct = int(round(value * 100.0))
		return clean_name + " : " + str(pct) + "%"
	else:
		return clean_name + " : " + str(int(round(value)))


func open_inventory() -> void:
	visible = true
	
func close_inventory() -> void:
	visible = false
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

func _on_loot_all_pressed() -> void:
	if current_chest_inventory == null or inventory_component == null: return
	
	# On boucle à l'envers ou on gère simplement les slots
	for i in range(current_chest_inventory.slots.size()):
		var slot = current_chest_inventory.slots[i]
		if slot["item"] != null:
			var item = slot["item"]
			var quantity = slot["quantity"]
			
			# Tente d'ajouter au joueur
			var remaining = inventory_component.add_item(item, quantity)
			var taken = quantity - remaining
			
			if taken > 0:
				# Enlève la quantité prise du coffre
				current_chest_inventory.remove_item_at_slot(i, taken)


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
