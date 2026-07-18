extends CanvasLayer

@export var player_health: HealthComponent
@onready var score_label: Label = $Label

var current_score: int = 0
var time_passed: float = 0.0
var is_player_dead: bool = false

func _ready() -> void:
	# 1. Le Score s'inscrit dans un groupe pour que les monstres le trouvent
	add_to_group("ScoreManager")
	
	score_label.text = "Score : 0"
	
	if player_health != null:
		player_health.died.connect(_on_player_died)
	else:
		push_warning("Attention : Le HealthComponent du joueur n'est pas assigné dans le ScoreManager !")

func _process(delta: float) -> void:
	if is_player_dead:
		return
		
	time_passed += delta
	
	# CHANGEMENT : 1 point toutes les 20 secondes
	if time_passed >= 20.0:
		current_score += 1
		time_passed -= 20.0 
		_update_score_display()

# ==========================================================
# NOUVEAU : Fonction appelée par les monstres au moment de leur mort
# ==========================================================
func add_kill_point() -> void:
	if is_player_dead:
		return
		
	current_score += 1
	_update_score_display()

# Petite fonction utilitaire pour éviter de répéter du code
func _update_score_display() -> void:
	score_label.text = "Score : " + str(current_score)

func _on_player_died() -> void:
	is_player_dead = true
	print("=========================================")
	print(" 💀 FIN DE PARTIE ! Le joueur est mort.")
	print(" 🏆 Score final : ", current_score, " points")
	print("=========================================")
