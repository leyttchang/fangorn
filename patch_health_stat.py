# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/health_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

new_func = '''
func _on_stat_changed(stat_name: String, new_value: float) -> void:
	if stat_name == "max_health":
		var diff = new_value - _known_max_health
		_known_max_health = new_value
		if diff > 0:
			current_health += diff
		else:
			if current_health > new_value:
				current_health = new_value
		health_changed.emit(current_health, new_value)
'''

if 'func _on_stat_changed' not in content:
    with open('Y:/Fangorn/fangorn/components/health_component.gd', 'a', encoding='utf-8') as f:
        f.write(new_func)
    print("Function added")
