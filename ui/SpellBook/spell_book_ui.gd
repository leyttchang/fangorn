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
		# Inverse la visibilité (si c'est caché ça s'affiche, si c'est affiché ça se cache)
		visible = !visible
		
		# Bonus : Libérer ou capturer la souris pour ton jeu 3D !
		if visible:
			# Le grimoire est ouvert : on libère la souris pour pouvoir cliquer
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			# Le grimoire est fermé : on recache la souris pour tourner la caméra
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
