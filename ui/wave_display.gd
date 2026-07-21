class_name WaveDisplay
extends CanvasLayer

@export var smart_spawner: SmartSpawner
@onready var label: Label = $CenterContainer/Label

var tween: Tween

func _ready() -> void:
	label.modulate.a = 0.0
	
	if smart_spawner == null:
		var spawners = get_tree().get_nodes_in_group("SmartSpawner")
		if not spawners.is_empty():
			smart_spawner = spawners[0] as SmartSpawner
			
	if smart_spawner != null:
		_connect_spawner(smart_spawner)
	else:
		get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if smart_spawner == null and node is SmartSpawner:
		smart_spawner = node
		_connect_spawner(smart_spawner)

func _connect_spawner(spawner: SmartSpawner) -> void:
	if not spawner.wave_started.is_connected(_on_wave_started):
		spawner.wave_started.connect(_on_wave_started)
	if not spawner.wave_completed.is_connected(_on_wave_completed):
		spawner.wave_completed.connect(_on_wave_completed)

func _on_wave_started(wave_number: int, _total_enemies: int) -> void:
	_display_banner("VAGUE " + str(wave_number), Color(1.0, 0.35, 0.35))

func _on_wave_completed(wave_number: int) -> void:
	_display_banner("VAGUE " + str(wave_number) + " TERMINÉE !", Color(0.35, 1.0, 0.5))

func _display_banner(text: String, color: Color = Color.WHITE) -> void:
	label.text = text
	label.self_modulate = color
	
	if tween != null and tween.is_running():
		tween.kill()
		
	tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
