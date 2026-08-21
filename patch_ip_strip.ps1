$content = Get-Content "Y:\Fangorn\fangorn\lvl\starting_menu.gd" -Raw

$content = $content -replace 'var ip = ip_input.text', "var ip = ip_input.text.strip_edges()"

Set-Content -Path "Y:\Fangorn\fangorn\lvl\starting_menu.gd" -Value $content -Encoding UTF8
