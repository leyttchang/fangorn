with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("@export_range(1.0, 10.0) var minor_match_multiplier", "@export var minor_match_multiplier")
content = content.replace("@export_range(1.0, 10.0) var notable_match_multiplier", "@export var notable_match_multiplier")
content = content.replace("@export_range(1.0, 10.0) var keystone_match_multiplier", "@export var keystone_match_multiplier")
content = content.replace("@export_range(0.0, 10.0) var tag_match_multiplier_per_tag_minor", "@export var tag_match_multiplier_per_tag_minor")
content = content.replace("@export_range(0.0, 20.0) var tag_match_multiplier_per_tag_notable", "@export var tag_match_multiplier_per_tag_notable")
content = content.replace("@export_range(0.0, 20.0) var tag_match_multiplier_per_tag_keystone", "@export var tag_match_multiplier_per_tag_keystone")

with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Removed range limitations")
