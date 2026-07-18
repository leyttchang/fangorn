extends CanvasLayer

# On exporte la variable pour pouvoir glisser le HealthComponent du joueur (ou du monstre) dans l'inspecteur
@export var health_component: HealthComponent

# On récupère ton TextureProgressBar vu dans image_0c87c2.png
@onready var progress_bar: TextureProgressBar = $TextureProgressBar

func _ready() -> void:
	if health_component != null:
		# 1. On initialise la barre au lancement du jeu avec les bonnes valeurs
		var max_hp = health_component.stats_component.get_stat_value("max_health")
		progress_bar.max_value = max_hp
		progress_bar.value = health_component.current_health
		
		# 2. On connecte le signal de ton HealthComponent à notre fonction de mise à jour
		health_component.health_changed.connect(_on_health_changed)
	else:
		push_warning("Attention : Aucun HealthComponent n'est assigné à la barre de vie " + name)


# Fonction appelée automatiquement à chaque fois que le signal 'health_changed' est émis
func _on_health_changed(current_health: float, max_health: float) -> void:
	# On met à jour le maximum au cas où le perso gagne un niveau ou un bonus de vie max
	progress_bar.max_value = max_health
	
	# AU CHOIX :
	
	# Option A : Changement instantané (classique)
	# progress_bar.value = current_health 
	
	# Option B : Changement fluide avec une animation (beaucoup plus satisfaisant)
	var tween = get_tree().create_tween()
	# La barre va mettre 0.2 secondes à rejoindre sa nouvelle valeur
	tween.tween_property(progress_bar, "value", current_health, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
