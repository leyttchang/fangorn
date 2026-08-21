$content = Get-Content "Y:\Fangorn\fangorn\lvl\starting_menu.gd" -Raw

$content = $content -replace 'MultiplayerPanel', "Host_menu"
$content = $content -replace 'BtnHost', "btnHost"
$content = $content -replace 'BtnJoin', "btnJoin"
$content = $content -replace 'BtnBack', "btnBack"

Set-Content -Path "Y:\Fangorn\fangorn\lvl\starting_menu.gd" -Value $content -Encoding UTF8
