class_name InventoryUI
extends CanvasLayer

@export var inventory_component: InventoryComponent 
@export var equipment_component: EquipmentComponent 
@export var stats_component: StatsComponent # <-- NOUVEAU
@export var slot_scene: PackedScene 

@onready var inv_grid: GridContainer = %inv_grid
@onready var stats_container: VBoxContainer = %StatsContainer # <-- NOUVEAU

var stat_labels: Dictionary = {}

func _ready() -> void:
	visible = false
	if inventory_component != null:
		inventory_component.inventory_changed.connect(update_ui)
		update_ui()
	else:
		push_error("InventoryUI : Il manque le InventoryComponent !")
		
	# Initialisation du panneau de stats
	if stats_component != null and stats_container != null:
		stats_component.stat_changed.connect(_on_stat_changed)
		_build_stats_ui()
	else:
		push_warning("InventoryUI : Pas de StatsComponent ou de StatsContainer trouvé.")

func _build_stats_ui() -> void:
	# On supprime les vieux labels si existants
	for child in stats_container.get_children():
		if child is Label:
			child.queue_free()
			
	# On crée un label pour chaque stat
	for stat_name in stats_component._stats.keys():
		var label = Label.new()
		label.text = _format_stat(stat_name, stats_component.get_stat_value(stat_name))
		stats_container.add_child(label)
		stat_labels[stat_name] = label

func _on_stat_changed(stat_name: String, new_value: float) -> void:
	if stat_labels.has(stat_name):
		stat_labels[stat_name].text = _format_stat(stat_name, new_value)

func _format_stat(stat_name: String, value: float) -> String:
	var clean_name = stat_name.capitalize().replace("_", " ")
	return clean_name + ": " + str(snapped(value, 0.1))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		visible = not visible
		if visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func update_ui() -> void:
	for child in inv_grid.get_children():
		child.queue_free()
		
	var index = 0
	for slot_data in inventory_component.slots:
		var slot_instance = slot_scene.instantiate() as InventorySlot
		inv_grid.add_child(slot_instance)
		
		# Le drag and drop est géré tout seul dans InventorySlot et EquipmentSlot !
		slot_instance.update_slot(slot_data["item"], slot_data["quantity"], index)
		index += 1
