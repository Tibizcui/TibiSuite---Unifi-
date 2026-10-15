# Conseiller TibiSuite : plan (2026-10-14)

Objectif : proposer au joueur 3 à 5 choses à faire (hauts faits, collections,
rares, renoms, activités) **qu'il n'a pas encore faites**, triées selon ce qu'il
aime jouer, et toujours avec la raison affichée.

Rien n'est écrit. Ce plan est à valider avant le code. Tout ce qui suit sera
à vérifier en jeu par Tibiscui avec un `/reload` (ou un redémarrage complet
quand un fichier est ajouté).

---

## Principe

Même schéma que `statusFn` et `overviewFn` : **chaque module fournit ses
suggestions, le core les note et les affiche.**

- Contrat facultatif de `RegisterModule` : `suggestFn()` renvoie une liste
  `{ id, kind, text, tag, proximity, endsAt, group, open }`.
  - `id` : stable (`"ach:12345"`, `"coll:jid:itemID"`, `"rare:npcID"`).
  - `kind` : `ach | coll | rare | renown | weekly`.
  - `tag` : type de contenu (`delve, dungeon, raid, mplus, pvp, world, quest,
    explore, prof, pet, event, rep, collect`).
  - `proximity` : 0..1 (part déjà faite).
  - `endsAt` : heure de fin si limitée dans le temps (événement, reset), sinon nil.
  - `group` : true si le contenu demande probablement un groupe.
  - `open` : fonction ou cible `openTo` pour y aller au clic.
- Le core appelle chaque `suggestFn` sous pcall, garde le résultat 5 min,
  calcule le score et renvoie la liste : `TibiSuite.GetSuggestions(n)`.

Pourquoi dans le core plutôt que dans Stats : les sources sont dans 5 modules,
et Ma semaine, la palette et `GetNextAction` vivent déjà dans le core. Stats
reste le fournisseur principal (hauts faits + historique).

---

## Le score

```
score = 100 * proximite^1.5 * (0.4 + affinite) * fenetre * poids_type * groupe
```

- **Proximité** : favorise ce qui est presque fini sans exclure le reste.
- **Affinité** (0..1) : part du `tag` dans l'activité des 28 derniers jours,
  lue dans `SX.Aggregate` (donjons, gouffres, raids, M+, JcJ, quêtes du monde,
  quêtes, métiers). Normalisée : le tag le plus joué vaut 1. Sans Stats ou sans
  historique : 0.5 partout (neutre), et la raison ne parle pas d'habitudes.
- **Fenêtre** : 1.6 si `endsAt` < 1 jour, 1.3 si < 3 jours, sinon 1 (d'abord 3 et 7 jours : tout l'hebdo était boosté en permanence, vu en jeu). La mention « Se termine dans » suit la même limite de 3 jours.
- **Poids par type** : réglable, 1 par défaut.
- **Groupe** : 0.6 si `group` et que le joueur ne fait presque jamais ce tag,
  sinon 1.
- **Diversité** : 2 suggestions au plus par `tag` dans la liste finale.
- **Écartées** : `TibiSuiteDB.sugDismissed[id] = until` (« pas intéressé »
  = 90 jours, « plus tard » = 7 jours). Ajouter les nouvelles clés à `SET_KEYS`.

**Raison affichée**, choisie selon le facteur qui pèse le plus :
- « Tu as fait 14 gouffres ces 4 dernières semaines : plus que 2 critères. »
- « L'événement se termine dans 2 jours. »
- « Tu as déjà fini cette instance : il te manque encore la monture (1 %). »
- « Presque fini : 9 sur 10. »

---

## Lot 0 : sonde (avant tout le reste)

`/stats probe adv` (+ `report`, `clear`), résultat dans
`StatsDB[perso].advProbe` (jamais une clé de premier niveau de StatsDB).

