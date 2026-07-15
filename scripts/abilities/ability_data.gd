class_name AbilityData
extends Resource

# La liste complète de tous les types de lancements possibles
enum TargetMode {
	INSTANT,        # Dash, Buff de statistiques, Cri de guerre (Centré sur le joueur)
	PROJECTILE,     # Boule de feu, Flèche (Part du centre de la caméra et avance)
	HITSCAN,        # Laser, Sniper (Tir instantané via le RayCast)
	GROUND_TARGET,  # Météore, Mur de flammes (Nécessite un clic sur le sol avec indicateur)
	MELEE_OVERRIDE, # Frappe magique (Force la MainDroite à attaquer avec des bonus)
	SUMMON          # Invocation (Apparition d'un allié, totem ou objet autonome au sol)
}

@export_group("Informations Générales")
@export var ability_name: String = "Nouvelle Compétence"
@export var icon: Texture2D
@export var cooldown: float = 1.0
@export var mana_cost: float = 0.0
@export var max_range: float = 50.0 

@export_group("Mécanique de Lancement")
@export var target_mode: TargetMode = TargetMode.INSTANT

@export_group("Scènes (Les Acteurs)")
# L'indicateur visuel au sol (Optionnel : utile surtout pour GROUND_TARGET et SUMMON)
@export var indicator_scene: PackedScene 
# La scène qui sera instanciée et qui contient le code de la compétence
@export var ability_scene: PackedScene
