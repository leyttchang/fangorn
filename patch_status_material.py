import os

path_data = 'Y:/Fangorn/fangorn/scripts/status_effects/status_effect_data.gd'
with open(path_data, 'r', encoding='utf-8') as f:
    content_data = f.read()

content_data = content_data.replace('@export var player_effect: PackedScene', '@export var player_effect: PackedScene\n@export var overlay_material: Material # Applique un Shader/Material sur le modele 3D du monstre (Glace, Feu, etc.)')

with open(path_data, 'w', encoding='utf-8') as f:
    f.write(content_data)


path_comp = 'Y:/Fangorn/fangorn/components/status_effect_componant.gd'
with open(path_comp, 'r', encoding='utf-8') as f:
    content_comp = f.read()

old_apply = '''\tif visual_scene != null:
\t\tvar vfx = visual_scene.instantiate()
\t\tnew_effect.visual_instance = vfx
\t\tadd_child(vfx)'''

new_apply = '''\tif visual_scene != null:
\t\tvar vfx = visual_scene.instantiate()
\t\tnew_effect.visual_instance = vfx
\t\tadd_child(vfx)
\t\t
\t# --- APPLICATION DU SHADER (Overlay Material) ---
\tif data.overlay_material != null and not is_local_player:
\t\t_apply_overlay_material(get_parent(), data.overlay_material)'''

content_comp = content_comp.replace(old_apply, new_apply)


old_remove = '''\t# Destruction visuel
\tif is_instance_valid(eff.visual_instance):
\t\teff.visual_instance.queue_free()'''

new_remove = '''\t# Destruction visuel
\tif is_instance_valid(eff.visual_instance):
\t\teff.visual_instance.queue_free()
\t\t
\t# Retrait du shader
\tif eff.data.overlay_material != null:
\t\tvar is_local = false
\t\tvar p = get_parent()
\t\tif p.is_in_group("Player") and p.is_multiplayer_authority():
\t\t\tis_local = true
\t\tif not is_local:
\t\t\t_remove_overlay_material(get_parent(), eff.data.overlay_material)'''

content_comp = content_comp.replace(old_remove, new_remove)

# Add the recursive functions at the end
helpers = '''
# --- FONCTIONS POUR SHADERS ---
func _apply_overlay_material(node: Node, mat: Material) -> void:
\tif node is MeshInstance3D:
\t\tnode.material_overlay = mat
\tfor child in node.get_children():
\t\t_apply_overlay_material(child, mat)

func _remove_overlay_material(node: Node, mat: Material) -> void:
\tif node is MeshInstance3D:
\t\tif node.material_overlay == mat:
\t\t\tnode.material_overlay = null
\tfor child in node.get_children():
\t\t_remove_overlay_material(child, mat)
'''

content_comp += helpers

with open(path_comp, 'w', encoding='utf-8') as f:
    f.write(content_comp)
