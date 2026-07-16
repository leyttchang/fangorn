class_name AbilityData
extends Resource

# --- La catégorie pour le calcul des dégâts et de la vitesse ---
enum AbilityCategory {
	MAGIC,          # Sort pur (Dégâts fixes + Stats Magiques, utilise le casting_speed)
	WEAPON_ATTACK   # Attaque martiale (Dégâts de l'arme + Stats Physiques, utilise l'attack_speed)
}

# La liste complète de la façon dont le sort vise
enum TargetMode {
	INSTANT,        # Centré sur le joueur (Coup d'épée, Dash, Cri de guerre, Tourbillon)
	PROJECTILE,     # Part de la caméra et avance (Boule de feu, Onde de choc)
	HITSCAN,        # Tir instantané via le RayCast (Laser)
	GROUND_TARGET,  # Nécessite de viser le sol avec un indicateur (Météore, Ice Crash)
	SUMMON          # Invocation au sol
}

@export_group("Informations Générales")
@export var ability_name: String = "Nouvelle Compétence"
@export var icon: Texture2D
@export var category: AbilityCategory = AbilityCategory.MAGIC
@export var cooldown: float = 1.0
@export var mana_cost: float = 0.0
@export var max_range: float = 50.0 
@export var cast_time: float = 0.0 # 0.0 = Lancement instantané !

@export_group("Dégâts & Arme")
# 0.0 = Sort purement magique (n'utilise pas l'arme)
# 1.5 = Inflige 150% des dégâts de l'arme équipée
@export var weapon_damage_multiplier: float = 0.0 
# 1.0 = Vitesse de base. 1.2 = Se charge 20% plus vite que la vitesse d'attaque normale de l'arme
@export var weapon_speed_multiplier: float = 1.0 

@export_group("Mécanique de Lancement")
@export var target_mode: TargetMode = TargetMode.INSTANT

@export_group("Animation")
# Le nom de l'animation à jouer sur le joueur au moment du lancement (ex: "attack_heavy_slam")
@export var anim_name: String = "" 

@export_group("Scènes (Les Acteurs)")
# L'indicateur visuel au sol (Optionnel : utile surtout pour GROUND_TARGET et SUMMON)
@export var indicator_scene: PackedScene 
# La scène qui sera instanciée et qui contient le code de la compétence (la logique des dégâts)
@export var ability_scene: PackedScene
