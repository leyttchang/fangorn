class_name StatusEffectApplication
extends Resource

@export var effect: StatusEffectData
@export var duration: float = 5.0
@export_range(0.0, 1.0) var apply_chance: float = 1.0
