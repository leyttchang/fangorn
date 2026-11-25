@tool
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
	COMPLEX_ATTACK, # Instancie des le debut, pilote par l'AnimationPlayer (Call Method Tracks)
	CHANNEL         # Sort canalise en maintenant Clic Gauche apres selection (Racines, Arc electrique...)
}

@export_group("Informations Generales")
@export var ability_name: String = "New Skill"
@export_multiline var description: String = "Skill description..."
@export var icon: Texture2D
@export var category: AbilityCategory = AbilityCategory.MAGIC
@export var cooldown: float = 1.0
@export_range(1, 10, 1) var max_charges: int = 1
@export var mana_cost: float = 0.0
@export var max_range: float = 50.0
@export var cast_time: float = 0.0 # 0.0 = Lancement instantane !

@export_group("Spell Tier, Leveling & Evolutions")
@export var spell_id: String = ""
@export_range(1, 3, 1) var tier: int = 1
@export_placeholder("fire, arcane, ice, lightning, hybrid") var element: String = ""
@export_range(1, 10, 1) var max_spell_level: int = 5
@export var base_xp_to_level: int = 80
@export var xp_growth_per_level: float = 1.35
@export var damage_growth_per_level: float = 0.14
@export var cooldown_reduction_per_level: float = 0.03
@export var is_rare_drop: bool = false
@export var is_evolution_only: bool = false
@export var evolutions: Array[AbilityData] = []
@export var unlock_requirements: Array[SpellRequirementData] = []

@export_group("Channeling (TargetMode.CHANNEL)")
@export var channel_mana_per_sec: float = 12.0
@export var channel_tick_interval: float = 0.22
@export var channel_max_duration: float = 0.0 # 0.0 = Illimite tant que le joueur maintient et a du mana

@export_group("Comportement & Tags (Global)")
enum SkillScalingType { SPELL, ATTACK }
@export var skill_type: SkillScalingType = SkillScalingType.SPELL

@export_group("Degats & Arme")
# 1.0 = Vitesse de base. 1.2 = Se charge 20% plus vite que la vitesse d'attaque normale de l'arme
@export var weapon_speed_multiplier: float = 1.0
## Si vrai sur une WEAPON_ATTACK, conserve `cast_time` (ex: 0.5s) comme temps de préparation de base (divisé par l'attack_speed)
@export var use_fixed_cast_time: bool = false
## Exposant de réduction du cooldown par la vitesse d'attaque (0.0 = aucun effet, > 0.0 = l'attack_speed réduit le CD)
@export var cooldown_attack_speed_scaling: float = 0.0

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


func get_effective_id() -> String:
	if not spell_id.strip_edges().is_empty():
		return spell_id.strip_edges().to_lower()
	return ability_name.strip_edges().to_lower().replace(" ", "_").replace("'", "")


func get_xp_for_next_level(current_lvl: int) -> int:
	var clamped_lvl: int = maxi(1, current_lvl)
	var base_req: float = maxf(10.0, float(base_xp_to_level))
	var growth: float = maxf(1.05, xp_growth_per_level)
	return maxi(10, int(roundf(base_req * pow(growth, float(clamped_lvl - 1)))))


func get_level_power_multiplier(current_lvl: int) -> float:
	var extra_lvls: int = maxi(0, current_lvl - 1)
	return maxf(0.1, 1.0 + float(extra_lvls) * damage_growth_per_level)


func get_level_cooldown_multiplier(current_lvl: int) -> float:
	var extra_lvls: int = maxi(0, current_lvl - 1)
	return clampf(1.0 - float(extra_lvls) * cooldown_reduction_per_level, 0.40, 1.0)
