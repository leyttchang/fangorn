extends Node3D

class_name ReviveComponent

@export var max_revive_progress: float = 100.0
@export var revive_speed: float = 25.0 # Combien de progression par seconde (4 secondes pour 100)
@export var health_cost_per_sec: float = 10.0 # Cout en PV par seconde pour celui qui soigne

var current_progress: float = 0.0
var is_active: bool = false
var target_player: CharacterBody3D = null

@onready var interaction_comp = $InteractionComponent if has_node("InteractionComponent") else null

signal player_revived

func _ready() -> void:
	target_player = get_parent()
	# Desactive l'interaction par defaut
	disable_revive()

func enable_revive() -> void:
	is_active = true
	current_progress = 0.0
	if interaction_comp:
		interaction_comp.monitoring = true
		interaction_comp.monitorable = true
		interaction_comp.prompt_text = "Maintenir E pour reanimer (0%)"
		var shape = interaction_comp.get_node_or_null("CollisionShape3D")
		if shape != null:
			shape.disabled = false

func disable_revive() -> void:
	is_active = false
	current_progress = 0.0
	if interaction_comp:
		interaction_comp.hide_prompt()
		interaction_comp.monitoring = false
		interaction_comp.monitorable = false
		var shape = interaction_comp.get_node_or_null("CollisionShape3D")
		if shape != null:
			shape.disabled = true

## Fonction appelee par le joueur qui SOIGNE (en boucle tant qu'il maintient E)
func process_revive(delta: float, reviver: CharacterBody3D) -> void:
	if not is_active:
		return
		
	# On verifie que le soigneur a assez de vie (il ne peut pas se suicider pour sauver quelqu'un)
	var reviver_health = reviver.get_node_or_null("HealthComponent")
	if reviver_health and reviver_health.current_health > 5.0 + (health_cost_per_sec * delta):
		
		# 1. Le soigneur PERD sa vie localement
		reviver_health.take_damage(health_cost_per_sec * delta)
		
		# 2. Il envoie un message reseau pour augmenter la jauge du joueur a terre
		rpc("add_progress_rpc", revive_speed * delta)

@rpc("any_peer", "call_local", "unreliable_ordered")
func add_progress_rpc(amount: float) -> void:
	if not is_active:
		return
		
	current_progress += amount
	
	if interaction_comp:
		interaction_comp.prompt_text = "Maintenir E pour reanimer (" + str(int(current_progress)) + "%)"
		# Force l'actualisation visuelle si on le regarde
		if interaction_comp.prompt_label and interaction_comp.prompt_label.visible:
			interaction_comp.prompt_label.text = interaction_comp.prompt_text
	
	if current_progress >= max_revive_progress:
		_complete_revive()

func _complete_revive() -> void:
	# Appele uniquement sur l'autorite du joueur a terre
	disable_revive()
	player_revived.emit()
	
	# La vie est rendue dans player.gd via _on_player_revived
		
	print("Joueur reanime !")
