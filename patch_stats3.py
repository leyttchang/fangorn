import re

with open('Y:/Fangorn/fangorn/ui/inventaire/inventory_ui.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# Add button logic to _build_stats_ui
replacement = '''\tvar stats_added = []

\t# Connexion automatique des boutons pour déplier/replier (s'ils existent)
\tvar off_btn = get_node_or_null("%OffenseBtn")
\tif off_btn and offense_vbox and not off_btn.pressed.is_connected(offense_vbox.set_visible):
\t\toff_btn.pressed.connect(func(): offense_vbox.visible = not offense_vbox.visible)
\t\t
\tvar def_btn = get_node_or_null("%DefenseBtn")
\tif def_btn and defense_vbox and not def_btn.pressed.is_connected(defense_vbox.set_visible):
\t\tdef_btn.pressed.connect(func(): defense_vbox.visible = not defense_vbox.visible)
\t\t
\tvar misc_btn = get_node_or_null("%MiscBtn")
\tif misc_btn and misc_vbox and not misc_btn.pressed.is_connected(misc_vbox.set_visible):
\t\tmisc_btn.pressed.connect(func(): misc_vbox.visible = not misc_vbox.visible)

\t# Remplissage par catégorie'''

content = content.replace('\tvar stats_added = []\n\n\t# Remplissage par catégorie', replacement)

with open('Y:/Fangorn/fangorn/ui/inventaire/inventory_ui.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Patched toggles!")
