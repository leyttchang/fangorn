with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''		if spell_instance.has_method("execute"):
			spell_instance.execute(get_parent(), target_data)''', '''		if spell_instance.has_method("execute"):
			spell_instance.execute(get_parent(), target_data)
			
		var impact = Vector3.ZERO
		var has_impact = false
		if target_data.has("impact_point"):
			impact = target_data["impact_point"]
			has_impact = true
			
		rpc("_rpc_spawn_spell_visual", ability.ability_scene.resource_path, get_parent().get_multiplayer_authority(), impact, has_impact)''')

with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
