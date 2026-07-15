class_name ContinuousAttackComponent
extends Node

@export var attack_component: AttackComponent
@export var tick_rate: float = 1.0 

# Un compteur pour savoir combien de cibles sont dans le piège
var targets_inside: int = 0
var timer: Timer

func _ready() -> void:
	if attack_component == null:
		push_error("ContinuousAttackComponent sur " + get_parent().name + " : AttackComponent manquant !")
		return
		
	timer = Timer.new()
	timer.wait_time = tick_rate
	# 1. Le timer est ÉTEINT par défaut !
	timer.autostart = false 
	add_child(timer)
	
	timer.timeout.connect(_on_timer_timeout)
	
	# 2. On écoute quand quelqu'un rentre ou sort de la zone
	attack_component.area_entered.connect(_on_area_entered)
	attack_component.area_exited.connect(_on_area_exited)

func _on_area_entered(area: Area3D) -> void:
	if area is HitboxComponent:
		targets_inside += 1
		# Si c'est la toute première victime qui entre, on réveille le Timer !
		if timer.is_stopped():
			timer.start()

func _on_area_exited(area: Area3D) -> void:
	if area is HitboxComponent:
		targets_inside -= 1
		attack_component.hit_entities.erase(area)
		
		# Si le piège est complètement vide, on endort le Timer
		if targets_inside <= 0:
			targets_inside = 0
			timer.stop()

func _on_timer_timeout() -> void:
	attack_component.reset_hit_entities()
	
	var areas_inside = attack_component.get_overlapping_areas()
	for area in areas_inside:
		# On applique les dégâts aux victimes encore à l'intérieur
		attack_component._on_area_entered(area)