À relever :
1. Arbre des catégories : `GetCategoryList` + `GetCategoryInfo` (id, titre,
   parent). Vérifier que les ID des racines sont stables quelle que soit la
   langue (Quêtes, Exploration, JcJ, Donjons et raids, Métiers, Réputation,
   Événements mondiaux, Combats de mascottes, Collections, Fonctionnalités
   d'extension) et repérer où sont rangés les Gouffres.
2. Sous-catégories par extension : leur ordre ou leur titre permet-il de
   déduire l'extension ?
3. Critères : `GetAchievementCriteriaInfo` (type de critère, `assetID`).
   Le type 8 (critère = autre haut fait) donne-t-il l'ID du haut fait enfant ?
   Utile pour les méta-hauts faits.
4. Chaînes : `GetPreviousAchievement` / `GetNextAchievement`.
5. Hauts faits de compte : `GetAchievementInfo` renvoie-t-il bien
   `wasEarnedByMe` et `isAccountWide` ?
6. Coût : durée d'un parcours complet, nombre de hauts faits lus.
7. Événement en cours : le nom du `HOLIDAY` du calendrier se retrouve-t-il
   dans le titre d'une sous-catégorie d'Événements mondiaux ?

Sans ces réponses, le classement par tag et par extension serait deviné.

### Résultats de la sonde (2026-10-14, Tibiscui-Kirin Tor, frFR, build 70391, niveau 90)

- **Volume** : 5 241 hauts faits (2 169 finis, 3 072 pas finis), 14 328
  critères lus. 0 guilde, 0 statistique (GetCategoryList ne les renvoie pas).
- **Coût** : 4,4 s de calcul au total sur 170 images, **pire image 150 ms**.
  Une catégorie par image ne suffit pas : il faut un budget en millisecondes
  par image, avec reprise au milieu d'une catégorie. Le parcours actuel de
  `SX.ScanAchievements` (7.1.5.45) a le même défaut : saccade possible toutes
  les 10 min quand le tableau de bord de Stats le relance.
- **Arbre** : 13 racines, ID stables (ceux attendus : 92, 96, 97, 95, 168,
  169, 201, 155, 15117, 15246, 15301, 81, 15234) plus **15522 Gouffres**
  (sous-catégories 15523 TWW, 15571 Midnight) et **15606 Logis**.
  Les sous-catégories sont rangées dans l'ordre des extensions, de Classique à
  Midnight, mais leurs titres varient selon la racine (« Pandarie »,
  « Donjons de Mists of Pandaria ») : table d'ID -> extension écrite en dur,
  repli sur l'ordre pour une catégorie inconnue (la dernière = extension en cours).
  Donjons et raids : sous-catégories séparées (ex. 15541 / 15566 Midnight).
- **À exclure** : 81 Tours de force, 15234 Héritage, 92 Personnages, 15606
  Logis (logement écarté de la suite), 272 hauts faits à 0 point.
- **Compte** : `wasEarnedByMe` fonctionne (274 finis par un autre personnage),
  drapeau compte sur 3 199 hauts faits.
- **Métas** : critère type 8 = ID d'un autre haut fait, confirmé sur 20 sur
  20 (ex. « Maître des traditions des royaumes de l'Est » -> « Quêtes des
  Hinterlands »). On peut proposer l'enfant le plus avancé.
- **Chaînes** : `GetPreviousAchievement` / `GetNextAchievement` fonctionnent
  (ex. mascottes 400 -> 500 -> ...). Règle : une seule étape par chaîne, la
  première pas finie.
- **Progression chiffrée** : quantité / requis présente sur les critères
  uniques (310/400 mascottes, 198/200 jouets, 298/300 montures, 98/100
  porteurs de drapeau).
- **Événements** : le rapprochement par titre marche (« Marcheurs du temps »)
  mais donne un faux positif (« bonus Champs de bataille » -> sous-catégorie
  « Bataille » des mascottes). Règle : chercher seulement dans les enfants de
  155 Évènements mondiaux, et seulement « titre de catégorie contenu dans le
  titre de l'événement ». Les événements bonus et les chocs JcJ n'ont pas de
  catégorie : ignorés.

**Correspondance racine -> tag retenue** : 96 quest, 97 explore, 15522 delve,
95 pvp, 168 dungeon ou raid (selon la sous-catégorie), 169 prof, 201 rep,
155 event, 15117 pet, 15246 collect, 15301 world.

---

## État (2026-10-14)

Lots 0, 1 et 2 écrits, banc d'essai fengari vert (29 vérifications), copiés
dans AddOns, **pas testés en jeu**. Test : `/ts conseil` (puis `all`,
`reset`). Écarts au plan : affinité par seuils fixes (`AFF_REF` dans
Stats_Module.lua, 1 = joueur régulier) au lieu de « le tag le plus joué vaut
1 » ; donjons et M+ fusionnés dans le tag dungeon ; `sugDismissed` hors
SET_KEYS (données, pas réglage). Réglages sans interface pour l'instant
(lot 4).

Premier test en jeu (2026-10-14, 20 h 49) : parcours complet, aucune erreur,
suggestions cohérentes (Amirdrassil héroïque, Trône du tonnerre via sa méta,
Cocktail de maléfices). Corrigé ensuite : racine 15301 Contenu d'extension
= tag `feature` (Fief de Draenor et Visions de N'Zoth étaient comptés comme
quêtes du monde), avancement en pourcentage au-delà de 25 éléments (« plus
que 1199 »), « presque fini » avant l'habitude dès 80 %.
Validé en jeu à 21 h 01. Puis : au-delà de 25 éléments, on regarde le
reste (« plus que 2 » pour 298 montures sur 300) avant le pourcentage.

**Lot 3 écrit (2026-10-14, non testé en jeu)**, banc d'essai à 62
vérifications. Champ `why` ajouté au contrat (raison du module, remplace
l'avancement, suivie de la fin si elle approche).
- DgnTracker `C.Suggestions(6)` (Collections.lua) : montures « avail »,
  facilité 0,4 + 0,2 (instance entamée) + 0,1 (extension passée) + 0,1 (taux
  documenté ≥ 1 %), poids 0,75, tag raid ou dungeon, taux en note. Rien tant
  que le catalogue n'est pas construit (vue Collections jamais ouverte).
- DailyTracker `DailyTracker_Suggest()` (Rares.lua) : boss mondiaux pas
  vaincus (hors Repaires, 0,8, fin de la quête sinon reset hebdo), 2 rares
  sûrs disponibles dans la zone actuelle (0,6).
- RenTracker `RenTrackerAPI.GetSuggestions()` : 3 factions à 50 % ou plus
  de leur palier, palier en note.
- WeeklyCompass `WeeklyCompassAPI.GetSuggestions()` : par ligne du Grand
  coffre, le prochain seuil (0,3 au moins), fin = reset hebdo.

Test en jeu du lot 3 (21 h 12 et 21 h 16) : boss mondial et Grand coffre
présents. Corrigé : Repaire de type inconnu (journal illisible) reconnu au
deux-points du titre ; fenêtre de fin limitée aux 3 derniers jours ; parcours
des hauts faits lancé tout seul 30 s après le chargement quand le Conseiller
est actif (sinon la première demande répondait « en cours »).
Validé en jeu à 21 h 20 (liste complète, aucune erreur ; le parcours est
protégé et `/ts conseil` affiche son avancement, `Stats_AdvisorState()`).

**Lot 4 écrit (2026-10-14, non testé en jeu)** :
- Ma semaine : rubrique « SUGGESTIONS » (3 lignes) sous les cartes, bouton
  « Tout voir ». Ligne commune `SugRow` / `FillSugRow` (icône, nom, raison,
  note ; clic = y aller, clic droit = `TibiSuite.ShowSuggestionMenu` : y
  aller, plus tard 7 j, pas intéressé 90 j, toutes les suggestions).
- Prochaine action : meilleure suggestion au score 180 (après l'urgent, le
  « À faire » et les objectifs, devant les modules peu avancés),
  `na.suggestion`, `RunNextAction` et le bandeau de Ma semaine l'ouvrent.
- Page Centre `suggest` (« Suggestions », après Objectifs) : 6 suggestions
  en haut, réglages en panneau socle `TibiSuiteCentreSuggest` ancré dessous
  (sugOn, sugHabits, sugNoGroup, un type par case, remise des écartées) :
  annulables et trouvables dans la palette.
- Palette : commande « Suggestions du Conseiller », rubrique « SUGGESTIONS »
  à l'accueil (3, sans répéter la prochaine action).
- Quoi de neuf : entrée `7.1.5.49` (WN_49_0), affichée seulement quand le
  core passera en 7.1.5.49.

Lot 4 validé en jeu le 2026-10-14 vers 21 h 30 (captures : rubrique de Ma
semaine et page Suggestions propres, réglages sous la liste).

**Fenêtre des propositions (2026-10-14 nuit, non testée en jeu, nouveau
fichier `Core/TibiSuiteAdvisor.lua` => redémarrage complet)** :
- 5 propositions en cartes (rang, icône, puce de type, raison, jauge pour les
  vrais avancements : hauts faits et renoms), halo d'accent, glissable,
  Échap natif (UISpecialFrames sans crochet), taille de la suite (SCALED).
- Infobulle commune `TibiSuite.AddSuggestionTooltip` (fenêtre ET lignes du
  Centre) : « Ce qu'il reste à faire » via le champ `steps()` du contrat,
  branché partout : critères d'un haut fait (`SX.AchSteps`, 10 au plus puis
  « N déjà faits »), boss / difficultés encore ouvertes / chance / source pour
  une monture, zone et temps restant (boss mondial, rare), réputation
  actuelle / palier (renom), chaque emplacement du Grand coffre.
- Connexion : vraie connexion seulement (pas /reload), essai à 35 s puis
  toutes les 3 s (2 min au plus), attend la fin de l'analyse (60 s au plus),
  hors combat, hors instance, sans recouvrir installateur, Quoi de neuf,
  Centre, palette ; rien à proposer = rien. `TibiSuiteDB.advPopup` (nil =
  actif, SET_KEYS), case dans la fenêtre et dans Centre > Suggestions.
- Raccourci : action `TIBISUITE_ADVISOR` (Bindings.xml), et bouton de capture
  dans Centre > Suggestions (`TibiSuite.AddAdvisorKeyRow`) : clic puis touche
  (Alt/Ctrl/Maj gérés), Échap annule, clic droit retire ; `SetBinding` +
  `SaveBindings` hors combat, remplacement d'une autre action signalé. Capture
  du clavier seulement pendant le choix (pas de capture permanente d'Échap).
- Aussi : `/ts propositions`, `/ts conseil show`, palette « Propositions du
  jour (fenêtre) », texte Quoi de neuf 7.1.5.49 complété.
- Bancs : moteur 78 vérifications, fenêtre 37 (faux client permissif).

Retour en jeu du 2026-10-15 (fenêtre affichée à la connexion) et corrections :
- Infobulle remplacée par une fiche maison `TibiSuiteAdvisorTip`
  (`TibiSuite.ShowSuggestionTip/HideSuggestionTip`, fenêtre ET lignes du
  Centre) façon fenêtre des hauts faits de Blizzard : icône, points,
  description, TOUS les critères dans l'ordre du jeu en 1 à 5 colonnes
  (coche verte = fait, tiret gris = à faire), compteur « 21 / 24 ». L'icône
  d'attente de l'appel aux armes s'affichait comme un « ? ».
  `SX.AchSteps` renvoie maintenant tous les critères + `{ desc, points }`.
- « Tu as fait 26 raids » : chiffre exact (26 visites de raid de Tibiscui
  en 28 jours, runs de farm de vieux raids, une visite = au moins un boss
  tué) mais trompeur ; phrase par type : « Tu joues souvent en raid : 26
  visites en 4 semaines. ».
- Bancs : moteur 79, fenêtre 48.

## Lot 1 : moteur dans le core

- Contrat `suggestFn`, `TibiSuite.GetSuggestions(n)`, `DismissSuggestion(id,
  days)`, `OnSuggestionsChanged(fn)`, mémoire 5 min, recalcul à la demande.
- Profil d'affinité : fonction globale `Stats_Affinity(days)` exposée par
  Stats (renvoie `{ tag = 0..1 }`), lue par le core si elle existe.
- Réglages (Centre) : activer le Conseiller, types proposés, tenir compte de
  mes habitudes (oui / non), masquer le contenu de groupe.
- Textes `TibiSuiteL.SUG_*` en FR + EN dans le core.

## Lot 2 : Stats, hauts faits

- Index des catégories (racine -> `tag`, sous-catégorie -> extension) d'après
  la sonde, construit une fois par version du jeu.
- Parcours élargi : au lieu de garder 5 hauts faits à 80 %, garder les 8
  meilleurs **par tag** à partir de 30 %. Budget de 5 ms par image avec
  reprise au milieu d'une catégorie (environ 10 s en tâche de fond), jamais
  en combat. Un parcours complet par session, puis mise à jour ciblée des
  candidats à `CRITERIA_UPDATE` / `ACHIEVEMENT_EARNED`. `NearAchievements`
  passe sur le même moteur (corrige la saccade de 150 ms).
- Exclusions : guilde, statistiques, 0 point, tours de force, hauts faits
  disparus (catégorie « Héritage »).
- `group` : catégorie Raids ou Mythique+, sauf extension ancienne et joueur au
  niveau maximum (heuristique, peut se tromper).
- Événement en cours : sous-catégorie qui correspond au `HOLIDAY` du moment,
  `endsAt` = fin de l'événement.
- Méta-hauts faits (si la sonde le permet) : proposer l'enfant le plus avancé
  plutôt que la méta entière, avec « fait partie de X ».
- `Stats_Affinity(days)` pour le core.

## Lot 3 : autres fournisseurs

- **DgnTracker** : instances déjà finies (`done`) qui ont encore une monture,
  mascotte ou un jouet manquant, taux de drop dans la raison si connu.
  Tag `collect`, `group` selon raid / difficulté.
- **DailyTracker** : rares et boss mondiaux pas tués cette semaine,
  `endsAt` = reset hebdo.
- **RenTracker** : renom à moins d'un palier de la prochaine récompense.
- **WeeklyCompass** : activités hebdo non faites, seulement si elles ne sont
  pas déjà « urgentes » (sinon doublon avec la prochaine action).

## Lot 4 : affichage

- Carte « Suggestions » dans Ma semaine (3 à 5 lignes, raison en dessous,
  clic = ouvrir, clic droit = menu Plus tard / Pas intéressé).
- `GetNextAction` : les suggestions arrivent après l'urgent, le « À faire » et
  les objectifs personnels.
- Palette : rubrique « Suggestions ».
- Page Centre « Suggestions » : liste complète, filtres par type, réglages,
  liste des écartées (avec bouton pour les rendre).
- Entrée `WHATSNEW` pour la version.

## Plus tard (non prévu dans ce plan)

- Carte sur le Dashboard (site + Companion) via l'export de Stats.
- Transformer une suggestion en objectif personnel en un clic.

---

## Limites assumées

- Aucune donnée externe : difficulté, durée et faisabilité en solo sont
  devinées par des règles simples.
- L'affinité ne connaît que ce que Stats a vu depuis son installation.
- Le parcours complet des hauts faits reste lent (réparti sur plusieurs
  secondes), d'où la mémoire.

## Questions ouvertes

1. Les suggestions de hauts faits portent-elles sur le personnage connecté
   seulement, ou aussi sur les hauts faits de compte gagnables par un autre
   personnage ?
2. Le Conseiller est-il actif par défaut pour tout le monde, ou à activer ?
