# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/ui/SpellBook/spell_book_ui.gd', 'r', encoding='utf-8') as f:
    content = f.read()

old_unlock = '''func unlock_spell(ability: AbilityData) -> bool:
	if ability == null:
		return false
	for s in unlocked_spells:
		if s != null and (s == ability or s.ability_name == ability.ability_name):
			return false
			
	unlocked_spells.append(ability)
	_setup_inventory_slots()
	return true'''

new_unlock = '''func unlock_spell(ability: AbilityData) -> bool:
	if ability == null: return false
	
	# Appel le RPC pour tout le monde (surtout le client concern?)
	rpc("_rpc_unlock_spell", ability.resource_path)
	return true

@rpc("authority", "call_local", "reliable")
func _rpc_unlock_spell(ability_path: String) -> void:
	var ability = load(ability_path) as AbilityData
	if ability == null: return
	
	for s in unlocked_spells:
		if s != null and (s == ability or s.ability_name == ability.ability_name):
			return
			
	unlocked_spells.append(ability)
	_setup_inventory_slots()
'''

if '_rpc_unlock_spell' not in content:
    content = content.replace(old_unlock, new_unlock)
    with open('Y:/Fangorn/fangorn/ui/SpellBook/spell_book_ui.gd', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Spellbook RPC patched")
