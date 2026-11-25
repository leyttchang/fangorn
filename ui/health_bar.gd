@tool
extends Control

@export var health_component: HealthComponent
@export var scroll_speed: Vector2 = Vector2(0.5, -0.5)

@onready var liquide: TextureRect = %liquid_health
var current_uv_offset: Vector2 = Vector2.ZERO
var info_label: Label = null
var shield_label: Label = null
var _frame_rect: TextureRect = null
var _bar_tween: Tween = null
var _last_hp: float = 100.0
var _last_max_hp: float = 100.0
var _last_shield: float = 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_frame_rect = get_node_or_null("Health_bar/frame") as TextureRect

	if health_component == null:
		var p: Node = owner
		while p != null:
			if p is CharacterBody3D and p.is_in_group("Player"):
				health_component = p.get_node_or_null("HealthComponent") as HealthComponent
				break
			p = p.owner if p.owner != null else p.get_parent()

	if health_component != null:
		var max_hp: float = health_component.get_max_health()
		_last_hp = health_component.current_health
		_last_max_hp = max_hp
		_last_shield = health_component.current_shield
		var health_percent: float = (_last_hp / max_hp) if max_hp > 0.0 else 1.0
		if liquide != null and liquide.material != null:
			(liquide.material as ShaderMaterial).set_shader_parameter("health_percent", health_percent)

		# Label "show_info"
		info_label = Label.new()
		info_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		info_label.visible = false
		info_label.add_theme_color_override("font_color", Color.WHITE)
		info_label.add_theme_color_override("font_outline_color", Color.BLACK)
		info_label.add_theme_constant_override("outline_size", 4)
		add_child(info_label)

		# Badge de Bouclier permanent tant qu'un bouclier est actif
		shield_label = Label.new()
		shield_label.name = "ShieldBadge"
		shield_label.position = Vector2(512.0, -52.0)
		shield_label.custom_minimum_size = Vector2(96.0, 26.0)
		shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shield_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		shield_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shield_label.add_theme_font_size_override("font_size", 16)
		shield_label.add_theme_color_override("font_color", Color(0.52, 0.94, 1.0, 1.0))
		shield_label.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.14, 0.96))
		shield_label.add_theme_constant_override("outline_size", 5)
		shield_label.visible = false
		add_child(shield_label)

		_refresh_text_and_shield_visuals()

		health_component.health_changed.connect(_on_health_changed)
		if health_component.has_signal("shield_changed"):
			health_component.shield_changed.connect(_on_shield_changed)
	else:
		push_warning("Attention : Aucun HealthComponent n'est assigne a la barre de vie " + name)


func _process(delta: float) -> void:
	if liquide == null or liquide.material == null:
		return

	current_uv_offset += scroll_speed * delta
	current_uv_offset.x = wrapf(current_uv_offset.x, 0.0, 1.0)
	current_uv_offset.y = wrapf(current_uv_offset.y, 0.0, 1.0)
	(liquide.material as ShaderMaterial).set_shader_parameter("current_offset", current_uv_offset)

	if info_label != null and not Engine.is_editor_hint():
		var show_it: bool = Input.is_action_pressed("show_info")
		if info_label.visible != show_it:
			info_label.visible = show_it
		if show_it and info_label.text != self.tooltip_text:
			info_label.text = self.tooltip_text


func _refresh_text_and_shield_visuals() -> void:
	var base_txt: String = "%d / %d" % [int(roundf(_last_hp)), int(roundf(_last_max_hp))]
	if _last_shield > 0.5:
		var sh_int: int = int(ceilf(_last_shield))
		self.tooltip_text = "%s (+%d Shield)" % [base_txt, sh_int]
		if shield_label != null:
			shield_label.text = "+%d SHIELD" % sh_int
			shield_label.visible = true
		if _frame_rect != null:
			_frame_rect.self_modulate = Color(0.58, 0.94, 1.0, 1.0)
	else:
		self.tooltip_text = base_txt
		if shield_label != null:
			shield_label.visible = false
		if _frame_rect != null:
			_frame_rect.self_modulate = Color.WHITE

	if info_label != null:
		info_label.text = self.tooltip_text


func _on_health_changed(current_health: float, max_health: float) -> void:
	if not is_inside_tree() or Engine.is_editor_hint():
		return

	_last_hp = current_health
	_last_max_hp = max_health
	_refresh_text_and_shield_visuals()

	var target_percent: float = (current_health / max_health) if max_health > 0.0 else 0.0
	if _bar_tween != null and _bar_tween.is_valid():
		_bar_tween.kill()
	_bar_tween = create_tween()
	var sh_mat: ShaderMaterial = liquide.material as ShaderMaterial
	if sh_mat == null:
		return
	var raw_cur: Variant = sh_mat.get_shader_parameter("health_percent")
	var current_percent: float = float(raw_cur) if raw_cur != null else 1.0

	_bar_tween.tween_method(
		func(val: float) -> void: sh_mat.set_shader_parameter("health_percent", val),
		current_percent,
		target_percent,
		0.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_shield_changed(current_shield: float, max_health: float) -> void:
	if not is_inside_tree() or Engine.is_editor_hint():
		return
	_last_shield = current_shield
	if max_health > 0.0:
		_last_max_hp = max_health
	_refresh_text_and_shield_visuals()
