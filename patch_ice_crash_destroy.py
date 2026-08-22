# -*- coding: utf-8 -*-
import re

with open('Y:/Fangorn/fangorn/scripts/abilities/Ice Crash/ice_crash.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the export var default to 15.0
content = re.sub(r'@export var duration_on_ground: float = 5\.0', '@export var duration_on_ground: float = 15.0', content)

# Replace the destruction part in execute
new_destruction = '''	# 4. DESTRUCTION AUTOMATIQUE DE SECOURS
	await get_tree().create_timer(duration_on_ground).timeout
	destroy_spell()
	
# --- NOUVELLE METHODE POUR LE DETRUIRE MANUELLEMENT ---
func destroy_spell() -> void:
	if is_instance_valid(self) and not is_queued_for_deletion():
		queue_free()'''

content = re.sub(r'\t# 4\. DESTRUCTION AUTOMATIQUE\n\tawait get_tree\(\)\.create_timer\(duration_on_ground\)\.timeout\n\tqueue_free\(\)', new_destruction, content)

with open('Y:/Fangorn/fangorn/scripts/abilities/Ice Crash/ice_crash.gd', 'w', encoding='utf-8') as f:
    f.write(content)
