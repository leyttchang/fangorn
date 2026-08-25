import re

with open('Y:/Fangorn/fangorn/ui/inventaire/inventory_ui.gd', 'r', encoding='utf-8') as f:
    content = f.read()

new_build_stats = '''
var stat_categories = {
\t"Offense": ["physical_damage", "magic_damage", "fire_damage", "ice_damage", "lightning_damage", "attack_speed", "casting_speed", "area_of_effect", "knockback_power"],
\t"Defense": ["max_health", "armor", "physical_resistance", "fire_resistance", "ice_resistance", "lightning_resistance", "knockback_resistance"],
\t"Misc": ["max_mana", "mana_regen", "movement_speed", "cd_red", "luck"]
}

func _build_stats_ui() -> void:
\tfor child in stats_container.get_children():
\t\tif not (child is Button and child.text == "KILL ALL"): # On garde le bouton de triche s'il est là
\t\t\tchild.queue_free()
\t\t\t
\t# 1. Ajout du Niveau
\tif level_component != null:
\t\tvar lvl_label = Label.new()
\t\tlvl_label.text = "Level : " + str(level_component.current_level)
\t\tlvl_label.add_theme_color_override("font_color", Color.GOLD)
\t\tstats_container.add_child(lvl_label)
\t\tstat_labels["current_level"] = lvl_label
\t\t
\t# 2. Ajout des Catégories
\tvar stats_added = []
\tfor category_name in stat_categories.keys():
\t\t# Le Bouton (Titre de la catégorie)
\t\tvar cat_btn = Button.new()
\t\tcat_btn.text = "- " + category_name + " -"
\t\tcat_btn.flat = true # Rend le bouton transparent (sans fond moche)
\t\tcat_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
\t\tcat_btn.add_theme_color_override("font_color", Color.CYAN)
\t\tstats_container.add_child(cat_btn)
\t\t
\t\t# Le conteneur des stats de cette catégorie (avec une marge à gauche pour l'indentation)
\t\tvar margin = MarginContainer.new()
\t\tmargin.add_theme_constant_override("margin_left", 15)
\t\tstats_container.add_child(margin)
\t\t
\t\tvar cat_vbox = VBoxContainer.new()
\t\tmargin.add_child(cat_vbox)
\t\t
\t\t# Rendre la catégorie dépliable au clic
\t\tcat_btn.pressed.connect(func(): margin.visible = not margin.visible)
\t\t
\t\t# Remplissage
\t\tvar has_stats = false
\t\tfor stat_name in stat_categories[category_name]:
\t\t\tif stats_component._stats.has(stat_name):
\t\t\t\thas_stats = true
\t\t\t\tstats_added.append(stat_name)
\t\t\t\tvar label = Label.new()
\t\t\t\tlabel.text = _format_stat(stat_name, stats_component.get_stat_value(stat_name))
\t\t\t\tcat_vbox.add_child(label)
\t\t\t\tstat_labels[stat_name] = label
\t\t\t\t
\t\t# Si une catégorie est vide, on la cache
\t\tif not has_stats:
\t\t\tcat_btn.visible = false
\t\t\tmargin.visible = false

\t# 3. Les stats restantes (non classées)
\tfor stat_name in stats_component._stats.keys():
\t\tif not stats_added.has(stat_name):
\t\t\tvar label = Label.new()
\t\t\tlabel.text = _format_stat(stat_name, stats_component.get_stat_value(stat_name))
\t\t\tstats_container.add_child(label)
\t\t\tstat_labels[stat_name] = label
'''

pattern = r'func _build_stats_ui\(\) -> void:[\s\S]*?(?=func _on_stat_changed)'
content = re.sub(pattern, new_build_stats, content)

with open('Y:/Fangorn/fangorn/ui/inventaire/inventory_ui.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Patched!")
