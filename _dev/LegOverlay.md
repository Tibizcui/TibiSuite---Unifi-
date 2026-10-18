# LegTracker : légendaire épinglé et overlay de farm

Plan rédigé le 2026-10-18, sur le modèle de l'overlay de pêche (SkillTracker 7.1.5.53).

**État (2026-10-18) : lots 1, 2 et 3 codés**, syntaxe contrôlée, simulation hors jeu
(43 vérifications : épingle, séance, pause, gains, boss, délai, estimation, quête,
obtention, reprise à la connexion, ligne d'état, aperçu, Conseiller). Déployé dans le
dossier AddOns, non commité. **Rien n'est testé en jeu** : à valider par Tibiscui
(nouveaux fichiers => redémarrage complet du client). Écarts avec le plan ci-dessous :
la zone de quête ne compte que si la quête est dans le journal et hors ville / auberge
(`IsResting`), pour ne pas compter Hurlevent (1re étape de Courroux du dragon) ; pas
d'entrée de CHANGELOG (à écrire à la release, avec la montée de version).

**Ajout du 2026-10-18 : Pêcheur de Terradiance.** Ce légendaire n'a ni raid ni carte de
quête : le chrono ne démarrait jamais. Ajout d'un champ de données `farm = { maps,
fishing, label }` (Îles Brisées, carte 619 et sous-cartes, Dalaran comprise) : séance
`fish` seulement pendant la pêche (lancer ou prise de moins de 90 s), close après 10 min,
comptée comme un passage pour l'estimation (« ~N séances de pêche restantes »). Le haut
fait « Passons aux gros poissons » (10596, 18 critères) devient un composant
`{ achievementID = 10596, need = 18 }`, avec les poissons manquants dans l'infobulle.
Simulation : 60 vérifications OK. À valider en jeu : déclenchement sur un lancer aux
Îles Brisées, rien à Hurlevent, compteur des critères, nom du haut fait par `/lt verify`.

## Réponse courte

Oui, c'est faisable, et LegTracker a déjà presque tout ce qu'il faut :

- **Composants** : `item.trackers` (objet ou monnaie, `need`), comptés par
  `CountItemEverywhere` / `TrackerCount` (sacs, banque, banque de bataillon).
- **Quête** : `ScanLegendaryStatus` renvoie déjà l'étape en cours (`step`) et si elle
  est dans le journal (`onQuest`). Il manque seulement les objectifs détaillés,
  lisibles par `C_QuestLog.GetQuestObjectives(questID)`.
- **Raids de farm** : `item.raids` (instanceID) + `GetRaidLockouts` (libre / verrouillé).
- **Butin** : `CheckLoot` compare déjà les compteurs avant / après chaque mise à jour.

Ce qui est vraiment nouveau : la notion d'épingle et le **chronomètre de farm**.

Différence avec la pêche à garder en tête : un légendaire se farme **en raid, une fois
par semaine**, sur plusieurs semaines. L'unité utile n'est donc pas « prises par heure »
mais **le temps passé, le nombre de séances et l'estimation de séances restantes**.

## Décisions

| Sujet | Décision |
|---|---|
| Combien d'épingles | **Une par personnage** (un légendaire est lié à la classe, et un overlay unique reste lisible). Épingler un autre légendaire remplace le précédent, son historique est gardé. |
| Où on épingle | Bouton punaise dans l'en-tête du panneau détail, icône punaise sur la ligne de la liste (survol), commande `/lt pin` (légendaire affiché) et `/lt pin off`. |
| Ce qui ne s'épingle pas | Légendaires `legacy`, `placeholder`, non équipables par la classe, déjà obtenus. Bouton grisé avec infobulle qui dit pourquoi. |
| Quand le chrono tourne | **Dans une instance listée dans `item.raids`** du légendaire épinglé (`select(8, GetInstanceInfo())`), **ou** dans la zone de la quête en cours (`q.mapID` = carte actuelle ou une de ses parentes). Pas ailleurs : une heure en capitale ne doit pas gonfler le temps de farm. |
| Pause | Comme la pêche : l'horloge se fige si le joueur est absent (`UnitIsAFK("player")`) ou mort en fantôme hors instance. En raid, pas de pause sur inactivité (on attend souvent le groupe, ça fait partie du farm). |
| Séance | Commence à l'entrée dans un raid de farm, se termine en sortant de l'instance **après 5 min de délai** (course fantôme, reset, déconnexion courte = même séance). Une séance de zone de quête se ferme après 10 min hors zone. |
| Boss | `ENCOUNTER_END` avec `success == 1` compte un boss tué dans la séance (valeurs passées par `issecretvalue` avant usage). Une séance de raid avec au moins un boss tué = **un passage**. |
| Gains | Compteurs des composants photographiés au début de la séance ; gain = compteur actuel moins photo (jamais négatif : un composant consommé par une quête ne fait pas baisser le gain). |
| Estimation | Après **2 passages au moins**, moyenne de gain par passage pour le composant le plus long, puis « environ N passages restants » (≈ N semaines si un seul raid). Rien d'affiché avant : pas de chiffre inventé. |
| Où c'est stocké | `LegTrackerDB.pin["Nom-Royaume"] = itemID` et `LegTrackerDB.farm["Nom-Royaume"][itemID]` (voir plus bas). Jamais de clé de premier niveau par personnage. |
| Obtention | Quand `CheckLoot` voit le légendaire : `doneAt` posé, séance close, l'overlay affiche « Obtenu après X h en N séances » jusqu'au prochain clic droit, puis l'épingle est retirée. Entrée dans le fil d'activité de la suite. |
| Overlay hors suite | Fonctionne aussi en addon autonome (socle embarqué `TibiMidnight`), comme la pêche. |
| Combat | L'overlay reste visible ; option « Estomper en combat » (défaut actif, 45 %). Mise à jour 1 fois par seconde seulement s'il est affiché, ticker coupé sinon. Aucune frame sécurisée, aucun `UISpecialFrames`. |
| Clic sur l'overlay | Glisser (clic gauche maintenu) = déplacer ; **clic gauche simple = ouvre LegTracker sur le légendaire** ; clic droit = fermer ; clic sur la ligne de quête = point de route (`AddTomTomWaypoint`, déjà existant). |
| Export / site | **Pas dans ce chantier.** Le temps de farm reste local. Éventuel lot 4 plus tard (Dashboard). |
| Langues | Textes FR + EN dans le fichier, comme `FishOverlay.lua` ; deDE / esES retombent sur l'anglais. |

## Ce qu'affiche l'overlay

Même gabarit que la pêche (fond plat, liseré d'accent orange légendaire `{1, 0.5, 0}`) :

```
Sulfuras, Main de Ragnaros        (pause)      1:12:40
Cœur du Magma · séance 3 · 6 boss
Total 4 h 05 en 5 séances · ~3 passages restants
------------------------------------------------------
[icône] Œil de Sulfuras          1 / 1   ✓
[icône] Lingot de sulfuron       5 / 8   ███████░░░  (+2)
[icône] Marteau en sulfuron      0 / 1
------------------------------------------------------
Quête 2/3 : Tonneraan le Cherchevent
  · Essence de Tonneraan  0/1
