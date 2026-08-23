# -*- coding: utf-8 -*-
import os

# Create directory
os.makedirs('Y:/Fangorn/fangorn/scripts/status_effects', exist_ok=True)

# 1. StatusEffectData
path_data = 'Y:/Fangorn/fangorn/scripts/status_effects/status_effect_data.gd'
content_data = '''class_name StatusEffectData
extends Resource

@export var effect_id: String = "unique_effect_name"
@export var is_buff: bool = false
@export var icon: Texture2D

@export_group("Modificateurs de Stats")
@export var stat_modifiers: Array[StatModifierData] = []

@export_group("Degats sur la duree (DoT)")
@export var tick_damage: float = 0.0
@export var tick_interval: float = 1.0

@export_group("Visuels")
@export var enemie_effect: PackedScene
@export var player_effect: PackedScene

# Fonction virtuelle pour les effets complexes (Chill -> Freeze, etc.)
func on_apply(target: Node, component: Node) -> void:
\tpass

func on_remove(target: Node, component: Node) -> void:
\tpass
'''
with open(path_data, 'w', encoding='utf-8') as f:
    f.write(content_data)

# 2. StatusEffectApplication
path_app = 'Y:/Fangorn/fangorn/scripts/status_effects/status_effect_application.gd'
content_app = '''class_name StatusEffectApplication
extends Resource

@export var effect: StatusEffectData
@export var duration: float = 5.0
@export_range(0.0, 1.0) var apply_chance: float = 1.0
'''
with open(path_app, 'w', encoding='utf-8') as f:
    f.write(content_app)

# 3. StatusEffectComponent
path_comp = 'Y:/Fangorn/fangorn/components/status_effect_componant.gd'
content_comp = '''class_name StatusEffectComponent
extends Node3D

@export var stats_component: Node # StatsComponent
@export var health_component: Node # HealthComponent

class ActiveEffect:
\tvar data: StatusEffectData
\tvar time_remaining: float = 0.0
\tvar next_tick_time: float = 0.0
\tvar visual_instance: Node = null

var _active_effects: Dictionary = {}

func apply_effect(data: StatusEffectData, duration: float) -> void:
\tif data == null: return
\t
\t# Si l'effet existe deja, on refresh la duree
\tif _active_effects.has(data.effect_id):
\t\tvar eff = _active_effects[data.effect_id]
\t\teff.time_remaining = max(eff.time_remaining, duration)
\t\t# Appel de la fonction custom meme en cas de refresh
\t\tdata.on_apply(get_parent(), self)
\t\treturn
\t\t
\tvar new_effect = ActiveEffect.new()
\tnew_effect.data = data
\tnew_effect.time_remaining = duration
\tnew_effect.next_tick_time = data.tick_interval
\t
\t_active_effects[data.effect_id] = new_effect
\t
\t# --- APPLICATION DES STATS ---
\tif stats_component != null and stats_component.has_method("add_modifier"):
\t\tfor mod in data.stat_modifiers:
\t\t\tstats_component.add_modifier(mod.stat_name, mod.mod_type, mod.value, "STATUS_" + data.effect_id)
\t\t\t
\t# --- SPAWN VISUEL ---
\tvar is_local_player = false
\tvar p = get_parent()
\tif p.is_in_group("Player") and p.is_multiplayer_authority():
\t\tis_local_player = true
\t\t
\tvar visual_scene = data.player_effect if is_local_player else data.enemie_effect
\t
\tif visual_scene != null:
\t\tvar vfx = visual_scene.instantiate()
\t\tnew_effect.visual_instance = vfx
\t\tadd_child(vfx)
\t\t
\t# Appel de la fonction custom
\tdata.on_apply(get_parent(), self)

func remove_effect(effect_id: String) -> void:
\tif not _active_effects.has(effect_id): return
\t
\tvar eff = _active_effects[effect_id]
\teff.data.on_remove(get_parent(), self)
\t
\t# Retrait des stats
\tif stats_component != null and stats_component.has_method("remove_modifier_by_source"):
\t\tstats_component.remove_modifier_by_source("STATUS_" + effect_id)
\t\t
\t# Destruction visuel
\tif is_instance_valid(eff.visual_instance):
\t\teff.visual_instance.queue_free()
\t\t
\t_active_effects.erase(effect_id)

func has_effect(effect_id: String) -> bool:
\treturn _active_effects.has(effect_id)

func _process(delta: float) -> void:
\tvar keys = _active_effects.keys()
\tfor key in keys:
\t\tif not _active_effects.has(key): continue
\t\tvar eff = _active_effects[key]
\t\t
\t\t# Ticks de degats (DoT)
\t\tif eff.data.tick_damage > 0.0 and eff.data.tick_interval > 0.0:
\t\t\teff.next_tick_time -= delta
\t\t\tif eff.next_tick_time <= 0.0:
\t\t\t\teff.next_tick_time = eff.data.tick_interval
\t\t\t\tif health_component != null and health_component.has_method("take_damage"):
\t\t\t\t\t# Envoi en degats bruts pour eviter l'armure si on veut, ou normal
\t\t\t\t\thealth_component.take_damage(eff.data.tick_damage)
\t\t
\t\t# Duree
\t\teff.time_remaining -= delta
\t\tif eff.time_remaining <= 0.0:
\t\t\tremove_effect(key)
'''
with open(path_comp, 'w', encoding='utf-8') as f:
    f.write(content_comp)

print("Systeme cree avec succes !")
