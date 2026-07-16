class_name CastingBarUI
extends CanvasLayer

# On glissera le composant du joueur ici
@export var skill_bar: SkillBarComponent

# Le chemin exact vers ta barre de progression d'après ton image
@onready var progress_bar: TextureProgressBar = $Control/Spell_casting_completion

func _ready() -> void:
	# On cache toute la barre au démarrage (elle ne s'affiche que quand on cast)
	visible = false
	
	if skill_bar == null:
		push_error("CastingBar : Le SkillBarComponent n'est pas assigné dans l'inspecteur.")
		return
		
	# On connecte l'interface aux signaux du composant
	skill_bar.cast_started.connect(_on_cast_started)
	skill_bar.cast_updated.connect(_on_cast_updated)
	skill_bar.cast_canceled.connect(_on_cast_ended)
	
	# On connectera aussi le succès (on va l'ajouter juste après !)
	if skill_bar.has_signal("cast_finished"):
		skill_bar.cast_finished.connect(_on_cast_ended)

# Quand on appuie sur la touche du sort
func _on_cast_started(_ability_name: String, max_time: float) -> void:
	visible = true
	progress_bar.max_value = max_time
	progress_bar.value = 0.0
	progress_bar.tint_progress = Color(1.0, 1.0, 1.0) # Couleur normale

# À chaque frame pendant qu'on maintient la touche
func _on_cast_updated(current_time: float, max_time: float) -> void:
	progress_bar.value = current_time
	
	# Bonus visuel : Quand la barre est pleine, on la teinte en Vert pour dire "Prêt à tirer !"
	if current_time >= max_time:
		progress_bar.tint_progress = Color(0.2, 1.0, 0.2) 

# Quand on relâche trop tôt, qu'on clic droit, ou qu'on tire avec succès
func _on_cast_ended() -> void:
	visible = false
