extends CanvasLayer

@export var health_component: HealthComponent

@onready var liquide: TextureRect = $MarginContainer/Health_bar/mask/liquid

func _ready() -> void:
	if health_component != null:
		# Initialise la barre
		var max_hp = health_component.stats_component.get_stat_value("max_health")
		var health_percent = health_component.current_health / max_hp
		liquide.material.set_shader_parameter("health_percent", health_percent)
		
		# Connecte le signal
		health_component.health_changed.connect(_on_health_changed)
	else:
		push_warning("Attention : Aucun HealthComponent n'est assigne a la barre de vie " + name)


func _on_health_changed(current_health: float, max_health: float) -> void:
	if not is_inside_tree():
		return
		
	var target_percent = current_health / max_health
	
	# Animation fluide du shader parameter (tween_method est parfait pour ca)
	var tween = create_tween()
	var current_percent = liquide.material.get_shader_parameter("health_percent")
	
	tween.tween_method(
		func(val: float): liquide.material.set_shader_parameter("health_percent", val),
		current_percent,
		target_percent,
		0.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
