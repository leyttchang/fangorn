import re

with open('Y:/Fangorn/fangorn/scripts/abilities/thunder_aspect/thunder_aspect.gd', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''extends Node3D

var mon_lanceur: Node3D = null

# Tu peux glisser ton res://scripts/status_effects/shock/shock_shader.tres ici dans l'inspecteur !
@export var weapon_material: Material

# Tu peux glisser ton buff de stats (StatusEffectData) ici !
@export var buff_data: StatusEffectData
# Optionnel: on peut aussi utiliser la durée de l'animation pour la durée du buff
@export var buff_duration: float = 5.0

func execute(caster: Node3D, target_data: Dictionary) -> void:
\tmon_lanceur = caster
\t
\t# 1. On applique les vraies stats (Le buff de dégâts/vitesse)
\tif buff_data != null:
\t\tvar status_comp = caster.get_node_or_null("status_effect_componant")
\t\tif status_comp != null:
\t\t\tstatus_comp.apply_effect(buff_data, buff_duration)
\t
\t# 2. On allume l'arme visuellement !
\t_set_weapon_material(weapon_material)
\t
\t# 3. On lance l'animation qui gère le chronomètre (le VFX de l'arme)
\tvar anim_player = get_node_or_null("AnimationPlayer")
\tif anim_player:
\t\tanim_player.play("buff_duration")
\telse:
\t\t# Sécurité si tu oublies l'AnimationPlayer
\t\tawait get_tree().create_timer(buff_duration).timeout
\t\tqueue_free()'''

# Replace the beginning of the file up to func _exit_tree
content = re.sub(r'extends Node3D.*?func _exit_tree', replacement + '\n\nfunc _exit_tree', content, flags=re.DOTALL)

with open('Y:/Fangorn/fangorn/scripts/abilities/thunder_aspect/thunder_aspect.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Added buff export")
