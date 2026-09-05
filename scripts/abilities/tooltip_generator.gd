@tool
class_name TooltipGenerator
extends Resource

@export var spell_data: AbilityData

@export var generer_tooltip: bool = false:
	set(val):
		if val:
			_generate()
			generer_tooltip = false

func _generate():
	if spell_data == null or spell_data.ability_scene == null:
		print("[TooltipGenerator] Erreur: Assigne un spell_data avec une scene valide.")
		return
		
	print("[TooltipGenerator] Analyse de la scene de " + spell_data.ability_name + "...")
	
	var bbcode = ""
	var type_str = "Spell"
	if spell_data.skill_type == AbilityData.SkillScalingType.ATTACK:
		type_str = "Attack"
		
	bbcode += "[color=lightblue]%s | Cooldown: %ss | Mana Cost: %s[/color]\n\n" % [type_str, spell_data.cooldown, spell_data.mana_cost]
	
	var scene_instance = spell_data.ability_scene.instantiate()
	
	# 1. ATTAQUES & DEGATS CLASSIQUES
	var scalings = _find_all_nodes(scene_instance, "SpellScalingComponent")
	for scaling in scalings:
		var attack_comp = scaling.get("attack_component")
		if attack_comp == null: continue
		bbcode += _format_attack(attack_comp, scaling)
		
	# 2. RECHERCHE DES EXPLOSIONS SPECIALES (ex: Boule de feu)
	var explosions = _find_explosion_nodes(scene_instance)
	for explo in explosions:
		var parent_attack = explo.get("attack_component")
		var parent_scaling = explo.get("scaling_component")
		var ratio = explo.get("ratio_degat")
		if ratio == null: ratio = 1.0
		
		if parent_attack != null and parent_scaling != null:
			var fake_attack = parent_attack.duplicate()
			fake_attack.base_damage = parent_attack.base_damage * ratio
			bbcode += "[color=orange][b]- %s -[/b][/color]\n" % "Explosion"
			
			var dmg_str = "[b]%s[/b] Base" % fake_attack.base_damage
			if parent_scaling.skill_type == 1:
				var mult = parent_scaling.base_weapon_multiplier * ratio
				if mult > 0.0:
					dmg_str += " [b]+ %s%%[/b] Weapon Damage" % (mult * 100)
					
			bbcode += "Damage: " + dmg_str + " [color=yellow](AoE)[/color]\n"
			
			var elements = []
			if parent_scaling.phys_ratio > 0: elements.append("[color=gray]" + str(parent_scaling.phys_ratio * 100) + "% Physical[/color]")
			if parent_scaling.fire_ratio > 0: elements.append("[color=orangered]" + str(parent_scaling.fire_ratio * 100) + "% Fire[/color]")
			if parent_scaling.ice_ratio > 0: elements.append("[color=cyan]" + str(parent_scaling.ice_ratio * 100) + "% Ice[/color]")
			if parent_scaling.lightning_ratio > 0: elements.append("[color=gold]" + str(parent_scaling.lightning_ratio * 100) + "% Lightning[/color]")
			
			if elements.size() > 0:
				bbcode += "Damage Type: " + " / ".join(elements) + "\n"
				
			if "status_effects_to_apply" in parent_attack and parent_attack.status_effects_to_apply != null:
				for effect_app in parent_attack.status_effects_to_apply:
					if effect_app != null and effect_app.effect != null:
						bbcode += "Applies [b]%s[/b] (%s%% chance) for %ss\n" % [
							effect_app.effect.effect_id.capitalize(),
							effect_app.apply_chance * 100,
							effect_app.duration
						]
			bbcode += "\n"
			fake_attack.free()
			
	# 3. RECHERCHE DES BUFFS/DEBUFFS DE ZONE DIRECTS (ex: Warcry, Thunder Aspect)
	var buffs = _find_buff_nodes(scene_instance)
	for b in buffs:
		var buff_data = b.get("buff_data")
		if buff_data != null:
			var dur = b.get("buff_duration")
			if dur == null: dur = 0.0
			
			var buff_title = buff_data.effect_id.capitalize()
			if buff_title == "": buff_title = "Aura"
			
			if buff_data.is_buff:
				bbcode += "[color=green][b]- %s (Buff) -[/b][/color]\n" % buff_title
			else:
				bbcode += "[color=purple][b]- %s (Debuff) -[/b][/color]\n" % buff_title
				
			bbcode += "Duration: %ss\n" % dur
			
			if "buff_radius" in b and b.buff_radius > 0:
				bbcode += "Radius: %sm\n" % b.buff_radius
			
			if buff_data.stat_modifiers != null and buff_data.stat_modifiers.size() > 0:
				for mod in buff_data.stat_modifiers:
					if mod == null: continue
					var mod_type_str = "%" if mod.mod_type == 1 else "" # 1 = PERCENT
					var display_val = mod.value * 100 if mod.mod_type == 1 else mod.value
					var sign_str = "+" if display_val >= 0 else ""
					var stat_nice = mod.stat_name.replace("_", " ").capitalize()
					bbcode += "  %s%s%s %s\n" % [sign_str, display_val, mod_type_str, stat_nice]
					
			if buff_data.tick_damage > 0:
				bbcode += "  Deals %s damage every %ss\n" % [buff_data.tick_damage, buff_data.tick_interval]
				
			bbcode += "\n"
			
	scene_instance.queue_free()
	
	var tooltip_res = SpellTooltipData.new()
	tooltip_res.generated_text = bbcode
	
	var original_path = spell_data.resource_path
	var new_path = original_path.get_base_dir() + "/" + original_path.get_file().get_basename() + "_tooltip.tres"
	
	ResourceSaver.save(tooltip_res, new_path)
	print("[TooltipGenerator] Succes ! Nouveau fichier cree: " + new_path)

