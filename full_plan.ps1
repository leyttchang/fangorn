content = """# Plan d'Intégration du Multijoueur Co-op (Client-Authoritatif) - Version Exhaustive

Ce document passe en revue la totalité des scripts du projet (y compris ceux de l'UI, des objets et des compétences) et détaille les actions exactes à mener pour les rendre compatibles avec le mode coopératif.

---

## 1. Moteur Réseau à Créer (Nouveaux Fichiers)
- **network_manager.gd (AutoLoad)** : Gérera l'UI de connexion, le lancement de `ENetMultiplayerPeer`, et contiendra le port et l'IP cible.
- **Les Spawners (Scènes)** : Tu auras besoin d'ajouter des nœuds `MultiplayerSpawner` dans ton `main.tscn` pour synchroniser l'apparition des Joueurs et des Monstres.

---

## 2. Le Joueur et ses Mouvements (`character/`)
- **player.gd**
  - *Modif :* Ajouter `if not is_multiplayer_authority(): return` au début de `_physics_process()`.
  - *Modif :* Ajouter un `MultiplayerSynchronizer` à la scène `player.tscn` (pour envoyer la position et la rotation).
- **main_droite.gd**
  - *Modif :* Dans la détection d'attaque (`_process` ou signaux d'animation), vérifier l'autorité réseau pour éviter que le client déclenche les attaques du joueur 1.
- **dummy.gd**
  - *Modif :* Ajouter un `MultiplayerSynchronizer`. Le dummy est géré par le Serveur. Le Client envoie des RPC pour lui infliger des dégâts.

---

## 3. L'Intelligence Artificielle et les Spawners (`character/enemie/`)
- **dumb.gd / dumb_archer.gd / fire_arrow.gd**
  - *Modif :* L'IA (mouvement, ciblage, tirs) doit être protégée par `if is_multiplayer_authority():`. Seul le serveur fait bouger les monstres.
  - *Modif :* `fire_arrow.gd` doit être instancié via le `MultiplayerSpawner` du serveur, ou alors le serveur demande aux clients de créer la flèche visuellement via un RPC.
- **dumb_spawner.gd / smart_spawner.gd / start_beacon.gd**
  - *Modif :* Remplacer `add_child()` par la méthode native `.spawn()` si on utilise un `MultiplayerSpawner`. Le Serveur décide quand et où faire spawner les monstres.
- **EnemyBehaviorData.gd**
  - *Statut :* **OK**. (C'est de la pure donnée).

---

## 4. Les 19 Components (`components/`)
- **attack_component.gd / hitbox_component.gd / knockback_componant.gd**
  - *Modif :* La collision doit être vérifiée côté "Propriétaire". Si c'est l'attaque du Joueur 2, c'est lui qui détecte. Les armes doivent avoir un `get_multiplayer_authority()` qui correspond au joueur qui les tient.
- **health_component.gd / mana_component.gd**
  - *Modif :* Ajouter un `MultiplayerSynchronizer`. Modifier les fonctions `take_damage()` pour qu'elles s'exécutent en local si c'est le joueur, ou qu'elles envoient un `rpc_id(1, "take_damage", ...)` si le client frappe un monstre (Client-Authoritatif).
- **combat_feedback_component.gd / hurt_sound_component.gd**
  - *Statut :* **Presque OK**. Les VFX locaux peuvent tourner tels quels, mais il faudra s'assurer qu'ils sont bien déclenchés par le client lors d'un RPC (ne jamais instancier de particules via le MultiplayerSpawner).
- **skill_bar_component.gd**
  - *Modif :* C'est le plus complexe. La logique de création d'une capacité (instantiate `ability_scene`) doit être scindée. Soit on crée un "Fake Visual Spell" via RPC pour les autres, soit on utilise le Spawner réseau, mais avec des restrictions de Hitbox.
- **spell_scaling_component.gd**
  - *Statut :* **OK**. Le calcul de dégâts que je viens de réécrire est 100% sûr, car il sera exécuté par le propriétaire du sort en local.
- **inventory_componant.gd / equipment_component.gd**
  - *Modif :* Totalement géré en local (parfait pour du Client-Authoritatif). Les inventaires ne sont pas synchronisés. Le serveur n'a pas besoin de savoir ce qu'a le joueur 2 dans son sac, sauf pour l'apparence visuelle.
- **visual_equipment_manager.gd**
  - *Modif :* Si le Joueur 2 équipe une épée, il doit envoyer un `rpc("equip_item_visuellement", item_id)` pour que le Joueur 1 voie son épée apparaître dans sa main.
- **interaction_component.gd**
  - *Modif :* Interagir avec un objet doit envoyer un RPC au serveur (`rpc_id(1, "request_interact")`). Le serveur valide et supprime l'objet.
- **continuous_attack_component.gd / enemy_movement_component.gd / enemy_navigation_component.gd**
  - *Modif :* Tournent uniquement sur le Serveur (`if is_multiplayer_authority()`).

---

## 5. Les Objets, Coffres et Armes (`item/`, `objet/`)
- **chest.gd / chest_spawner.gd / skill_chest.gd**
  - *Modif :* Le loot (les items qui tombent au sol) DOIT être géré par le Serveur. Quand le serveur ouvre un coffre, il fait spawner les items via un `MultiplayerSpawner`. Le client interagit avec eux via l'`interaction_component`.
- **weapon.gd / weapon_item.gd / item_data.gd / affix_data.gd**
  - *Statut :* **OK**. (Scripts de données, rien à changer).

---

## 6. L'Arbre de Talents (`passive_skill_tree/`)
- **generator_test.gd**
  - *Modif :* Pour que tous les joueurs aient le même arbre (si c'est le design choisi), le Serveur doit envoyer la variable `tree_seed` par RPC au moment de la connexion.
- **skill_node_ui.gd / skill_node_data.gd**
  - *Statut :* **OK**.
- **Les 14 Keystones (brutality_keystone.gd, etc.)**
  - *Statut :* **Majoritairement OK**. Elles modifient les stats en local.
  - *Exception :* `mana_storm.gd`. Il utilise `.instantiate()` pour créer la tornade. Il faudra utiliser un RPC ou un Spawner réseau pour que la tornade de mana apparaisse sur les autres PC.

---

## 7. Les Compétences Actives et Sorts (`scripts/abilities/`)
**Fichiers concernés :** `dash.gd`, `fireball.gd`, `ice_crash.gd`, `chain_lightning.gd`...
- *Problème :* Tous tes sorts sont instanciés en local.
- *Solution :* Si le Joueur 2 lance un "Ice Crash", le joueur 1 ne verra rien. Il faut modifier chaque script de compétence pour qu'il inclue un `rpc("play_visuals")`.
- *Exception :* `dash.gd`. Pas besoin d'effet réseau si le Dash modifie juste la position du joueur (le Synchronizer du joueur se chargera de montrer qu'il a bougé vite).

---

## 8. Les Statistiques (`scripts/stats/`)
**Fichiers concernés :** `entity_stats.gd`, `stat.gd`, `stat_modifier.gd`
- *Statut :* **100% OK**. Ne change rien. Ton système de statistiques est mathématique et local, il est déjà parfait pour du multi Client-Authoritatif.

---

## 9. L'Interface Utilisateur (UI) (`ui/`)
**Fichiers concernés :** `health_bar.gd`, `inventory_ui.gd`, `damage_text.gd`, `pause_menu.gd`, `spell_book_ui.gd`, etc. (plus de 15 scripts).
- *Statut :* **100% OK**.
- **Explication :** L'interface tourne exclusivement en local et écoute les signaux du joueur local. Tu n'as absolument **aucune ligne de réseau** à écrire dans l'UI.

---

## Résumé et Points de Vigilance (Inter-Scripts)
1. **La "Trinité du Sort" :** Un sort implique `skill_bar_component.gd`, le script du sort (ex: `fireball.gd`) et `attack_component.gd`. Cette chaîne devra être divisée entre le *Calcul local* et *l'Affichage RPC global*.
2. **Duplication des Effets Visuels :** Assure-toi que les `hurt_sound_component.gd` et `combat_feedback_component.gd` ne sont PAS déclenchés par le serveur ET par le client en même temps, sinon on entendra les sons en double.
3. **Le Loot :** C'est le point le plus fragile. L'objet 3D par terre appartient au serveur, mais quand ramassé, il devient une donnée (`ItemData`) dans l'inventaire purement local du client. La passation de pouvoir (`rpc`) doit être millimétrée.
"""

with open("Y:/Fangorn/fangorn/coop_multiplayer_plan.md", "w", encoding="utf-8") as f:
    f.write(content)
print("done")
