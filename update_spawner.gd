@tool
extends SceneTree

func _init():
	var path = "res://lvl/game.tscn"
	var scene = ResourceLoader.load(path) as PackedScene
	if not scene:
		print("Erreur chargement game.tscn")
		quit()
		return
		
	var root = scene.instantiate()
	var spawner = root.get_node("NetworkObjects/MultiplayerSpawner") as MultiplayerSpawner
	if not spawner:
		print("Spawner introuvable !")
		root.queue_free()
		quit()
		return
		
	var scenes_to_add = [
		"res://character/enemie/ogre_boss/ogre_jumping_slam.tscn",
		"res://character/enemie/ogre_boss/rock_throw.tscn",
		"res://character/enemie/ogre_boss/ogre_ground_slam.tscn",
		"res://character/enemie/ogre_boss/ogre_roar.tscn"
	]
	
	var added = false
	for s in scenes_to_add:
		if not spawner.has_spawnable_scene(s):
			spawner.add_spawnable_scene(s)
			added = true
			print("Ajouté: ", s)
			
	if added:
		var packed = PackedScene.new()
		packed.pack(root)
		ResourceSaver.save(packed, path)
		print("Sauvegardé !")
	else:
		print("Déjà à jour.")
		
	root.queue_free()
	quit()
