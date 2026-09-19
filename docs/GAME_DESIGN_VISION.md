# FANGORN — BIBLE DE GAME DESIGN & VISION DE JEU
> **Genre** : Roguelike FPS x ARPG (Inspirations : *Path of Exile, Diablo 2, Risk of Rain 2, Darktide*)  
> **Mode principal** : Co-op multijoueur (1 à 4 joueurs)  
> **Structure** : 3 Actes / Zones procédurales $\rightarrow$ Boss intermédiaire $\rightarrow$ Boss Final

---

## 1. VISION GLOBALE & IDENTITÉ DU JEU

Fangorn combine l'immersion et la nervosité d'un **FPS de tir et de corps-à-corps** avec la profondeur de build d'un **ARPG** (statistiques riches, affixes procéduraux, synergies de sorts, raretés d'objets) dans une structure de **run Roguelike** sous tension.

### La Boucle d'une Partie (Run)
```mermaid
flowchart LR
    A["Zone 1 : Forêt / Plaines"] --> B["Boss 1"]
    B --> C["Marchand & Forge"]
    C --> D["Zone 2 : Marais / Donjons"]
    D --> E["Boss 2"]
    E --> F["Marchand & Forge"]
    F --> G["Zone 3 : Terres Désolées"]
    G --> H["BOSS FINAL"]
```

---

## 2. LA TENSION TEMPORELLE & LE DILEMME "RUSH VS EXPLORATION"

### Le Problème du genre
Dans la majorité des ARPGs, la stratégie optimale est de tout raser pour accumuler le maximum d'XP et de stuff avant le boss. Cela rend le rythme lent et prévisible.

### La Solution : L'Écologie Menaçante (Pas de simple chrono UI)
Au lieu d'un simple compte à rebours numérique à l'écran, **le monde lui-même s'assombrit et devient hostile** :

1. **0 à 10 minutes (Phase Clémence)** :
   - Ciel clair / brume légère.
   - Les monstres sont dans leurs camps et sur leurs routes de patrouille normales.
   - Le joueur explore, repère les opportunités et démarre son build.
2. **10 à 20 minutes (Phase de Dégradation)** :
   - La météo se gâte : pluie battante, ciel orageux, visibilité réduite.
   - Les monstres gagnent en agressivité et en portée de détection (+30%).
   - Les premiers éclaireurs sauvages traquent activement les joueurs.
