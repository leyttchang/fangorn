# -*- coding: utf-8 -*-
import os, re

path = 'Y:/Fangorn/fangorn/components/health_component.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

pattern = re.compile(r'\tif armor_curve == null:\n\t\tpush_warning\("HealthComponent sur " \+ get_parent\(\)\.name \+ " : Pas de armor_curve assign.*? L\'armure ne fonctionnera pas\."\)\n\t\t', re.DOTALL)
content = pattern.sub('', content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
