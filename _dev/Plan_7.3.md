# Plan 7.3 : chat unifié et six ajouts

Rédigé le 2026-10-20. Rien n'est écrit, rien n'est testé en jeu. Chaque lot
sera validé par Tibiscui avec un `/reload` (ou un redémarrage complet du
client quand un lot ajoute un fichier).

Ordre proposé : lot 0 (petit, utile tout de suite), puis A, B, D, E, F, et C
en dernier (le plus risqué côté API).

Règles rappelées pour tous les lots : aucune SavedVariables renommée ni
déplacée, mode double respecté (chaque module marche seul), textes FR + EN
dans le core (`TibiSuiteL`), toute nouvelle clé de réglage de suite ajoutée à
`SET_KEYS`, une entrée `WHATSNEW` à la release.

---

## Lot 0 : un seul annonceur dans le chat

### Ce qui est demandé (ma lecture)

- **TibiSuite (le core) est chargé** : à la connexion, seul TibiSuite écrit
  dans le chat. Aucun module n'annonce sa propre ligne, même si les 15 sont
  installés et actifs.
- **TibiSuite absent** (ou désactivé dans la liste des addons) : chaque addon
  installé affiche sa propre ligne, comme aujourd'hui.

### État actuel (relevé dans le code)

Le réglage `TibiSuiteDB.loginMsg` (`full | one | none`, défaut `one`) existe
déjà, mais il n'est pas appliqué partout de la même façon :

| Module | Comportement en suite aujourd'hui |
|---|---|
| XPBar, RepBar | muets en suite (correct) |
| DailyTracker, DgnTracker, LvlHistory, LairLens, SkillTracker, PostBox, MiniHub | muets en `one` / `none`, **parlent en `full`** |
| RenTracker | **ignore le core**, parle toujours (suit seulement sa propre option `loginMsg`), et peut même parler deux fois (rattrapage `IsLoggedIn` dans `ADDON_LOADED` puis `PLAYER_LOGIN`) |
| LegTracker | **parle toujours**, sans condition (`LegTracker.lua:2840`), avec en plus la liste de ses sous-commandes |
| WeeklyCompass, Stats, Opacity, Standby | pas de ligne de version trouvée ; à confirmer par l'audit (étape 1) |

### Ce qu'on change

1. **Audit complet** des sorties automatiques du chat (tout `print` qui ne
   répond pas à une commande tapée par le joueur) : connexion, rattrapage
   LoadOnDemand, alertes. Tableau final dans ce fichier.
2. **Règle unique dans chaque module** : `if HasCore() then` silence au
   login, quel que soit `loginMsg`. En autonome, rien ne change (chaque
   module garde sa propre option, ex. `RenTrackerDB.options.loginMsg`).
3. **Le core devient le seul annonceur**, selon `loginMsg` :
   - `one` (défaut) : la ligne actuelle, plus le nombre de modules actifs
     (« TibiSuite v7.3.0, 15 modules actifs, /ts pour ouvrir »).
   - `full` : l'en-tête actuel, puis une ligne compacte avec les commandes
     des modules actifs (`/dt /dg /rt /lt ...`), lues depuis le catalogue
     `MODULES` (nouveau champ `slash`). C'est ce qui remplace les lignes
     individuelles.
   - `none` : rien (l'alerte de nouvelle version reste, comme aujourd'hui).
4. RenTracker : supprimer le double message du rattrapage.
5. Alertes hors connexion (Paragon de RenTracker, rares de DailyTracker,
   etc.) : en suite, elles passent déjà ou passeraient par le fil
   d'activité. **Question ouverte** ci-dessous : faut-il aussi les retirer
   du chat en mode suite ?

Ce qui ne change pas : les réponses aux commandes tapées (`/lt verify`,
`/stats probe`...) continuent d'écrire dans le chat. L'alerte de version
du socle reste unique (déjà gérée au nom de TibiSuite en suite).

Effort : petit. 10 à 12 fichiers touchés, aucun nouveau fichier, `/reload`
suffit.

---

## Lot A : « J'ai X minutes » (session guidée)

