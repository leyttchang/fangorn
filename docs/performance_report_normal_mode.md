# Rapport Performance — Mode NORMAL (map_generator)

> Analyse statique (aucun code modifié, **aucun profilage réel lancé**). Les gains indiqués sont des estimations d'ordre de grandeur : il faut les confirmer avec le profiler (voir §6).
> Config lue dans `map_generator.tscn` : carte **1×1 chunk (1024×1024 m)**, `max_height=200`, `max_trees=60000`, 10 packs ambush + 10 patrol + 10 roam, 6 encounters.

---

## 0. Résumé : où part le FPS (par ordre de suspicion)

| # | Cause | Type | Gain estimé |
|---|---|---|---|
| 1 | Pluie : 10 000 particules **ribbon trail** + collision **HeightField** + **sub-emitter** (16 000 étincelles) | GPU | 🔴 très gros (10-30 FPS) |
| 2 | Herbe : espacement **0.6 m** → des centaines de milliers d'instances dans les 200 m visibles | GPU (vertex/draw) | 🔴 gros |
| 3 | Environnement nuit : SSAO + SSIL + glow + **volumetric fog** + ombres directionnelles | GPU | 🔴 gros |
| 4 | Ombres des arbres (MultiMesh en `cast_shadow` ON, échelle 8-12 + mur d'arbres échelle 24-32) | GPU | 🟠 moyen/gros |
| 5 | Monstres : ~30+ packs, scaling multi, IA/animations/nav par ennemi | CPU | 🟠 moyen |
| 6 | Paramètres rendu : driver D3D12, FSR actif à `render_scale=1.0` (inutile), pas de LOD | GPU | 🟠 moyen |
| 7 | Scène `.tscn` de 449 Ko avec 118 nœuds de monstres/encounters « bakés » | chargement / mémoire | 🟡 faible FPS, gros temps de chargement |
| 8 | Terrain3D `collision_mode = 3` (Full/Game) | mémoire / démarrage | 🟡 faible |

---

## 1. Pluie (`map/meteo/raining/rain.tscn`, `rain.gd`, `map/map_generator/timer_sys.gd`)

Constats (fichier [rain.tscn](file:///y:/Fangorn/fangorn/map/meteo/raining/rain.tscn)) :
- `rain_P` : `amount = 10000`, `trail_enabled = true` (`trail_lifetime 0.12`), mesh `RibbonTrailMesh` (6 sections) → chaque goutte = ruban de ~12+ triangles + matériau **transparent / additif**. Gros overdraw.
- `fixed_fps = 120` : le sim particules tourne à 120 Hz même si le jeu est à 60.
- `collision_mode = 2` (HeightField) + nœud `GPUParticlesCollisionHeightField3D` de **200×250×200 m** : le moteur re-rend la scène vue du dessus pour fabriquer la heightmap. Comme `rain.gd` déplace le nœud **chaque frame** avec le joueur, la heightmap est probablement **régénérée en continu** (et rend terrain + arbres + herbe selon le `cull_mask` = presque toutes les couches).
- `sub_emitter_mode = 3` (à la collision) avec `sub_emitter_amount_at_collision = 4` → `spraks` (`amount = 16000`, additif, billboard) : jusqu'à 4 étincelles par goutte au sol = pic de dizaines de milliers de particules transparentes.
- `emission_ring_radius = 80` : toute la pluie est émise sur un disque de 160 m de diamètre, dont une grande partie hors champ ou loin de la caméra.
- `timer_sys.gd` force `amount = max_rain_particles` (10 000) dès le départ, donc le buffer est alloué à plein même quand `amount_ratio` est bas ; la montée « 500→10 000 » ne réduit que l'émission, pas la mémoire.

Pistes (de la plus rentable à la moins rentable) :
1. **Supprimer le sub-emitter** `spraks` (ou le réduire à 1 étincelle, `amount` ≪ 16000, ou le faire uniquement dans un rayon ~15 m du joueur). Probablement le plus gros gain.
2. **Désactiver la collision HeightField** et la remplacer par : particules qui meurent à une hauteur fixe sous la caméra (`lifetime` ajusté), ou une petite zone de collision (ex. 40×40 m) avec `update_mode = WHEN_MOVED` et résolution basse, ou une collision `Box` plate au niveau du sol local.
3. **Baisser le nombre de gouttes** (3 000-4 000 suffisent avec des gouttes plus longues/plus visibles) et resserrer `emission_ring_radius` (80 → 30-40 m ; la pluie lointaine est invisible de toute façon avec le fog).
4. **Remplacer le ribbon trail** par un simple quad étiré (billboard Y, 2 triangles) : 6× moins de géométrie par goutte.
5. `fixed_fps` 120 → 30-60 (+ `interpolate = true`).
6. Matériau : passer de `blend_mode ADD` + `transparency ALPHA` à un seul mode, `shading_mode unshaded` (déjà), pas de depth-draw ; vérifier `visibility_aabb` pas démesurée.
7. Dans `timer_sys.gd` : ne pas allouer le `amount` max au démarrage, allouer au palier ; arrêter complètement le nœud (`visible=false`, `emitting=false`) tant qu'il ne pleut pas (déjà le cas pour `emitting`, mais `spraks` + HeightField restent dans l'arbre).

---

## 2. Herbe (`map/map_generator/grass_generator.gd`)

Constats ([grass_generator.gd](file:///y:/Fangorn/fangorn/map/map_generator/grass_generator.gd)) :
- `spacing` n'est pas surchargé dans la scène → **0.6 m** (défaut). Grille ≈ 954/0.6 ≈ **1590 × 1590 ≈ 2,5 M de points** avant filtres.
- `max_draw_distance = 200` (scène) : disque visible ≈ π·200² ≈ 125 000 m² → **~350 000 touffes candidates** dans le rayon, ~50 % après le bruit/seuil → **~150-200 k instances** potentiellement dessinées en même temps.
- Chunks de 64 m (OK pour le frustum culling) mais **un seul mesh de touffe sans LOD** : chaque instance est dessinée en entier jusqu'à 200 m. `visibility_range_end_margin = 20` avec fade mode par défaut (`DISABLED`) = pop-in net mais pas de coût de dithering (bien).
- `cast_shadow = OFF` : **correct**, à garder.
- `rng.seed = 123456` codé en dur (pas la `world_seed`) : pas un problème de perf, mais ce n'est plus « la même seed que la map ».
- Génération : boucle GDScript de ~2,5 M itérations + `terrain.data.get_height()` par point = **plusieurs secondes de CPU au chargement** (étalé par `await` toutes les 16 lignes, donc pas de freeze mais long).

Pistes :
1. **Réduire `max_draw_distance` à 60-80 m** (l'herbe 0.5-1.5 m n'est plus lisible au-delà, surtout avec brume/pluie). Gain direct ≈ ×6-8 sur le nombre d'instances.
2. **Augmenter `spacing`** à 0.9-1.2 m (densité ÷2-4) et compenser par un `min_scale/max_scale` un peu plus grand.
3. **Densité décroissante avec la distance** : 2 niveaux de MultiMesh par chunk (dense près, clairsemé loin) ou `visibility_range_begin/end` croisés (LOD1 dense 0-40 m / LOD2 1 instance sur 4 de 40 à 80 m).
4. **Mesh de touffe plus léger** : vérifier le nombre de triangles de [grass_2.tscn](file:///y:/Fangorn/fangorn/map/grass/grass_2.tscn) (cible ≤ 20-40 triangles, matériau alpha-scissor plutôt qu'alpha blend, pas d'`alpha`/transparence, shader sans `discard` lourd).
5. **Alternative recommandée** : utiliser l'**instancer natif de Terrain3D** (`mesh_list` déjà présent dans `Terrain3DAssets`) qui gère les chunks, le LOD et le culling pour l'herbe ; `map_optimize.gd` y fait déjà référence.
6. Génération : passer à un calcul par chunk à la demande (streaming autour du joueur) plutôt que toute la carte d'un coup ; ou précalculer dans un `PackedVector3Array` via un thread (`WorkerThreadPool`).
7. Ne **pas** générer l'herbe au-dessous des zones boisées denses (arbres échelle 8-12 ⇒ le sol est à l'ombre/caché) : filtrer avec le `forest_noise` du `MeshSpawner`.

---

## 3. Environnement / post-process (`map/meteo/night_time/night_time.tscn`, `SettingsManager`)

Constats ([night_time.tscn](file:///y:/Fangorn/fangorn/map/meteo/night_time/night_time.tscn)) :
- `ssao_enabled = true`, `ssil_enabled = true`, `glow_enabled = true`, `tonemap_mode = 4`, **`volumetric_fog_enabled = true`** (`volumetric_fog_length = 152`, `light_volumetric_fog_energy = 15`), `fog_mode`, `DirectionalLight3D shadow_enabled = true` (modes de split / `directional_shadow_max_distance` jamais réglés → défauts : 4 cascades, 100 m).
- SSIL + volumetric fog + SSAO sont parmi les effets les plus coûteux de Forward+ ; ensemble ils peuvent coûter 30-50 % du frame sur GPU moyen, **surtout en 1920×1080 natif**.
- [SettingsManager](file:///y:/Fangorn/fangorn/scripts/globals/settings_manager.gd) : `render_scale = 1.0`, `fsr_mode = 1` (FSR 1.0) → FSR à l'échelle 1.0 **n'apporte aucun gain** (il ne fait que du post-sharpening). `volumetric_fog_enabled`, `shadow_quality` existent déjà mais le défaut est « High / ON ».
- `map_optimize.gd` (qui coupe ssao/ssil selon la qualité) est dans `map/map/`, c'est-à-dire côté **wave mode** ; vérifier qu'il est aussi instancié sous `map_generator.tscn` (sinon les réglages de qualité n'ont aucun effet sur le mode NORMAL).

Pistes :
1. **Désactiver SSIL** (très cher, gain visuel faible) ; garder SSAO à demi-résolution (`ssao_half_size`/`ssao_detail` bas) ou le couper.
2. **Volumetric fog** : réduire `volumetric_fog_length` (152 → 60-80), densité plus faible, ou le remplacer par du `fog` classique (`fog_mode`/`fog_density`) + `fog_height`. Projet : `rendering/environment/volumetric_fog/volume_size` (64→32) et `volume_depth` (64→32).
3. **Ombres directionnelles** : `directional_shadow_mode = PSSM 2 splits`, `directional_shadow_max_distance` 100 → 60-80, `shadow_blur` bas, `Project Settings > rendering/lights_and_shadows/directional_shadow/size` 4096 → 2048, `soft_shadow_filter_quality` Low.
4. **Mettre `render_scale` à 0.75-0.85 avec FSR 1.0 / FSR 2.2** par défaut (ou un preset « Performance »). Gain typique 25-40 % GPU sur ce genre de scène bound-fill.
5. Passer le **driver Windows de `d3d12` à `vulkan`** (`rendering_device/driver.windows`) : en Godot 4.x le backend Vulkan est généralement plus rapide et plus stable ; à tester car ça varie selon la carte.
6. Activer `rendering/occlusion_culling/use_occlusion_culling` (déjà ON) n'aide pas ici (terrain ouvert) — il peut même coûter ; à mesurer avec/sans.
7. Presets de qualité : brancher `SettingsManager` pour que « Bas » désactive SSAO/SSIL/volumetric/pluie-trail d'un coup.

---

## 4. Arbres (`mesh_spawner.gd`, `border_tree_wall.gd`)

Constats :
- Architecture **correcte** : `MultiMeshInstance3D` par chunk de 128 m, collisions via `PhysicsServer3D` (pas de nœuds), `visibility_range_end = 350` (marge 50), culling OK. `max_trees = 60000` est un plafond, pas le nombre réel : avec `grid_spacing = 28` par défaut ≈ 36² ≈ 1300 points avant le filtre bruit → **quelques centaines d'arbres**, mais d'**échelle 8-12** (donc très gros à l'écran).
- **Ombres** : le `MultiMeshInstance3D` des arbres ne règle pas `cast_shadow` (donc ON). Chaque arbre énorme est dessiné dans les cascades d'ombres (jusqu'à 4 passes). Ni `visibility_range_fade_mode` ni LOD.
- **Mur de bordure** (`border_tree_wall.gd`) : `tree_spacing = 10`, `min/max_scale = 24-32`, 1 rangée → ~**400 arbres géants** autour des 4 côtés, `visibility_range_end = 450`. Avec leur taille, ils occupent beaucoup de pixels et projettent des ombres énormes ; ils sont visibles de loin même si le joueur est à l'autre bout (450 m).
- Shader d'arbre `res://particule/shader/tree.gdshader` (vent ?) : vérifier qu'il n'utilise pas de calculs lourds par vertex/fragment (sin/cos multiples, `discard`, transparence).
- Mesh source `Tree Type6 04.dae` : **nombre de triangles inconnu** — à vérifier (cible : ≤ 1500-2500 tris près, version ≤ 400 tris ou billboard au loin).

Pistes :
1. `cast_shadow = SHADOW_CASTING_SETTING_OFF` sur le **mur de bordure** (invisible de toute façon depuis l'intérieur), et sur les arbres au-delà de ~80-100 m (2e MultiMesh « LOD lointain » sans ombre).
2. **LOD d'arbres** : 2-3 niveaux via `visibility_range_begin/end` croisés (mesh complet 0-120 m, mesh simplifié 120-250 m, billboard/impostor 250-350 m).
3. Importer les `.dae` en **mesh LOD automatique** (`ImporterMesh.generate_lods`, activé par défaut pour `.glb/.gltf`) ; convertir en `.glb` pour bénéficier des LOD et de `mesh_lod_threshold`.
4. Mur de bordure : `visibility_range_end` 450 → 200-250 (le brouillard cache de toute façon), `wall_rows = 1` (déjà), `tree_spacing` 10 → 14 si les troncs se touchent déjà.
5. Réduire `visibility_range_end` des arbres à 250-300 si le fog est dense ; ajuster `visibility_range_fade_mode` sur `DISABLED` (déjà par défaut, bien).
6. `Terrain3D` : s'assurer que la caméra du **joueur local** est bien liée (`set_camera`) sinon le LOD/clipmap se calcule depuis la mauvaise position (un fix existe dans `game.gd` et `player.gd`).

---

## 5. Monstres / IA / réseau

Constats :
- [map_generator.tscn](file:///y:/Fangorn/fangorn/map/map_generator/map_generator.tscn) contient **118 nœuds enfants de `MonsterPackGenerator`** (AmbushPack_*, PatrolPack_*, RoamPack_* + leurs monstres) et 12 sous-nœuds `Encounters` **sauvegardés dans la scène** (reste d'un test en éditeur avec `spawn_now`). En jeu, `generate_monster_packs()` appelle d'abord `clear_monster_packs()` (qui supprime tous les enfants), donc le serveur/solo les remplace — mais :
  - ils sont **instanciés puis détruits** à chaque chargement (temps de chargement, pic mémoire, 449 Ko de `.tscn` à parser) ;
  - **sur un client multi, `generate_monster_packs()` retourne tôt → les 118 nœuds sauvegardés restent actifs côté client** (monstres fantômes dupliqués non synchronisés + coût CPU/GPU inutile). Bug de perf **et** de gameplay à corriger.
- Nombre de monstres : 10+10+10 packs × (2-4 monstres) ≈ **90-110 ennemis** en solo, ×1.33 à ×2 en multi (`difficulty_scale_per_extra_player`), +1/pack à ≥3 joueurs. Types : `dumb`, `scout`, `creep`, `dumb_archer`, `spider_enemie`.
- [EnemyOptimizerComponent](file:///y:/Fangorn/fangorn/components/enemy_optimizer_component.gd) fait déjà du bon travail (culling visuel 85 m, coupure animation hors-écran/65 m, raycasts/IK coupés). Points faibles :
  - `_update_culling_state()` appelle `get_tree().get_nodes_in_group("Player")` et `get_camera_3d()` pour **chaque ennemi toutes les 0,18-0,28 s** ; avec 100 ennemis = ~400 allocations d'`Array`/s. À mutualiser dans un manager unique (1 passe pour tous).
  - Un `VisibleOnScreenNotifier3D` par ennemi (100+ notifiers) ; acceptable mais cumulatif.
  - Les ennemis **hors-champ mais proches (<16 m)** animent toujours (voulu).
  - Pas de **désactivation du `_physics_process`/IA** pour les ennemis lointains (>120-150 m) non-aggro : ils continuent de tourner (patrouilles/roam, NavigationAgent, `move_and_slide`).
- [EnemyNavigationComponent](file:///y:/Fangorn/fangorn/components/enemy_navigation_component.gd) : `get_nodes_in_group("Player")` dans la détection ; `nav_agent.target_position` est mis à jour seulement si la cible a bougé de >1,5 m (bien). Vérifier `avoidance_enabled` (RVO coûteux avec beaucoup d'agents) et `path_max_distance` / `navigation_layers`.
- Navmesh : 1 seul `NavRegion_0_0` (carte 1×1), `cell_size 0.75` sur 1024×1024 m : **maillage très dense** (≈ 1,9 M cellules) → pathfinding plus lent et RAM élevée. Passer `cell_size` à 1.0-1.5 et `cell_height` 0.25→0.4 divise fortement le coût. Le cuisson est asynchrone (ok) mais **dure** au chargement.
- Réseau (même en solo, `multiplayer` actif) : chaque ennemi a un `MultiplayerSynchronizer` (position/rotation/vie en continu) ; en solo sans peer ça reste léger, en multi c'est de la bande passante (×100 ennemis). Prévoir `replication_interval` plus grand (0,05-0,1) et `visibility` filtrée par distance (`public_visibility=false` + `set_visibility_for`).

Pistes :
1. **Nettoyer la scène** : supprimer les 118 nœuds sauvegardés dans `MonsterPackGenerator` et les 12 sous-nœuds `Encounters` (et vider `NavRegions`/`Meteo` si instanciés par erreur). Conséquences : `.tscn` ~449 Ko → quelques Ko, chargement plus rapide, plus de monstres fantômes côté client.
2. **Manager d'optimisation unique** (Autoload ou nœud) : un seul `_process` tous les 0,25 s qui parcourt la liste des ennemis et pose `is_anim_culled`, au lieu d'un timer + `get_nodes_in_group` par ennemi.
3. **Sleep des ennemis lointains** : au-delà de ~150 m du joueur le plus proche et sans cible → `process_mode = DISABLED` (ou ticks IA 4× plus lents), réveil par distance.
4. Cap global : `max_active_enemies` (ex. 60) + spawn dynamique par proximité du joueur au lieu de tout instancier au démarrage (le `MonsterPackGenerator` pourrait créer les packs **à la demande** quand un joueur s'approche à <200 m et les libérer ensuite).
5. `NavigationAgent3D` : `avoidance_enabled = false` pour les ennemis non-boss, `path_postprocessing = CORRIDORFUNNEL`, `max_speed` cohérent, recalcul de chemin ≤ 4 Hz.
6. Spider (`spider_enemie`) : vérifier les `Skeleton3D`/IK et collisions multiples (ne contient pas de RayCast/IK dans la scène elle-même, mais sa logique de pattes peut le faire en code) ; passer à `AnimationPlayer` simple à distance.

---

## 6. Paramètres projet / moteur à vérifier

- `rendering_device/driver.windows = "d3d12"` → tester `vulkan`.
- `physics/common/physics_interpolation = true` : coût mesurable avec 100+ corps ; vérifier qu'il n'interpole que les nœuds nécessaires.
- `jolt_physics_3d/limits/*` surdimensionnés (65536 corps) : n'impacte pas le FPS mais la mémoire préallouée (`temp_buffer_size` 64 Mo) ; inutile de monter.
- Terrain3D : `collision_mode = 3` (Full/Game) construit un collider pour **toute** la carte au démarrage ; `Dynamic/Game` (1) ne génère la collision que près du joueur → moins de mémoire et démarrage plus rapide. Aussi `mesh_lods`, `mesh_size`, `vertex_spacing` (laisser 1.0 sauf besoin) et `render_cull_margin` à examiner.
- MSAA/TAA/FXAA non réglés : vérifier `rendering/anti_aliasing/*` (MSAA 3D coûte cher avec beaucoup de transparence ; préférer FXAA/TAA + FSR).
- Cap FPS : `fps_cap = 0` + `vsync = true`. Ok. Si le moniteur est 60-75 Hz, 50-80 FPS peut être simplement du VSync qui bascule entre 60 et 30 → **tester avec VSync OFF** pour mesurer la vraie perf.

---

## 7. Méthode de mesure (à faire AVANT de coder, pour prioriser)

1. **Moniteurs Godot (Debugger → Monitors / Visual Profiler)** en mode NORMAL, 1 joueur, au spawn puis en pleine forêt :
   - Rendu : `Draw Calls`, `Objects drawn`, `Primitives drawn`, `Video RAM`, `Frame time CPU vs GPU` (si GPU ≫ CPU → §1-4 ; si CPU ≫ GPU → §5).
2. **Bascules ciblées** (un seul changement à la fois, noter FPS) :
   - cacher le nœud `rain` ;
   - désactiver `spraks` seul (`emitting=false`) ;
   - `grass_generator.visible = false` ;
   - cacher `MeshSpawner` puis `BorderTreeWall` ;
   - désactiver `WorldEnvironment` (ou chaque effet : SSAO, SSIL, volumetric fog, glow) ;
   - `DirectionalLight3D.shadow_enabled = false` ;
   - supprimer/cacher `MonsterPackGenerator` ;
   - `render_scale = 0.7`.
3. **Menu View → Display Overdraw / Wireframe** (éditeur) pour voir l'overdraw de la pluie, l'herbe et les arbres géants.
4. Profiler script (GDScript) pour le CPU : `_physics_process` des ennemis, `EnemyOptimizerComponent._update_culling_state`, `EnemyNavigationComponent`.

---

## 8. Plan d'action priorisé (pour l'autre IA)

**Quick wins (≈ 30 min, gros impact attendu) :**
1. `rain.tscn` : retirer `sub_emitter`/réduire `spraks`, passer `amount` 10000 → 3000-4000, `trail_enabled=false` (ou quad), `emission_ring_radius` → 35, `fixed_fps` → 30-60, désactiver/shrinker la HeightField.
2. Herbe : `max_draw_distance` 200 → 70, `spacing` 0.6 → 0.9-1.0.
3. Environnement : SSIL OFF, volumetric fog réduit (ou fog classique), `directional_shadow_max_distance` ~70, 2 splits.
4. `BorderTreeWall` : `cast_shadow OFF`, `visibility_range_end` 450 → 250.
5. `SettingsManager` : `render_scale` 0.8 par défaut, preset « Performance ».

**Moyen terme :**
6. Nettoyer `map_generator.tscn` (118 + 12 nœuds sauvegardés) → corrige aussi les monstres fantômes côté client.
7. LOD arbres (mesh simplifié + billboard) et `cast_shadow` désactivé au-delà de ~100 m.
8. Manager d'optimisation ennemis unique + sleep des ennemis lointains + spawn de packs par proximité.
9. Navmesh `cell_size` 0.75 → 1.0-1.5 ; `avoidance_enabled` off.
10. Terrain3D `collision_mode` → Dynamic/Game ; test driver Vulkan.

**Long terme :**
11. Herbe via l'instancer natif de Terrain3D ou streaming par chunk + LOD.
12. Presets de qualité complets (Bas/Moyen/Haut) qui pilotent pluie, herbe, brouillard, ombres, nombre d'ennemis actifs.
13. Réplication réseau : `replication_interval` + filtrage de visibilité par distance pour les ennemis.

## 9. Points de vigilance multijoueur liés à la perf

- Tout ce qui est visuel (herbe, arbres, mur, pluie) est **local et déterministe** : on peut le réduire par joueur (preset de qualité) **sans désynchroniser** le gameplay. Les collisions d'arbres, elles, doivent rester identiques partout (ne pas toucher au placement/seed).
- Ne pas changer `grid_spacing`, seed offsets (`+101`, `+202`, `+5544`, `+9876`, `+7777`) ni l'ordre des appels `rng` : cela changerait la carte et casserait la cohérence entre clients.
- `rain.gd` utilise `_noise.seed = randi()` : le vent diffère par client (purement visuel, OK).
- Le scaling de monstres est basé sur `GameData.starting_player_count` : ne pas l'optimiser en réduisant le nombre côté serveur sans le répercuter côté difficulté.
