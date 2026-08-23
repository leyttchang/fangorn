# -*- coding: utf-8 -*-
import os, re

path = 'Y:/Fangorn/fangorn/components/combat_feedback_component.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Inject static variables at the top (after volume_db max_distance)
static_vars = '''
# Limite stricte de textes instancies par frame pour les AoE (Bloqueur de perf)
static var _texts_spawned_this_frame: int = 0
static var _frame_reset_active: bool = false
'''

# We find the place after max_distance
content = re.sub(r'(@export var max_distance: float = 40\.0\n)', r'\1' + static_vars, content)

# 2. Inject the logic in _on_damage_taken
old_logic = '''\t\telse:
\t\t\t_active_text = damage_text_scene.instantiate()
\t\t\tget_tree().root.add_child(_active_text)
\t\t\t_active_text.global_position = get_parent().global_position + Vector3(0, spawn_height, 0)
\t\t\t_active_text.start_animation(amount)'''

new_logic = '''\t\telse:
\t\t\tif CombatFeedbackComponent._texts_spawned_this_frame >= 2:
\t\t\t\treturn
\t\t\t\t
\t\t\tCombatFeedbackComponent._texts_spawned_this_frame += 1
\t\t\t
\t\t\t_active_text = damage_text_scene.instantiate()
\t\t\tget_tree().root.add_child(_active_text)
\t\t\t_active_text.global_position = get_parent().global_position + Vector3(0, spawn_height, 0)
\t\t\t_active_text.start_animation(amount)
\t\t\t
\t\t\tif not CombatFeedbackComponent._frame_reset_active and get_tree() != null:
\t\t\t\tCombatFeedbackComponent._reset_counter_next_frame(get_tree())'''

content = content.replace(old_logic, new_logic)

# 3. Add the static reset function at the very end
reset_func = '''
static func _reset_counter_next_frame(tree: SceneTree) -> void:
\t_frame_reset_active = true
\tawait tree.process_frame
\t_texts_spawned_this_frame = 0
\t_frame_reset_active = false
'''

if 'func _reset_counter_next_frame' not in content:
    content += reset_func

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
