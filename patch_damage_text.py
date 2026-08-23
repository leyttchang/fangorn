# -*- coding: utf-8 -*-
import os, re

# --- PATCH DAMAGE TEXT ---
path_dt = 'Y:/Fangorn/fangorn/ui/damage_text.gd'
new_dt = '''extends Label3D

var total_damage: float = 0.0
var original_y: float = 0.0
var target_y: float = 0.0
var active_tween: Tween = null

func start_animation(amount: float) -> void:
\ttotal_damage = amount
\toriginal_y = position.y
\ttarget_y = original_y + 1.5
\t_update_visuals()

func add_damage(amount: float) -> void:
\ttotal_damage += amount
\t_update_visuals()
\t
\t# Petit effet de "pop" satisfaisant
\tscale = Vector3(1.5, 1.5, 1.5)
\tvar pop_tween = create_tween()
\tpop_tween.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT)

func _update_visuals() -> void:
\ttext = "%.1f" % total_damage
\t
\t# On detruit l'ancienne animation
\tif active_tween != null and active_tween.is_valid():
\t\tactive_tween.kill()
\t\t
\tmodulate.a = 1.0
\t
\tactive_tween = create_tween()
\tactive_tween.set_parallel(true)
\t
\t# Il continue de monter vers target_y (qui est fixe, donc il ne monte pas a l'infini !)
\tactive_tween.tween_property(self, "position:y", target_y, 1.0).set_ease(Tween.EASE_OUT)
\t# Il reste invisible pendant 0.5s, puis disparait en 0.5s
\tactive_tween.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.5)
\t
\tactive_tween.chain().tween_callback(queue_free)
'''

with open(path_dt, 'w', encoding='utf-8') as f:
    f.write(new_dt)


# --- PATCH COMBAT FEEDBACK ---
path_cf = 'Y:/Fangorn/fangorn/components/combat_feedback_component.gd'
with open(path_cf, 'r', encoding='utf-8') as f:
    cf_content = f.read()

# Remove the static limits and request_damage_text func
cf_content = re.sub(r'static var _texts_spawned_this_frame: int = 0\nstatic var _frame_reset_active: bool = false\n', 'var _active_text: Label3D = null\n', cf_content)
cf_content = re.sub(r'static func request_damage_text.*?_frame_reset_active = false\n', '', cf_content, flags=re.DOTALL)

# Replace the call in _on_damage_taken
old_call = '''\tif damage_text_scene != null:
\t\tvar pos = get_parent().global_position + Vector3(0, spawn_height, 0)
\t\tCombatFeedbackComponent.request_damage_text(damage_text_scene, pos, amount, get_tree())'''

new_call = '''\tif damage_text_scene != null:
\t\tif is_instance_valid(_active_text):
\t\t\t_active_text.add_damage(amount)
\t\telse:
\t\t\t_active_text = damage_text_scene.instantiate()
\t\t\tget_tree().root.add_child(_active_text)
\t\t\t_active_text.global_position = get_parent().global_position + Vector3(0, spawn_height, 0)
\t\t\t_active_text.start_animation(amount)'''

cf_content = cf_content.replace(old_call, new_call)

with open(path_cf, 'w', encoding='utf-8') as f:
    f.write(cf_content)

print("Patch damage text reussi !")
