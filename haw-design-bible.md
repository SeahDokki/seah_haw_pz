# Humans: Are Weak — Design Bible
**Mod Project Zomboid** · Trait Mod · Phase de conception

---

## Concept général

Un mod de traits uniquement négatifs basé sur de vraies pathologies humaines communes. Chaque trait est une contrainte mécanique authentique qui change activement la façon de jouer.

Les points accordés par ces traits peuvent être dépensés dans des traits positifs lors de la création du personnage.

---

## Vue d'ensemble — 13 traits, 80 points

| Trait | Points |
|---|---|
| Épileptique | +12 |
| Narcoleptique | +12 |
| Diabétique | +10 |
| Dépressif | +6 |
| Immunodéprimé | +6 |
| Asthmatique | +5 |
| SED | +5 |
| Névralgique | +5 |
| Tourette | +5 |
| Allergie | +4 |
| Arthrose | +4 |
| TDAH | +4 |
| Daltonien | +2 |
| **Total points disponibles** | **80 pts** |

---

## Épileptique *(+12 pts)*

Crises convulsives déclenchées par des conditions spécifiques.

**Déclencheurs :** Stress élevé · Fatigue extrême · Source lumineuse directe prolongée (flashlight, phares) · TV regardée longtemps. Cooldown entre crises.

**Effets de crise :** Chute + convulsions ~15–20s, incapacité totale. Bruit généré (attire zombies). Possible blessure légère à la tête. Courte phase de confusion post-crise.

**Implémentation :**
- `Events.OnPlayerUpdate` — vérifier moodles Stress + Fatigue + lumières
- Timer TV via `HAW_tvTimer` dans ModData
- `player:playAnim("fall")` + lock inputs pendant la crise
- `getSoundManager():PlayWorldSound()` pour le bruit
- Cooldown : `HAW_epilepsyLastCrisis` (timestamp)

---

## Narcoleptique *(+12 pts)*

Endormissements soudains imprévisibles, n'importe où, n'importe quand.

**Conditions :** Timer aléatoire de base. Risque amplifié après repas copieux (moodle Stuffed) ou fatigue intense. Légèrement réduit si bien reposé.

**Effets :** Endormissement instantané sur place. Écran qui s'assombrit → état "endormi". Durée 30s–2min de jeu (aléatoire). Le joueur peut se faire attaquer. Réveil forcé si dommages reçus.

**Implémentation :**
- `Events.OnPlayerUpdate` — timer aléatoire décrémenté à chaque tick
- `player:setAsleep(true)` pour forcer le sommeil
- Durée dans `HAW_narcoSleepDuration`

---

## Diabétique *(+10 pts)*

Gestion permanente de la glycémie. L'insuline devient aussi précieuse que les munitions.

**Mécanique glycémie (0–100) :**
- Hypoglycémie (< 25) : malaise, vision floue, tremblements → coma si non traité → mort
- Normal (25–75) : aucun effet
- Hyperglycémie (> 75) : fatigue accélérée, soif extrême
- Manger du sucre remonte rapidement; l'insuline régule
- Effort intense fait chuter plus vite
- Sans glucomètre : état inconnu du joueur

**Nouveaux objets requis :**
- **Glucomètre** — lit la glycémie; nécessite piles; loot pharmacie/hôpital
- **Insuline** — injectable, normalise vers 50; loot pharmacie/hôpital
- **Insuline Bovine** (craft) — organes de bovin + kit médical + distillation; moins efficace

**Implémentation :**
- `HAW_glycemia` (float) décrémenté via `Events.EveryTenMinutes`
- Glucomètre : action contextuelle → lit et affiche la valeur
- Insuline : item injectable → normalise la valeur
- Recette insuline bovine dans `scripts/recipes/`

⚑ Taux de décrémentation exact à définir. Péremption insuline : à décider.

---

## Dépressif *(+6 pts)*

La dépression s'installe et ne lâche pas.

