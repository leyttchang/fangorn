with open("Y:/Fangorn/fangorn/components/health_component.gd", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("Pour le Hut Builder", "Pour Ignore Death")
content = content.replace("CHEAT DEATH (Hut Builder)", "CHEAT DEATH (Ignore Death)")

with open("Y:/Fangorn/fangorn/components/health_component.gd", "w", encoding="utf-8") as f:
    f.write(content)
