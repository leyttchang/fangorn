# Optimisations « sans changer le rendu ni le gameplay »

> Complément de `performance_report_normal_mode.md` (non modifié). Ici : uniquement ce qui coûte des perfs **sans rien apporter** visuellement ou en gameplay. Aucune réduction de densité/portée « visible ».
> Rien n'a été profilé : chaque point doit être validé par une mesure avant/après (voir §9).

## Correction par rapport au premier rapport
- Les nœuds enfants sauvegardés dans `map_generator.tscn` (monstres, encounters) **ne posent pas de problème** : `generate_terrain_async()` appelle `clear_terrain()` sur **tous les peers** (serveur et clients), qui appelle `clear_monster_packs()` / `clear_encounters()`. J'avais écrit à tort que les clients gardaient des monstres fantômes : c'est faux. Il ne reste qu'un petit surcoût de chargement (scène de 449 Ko instanciée puis vidée), négligeable. **À ignorer.**
- `render_scale = 1.0` par défaut : OK, c'est un réglage utilisateur. À ignorer.

---

## 1. Herbe : supprimer le « cercle visible » ET gagner des perfs

### Pourquoi on voit le cercle
Dans [grass_generator.gd](file:///y:/Fangorn/fangorn/map/map_generator/grass_generator.gd), la distance se règle par **chunk de 64 m** (`visibility_range_end = max_draw_distance` sur chaque `MultiMeshInstance3D`). La coupure se fait donc **par blocs carrés de 64 m**, avec un « pop » franc (le `fade_mode` est `DISABLED` par défaut, la marge de 20 m ne sert à rien dans ce mode). Résultat : un contour en escalier, très visible quand on marche. Baisser la distance rend le défaut encore plus visible.

### Solution recommandée : fondu par instance dans le shader (aucun coût en plus)
Dans le shader du matériau d'herbe (celui du `grass_2.tscn`, à passer en `ShaderMaterial` si c'est un `StandardMaterial3D`), dans `vertex()` :
- calculer la distance caméra ↔ instance : `float d = length((MODEL_MATRIX * vec4(0,0,0,1)).xyz - CAMERA_POSITION_WORLD);` (avec un MultiMesh, `MODEL_MATRIX` inclut la transformation de l'instance) ;
- appliquer un **rétrécissement progressif** : `float k = 1.0 - smoothstep(fade_start, fade_end, d); VERTEX *= k;` avec par ex. `fade_start = 0.75 * max_draw_distance` et `fade_end = max_draw_distance`.
Les touffes **poussent/rapetissent dans le sol** sur les derniers 25 % de la distance : plus de cercle net, plus de pop. Le coût GPU est quasi nul, et les triangles dégénérés (scale 0) sont éliminés tôt.
Variante : `ALPHA` + dithering (`ALPHA_SCISSOR` avec un seuil bruité par distance) si le rétrécissement ne plaît pas.

Ensuite :
- passer `visibility_range_end` des chunks à `max_draw_distance + taille_chunk` (~ +64 m) pour que le chunk entier ne disparaisse que quand **toutes** ses touffes sont déjà à échelle 0 (l'effet visuel est alors purement géré par le shader) ;
- le brouillard (`fog`) masque aussi le reste : aligner `fade_end` sur la distance où le fog est ≥ 70-80 %.
Cela permet d'utiliser une portée **un peu plus courte qu'aujourd'hui sans que ça se voie**, mais c'est un choix à valider visuellement (la demande est de ne rien changer : garder 200 m si besoin, le fondu règle déjà le côté moche).

### Réduire le coût sans toucher à la densité visible
1. **Mesh d'herbe** ([grass_2.tscn](file:///y:/Fangorn/fangorn/map/grass/grass_2.tscn)) : vérifier le nombre de triangles (cible 8-24 tris par touffe). Un bouquet fait de 2-3 quads croisés avec texture alpha donne le même rendu qu'un mesh de 100 tris, pour 5× moins de sommets. C'est **le** levier principal et invisible : à 150 000+ instances, 10 triangles de moins = ~1,5 M de triangles économisés par frame.
2. **Matériau** : `alpha scissor` (+ `alpha_scissor_threshold`, `alpha_antialiasing` éventuel) plutôt que `alpha blend` (le blend désactive l'écriture de profondeur → overdraw massif et tri coûteux). `shading_mode` simple, pas de `cull_mode = disabled` si le mesh est double-face par construction, textures avec mipmaps et compression VRAM.
3. **LOD à 2 niveaux, rendu identique** : par chunk, un MultiMesh « proche » (0-70 m, mesh complet) et un « loin » (70-200 m) avec un **mesh plus léger** (ex. 2 quads croisés) via `visibility_range_begin/end` avec marge croisée. À cette distance, la différence de géométrie est invisible, surtout avec la pluie/fog.
4. **Densité « apparente » identique au loin** : au loin, la moitié des instances avec une échelle ×1,4 donne la même couverture visuelle pour moitié moins de coût (à faire sur le niveau « loin » seulement).
5. **Chunks plus petits** (64 → 32 m) : le culling frustum/distance est plus fin. Coût CPU un peu plus haut (plus de nœuds : ~1000 chunks pour 1024²), à tester avec la pluie/arbres.
6. **Ne pas planter d'herbe sous les arbres/zones couvertes** : filtrer avec `forest_noise` du `MeshSpawner` et la distance aux troncs (invisible pour le joueur, supprime des instances cachées par les arbres).
7. **Ne pas planter là où le joueur ne va jamais** : bande plate de bordure (`border_margin`) derrière le mur d'arbres, pentes très raides (> `max_slope`) où il y a déjà de la roche.
8. `custom_aabb` sur les MultiMesh : mettre la hauteur réelle (`h` max/min du chunk) pour que le frustum culling soit exact (par défaut l'AABB peut être trop grand/petit).
9. **Génération** (chargement uniquement) : déjà asynchrone ; possibilité de la passer dans un `WorkerThreadPool` ou de précalculer les transforms avec un `PackedVector3Array`. N'a aucun effet sur les FPS mais accélère le chargement.

---

## 2. Rendu : gains invisibles
- **Driver** : tester `rendering_device/driver.windows = "vulkan"` à la place de `d3d12` (même rendu, souvent plus rapide).
- **VSync** : vérifier que les 50-80 FPS ne sont pas un artefact de VSync (60 Hz → sauts 60/30). Tester avec VSync OFF.
- **Compression des textures** : toutes les textures 3D en VRAM compressée (BPTC/S3TC) + mipmaps + filtre anisotrope modéré. Gain mémoire et bande passante, rendu identique.
- **Matériaux** : un seul `Material` partagé par espèce d'arbre/herbe (déjà le cas via `material_override`) ; supprimer les `next_pass`/overlays inutilisés sur les arbres et ennemis.
- **Ombres directionnelles** : `directional_shadow_max_distance` ne doit pas dépasser la distance où l'ombre est réellement visible (brouillard/pluie). Régler aussi `directional_shadow_split_*` pour concentrer la résolution près du joueur ; **l'aspect reste identique** si on ne réduit pas la qualité près de la caméra.
- **Ombres des arbres lointains** : au-delà de la distance max d'ombre, le moteur dessine quand même ces arbres dans les passes d'ombre si leur AABB croise la cascade. Mettre les **chunks lointains** d'arbres en `cast_shadow = OFF` (via `visibility_range` croisé ou un second MultiMesh sans ombre) : invisible, car cet arbre ne projette plus d'ombre exploitable de toute façon.
- **Mur de bordure** (`border_tree_wall.gd`) : ses arbres sont derrière le joueur de toute façon ; `cast_shadow` OFF seulement si l'ombre n'est pas visible sur le terrain jouable (à vérifier près du bord), et `visibility_range_end` 450 → distance où le fog est déjà opaque (~250-300).
- **Mesh d'arbres** : activer/générer des **LOD automatiques** (importer en `.glb`, `generate_lods`, `mesh_lod_threshold`) : même aspect, moins de triangles au loin. Vérifier le nombre de triangles de `Tree Type6 04.dae`.
- **Occlusion culling** : le terrain est ouvert, donc `use_occlusion_culling` n'apporte probablement rien et a un petit coût CPU ; mesurer ON/OFF.

---

## 3. Pluie : choses qui ne changent pas l'aspect (déjà validé « ok » côté sujet, mais sans impact visuel)
- `visibility_aabb` des particules au plus près de la zone réelle, `fixed_fps` à 60 avec `interpolate = true` (la pluie reste fluide).
- `spraks` : ne l'émettre que dans un rayon ~15-20 m du joueur (au-delà, les impacts sont invisibles).
- Ne pas allouer `amount = 10000` quand `amount_ratio` est petit ; arrêter tout le nœud tant qu'il ne pleut pas (`process_mode = DISABLED`, `visible = false` pour la HeightField et `spraks`).
- `rain.gd` : `_apply_wind` réécrit `process_material.gravity` chaque frame ; passer à 10-15 Hz avec interpolation (aucun écart visible).

---

## 4. Monstres / IA / animations (CPU) : aucun changement de gameplay
1. **`EnemyOptimizerComponent`** ([enemy_optimizer_component.gd](file:///y:/Fangorn/fangorn/components/enemy_optimizer_component.gd)) : chaque ennemi appelle `get_tree().get_nodes_in_group("Player")` et `get_camera_3d()` à ~4 Hz. Centraliser dans **un seul** manager qui calcule la position caméra/joueurs une fois et met à jour tous les ennemis dans une boucle ; supprime des centaines d'allocations d'`Array` par seconde.
2. **`EnemyNavigationComponent`** ([enemy_navigation_component.gd](file:///y:/Fangorn/fangorn/components/enemy_navigation_component.gd)) : même chose pour `get_nodes_in_group("Player")` (mettre en cache la liste des joueurs, rafraîchie sur `child_entered_tree`/`tree_exited` du groupe ou toutes les 0,5 s). Étaler les recalculs de cible dans le temps (timer désynchronisé par ennemi).
3. **`NavigationAgent3D`** : `avoidance_enabled = false` pour les ennemis qui n'en ont pas réellement besoin (si le rendu actuel n'en dépend pas) ; `path_postprocessing`, `max_neighbors`, `neighbor_distance` réduits. À valider visuellement : si les monstres ne se traversent pas aujourd'hui sans RVO, ne pas y toucher.
4. **Hors-écran / lointain** : le composant coupe déjà l'animation ; compléter en suspendant aussi le `_physics_process` d'**IA** (pas la gravité) des ennemis non-aggro à > ~150 m, avec un tick réduit (ex. 5 Hz) : comportement identique du point de vue du joueur car ils sont invisibles et inactifs.
5. **Pack AI** (`MonsterPack._physics_process`) : `_cleanup_invalid_members()` et `_find_active_target_in_pack()` à chaque frame physique pour chaque pack ; passer à 5-10 Hz (le comportement n'est pas perceptible).
6. **Ambush** : `_process_ambush_detection()` boucle sur tous les joueurs + tous les membres chaque frame ; limiter à 10 Hz.
7. **Navmesh** : si les chemins sont corrects aujourd'hui, `cell_size 0.75 → 1.0` réduit mémoire/temps de cuisson/pathfinding (à vérifier que les monstres ne se coincent pas près des arbres ; sinon garder).
8. **Synchronisation réseau** (surtout en multi) : `MultiplayerSynchronizer` des ennemis avec `replication_interval` (ex. 0,05 s) et visibilité filtrée par distance ; interpolation déjà gérée par `NetworkSmoother`.

---

## 5. Physique
- Les collisions d'arbres passent déjà par `PhysicsServer3D` (bien). Vérifier que les corps statiques d'arbres sont sur une couche/masque minimal pour ne pas être testés par les projectiles/sorts inutilement (réduit les paires broadphase).
- `common/physics_interpolation = true` : l'activer seulement pour les nœuds qui en ont besoin ; pour les ennemis loin de la caméra, `physics_interpolation_mode = OFF`.
- Jolt : les limites (65 536 corps, 64 Mo de tampon) n'affectent pas le FPS, juste la mémoire préallouée ; laisser.

---

## 6. Terrain3D
- `collision_mode = 3` (Full/Game) génère la collision de **toute** la carte au démarrage ; **Dynamic/Game (1)** ne la génère qu'autour du joueur : même gameplay, moins de mémoire, démarrage plus rapide.
- Vérifier `mesh_lods`, `mesh_size` et `vertex_spacing` aux valeurs par défaut du plugin (inutile de les augmenter).
- Les `set_camera()` multiples (joueur local, spectateur) : s'assurer que la **seule** caméra liée est celle du joueur local (déjà géré dans `game.gd` / `player.gd`).

---

## 7. Scripts @tool : s'assurer qu'ils ne tournent pas en jeu
Les scripts `@tool` (`map_generator.gd`, `mesh_spawner.gd`, `grass_generator.gd`, `monster_pack_generator.gd`, `encounters.gd`, `pnj_encounter.gd`, `meteo.gd`, `timer_sys.gd`) doivent avoir `if Engine.is_editor_hint(): return` dans tout `_process/_physics_process` (c'est déjà le cas pour `timer_sys.gd`). Vérifier qu'aucun `_process` vide ou coûteux ne reste actif en jeu (un `_process` qui ne fait rien coûte quand même un appel par frame par nœud : `set_process(false)` dans `_ready()` si inutile).

---

## 8. Temps de chargement (aucun effet FPS, aucun effet visuel)
- Générer l'herbe/arbres dans un thread et réutiliser le même `Mesh`/`Material` (déjà fait pour les arbres).
- Précharger les scènes ennemies (`preload` déjà utilisés) ; éviter les `load()` dans les boucles de spawn.
- `shader_precompiler.gd` : couvre déjà abilities/particules ; ajouter le matériau d'herbe, le shader d'arbre et les matériaux du terrain pour éviter les saccades à la première apparition.

---

## 9. Comment valider (rapide)
1. Noter FPS + `Frame time CPU/GPU` (Debugger → Monitors) : spawn, forêt dense, combat avec ~10 ennemis.
2. Appliquer **un** changement à la fois (ordre conseillé ci-dessous), re-mesurer.
3. Comparer des captures aux mêmes positions pour s'assurer que **le rendu est identique** (surtout herbe et fondu lointain).

### Ordre conseillé (impact / risque visuel)
| Priorité | Action | Risque visuel |
|---|---|---|
| 1 | Fondu d'herbe par shader + vérifier triangles/matériau alpha-scissor | nul (améliore le rendu) |
| 2 | LOD mesh d'herbe lointaine (2 quads) | nul si bien réglé |
| 3 | Driver Vulkan + test VSync OFF | nul |
| 4 | Ombres : cascades/distances réglées pour ne cacher que l'invisible ; `cast_shadow` OFF des arbres lointains et du mur | quasi nul |
| 5 | LOD arbres (`.glb` + `generate_lods`) | quasi nul |
| 6 | Manager unique d'optimisation + caches de joueurs/caméra (IA, nav, packs, ambush) | nul |
| 7 | `Terrain3D collision_mode` Dynamic | nul |
| 8 | Particules de pluie : `visibility_aabb`, `fixed_fps` 60 + interpolation, `spraks` limitées au voisinage | nul |
| 9 | Navmesh `cell_size` 1.0, RVO off | à vérifier (comportement IA) |
