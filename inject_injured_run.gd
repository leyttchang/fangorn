@tool
extends SceneTree

func _init():
	var path = "res://character/enemie/ogre_boss/ogre_boss_anim_tree.tres"
	var tree = ResourceLoader.load(path)
	if tree == null or not (tree is AnimationNodeStateMachine):
		print("Erreur: Impossible de charger l'AnimationNodeStateMachine.")
		quit()
		return
	
	print("Fichier charge !")
	
	# Creer le noeud d'animation Injured_run
	var anim_node = AnimationNodeAnimation.new()
	anim_node.animation = "Injured_run"
	
	# L'ajouter a l'arbre s'il n'existe pas
	if not tree.has_node("Injured_run"):
		tree.add_node("Injured_run", anim_node, Vector2(500, 160))
		print("Noeud Injured_run ajoute.")
	else:
		print("Le noeud Injured_run existe deja.")
		
	# Ajouter les transitions
	var connections = [
		["idle", "Injured_run"],
		["Injured_run", "idle"],
		["Injured_run", "swing_attack"],
		["Injured_run", "death"],
		["Injured_run", "jumping_attack"],
		["Injured_run", "ground_slam"],
		["Injured_run", "rock_throw"],
		["Injured_run", "roar"]
	]
	
	for conn in connections:
		var from = conn[0]
		var to = conn[1]
		if tree.has_transition(from, to):
			print("Transition existe deja: ", from, " -> ", to)
			continue
			
		var transition = AnimationNodeStateMachineTransition.new()
		transition.xfade_time = 0.2
		tree.add_transition(from, to, transition)
		print("Transition ajoutee: ", from, " -> ", to)
		
	var err = ResourceSaver.save(tree, path)
	if err == OK:
		print("Sauvegarde reussie !")
	else:
		print("Erreur de sauvegarde: ", err)
		
	quit()