func _format_attack(attack_comp, scaling) -> String:
	var bbcode = "[color=orange][b]- %s -[/b][/color]\n" % attack_comp.get_parent().name.capitalize()
	
	var dmg_str = "[b]%s[/b] Base" % attack_comp.base_damage
	if scaling.skill_type == 1:
		var mult = scaling.base_weapon_multiplier
		if mult > 0.0:
			dmg_str += " [b]+ %s%%[/b] Weapon Damage" % (mult * 100)
			
	bbcode += "Damage: " + dmg_str
	if scaling.is_aoe: bbcode += " [color=yellow](AoE)[/color]"
	bbcode += "\n"
	
	var elements = []
	if scaling.phys_ratio > 0: elements.append("[color=gray]" + str(scaling.phys_ratio * 100) + "% Physical[/color]")
	if scaling.fire_ratio > 0: elements.append("[color=orangered]" + str(scaling.fire_ratio * 100) + "% Fire[/color]")
	if scaling.ice_ratio > 0: elements.append("[color=cyan]" + str(scaling.ice_ratio * 100) + "% Ice[/color]")
	if scaling.lightning_ratio > 0: elements.append("[color=gold]" + str(scaling.lightning_ratio * 100) + "% Lightning[/color]")
	
	if elements.size() > 0:
		bbcode += "Damage Type: " + " / ".join(elements) + "\n"
		
	if attack_comp.knockback_force > 0:
		bbcode += "Knockback: " + str(attack_comp.knockback_force) + "\n"
		
	if "can_headshot" in attack_comp and attack_comp.can_headshot:
		bbcode += "[color=red]* Can Headshot[/color]\n"
		
	if "status_effects_to_apply" in attack_comp and attack_comp.status_effects_to_apply != null:
		for effect_app in attack_comp.status_effects_to_apply:
			if effect_app != null and effect_app.effect != null:
				bbcode += "Applies [b]%s[/b] (%s%% chance) for %ss\n" % [
					effect_app.effect.effect_id.capitalize(),
					effect_app.apply_chance * 100,
					effect_app.duration
				]
	bbcode += "\n"
	return bbcode

func _find_all_nodes(node: Node, class_name_str: String) -> Array:
	var result = []
	var script = node.get_script()
	if script != null and script.resource_path.get_file().begins_with("spell_scaling"):
		result.append(node)
	elif node.get_class() == class_name_str:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_nodes(child, class_name_str))
	return result

func _find_explosion_nodes(node: Node) -> Array:
	var result = []
	var script = node.get_script()
	if script != null and script.resource_path.get_file().begins_with("explosion-after"):
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_explosion_nodes(child))
	return result

func _find_buff_nodes(node: Node) -> Array:
	var result = []
	if "buff_data" in node and node.get("buff_data") != null:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_buff_nodes(child))
	return result
