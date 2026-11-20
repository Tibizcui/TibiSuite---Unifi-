# TibiSuite : journal de développement (multi-versions, LvlHistory)

> Extrait de CLAUDE.md, déplacé tel quel (texte non modifié). À lire quand on travaille sur ce sujet.

## Multi-versions Classic et Forever : core, XPBar, RepBar, Stats, MiniHub, Opacity, Standby, SkillTracker, LvlHistory, RenTracker (2026-11-08, non testé en jeu)

Seuls modules ouverts à WoW Forever et Classic, en autonome (le core reste
Midnight). `XPBar.toc` = Midnight + Forever (16001), `XPBar_Vanilla.toc`, `XPBar_Wrath.toc`, `XPBar_Cata.toc`,
`XPBar_TBC.toc`, `XPBar_Mists.toc` : même contenu, seule la ligne Interface
change, **toute modification de la liste de fichiers est à reporter dans les 6**
(et le bump de version aussi). Le code choisit ses API par présence de la
fonction, jamais par numéro de version ; un événement absent de Classic
s'inscrit sous pcall. Détails et check-list : `_dev/XPBar_MultiVersions.md`.
RepBar suit le même schéma (`RepBar_Vanilla/TBC/Wrath/Cata/Mists.toc`) ; en tête de
`RepBar.lua`, une copie LOCALE de `C_Reputation` (métatable sur la globale,
jamais d'écriture dans la table globale) reconstruit `GetFactionDataByID`,
`GetNumFactions`, `GetFactionDataByIndex`, `SetWatchedFactionByID` avec
l'ancienne API. « Centrer en bas » (XPBar et RepBar) se pose au-dessus des
barres natives visibles (`BottomBarsTop` / `EdgeOffset`), RepBar aussi
au-dessus ou sous XPBar. Si RepBar est collé sous XPBar centré en bas, XPBar
réserve sa hauteur (`RepReserve`, `XPBarDB.centerRepReserve`) ; RepBar appelle
le global `XPBar_UpdateRepReserve()` à chaque `ApplyPosition` / `ApplySize` /
fin de déplacement, XPBar aussi 1,5 s après la connexion (seul l'écart change,
un réglage Maj + glisser est conservé).
Stats (lot 1, en jeu seul) : même schéma (`Stats_Vanilla/TBC/Wrath/Cata/Mists.toc`),
toutes les inscriptions d'événements sous pcall ; le reste était déjà protégé.
L'historique Classic / Forever vit dans le `StatsDB` de chaque client (dossier
WTF propre à la version) : Tibi Companion ne lit que `_retail_`, donc rien
n'arrive au Dashboard tant que le lot 2 (version du jeu dans l'export,
Companion qui lit les autres dossiers, filtre par version) n'est pas fait.
Core TibiSuite et MiniHub : même schéma (`TibiSuite_*.toc`, `MiniHub_*.toc`),
inscriptions sous pcall ; menu Échap, `Settings`, `MenuUtil`, `C_Calendar`
étaient déjà testés avant usage. `C_AddOns` existe sur toutes les versions
Classic actuelles (DBM-Core, qui déclare 11509, l'appelle sans garde) : pas de
repli prévu. Avec le core présent, les boutons minimap d'XPBar / RepBar /
Stats s'effacent comme sur Retail. Les autres modules restent Midnight seul :
le catalogue les voit simplement absents.
Opacity, Standby, SkillTracker : même schéma (`*_Vanilla/TBC/Wrath/Cata/Mists.toc`),
inscriptions sous pcall, le reste était déjà protégé. SkillTracker en Classic
Era / TBC / Wrath (et Forever si `GetProfessions` ne renvoie rien) : repli
`GatherLegacyProfessions` sur `GetSkillLineInfo` (principal = abandonnable,
secondaires reconnus par nom de sort, `LEGACY_PROFS` skillLine -> sort, sinon
id 900000+ tiré du nom), un palier par métier marqué `fixedIdx` (extension du
client, respecté par `ResolveLineIndexes`).
LvlHistory : idem, plus un repli `MAX_PLAYER_LEVEL` dans `T.MaxLevel` et
l'onglet Alts (`GetMaxPlayerLevel` appelé sans garde).
**WoW Forever interdit `COMBAT_LOG_EVENT_UNFILTERED`** (inscription =>
ADDON_ACTION_FORBIDDEN « UNKNOWN() », fenêtre « X a été bloqué », le pcall
n'y peut rien) : Stats ne s'y inscrit pas quand `SX.IS_FOREVER` (interface
16000-19999, seule détection par numéro de version, comme EllesmereUI). Ne
jamais forcer le chargement d'un `Blizzard_*` depuis notre code (Stats
Backfill chargeait le journal d'aventure). Sonde de Stats (`Constants.lua`) :
ADDON_ACTION_BLOCKED/FORBIDDEN + `debugstack` => ligne fautive dans le chat
et `StatsDB.blockLog` (10).
RenTracker : copie locale de `C_Reputation` (bloc de RepBar, `SetWatchedFactionByID`
reconstruit renvoie false au lieu d'une erreur), onglets filtrés par
`GameMaxExpansion()` (numéro d'interface : <20000 Vanilla, <30000 TBC...),
`EXT_ALLOWED`, mention `QUESTS_RETAIL_NOTE` hors Retail.
Restent Midnight seul : DailyTracker, DgnTracker, LairLens, LegTracker,
PostBox, WeeklyCompass.

## LvlHistory : onglet Raids (non testé en jeu)

Fenêtre à 7 onglets : 1 Session, 2 Zones, 3 Alts, 4 Donjons, 5 **Raids**, 6 Stats,
7 Niveaux (`LvlHistoryAPI.Open(tab)`, `/lvlh raids`, `/lvlh niveaux`). Un run de
raid = un raid + une difficulté (`LFR|N|H|M`, déduite du `difficultyID` de
`ENCOUNTER_END`, jamais du nom localisé) + un verrou hebdomadaire : le premier
boss tué ouvre le run, les suivants s'y ajoutent (`T.RecordRaidKill`, état dans
`raidWeek`, aucun état à réconcilier au login). Données par personnage :
`raidRuns`, `raidDetails` (`"Nom||Diff"`), `raidBoss`, `raidBossDiff`, `raidLog`.
L'onglet réutilise les lignes de l'onglet Donjons (segments LFR / N / H / M).
Branché sur : le résumé Dashboard (`raids`, `raidBoss`, `sess[].rd`, repris
par `Stats/Export.lua`, ajout additif), la recherche de la suite, l'API
(`GetRaidStats`, événement `onRaidBossKilled`). Toute nouvelle entrée de tab
décale les numéros : vérifier `OpenTab`, `RefreshTabN`, `listContentH[N]` et le
mode réduit (`activeTab == N`).


## LvlHistory : temps passé en instance (non testé en jeu)

- Chrono persistant `db._inst` (Core.lua, bloc « Temps passé en instance ») : `T.InstSync()` à chaque `PLAYER_ENTERING_WORLD`, `T.InstPause()` à `PLAYER_LEAVING_WORLD` (le hors-jeu et les écrans de chargement ne comptent pas), `T.InstTick()` toutes les 5 min.
- Donjons : `dgnTime[nom]` (toutes visites), `dgnTimeRuns` / `dgnTimeDone` (runs terminés, base de la moyenne). Une clé M+ utilise la durée exacte `ms` de `CHALLENGE_MODE_COMPLETED`, les autres la durée de la visite.
- Raids : `raidTime["Nom||Diff"]` et `raidTimeRuns` (un verrou hebdo chronométré = un run, drapeau `timed` dans `raidWeek`).
- Pas d'historique rétroactif ; le temps inclut wipes, AFK et pillage. Colonne « Passé » (onglets Donjons et Raids), infobulle total + moyenne, total dans le bandeau. Largeurs de colonnes rééquilibrées (barre 48, nom max 150).
- Largeur auto (UI.lua) : `ApplyWidth()` élargit la fenêtre (plancher `FW`, plafond écran - 40) selon `listContentW[onglet]` (Donjons/Raids : nom + statut + colonnes) et `FooterNeedW()` (le bouton Opacité est ancré à gauche du nom de zone). `curW` remplace `FW` pour les lignes Donjons/Raids/Gouffres. Les onglets 1 à 3, 6 et 7 gardent leur mise en page de base (non étirée). Non testé en jeu.

## LvlHistory : chronomètre d'instance à l'écran (2026-11-15, non testé en jeu)

- Nouveau fichier `LvlHistory/Timer.lua` (inscrit dans les 2 `.toc` après `UI.lua` : redémarrage complet du client requis la première fois). Cadre `LvlHistoryInstTimer` : nom de l'instance (+ difficulté en raid), temps `mm:ss` ou `h:mm:ss`, type, liseré coloré par type. Rafraîchi chaque seconde uniquement quand il est visible ; glisser pour déplacer, clic droit = options, croix = masqué jusqu'à la prochaine instance.
- Aucun second compteur : lit `db._inst` via `T.InstElapsed()` (Core.lua, lecture seule). `T.InstKind()` classe l'instance : `party`, `raid`, `lair` (type raid + `difficultyID` 250 ou `C_DelvesUI.IsInLair`), `delve` (`T.CurrentContext()`), `scenario` (Tourment, scénarios de Mists...), `pvp`, `arena`. Le Mythique+ est un `party` affiché comme `mplus` (`C_ChallengeMode.IsChallengeModeActive` ou `difficultyID` 8), avec sa propre case.
- Seuls `party` et `raid` alimentent `dgnTime` / `raidTime` : les autres types ne servent qu'à l'affichage. **Changement** : le temps des Repaires n'est plus rangé dans `raidTime` en « N » (l'existant n'est pas effacé), et `ENCOUNTER_END` ignore les boss de repaire (`IsLair(diffID)`) : ni run ni boss de raid. Aucune donnée de repaire n'existait dans la sauvegarde de Tibiscui au 15 novembre 2026.
- Options (LvlHistory_Suite.lua, section « Chronomètre d'instance », avant `FloatControls`) : case générale, une case par type (Repaires et Gouffres masquées sans `C_DelvesUI`), verrouillage, replacer. Réglages dans `LvlHistoryDB.settings` (compte) : `timer` (false = coupé), `timerOff[type] = true`, `timerLocked`, `timerPos = {point, relPoint, x, y}`. Aucune nouvelle SavedVariables.
- 26 libellés `OPT_TIMER_*` / `TIMER_*` en 9 fichiers `Locale/` (français accentué par défaut dans le code). Diagnostic : `/lvlh temps` affiche le type détecté.
- **Reprise après une mort** (Core.lua, `INST_GRACE` = 15 min) : sortir de l'instance en fantôme (`UnitIsDeadOrGhost`) met le chrono en attente (`db._inst.leftAt`, `t0 = nil` : la course dehors ne compte pas, cadre masqué). Retour dans la même instance (même type, nom, difficulté) sous 15 min : le chrono reprend ; sinon clos au retour ailleurs ou par `T.InstTick()`. Seulement donjon pas encore compté et raid ; champ de bataille, arène, gouffre, scénario et repaire quittés sont clos. Côté donjon : une sortie en fantôme ne compte plus le run (`db._dgn.ghostOut`), le retour garde les boss tués ; un run quitté en fantôme sans retour est compté à l'entrée suivante (comme avant à la sortie). Aussi : passage direct d'un donjon à un autre (file d'attente) = le premier est compté s'il avait un boss. `/lvlh temps` affiche « en attente du retour (mort) ».
- **Boss tués / total** (7.6.1, Timer.lua) à droite de l'horloge, pour donjon, Mythique+, raid et repaire. Tués : le plus grand de (verrou d'instance `GetSavedInstanceInfo` progress, boss tués pendant la visite `db._inst.kills[encID]` via `ENCOUNTER_END` réussi). Total : verrou (`numEncounters`), sinon Journal (`EJ_GetInstanceForMap` + `EJ_GetEncounterInfoByIndex`, sélection d'instance puis palier restauré, jamais en combat ni journal ouvert, cache par jid, nouvel essai toutes les 10 s). Sans total : « N boss ». `RequestRaidInfo` à l'entrée et 2 s après un boss, `UPDATE_INSTANCE_INFO` recalcule. Option `timerBoss` (false = masqué). Le journal peut compter un boss absent d'une difficulté.
- **Difficulté de raid relue en continu** (après 7.6.1, constat en jeu du 15 novembre 2026 : Sépulcre des Fondateurs en Mythique affiché « (N) »). La difficulté n'était lue qu'à `PLAYER_ENTERING_WORLD`. `T.InstCheckDiff()` (Core.lua) la relit à `PLAYER_DIFFICULTY_CHANGED` et à chaque seconde du chronomètre ; si le code change, `T.InstMarkRaid` déplace le temps déjà cumulé vers la nouvelle difficulté. `/lvlh temps` affiche aussi le `difficultyID` brut et son code, pour repérer un identifiant absent de `RAID_DIFF` (repli « N »). Cause exacte non confirmée en jeu (changement sur place supposé).
- **Prochain boss à tuer** (après 7.6.3, Timer.lua) : 3e ligne « Suivant : X » (cadre de 44 à 58 px, horloge et type ancrés au haut du cadre), « Tous les boss sont vaincus » quand le total est atteint. Liste dans l'ordre du Journal (`EJ_GetEncounterInfoByIndex`, 8e retour = `dungeonEncounterID`, le même que `ENCOUNTER_END`), sinon ordre du verrou (`GetSavedInstanceEncounterInfo` : nom, tué). Un boss est tué s'il est dans `db._inst.kills` (identifiant) ou marqué tué dans le verrou (nom localisé). Raid à ailes ou ordre libre : c'est le prochain dans l'ordre du journal. Option `timerNext` (false = masqué), libellés `OPT_TIMER_NEXT`, `TIMER_NEXT_FMT`, `TIMER_NEXT_DONE` en 9 langues.
- **Arrêt au boss de fin et Labyrinthe** (7.6.6, Timer.lua + Core.lua, NON TESTÉ EN JEU) : `db._inst.doneAt` fige l'affichage (horloge verte, plus de tic) ; le temps des onglets n'est pas touché. Fin = dernier boss du journal (`bossCache.lastEnc`) ou tous les boss (revérifié 4 s après le kill), `CHALLENGE_MODE_COMPLETED`, `LFG_COMPLETION_REWARD` en instance, `SCENARIO_COMPLETED` (gouffre, scénario), rencontre finale connue `FINAL_ENC` (3548 = Kindo'jan, lu dans DBM-Delves-Midnight). Labyrinthe : type d'instance réel inconnu ; `T.InstKind` accepte un gouffre actif (`HasActiveDelve` + `C_Scenario.IsInScenario`) hors des types connus, et `T.InstRecheck` ouvre le chrono sur `ZONE_CHANGED_NEW_AREA` / `SCENARIO_UPDATE` si aucun n'est ouvert. Difficulté à côté du nom (`DiffLabel`) : palier (`T.DelveTier`), clé M+, nom de difficulté du jeu, code raid. `/lvlh temps` donne la détection brute.
- Vérifié : syntaxe Lua 5.1 (luaparse), 56 tests fengari (dont 9 sur le prochain boss) ; 47 tests fengari (dont 5 sur le changement de difficulté) ; avant ce correctif, 42 tests fengari sur faux client (dont, pour les boss : total du journal, kill compté une fois, wipe ignoré, verrou prioritaire, option, Classic sans journal, champ de bataille sans compteur). Avant les boss, 32 tests (classement des types, temps écoulé, repaire hors `raidTime` et hors boss de raid, masquage par type, coupure générale, reprise raid et donjon, délai dépassé, sortie vivante, champ de bataille sans reprise). Validé en jeu le 15 novembre 2026 : affichage en donjon et en raid (avant le lot reprise après une mort). À valider en jeu : reprise après une mort, détection M+, Tourment en `scenario`, repaire, clients Classic et Forever.
