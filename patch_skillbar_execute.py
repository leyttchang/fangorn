import os

path = 'Y:/Fangorn/fangorn/components/skill_bar_component.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# On va chercher le debut de _execute_ability
parts = content.split('func _execute_ability(ability: AbilityData, target_data: Dictionary) -> void:')
if len(parts) < 2:
    print("Erreur")
    exit()

before_execute = parts[0]
execute_and_after = parts[1]

# On separe a partir de _start_cooldown(ability) jusqu'a func _start_cooldown pour remplacer l'interieur
parts2 = execute_and_after.split('func _start_cooldown(ability: AbilityData) -> void:')

execute_body = parts2[0]
after_execute = 'func _start_cooldown(ability: AbilityData) -> void:' + parts2[1]

new_execute = '''
\tprint("Lancement reussi de : ", ability.ability_name)
\t_start_cooldown(ability)

\t# Consommation de la ressource
\tif current_casting_resource == CastingResource.MANA:
\t\tvar mana_comp = get_parent().get_node_or_null("ManaComponent")
\t\tif mana_comp == null: mana_comp = get_parent().get_node_or_null("mana_component")
\t\tif mana_comp != null:
\t\t\tmana_comp.use_mana(ability.mana_cost)
\telif current_casting_resource == CastingResource.HEALTH:
\t\tvar health_comp = get_parent().get_node_or_null("HealthComponent")
\t\tif health_comp == null: health_comp = get_parent().get_node_or_null("health_component")
\t\tif health_comp != null:
\t\t\thealth_comp.pay_health_cost(ability.mana_cost)
\t\t\thealth_spent_for_spell.emit(ability.mana_cost)

\tif ability.ability_scene != null:
\t\tvar spell_instance = null
\t\t
\t\tif ability.target_mode == AbilityData.TargetMode.COMPLEX_ATTACK and current_vfx_instance != null:
\t\t\t# Le sort est deja sur le terrain car instancie au debut de l'animation !
\t\t\tspell_instance = current_vfx_instance
\t\telse:
\t\t\t# Sort normal : on l'instancie maintenant
\t\t\tspell_instance = ability.ability_scene.instantiate()
\t\t\t
\t\t\tvar attack_comp = spell_instance.get_node_or_null("AttackComponent")
\t\t\tif attack_comp == null:
\t\t\t\tattack_comp = spell_instance.find_child("AttackComponent*", true, false)
\t\t\tif attack_comp != null:
\t\t\t\tattack_comp.set_meta("caster_authority", get_parent().get_multiplayer_authority())
\t\t\t\t
\t\t\tget_tree().root.add_child(spell_instance)
\t\t
\t\ttarget_data["ability_data"] = ability 
\t\t
\t\t# Placement au sol si necessaire
\t\tif ability.target_mode in [AbilityData.TargetMode.GROUND_TARGET, AbilityData.TargetMode.SUMMON]:
\t\t\tif target_data.has("impact_point"):
\t\t\t\tspell_instance.global_position = target_data["impact_point"]
\t\t
\t\t# IMPORTANT : EXECUTION POUR TOUS LES SORTS !
\t\tif spell_instance.has_method("execute"):
\t\t\tspell_instance.execute(get_parent(), target_data)
\t\t\t
\t\tvar impact = Vector3.ZERO
\t\tvar has_impact = false
\t\tif target_data.has("impact_point"):
\t\t\timpact = target_data["impact_point"]
\t\t\thas_impact = true
\t\t\t
\t\trpc("_rpc_spawn_spell_visual", ability.ability_scene.resource_path, get_parent().get_multiplayer_authority(), impact, has_impact)

'''

final = before_execute + 'func _execute_ability(ability: AbilityData, target_data: Dictionary) -> void:' + new_execute + after_execute
with open(path, 'w', encoding='utf-8') as f:
    f.write(final)

print("Execute rebuilt!")
