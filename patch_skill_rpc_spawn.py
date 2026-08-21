with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

rpc_code = '''
@rpc("any_peer", "call_remote", "reliable")
func _rpc_spawn_spell_visual(scene_path: String, caster_id: int, impact_point: Vector3, has_impact: bool) -> void:
	if scene_path == "": return
	var scene = load(scene_path)
	if scene == null: return
	
	var spell_instance = scene.instantiate()
	
	var attack_comp = spell_instance.get_node_or_null("AttackComponent")
	if attack_comp == null:
		attack_comp = spell_instance.find_child("AttackComponent*", true, false)
	if attack_comp != null:
		attack_comp.is_active_for_network = false
		
	get_tree().root.add_child(spell_instance)
	
	if has_impact:
		spell_instance.global_position = impact_point
		
	if spell_instance.has_method("execute"):
		spell_instance.execute(get_parent(), {})
'''

content += rpc_code

with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
