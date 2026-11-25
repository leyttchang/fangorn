class_name FpsCounter
extends CanvasLayer

@onready var label: Label = $Label
var _last_fps: int = -1

func _process(_delta: float) -> void:
	var fps: int = int(Engine.get_frames_per_second())
	if fps != _last_fps:
		_last_fps = fps
		label.text = "FPS: " + str(fps)
