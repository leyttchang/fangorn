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

	# 1. Stopper la physique et désactiver la collision principale du projectile
	freeze = true
	sleeping = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	set_physics_process(false)
	
	var col = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col != null:
		col.set_deferred("disabled", true)

	# 2. Désactiver la Hurtbox / AttackComponent pour éviter d'infliger des dégâts à nouveau
	if attack_component != null:
		attack_component.set_deferred("monitoring", false)
		attack_component.set_deferred("monitorable", false)
		var attack_col = attack_component.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if attack_col != null:
			attack_col.set_deferred("disabled", true)

	# 3. Reparenter la flèche (en différé call_deferred pour ne pas bloquer le serveur de physique Godot)
	if is_instance_valid(target) and target.is_inside_tree():
		var parent_node: Node3D = null
		if target is HitboxComponent:
			parent_node = target.get_parent() as Node3D
		elif target is Node3D:
			parent_node = target as Node3D
			
		if parent_node != null and is_instance_valid(parent_node) and parent_node.is_inside_tree():
			call_deferred("reparent", parent_node, true)

	# 4. Faire disparaître la flèche après 10 secondes
	await get_tree().create_timer(stick_duration).timeout
	if is_instance_valid(self):
		queue_free()
