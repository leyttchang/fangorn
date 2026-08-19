with open("Y:/Fangorn/fangorn/components/skill_bar_component.gd", "r", encoding="utf-8") as f:
    content = f.read()

# Add enum and signal
old_vars = """var current_state: State = State.IDLE
var can_cast_spells: bool = true

# --- SIGNAUX ---
signal spells_updated"""

new_vars = """var current_state: State = State.IDLE
var can_cast_spells: bool = true

enum CastingResource { MANA, HEALTH }
var current_casting_resource: CastingResource = CastingResource.MANA

# --- SIGNAUX ---
signal spells_updated
signal health_spent_for_spell(amount: float)"""

content = content.replace(old_vars, new_vars)

# Replace handle_inputs mana check
old_check = """				# Vérification du mana
				var mana_comp = get_parent().get_node_or_null("ManaComponent")
				if mana_comp == null:
					mana_comp = get_parent().get_node_or_null("mana_component")
					
				if mana_comp != null and not mana_comp.has_enough_mana(ability.mana_cost):
					print(ability.ability_name, " : Pas assez de mana !")
					continue"""

new_check = """				# Vérification de la ressource (Mana ou Vie)
				var can_afford = false
				if current_casting_resource == CastingResource.MANA:
					var mana_comp = get_parent().get_node_or_null("ManaComponent")
					if mana_comp == null: mana_comp = get_parent().get_node_or_null("mana_component")
					if mana_comp != null:
						can_afford = mana_comp.has_enough_mana(ability.mana_cost)
				elif current_casting_resource == CastingResource.HEALTH:
					var health_comp = get_parent().get_node_or_null("HealthComponent")
					if health_comp == null: health_comp = get_parent().get_node_or_null("health_component")
					if health_comp != null:
						# Sécurité : la vie doit être strictement supérieure au coût pour ne pas se tuer
						can_afford = health_comp.current_health > ability.mana_cost
						
				if not can_afford:
					print(ability.ability_name, " : Pas assez de ressource (Mana/Vie) !")
					continue"""

content = content.replace(old_check, new_check)

# Replace execute_ability consumption
old_consume = """	# Consommation du mana
	var mana_comp = get_parent().get_node_or_null("ManaComponent")
	if mana_comp == null:
		mana_comp = get_parent().get_node_or_null("mana_component")
		
	if mana_comp != null:
		mana_comp.use_mana(ability.mana_cost)"""

new_consume = """	# Consommation de la ressource
	if current_casting_resource == CastingResource.MANA:
		var mana_comp = get_parent().get_node_or_null("ManaComponent")
		if mana_comp == null: mana_comp = get_parent().get_node_or_null("mana_component")
		if mana_comp != null:
			mana_comp.use_mana(ability.mana_cost)
	elif current_casting_resource == CastingResource.HEALTH:
		var health_comp = get_parent().get_node_or_null("HealthComponent")
		if health_comp == null: health_comp = get_parent().get_node_or_null("health_component")
		if health_comp != null:
			health_comp.pay_health_cost(ability.mana_cost)
			health_spent_for_spell.emit(ability.mana_cost)"""

content = content.replace(old_consume, new_consume)

with open("Y:/Fangorn/fangorn/components/skill_bar_component.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated skill_bar_component.gd")
