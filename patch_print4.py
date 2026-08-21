# -*- coding: utf-8 -*-
import re

with open('Y:/Fangorn/fangorn/components/health_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()
# Clean up any bad take_damage declarations
content = re.sub(r'func take_damage\(raw_damage: float\) -> void:.*?(?=\n\s+if not owner\.is_multiplayer_authority\(\):)', 'func take_damage(raw_damage: float) -> void:\n\tprint("TAKE DAMAGE CALLED! ", raw_damage)', content, flags=re.DOTALL)
with open('Y:/Fangorn/fangorn/components/health_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)

with open('Y:/Fangorn/fangorn/components/knockback_componant.gd', 'r', encoding='utf-8') as f:
    content = f.read()
# Clean up any bad apply_knockback declarations
content = re.sub(r'func apply_knockback\(push_direction: Vector3, raw_knockback_force: float\) -> void:.*?(?=\n\s+# On accepte la direction)', 'func apply_knockback(push_direction: Vector3, raw_knockback_force: float) -> void:\n\tprint("APPLY KNOCKBACK CALLED! Force: ", raw_knockback_force)', content, flags=re.DOTALL)
with open('Y:/Fangorn/fangorn/components/knockback_componant.gd', 'w', encoding='utf-8') as f:
    f.write(content)

print("Cleaned via regex")
