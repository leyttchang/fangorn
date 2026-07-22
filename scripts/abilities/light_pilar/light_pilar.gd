extends Node3D

@onready var omni_light = $OmniLight3D
@onready var anim_player = $OmniLight3D/AnimationPlayer
@onready var particles = $chest_particule/aura_glow_effect/particles
@onready var aura = $chest_particule/aura_glow_effect

func _ready() -> void:
	# On s'assure que la lumière brille
	if anim_player and anim_player.has_animation("glow"):
		anim_player.play("glow")
		
	# On lance le compte à rebours de 15 secondes
	var timer = get_tree().create_timer(15.0)
	timer.timeout.connect(_on_timer_timeout)

func _on_timer_timeout() -> void:
	# 1. On empêche l'AnimationPlayer de toucher à la lumière pendant qu'on l'éteint
	if anim_player:
		anim_player.stop()
		
	# 2. On coupe le générateur de particules
	if particles:
		particles.emitting = false
		
	# 3. On utilise un Tween pour faire baisser la lumière progressivement sur 2 secondes
	var tween = create_tween()
	tween.set_parallel(true) # Pour animer plusieurs choses en même temps
	
	if omni_light:
		tween.tween_property(omni_light, "light_energy", 0.0, 2.0)
		
	# (Optionnel) Si l'aura a une transparence dans son shader
	if aura and aura.material_override:
		var mat = aura.material_override as ShaderMaterial
		if mat:
			tween.tween_property(mat, "shader_parameter/fading_param", 0.0, 2.0)
			
	# 4. Quand les 2 secondes de fondu sont terminées, on supprime le pilier proprement !
	tween.chain().tween_callback(queue_free)
