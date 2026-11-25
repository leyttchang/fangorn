class_name Stat
extends RefCounted

var base_value: float:
	set(val):
		base_value = val
		_is_dirty = true
var modifiers: Array[StatModifier] = []
var _cached_value: float = 0.0
var _is_dirty: bool = true

func _init(default_value: float = 0.0):
	base_value = default_value
	_is_dirty = true

func mark_dirty() -> void:
	_is_dirty = true

func has_modifier(modifier_id: String) -> bool:
	for mod in modifiers:
		if mod != null and mod.id == modifier_id:
			return true
	return false

# Ajouter un buff/debuff
func add_modifier(modifier: StatModifier) -> void:
	modifiers.append(modifier)
	_is_dirty = true

# Retirer un buff/debuff grâce à son ID
func remove_modifier(modifier_id: String) -> bool:
	var removed: bool = false
	for i in range(modifiers.size() - 1, -1, -1):
		if modifiers[i].id == modifier_id:
			modifiers.remove_at(i)
			removed = true
	if removed:
		_is_dirty = true
	return removed

func remove_modifiers_by_source(source_id: String) -> bool:
	return remove_modifier(source_id)

# La fonction magique qui calcule la valeur finale
func get_value() -> float:
	if not _is_dirty:
		return _cached_value

	var final_value: float = base_value
	var percent_multiplier: float = 0.0
	
	for mod in modifiers:
		if mod.type == StatModifier.Type.FLAT:
			# Ajout brut (ex: +10 dégâts)
			final_value += mod.value
		elif mod.type == StatModifier.Type.PERCENT:
			# Ajout en pourcentage (ex: +0.20 pour 20%)
			percent_multiplier += mod.value
			
	# On applique le pourcentage total à la fin
	_cached_value = final_value * (1.0 + percent_multiplier)
	_is_dirty = false
	return _cached_value

## Calcule la valeur finale en ignorant un modificateur spécifique (ex: bonus temporaire de route)
func get_value_excluding(excluded_id: String) -> float:
	var final_value = base_value
	var percent_multiplier = 0.0
	
	for mod in modifiers:
		if mod.id == excluded_id:
			continue
		if mod.type == StatModifier.Type.FLAT:
			final_value += mod.value
		elif mod.type == StatModifier.Type.PERCENT:
			percent_multiplier += mod.value
			
	return final_value * (1.0 + percent_multiplier)
