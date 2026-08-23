class_name ChillEffectData
extends StatusEffectData

@export_group("Combo Glace")
@export var freeze_effect: StatusEffectData
@export var freeze_duration: float = 3.0

func on_apply(target: Node, component: Node, is_refresh: bool) -> void:
	# is_refresh est "vrai" si le monstre avait DEJA le statut Chill
	
	if is_refresh and freeze_effect != null:
		# 1. On retire le chill car il va etre gelee
		component.call_deferred("remove_effect", effect_id)
		
		# 2. On applique le Freeze
		component.call_deferred("apply_effect", freeze_effect, freeze_duration)
