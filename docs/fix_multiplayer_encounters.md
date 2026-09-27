# Fix Multiplayer Encounters — Instructions pour Agent

## Contexte
Le système d'encounters (camps PNJ) a 4 bugs critiques en multijoueur. Le reste du multi (lobby, spawn joueurs, monstres open-world, combat, loot) fonctionne correctement.

**Design voulu :** Chaque joueur peut claim son propre buff PNJ indépendamment. Ce n'est PAS un bug que `pnj_buff_choice.gd` soit local — c'est intentionnel.

---

## Bug #1 — `encounters.gd` crée des instances dupliquées (CAUSE RACINE)

**Fichier :** `map/map_generator/encounters.gd`  
**Problème :** `spawn_encounters()` est appelé par `map_generator.gd` sur TOUS les peers (server + clients). Chaque peer crée ses propres instances de `pnj_encounter.tscn`. Le `MobRaycastSpawner` du client ne spawn pas de mobs (guard `is_server()`), donc le signal `all_mobs_defeated` ne fire jamais côté client → cage jamais ouverte.

**Fix :** Ajouter un guard `is_server()` dans `spawn_encounters()`. Les encounters doivent être instanciés UNIQUEMENT par le serveur, puis répliqués via le `MultiplayerSpawner` de `NetworkObjects`.

```
Dans encounters.gd, fonction spawn_encounters():
- Ajouter au début: if multiplayer.has_multiplayer_peer() and not multiplayer.is_server(): return
- Changer le parent: au lieu de marker.add_child(instance), ajouter dans NetworkObjects:
  var net_obj = get_tree().current_scene.get_node_or_null("NetworkObjects")
  if net_obj: net_obj.add_child(instance, true)
  else: marker.add_child(instance)
- Positionner l'instance à marker.global_position avant l'add_child
```

**IMPORTANT :** Il faut aussi ajouter le UID de `pnj_encounter.tscn` (et tout autre encounter scene comme `orc_village.tscn`, `boss_arena.tscn`) dans la liste `_spawnable_scenes` du `MultiplayerSpawner` sous `NetworkObjects` dans `game.tscn`.

---

## Bug #2 — `open_cage()` pas synchronisé

**Fichier :** `map/encounters/pnj_encounter/pnj_encounter.gd`  
**Problème :** `open_cage()` est local. Le signal `all_mobs_defeated` fire uniquement côté serveur. Les clients ne voient jamais la cage exploser.

**Fix :** Faire de `open_cage()` un RPC broadcasté par le serveur.

```
- Renommer open_cage() en _do_open_cage() (logique interne inchangée)
- Créer une nouvelle open_cage() qui fait:
  if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
      rpc("_rpc_open_cage")
  else:
      _do_open_cage()
- Ajouter:
  @rpc("authority", "call_local", "reliable")
  func _rpc_open_cage() -> void:
      _do_open_cage()
```

Le signal `all_mobs_defeated` connecté à `open_cage()` reste inchangé — il fire côté serveur, qui broadcast le RPC.

---

## Bug #3 — `mob_raycast_spawner.gd` mobs hors de NetworkObjects

**Fichier :** `mob_raycast_spawner.gd`  
**Problème :** Quand `mobs_container` n'est pas configuré dans l'inspecteur, les mobs sont ajoutés comme enfants du spawner → pas répliqués par `MultiplayerSpawner`.

**Fix :** Ajouter un fallback automatique vers `NetworkObjects`, comme le fait déjà `monster_pack_generator.gd`.

```
Dans spawn_mobs(), remplacer:
  var target_container = mobs_container if mobs_container != null else self

Par:
  var target_container = mobs_container
  if target_container == null:
      target_container = get_tree().current_scene.get_node_or_null("NetworkObjects")
  if target_container == null:
      target_container = self
```

---

## Bug #4 — `pnj_buff_choice.gd` : `is_freed` pas sync

**Fichier :** `map/encounters/pnj_buff_choice/pnj_buff_choice.gd`  
**Problème :** `is_freed` est mis à `true` par `unlock_pnj()` qui est appelé dans `open_cage()`. Si le Bug #2 est fixé (open_cage broadcasté), `unlock_pnj()` sera aussi appelé sur tous les peers → `is_freed` sera sync automatiquement.

**Vérification :** Après fix du Bug #2, vérifier que `_do_open_cage()` appelle bien `pnj.unlock_pnj()` et que ce call arrive sur tous les peers via le RPC. Si c'est le cas, aucun changement supplémentaire nécessaire dans `pnj_buff_choice.gd`.

Le `reward_claimed` reste local par joueur — c'est voulu (chaque joueur claim son propre buff).

---

## Bug #5 (mineur) — Race condition spawn joueur

**Fichier :** `lvl/game.gd`  
**Problème :** Un client peut envoyer `_rpc_client_ready` avant que le serveur ait fini `await terrain_ready`.

**Fix simple :** Stocker les IDs en attente et les spawner après `terrain_ready`.

```
var _pending_clients: Array[int] = []
var _terrain_is_ready: bool = false

# Dans _rpc_client_ready():
if not _terrain_is_ready:
    _pending_clients.append(sender_id)
    return
spawn_player(sender_id)

# Après await terrain_ready, ajouter:
_terrain_is_ready = true
for id in _pending_clients:
    spawn_player(id)
_pending_clients.clear()
```

---

## Résumé des fichiers à modifier

| Fichier | Action |
|---|---|
| `map/map_generator/encounters.gd` | Guard `is_server()` + parent dans `NetworkObjects` |
| `map/encounters/pnj_encounter/pnj_encounter.gd` | RPC `open_cage()` |
| `mob_raycast_spawner.gd` | Fallback `NetworkObjects` |
| `lvl/game.gd` | Buffer `_pending_clients` |
| `lvl/game.tscn` | Ajouter UIDs des encounter scenes dans `NetworkObjects/MultiplayerSpawner._spawnable_scenes` |