3. **20+ minutes (L'Heure Sombre / La Horde Incessante)** :
   - Le ciel vire au rouge sang / nuit d'encre.
   - Des vagues de créatures cauchemardesques affluent en continu vers la position des joueurs.
   - **Règle d'or** : Ces monstres de horde ne donnent **presque pas d'XP et aucun loot de valeur**. Rester sur la carte devient un gouffre à ressources (points de vie, munitions, potions).
   - **Résultat** : Les joueurs sont contraints de fuir vers la porte du Boss. **On ne peut pas tout faire sur une carte**, il faut choisir ses combats !

### Le Repérage Tactique (Scouting)
Puisque le temps est compté, les joueurs ne doivent pas errer à l'aveugle :
- **Tours de guet / Balises de cartographie** : Nettoyer un petit point d'observation révèle sur la boussole/carte le type de récompense des camps voisins (ex: *"Icône de Coffre de Sorts au Nord"*, *"Grotte aux Runes à l'Est"*).
- Cela transforme la traversée en un jeu de planification rapide : *"On a le temps pour 2 camps et 1 donjon avant la pluie. Lesquels servent le plus nos builds ?"*

---

## 3. LES SHRINES DE PUISSANCE & LE PACTE AVEC LE BOSS

### Le Dilemme Central (Risk vs Reward)
Chaque zone abrite des **Sanctuaires Élémentaires (Shrines)**. Ce sont des camps ou rituels optionnels majeurs.

- **Le Gain** : Vaincre les gardiens du Sanctuaire débloque un coffre puissant au thème précis (Stuff, Runes et Sorts de l'élément en question).
- **Le Prix (Le Pacte)** : Purifier le Sanctuaire absorbe l'énergie du lieu et **transfère un enchantement direct au Boss de fin de zone** !

| Type de Sanctuaire | Récompenses Joueur | Enchantement conféré au Boss |
| :--- | :--- | :--- |
| **Sanctuaire du Feu** | Armes d'embrasement, sorts de météore, bonus dégâts de brûlure | Le Boss gagne une aura de lave et fait pleuvoir des météores |
| **Sanctuaire du Givre** | Armures de glace, ralentissements, nova gelée | Le Boss gagne un bouclier de glace et gèle les joueurs au contact |
| **Sanctuaire de la Foudre** | Dagues critiques, arcs électriques, téléportation | Le Boss dash à la vitesse de l'éclair et invoque la foudre |
| **Sanctuaire du Sang** | Vol de vie, bonus de vitesse d'attaque, régénération | Le Boss régénère sa vie quand il touche un joueur |

> **Impact Gameplay** : Un joueur jouant un build Glace ne touchera **jamais** au Sanctuaire du Feu, car il ne profiterait pas des loots tout en rendant le boss inutilement plus dangereux. Le groupe doit débattre : *"Est-ce qu'on prend le risque de booster le Boss pour que notre mage récupère son sort ultime ?"*

---

## 4. LE SYSTÈME DE RUNEWORDS (FORGE D'ITEMS UNIQUES À LA DIABLO 2)

### Philosophie
Dans Diablo 2, trouver une rune rare donnait une immense satisfaction parce qu'on visualisait immédiatement l'item de rêve qu'on allait fabriquer. Dans Fangorn, ce système est adapté au format Roguelike : **plus direct, plus flexible, sans farm rébarbatif**.

### Fonctionnement
- **Les Runes** : Objets rares lâchés par les Mini-boss de donjons, les Shrines ou les élites cachés.
- **Le Forgeron (Inter-Zone)** : Présent dans le sanctuaire sécurisé après le Boss de chaque zone.
- **La Recette Runique** : Associer 2 ou 3 Runes crée un **Item Unique précis** doté de passifs surpuissants.

### Flexibilité Roguelike (Recettes d'équivalence)
Pour éviter qu'une run soit gâchée parce qu'il manque UNE rune précise :
- Les Runes possèdent des **Mots-Clés** (ex: *Puissance, Vitesse, Esprit, Sang*).
- Si tu n'as pas la Rune exacte pour la *"Lame du Tyran"*, combiner une Rune de substitution partageant le même mot-clé forgera une version alternative de l'arme (légèrement différente mais tout aussi viable).

---

## 5. LES DONJONS & GROTTES SECONDAIRES

Sur les flancs des falaises et sous les collines de la carte se trouvent des entrées de grottes procédurales :
- **L'Enseigne / Le Sceau d'Entrée** : Une rune ou un symbole lumineux gravé au-dessus de l'entrée indique la récompense garantie au fond (ex: *Symbole d'Arme Lourde*, *Symbole de Rune de Foudre*, *Symbole de Bijou Magique*).
- **Le Déroulement** : Un couloir serré avec une ambiance claustrophobe (torches, boyaux rocheux), 2 ou 3 packs d'ennemis spécialisés (ex: nuées d'araignées).
- **Le Gardien de l'Antre (Mini-Boss)** : Une créature redoutable avec une arène dédiée. La vaincre ouvre le coffre de salle au trésor.

---

## 6. DENSITÉ, PATROUILLES & LOOT AU SOL

### Tuer le vide entre les Encounters
La carte ne doit jamais être un désert avec seulement 4 points d'intérêt :
1. **Les Embuscades Sauvages** :
   - Des orques cachés immobiles derrière les rochers ou accroupis dans les sous-bois denses.
   - Ils ne bougent **que** lorsqu'un joueur entre dans leur rayon de déclenchement (effet de surprise garanti).
2. **Les Patrouilles (IA de Ronde)** :
   - Des petits groupes de 3 à 4 monstres qui voyagent entre 2 points de repère le long des chemins secondaires.
   - S'ils aperçoivent un joueur, ils poussent un cor de guerre qui alerte les packs voisins à 20 mètres.
