class_name ItemTooltip
extends PanelContainer

@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var desc_label: Label = $MarginContainer/VBoxContainer/DescLabel
@onready var stats_label: RichTextLabel = $MarginContainer/VBoxContainer/StatsLabel

var _item: ItemData
var _is_equipped: bool = false

func set_item(item: ItemData) -> void:
	_item = item

func set_equipped() -> void:
	_is_equipped = true

func _ready() -> void:
	if _item == null: return
	
	name_label.text = _item.item_name
	var rarity_colors = {
		ItemData.Rarity.COMMON: Color.WHITE,
		ItemData.Rarity.MAGIC: Color(0.2, 0.6, 1.0), # Bleu
		ItemData.Rarity.RARE: Color(1.0, 0.8, 0.2), # Jaune
		ItemData.Rarity.LEGENDARY: Color(1.0, 0.5, 0.0) # Orange
	}
	name_label.add_theme_color_override("font_color", rarity_colors[_item.rarity])
	
	if _is_equipped:
		name_label.text += "\n(Équipé)"
	
	desc_label.text = _item.description
	
	var stats_text = ""
	
	# Ajout du niveau de l'objet (ilvl)
	if _item.ilvl > 0:
		stats_text += "[color=darkgray]Item Level : " + str(_item.ilvl) + "[/color]\n\n"
	
	if _item is WeaponItem:
		var weapon = _item as WeaponItem
		stats_text += "[color=white]Dégâts : " + str(weapon.base_damage) + "[/color]\n"
		stats_text += "[color=white]Vitesse d'attaque : " + str(weapon.base_attack_speed) + "[/color]\n"
		
	var percent_stats = GameData.PERCENT_STATS
	var get_formatted_val = func(k, v):
		if k in percent_stats:
			var pct = round(v * 100.0)
			return ("+" if pct > 0 else "") + str(pct) + "%"
		else:
			return ("+" if v > 0 else "") + str(round(v))
			
	if _item is EquipmentItem:
		var equip = _item as EquipmentItem
		# Sécurité : Si l'objet n'a pas été généré par le générateur (objet statique placé à la main)
		if equip.innate_stats.is_empty() and equip.affix_stats.is_empty():
			for key in equip.stat_bonuses:
				var val = equip.stat_bonuses[key]
				if val != 0.0:
					stats_text += "[color=white]" + key.capitalize().replace("_", " ") + " : " + get_formatted_val.call(key, val) + "[/color]\n"
		else:
			# 1. Affichage des stats de base en Blanc
			for key in equip.innate_stats:
				var val = equip.innate_stats[key]
				if val != 0.0:
					stats_text += "[color=white]" + key.capitalize().replace("_", " ") + " : " + get_formatted_val.call(key, val) + "[/color]\n"
			
			# 2. Affichage des stats d'affixes en Bleu
			for key in equip.affix_stats:
				var val = equip.affix_stats[key]
				if val != 0.0:
					stats_text += "[color=lightskyblue]" + key.capitalize().replace("_", " ") + " : " + get_formatted_val.call(key, val) + "[/color]\n"
				
	if stats_text == "":
		stats_label.visible = false
	else:
		stats_label.visible = true
		stats_label.text = stats_text
