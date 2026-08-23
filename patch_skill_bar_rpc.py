import os

path = 'Y:/Fangorn/fangorn/components/skill_bar_component.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Modifier trigger_mid_cast_event
old_trigger = '''func trigger_mid_cast_event(event_name: String) -> void:
\tif current_complex_spell_instance != null and current_complex_spell_instance.has_method("on_mid_cast_event"):
\t\tcurrent_complex_spell_instance.on_mid_cast_event(event_name)'''
new_trigger = '''func trigger_mid_cast_event(event_name: String) -> void:
\tif current_complex_spell_instance != null and current_complex_spell_instance.has_method("on_mid_cast_event"):
\t\tcurrent_complex_spell_instance.on_mid_cast_event(event_name)
\t\t
\t\t# Synchronisation multijoueur : on previent les autres clients de lancer cet evenement !
\t\tif is_multiplayer_authority() and casting_ability != null and casting_ability.ability_scene != null:
\t\t\trpc("_rpc_trigger_mid_cast_event", event_name, casting_ability.ability_scene.resource_path)'''
content = content.replace(old_trigger, new_trigger)

# Ajouter l'RPC en bas du fichier
if "_rpc_trigger_mid_cast_event" not in content:
    content += '''
@rpc("any_peer", "call_remote", "reliable")
func _rpc_trigger_mid_cast_event(event_name: String, scene_path: String) -> void:
\t# Sur les autres clients, on instancie le sort juste a temps s'il n'existe pas encore
\tif current_complex_spell_instance == null and scene_path != "":
\t\tvar scene = load(scene_path)
\t\tif scene != null:
\t\t\tcurrent_complex_spell_instance = scene.instantiate()
\t\t\tget_tree().root.add_child(current_complex_spell_instance)
\t\t\t
\t\t\t# Transmission de l'autorite pour les degats
\t\t\tvar auth = get_parent().get_multiplayer_authority()
\t\t\tfor child in current_complex_spell_instance.find_children("AttackComponent*", "Area3D", true, false):
\t\t\t\tchild.set_meta("caster_authority", auth)
\t\t\t\t
\t\t\tif current_complex_spell_instance.has_method("start_complex_cast"):
\t\t\t\tcurrent_complex_spell_instance.start_complex_cast(get_parent())
\t
\tif current_complex_spell_instance != null and current_complex_spell_instance.has_method("on_mid_cast_event"):
\t\tcurrent_complex_spell_instance.on_mid_cast_event(event_name)
'''

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
