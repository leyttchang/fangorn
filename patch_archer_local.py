# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/dumb_archer.gd', 'r', encoding='utf-8') as f:
    content = f.read()

old_func = '''func fire_arrow() -> void:
	if not multiplayer.is_server(): return
	if arrow_scene == null:
		push_error("L'Archer essaie de tirer, mais aucune scne de flche n'est assign?e dans l'inspecteur !")
		return
		
	var new_arrow = arrow_scene.instantiate()
	get_tree().current_scene.get_node("NetworkObjects").add_child(new_arrow, true)
	new_arrow.execute(self, {})'''

new_func = '''func fire_arrow() -> void:
	if arrow_scene == null: return
		
	var new_arrow = arrow_scene.instantiate()
	# On l'ajoute  la racine, en dehors du r?seau pour ?viter les conflits de nom
	get_tree().root.add_child(new_arrow, true)
	
	if not multiplayer.is_server():
		# Le client cr?e une fausse flche (echo visuel) qui ne fait pas de d?g?ts
		var attack_comp = new_arrow.get_node_or_null("AttackComponent")
		if attack_comp:
			attack_comp.queue_free()
			
	new_arrow.execute(self, {})'''

if 'get_tree().root.add_child' not in content:
    content = content.replace(old_func, new_func)
    with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/dumb_archer.gd', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Archer patched")
