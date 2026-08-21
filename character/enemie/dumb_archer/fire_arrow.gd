extends RigidBody3D

@export var lifespan: float = 20.0
@export var stick_duration: float = 10.0

@onready var attack_component: AttackComponent = $AttackComponent

var _has_impacted: bool = false

func _ready() -> void:
	if attack_component != null:
		attack_component.attack_landed.connect(_on_attack_landed)
	
	# Destruction après la durée de vie max si elle n'a rien touché
	await get_tree().create_timer(lifespan).timeout
	if is_instance_valid(self) and not _has_impacted:
		if is_inside_tree() and multiplayer.is_server():
			queue_free()

func execute(caster: Node3D, target_data: Dictionary) -> void:
	# On fouille dans tous les composants attachés à ce sort
	for child in get_children():
		# Si le composant a une fonction "on_execute", on l'appelle !
		if child.has_method("on_execute"):
			child.on_execute(caster, target_data)

func _on_attack_landed(target: Node) -> void:
	if _has_impacted:
		return
	_has_impacted = true

	var is_character = false
	if target is HitboxComponent:
		if target.get_parent() is CharacterBody3D:
			is_character = true
	elif target is CharacterBody3D:
		is_character = true

	if is_character:
		# Si on touche un personnage (joueur ou autre), la flche se dtruit immdiatement
		if is_inside_tree() and multiplayer.is_server():
			queue_free()
		return

	# 1. Stopper la physique et dsactiver la collision principale du projectile (si on touche le dcor)
	freeze = true
	sleeping = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	set_physics_process(false)
	
	var col = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col != null:
		col.set_deferred("disabled", true)

	# 2. Dsactiver la Hurtbox / AttackComponent pour viter d'infliger des dgts  nouveau
	if attack_component != null:
		attack_component.set_deferred("monitoring", false)
		attack_component.set_deferred("monitorable", false)
		var attack_col = attack_component.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if attack_col != null:
			attack_col.set_deferred("disabled", true)

	# 3. Faire disparatre la flche aprs 10 secondes (si elle est dans un mur)
	await get_tree().create_timer(stick_duration).timeout
	if is_instance_valid(self):
		if is_inside_tree() and multiplayer.is_server():
			queue_free()
