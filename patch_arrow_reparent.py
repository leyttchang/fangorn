# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/fire_arrow.gd', 'r', encoding='utf-8') as f:
    content = f.read()

import re
# Remove the reparenting logic block
content = re.sub(r'# 3\. Reparenter la fl.*?(?=# 4\.)', '', content, flags=re.DOTALL)

with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/fire_arrow.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Arrow reparent removed")