3. **Le Loot au sol viscéral (Kill Drops)** :
   - Fini le loot limité aux seuls coffres.
   - Tuer un mob a une chance de faire jaillir un objet physique avec effet sonore et halo coloré selon la rareté :
     - *Monstres normaux* : Orbes de vie, fioles de mana, pièces d'or.
     - *Élites / Champions* : Garantie de drop d'un équipement Magique ou Rare avec un rayon lumineux montant vers le ciel.

---

## 7. MOBILITÉ, VERTICALITÉ & COHÉSION CO-OP

Traverser la carte doit être **amusant en soi**, pas juste courir en ligne droite avec la touche W enfoncée.

### A. Mécaniques de Déplacement dans le Monde
1. **Tremplins Magiques / Geysers d'Air** :
   - Placés stratégiquement près des vallées et des falaises.
   - Propulsent les joueurs haut dans les airs pour franchir une montagne ou fondre sur un camp ennemi en piqué.
2. **Waypoints des Feux de Camp** :
   - Nettoyer un camp d'orques allume son feu de camp central, qui devient un **Téléporteur rapide**.
   - Évite les allers-retours fastidieux à pied une fois une zone nettoyée.

### B. Résoudre le Problème des Vesses Différentes en Co-op
Dans un jeu avec des stats, un joueur agile aura +80% Movement Speed et sèmera ses alliés tanky, créant de la frustration.
- **La Piste / L'Aspiration de Sentier** :
  - Sur les routes principales, un joueur plus lent qui suit un joueur plus rapide bénéficie de **l'effet d'aspiration** (il gagne jusqu'à 70% de la vitesse de déplacement de son allié en tête).
- **Sorts de Mobilité de Groupe (Keystones Utilitaires)** :
  - **La Bulle Céleste** : Le lanceur de sort invoque une sphère magique flottante ; tous les alliés à l'intérieur s'envolent et le caster pilote la bulle à grande vitesse par-dessus les falaises et les forêts.
  - **L'Étendard de Marche** : Une aura de groupe qui booste la vitesse de sprint hors-combat de 50% pour toute l'équipe.

---

## 8. L'IA DE PANIQUE & LE BESTIAIRE MENAÇANT

Pour créer une vraie tension coopérative, les ennemis ne doivent pas se contenter d'avancer tout droit vers le joueur :

```
[LE BESTIAIRE DE LA PANIQUE]
├── 1. Le Creep (L'Égorgeur Furtif)
│      └── Se déplace dans le dos du groupe, silencieux, frappe mortelle si non surveillé.
├── 2. Le Bondisseur (Araignée / Gobelin Sauteur)
│      └── Saute depuis les branches ou les falaises directement sur la caméra du joueur.
├── 3. Le Brise-Ligne (Ogre / Berserker lourd)
│      └── Charge en ligne droite, traverse les défenses et propulse les joueurs dans les airs.
├── 4. L'Enracineur (Chaman / Tisseur)
│      └── Piège un joueur au sol dans des ronces ou toiles ; les alliés doivent casser le piège.
└── 5. Le Kamikaze (Porteur de Poudre)
       └── Court à pleine vitesse avec un son strident ; doit être abattu d'urgence avant l'explosion.
```

---

## 9. FEUILLE DE ROUTE SUGGÉRÉE DE DÉVELOPPEMENT

1. **Phase 1 : Le Rythme du Monde**
   - Implémenter le drop de loot physique au sol à la mort des monstres.
   - Ajouter l'effet d'aspiration de vitesse sur les routes en co-op.
2. **Phase 2 : La Densité & Les Embuscades**
   - Créer le composant d'IA d'embuscade (dormant jusqu'au passage proche du joueur).
   - Placer des patrouilles mobiles sur la carte procédurale.
3. **Phase 3 : Les Shrines & La Pression du Boss**
   - Implémenter 2 types de Shrines élémentaires avec transmission de modificateurs au Boss.
   - Connecter l'évolution météo (pluie $\rightarrow$ horde de nuit) au timer de la carte.
4. **Phase 4 : Les Runewords & Donjons**
   - Système de forge runique auprès du marchand de fin de zone.
   - Génération des entrées de grottes avec symboles de récompense.
