import os

path_comp = 'Y:/Fangorn/fangorn/components/skill_bar_component.gd'
with open(path_comp, 'r', encoding='utf-8') as f:
    content_comp = f.read()

trigger_func = '''
# --- LE RELAIS MAGIQUE POUR COMPLEX_ATTACK ---
func trigger_mid_cast_event(event_name: String) -> void:
\tprint("Event animation recu : ", event_name)
\tif current_vfx_instance != null and current_vfx_instance.has_method("on_mid_cast_event"):
\t\tcurrent_vfx_instance.on_mid_cast_event(event_name)

'''

if 'func trigger_mid_cast_event' not in content_comp:
    # On l'insere avant _try_cast_ability
    content_comp = content_comp.replace('func _try_cast_ability(ability: AbilityData) -> void:', trigger_func + 'func _try_cast_ability(ability: AbilityData) -> void:')

old_cast_setup = '''\t\t\t\t\tcasting_ability = ability
\t\t\t\t\tcasting_action = action
\t\t\t\t\tcurrent_cast_time = 0.0
\t\t\t\t\trequired_cast_time = final_required_time'''

new_cast_setup = '''\t\t\t\t\tcasting_ability = ability
\t\t\t\t\tcasting_action = action
\t\t\t\t\tcurrent_cast_time = 0.0
\t\t\t\t\trequired_cast_time = final_required_time
\t\t\t\t\t
\t\t\t\t\tif ability.target_mode == AbilityData.TargetMode.COMPLEX_ATTACK:
\t\t\t\t\t\tif ability.ability_scene != null:
\t\t\t\t\t\t\tvar spell_instance = ability.ability_scene.instantiate()
\t\t\t\t\t\t\tget_tree().root.add_child(spell_instance)
\t\t\t\t\t\t\tcurrent_vfx_instance = spell_instance
\t\t\t\t\t\t\tspell_instance.global_position = get_parent().global_position
\t\t\t\t\t\t\tif spell_instance.has_method("start_complex_cast"):
\t\t\t\t\t\t\t\tspell_instance.start_complex_cast(get_parent())'''

if 'spell_instance.start_complex_cast' not in content_comp:
    content_comp = content_comp.replace(old_cast_setup, new_cast_setup)

with open(path_comp, 'w', encoding='utf-8') as f:
    f.write(content_comp)
print("Patch OK !")
