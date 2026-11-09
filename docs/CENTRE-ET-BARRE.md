# TibiSuite : styles de la barre et Centre TibiSuite

> Extrait de CLAUDE.md, déplacé tel quel (texte non modifié). À lire quand on travaille sur ce sujet.

## Styles de la barre (7.1.5.43, Dock et Panneau vivant)

`TibiSuiteDB.barStyle` = `"classic" | "dock" | "panel"`, posé une fois à
`ADDON_LOADED` AVANT le remplissage des défauts : `classic` si `setupDone` ou
`mmAngle` existait déjà (joueur existant), `dock` pour une nouvelle install.
Moteurs dans le core : `Renderers.dock/panel = { Build, Layout, Refresh, Hide }`,
aiguillés par `LayoutBar()` ; le Classique est `LayoutClassic()` (code d'origine).
Les onglets classiques restent toujours construits et tenus à jour par
`UpdateTabHighlights` (ils portent le câblage d'Échap) : ne pas les supprimer.
Icônes = `TibiSuite.MODULE_LOGO` (table déplacée d'Options vers le core),
initiale du module si le dossier est absent. Dock : une rangée ou une colonne
(cols/rows = Classique seulement). Panneau : groupes `PANEL_GROUPS` (À faire,
Progression, Interface en icônes), états urgents en tête, ticker de 30 s
seulement barre affichée. API : `GetBarStyle()`, `SetBarStyle(s)`,
`ApplyBarSettings{style=}`, `RefreshStatus()` (regroupé à 0,5 s),
`FmtDuration(s)`, `FmtGold(copper)`, `/ts bar classic|dock|panel`, clé `st=`
des profils TS1 (ignorée par les anciennes versions).

**Contrat `statusFn`** (champ facultatif de `RegisterModule`) : renvoie
`{ text=, color={r,g,b}, progress=0..1, urgent=bool }` ou nil, appelé sous
pcall par le core. Les textes viennent du core (`TibiSuiteL.ST_*`, FR + EN),
pas des locales des modules. Branché : Daily (`DailyTracker_Status`), Weekly
(`WeeklyCompassAPI.GetStatus`), Post (`PostBox_Status`), Skill
(`SkillTracker_Status`), Rep (`RenTrackerAPI.GetStatus`), Leg
(`LegTracker_Status`), et dans le glue pour Lvl, Stats, Dgn, Lair.
XPBar, RepBar, MiniHub, Opacity, Standby : pas d'état (rangée Interface).

## Centre TibiSuite (`TibiSuite/Core/TibiSuiteCentre.lua`, 7.1.5.42)

Fenêtre unique de réglages façon EllesmereUI (`TibiSuiteCentre`, DIALOG,
UISpecialFrames sans hook, redimensionnable : `TibiSuiteDB.centreW/centreH`).
Barre latérale : Général (Accueil, Barre et accès, Diagnostic, Maintenance) puis
un interrupteur par module (`SetModuleEnabled`). Page d'un module = SON panneau
d'options **ancré** (socle v13) : le Centre appelle `onOptions` /
`<Addon>_OpenOptions`, lit `UI.lastShownPanel`, puis `panel:Dock(page, largeur)`.
Aucun module n'a été modifié pour ça. **Depuis le socle v14**, toute ouverture
flottante d'un panneau de module (roue, Maj+clic droit, clic droit sur l'onglet,
slash) est redirigée vers le Centre : `panel:Show` appelle `UI.PanelRedirect`
(posé par le Centre ; table `PANEL_PAGE` nom du panneau -> page, `_name` =
`cfg.name`), sauf pendant `GrabPanel` (`UI._noRedirect`). Réglage
`TibiSuiteDB.optionsInCentre` (nil = actif, `false` = fenêtres flottantes) dans
Barre et accès ; `TibiSuite.OptionsInCentre()`. Standby est hors table (son
panneau est aussi sa fenêtre principale). Un nouveau module doit être ajouté à
`PANEL_PAGE`, sinon il reste flottant. Maintenance = panneau
`TibiSuiteModulesPanel` (sans les cases des modules, passées dans la barre
latérale). Briques visuelles partagées : `TibiSuite._kit` (fin de
`TibiSuiteOptions.lua`). API : `OpenCentre(page)`, `ToggleCentre()`,
`IsCentreShown()`, `OpenModule(key)`, `RunDoctor(emit)` / `RunPerf(emit)`,
`GetBarPos/SetBarPos`, `IsTabShown/SetTabShown`, `SetAllModulesShown`.
Clic droit (minimap, logo de barre, LDB, AddonCompartment) => Centre. Page
« TibiSuite » dans Options > AddOns (ne referme jamais `SettingsPanel` : taint).

**Ma semaine, palette, fil d'activité (7.1.5.44, non testés en jeu).**
- Accueil du Centre = « Ma semaine » : tuiles reset quotidien / hebdo
  (`C_DateAndTime`) / points urgents, puis une carte par module qui a un
  `statusFn` (groupes `TibiSuite.PANEL_GROUPS`, urgent en tête), accès rapides.
  Core : `TibiSuite.GetModuleStatus(key)`, `TibiSuite.OnStatusChanged(fn)`
  (appelé après chaque `RefreshStatus`, même barre cachée).
- `Core/TibiSuitePalette.lua` : `OpenPalette(q)` / `TogglePalette()` /
  `ClosePalette()`. Commandes + **réglages** (index du socle v14 :
  `panel._items` {kind,label,section,obj}, `panel:Reveal(item)` défile et
  surligne) + contenu (`UI.RunGlobalSearch`). `TibiSuite.PrebuildPanels()`
  (Centre) construit les panneaux des modules chargés sans les afficher. La loupe
  de la barre ouvre la palette ; `/ts k`. Raccourcis : `TibiSuite/Bindings.xml`
  (palette, Centre, Ma semaine, fil, barre), aucune touche par défaut.
- `Core/TibiSuiteActivity.lua` : `TibiSuite.Notify(key, text, {urgent, toast,
  sound, once})`, `GetFeed`, `UnreadCount`, `MarkFeedSeen`, `ClearFeed`,
  `OnFeedChanged`, `IsNotifMuted/SetNotifMuted`. `TibiSuiteDB.feed` (200 max),
  `feedSeen`, `notifToasts/notifSound/notifCombat` (nil = actif), `notifMute`.
  Sources du core : transitions des `statusFn` (devient urgent / atteint 100 %),
  courrier, niveau, Renom, nouvelle semaine (`TibiSuiteCharDB.nextWeeklyReset`).
  Modules branchés (trace seule, `toast=false`) : LegTracker (butin),
  SkillTracker (concentration pleine). Page Centre « Fil d'activité ».
  Nouveaux fichiers => redémarrage complet du client.

**Lots 1 à 6 (7.1.5.44, non testés en jeu, nouveaux fichiers => redémarrage complet).**
- Lot 1 (core) : mode streaming (`TibiSuiteDB.streaming`, `IsStreaming`,
  `SetStreaming`, `SafeName`, `OnDisplayChanged` ; `FmtGold` renvoie `***`,
  nom « Personnage » dans Panneau vivant, Ma semaine, fil). Masquage auto de la
  barre ET des widgets : `autoCombat/autoInstance/autoMount/autoVehicle/autoPet`,
  `autoMode` (nil = estomper, "hide"), `autoFade` (%) ; ne touche jamais
  `barOpen/barCollapsed`. `TibiSuite.GetNextAction()` / `RunNextAction()` (urgent,
  puis 1er « À faire » incomplet, puis plus faible progression), bandeau dans
  Ma semaine. Slash `/ts stream|next`.
- Lot 2 : `Core/TibiSuiteWidgets.lua`, lignes d'état épinglées à l'écran
  (`TibiSuiteDB.widgets[key]={p,x,y}`, `widgetsLocked`, `widgetScale`),
  `PinWidget/ToggleWidget/UnpinAllWidgets/ApplyWidgets/PinnableModules`.
  Maj + clic sur une carte de Ma semaine.
- Socle **v15** : `index()` garde `get/set` des cases et curseurs,
  `UI.RecordUndo(panel,item,snapFn)` appelé avant chaque changement souris
  (muet pendant `Refresh`), `panel:ApplySnapshot(snap)` (cases cochées d'abord :
  gère les cases « radio »), `UI.ApplyReadability{contrast,cvd}` modifie `UI.C`
  sur place.
- `Core/TibiSuiteComfort.lua` (lots 3-6) : `SET_KEYS` = réglages de suite
  photographiés (`CaptureSettings` / `ApplySettings`, rechargement proposé
  jamais forcé). Annuler : `Undo/CanUndo/GetUndoLabel/OnUndoChanged` (30,
  session). Points de restauration `TibiSuiteDB.restorePoints` (8, auto à la
  connexion si changement, avant import TS1 / profil / restauration).
  Lisibilité : `uiScale` (90-130, fenêtres de la suite seulement), `highContrast`,
  `cvd`. Profils auto : `TibiSuiteDB.setups`, `setupRules{char,spec,leveling}`,
  `activeSetup` (mémorisé avant de passer à un autre), priorité spé > perso >
  montée de niveau. Rappels : `remindWeekly` (défaut actif, `remindWeeklyH`=3),
  `remindDaily` (défaut coupé, `remindDailyMin`=60), `remindCal` (C_Calendar,
  15 min avant), `remindNote` + `TibiSuiteCharDB.note`, déjà-vus dans
  `TibiSuiteCharDB.remindFired`. Ajouter toute nouvelle clé de réglage de suite
  à `SET_KEYS`.
- Centre : pages Lisibilité, Rappels, Profils et restauration ; bouton
  Annuler dans le pied. Raccourcis ajoutés : streaming, prochaine action,
  annuler. Slash `/ts undo|restore|display|rappels`.

**Accessibilité widgets et palette (7.1.5.44, non testé en jeu).** Socle **v16**
(curseurs indexés avec `min/max/step`). Page Centre « Widgets » (aperçus via
`TibiSuite.MakeWidgetPreview(parent,key)`, épingler, verrou, taille) ; la section
widgets a quitté Barre et accès. Punaise sur les cartes de Ma semaine.
Clic droit sur un module de la barre (Dock, Panneau, Classique) =>
`TibiSuite.ShowModuleMenu(owner, mod)` (MenuUtil : Ouvrir, Options, Épingler),
repli sur les options si MenuUtil absent. `OnWidgetsChanged(fn)`. Palette :
rubriques non sélectionnables (Prochaine action, Récents, Actions rapides ;
recherche groupée par catégorie), filtres Tout/Commandes/Réglages/Modules/Contenu
(Tab), réglages modifiables sur place (Entrée coche, Gauche/Droite curseur,
Maj+Entrée ouvre le Centre ; enregistrés dans Annuler), icônes par type (éclair,
engrenage, logo). Lot 7 : `TibiSuite.ExportSuite()` / `TibiSuiteDB.weekSnap`,
lus par `Stats/Export.lua` (`chars[k].week`, `data.suite`) ; cartes « Ma semaine »
et « Fil d'activité » du Dashboard (site + copie de Companion).

**Aperçus des modules (7.1.5.45, non testés en jeu).** Contrat facultatif de
`RegisterModule` : `overviewFn()` -> `{ lines = { {text, value, progress,
urgent, color, target} } (5 max), empty, at }` et `openTo(target)` (renvoyer
false = pas su viser, le core ouvre simplement). Core :
`TibiSuite.GetModuleOverview(key, fresh)` (pcall, mémoire 3 s sauf `fresh`),
`HasOverview`, `OpenModuleTo(key, target)`, `AddOverviewToTooltip(tt, key)`
(3 lignes, 1 en combat). Centre : aperçu en haut de la page du module, options
ancrées dans `p.optHost` dessous (pas d'évolution du socle). Infobulles Dock,
Panneau, onglets Classique et widgets. Branchés : WeeklyCompass
(`WeeklyCompassAPI.GetOverview/OpenTab`), RenTracker (`RenTrackerAPI.GetOverview`),
DgnTracker (glue, `DgnTrackerAPI.OpenInstance`), PostBox (`PostBox_Overview`,
`PostBox_OpenAlts`), DailyTracker, SkillTracker, LegTracker (`*_Overview`),
LvlHistory (glue, `LvlHistoryAPI.Open(tab)`), LairLens (glue, `OpenInfo`),
Stats (glue), Opacity (`OP.Overview`), Standby (`SB.Overview`), RepBar (glue).
Textes `TibiSuiteL.OV_*` (FR dans le core, EN dans enUS). Fil d'activité :
resets quotidien et hebdo épinglés en haut (compte à rebours, 30 s).

**Prix des récoltes, lot A (SkillTracker, 7.1.5.45, non testé en jeu).**
`SkillTracker/Gathering.lua` (nouveau fichier => redémarrage complet) :
`ST.Prices.Vendor(id)` (GetItemInfo), `ST.Prices.AH(id)` via Auctionator
(`Auctionator.API.v1.GetAuctionPriceByItemID/GetAuctionAgeByItemID`, appelant
"SkillTracker") ou TSM (`TSM_API.GetCustomPriceValue` dbmarket, dbminbuyout,
dbrecent), réglage `ST.settings.priceSource` (nil = auto, "auctionator", "tsm"),
`Providers/HasProvider/MissingText/StatusText` (invite à installer l'un des
deux). Sonde `/skt probe` (`report`, `clear`) : infobulles de la minicarte et
du monde (texte, propriétaire, `issecretvalue`, `GetTooltipData` type/guid,
objectID tiré du GUID GameObject) dans `SkillTrackerDB.probe`. Section « Prix
des récoltes » dans les options. Lots B (table des nœuds + infobulles) et C
(mémoire des prix sans Auctionator/TSM) à faire après le retour de la sonde.
Résultat de la sonde (2026-10-11) : aucun identifiant de nœud, seulement le
nom ; type 21 = minicarte (plusieurs noms possibles, séparés par des retours),
type 4 = objet du monde (2e ligne = métier). **Lot B fait** : table de départ
FR + EN courte (`SEED`), apprentissage à la récolte (`UNIT_SPELLCAST_SENT`
cible + `LOOT_READY`, butin d'un GameObject, classe 7) dans
`SkillTrackerDB.nodes[langue][nom normalisé]`, l'appris passe devant la table ;
`TooltipDataProcessor.AddTooltipPostCall` types 4 et 21 ; réglages
`priceMinimap/priceWorld/priceLearn` ; `ST.NodeItems`, `ST.ForgetNodes`.
**Session de récolte (feuille de route lot 1, non testée en jeu)** : même
butin que l'apprentissage, `SkillTrackerDB.farm = { cur, sessions (20), total }`,
fin après 10 min sans récolte ou `/skt farm`, `ST.FarmActive/FarmToggle/
FarmClose/ItemsValue/UnitPrice` (valeur au prix du moment, HV sinon vendeur),
vue « Récolte » (`metierView = "farm"`, `farmScope cur|hist|all`, `farmSort
name|qty|value|ext`, `farmExtFilter`), la ligne d'état passe à la session
pendant le farm (`TibiSuiteL.ST_FARM_FMT`), `SkillTracker_OpenView(v)` pour
`openTo`. Comptage limité aux sous-classes 4, 7, 9, 10 (gemmes, métaux,
plantes, éléments) ; po/h seulement après 5 min (`ST.FarmRate`).
**Valeur des sacs et banques (lot 2, non testé en jeu)** :
`SkillTrackerDB.wealth = { chars[Nom-Royaume] = { class, bags, bank },
warband }`, relevés `{ at, items, bound }` (sacs à `BAG_UPDATE_DELAYED`,
banques à `BANKFRAME_OPENED`, onglets `Enum.BagIndex.CharacterBankTab_*` /
`AccountBankTab_*`), `ST.SnapValue` (vendable HV sinon vendeur, lié au
vendeur), `ST.WealthTop`, vue « Valeur » (`metierView = "wealth"`).
Piège Lua rencontré : `local a, b = x and f()` ne garde que la 1re valeur.
**Pêche (lots 1 et 2, idées de Fishing Buddy, validés en jeu le 2026-10-18)** :
`SkillTracker/Fishing.lua` (nouveau fichier => redémarrage complet), code
réécrit (Fishing Buddy est sous CC BY-NC-SA : ne rien copier). Prise =
`LOOT_READY` avec `IsFishingLoot()`, sinon butin dans les 35 s d'un
`UNIT_SPELLCAST_CHANNEL_START` de Pêche (131474 ou même nom de sort), tous
objets comptés. `SkillTrackerDB.fish = { cur, sessions (20), total, spots[langue]
["Zone · Sous-zone"] = {n, at, items} }`, même forme que `farm` (`nodes` = prises)
pour réutiliser `FarmDuration/FarmRate/FarmTopZone` ; vue « Pêche »
(`metierView = "fish"`, `fishScope cur|hist|all|spots`, rendu `renderFarm(kind)`
partagé avec Récolte via `FARM_SRC`), `/skt peche`, `openTo("fish")`, ligne
d'état `TibiSuiteL.ST_FISH_FMT/ST_FISH_RATE_FMT` (la session la plus récente
entre récolte et pêche). Lot 2 : sons de pêche (`fishSound`, défaut coupé,
`fishSoundBG`) et clic pour se déplacer coupé (`fishNoCTM`), CVars notées dans
`SkillTrackerDB.fishRestore` AVANT changement, remises après 90 s sans relancer,
au combat, au logout et au login. Sonde `/skt peche sonde` (`clear`), trace dans
`SkillTrackerDB.fishProbe` ; dédoublonnage du butin par le temps (1 s, LOOT_READY
puis LOOT_OPENED), plus de garde LOOT_CLOSED. Liste d'objets de Récolte / Pêche
en tableau (carte de synthèse, en-tête de tri, `placeItemRow`, pools `item/card/sort`).
**Récolte au niveau de la pêche (validé en jeu le 2026-10-18)** : Dépeçage =
sort reconnu dans `UNIT_SPELLCAST_SENT` (4e argument, 8613 / 194174 ou nom
contenant celui de 8613, `ST.IsSkinningSpell`), butin d'une `Creature` limité
aux marchandises sous-classe 6 (`ST.IsSkinItem`), `FarmRecord(qty, "skin")`,
jamais appris comme nœud, gardé par `FarmCleanup`. `SkillTrackerDB.farm.spots`
et `.zoneStats` par langue (zone seule), vues Lieux et Zones de Récolte via
`FARM_SRC.spotList/zoneList/forgetSpots/forgetZones`, réglage `farmSpots`.
Temps par métier : `TIME_PROFS` mining, herb, skin, fish (`SkillTrackerDB.ftime`,
vue Or > Temps). L'overlay (`FishOverlay.lua`) suit la session la plus récente,
pêche ou récolte (`curKind`, titre = métier, pause 180 s en récolte), réglage
`farmOverlay` (nil = actif) ; infobulle de prix au survol collée à 2 px.
Pas de lancer au double-clic (code sécurisé)
ni de tenue (canne en emplacement de métier). `WHATSNEW["7.1.5.51"]`.
**Objectifs personnels (lot 3, non testés en jeu)** : `TibiSuiteDB.goals`
(`id, text, kind manual|gather|gold|module, target, item, module, weekly,
done/doneWeek, notified`), `TibiSuite.GetGoals/AddGoal/RemoveGoal/ToggleGoal/
GoalProgress/CheckGoals/OnGoalsChanged`, semaine = heure du prochain reset
(`GoalWeekId`). Sources : `SkillTracker_GatheredSince(since, itemID)`,
`Stats_WeeklyNet()` (compte), `GetModuleStatus(key).progress`. Centre : page
« Objectifs », groupe « MES OBJECTIFS » en tête de Ma semaine, prochaine action
(score 150 + rang, après l'urgent et le « À faire »), fil d'activité à
l'atteinte. Export `data.suite.goals` + bloc « Mes objectifs » du Dashboard
(site et Companion).
**Plafonds et événement (lot 4, non testés en jeu)** :
`WeeklyCompassAPI.GetCurrencyCaps()` sur `ns.SheetCurrencies` (near = stock ≥
90 % du plafond, urgent dans la ligne d'état ; capped = plafond de saison
atteint, `useTotalEarnedForMaxQty` ; room = reste à gagner), lignes dans
l'aperçu. `TibiSuite.GetWeekEvents()` (calendrier, type HOLIDAY, 2 au plus,
mémoire 60 s), 4e tuile « Événement de la semaine » de Ma semaine.
**Mythique+ (lot 5, non testé en jeu)** : `ns.CollectMPlus()` (WeeklyCompass,
`Data/Activities/Sheet.lua`) = cote, meilleure clé par donjon de la saison
(`GetSeasonBestForMap`, dans les temps ou non), meilleure clé et nombre de
courses de la semaine (`GetRunHistory`), clé en poche ; stocké dans la fiche
(`sheet.mplus`), section « Mythique+ » de la fiche, ligne dans l'aperçu.
Sonde `/wc mplus` (`WeeklyCompassDB.mplusProbe`).
**Hauts faits et session (lot 6, Stats, non testés en jeu)** :
`SX.ScanAchievements/NearAchievements` (parcours une catégorie par image,
≥ 80 %, 5 gardés, mémoire 10 min, hors guilde, statistiques et 0 point),
`SX.OpenAchievement`. Session : `rec.liveSession` dans l'entrée du personnage
(jamais une clé de premier niveau de StatsDB : elle serait prise pour un
personnage), reload < 5 min = même session, bilan de la précédente (≥ 10 min)
dans le fil à la connexion, `rec.lastSession`, `SX.SessionNow/SessionText`.
3e rangée de tuiles de Stats (« Hauts faits », « Session ») avec détails. Les 6 tuiles du bas sont
des cartes histogrammes (même taille et grille que les cartes du haut, 1re
rangée à côté de la dernière carte) : métriques `delveBest`, `repFactions`,
`profCount`, `achPoints` (`d.achPoints`, ACHIEVEMENT_EARNED) et `sessions`
(`d.sessions/sessionTime` écrits à la clôture, session en cours comptée par
`SX.Aggregate`), `SX.HistorySince` (`rec.histSince`). **Depuis, vue d'ensemble = tableau de
bord (piste A)** : `BuildKPI` = 12 tuiles chiffrées en 3 rangées (`KPI_ROWS`
Activité / Contenu / Progression, `KPI_DEF` key -> metric, hist, tile) avec
mini-courbe, évolution « à date égale » (période en cours jusqu'à maintenant
contre la même durée de la précédente), tuile vide estompée ; clic =
`view.focus`, un seul grand graphique dessous (Historique = vue détail
existante, Tableau détaillé = `view.summaryExpanded`). Les anciennes cartes /
tuiles ne s'affichent plus en vue d'ensemble. `SX.KpiTiles()` = accès de test.
DgnTracker : taux de drop estimés des montures (`RATES` par mountID dans
Collections.lua, `C.Rate`, sources missingmounts/Wowhead relevées le 2026-10-12,
rien d'affiché si non documenté).
**Rares et boss mondiaux (lot 7, DailyTracker, non testés en jeu)** :
`DailyTracker/Rares.lua` (nouveau fichier => redémarrage complet), `NS.Rares`.
Sonde `/dt probe` (report, off, clear) dans `DailyTracker_Suite.lua`. Rares
appris au kill (cible rare/rareelite morte, différence de
`GetAllCompletedQuestIDs` 3 s après ou au butin, 6 quêtes max sinon bruit) :
`DailyTrackerDB.rares[npcID] = {name,map,x,y,q={[qid]=true|"rep"},kills}` ;
« rep » = quête vue redevenir à faire (`chars[k].rareQ`), seules les « rep »
comptent dès qu'il y en a une. Vignettes `VignetteKill*` (pas de quête de
récompense). Boss mondial = quête du monde tagID 289 / worldQuestType 18 sur
les cartes de Midnight, mémorisée pour la semaine (`DailyTrackerDB.wb`,
`chars[k].wb`), liste du journal (`EJBosses`) ; le type 289 couvre aussi les Repaires : `R.KindOf(title)` = "wb" si le titre contient un nom du journal, sinon "lair" (rubrique à part, hors compteurs). Vue « Rares » (`view="rares"`,
`/dt rares`, `DailyTracker_OpenRares`, `openTo("rares")`), « Boss x/y » dans
Personnages, lignes d'aperçu `OV_DAILY_WB/RARES`, alerte au fil
(`rareAlert`, `rareToast`, nil = actif). **Collections (lot 8, DgnTracker, non testées en jeu)** :
`DgnTracker/Collections.lua` (nouveau fichier => redémarrage complet),
`DgnTrackerColl`. Catalogue construit à la 1re ouverture de la vue, une fois
par version du jeu + langue (`DgnTrackerDB.coll = {build, locale, inst[jid] =
{name, tier, tierName, raid, map, items[itemID] = {k, n, ic, m, s, e, en, d}}}`) :
journal d'aventure tous paliers, objets à slot vide seulement, chargement
`C_Item.RequestLoadItemDataByID` + `ITEM_DATA_LOAD_RESULT` (pas
GET_ITEM_INFO_RECEIVED) puis classement mount/pet/toy. État en direct :
`owned`, `tw` (24/33 seulement), `done` (boss tué dans toutes les difficultés,
`GetSavedInstanceEncounterInfo` par nom de boss, carte = 10e retour
d'`EJ_GetInstanceInfo` = 14e de `GetSavedInstanceInfo`), `avail`. Vue
virtuelle `Coll` (`/dg collections`, `rebuild`, `DgnTracker_OpenView`,
`openTo("coll")`), lignes d'aperçu `OV_DGN_COLL*`, fil à NEW_MOUNT/PET/TOY_ADDED.
Sonde `/dg loot` (+ report) dans Live.lua. Récap hebdo de DailyTracker en
notification flottante à la vraie connexion (`NS.initialLogin`) ; PostBox ne
rouvre plus une fenêtre ouverte par la boîte aux lettres (`openByMail`).
Croix de fermeture ajoutée à
`PostBoxMainFrame` (les autres fenêtres en avaient déjà une). Maj + clic droit sur un
module de la barre = options directes (clic droit = menu).

**Conseiller (lots 0-2, prochaine version, non testés en jeu).** Plan dans
`_dev/Conseiller.md`. Contrat facultatif `suggestFn()` -> liste, pending
(`{ id, kind, text, tag, proximity, done, total, endsAt, group, note, open |
target }`). Core (fin de `TibiSuiteComfort.lua`) : `GetSuggestions(n, fresh)`
(note `100 * prox^1.5 * (0.4 + affinité) * fenêtre * groupe * poids`, 2 au plus
par tag, mémoire 5 min), `GetAffinity` (lit `Stats_Affinity(28)`),
`DismissSuggestion(id, jours)`, `RestoreSuggestions`, `OpenSuggestion`,
`InvalidateSuggestions`, `OnSuggestionsChanged`, `/ts conseil [all|reset]`.
Réglages `sugOn/sugHabits/sugNoGroup/sugKinds` (SET_KEYS), données
`sugDismissed`. Stats : un seul parcours budgété (5 ms par image, reprise dans
la catégorie, jamais en combat, complet toutes les 30 min, mise à jour ciblée à
ACHIEVEMENT_EARNED / CRITERIA_UPDATE) sert `NearAchievements` et
`SX.AdvisorSuggestions` ; tables d'ID racine -> tag et sous-catégorie ->
extension relevées par la sonde `/stats probe adv`. Exclus : Tours de force,
Héritage, Personnages, Logis ; 15301 Contenu d'extension = tag `feature`. Métas : on propose les enfants (note « Fait
partie de »), chaînes : seule la première étape pas finie, événements : seulement
en cours (enfants de 155 dont le titre est dans celui du calendrier). **Lot 3** (non testé en jeu) : champ `why` du contrat (raison du module). Fournisseurs : DgnTracker `DgnTrackerColl.Suggestions` (montures faisables, poids 0,75), DailyTracker `DailyTracker_Suggest` (boss mondiaux, rares de la zone), RenTracker `RenTrackerAPI.GetSuggestions` (factions à 50 % ou plus), WeeklyCompass `WeeklyCompassAPI.GetSuggestions` (prochain seuil du Grand coffre). **Lot 4** (non testé en jeu) : rubrique SUGGESTIONS de Ma semaine, page Centre `suggest` (panneau socle `TibiSuiteCentreSuggest`), `TibiSuite.ShowSuggestionMenu`, suggestion dans `GetNextAction` (score 180, `na.suggestion`), rubrique de la palette, `WHATSNEW["7.1.5.49"]`. Diagnostic : `Stats_AdvisorState()` (avancement, pause en combat, dernière erreur), affiché par `/ts conseil`. **Fenêtre des propositions** (`Core/TibiSuiteAdvisor.lua`, non testée en jeu) : `TibiSuite.ShowAdvisor(force)` / `ToggleAdvisor()`, 5 cartes, infobulle `AddSuggestionTooltip` (champ `steps()` du contrat : `{ {text, done, value} }`, branché dans les 5 fournisseurs), à la vraie connexion (pas /reload) une fois l'analyse finie, hors combat et instance, `TibiSuiteDB.advPopup` (nil = actif). Raccourci `TIBISUITE_ADVISOR` + capture dans Centre > Suggestions (`AddAdvisorKeyRow`, `SetAdvisorKey`).

**Légendaire épinglé (LegTracker, lots 1-3, non testés en jeu).** Plan
`_dev/LegOverlay.md`. `LegTracker.lua` passe à `local ADDON, NS = ...` et
expose ses fonctions en fin de fichier (`NS.Scan`, `TrackerCount`, `FindItem`,
`SelectItem`, `Owned`...). `LegFarm.lua` (nouveau) : une épingle par perso
(`LegTrackerDB.pin["Nom-Royaume"]`), séance de farm dans un raid de
`item.raids` ou la zone de la quête en cours (quête dans le journal, hors
`IsResting`), fermée après 5 min hors raid / 10 min hors zone, pause `/afk`,
boss par `ENCOUNTER_END`, gains = hausses des compteurs (`cur.seen`, recalés à
la banque et à la connexion), `LegTrackerDB.farm[perso][itemID] = { total,
runs, nSess, sessions (10), perRun, doneAt, cur }`, estimation après 2
passages (`NS.Estimate`), fin à l'obtention (hook `NS.OnLegendaryCheck` dans
`CheckLoot`). `LegOverlay.lua` (nouveau) : fenêtre `LegTrackerOverlay`,
réglages `overlay/overlayAuto/overlayCompact/overlayFade/overlayScale/
overlayAlpha/overlayPos`. Punaise du panneau détail, clic droit sur une ligne,
`/lt pin|pin off|farm|overlay`. Suite : `NS.PinStatus` (ligne d'état,
`ST_LEG_PIN_FMT`), ligne `OV_LEG_PIN` en tête de l'aperçu, `openTo("pin")`,
`LegTracker_Suggest` (kind `legendary`, ajouté à `SUG_KINDS` du Centre,
`SUG_L_FMT`), fil d'activité en fin de séance et à l'obtention,
`WHATSNEW["7.1.5.54"]`. **Farm de pêche (Pêcheur de Terradiance)** : champ
de données `farm = { maps = {619}, fishing = true, label }` (séance de type
`fish` sur ces cartes ou leurs sous-cartes, seulement avec un lancer de Pêche
131474 / même nom de sort ou une prise `IsFishingLoot` de moins de 90 s, fermée
après 10 min ; une séance de pêche compte comme un passage pour l'estimation).
Nouveau type de composant `{ achievementID, need }` = critères faits du haut
fait (`CountAchievementCriteria`, infobulle des critères manquants, contrôlé
par `/lt verify`), gains sur `CRITERIA_UPDATE` / `ACHIEVEMENT_EARNED`.
Tant qu'un haut fait composant n'est pas fini, le survol de sa ligne dans l'overlay liste ses critères
manquants en infobulle (`NS.CriteriaList`, zone `r.hit` qui renvoie clics et glisser à l'overlay),
réglage `overlayCriteria` (nil = actif).

**Lot 7.3 (plan `_dev/Plan_7.3.md`, non testé en jeu, 6 nouveaux fichiers => redémarrage complet).**
- Chat : en suite, SEUL le core annonce la connexion (nombre de modules,
  commandes de `MODULE_SLASH` en mode `full`) ; un module ne `print` sa ligne
  qu'en autonome (`not HasCore()`), quel que soit `loginMsg`. Alertes qui ont
  une entrée dans le fil : fil seulement en suite.
- `Core/TibiSuitePlanner.lua` : `PlanSession/StartSession/StopSession/
  GetSession/ShowSessionWindow`, `TibiSuiteCharDB.session/sessionLast`,
  `TibiSuiteDB.estLearn`, champ facultatif `est` (minutes) des contrats,
  `/ts temps [min]`, raccourci `TIBISUITE_PLANNER`.
- `TibiSuite.RegisterCentrePage{id,label,desc,after,build,refresh}` (Centre),
  `TibiSuite.GetCentreAnchor(id)`.
- `Core/TibiSuiteWorth.lua` : page `worth`, `GetWorth`, `ExportWorth`,
  `TibiSuiteDB.worthHist[AAAAMMJJ]={g,i}` (120 j). Lit
  `WeeklyCompassAPI.GetGold`, `SkillTracker_WealthSummary/WealthTop/
  FarmValueSince`, `Stats_GoldSources`. `/ts patrimoine`.
- `Core/TibiSuiteRecap.lua` : `FreezeWeek` (10 min, logout, changement
  d'état), `TibiSuiteDB.weekRecap[wid]` (8), `recapSeen`, `weekRecapPopup`,
  `ShowRecap`, `ExportRecap`, `Stats_Summary(from,to)`. `/ts bilan`.
  `ExportSuite` porte `worth` et `recap`.
- WeeklyCompass : `WeeklyCompassAPI.GetMPlusRoster()`, `UI/MPlus.lua`
  (onglet « Mythique+ » = action, `/wc cles`, `OpenTab("mplus")`),
  suggestions `kind = "mplus"` (ajouté à `SUG_KINDS`).
- `Core/TibiSuiteTour.lua` : `StartTour/StopTour`, `TibiSuiteDB.tourDone`,
  `/ts visite`. `Core/TibiSuiteGroupProbe.lua` : `/ts sonde groupe`
  (préfixe `TibiSuiteGP`, `TibiSuiteDB.groupProbe`).
- `Core/TibiSuiteGroup.lua` : partage en groupe, coupé par défaut
  (`TibiSuiteDB.groupShare`, SET_KEYS). Préfixe `TibiSuiteG`, messages
  `G1:L|M|P|Q|X`. Sonde : code 11 pendant une rencontre, donc rien ne part
  tant que `InChatMessagingLockdown()` ou combat, file (un message par type)
  vidée à `ENCOUNTER_END` / `PLAYER_REGEN_ENABLED`. Pairs en mémoire
  seulement. Lit `LegTracker_PinnedItemID`, `DgnTracker_MissingMountsHere`.
  Fenêtre `TibiSuiteGroup`, `/ts groupe`, bouton « Groupe » de Ma semaine.
  Partage validé en jeu par Tibiscui le 2026-10-20.

**Menu Échap (validé en jeu, y compris en combat).** `GameMenuFrame:AddButton`
dans un post-hook de `InitButtons` posé **au chargement du fichier**, donc avant
ceux d'EllesmereUI/ElvUI : leur passe d'habillage stylise notre bouton toute
seule. Placement sous EllesmereUI (sinon sous Boutique) par un post-hook de
`Layout` posé au premier `PLAYER_ENTERING_WORLD` + 1 s (après les leurs),
hors combat, rien avec ElvUI. Case `TibiSuiteDB.gameMenuEntry` (nil = actif ;
attention au piège Lua `x and false or nil` qui vaut toujours nil).

