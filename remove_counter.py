with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "r", encoding="utf-8") as f:
    content = f.read()

import re

# 1. Remove export
content = re.sub(r'@export var show_node_stats: bool = true :\s*set\(val\):\s*show_node_stats = val\s*generate_tree\(\)', '', content)

# 2. Remove the stats section
start_marker = "	# 5. Compter les noeuds et afficher les stats"
end_marker = "	# 4. Initialisation des états"

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

if start_idx != -1 and end_idx != -1:
    content = content[:start_idx] + content[end_idx:]

with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Removed node counter")
