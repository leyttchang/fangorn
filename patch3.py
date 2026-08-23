
with open("Y:/Fangorn/fangorn/scripts/abilities/thunder_slash/thunder_slash.gd", "r", encoding="utf-8") as f:
    lines = f.readlines()

lines[5] = "@onready var slash1_local_basis = $slash_1.transform.basis\n"
lines[6] = "@onready var slash2_local_basis = $slash_2.transform.basis if has_node(\"slash_2\") else Basis()\n"

with open("Y:/Fangorn/fangorn/scripts/abilities/thunder_slash/thunder_slash.gd", "w", encoding="utf-8") as f:
    f.writelines(lines)

