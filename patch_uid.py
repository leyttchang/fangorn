import re

with open('Y:/Fangorn/fangorn/particule/blood/blood_particule.tscn', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    '[ext_resource type="Script" path="res://particule/blood/blood_particule.gd" id="1_script"]',
    '[ext_resource type="Script" uid="uid://bco7glg7f4hdn" path="res://particule/blood/blood_particule.gd" id="1_script"]'
)

with open('Y:/Fangorn/fangorn/particule/blood/blood_particule.tscn', 'w', encoding='utf-8') as f:
    f.write(content)
