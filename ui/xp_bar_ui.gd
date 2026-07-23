class_name XPBarUI
extends CanvasLayer

@export var level_component: LevelComponent

@onready var progress_bar: ProgressBar = $ProgressBar

func _ready() -> void:
	# Tente de trouver le level_component si on ne l'a pas mis dans l'inspecteur
	if level_component == null:
		# 1. On cherche par groupe
		var player = get_tree().get_first_node_in_group("Player")
		
		# 2. Si le joueur n'est pas encore dans le groupe (car _ready se lance de bas en haut), on prend le parent/owner
		if player == null:
			player = owner
			
		if player != null:
			level_component = player.get_node_or_null("lvl_component") as LevelComponent
			
	if level_component != null:
		# On écoute les signaux du composant
		level_component.xp_changed.connect(_on_xp_changed)
		level_component.level_up.connect(_on_level_up)
		
		# Affichage initial
		_update_ui(level_component.current_xp, level_component.xp_to_next_level, level_component.current_level)
	else:
		push_warning("XPBarUI : LevelComponent introuvable ! Pensez à l'assigner dans l'inspecteur.")

func _on_xp_changed(current_xp: int, xp_to_next: int) -> void:
	_update_ui(current_xp, xp_to_next, level_component.current_level)

func _on_level_up(new_level: int) -> void:
	_update_ui(level_component.current_xp, level_component.xp_to_next_level, new_level)

func _update_ui(current_xp: int, xp_to_next: int, _level: int) -> void:
	if progress_bar:
		progress_bar.max_value = xp_to_next
		progress_bar.value = current_xp
