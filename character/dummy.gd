extends CharacterBody3D

var damage_text_scene = preload("res://ui/damage_text.tscn")

@onready var health_component: HealthComponent = $HealthComponent

# On récupère la force de gravité définie dans les paramètres du projet Godot
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- DPS TRACKING ---
var total_damage_taken: float = 0.0
var dps_phase_active: bool = false
var phase_time_remaining: float = 0.0

var timer_label: Label3D

func _ready() -> void:
	health_component.damage_taken.connect(_on_damage_taken)
	health_component.died.connect(_on_died)
	
	# Création du label pour le chronomètre (caché par défaut)
	timer_label = Label3D.new()
	timer_label.modulate = Color.WHITE
	timer_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	timer_label.font_size = 48
	timer_label.outline_size = 8
	timer_label.position.y = 2.5
	timer_label.visible = false
	add_child(timer_label)
	
func _physics_process(delta: float) -> void:
	if dps_phase_active:
		phase_time_remaining -= delta
		timer_label.text = str(snapped(phase_time_remaining, 0.1)) + "s"
		
		if phase_time_remaining <= 0.0:
			_end_dps_phase()

	# 1. On applique la gravité si l'entité n'est pas sur le sol
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Le moteur lit la vélocité et déplace le corps
	move_and_slide()
	
	# 3. Le freinage (Friction)
	# On freine UNIQUEMENT les axes X et Z pour ne pas annuler la chute (axe Y)
	velocity.x = move_toward(velocity.x, 0, 5.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 5.0 * delta)
	
	# (Alternative avec lerp si tu préfères un freinage plus "glissant") :
	# velocity.x = lerp(velocity.x, 0.0, 5.0 * delta)
	# velocity.z = lerp(velocity.z, 0.0, 5.0 * delta)


func _on_damage_taken(amount: float) -> void:
	var text_instance = damage_text_scene.instantiate()
	add_child(text_instance)
	text_instance.position.y = 1.0 
	text_instance.animate(amount)
	
	total_damage_taken += amount
	
	if not dps_phase_active:
		dps_phase_active = true
		phase_time_remaining = 10.0
		timer_label.visible = true

func _end_dps_phase() -> void:
	dps_phase_active = false
	timer_label.visible = false
	
	var dps: float = total_damage_taken / 10.0
		
	# Afficher le DPS
	var dps_label = Label3D.new()
	dps_label.text = "DPS: " + str(round(dps))
	dps_label.modulate = Color(1.0, 1.0, 0.0) # Jaune
	dps_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dps_label.font_size = 64
	dps_label.outline_size = 12
	dps_label.position.y = 2.5 # À la même hauteur que le timer
	add_child(dps_label)
	
	# Le faire disparaître au bout de 10 secondes
	var tween = create_tween()
	tween.tween_interval(10.0)
	tween.tween_property(dps_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(dps_label.queue_free)
	
	# Réinitialisation pour la prochaine salve
	total_damage_taken = 0.0

func _on_died() -> void:
	queue_free()
