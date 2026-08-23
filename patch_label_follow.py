# -*- coding: utf-8 -*-
import os, re

# --- PATCH DAMAGE TEXT ---
path_dt = 'Y:/Fangorn/fangorn/ui/damage_text.gd'
with open(path_dt, 'r', encoding='utf-8') as f:
    content_dt = f.read()

old_add = '''func add_damage(amount: float) -> void:
\ttotal_damage += amount
\t_update_visuals()'''

new_add = '''func add_damage(amount: float, new_pos: Vector3 = Vector3.ZERO) -> void:
\ttotal_damage += amount
\t
\tif new_pos != Vector3.ZERO:
\t\tglobal_position.x = new_pos.x
\t\tglobal_position.z = new_pos.z
\t\t
\t_update_visuals()'''

content_dt = content_dt.replace(old_add, new_add)
with open(path_dt, 'w', encoding='utf-8') as f:
    f.write(content_dt)


# --- PATCH COMBAT FEEDBACK ---
path_cf = 'Y:/Fangorn/fangorn/components/combat_feedback_component.gd'
with open(path_cf, 'r', encoding='utf-8') as f:
    content_cf = f.read()

old_call = '''\t\tif is_instance_valid(_active_text):
\t\t\t_active_text.add_damage(amount)
\t\telse:'''

new_call = '''\t\tif is_instance_valid(_active_text):
\t\t\tvar pos = get_parent().global_position + Vector3(0, spawn_height, 0)
\t\t\t_active_text.add_damage(amount, pos)
\t\telse:'''

content_cf = content_cf.replace(old_call, new_call)
with open(path_cf, 'w', encoding='utf-8') as f:
    f.write(content_cf)


# --- PATCH DUMMY ---
path_du = 'Y:/Fangorn/fangorn/character/dummy.gd'
with open(path_du, 'r', encoding='utf-8') as f:
    content_du = f.read()

old_du = '''\tif is_instance_valid(_active_text):
\t\t_active_text.add_damage(amount)
\telse:'''

new_du = '''\tif is_instance_valid(_active_text):
\t\tvar pos = global_position
\t\tpos.y += 1.0
\t\t_active_text.add_damage(amount, pos)
\telse:'''

content_du = content_du.replace(old_du, new_du)
with open(path_du, 'w', encoding='utf-8') as f:
    f.write(content_du)

print("Patch follow reussi !")
