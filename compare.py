import re

def parse_tscn(filepath):
    nodes = []
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Extract nodes
    node_matches = re.finditer(r'\[node name="([^"]+)" type="([^"]+)"[^\]]*\]', content)
    for m in node_matches:
        nodes.append({'name': m.group(1), 'type': m.group(2)})
        
    # Extract inherited nodes
    node_matches_inherit = re.finditer(r'\[node name="([^"]+)" parent="([^"]+)"[^\]]*\]', content)
    for m in node_matches_inherit:
        if 'type=' not in m.group(0):
            nodes.append({'name': m.group(1), 'type': 'Inherited/Unknown'})
            
    return nodes

scout = parse_tscn('Y:/Fangorn/fangorn/character/enemie/Scout/scout.tscn')
dumb = parse_tscn('Y:/Fangorn/fangorn/character/enemie/dumb/dumb.tscn')

print("=== SCOUT NODES ===")
for n in scout:
    print(f"- {n['name']} ({n['type']})")
    
print("\n=== DUMB NODES ===")
for n in dumb:
    print(f"- {n['name']} ({n['type']})")
