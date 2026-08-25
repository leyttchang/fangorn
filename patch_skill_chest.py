import re
with open('Y:/Fangorn/fangorn/objet/chest/skill_chest.gd', 'r', encoding='utf-8') as f:
    text = f.read()

replacement = '''\tvisible = false
\tvar interact = get_node_or_null("InteractionComponent")
\tif interact:
\t\tinteract.queue_free()
\t
\tvar static_body = get_node_or_null("StaticBody3D")
\tif static_body:
\t\tstatic_body.queue_free()'''

text = text.replace(
    "\tvisible = false\n\tvar interact = get_node_or_null(\"InteractionComponent\")\n\tif interact:\n\t\tinteract.queue_free()",
    replacement
)

with open('Y:/Fangorn/fangorn/objet/chest/skill_chest.gd', 'w', encoding='utf-8') as f:
    f.write(text)

print("skill_chest patched")
