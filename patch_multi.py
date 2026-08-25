import re

with open('Y:/Fangorn/fangorn/scripts/abilities/Warcry/warcry.gd', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''\t# 1. On applique les vraies stats à TOUS les joueurs dans la zone
\t# MULTIJOUEUR : Seul celui qui a lancé le sort décide de qui est touché
\tif buff_data != null and caster.is_multiplayer_authority():
\t\tvar all_players = get_tree().get_nodes_in_group("Player")'''

content = content.replace('\t# 1. On applique les vraies stats à TOUS les joueurs dans la zone\n\tif buff_data != null:\n\t\tvar all_players = get_tree().get_nodes_in_group("Player")', replacement)

with open('Y:/Fangorn/fangorn/scripts/abilities/Warcry/warcry.gd', 'w', encoding='utf-8') as f:
    f.write(content)


with open('Y:/Fangorn/fangorn/scripts/abilities/thunder_aspect/thunder_aspect.gd', 'r', encoding='utf-8') as f:
    content2 = f.read()

replacement2 = '''\t# 1. On applique les vraies stats (Le buff de dégâts/vitesse)
\t# MULTIJOUEUR : Seul le lanceur applique l'effet pour éviter que tout le monde envoie la commande en même temps
\tif buff_data != null and caster.is_multiplayer_authority():'''

content2 = content2.replace('\t# 1. On applique les vraies stats (Le buff de dégâts/vitesse)\n\tif buff_data != null:', replacement2)

with open('Y:/Fangorn/fangorn/scripts/abilities/thunder_aspect/thunder_aspect.gd', 'w', encoding='utf-8') as f:
    f.write(content2)

print("Patched multiplayer authorities")
