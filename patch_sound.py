import re
with open('Y:/Fangorn/fangorn/scripts/sound_manager.gd', 'r', encoding='utf-8') as f:
    text = f.read()

# We change:
# 	if current_time - _last_hit_sound_time < 30:
# 		return
# 	_last_hit_sound_time = current_time
# To:
# 	if custom_stream == null:
# 		if current_time - _last_hit_sound_time < 30:
# 			return
# 		_last_hit_sound_time = current_time

new_text = text.replace(
	"\tvar current_time = Time.get_ticks_msec()\n\tif current_time - _last_hit_sound_time < 30:\n\t\treturn\n\t_last_hit_sound_time = current_time",
	"\tvar current_time = Time.get_ticks_msec()\n\tif custom_stream == null:\n\t\tif current_time - _last_hit_sound_time < 30:\n\t\t\treturn\n\t\t_last_hit_sound_time = current_time"
)

with open('Y:/Fangorn/fangorn/scripts/sound_manager.gd', 'w', encoding='utf-8') as f:
    f.write(new_text)

print("SoundManager patched")
