$content = Get-Content "Y:\Fangorn\fangorn\components\interaction_component.gd" -Raw

$content = $content -replace 'if player_in_range != null:', "if player_in_range != null and player_in_range.is_multiplayer_authority():"

Set-Content -Path "Y:\Fangorn\fangorn\components\interaction_component.gd" -Value $content -Encoding UTF8
