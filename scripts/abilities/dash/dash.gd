extends Node3D

@export var dash_speed: float = 25.0 
@export var dash_duration: float = 0.25 # Un peu plus long pour une roulade
@export var effect_duration: float = 1.0 

@onready var particles = $GPUParticles3D
@onready var audio = $AudioStreamPlayer3D 

var is_dashing: bool = false
var dash_target: CharacterBody3D = null
var dash_direction: Vector3 = Vector3.ZERO
var dash_timer: float = 0.0

func execute(caster: Node3D, target_data: Dictionary) -> void:
	global_position = caster.global_position
	
	if caster is CharacterBody3D:
		dash_target = caster
		
		# 1. On isole le mouvement horizontal du joueur (sans tenir compte des sauts/chutes)
		var horizontal_velocity = Vector3(caster.velocity.x, 0.0, caster.velocity.z)
		
		# 2. On vérifie si le joueur est en train de bouger
		# (S'il marche, la longueur du vecteur sera supérieure à zéro)
		if horizontal_velocity.length() > 0.1:
			# Il bouge : la direction du dash devient la direction de sa course
			dash_direction = horizontal_velocity.normalized()
		else:
			# Il est à l'arrêt : on dash vers l'avant (par rapport à sa rotation)
			dash_direction = -caster.global_transform.basis.z.normalized()
			dash_direction.y = 0.0 
			dash_direction = dash_direction.normalized() 
		
		is_dashing = true
	
	if particles != null:
		particles.emitting = true
	if audio != null:
		audio.play()
	
	await get_tree().create_timer(effect_duration).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	if is_dashing and dash_target != null:
		# On maintient l'effet visuel sur le joueur
		global_position = dash_target.global_position
		
		dash_timer += delta
		if dash_timer < dash_duration:
			# Pendant la durée : on impose une vitesse stricte
			dash_target.velocity = dash_direction * dash_speed
			dash_target.move_and_slide()
		else:
			# FIN DU DASH : On écrase la vélocité à zéro pour stopper net l'inertie
			dash_target.velocity = Vector3.ZERO
			is_dashing = false
