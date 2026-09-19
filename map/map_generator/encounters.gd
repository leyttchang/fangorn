@tool
extends Node3D

@export_category("Points d'intérêt (Encounters)")

## Nombre de POI à placer sur la carte
@export var encounter_count: int = 8

## Distance minimale en mètres entre deux Encounters (évite le clustering)
@export var min_distance_between_encounters: float = 400.0

## Distance minimale en mètres entre un Encounter et les chemins principaux
@export var min_distance_from_main_roads: float = 150.0
