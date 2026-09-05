@tool
extends Control

@export var health_component: HealthComponent
@export var scroll_speed: Vector2 = Vector2(0.5, -0.5)

@onready var liquide: TextureRect = %liquid_health
var current_uv_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	# En mode editeur, on evite de lancer la logique du joueur
	if Engine.is_editor_hint():
		return
		
	if health_component == null:
		var player = get_tree().get_first_node_in_group("Player")
		if player != null and player.owner != null and not player.has_node("HealthComponent"):
			player = player.owner
		if player == null:
			player = owner
		if player != null:
			health_component = player.get_node_or_null("HealthComponent")
			
	if health_component != null:
		var max_hp = health_component.stats_component.get_stat_value("max_health")
		var health_percent = health_component.current_health / max_hp
		liquide.material.set_shader_parameter("health_percent", health_percent)
		health_component.health_changed.connect(_on_health_changed)
	else:
		push_warning("Attention : Aucun HealthComponent n'est assigne a la barre de vie " + name)

func _process(delta: float) -> void:
	# Securite si le noeud n'est pas encore pret dans l'editeur
	if liquide == null:
		return
		
	# Calcule l'avancement fluide sans saccade (tourne dans l'editeur et en jeu !)
	current_uv_offset += scroll_speed * delta
	
	# Boucle a l'infini entre 0 et 1 pour preserver la precision des shaders (evite les saccades au bout de 2h de jeu)
	current_uv_offset.x = wrapf(current_uv_offset.x, 0.0, 1.0)
	current_uv_offset.y = wrapf(current_uv_offset.y, 0.0, 1.0)
	
	liquide.material.set_shader_parameter("current_offset", current_uv_offset)

func _on_health_changed(current_health: float, max_health: float) -> void:
	if not is_inside_tree() or Engine.is_editor_hint():
		return
		
	var target_percent = current_health / max_health
	var tween = create_tween()
	var current_percent = liquide.material.get_shader_parameter("health_percent")
	
	tween.tween_method(
		func(val: float): liquide.material.set_shader_parameter("health_percent", val),
		current_percent,
		target_percent,
		0.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
