class_name SpellBookUI
extends CanvasLayer

@export var skill_bar: SkillBarComponent
# La liste de tous les sorts que le joueur a débloqués (à remplir dans l'inspecteur)
@export var unlocked_spells: Array[AbilityData] 

@onready var u_grid = $MainPanel/inventaire/inv_grid
@onready var e_grid = $MainPanel/equipe/inv_grid

func _ready() -> void:
	if skill_bar == null:
		push_error("SpellBookUI : SkillBarComponent manquant.")
		return
		
	_setup_inventory_slots()
	_setup_equipment_slots()
	
	# On écoute les changements pour rafraîchir l'affichage instantanément
	skill_bar.spells_updated.connect(_refresh_equipment_visuals)
	_refresh_equipment_visuals()

# Remplit la grande liste de droite avec les sorts débloqués
func _setup_inventory_slots() -> void:
	var u_slots = u_grid.get_children()
	for i in range(u_slots.size()):
		if i < unlocked_spells.size():
			u_slots[i].set_ability(unlocked_spells[i])
		else:
			u_slots[i].set_ability(null)

# Débloque un nouveau sort s'il n'est pas déjà possédé
func unlock_spell(ability: AbilityData) -> bool:
	if ability == null:
		return false
	for s in unlocked_spells:
		if s != null and (s == ability or s.ability_name == ability.ability_name):
			return false
			
	unlocked_spells.append(ability)
	_setup_inventory_slots()
	return true

# Prépare les 6 cases de gauche (assignation des noms et du lien vers le joueur)
func _setup_equipment_slots() -> void:
	var e_slots = e_grid.get_children()
	for i in range(e_slots.size()):
		var slot_key = "slot_" + str(i + 1)
		e_slots[i].slot_name = slot_key
		e_slots[i].skill_bar = skill_bar

# Met à jour les images de gauche quand un sort est équipé/déséquipé
func _refresh_equipment_visuals() -> void:
	var e_slots = e_grid.get_children()
	for i in range(e_slots.size()):
		var slot_key = "slot_" + str(i + 1)
		if skill_bar.slots.has(slot_key):
			e_slots[i].set_ability(skill_bar.slots[slot_key])
# On écoute les touches pressées par le joueur
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_spellbook"):
		_set_spellbook_visible(!visible)
	elif visible:
		if (event is InputEventKey and event.physical_keycode == KEY_TAB and event.pressed) or event.is_action_pressed("toggle_inventory"):
			_set_spellbook_visible(false)

func _set_spellbook_visible(is_vis: bool) -> void:
	visible = is_vis
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
