extends Label3D

var total_damage: float = 0.0
var original_y: float = 0.0
var target_y: float = 0.0
var active_tween: Tween = null

func start_animation(amount: float) -> void:
	total_damage = amount
	original_y = position.y
	target_y = original_y + 1.5
	_update_visuals()

func add_damage(amount: float, new_pos: Vector3 = Vector3.ZERO) -> void:
	total_damage += amount
	
	if new_pos != Vector3.ZERO:
		var pos_tween = create_tween()
		pos_tween.set_parallel(true)
		# Le texte glisse de facon elastique et tres rapide vers la nouvelle position
		pos_tween.tween_property(self, "global_position:x", new_pos.x, 0.15).set_ease(Tween.EASE_OUT)
		pos_tween.tween_property(self, "global_position:z", new_pos.z, 0.15).set_ease(Tween.EASE_OUT)
		
	_update_visuals()
	
	# Petit effet de "pop" satisfaisant
	scale = Vector3(1.5, 1.5, 1.5)
	var pop_tween = create_tween()
	pop_tween.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT)

func _update_visuals() -> void:
	text = "%.1f" % total_damage
	
	# On detruit l'ancienne animation
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
		
	modulate.a = 1.0
	
	active_tween = create_tween()
	active_tween.set_parallel(true)
	
	# Il continue de monter vers target_y (qui est fixe, donc il ne monte pas a l'infini !)
	active_tween.tween_property(self, "position:y", target_y, 1.0).set_ease(Tween.EASE_OUT)
	# Il reste invisible pendant 0.5s, puis disparait en 0.5s
	active_tween.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.5)
	
	active_tween.chain().tween_callback(queue_free)
