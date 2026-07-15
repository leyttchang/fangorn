class_name HealthComponent
extends Node

# --- SIGNAUX ---
signal health_changed(current_health: float, max_health: float)
signal died
signal damage_taken(amount: float)

# --- DÉPENDANCES ---
@export var stats_component: StatsComponent

# --- NOUVEAUTÉS ARMURE ---
# La courbe de réduction qu'on va glisser dans l'inspecteur
@export var armor_curve: Curve
# La valeur d'armure maximale prévue par ton graphique (l'axe X = 1.0)
@export var max_expected_armor: float = 100.0

var current_health: float

func _ready() -> void:
	if stats_component == null:
		push_error("HealthComponent sur " + get_parent().name + " : StatsComponent manquant !")
		return
		
	if armor_curve == null:
		push_warning("HealthComponent sur " + get_parent().name + " : Pas de armor_curve assignée ! L'armure ne fonctionnera pas.")
		
	# Au début du jeu, le personnage a toute sa vie
	current_health = stats_component.get_stat_value("max_health")

# Fonction appelée quand une arme ou un sort touche ce personnage
func take_damage(raw_damage: float) -> void:
	if current_health <= 0:
		return
		
	# 1. On demande l'armure actuelle au StatsComponent
	var armor = stats_component.get_stat_value("armor")
	armor = max(armor, 0.0) # On empêche d'avoir une armure négative
	
	# 2. On calcule le pourcentage de réduction grâce à la courbe
	var reduction_percent: float = 0.0
	
	if armor_curve != null:
		# On calcule notre position sur l'axe horizontal du graphique (entre 0.0 et 1.0)
		var armor_position_on_x = armor / max_expected_armor
		
		# On s'assure de ne pas dépasser le bout du graphique
		armor_position_on_x = min(armor_position_on_x, 1.0)
		
		# On demande à la courbe de nous donner la valeur verticale (Y) correspondante
		reduction_percent = armor_curve.sample(armor_position_on_x)
	
	# 3. On calcule les dégâts finaux (Dégâts purs multipliés par ce qu'il reste après réduction)
	var final_damage = raw_damage * (1.0 - reduction_percent)
	
	# On garde ta sécurité : une attaque réussie fait toujours au moins 1 de dégât
	final_damage = max(0.1, final_damage)
	
	# 4. On applique les dégâts
	current_health -= final_damage
	damage_taken.emit(final_damage)
	
	# On s'assure que la vie ne descend pas en dessous de zéro
	current_health = max(current_health, 0.0)
	
	# 5. On prévient le reste du jeu que la vie a changé
	var max_hp = stats_component.get_stat_value("max_health")
	health_changed.emit(current_health, max_hp)
	
	# 6. On vérifie si le personnage est mort
	if current_health == 0:
		died.emit()
