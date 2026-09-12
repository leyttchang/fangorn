@tool
extends Control

@export var health_component: HealthComponent
@export var scroll_speed: Vector2 = Vector2(0.5, -0.5)

@onready var liquide: TextureRect = %liquid_health
var current_uv_offset: Vector2 = Vector2.ZERO
var info_label: Label

func _ready() -> void:
	# En mode editeur, on evite de lancer la logique du joueur
	if Engine.is_editor_hint():
		return
		
	if health_component == null:
		var p = owner
		while p != null:
			if p is CharacterBody3D and p.is_in_group("Player"):
				health_component = p.get_node_or_null("HealthComponent")
				break
			p = p.owner if p.owner != null else p.get_parent()
	if health_component != null:
		var max_hp = health_component.stats_component.get_stat_value("max_health")
		var health_percent = health_component.current_health / max_hp
		liquide.material.set_shader_parameter("health_percent", health_percent)
		
		# Tooltip
		self.tooltip_text = str(int(health_component.current_health)) + " / " + str(int(max_hp))
		
		# Creation du Label pour "show_info"
		info_label = Label.new()
		info_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		info_label.visible = false
		info_label.add_theme_color_override("font_color", Color.WHITE)
		info_label.add_theme_color_override("font_outline_color", Color.BLACK)
		info_label.add_theme_constant_override("outline_size", 4)
		info_label.text = self.tooltip_text
		add_child(info_label)
		
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
	
	if info_label != null:
		if Input.is_action_pressed("show_info"):
			info_label.visible = true
			info_label.text = self.tooltip_text
		else:
			info_label.visible = false

func _on_health_changed(current_health: float, max_health: float) -> void:
	if not is_inside_tree() or Engine.is_editor_hint():
		return
		
	# Maj du tooltip
	self.tooltip_text = str(int(current_health)) + " / " + str(int(max_health))
		
	var target_percent = current_health / max_health
	var tween = create_tween()
	var current_percent = liquide.material.get_shader_parameter("health_percent")
	
	tween.tween_method(
		func(val: float): liquide.material.set_shader_parameter("health_percent", val),
		current_percent,
		target_percent,
		0.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
