import re
with open('Y:/Fangorn/fangorn/character/enemie/Scout/scout.tscn', 'r', encoding='utf-8') as f:
    content = f.read()

node_matches = re.finditer(r'\[node name="([^"]+)" type="([^"]+)"[^\]]*\]', content)
nodes = [(m.group(1), m.group(2)) for m in node_matches]

inherit_matches = re.finditer(r'\[node name="([^"]+)" parent="([^"]+)"[^\]]*\]', content)
inherits = [(m.group(1), m.group(2)) for m in inherit_matches if 'type=' not in m.group(0)]

print("=== SCOUT NODES ===")
for name, t in nodes: print(f"- {name} ({t})")
for name, p in inherits: print(f"- {name} (child of {p})")
