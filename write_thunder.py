import os

content = '''extends Node3D

@onready var anim_player: AnimationPlayer = $AnimationPlayer
var caster: Node3D = null

func start_complex_cast(player: Node3D) -> void:
    caster = player

func on_mid_cast_event(event_name: String) -> void:
    if event_name == "slash_1":
        if anim_player.has_animation("slash_1"):
            anim_player.stop()
            anim_player.play("slash_1")
            print("Thunderslash : slash_1 est joue depuis le sort !")
    elif event_name == "slash_2":
        print("Thunderslash : deuxieme coup !")

func execute(player: Node3D, target_data: Dictionary) -> void:
    print("Thunderslash : Fin du cast !")
    await get_tree().create_timer(2.0).timeout
    queue_free()
'''

# Convert 4 spaces to tabs
content = content.replace('    ', '\t')

with open('Y:/Fangorn/fangorn/scripts/abilities/thunder_slash/thunder_slash.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Done!")
