class_name KnockbackComponent
extends Node

@export var stats_component: StatsComponent
@export var minimum_force_threshold: float = 0.0
@export var max_player_vertical_knockback: float = 9.5
@export var max_player_horizontal_knockback: float = 22.0
@export var max_enemy_vertical_knockback: float = 14.0

var target_body: Node3D

func _ready() -> void:
	target_body = get_parent()

func apply_knockback(push_direction: Vector3, raw_knockback_force: float) -> void:
	# Ne jamais appliquer de knockback à un joueur à terre ou intangible (ex: Spark Step)
	if target_body == null or target_body.get("is_dead") == true:
		return
	var hc: HealthComponent = target_body.get_node_or_null("HealthComponent") as HealthComponent
	if hc != null and hc.is_intangible:
		return
	
	# On accepte la direction envoyée par l'attaque (qui gère l'angle)
	if push_direction.length_squared() > 0.001:
		push_direction = push_direction.normalized()
	
	var resistance: float = 0.0
	if stats_component != null:
		var stat_val = stats_component.get_stat_value("knockback_resistance")
		if stat_val != null:
			resistance = stat_val
			
	var final_force = raw_knockback_force - resistance
	final_force = max(0.0, final_force)
	
	if final_force >= minimum_force_threshold:
		if target_body.is_multiplayer_authority():
			_apply_physics(push_direction, final_force)
		else:
			rpc_id(target_body.get_multiplayer_authority(), "_rpc_apply_physics", push_direction, final_force)

func _apply_physics(push_direction: Vector3, final_force: float) -> void:
	if target_body == null or target_body.get("is_dead") == true:
		return
	var hc: HealthComponent = target_body.get_node_or_null("HealthComponent") as HealthComponent
	if hc != null and hc.is_intangible:
		return
	if target_body is CharacterBody3D:
		var cb: CharacterBody3D = target_body as CharacterBody3D
		var impulse: Vector3 = push_direction * final_force
		if cb.is_in_group("Player"):
			var prev_horiz := Vector2(cb.velocity.x, cb.velocity.z)
			var next_horiz: Vector2 = prev_horiz + Vector2(impulse.x, impulse.z)
			var allowed_max_h: float = maxf(prev_horiz.length(), max_player_horizontal_knockback)
			if next_horiz.length() > allowed_max_h and next_horiz.length_squared() > 0.0001:
				next_horiz = next_horiz.normalized() * allowed_max_h
			cb.velocity.x = next_horiz.x
			cb.velocity.z = next_horiz.y
			if impulse.y > 0.0:
				cb.velocity.y = maxf(cb.velocity.y, minf(impulse.y, max_player_vertical_knockback))
			else:
				cb.velocity.y += impulse.y
		else:
			cb.velocity.x += impulse.x
			cb.velocity.z += impulse.z
			if impulse.y > 0.0:
				cb.velocity.y = maxf(cb.velocity.y, minf(impulse.y, max_enemy_vertical_knockback))
			else:
				cb.velocity.y += impulse.y
	elif target_body is RigidBody3D:
		target_body.apply_central_impulse(push_direction * final_force)

@rpc("any_peer", "call_local", "reliable")
func _rpc_apply_physics(push_direction: Vector3, final_force: float) -> void:
	if multiplayer.get_remote_sender_id() != 1 and multiplayer.get_remote_sender_id() != target_body.get_multiplayer_authority():
		# Vrifie que le sender est soit le serveur, soit qqun qui a le droit de nous frapper
		pass 
	_apply_physics(push_direction, final_force)


func apply_pull_displacement(step_offset: Vector3) -> void:
	if target_body == null or target_body.get("is_dead") == true:
		return
	var hc: HealthComponent = target_body.get_node_or_null("HealthComponent") as HealthComponent
	if hc != null and (hc.is_intangible or hc.current_health <= 0.0):
		return
	if step_offset.length_squared() < 0.000001:
		return
	if not multiplayer.has_multiplayer_peer() or target_body.is_multiplayer_authority():
		_internal_apply_pull(step_offset)
	else:
		rpc_id(target_body.get_multiplayer_authority(), "_rpc_apply_pull_displacement", step_offset)


func _internal_apply_pull(step_offset: Vector3) -> void:
	if target_body == null or not is_instance_valid(target_body) or target_body.get("is_dead") == true:
		return
	var hc: HealthComponent = target_body.get_node_or_null("HealthComponent") as HealthComponent
	if hc != null and (hc.is_intangible or hc.current_health <= 0.0):
		return
	var cb: CharacterBody3D = target_body as CharacterBody3D
	if cb != null:
		cb.move_and_collide(step_offset)


@rpc("any_peer", "call_local", "unreliable")
func _rpc_apply_pull_displacement(step_offset: Vector3) -> void:
	if target_body != null and target_body.is_multiplayer_authority():
		_internal_apply_pull(step_offset)
