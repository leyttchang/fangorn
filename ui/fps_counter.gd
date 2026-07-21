class_name FpsCounter
extends CanvasLayer

@onready var label: Label = $Label

func _process(_delta: float) -> void:
	label.text = "FPS: " + str(Engine.get_frames_per_second())
