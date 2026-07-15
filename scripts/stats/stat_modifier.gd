class_name StatModifier
extends RefCounted

# On définit les deux types de modificateurs possibles
enum Type { FLAT, PERCENT }

var id: String
var value: float
var type: Type

# Le constructeur : ce qui est appelé quand on fait StatModifier.new(...)
func _init(p_id: String, p_value: float, p_type: Type):
	id = p_id
	value = p_value
	type = p_type
