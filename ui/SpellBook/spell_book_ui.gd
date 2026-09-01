class_name SpellBookUI
extends CanvasLayer

@export var skill_bar: SkillBarComponent
# La liste de tous les sorts que le joueur a débloqués (à remplir dans l'inspecteur)
@export var unlocked_spells: Array[AbilityData] 

@onready var u_grid = %inv_grid
@onready var unlock_btn: Button = find_child("UnlockAllButton", true, false)

func _ready() -> void:
	visible = false
	if skill_bar == null:
		push_error("SpellBookUI : SkillBarComponent manquant.")
		return
		
	_setup_inventory_slots()

	if unlock_btn != null:
		if not unlock_btn.pressed.is_connected(unlock_all_spells):
			unlock_btn.pressed.connect(unlock_all_spells)

func unlock_all_spells() -> void:
	print("Bouton cliqué : Déblocage de tous les sorts...")
	var all_spells = GameData.get_all_spells()
	for spell_res in all_spells:
		if spell_res != null:
			unlock_spell(spell_res)
	_setup_inventory_slots()
	print("Tous les sorts du jeu ont été débloqués !")

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
	if ability == null: return false
	
	# Appel le RPC pour tout le monde (surtout le client concern?)
	rpc("_rpc_unlock_spell", ability.resource_path)
	return true

@rpc("authority", "call_local", "reliable")
func _rpc_unlock_spell(ability_path: String) -> void:
	var ability = load(ability_path) as AbilityData
	if ability == null: return
	
	for s in unlocked_spells:
		if s != null and (s == ability or s.ability_name == ability.ability_name):
			return
			
	unlocked_spells.append(ability)
	_setup_inventory_slots()

func open_spellbook() -> void:
	visible = true
	
func close_spellbook() -> void:
	visible = false