**Effets :**
- Moodle Depression monte plus vite, descend moins facilement
- À depression maximum : moodle Faim masqué (le joueur ne sait pas s'il a faim)
- À depression élevée : chance aléatoire de ne pas attaquer (apathie)

**Implémentation :**
- Multiplicateur du moodle Depression modifié
- Hook sur affichage des moodles (UI) pour masquer Faim
- Hook sur `player:attack()` pour le jet d'apathie

---

## Immunodéprimé *(+6 pts)*

Upgrade sévère de "Enclin à la maladie". Une égratignure peut devenir fatale.

**Effets :**
- Toute plaie s'infecte systématiquement sans antibiotiques — aucune guérison naturelle possible
- Risque de maladie aléatoire significativement augmenté
- **Virus Knox :** si le personnage est infecté, la zombification est immédiate — aucun délai de survie

**Implémentation :**
- Taux d'infection des plaies porté à 100% (override du jet aléatoire vanilla)
- Multiplicateurs de progression des maladies amplifiés (surcharge de "Prone to Illness")
- Knox : hook sur l'événement d'infection Knox → forcer la progression à 100% instantanément via `player:setInfected(true)`

Note : la zombification immédiate est absolue. Les mods ajoutant un remède Knox ne la contournent pas.

---

## Asthmatique *(+5 pts)*

L'inhalateur devient un objet de survie.

**Effets :**
- Endurance réduite, régénération lente
- Respiration bruyante lors de l'essoufflement : aggro zombies à courte distance
- Course prolongée → risque de crise d'asthme (actions bloquées)
- Sans inhalateur longtemps : crises plus fréquentes et graves

**Nouvel objet :** **Inhalateur** — loot pharmacie (rare). Interrompt une crise + boost récupération endurance.

**Implémentation :**
- Multiplicateurs Endurance du trait
- Bruit respiratoire : `PlayWorldSound("asthma_breath")` si Endurance < seuil
- Timer de crise : blocage si endurance à 0 trop longtemps
- Fichier son : `media/sound/asthma_breath.ogg`

---

## SED — Syndrome d'Ehlers-Danlos *(+5 pts)*

Hyperlaxité articulaire. Chaque sprint est un pari.

**Effets :**
- Probabilité d'entorse significativement augmentée
- Probabilité de fracture légère augmentée lors des chocs
- Chance de chuter sans raison lors du sprint (chevilles qui lâchent)
- Récupération des entorses/fractures légères plus longue
- Note : utilise "fracture légère" (existe en jeu) — pas de luxation (n'existe pas)

**Implémentation :**
- Multiplicateurs d'entorse/fracture (vanilla)
- `Events.OnPlayerUpdate` : si sprint → jet probabiliste → `player:addBuff("Sprain")`

---

## Névralgique *(+5 pts)*

Éclairs de douleur aléatoires, sans prévenir.

**Effets :**
- Pic de "douleur atroce" aléatoire plusieurs fois par jour de jeu
- Pendant la crise (~10s) : blocage des actions (attaque, course, fouille)
- Animation de douleur + grognement discret (bruit)
- Timer dans une plage aléatoire (ex. toutes les 10–40 min de jeu)

**Implémentation :**
- Timer aléatoire via `Events.OnPlayerUpdate`
- Lock des actions + message UI "Douleur atroce"
- Son discret via `PlayWorldSound`

---

## Tourette *(+5 pts)*

Le tic vocal arrive au pire moment.

**Effets :**
- Cri involontaire aléatoire à intervalles irréguliers
- Portée : ~15–20 tiles (comme un cri humain normal)
- Attire les zombies dans la zone
- Fréquence amplifiée si stress élevé

**Implémentation :**
- Timer aléatoire via `Events.OnPlayerUpdate`
- `getSoundManager():PlayWorldSound("tourette_tic", x, y, z, radius)`
- Fichier son : `media/sound/tourette_tic.ogg` (plusieurs variantes)
- Modificateur fréquence si moodle Stress élevé

---

## Allergie *(+4 pts)*

Les bois au printemps, et les arachides, deviennent des dangers.

**Effets :**
- Éternuements uniquement en zone boisée, uniquement au printemps (mois 3–5)
- Chaque éternuement attire les zombies (bruit)
- Consommer des arachides → food poisoning
- Antihistaminiques (pharmacie) : suppriment éternuements temporairement

**Implémentation :**
- Check biome de la tile courante + `GameTime.getInstance():getMonth()` (mois 3–5)
- `PlayWorldSound("sneeze")` + timer aléatoire
- Tag "ContainsNuts" sur les items concernés → hook `Events.OnPlayerEat`

⚑ Inventaire items vanilla contenant des arachides à vérifier.

---

## Arthrose *(+4 pts)*

Les articulations grincent. Chaque combat est une négociation avec la douleur.

**Effets :**
- Vitesse d'attaque réduite (cooldown entre coups plus long)
- Fatigue des mains accélérée en combat prolongé
- Malus supplémentaire par temps froid (optionnel)

**Implémentation :**
- Modificateur sur l'attack cooldown du trait
- Endurance en combat : multiplicateur de fatigue accéléré

---

## TDAH *(+4 pts)*

L'hyperfocus peut tout changer. Le stress aussi.

**Effets :**
- Lecture **3× plus lente** — temps de lecture triplé (tous livres et magazines)
- EXP ×15 sur une compétence aléatoire à la fois (hyperfocus)
- La compétence boostée change à intervalles aléatoires
- Moodle Stress monte très vite, Moodle Ennui monte très vite
- Si Stress trop élevé : le personnage refuse certaines actions (attendre, lire, dormir)

**Implémentation :**
- Modificateur vitesse de lecture (vanilla) — ralentissement ×3, pas une accélération
- Hook sur gain d'XP : si compétence == `HAW_tdahFocusSkill` → ×15
- `HAW_tdahFocusSkill` recalculé aléatoirement via `Events.EveryTenMinutes`
- Multiplicateurs Stress/Ennui via paramètres du trait
- Refus d'actions : check `player:getMoodleLevel("Stress")`

⚑ Seuil de Stress exact et liste d'actions refusées à définir. Le joueur est-il informé de sa compétence en hyperfocus ?

---

## Daltonien *(+2 pts)*

Le monde en nuances de gris, si techniquement faisable.

**Effets :** Rendu en noir et blanc (filtre désaturation global). Fallback : UI désaturée uniquement.

**Implémentation :** Shader post-processing via API vanilla (faisabilité à confirmer). Script client uniquement (`media/lua/client/`).

⚑ Faisabilité du shader Lua à confirmer avant implémentation.

---

## Nouveaux objets

| Objet | Source | Usage |
|---|---|---|
| Glucomètre | Loot pharmacie/hôpital | Lit la glycémie (Diabétique) |
| Insuline | Loot pharmacie/hôpital (rare) | Injectable, normalise glycémie |
| Insuline Bovine | Craft (organes bovin + kit médical) | Alternative artisanale |
| Inhalateur | Loot pharmacie (rare) | Stoppe crise d'asthme |
| Antihistaminique | Loot pharmacie | Supprime éternuements (Allergie) |

---

## Architecture technique

### Hooks principaux

| Événement | Rôle |
|---|---|
| `Events.OnPlayerUpdate` | Boucle principale — timers crises, moodles, conditions |
| `Events.EveryTenMinutes` | Mises à jour lentes — glycémie, compétence TDAH, flush data |
| `Events.OnGameStart` | Initialisation état personnage |
| `Events.OnPlayerEat` | Hook Allergie — détecter arachides |

### ModData par personnage (`player:getModData()` — préfixe `HAW_`)

```lua
data.HAW_initialized           -- bool : déjà traité
data.HAW_epilepsyLastCrisis    -- int  : timestamp dernière crise
data.HAW_epilepsyTvTimer       -- float: durée cumulée devant TV
data.HAW_narcoSleepTimer       -- float: timer prochaine attaque narco
data.HAW_glycemia              -- float: valeur glycémie (0–100)
data.HAW_tdahFocusSkill        -- string: compétence en hyperfocus (×15 XP)
data.HAW_tdahFocusTimer        -- float: timer prochain changement de compétence
data.HAW_touretteTimer         -- float: timer prochain tic vocal
data.HAW_neuralgiaTimer        -- float: timer prochain pic de douleur
data.HAW_asthmaInhalerDays     -- int  : jours depuis dernier inhalateur
```

---

## Points ouverts

1. **Diabétique** — Taux de décrémentation glycémie selon l'activité. Péremption insuline : oui ou non ?
2. **Daltonien** — Faisabilité shader noir-et-blanc via Lua à confirmer.
3. **TDAH** — Seuil Stress exact pour refus d'actions. Liste précise des actions bloquées. Visibilité de la compétence hyperfocus pour le joueur ?
4. **Allergie** — Inventaire items vanilla avec arachides. Nouveau tag "ContainsNuts" ou nouveaux items ?
5. **TDAH refus d'actions** — Animation de refus, message UI ou blocage silencieux ?
6. **Insuline Bovine** — Recette exacte. Efficacité vs insuline pharmacie.
