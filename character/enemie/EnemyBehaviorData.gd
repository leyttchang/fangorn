class_name EnemyBehaviorData
extends Resource

@export_category("Intelligence Artificielle")
@export var attack_range: float = 1.5
# À 0.0 pour les monstres de mêlée, à > 0.0 pour les tireurs fuyards
@export var flee_threshold: float = 0.0 
## Distance max de détection en mode NORMAL (en mètres)
@export var detection_range: float = 25.0
## Distance de perte d'aggro en mode NORMAL (en mètres)
@export var lose_aggro_range: float = 35.0

@export_category("Physique des Mouvements")
@export var acceleration: float = 40.0
@export var friction: float = 35.0
@export var air_friction: float = 10.0
@export var rotation_speed: float = 10.0
