@tool
extends SceneTree

const TooltipGenerator = preload("res://scripts/abilities/tooltip_generator.gd")

func _init():
    var generator = TooltipGenerator.new()
    generator.spell_data = load("res://scripts/abilities/fireball/Fireball.tres")
    generator._generate()
    quit()
