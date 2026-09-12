@tool
class_name ManaBarUI
extends Control

@export var mana_component: Node 
@export var scroll_speed: Vector2 = Vector2(0.5, -0.5)

@onready var liquide: TextureRect = %liquid_mana
var current_uv_offset: Vector2 = Vector2.ZERO
var info_label: Label

func _ready() -> void:
	if Engine.is_editor_hint():
		return
		
	if mana_component == null:
		var p = owner
		while p != null:
			if p is CharacterBody3D and p.is_in_group("Player"):
				mana_component = p.get_node_or_null("ManaComponent")
				if mana_component == null:
					mana_component = p.get_node_or_null("mana_component")
				break
			p = p.owner if p.owner != null else p.get_parent()
			
	if mana_component != null:
		mana_component.mana_changed.connect(_on_mana_changed)
		
		# Initialisation
		if mana_component.has_method("get_max_mana"):
			var max_mana = mana_component.get_max_mana()
			if max_mana > 0:
				liquide.material.set_shader_parameter("health_percent", mana_component.current_mana / max_mana)
				self.tooltip_text = str(int(mana_component.current_mana)) + " / " + str(int(max_mana))
		else:
			# Fallback if there is no get_max_mana but there is stats_component
			if mana_component.stats_component != null:
				var max_mana = mana_component.stats_component.get_stat_value("max_mana")
				liquide.material.set_shader_parameter("health_percent", mana_component.current_mana / max_mana)
				self.tooltip_text = str(int(mana_component.current_mana)) + " / " + str(int(max_mana))
				
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
	else:
		push_error("ManaBarUI : Impossible de trouver le ManaComponent du joueur !")

func _process(delta: float) -> void:
	if liquide == null:
		return
		
	current_uv_offset += scroll_speed * delta
	current_uv_offset.x = wrapf(current_uv_offset.x, 0.0, 1.0)
	current_uv_offset.y = wrapf(current_uv_offset.y, 0.0, 1.0)
	liquide.material.set_shader_parameter("current_offset", current_uv_offset)

	if info_label != null:
		if Input.is_action_pressed("show_info"):
			info_label.visible = true
			info_label.text = self.tooltip_text
		else:
			info_label.visible = false

func _on_mana_changed(current_mana: float, max_mana: float) -> void:
	if not is_inside_tree() or Engine.is_editor_hint():
		return
		
	# Maj du tooltip
	self.tooltip_text = str(int(current_mana)) + " / " + str(int(max_mana))
		
	var target_percent = 0.0
	if max_mana > 0:
		target_percent = current_mana / max_mana
		
	var tween = create_tween()
	var current_percent = liquide.material.get_shader_parameter("health_percent")
	if current_percent == null:
		current_percent = 1.0
		
	tween.tween_method(
		func(val: float): liquide.material.set_shader_parameter("health_percent", val),
		current_percent,
		target_percent,
		0.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
