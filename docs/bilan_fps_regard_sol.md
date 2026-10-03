# Bilan FPS « regard vers le sol » (140-180 FPS au ciel → 50-80 au sol)

> Analyse statique après lecture de [changements_optimisations.md](file:///y:/Fangorn/fangorn/docs/changements_optimisations.md), du [grass_generator.gd](file:///y:/Fangorn/fangorn/map/map_generator/grass_generator.gd) et du [grass.gdshader](file:///y:/Fangorn/fangorn/assets/3D_models/grass/grass.gdshader). **Rien n'a été profilé ni modifié.** Le nombre de triangles de `grass2.res` n'a pas pu être lu (fichier binaire, pas de Godot en ligne de commande dans le PATH) : à mesurer (voir §1).

---

## 0. Ce que révèle le symptôme

Regarder le ciel = presque aucun pixel de sol/arbre/herbe à dessiner **et** les effets plein écran (SSAO, SSIL, brouillard volumétrique, ombres reçues) ignorent les pixels « ciel ». Regarder le sol = tout cela devient actif sur 100 % de l'écran. Donc la chute de ~100 FPS est du **GPU-bound** (rasterisation + shading), pas du CPU. Le gain de l'IA/pluie/réseau ne peut pas expliquer ça.

Trois coupables possibles, indiscernables sans test (§1) :

| Suspect | Pourquoi |
|---|---|
| **Herbe** (dessinée entièrement jusqu'à 200 m) | ~75 000-150 000 instances dans le champ, triangles minuscules, fort overdraw, éclairage PBR complet + réception des ombres + SSAO/SSIL par pixel |
| **Effets plein écran** (SSAO + SSIL + volumetric fog + glow) | coût proportionnel au nombre de pixels non-ciel ; non modifiés dans le journal des changements |
| **Ombres directionnelles reçues** (terrain, herbe, arbres) | idem, coût par pixel opaque |

---

## 1. Diagnostic en 10 minutes (à faire en premier, ça évite de coder à l'aveugle)

Se placer au même endroit, regard vers le sol / à l'horizon, noter FPS (VSync OFF) et `Frame time GPU` (Debugger → Monitors, ou Visual Profiler) :

1. `grass_generator` → `visible = false`. **Si le gain est ≥ 30 FPS : l'herbe est le problème n°1.**
2. Remettre l'herbe, désactiver SSIL (`environment.ssil_enabled = false`) → noter. Puis SSAO, puis `volumetric_fog_enabled`, puis `glow_enabled`.
3. `DirectionalLight3D.shadow_enabled = false` → noter.
4. `MeshSpawner.visible = false` (arbres) → noter.
5. `Viewport` → `Debug Draw = Overdraw` (menu *Perspective* de l'éditeur ou `get_viewport().debug_draw = Viewport.DEBUG_DRAW_OVERDRAW`) : si le sol est très clair/blanc = beaucoup d'overdraw d'herbe.
6. Lire dans la sortie console la ligne `GrassGenerator: Génération terminée ! N touffes…` : **N = nombre total d'instances** (donne l'échelle réelle).
7. Mesh d'herbe : ouvrir `res://assets/3D_models/grass/grass2.res` dans l'éditeur (Inspecteur → `ArrayMesh` → ou `Mesh > View Information`/ Vue *Display Information* activée) et noter le **nombre de triangles par touffe**. Budget cible ≤ 20-30.

Ordre de décision : si (1) donne le plus gros gain → §2 à §4. Si (2)/(3) → §6.

---

## 2. Herbe : rendre moins cher sans changer le rendu perçu

### 2.1 Amincissement par distance dans le shader (priorité 1)
Le fondu actuel (140→200 m) ne retire le coût qu'à la toute fin. Entre 30 et 140 m, **toute** l'herbe est dessinée à pleine densité alors qu'un brin à 100 m fait 1-2 pixels. Principe : au loin, ne garder qu'une fraction des brins et agrandir un peu ceux qui restent pour **conserver la même couverture visuelle**. Tout se passe dans `vertex()` de `grass.gdshader`, aucune régénération de la map, déterministe et sans pop si on lisse.

```glsl
uniform float thin_start = 35.0;   // début de l'amincissement (m)
uniform float thin_end   = 140.0;  // distance où on atteint far_keep
uniform float far_keep : hint_range(0.1, 1.0) = 0.35; // part de brins gardés au loin

// dans vertex(), après le calcul de `dist` et avant VERTEX *= fade :
float h = fract(sin(dot(MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5453);
float keep = mix(1.0, far_keep, smoothstep(thin_start, thin_end, dist));
float alive = smoothstep(h - 0.08, h, keep);       // 1 = présent, 0 = supprimé (transition douce)
float comp  = inversesqrt(keep);                   // compense la couverture perdue
VERTEX.xz *= comp;                                 // plus large
VERTEX.y  *= mix(1.0, comp, 0.4);                  // un peu plus haut (limiter pour garder la silhouette)
VERTEX *= alive;                                   // supprimé = triangles dégénérés (rejetés avant rasterisation)
```
Effet attendu : le coût de rasterisation/fragment de l'herbe lointaine (la majorité des pixels d'herbe) est divisé par ~2-3 (les triangles à échelle 0 sont éliminés avant le raster ; il reste le coût vertex, bon marché). À régler à l'œil : `far_keep` 0.35-0.5, `thin_start` 30-50 m. La zone proche reste **strictement identique** (< `thin_start`).

> Note : `MODEL_MATRIX[3].xz` (position monde de l'instance) sert de graine de hasard → stable d'une frame à l'autre et identique sur tous les clients.

### 2.2 Réduire le coût pixel de l'herbe (modes de rendu quasi invisibles)
Dans le même shader, ajouter selon ce que le rendu tolère (tester un par un en comparant des captures) :
- `render_mode cull_disabled, specular_disabled;` (le spéculaire d'une herbe mate est quasi imperceptible, économise le calcul de la lumière spéculaire pour chaque pixel et chaque lumière).
- `ROUGHNESS = 1.0; METALLIC = 0.0;` explicites en `fragment()` (évite des lectures/valeurs par défaut variables).
- `render_mode ... diffuse_lambert;` (au lieu de Burley par défaut : moins cher, différence très faible sur de l'herbe).
- Optionnel, **change légèrement le rendu** : `shadows_disabled` (l'herbe cesse de *recevoir* les ombres des arbres/collines : gros gain en lecture de cascade d'ombres, mais l'herbe sous un arbre ne s'assombrit plus). À n'activer que si l'écart plaît (par ex. uniquement au-delà de 40 m en assombrissant avec `ALBEDO *= mix(1.0, 0.85, smoothstep(40.0, 120.0, dist))`).
- Vent : ne calculer le `sin()` que si `dist < ~90.0` (au-delà le mouvement est imperceptible) : `if (dist < 90.0) { ...vent... }`. Économie vertex, aucun effet visible.
- `fragment()` : le `texture(noise, worldPos.xz / noiseScale)` est lu **par pixel** pour de l'herbe qui a déjà beaucoup de pixels ; on peut le déplacer en `vertex()` (couleur par sommet via `varying vec3 tint`) : 1 lecture par sommet au lieu de 1 par pixel, rendu quasi identique pour des brins étroits.

### 2.3 Mesh d'herbe
- Si `grass2.res` dépasse ~30 triangles : le simplifier (2-3 quads croisés/courbés avec UV + gradient de couleur suffisent) ; c'est le multiplicateur le plus direct (instances × triangles).
- Les brins étroits créent beaucoup de « quad overshading » (GPU évalue des blocs de 2×2 pixels) : préférer **moins de brins plus larges** par touffe plutôt que beaucoup de brins fins.

### 2.4 Structure des chunks
- Actuel : chunks de 64 m, `visibility_range_end = max_draw_distance + chunk_size`. OK. Tester des chunks de **32 m** : culling frustum plus précis (moins d'instances soumises hors champ). Coût : ~4× plus de nœuds (≈ 1000 chunks pour 1024²), donc à mesurer.
- L'herbe entre 200 et 264 m est encore soumise (puis réduite à 0 par le shader) : `visibility_range_end = max_draw_distance + 32` suffit avec des chunks de 32 m.

---

## 3. L'occlusion culling : ce qu'il peut vraiment apporter ici

Constat : `use_occlusion_culling = true` dans les paramètres, **mais Godot ne culle que ce qui est masqué par des `OccluderInstance3D`**. Ni Terrain3D ni le `MeshSpawner` n'en créent. **Aujourd'hui l'occlusion culling ne fait donc probablement rien** (et coûte un peu de CPU pour rien). Sur un terrain avec `max_height = 200` et du relief marqué, il y a un vrai gain potentiel : tout ce qui est derrière une colline (herbe, arbres, monstres) serait ignoré.

Proposition (aucun changement visuel, seulement du culling) : générer **un occluder de terrain grossier au runtime**, après `terrain_ready` :
1. Échantillonner `terrain.data.get_height()` sur une grille de **16-32 m** (1024/16 = 64×64 = 8 192 triangles).
2. **Abaisser chaque sommet** de 3 à 5 m, et prendre le **minimum** des hauteurs voisines : l'occluder doit toujours être *sous* le sol réel (sinon des brins d'herbe ou des monstres légitimement visibles seraient cullés, créant des « trous »).
3. Créer un `ArrayOccluder3D` (vertices + indices) dans un `OccluderInstance3D` enfant du map_generator ; pas de collision ni de mesh visible.
4. Déterministe (même hauteur partout) donc identique sur tous les peers ; purement visuel.

Limites honnêtes : (a) sur terrain **plat**, aucun gain ; (b) le culling est par objet entier : un chunk d'herbe de 64 m n'est cullé que si **toute** sa boîte est masquée → avec des chunks de 32 m c'est plus efficace ; (c) coût CPU du rastériseur logiciel (réglable : `rendering/occlusion_culling/occlusion_rays_per_thread`, `bvh_build_quality`). À mesurer ON/OFF avec le Visual Profiler avant de généraliser. Ajouter aussi des occluders sur le **mur de bordure** (boîte basse et épaisse) est possible mais peu utile.

Ce que l'occlusion culling **ne** réglera **pas** : le regard vers le sol sur terrain plat (rien n'est masqué, tout est visible).

---

## 4. Terrain et arbres (à vérifier avec les bascules du §1)
- **Terrain3D** : le terrain rendu depuis le dessus occupe 100 % des pixels du bas de l'écran avec un matériau multi-textures (blend, normales, éventuels détails) : c'est le coût pixel de base. Vérifier dans les propriétés du `Terrain3DMaterial` : réduire les couches/détails, désactiver les features non utilisées (`auto_shader`, `dual_scaling`, `world_background`, `show_checkered`, etc.), et `mesh_lods`/`mesh_size` aux valeurs raisonnables.
- **Arbres** : `cast_shadow` actif sur les arbres normaux (le mur est déjà coupé). Au-delà de la distance d'ombre (`directional_shadow_max_distance`), mettre les chunks lointains en `cast_shadow = OFF` (second MultiMesh ou `visibility_range` croisé) ; LOD de mesh (`.glb` + LOD auto) pour les arbres à > 100 m.

---

## 5. Pluie (fait, +10 FPS de coût mesuré)
Rien d'urgent. Si besoin plus tard : limiter `spraks` au voisinage du joueur et `visibility_aabb` au plus juste.

---

## 6. Effets plein écran (si le test §1.2 montre un gros gain)
Ces effets ne coûtent presque rien en regardant le ciel et beaucoup au sol, ce qui colle avec le symptôme.
- **SSIL** : le plus cher, rendu discret → le désactiver ou le passer en `ssil_quality` basse.
- **SSAO** : `ssao_detail` et `ssao_horizon` bas, qualité *Low* (`rendering/environment/ssao/quality = 0/1`, `half_size = true`).
- **Volumetric fog** : `rendering/environment/volumetric_fog/volume_size` 64 → 48-32, `volume_depth` 64 → 32 ; `volumetric_fog_length` 152 → ~80.
- **Glow** : `glow_levels` limités (niveaux 3-5 suffisent), pas de bicubic (`rendering/environment/glow/upscale_mode`).
- **Ombres** : `directional_shadow_mode = 2 splits`, `directional_shadow_max_distance` ≈ distance réellement visible, résolution 4096 → 2048 (`rendering/lights_and_shadows/directional_shadow/size`), `soft_shadow_filter_quality` Low/Medium.
- Si ça plaît à l'œil, c'est **le** poste qui changerait le plus le FPS « au sol » ; mais ça modifie le rendu : à proposer comme preset de qualité plus tard (comme prévu par l'utilisateur), pas à imposer.

---

## 7. Plan d'action ordonné (impact attendu / risque)

| # | Action | Gain attendu | Risque visuel |
|---|---|---|---|
| 1 | Diagnostic §1 (toggle herbe / SSIL / SSAO / fog / ombres) | décide de tout | nul |
| 2 | Shader herbe : amincissement par distance (§2.1) | gros si l'herbe est le problème | très faible (à régler à l'œil) |
| 3 | Shader herbe : `specular_disabled`, vent limité à < 90 m, noise en vertex (§2.2) | moyen | très faible |
| 4 | Vérifier/simplifier le mesh d'herbe (§2.3) | gros si > 30 tris | faible |
| 5 | Occluder de terrain runtime + chunks 32 m (§3) | moyen sur relief, nul sur plat | nul si l'occluder est bien sous le sol |
| 6 | Arbres : ombres off au loin, LOD mesh (§4) | moyen | quasi nul |
| 7 | Terrain3D : alléger le matériau (§4) | moyen | à vérifier |
| 8 | Presets de qualité (SSIL/SSAO/fog/ombres) (§6) | gros | visible → réservé aux options |

## 8. Pièges à éviter
- Ne **jamais** modifier la graine ni l'ordre des `rng` dans `grass_generator.gd`, `mesh_spawner.gd`, `path_generator.gd` (cohérence entre clients).
- Un occluder au-dessus du sol cause des brins d'herbe/monstres qui disparaissent : toujours le tenir 3-5 m **sous** le terrain.
- Le shader d'herbe est aussi précompilé dans `shader_precompiler.gd` : après modification, vérifier qu'aucun uniform renommé ne casse les `ShaderMaterial` existants (`color`, `color2`, `noise`, `noiseScale`, `wind_*`, `fade_distance_*`).
- Toujours comparer des captures avant/après aux mêmes positions pour valider que la couverture d'herbe au loin reste identique.
