class_name MonsterIceNova
extends Node3D

## Petite Ice Nova périodique émise autour d'un monstre affecté par l'enchantement de glace :
## - Réutilise les assets et shaders d'Ice Nova (onde de glace, brume, éclats, flocons, décal de givre)
## - N'inflige AUCUN dégât ni recul, mais déclenche l'application du slow cumulable aux joueurs touchés

const BASE_WAVE_MESH_RADIUS := 10.0
const BASE_PETITE_RADIUS := 4.2

@export var nova_radius: float = 4.2

var slow_hit_callback: Callable = Callable()
var _hit_triggered: bool = false

@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
@onready var wave_particles: GPUParticles3D = get_node_or_null("Visuals/wave") as GPUParticles3D
@onready var smoke_particles: GPUParticles3D = get_node_or_null("Visuals/smoke") as GPUParticles3D
@onready var sparks_particles: GPUParticles3D = get_node_or_null("Visuals/spraks") as GPUParticles3D
@onready var snow_burst_particles: GPUParticles3D = get_node_or_null("Visuals/snow_burst") as GPUParticles3D
@onready var ground_decal: Decal = get_node_or_null("Visuals/Decal") as Decal
@onready var flash_light: OmniLight3D = get_node_or_null("Visuals/FlashLight") as OmniLight3D

func setup(p_radius: float, p_slow_cb: Callable = Callable()) -> void:
	nova_radius = maxf(1.0, p_radius)
	slow_hit_callback = p_slow_cb
	if is_node_ready():
		_apply_radius_scale()

func _ready() -> void:
	# Dupliquer le ShaderMaterial de l'onde par instance pour que plusieurs novas simultanées
	# animent indépendamment leurs uniforms impact_speed / text_ofset sans interférer
	if wave_particles != null and wave_particles.material_override != null:
		wave_particles.material_override = wave_particles.material_override.duplicate()

	_apply_radius_scale()

	if anim_player != null:
		anim_player.clear_caches()
		if anim_player.has_animation(&"burst"):
			anim_player.play(&"burst")

func _apply_radius_scale() -> void:
	var wave_scale := nova_radius / BASE_WAVE_MESH_RADIUS
	var particle_scale := nova_radius / BASE_PETITE_RADIUS

	if wave_particles != null:
		wave_particles.scale = Vector3(wave_scale, 0.65, wave_scale)
	if ground_decal != null:
		ground_decal.size = Vector3(25.0 * wave_scale, 3.0, 25.0 * wave_scale)
	if smoke_particles != null:
		smoke_particles.scale = Vector3.ONE * particle_scale
	if sparks_particles != null:
		sparks_particles.scale = Vector3.ONE * particle_scale
	if snow_burst_particles != null:
		snow_burst_particles.scale = Vector3.ONE * particle_scale
	if flash_light != null:
		flash_light.omni_range = maxf(3.0, nova_radius * 1.45)

## Appelée par l'AnimationPlayer au moment exact où l'onde glacée balaye la zone (~0.32s)
func trigger_slow_wave() -> void:
	if _hit_triggered:
		return
	_hit_triggered = true
	if slow_hit_callback.is_valid():
		slow_hit_callback.call(global_position, nova_radius)

## Appelée par l'AnimationPlayer à la fin de la dissipation des particules
func disappear() -> void:
	queue_free()