Raids : Cœur du Magma libre · Repaire de l'Aile noire verrouillé
```

- Ligne 1 : nom, état (pause), chrono de la séance en cours (sinon temps total).
- Ligne 2 : lieu, numéro de séance, boss tués.
- Ligne 3 : total cumulé et estimation (masquée sans données).
- Composants : 5 au plus, barre de progression, gain de la séance entre parenthèses,
  coche quand c'est complet.
- Quête : étape en cours ; objectifs du journal si `onQuest`, sinon « À prendre :
  PNJ, zone » (clic = point de route) ; rien si le légendaire n'a pas de quête listée.
- Raids : verrouillages de la semaine (réutilise `GetRaidLockouts`).
- **Mode compact** : une ligne, `Sulfuras · 5/8 lingots · 1:12:40`.

## Données

```lua
LegTrackerDB.pin  = { ["Nom-Royaume"] = itemID }
LegTrackerDB.farm = { ["Nom-Royaume"] = { [itemID] = {
  total = 0,          -- secondes cumulées
  runs = 0,           -- passages (séance de raid avec au moins un boss)
  sessions = { },     -- 10 dernières : { start, dur, place, kills, gains = { [compID] = n } }
  cur = nil,          -- séance ouverte : { start, active, last, place, kills, base = { [compID] = n } }
  perRun = { },       -- [compID] = gain total sur les passages (pour la moyenne)
  doneAt = nil,
}}}
-- Réglages (défauts entre parenthèses)
LegTrackerDB.overlay        (true)   -- affiché quand un légendaire est épinglé
LegTrackerDB.overlayAuto    (true)   -- seulement en raid de farm / zone de quête
LegTrackerDB.overlayCompact (false)
LegTrackerDB.overlayScale   (100)
LegTrackerDB.overlayAlpha   (92)
LegTrackerDB.overlayFade    (true)   -- estomper en combat
LegTrackerDB.overlayPos     (nil)
```

Aucune donnée existante n'est modifiée ni migrée. Le nouveau bloc est créé à la volée.

## Lots

### Lot 1 : épingle et chrono (`LegTracker/LegFarm.lua`, nouveau fichier)

- `LegTracker.lua` : passer à `local _, NS = ...` et exposer les fonctions locales
  utiles sans changer leur comportement (`NS.Scan = ScanLegendaryStatus`,
  `NS.TrackerCount`, `NS.CountItem`, `NS.GetRaidLockouts`, `NS.DisplayName`,
  `NS.GetIcon`, `NS.GetTrackerIcon`, `NS.AddWaypoint`, `NS.FindItem(itemID)`,
  `NS.SelectItem(itemID)` qui ouvre la fenêtre sur le légendaire).
- `LegFarm.lua` : `NS.GetPin/SetPin/Unpin/CanPin(item)` (renvoie la raison du refus),
  détection du lieu (`PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`), séance
  (ouverture, délai de 5 / 10 min, fermeture), pause (AFK, fantôme), `ENCOUNTER_END`,
  gains via la photo de départ, moyenne par passage, `doneAt` branché sur `CheckLoot`.
- Fermeture propre au `PLAYER_LOGOUT` (séance gardée ouverte avec `last`, reprise au
  login si moins de 5 min, sinon close à `last`).
- Bouton punaise (détail + ligne de liste), `/lt pin`, `/lt pin off`, `/lt farm`
  (résumé dans le chat).
- `.toc` : `LegFarm.lua` après `LegTracker.lua`.

### Lot 2 : overlay (`LegTracker/LegOverlay.lua`, nouveau fichier)

- Fenêtre `LegTrackerOverlay`, construite au premier affichage seulement.
- Rendu complet et compact décrits plus haut, ticker 1 s seulement visible.
- Objectifs de quête : `C_QuestLog.GetQuestObjectives`, rafraîchis à `QUEST_LOG_UPDATE`
  (regroupé à 0,5 s).
- Options dans `LegTracker_Suite.lua`, nouvelle section « Overlay de farm » (cases et
  curseurs du socle, donc indexées par la palette et l'Annuler de la suite), bouton
  « Remettre l'overlay à sa place », `/lt overlay`.
- `.toc` : `LegOverlay.lua` après `LegFarm.lua`.

### Lot 3 : branchements dans la suite

- `LegTracker_Status()` : si un légendaire est épinglé, la ligne d'état devient la
  sienne (`Sulfuras 5/8`, progression = composant le plus long), sinon inchangée.
  Texte `TibiSuiteL.ST_LEG_PIN_FMT` (FR + EN, core).
- `LegTracker_Overview()` : première ligne = légendaire épinglé avec temps total.
- `openTo("pin")` ouvre la fenêtre sur le légendaire épinglé.
- Fil d'activité : fin de séance de raid (`Cœur du Magma : 48 min, +2 Lingots`,
  `toast = false`), légendaire obtenu avec le temps total (`toast` actif).
- Conseiller : si un raid de farm du légendaire épinglé est libre cette semaine, une
  suggestion `kind = "legendary"` passe devant (poids 1,2). Fournisseur
  `LegTracker_Suggest` déclaré par `suggestFn` dans le glue.
- `WHATSNEW` de la prochaine version + CHANGELOG.

### Lot 4 (plus tard, pas maintenant) : Dashboard

Temps de farm et estimation dans `LegTrackerDB.dashboard`, carte du site et de
Companion. Seulement si Tibiscui le demande après usage en jeu.

## Pièges à respecter

- Midnight : nom de zone et arguments d'`ENCOUNTER_END` passés par `issecretvalue`
  avant toute opération.
- `GetInstanceInfo` : instanceID = 8e retour ; les IDs de `item.raids` sont déjà
  contrôlés par `/lt verify`.
- `C_Item.GetItemCount` ne voit la banque qu'après une ouverture : un composant en
  banque peut sembler « gagné » à l'ouverture de la banque. Parade : la photo de
  séance est refaite à `BANKFRAME_OPENED` si une séance est ouverte (le gain repart de
  là, rien de faux n'est compté).
- Piège Lua déjà vu : `local a, b = x and f()` ne garde que la 1re valeur.
- Aucun `StaticPopupDialogs`, aucun hook `OnHide` sur une frame Échap.

## Validation en jeu (pour Tibiscui)

1. Redémarrage complet du client (deux nouveaux fichiers).
2. Épingler un légendaire faisable (ex. Sulfuras) depuis le détail : l'overlay
   n'apparaît pas en ville avec « auto ».
3. Entrer dans le raid : chrono qui démarre, boss comptés, gain d'un composant affiché.
4. Sortir puis rentrer en moins de 5 min : même séance.
5. `/reload` en raid : la séance continue.
6. `/afk` : « pause ».
7. Mode compact, taille, opacité, déplacement, clic gauche (ouvre LegTracker),
   clic droit (ferme).
8. Ligne d'état et aperçu du Centre, entrée du fil à la fin de la séance.

Ordre d'écriture : lot 1, puis lot 2 (l'overlay lit les séances du lot 1), puis lot 3.
