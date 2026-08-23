class_name StatusEffectData
extends Resource

@export var effect_id: String = "unique_effect_name"
@export var is_buff: bool = false
@export var icon: Texture2D

@export_group("Modificateurs de Stats")
@export var stat_modifiers: Array[StatModifierData] = []

@export_group("Degats sur la duree (DoT)")
@export var tick_damage: float = 0.0
@export var tick_interval: float = 1.0

@export_group("Visuels")
@export var enemie_effect: PackedScene
@export var player_effect: PackedScene
@export var overlay_material: Material # Applique un Shader/Material sur le modele 3D du monstre (Glace, Feu, etc.)

# Fonction virtuelle pour les effets complexes (Chill -> Freeze, etc.)
func on_apply(target: Node, component: Node, is_refresh: bool) -> void:
	pass

func on_remove(target: Node, component: Node) -> void:
	pass
