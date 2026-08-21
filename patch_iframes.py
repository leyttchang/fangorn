# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/hitbox_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

new_content = '''class_name HitboxComponent
extends Area3D

@export var health_component: HealthComponent
@export var knockback_component: KnockbackComponent

var is_invincible: bool = false
var invincibility_timer: Timer

func _ready() -> void:
	if health_component == null:
		push_warning("HitboxComponent sur " + get_parent().name + " n'a pas de HealthComponent assign? !")
		
	invincibility_timer = Timer.new()
	invincibility_timer.wait_time = 0.5
	invincibility_timer.one_shot = true
	invincibility_timer.timeout.connect(func(): is_invincible = false)
	add_child(invincibility_timer)

func receive_hit(attack: AttackComponent) -> void:
	if is_invincible:
		return
		
	is_invincible = true
	invincibility_timer.start()

	if health_component != null:
		health_component.take_damage(attack.damage)
		
	if knockback_component != null:
		var push_dir: Vector3
		if attack.is_projectile:
			push_dir = -attack.global_transform.basis.z
		else:
			push_dir = global_position - attack.global_position
			
		push_dir.y = 0
		if push_dir.length_squared() > 0.001:
			push_dir = push_dir.normalized()
		else:
			push_dir = Vector3.FORWARD
			
		var angle_rad = deg_to_rad(attack.knockback_angle)
		push_dir = push_dir * cos(angle_rad)
		push_dir.y = sin(angle_rad)
			
		knockback_component.apply_knockback(push_dir, attack.knockback_force)
'''

with open('Y:/Fangorn/fangorn/components/hitbox_component.gd', 'w', encoding='utf-8') as f:
    f.write(new_content)
print("I-frames added")
