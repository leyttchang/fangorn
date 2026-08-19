import os
import re

directory = "Y:/Fangorn/fangorn/passive_skill_tree/ressource_node"

for root, _, files in os.walk(directory):
    for f in files:
        if f.endswith(".tres"):
            filepath = os.path.join(root, f)
            with open(filepath, "r", encoding="utf-8") as file:
                content = file.read()
                
            def clamp_multiplier(match):
                val = float(match.group(2))
                if val > 1.0:
                    return f"{match.group(1)}1.0"
                return match.group(0)

            # Match tier_X_multiplier = Y.Y
            content = re.sub(r'(tier_[123]_multiplier\s*=\s*)([\d.]+)', clamp_multiplier, content)
            
            with open(filepath, "w", encoding="utf-8") as file:
                file.write(content)
                
print("Clamped tier multipliers to 1.0")
