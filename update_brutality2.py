with open("Y:/Fangorn/fangorn/passive_skill_tree/ressource_node/Keystone/brutality_keystone.gd", "r", encoding="utf-8") as f:
    content = f.read()

import re

# Add skill_bar variable
content = content.replace("var stats: StatsComponent", "var stats: StatsComponent\nvar skill_bar: SkillBarComponent")

# Find skill_bar in ready
ready_hook = """\tif stats != null:
		stats.stat_changed.connect(_on_stat_changed)
		_apply_brutality()"""
ready_new = """\tskill_bar = player.get_node_or_null("SkillBarComponent")
	if skill_bar == null:
		skill_bar = player.get_node_or_null("%SkillBarComponent")
		
	if skill_bar != null:
		skill_bar.can_cast_spells = false
		
	if stats != null:
		stats.stat_changed.connect(_on_stat_changed)
		_apply_brutality()"""
content = content.replace(ready_hook, ready_new)

# Re-enable in exit_tree
exit_hook = """func _exit_tree() -> void:
	if stats != null:"""
exit_new = """func _exit_tree() -> void:
	if skill_bar != null:
		skill_bar.can_cast_spells = true
		
	if stats != null:"""
content = content.replace(exit_hook, exit_new)

with open("Y:/Fangorn/fangorn/passive_skill_tree/ressource_node/Keystone/brutality_keystone.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated brutality keystone casting logic")
