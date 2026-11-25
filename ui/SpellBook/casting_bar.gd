class_name CastingBarUI
extends CanvasLayer

@export var skill_bar: SkillBarComponent

@onready var progress_bar: TextureProgressBar = $Control/Spell_casting_completion


func _ready() -> void:
	visible = false

	if skill_bar == null:
		var p: Node = owner
		while p != null:
			if p is CharacterBody3D and p.is_in_group("Player"):
				skill_bar = p.get_node_or_null("SkillBarComponent") as SkillBarComponent
				break
			p = p.owner if p.owner != null else p.get_parent()

	if skill_bar == null:
		push_error("CastingBar : Le SkillBarComponent n'est pas assigné dans l'inspecteur.")
		return

	skill_bar.cast_started.connect(_on_cast_started)
	skill_bar.cast_updated.connect(_on_cast_updated)
	skill_bar.cast_canceled.connect(_on_cast_ended)
	skill_bar.cast_finished.connect(_on_cast_ended)

	if skill_bar.has_signal("channel_started"):
		skill_bar.channel_started.connect(_on_channel_started)
	if skill_bar.has_signal("channel_updated"):
		skill_bar.channel_updated.connect(_on_channel_updated)


func _on_cast_started(_ability_name: String, max_time: float) -> void:
	visible = true
	progress_bar.max_value = maxf(0.01, max_time)
	progress_bar.value = 0.0
	progress_bar.tint_progress = Color(1.0, 1.0, 1.0)


func _on_cast_updated(current_time: float, max_time: float) -> void:
	progress_bar.value = current_time
	if current_time >= max_time:
		progress_bar.tint_progress = Color(0.2, 1.0, 0.2)


func _on_channel_started(_ability_name: String, max_duration: float) -> void:
	visible = true
	if max_duration > 0.0:
		progress_bar.max_value = max_duration
		progress_bar.value = max_duration
	else:
		progress_bar.max_value = 1.0
		progress_bar.value = 1.0
	progress_bar.tint_progress = Color(0.45, 0.88, 1.0, 1.0)


func _on_channel_updated(elapsed: float, max_duration: float, resource_ratio: float) -> void:
	var pulse: float = 0.85 + 0.15 * sin(elapsed * 10.0)
	progress_bar.tint_progress = Color(0.42 * pulse, 0.88 * pulse, 1.0, 1.0)
	if max_duration > 0.0:
		progress_bar.max_value = max_duration
		progress_bar.value = maxf(0.0, max_duration - elapsed)
	else:
		progress_bar.max_value = 1.0
		progress_bar.value = clampf(resource_ratio, 0.0, 1.0)


func _on_cast_ended() -> void:
	visible = false
