import re

with open('Y:/Fangorn/fangorn/ui/inventaire/inventory_ui.gd', 'r', encoding='utf-8') as f:
    content = f.read()

new_build_stats = '''
var stat_categories = {
\t"Offense": ["physical_damage", "magic_damage", "fire_damage", "ice_damage", "lightning_damage", "attack_speed", "casting_speed", "area_of_effect", "knockback_power", "flat_physical_damage"],
\t"Defense": ["max_health", "armor", "physical_resistance", "fire_resistance", "ice_resistance", "lightning_resistance", "knockback_resistance"],
\t"Misc": ["max_mana", "mana_regen", "movement_speed", "cd_red", "luck"]
}

@onready var offense_vbox: VBoxContainer = get_node_or_null("%OffenseVBox")
@onready var defense_vbox: VBoxContainer = get_node_or_null("%DefenseVBox")
@onready var misc_vbox: VBoxContainer = get_node_or_null("%MiscVBox")
@onready var level_label: Label = get_node_or_null("%LevelLabel")

func _build_stats_ui() -> void:
\t# Nettoyage des anciennes stats
\tif offense_vbox:
\t\tfor c in offense_vbox.get_children(): c.queue_free()
\tif defense_vbox:
\t\tfor c in defense_vbox.get_children(): c.queue_free()
\tif misc_vbox:
\t\tfor c in misc_vbox.get_children(): c.queue_free()
\t\t
\t# Mise à jour du niveau (si le label existe dans la scène)
\tif level_label != null and level_component != null:
\t\tlevel_label.text = "Level : " + str(level_component.current_level)
\t\tstat_labels["current_level"] = level_label

\tvar stats_added = []

\t# Remplissage par catégorie
\tfor category_name in stat_categories.keys():
\t\tvar target_vbox: VBoxContainer = null
\t\tif category_name == "Offense": target_vbox = offense_vbox
\t\telif category_name == "Defense": target_vbox = defense_vbox
\t\telif category_name == "Misc": target_vbox = misc_vbox
\t\t
\t\tif target_vbox == null: continue
\t\t
\t\tfor stat_name in stat_categories[category_name]:
\t\t\tif stats_component._stats.has(stat_name):
\t\t\t\tstats_added.append(stat_name)
\t\t\t\tvar label = Label.new()
\t\t\t\tlabel.text = _format_stat(stat_name, stats_component.get_stat_value(stat_name))
\t\t\t\ttarget_vbox.add_child(label)
\t\t\t\tstat_labels[stat_name] = label

\t# Les stats restantes (non classées) vont dans Misc par défaut (ou StatsContainer si Misc n'existe pas)
\tvar fallback_vbox = misc_vbox if misc_vbox else stats_container
\tfor stat_name in stats_component._stats.keys():
\t\tif not stats_added.has(stat_name):
\t\t\tvar label = Label.new()
\t\t\tlabel.text = _format_stat(stat_name, stats_component.get_stat_value(stat_name))
\t\t\tif fallback_vbox: fallback_vbox.add_child(label)
\t\t\tstat_labels[stat_name] = label
'''

pattern = r'var stat_categories = \{[\s\S]*?(?=func _on_stat_changed)'
content = re.sub(pattern, new_build_stats, content)

with open('Y:/Fangorn/fangorn/ui/inventaire/inventory_ui.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Patched!")
