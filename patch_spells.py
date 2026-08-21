# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace local spell instantiation with RPC
old_spell_spawn = '''	if ability.ability_scene != null:
		var spell_instance = ability.ability_scene.instantiate()
		get_tree().root.add_child(spell_instance)'''

new_spell_spawn = '''	if ability.ability_scene != null:
		var spell_instance = ability.ability_scene.instantiate()
		get_tree().root.add_child(spell_instance)
		# On previent les autres de faire l'echo visuel
		rpc("_rpc_spawn_spell_echo", ability.resource_path, target_data.get("impact_point", Vector3.ZERO))'''

rpc_def = '''
@rpc("any_peer", "call_remote", "reliable")
func _rpc_spawn_spell_echo(ability_path: String, impact_point: Vector3) -> void:
	var ability = load(ability_path)
	if ability == null or ability.ability_scene == null: return
	
	var spell_instance = ability.ability_scene.instantiate()
	get_tree().root.add_child(spell_instance)
	
	# Si c'est un sort de zone
	if impact_point != Vector3.ZERO:
		spell_instance.global_position = impact_point
		
	# On desactive la hitbox pour que ce soit juste un visuel !
	var hitbox = spell_instance.get_node_or_null("HitboxComponent")
	if hitbox != null:
		hitbox.queue_free()
		
	# On declenche l'execution visuelle si possible
	var dummy_data = {"impact_point": impact_point}
	if spell_instance.has_method("execute"):
		spell_instance.execute(get_parent(), dummy_data)
'''

if '_rpc_spawn_spell_echo' not in content:
    content = content.replace(old_spell_spawn, new_spell_spawn)
    content += rpc_def
    with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Spells patched")
