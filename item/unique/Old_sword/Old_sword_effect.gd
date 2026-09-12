extends Node

var player: Node3D
var stats: Node
var mana_comp: Node

func _ready() -> void:
	player = get_parent().get_parent()
	stats = player.get_node_or_null("%StatsComponent")
	mana_comp = player.get_node_or_null("ManaComponent")
	
	print("La Vieille Epee est equipee...")
	
	if player.has_signal("player_hit_enemy"):
		player.player_hit_enemy.connect(_on_enemy_hit)

func _on_enemy_hit() -> void:
	if mana_comp != null:
		if player.is_multiplayer_authority():
			mana_comp.add_mana(0.5)

func _exit_tree() -> void:
	if player != null and player.has_signal("player_hit_enemy"):
		if player.player_hit_enemy.is_connected(_on_enemy_hit):
			player.player_hit_enemy.disconnect(_on_enemy_hit)
