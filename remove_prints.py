with open('Y:/Fangorn/fangorn/scripts/abilities/thunder_slash/thunder_slash.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()
    
new_lines = [line for line in lines if 'print("Thunderslash :' not in line]

with open('Y:/Fangorn/fangorn/scripts/abilities/thunder_slash/thunder_slash.gd', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
    
print("Prints removed.")
