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
