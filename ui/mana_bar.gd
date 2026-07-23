class_name ManaBarUI
extends CanvasLayer

@export var mana_component: Node 

@onready var progress_bar: TextureProgressBar = $TextureProgressBar

func _ready() -> void:
	if mana_component == null:
		var player = get_tree().get_first_node_in_group("Player")
		if player != null and not player.has_node("lvl_component") and player.owner != null:
			player = player.owner
			
		if player == null:
			player = owner
			
		if player != null:
			mana_component = player.get_node_or_null("ManaComponent")
			if mana_component == null:
				mana_component = player.get_node_or_null("mana_component")
			
	if mana_component != null:
		mana_component.mana_changed.connect(_on_mana_changed)
	else:
		push_error("ManaBarUI : Impossible de trouver le ManaComponent du joueur !")

func _on_mana_changed(current_mana: float, max_mana: float) -> void:
	progress_bar.max_value = max_mana
	progress_bar.value = current_mana
