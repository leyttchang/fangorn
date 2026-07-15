extends Node3D

@export var radius: float = 4.0
@export var density: float = 13

# On récupère le nœud des particules (Vérifie que le nom correspond bien à ton nœud)
@onready var fire_particles: GPUParticles3D = $fire
@onready var spraks_particules: GPUParticles3D = $spraks

func _ready() -> void:
	# 1. Le nombre de particules doit obligatoirement être un entier (int)
	var nbr_particules: int = int(radius * radius * density)
	
	# 2. On applique la quantité directement sur le nœud GPUParticles3D
	fire_particles.amount = nbr_particules
	spraks_particules.amount = nbr_particules
	# 3. Modification du Radius dans le Process Material
	if fire_particles.process_material != null:
		# TRÈS IMPORTANT : On duplique le material pour que cette zone de feu soit indépendante des autres
		fire_particles.process_material = fire_particles.process_material.duplicate()
		
		# On modifie le rayon d'émission de l'anneau
		fire_particles.process_material.emission_ring_radius = radius
		
	if spraks_particules.process_material != null:
		# TRÈS IMPORTANT : On duplique le material pour que cette zone de feu soit indépendante des autres
		spraks_particules.process_material = spraks_particules.process_material.duplicate()
		
		# On modifie le rayon d'émission de l'anneau
		spraks_particules.process_material.emission_ring_radius = radius
