extends Node3D

@export var radius: float = 4.0
@export var density: float = 13

# On récupère le nœud des particules (Vérifie que le nom correspond bien à ton nœud)
@onready var fire_particles: GPUParticles3D = $fire
@onready var spraks_particules: GPUParticles3D = $spraks

var _fire_mat_duplicated: bool = false
var _sparks_mat_duplicated: bool = false

func _ready() -> void:
	apply_radius(radius)

func apply_radius(new_radius: float) -> void:
	radius = new_radius
	if fire_particles == null:
		fire_particles = get_node_or_null("fire") as GPUParticles3D
	if spraks_particules == null:
		spraks_particules = get_node_or_null("spraks") as GPUParticles3D

	# 1. Le nombre de particules doit obligatoirement être un entier >= 1
	var nbr_particules: int = maxi(1, int(radius * radius * density))

	# 2. N'appliquer amount que s'il a réellement changé (évite de réallouer le buffer GPU)
	if fire_particles != null:
		if fire_particles.amount != nbr_particules:
			fire_particles.amount = nbr_particules
		if fire_particles.process_material != null:
			if not _fire_mat_duplicated:
				fire_particles.process_material = fire_particles.process_material.duplicate()
				_fire_mat_duplicated = true
			fire_particles.process_material.emission_ring_radius = radius

	if spraks_particules != null:
		if spraks_particules.amount != nbr_particules:
			spraks_particules.amount = nbr_particules
		if spraks_particules.process_material != null:
			if not _sparks_mat_duplicated:
				spraks_particules.process_material = spraks_particules.process_material.duplicate()
				_sparks_mat_duplicated = true
			spraks_particules.process_material.emission_ring_radius = radius
