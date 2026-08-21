$content = Get-Content "Y:\Fangorn\fangorn\components\skill_bar_component.gd" -Raw

$content = $content -replace 'func _input\(event: InputEvent\) -> void:', "func _input(event: InputEvent) -> void:
	if not owner.is_multiplayer_authority(): return"
$content = $content -replace 'func _handle_inputs\(\) -> void:', "func _handle_inputs() -> void:
	if not owner.is_multiplayer_authority(): return"
$content = $content -replace 'func _process\(delta: float\) -> void:', "func _process(delta: float) -> void:
	if not owner.is_multiplayer_authority(): return"

Set-Content -Path "Y:\Fangorn\fangorn\components\skill_bar_component.gd" -Value $content -Encoding UTF8
