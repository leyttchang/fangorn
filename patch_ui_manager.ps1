$content = Get-Content "Y:\Fangorn\fangorn\ui\ui_manager.gd" -Raw

$content = $content -replace 'func _input\(event: InputEvent\) -> void:', "func _input(event: InputEvent) -> void:
	if not owner.is_multiplayer_authority(): return"

Set-Content -Path "Y:\Fangorn\fangorn\ui\ui_manager.gd" -Value $content -Encoding UTF8
