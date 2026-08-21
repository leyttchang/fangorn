# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/health_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

import re
content = re.sub(r'damage_taken\.emit\(final_damage\)', 'damage_taken.emit(final_damage)\\n\\trpc("_rpc_broadcast_damage", final_damage)', content, count=1)

with open('Y:/Fangorn/fangorn/components/health_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Broadcast call injected via regex")
