import re

content = '''extends Node3D

var mon_lanceur: Node3D = null

# Tu peux glisser ton res://scripts/status_effects/shock/shock_shader.tres ici dans l'inspecteur !
@export var weapon_material: Material

func execute(caster: Node3D, target_data: Dictionary) -> void:
\tmon_lanceur = caster
\t
\t# 1. On allume l'arme !
\t_set_weapon_material(weapon_material)
\t
\t# 2. On lance l'animation qui gère le chronomètre
\tvar anim_player = get_node_or_null("AnimationPlayer")
\tif anim_player:
\t\tanim_player.play("buff_duration")
\telse:
\t\t# Sécurité si tu oublies l'AnimationPlayer
\t\tawait get_tree().create_timer(5.0).timeout
\t\tqueue_free()

func _exit_tree() -> void:
\t# 3. Quand l'animation se termine (et détruit la scène avec queue_free), on nettoie l'arme
\t_set_weapon_material(null)

func _set_weapon_material(mat: Material) -> void:
\tif mon_lanceur == null: return
\t
\t# On trouve la main droite
\tvar main_droite = mon_lanceur.get_node_or_null("Camera3D/MainDroite")
\tif main_droite:
\t\t# On cherche le mesh (le modèle 3D) de l'arme
\t\tvar meshes = main_droite.find_children("*", "MeshInstance3D", true, false)
\t\tfor mesh in meshes:
\t\t\tmesh.material_overlay = mat
'''

with open('Y:/Fangorn/fangorn/scripts/abilities/thunder_aspect/thunder_aspect.gd', 'w', encoding='utf-8') as f:
    f.write(content)
