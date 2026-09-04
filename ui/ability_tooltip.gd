class_name AbilityTooltip
extends PanelContainer

@export var title_label: Label
@export var description_label: Label
@export var stats_label: RichTextLabel 

func setup(ability: AbilityData) -> void:
	if not ability: return
	
	if title_label:
		title_label.text = ability.ability_name
	
	if description_label:
		description_label.text = ability.description
	
	if not stats_label: return
	
	# Si le joueur a glisse le tooltip genere manuellement dans AbilityData
	if ability.get("custom_tooltip") != null:
		if ability.custom_tooltip.generated_text != "":
			stats_label.text = ability.custom_tooltip.generated_text
			return
			
	# Sinon on le cherche automatiquement (en fallback)
	var original_path = ability.resource_path
	var tooltip_path = original_path.get_base_dir() + "/" + original_path.get_file().get_basename() + "_tooltip.tres"
	
	if ResourceLoader.exists(tooltip_path):
		var tooltip_data = ResourceLoader.load(tooltip_path)
		if tooltip_data and "generated_text" in tooltip_data:
			stats_label.text = tooltip_data.generated_text
			return
		
	stats_label.text = "[color=gray]Fichier tooltip manquant. Utilisez TooltipGenerator pour le creer.[/color]"
