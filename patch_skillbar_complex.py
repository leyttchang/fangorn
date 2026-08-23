import os

path_data = 'Y:/Fangorn/fangorn/scripts/abilities/ability_data.gd'
with open(path_data, 'r', encoding='utf-8') as f:
    content_data = f.read()

old_enum = 'SUMMON          # Invocation au sol'
new_enum = 'SUMMON,         # Invocation au sol\n\tCOMPLEX_ATTACK  # Instancie des le debut, pilote par l\'AnimationPlayer (Call Method Tracks)'

if 'COMPLEX_ATTACK' not in content_data:
    content_data = content_data.replace(old_enum, new_enum)
    with open(path_data, 'w', encoding='utf-8') as f:
        f.write(content_data)


path_comp = 'Y:/Fangorn/fangorn/components/skill_bar_component.gd'
with open(path_comp, 'r', encoding='utf-8') as f:
    content_comp = f.read()

# On ajoute le trigger public
new_trigger = '''\t\t\t\t
\t\t\t_execute_ability(active_ability, target_data)
\t\telse:'''

trigger_code = '''
# --- LE RELAIS MAGIQUE POUR COMPLEX_ATTACK ---
func trigger_mid_cast_event(event_name: String) -> void:
\tprint("Event animation recu : ", event_name)
\tif current_vfx_instance != null and current_vfx_instance.has_method("on_mid_cast_event"):
\t\tcurrent_vfx_instance.on_mid_cast_event(event_name)
'''
if 'trigger_mid_cast_event' not in content_comp:
    content_comp = content_comp.replace('func _start_casting(ability: AbilityData) -> void:', trigger_code + '\nfunc _start_casting(ability: AbilityData) -> void:')

# Dans start_casting, si COMPLEX_ATTACK, on spawn la scene!
old_start = '''func _start_casting(ability: AbilityData) -> void:
\tcasting_ability = ability'''
new_start = '''func _start_casting(ability: AbilityData) -> void:
\tcasting_ability = ability
\t
\t# Si c'est une COMPLEX_ATTACK, on instancie la scene DU SORT DES LE DEBUT !
\tif ability.target_mode == AbilityData.TargetMode.COMPLEX_ATTACK:
\t\tif ability.ability_scene != null:
\t\t\tvar spell_instance = ability.ability_scene.instantiate()
\t\t\tget_tree().root.add_child(spell_instance)
\t\t\tcurrent_vfx_instance = spell_instance # On le garde en memoire pour trigger_mid_cast_event !
\t\t\t
\t\t\t# On l'attache au caster par defaut
\t\t\tspell_instance.global_position = get_parent().global_position
\t\t\t
\t\t\t# Si le sort a besoin de s'initialiser
\t\t\tif spell_instance.has_method("start_complex_cast"):
\t\t\t\tspell_instance.start_complex_cast(get_parent())
\t'''
if 'AbilityData.TargetMode.COMPLEX_ATTACK' not in content_comp:
    content_comp = content_comp.replace(old_start, new_start)

# Dans _try_cast_ability
old_try = 'AbilityData.TargetMode.INSTANT, AbilityData.TargetMode.PROJECTILE:'
new_try = 'AbilityData.TargetMode.INSTANT, AbilityData.TargetMode.PROJECTILE, AbilityData.TargetMode.COMPLEX_ATTACK:'
content_comp = content_comp.replace(old_try, new_try)

# Dans reset_casting, on nettoie
old_reset = '''\tcurrent_state = State.IDLE
\tcasting_ability = null'''
new_reset = '''\tcurrent_state = State.IDLE
\tcasting_ability = null
\t
\t# Si on avait un spell complex en attente, on oublie le lien (il s'auto-detruira ou restera en vie selon son script)
\tcurrent_vfx_instance = null
'''
if 'Si on avait un spell complex' not in content_comp:
    content_comp = content_comp.replace(old_reset, new_reset)

# Dans _execute_ability, empecher le double spawn
old_spawn = '''\tif ability.ability_scene != null:
\t\tvar spell_instance = ability.ability_scene.instantiate()
\t\tget_tree().root.add_child(spell_instance)
\t\t
\t\tmatch ability.target_mode:'''
new_spawn = '''\tif ability.ability_scene != null:
\t\tvar spell_instance = null
\t\t
\t\tif ability.target_mode == AbilityData.TargetMode.COMPLEX_ATTACK:
\t\t\t# Il est deja instancie ! On le recupere
\t\t\tspell_instance = current_vfx_instance
\t\telse:
\t\t\t# Comportement normal
\t\t\tspell_instance = ability.ability_scene.instantiate()
\t\t\tget_tree().root.add_child(spell_instance)
\t\t
\t\tif spell_instance != null:
\t\t\tmatch ability.target_mode:'''
if 'spell_instance = current_vfx_instance' not in content_comp:
    content_comp = content_comp.replace(old_spawn, new_spawn)
    
# Reparer l'indentation de match 
old_match = '''\t\t\t\ttarget_data.has("impact_point"):
\t\t\t\tspell_instance.global_position = target_data["impact_point"]'''
new_match = '''\t\t\t\ttarget_data.has("impact_point"):
\t\t\t\t\tspell_instance.global_position = target_data["impact_point"]'''
content_comp = content_comp.replace(old_match, new_match)

# Remplacer la fin de _execute_ability
old_end = '''\t\tif spell_instance.has_method("execute"):
\t\t\tspell_instance.execute(get_parent(), target_data)'''
new_end = '''\t\t\tif spell_instance.has_method("execute"):
\t\t\t\tspell_instance.execute(get_parent(), target_data)'''
content_comp = content_comp.replace(old_end, new_end)


with open(path_comp, 'w', encoding='utf-8') as f:
    f.write(content_comp)
print("Patch OK !")
