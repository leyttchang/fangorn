import os

path = 'Y:/Fangorn/fangorn/components/skill_bar_component.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. On rajoute une variable dedie pour ne pas ecraser current_vfx_instance
if 'var current_complex_spell_instance: Node3D = null' not in content:
    content = content.replace('var current_vfx_instance: Node3D = null', 'var current_vfx_instance: Node3D = null\nvar current_complex_spell_instance: Node3D = null')

# 2. Dans _start_casting ou _try_cast_ability, la ou on instancie le complex attack
old_complex = '''\t\t\t\t\tif ability.target_mode == AbilityData.TargetMode.COMPLEX_ATTACK:
\t\t\t\t\t\tif ability.ability_scene != null:
\t\t\t\t\t\t\tvar spell_instance = ability.ability_scene.instantiate()
\t\t\t\t\t\t\tget_tree().root.add_child(spell_instance)
\t\t\t\t\t\t\tcurrent_vfx_instance = spell_instance
\t\t\t\t\t\t\tspell_instance.global_position = get_parent().global_position
\t\t\t\t\t\t\tif spell_instance.has_method("start_complex_cast"):
\t\t\t\t\t\t\t\tspell_instance.start_complex_cast(get_parent())'''

new_complex = '''\t\t\t\t\tif ability.target_mode == AbilityData.TargetMode.COMPLEX_ATTACK:
\t\t\t\t\t\tif ability.ability_scene != null:
\t\t\t\t\t\t\tvar spell_instance = ability.ability_scene.instantiate()
\t\t\t\t\t\t\tget_tree().root.add_child(spell_instance)
\t\t\t\t\t\t\tcurrent_complex_spell_instance = spell_instance
\t\t\t\t\t\t\tspell_instance.global_position = get_parent().global_position
\t\t\t\t\t\t\tif spell_instance.has_method("start_complex_cast"):
\t\t\t\t\t\t\t\tspell_instance.start_complex_cast(get_parent())'''

content = content.replace(old_complex, new_complex)

# 3. Dans trigger_mid_cast_event, on utilise la nouvelle variable
old_trigger = '''func trigger_mid_cast_event(event_name: String) -> void:
\tprint("Event animation recu : ", event_name)
\tif current_vfx_instance != null and current_vfx_instance.has_method("on_mid_cast_event"):
\t\tcurrent_vfx_instance.on_mid_cast_event(event_name)'''

new_trigger = '''func trigger_mid_cast_event(event_name: String) -> void:
\tprint("Event animation recu : ", event_name)
\tif current_complex_spell_instance != null and current_complex_spell_instance.has_method("on_mid_cast_event"):
\t\tcurrent_complex_spell_instance.on_mid_cast_event(event_name)'''

content = content.replace(old_trigger, new_trigger)

# 4. Dans _execute_ability, on utilise la nouvelle variable
old_exec = '''\t\tif ability.target_mode == AbilityData.TargetMode.COMPLEX_ATTACK and current_vfx_instance != null:
\t\t\t# Le sort est deja sur le terrain car instancie au debut de l'animation !
\t\t\tspell_instance = current_vfx_instance'''

new_exec = '''\t\tif ability.target_mode == AbilityData.TargetMode.COMPLEX_ATTACK and current_complex_spell_instance != null:
\t\t\t# Le sort est deja sur le terrain car instancie au debut de l'animation !
\t\t\tspell_instance = current_complex_spell_instance'''

content = content.replace(old_exec, new_exec)

# 5. On repare _reset_casting (on supprime current_vfx_instance = null du MAUVAIS endroit)
old_reset = '''\tcurrent_state = State.IDLE
\tcasting_ability = null
\t
\t# Si on avait un spell complex en attente, on oublie le lien (il s'auto-detruira ou restera en vie selon son script)
\tcurrent_vfx_instance = null

\tcasting_action = ""'''

new_reset = '''\tcurrent_state = State.IDLE
\tcasting_ability = null
\t
\t# Si on avait un spell complex en attente, on oublie le lien (il s'auto-detruira ou restera en vie selon son script)
\tcurrent_complex_spell_instance = null

\tcasting_action = ""'''

content = content.replace(old_reset, new_reset)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Fix ok!")
