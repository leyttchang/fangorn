import os

path = 'Y:/Fangorn/fangorn/scripts/abilities/thunder_slash/thunder_slash.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Ajout des variables pour sauvegarder les rotations locales
old_vars = '''@onready var anim_player: AnimationPlayer = 
var caster: Node3D = null'''

new_vars = '''@onready var anim_player: AnimationPlayer = 
var caster: Node3D = null

@onready var slash1_local_basis = $slash_1.transform.basis
@onready var slash2_local_basis = $slash_2.transform.basis if has_node("slash_2") else Basis()'''
content = content.replace(old_vars, new_vars)

# Pour slash_1
old_s1 = '''\t\t\tvar cam = caster.get_node_or_null("Camera3D")
\t\t\tif cam != null:
\t\t\t\t$slash_1.global_transform.basis = cam.global_transform.basis
\t\t\telse:
\t\t\t\t$slash_1.global_transform.basis = caster.global_transform.basis'''
new_s1 = '''\t\t\tvar target_basis = caster.global_transform.basis
\t\t\tvar cam = caster.get_node_or_null("Camera3D")
\t\t\tif cam != null:
\t\t\t\ttarget_basis = cam.global_transform.basis
\t\t\t
\t\t\t# On applique la direction de la camera + on conserve ta rotation locale (editor) !
\t\t\t$slash_1.global_transform.basis = target_basis * slash1_local_basis
\t\t\t# On donne la VRAIE direction d'avancement au script (pour qu'il avance tout droit)
\t\t\t$slash_1.forward_direction = -target_basis.z'''
content = content.replace(old_s1, new_s1)

# Pour slash_2
old_s2 = '''\t\t\tvar cam = caster.get_node_or_null("Camera3D")
\t\t\tif cam != null:
\t\t\t\t$slash_2.global_transform.basis = cam.global_transform.basis
\t\t\telse:
\t\t\t\t$slash_2.global_transform.basis = caster.global_transform.basis'''
new_s2 = '''\t\t\tvar target_basis = caster.global_transform.basis
\t\t\tvar cam = caster.get_node_or_null("Camera3D")
\t\t\tif cam != null:
\t\t\t\ttarget_basis = cam.global_transform.basis
\t\t\t
\t\t\t$slash_2.global_transform.basis = target_basis * slash2_local_basis
\t\t\t
\t\t\tif $slash_2.get("forward_direction") != null:
\t\t\t\t$slash_2.forward_direction = -target_basis.z'''
content = content.replace(old_s2, new_s2)

content = content.replace('$', '$')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
