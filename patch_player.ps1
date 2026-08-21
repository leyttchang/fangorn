$content = Get-Content "Y:\Fangorn\fangorn\character\player.gd" -Raw

$content = $content -replace 'func _ready\(\) -> void:', "func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready() -> void:"

$content = $content -replace 'Input\.set_mouse_mode\(Input\.MOUSE_MODE_CAPTURED\)', "if is_multiplayer_authority():
		camera.current = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)"

$content = $content -replace 'func _physics_process\(delta: float\) -> void:', "func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
"

$content = $content -replace 'func _unhandled_input\(event: InputEvent\) -> void:', "func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
"

Set-Content -Path "Y:\Fangorn\fangorn\character\player.gd" -Value $content -Encoding UTF8