**But.** Le joueur choisit un temps (15, 30, 45, 60, 90 min). La suite
compose une liste ordonnée d'activités qui tient dans ce temps et la coche
au fil de la session.

**Briques existantes.** `TibiSuite.GetNextAction()` (Centre), Conseiller
(`GetSuggestions`), `statusFn` / `overviewFn` des modules, rappels de reset,
objectifs (`GetGoals`), durées de récolte / pêche (`SkillTracker`).

**Conception.**
- Nouveau champ facultatif `est` (minutes estimées) dans le contrat
  `suggestFn` et dans les lignes d'`overviewFn`. Sans `est`, une table de
  durées par défaut dans le core, par `kind` (rare 3, boss mondial 6,
  quête quotidienne 4, gouffre 15, clé M+ 30, seuil de coffre selon le
  type, farm = temps restant).
- Planificateur glouton : on prend les candidats triés par la note
  actuelle (urgent, À faire, objectif, suggestion), on ajoute tant que le
  budget tient, une marge de 15 % pour les trajets. Un seul farm au plus,
  placé en fin de liste pour remplir le reste.
- Suivi : chaque entrée se coche quand son état change (même mécanisme que
  les transitions du fil d'activité). Fin de session = budget écoulé ou
  tout coché, bilan d'une ligne dans le fil.
- Lot A2 (après retour en jeu) : apprendre les durées réelles quand elles
  sont mesurables (temps entre deux transitions d'un même module), moyenne
  glissante dans `TibiSuiteDB.estLearn[kind]`.

**Interface.** Bouton « J'ai du temps » dans Ma semaine (choix du temps),
commande de palette, `/ts temps 45`. Petite fenêtre de liste à cocher,
épinglable comme un widget, masquée en combat selon les règles d'auto-masquage.

**Données.** `TibiSuiteCharDB.session = { at, budget, items = { {id, key,
text, est, done} } }`.

**Branchements modules.** `est` dans DailyTracker, WeeklyCompass,
DgnTracker, RenTracker, LegTracker, SkillTracker (6 fichiers de glue ou
d'API, aucun changement de SavedVariables).

**Risque.** Les estimations seront fausses au début : on l'affiche comme
« environ », jamais comme une promesse.

Effort : moyen. Un nouveau fichier `Core/TibiSuitePlanner.lua` (redémarrage
complet du client).

---

## Lot B : le patrimoine de la bande de guerriers

**But.** Une vue « combien je vaux et d'où vient l'argent » : or de tous les
persos, banque de bataillon, valeur des sacs et banques, gains par source,
courbe dans le temps.

**Briques existantes.** Or et historique `gold` de Stats (`KPI_DEF.gold`),
`Stats_WeeklyNet()`, `SkillTrackerDB.wealth` (relevés sacs / banques,
`ST.SnapValue`, `ST.WealthTop`), sessions de récolte et de pêche (valeur et
po/h), journal HV de PostBox.

**Conception.**
- API de lecture par source, aucune donnée copiée dans le core :
  `Stats_GoldByChar()`, `SkillTracker_WealthSummary()`,
  `PostBox_LedgerSummary(since)`, `SkillTracker_FarmValueSince(since)`.
- Historique : on ajoute un point par jour dans la base du module qui
  possède la donnée (`SkillTrackerDB.wealth.hist`, 90 jours), l'or reste
  dans Stats. Le core compose la courbe totale.
- Répartition des gains de la semaine : HV, récolte, pêche, butin / quêtes
  (reste = net Stats moins les sources connues, affiché comme « autres »).
- Banque de bataillon : `C_Bank.FetchDepositedMoney(Enum.BankType.Account)`
  n'a pas été confirmé en jeu (sonde phase 0 de WeeklyCompass). Sonde
  d'abord, sinon on relève à l'ouverture de la banque.

**Interface.** Page Centre « Patrimoine » (total, courbe 30 / 90 jours,
répartition, top 5 objets de valeur, top persos), ligne dans Ma semaine,
mode streaming respecté (`FmtGold` renvoie `***`).

**Site / Companion.** Bloc `data.suite.worth` dans l'export Stats et carte
« Patrimoine » du Dashboard (dépôt Tibiscui.fr + copie Companion).

Effort : moyen. Le plus gros du travail est la page et la courbe.

---

## Lot C : partage en groupe (le plus risqué, en dernier)

**But.** En groupe ou en raid, voir ce que les autres joueurs de la suite
partagent : qui est déjà sauvegardé sur quel boss, qui farme quel
légendaire, qui a besoin de quelle monture de ce donjon.

**Briques existantes.** Préfixe addon `TibiSuite` et rythme d'envoi du
socle (alerte de version), verrouillages (WeeklyCompass), épingle
LegTracker, catalogue Collections de DgnTracker.

**Conception.**
- Désactivé par défaut (`TibiSuiteDB.groupShare`, `SET_KEYS`), visible et
  explicite dans le Centre : on ne partage rien sans accord.
- Message `G1:<type>:<charge>` court, envoyé une fois à l'entrée dans un
  groupe et à la demande d'un membre arrivé plus tard, jamais en combat,
  60 s au moins entre deux envois par canal.
- Types : `L` verrouillages de l'instance courante, `P` légendaire épinglé,
  `M` montures manquantes de l'instance courante (identifiants seulement).
- Réception : table en mémoire seulement, rien n'est sauvegardé sur les
  autres joueurs.

**Risque majeur.** Depuis Midnight, la communication entre addons est
limitée en instance pendant les rencontres et les clés. **Sonde
obligatoire avant tout code** : envoi et réception en groupe, en donjon
hors combat, en raid, en clé, avec trace dans `TibiSuiteDB.groupProbe`.

**Interface.** Encart « Groupe » dans l'aperçu de DgnTracker et de
LegTracker, infobulle sur les boss.

Effort : moyen, mais dépend entièrement du résultat de la sonde.

---

## Lot D : récap de fin de semaine

**But.** Au premier login après le reset hebdo : ce que tu as fait la
semaine passée, comparé à la précédente, objectifs atteints, meilleur
moment. Partageable sur le Dashboard.

**Briques existantes.** `TibiSuiteCharDB.nextWeeklyReset` (détection de
nouvelle semaine), `TibiSuiteDB.weekSnap` (60 jours), objectifs
(`doneWeek`), métriques hebdo de Stats, fil d'activité, récap hebdo de
DailyTracker.

**Conception.**
- Le piège : au reset, les compteurs de la semaine sont déjà remis à zéro.
  On fige donc la semaine en continu (au logout et toutes les 10 min) dans
  `TibiSuiteDB.weekRecap[cle][weekId]`, 8 semaines gardées.
- Contenu : temps joué, or net, donjons / raids / gouffres / clés, Grand
  coffre (niveaux obtenus), réputations gagnées, objectifs faits / ratés,
  légendaire (progression), « meilleur moment » = l'événement le plus
  rare du fil (haut fait, monture, légendaire, niveau).
- Comparaison avec la semaine d'avant, flèches et pourcentages.
- Le récap de DailyTracker devient une section de celui-ci en mode suite
  (il reste tel quel en autonome).

**Interface.** Fenêtre à la vraie connexion (pas au `/reload`), une fois par
semaine, hors combat et instance, `TibiSuiteDB.weekRecapPopup` (nil =
actif). Rejouable depuis Ma semaine et `/ts semaine`.

**Site / Companion.** `data.suite.recap` dans l'export, carte « Ma semaine
passée » du Dashboard.

Effort : moyen.

---

## Lot E : planificateur de clés Mythique+ sur tous les persos

**But.** D'un coup d'œil : clé en poche de chaque perso, cote, donjons qui
rapportent le plus de cote, persos dont le coffre M+ n'est pas rempli.

**Briques existantes.** `ns.CollectMPlus()` (WeeklyCompass, lot 5 : cote,
meilleure clé par donjon, courses de la semaine, clé en poche), fiche par
perso (`sheet.mplus`), gestionnaire de personnages de WeeklyCompass.

**Conception.**
- Lecture des fiches de tous les persos (déjà sauvegardées par
  WeeklyCompass), rien de nouveau à collecter sauf vérifier la clé en
  poche, notée « non confirmée » dans la sonde phase 0.
- « Gain de cote possible » par donjon : écart entre la meilleure clé du
  perso et le niveau de la clé en poche, calcul simplifié et annoncé comme
  estimation (la formule exacte de Blizzard n'est pas publique).
- Coffre : nombre de courses manquantes pour le prochain seuil M+.
- Sortie Conseiller : `kind = "mplus"` (« ta clé +12 Cinderbrew rapporte
  environ 25 points sur Untel »).

**Interface.** Onglet « Mythique+ » dans WeeklyCompass (tableau persos x
donjons, coloré), ligne dans l'aperçu, entrée de « J'ai X minutes » (lot A).

Effort : moyen. `/wc mplus` sert de sonde de contrôle.

---

## Lot F : visite guidée du Centre

**But.** Faire découvrir en 2 minutes ce qui est puissant mais caché :
Ma semaine, la palette (`/ts k`), les widgets (Maj + clic), le clic droit
sur la barre, Annuler, le Conseiller.

**Conception.**
- 7 étapes, chacune surligne une zone réelle (cadre d'accent animé) avec
  une bulle de texte, boutons Suivant / Passer.
- Lancée une fois après l'installateur ou à la première ouverture du Centre
  après la mise à jour (`TibiSuiteDB.tourDone = version`). Relançable
  depuis Accueil et `/ts visite`.
- Étapes qui s'adaptent : celles d'un module désactivé sont sautées.
- Aucun texte dans les modules, tout dans `TibiSuiteL` (FR + EN).

Effort : petit à moyen. Un nouveau fichier `Core/TibiSuiteTour.lua`
(redémarrage complet).

---

## Questions à trancher avant de coder

1. **Lot 0** : en mode suite, les alertes automatiques des modules (Paragon,
   rares...) doivent-elles aussi quitter le chat pour aller seulement dans
   le fil d'activité ? Proposé : oui pour celles qui ont déjà une entrée
   dans le fil, le reste ne bouge pas.
2. **Lot 0** : garde-t-on le mode `full` avec la ligne des commandes des
   modules, ou le simplifie-t-on ?
3. **Lot A** : durées par défaut proposées ci-dessus, à corriger selon ton
   expérience de jeu.
4. **Lot C** : d'accord pour une sonde d'abord, et pour que le partage reste
   désactivé par défaut ?
5. **Lots B et D** : carte Dashboard et Companion dans la même release, ou
   l'addon d'abord ?
6. Version cible : tout en 7.3.0, ou une release par lot (7.2.2 pour le
   lot 0) ?

---

## État de réalisation (2026-10-20)

Les 7 lots sont écrits, vérifiés en syntaxe (luaparse, Lua 5.1) et passés
dans un banc fengari avec un faux client (planificateur, patrimoine, bilan,
Mythique+, visite, sonde). **Rien n'est testé en jeu.** Six nouveaux
fichiers : **redémarrage complet du client** obligatoire.

Choix retenus pour les questions ouvertes : les propositions du plan
(alertes déjà présentes dans le fil = fil seulement en suite, mode `full`
avec la ligne des commandes, sonde avant le partage, partage coupé par
défaut). Version et WHATSNEW : à décider à la release.

### Écarts par rapport au plan

- **Lot 0.** Fait comme prévu. En suite, passent par le fil d'activité au
  lieu du chat : conflit de MiniHub, concentration pleine de SkillTracker
  (avec notification), butin de LegTracker (l'alerte de raid reste).
  Restent dans le chat (pas d'entrée dans le fil) : coffre de Paragon de
  RenTracker, bilan d'absence de Standby. Le core réutilise
  `MODULE_SLASH` de TibiSuiteOptions.lua (LairLens = `/ll`).
- **Lot A.** Champ `est` accepté dans `statusFn` / `suggestFn` / objectifs,
  mais aucun module ne le renseigne encore : table `DEF_EST` + apprentissage
  (`TibiSuiteDB.estLearn`). Bouton « J'ai du temps » dans les accès rapides
  de Ma semaine, raccourci `TIBISUITE_PLANNER`, `/ts temps [min]`.
- **Lot B.** Historique dans `TibiSuiteDB.worthHist` (le total est une
  donnée de suite, aucun module ne la possède). Pas de journal PostBox : les
  ventes HV viennent du journal d'or de Stats (`goldLog`, source `ah`). Or
  par perso et banque de Bataillon : WeeklyCompass (déjà sondé). Pas de ligne
  dans Ma semaine. Page Centre `worth` via le nouveau registre
  `TibiSuite.RegisterCentrePage`. Carte du Dashboard et de Companion : pas
  faite (dépôt Tibiscui.fr), le bloc `data.suite.worth` est déjà exporté.
- **Lot D.** `/ts bilan` (`/ts semaine` ouvrait déjà Ma semaine). Le récap
  de DailyTracker n'est pas fusionné. Bloc `data.suite.recap` exporté, carte
  du Dashboard pas faite.
- **Lot E.** Aucun calcul en points de cote (formule de Blizzard non
  publique) : on compare des niveaux de clé. Fenêtre à part
  (`WeeklyCompassMPlusFrame`), ouverte par l'onglet « Mythique+ », `/wc cles`
  ou `openTo("mplus")`. Suggestions `kind = "mplus"` dans le Conseiller.
- **Lot F.** 9 étapes (session guidée et Patrimoine ajoutés).
- **Lot C.** Sonde seulement : `/ts sonde groupe` (report, clear), préfixe
  `TibiSuiteGP`, trace dans `TibiSuiteDB.groupProbe`. Le partage lui-même
  attend le résultat.

### À valider en jeu en premier

1. Connexion avec tous les modules : une seule ligne TibiSuite dans le chat.
2. `/ts temps 30` : liste cohérente, coche automatique d'un « À faire ».
3. Centre > Patrimoine : or des persos, objets, banque de Bataillon.
4. Onglet Mythique+ de WeeklyCompass : clé en poche, meilleures par donjon.
5. Visite guidée à la première ouverture du Centre.
6. Le bilan ne peut se voir qu'au premier login après le prochain reset
   hebdo (ou `/ts bilan` pour la semaine en cours).

### Retour de la sonde de groupe (2026-10-20, Tibiscui seul en groupe)

- `party` hors combat : 4 envois, code 0 (succès).
- `party+combat` (hors rencontre) : 1 envoi, code 0 (succès).
- `party+enc+combat+lockdown` (rencontre de boss) : 2 envois, code 11,
  très probablement `AddOnMessageLockdown` : `InChatMessagingLockdown()` vaut
  vrai pendant une rencontre et le client refuse l'envoi.
- Réceptions : 0, normal (aucun autre joueur n'avait la sonde active).
- Enregistrement du préfixe : 0 (succès).

Conséquence pour le partage : envoyer seulement hors verrouillage
(`C_ChatInfo.InChatMessagingLockdown()` faux), mettre en file d'attente
pendant une rencontre et envoyer à la fin. Reste à vérifier avec un 2e
joueur : la réception, puis le raid et une clé Mythique+.

### Lot C écrit (2026-10-20, demande de Tibiscui)

`TibiSuite/Core/TibiSuiteGroup.lua` : partage coupé par défaut, case dans la
fenêtre Groupe (`/ts groupe`, palette). Partagé : boss tués de l'instance
courante (`G1:L`), légendaire épinglé (`G1:P`), montures manquantes ici
(`G1:M`), demande (`G1:Q`). Règle du verrouillage appliquée : file d'attente
pendant une rencontre ou en combat, vidée à la fin. Testé dans le banc avec
deux joueurs simulés ; la réception réelle reste à vérifier à deux en jeu.

Validation en jeu (2026-10-20) : partage en groupe confirmé par Tibiscui
après redémarrage complet du client.
