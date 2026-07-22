extends Node3D

@export var health_component: HealthComponent
@onready var animation_player: AnimationPlayer = $MeshInstance3D/AnimationPlayer

func _ready() -> void:
	if health_component != null:
		health_component.damage_taken.connect(_on_damage_taken)
	else:
		push_warning("DamageScreenEffect: Aucun HealthComponent assigné dans l'inspecteur !")

func _on_damage_taken(_amount: float) -> void:
	# On relance l'animation depuis le début si le joueur se prend un nouveau coup pendant qu'elle joue
	animation_player.stop()
	animation_player.play("hurt")
