# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/attack_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('func _on_area_entered(area: Area3D) -> void:', '''func _on_area_entered(area: Area3D) -> void:
\tprint("[", multiplayer.get_unique_id(), "] AttackComponent._on_area_entered triggered by ", area.name)''')

content = content.replace('hit_entities.append(area)', '''hit_entities.append(area)
\tprint("[", multiplayer.get_unique_id(), "] AttackComponent hitting ", area.name, " (not in hit_entities)")''')

content = content.replace('func reset_hit_entities() -> void:', '''func reset_hit_entities() -> void:
\tprint("[", multiplayer.get_unique_id(), "] AttackComponent.reset_hit_entities CALLED!")''')

with open('Y:/Fangorn/fangorn/components/attack_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)

with open('Y:/Fangorn/fangorn/components/hitbox_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('func receive_hit(attack: AttackComponent) -> void:', '''func receive_hit(attack: AttackComponent) -> void:
\tprint("[", multiplayer.get_unique_id(), "] HitboxComponent.receive_hit CALLED by ", attack.get_parent().name if attack.get_parent() else "Spike?")''')

with open('Y:/Fangorn/fangorn/components/hitbox_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)

with open('Y:/Fangorn/fangorn/components/health_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('func take_damage(raw_damage: float) -> void:', '''func take_damage(raw_damage: float) -> void:
\tprint("[", multiplayer.get_unique_id(), "] HealthComponent.take_damage CALLED for ", raw_damage, " dmg")''')

content = content.replace('func _rpc_take_damage(raw_damage: float) -> void:', '''func _rpc_take_damage(raw_damage: float) -> void:
\tprint("[", multiplayer.get_unique_id(), "] HealthComponent._rpc_take_damage RECEIVED for ", raw_damage, " dmg")''')

with open('Y:/Fangorn/fangorn/components/health_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)

with open('Y:/Fangorn/fangorn/components/knockback_componant.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('func apply_knockback(push_direction: Vector3, raw_knockback_force: float) -> void:', '''func apply_knockback(push_direction: Vector3, raw_knockback_force: float) -> void:
\tprint("[", multiplayer.get_unique_id(), "] KnockbackComponent.apply_knockback CALLED! Force: ", raw_knockback_force)''')

content = content.replace('func _rpc_apply_physics(push_direction: Vector3, final_force: float) -> void:', '''func _rpc_apply_physics(push_direction: Vector3, final_force: float) -> void:
\tprint("[", multiplayer.get_unique_id(), "] KnockbackComponent._rpc_apply_physics RECEIVED! Force: ", final_force)''')

with open('Y:/Fangorn/fangorn/components/knockback_componant.gd', 'w', encoding='utf-8') as f:
    f.write(content)

with open('Y:/Fangorn/fangorn/components/continuous_attack_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('timer.start()', '''print("[", multiplayer.get_unique_id(), "] ContinuousAttackComponent: Timer STARTED!")
\t\t\ttimer.start()''')

content = content.replace('func _on_timer_timeout() -> void:', '''func _on_timer_timeout() -> void:
\tprint("[", multiplayer.get_unique_id(), "] ContinuousAttackComponent: Timer TIMEOUT TICK!")''')

with open('Y:/Fangorn/fangorn/components/continuous_attack_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Prints applied everywhere")
