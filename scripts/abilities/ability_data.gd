class_name AbilityData
extends Resource

# --- La categorie pour le calcul des degats et de la vitesse ---
enum AbilityCategory {
	MAGIC,          # Sort pur (Degats fixes + Stats Magiques, utilise le casting_speed)
	WEAPON_ATTACK   # Attaque martiale (Degats de l'arme + Stats Physiques, utilise l'attack_speed)
}

# La liste complete de la facon dont le sort vise
enum TargetMode {
	INSTANT,        # Centre sur le joueur (Coup d'epee, Dash, Cri de guerre, Tourbillon)
	PROJECTILE,     # Part de la camera et avance (Boule de feu, Onde de choc)
	HITSCAN,        # Tir instantane via le RayCast (Laser)
	GROUND_TARGET,  # Necessite de viser le sol avec un indicateur (Meteore, Ice Crash)
	SUMMON,         # Invocation au sol
	COMPLEX_ATTACK  # Instancie des le debut, pilote par l'AnimationPlayer (Call Method Tracks)
}

@export_group("Informations Generales")
@export var ability_name: String = "Nouvelle Competence"
@export_multiline var description: String = "Description de la competence..."
@export var icon: Texture2D
@export var category: AbilityCategory = AbilityCategory.MAGIC
@export var cooldown: float = 1.0
@export var mana_cost: float = 0.0
@export var max_range: float = 50.0 
@export var cast_time: float = 0.0 # 0.0 = Lancement instantane !

@export_group("Comportement & Tags (Global)")
enum SkillScalingType { SPELL, ATTACK }
@export var skill_type: SkillScalingType = SkillScalingType.SPELL

@export_group("Degats & Arme")
# 1.0 = Vitesse de base. 1.2 = Se charge 20% plus vite que la vitesse d'attaque normale de l'arme
@export var weapon_speed_multiplier: float = 1.0 

@export_group("Mecanique de Lancement")
@export var target_mode: TargetMode = TargetMode.INSTANT

@export_group("Animation")
# Le nom de l'animation a jouer sur le joueur au moment du lancement (ex: "attack_heavy_slam")
@export var anim_name: String = "" 

@export_group("Stats UI & Tooltip Automatique")
@export var custom_tooltip: SpellTooltipData

@export_group("Scenes (Les Acteurs)")
# L'effet visuel joue pendant le temps d'incantation (optionnel)
@export var cast_vfx_scene: PackedScene
# L'indicateur visuel au sol (Optionnel : utile surtout pour GROUND_TARGET et SUMMON)
@export var indicator_scene: PackedScene 
# La scene qui sera instanciee et qui contient le code de la competence (la logique des degats)
@export var ability_scene: PackedScene
