# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/health_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

import re
lines = content.split('\n')
for i, line in enumerate(lines):
    if "rpc_id" in line:
        print(f"{i+1}: {line}")
