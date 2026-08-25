content = '''extends Node3D

var mon_lanceur: Node3D = null

# Les variables exportées pour l'inspecteur
@export var buff_data: StatusEffectData
@export var buff_duration: float = 5.0
@export var buff_radius: float = 15.0 # Le rayon d'action du buff de zone
@export var weapon_material: Material # Optionnel : un shader pour l'arme du lanceur

func execute(caster: Node3D, target_data: Dictionary) -> void:
\tmon_lanceur = caster
\t
\t# 1. On applique les vraies stats à TOUS les joueurs dans la zone
\tif buff_data != null:
\t\tvar all_players = get_tree().get_nodes_in_group("Player")
\t\tfor p in all_players:
\t\t\t# Vérification de la distance (Sphère d'effet)
\t\t\tif p.global_position.distance_to(caster.global_position) <= buff_radius:
\t\t\t\tvar status_comp = p.get_node_or_null("status_effect_componant")
\t\t\t\tif status_comp != null:
\t\t\t\t\tstatus_comp.apply_effect(buff_data, buff_duration)
\t\t\t\t\t
\t\t\t\t\t# Si tu as une animation ou des particules à créer sur CHAQUE allié, tu pourrais le faire ici !
\t
\t# 2. On allume l'arme du lanceur visuellement ! (Optionnel)
\t_set_weapon_material(weapon_material)
\t
\t# 3. On lance l'animation qui gère le chronomètre (le VFX global)
\tvar anim_player = get_node_or_null("AnimationPlayer")
\tif anim_player:
\t\tanim_player.play("buff_duration")
\telse:
\t\t# Sécurité si tu oublies l'AnimationPlayer
\t\tawait get_tree().create_timer(buff_duration).timeout
\t\tqueue_free()

func _exit_tree() -> void:
\t# Quand l'animation se termine, on nettoie l'arme du lanceur
\t_set_weapon_material(null)

func _set_weapon_material(mat: Material) -> void:
\tif mon_lanceur == null or mat == null: return
\t
\tvar main_droite = mon_lanceur.get_node_or_null("Camera3D/MainDroite")
\tif main_droite:
\t\tvar meshes = main_droite.find_children("*", "MeshInstance3D", true, false)
\t\tfor mesh in meshes:
\t\t\tmesh.material_overlay = mat
'''

with open('Y:/Fangorn/fangorn/scripts/abilities/Warcry/warcry.gd', 'w', encoding='utf-8') as f:
    f.write(content)
