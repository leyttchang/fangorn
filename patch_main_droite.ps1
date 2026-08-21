$content = Get-Content "Y:\Fangorn\fangorn\character\main_droite.gd" -Raw

$content = $content -replace 'func _input\(event\):', "func _input(event):
	if not owner.is_multiplayer_authority(): return"
$content = $content -replace 'func _process\(delta: float\) -> void:', "func _process(delta: float) -> void:
	if not owner.is_multiplayer_authority(): return"

Set-Content -Path "Y:\Fangorn\fangorn\character\main_droite.gd" -Value $content -Encoding UTF8
