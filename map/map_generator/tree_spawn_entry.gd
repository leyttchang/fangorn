@tool
class_name TreeSpawnEntry
extends Resource

## Nom descriptif de l'espece ou variante d'arbre (ex: "Arbre Vivant", "Arbre Mort")
@export var name: String = "Arbre"

## Scene de l'arbre modele (ex: Island_tree_hb.tscn, dead_tree.tscn)
@export var tree_scene: PackedScene

## Poids d'apparition relatif (plus le poids est eleve par rapport aux autres, plus il apparait souvent).
## Ex: 80 pour l'arbre vivant et 20 pour l'arbre mort donne 80% / 20%.
@export_range(0.01, 1000.0, 0.1) var weight: float = 1.0

## Multiplicateur d'echelle pour cette espece (1.0 = utilise le min/max scale global du spawner).
@export var scale_multiplier: float = 1.0
