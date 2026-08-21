# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/dumb_archer.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the duplicate definitions
content = content.replace('''var _pending_attacker: Node3D = null
var _is_waiting_for_aggro: bool = false

var _pending_attacker: Node3D = null
var _is_waiting_for_aggro: bool = false''', '''var _pending_attacker: Node3D = null
var _is_waiting_for_aggro: bool = false''')

with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/dumb_archer.gd', 'w', encoding='utf-8') as f:
    f.write(content)
