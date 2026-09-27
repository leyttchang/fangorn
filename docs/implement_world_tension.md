# Système de Tension Temporelle — Instructions pour Agent

## Concept
Timer invisible (pas de chrono UI). Le monde change visuellement et mécaniquement en 3 phases pour forcer les joueurs vers le boss.

---

## Architecture : 1 nouveau script central

### Créer `map/map_generator/world_tension.gd`

Script Node attaché comme enfant de `map_generator.tscn`. **Server-authoritative** avec RPC pour sync les phases aux clients.

```
Variables:
- elapsed_time: float = 0.0
- current_phase: int = 0  (0=Clémence, 1=Dégradation, 2=Horde)
- phase_1_time: float = 600.0  (10 min)
- phase_2_time: float = 1200.0  (20 min)
- horde_spawn_interval: float = 30.0  (secondes entre vagues en phase 2)

Signal: phase_changed(new_phase: int)
```

**Logique `_physics_process(delta)` — SERVER ONLY :**
1. `elapsed_time += delta`
2. Calculer la phase selon le temps
3. Si la phase change → `rpc("_rpc_set_phase", new_phase)` → émet `phase_changed`

**RPC :**
```
@rpc("authority", "call_local", "reliable")
func _rpc_set_phase(phase: int):
    current_phase = phase
    phase_changed.emit(phase)
```

---

## 5 systèmes à connecter au signal `phase_changed`

### 1. Météo dynamique (modifier `meteo.gd`)

Au lieu de choisir un preset random au chargement, `meteo.gd` doit aussi réagir aux phases :

- **Phase 0 :** Garder la météo initiale (ciel clair ou léger brouillard)
- **Phase 1 :** Transition vers pluie + ciel orageux + `DirectionalLight3D` intensity réduite + fog density augmentée
- **Phase 2 :** Ciel rouge sang / nuit d'encre + `DirectionalLight3D` color rouge sombre + fog très dense

**Approche :** Avoir 3 `WorldEnvironment` presets (ou tweener les propriétés environment existantes). `world_tension.phase_changed` → `meteo.transition_to_phase(phase)`.

### 2. Agressivité des monstres (modifier `enemy_navigation_component.gd`)

Ajouter un multiplicateur global de détection :

```
# Dans EnemyNavigationComponent, lire le multiplicateur depuis WorldTension
var tension_detection_mult: float = 1.0

# Phase 0: mult = 1.0 (normal)
# Phase 1: mult = 1.3 (+30% range)  
# Phase 2: mult = 2.0 (double range)
```

**Connecter :** Au `_ready()` de chaque ennemi, chercher `WorldTension` dans l'arbre et écouter `phase_changed`. Ou plus simple : variable statique `WorldTension.detection_multiplier` lue directement.

### 3. Spawner de Horde (NOUVEAU — `map/map_generator/horde_spawner.gd`)

Activé uniquement en **Phase 2**. Server-only.

```
Logique:
- Timer récurrent (toutes les 30s)
- Trouver la position de chaque joueur vivant
- Spawner une vague de X mobs "horde" à ~80-120m du joueur dans une direction aléatoire
- Les mobs sont ajoutés dans NetworkObjects (comme monster_pack_generator)
- Scaling: nombre de mobs = base * player_count_multiplier
- Les mobs horde convergent vers le joueur le plus proche
```

**Scènes de mobs horde :** Réutiliser `dumb.tscn` / `creep.tscn` existants MAIS leur ajouter un tag/meta `is_horde_mob = true`.

### 4. XP et Loot réduits pour mobs horde (modifier existants)

**Dans `lvl_component.gd`** (composant XP) :
- Avant de donner l'XP, vérifier `if enemy.get_meta("is_horde_mob", false): xp *= 0.05` (5% de l'XP normale)

**Dans `loot_drop_component.gd`** :
- Avant de drop : `if owner.get_meta("is_horde_mob", false): return` (aucun loot)

### 5. Indicateurs visuels subtils (optionnel mais recommandé)

Pas de chrono UI, mais des indices visuels :
- **Phase 1 :** Son d'orage lointain + particules de pluie
- **Phase 2 :** Son de cor de guerre / tambours + screen tint rouge léger via shader post-process
- Optionnel : les PNJ rescapés ont une ligne de dialogue qui change ("Dépêchez-vous, la nuit approche !")

---

## Fichiers à créer / modifier

| Fichier | Action |
|---|---|
| `map/map_generator/world_tension.gd` | **NOUVEAU** — Timer central, phases, RPC sync |
| `map/map_generator/horde_spawner.gd` | **NOUVEAU** — Vagues de mobs phase 2 |
| `map/map_generator/map_generator.tscn` | Ajouter les nodes `WorldTension` et `HordeSpawner` comme enfants |
| `map/map_generator/meteo.gd` | Ajouter `transition_to_phase(phase)` — tween environnement |
| `components/enemy_navigation_component.gd` | Lire `WorldTension.detection_multiplier` pour la range |
| `components/lvl_component.gd` | Check `is_horde_mob` meta → XP x0.05 |
| `components/loot_drop_component.gd` | Check `is_horde_mob` meta → skip drop |

## Points clés multi

- `world_tension.gd` : seul le **serveur** avance le timer et décide des phases. Les clients reçoivent la phase par RPC.
- `horde_spawner.gd` : **server-only**, mobs dans `NetworkObjects`, répliqués par `MultiplayerSpawner`.
- La météo/ambiance tourne en **local** sur chaque peer (déterministe car même phase).
- Le multiplicateur de détection s'applique côté **serveur** (c'est lui qui run l'IA).
