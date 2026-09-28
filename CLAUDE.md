# TibiSuite (Unifié) — contexte pour Claude Code

Suite d'addons World of Warcraft de Tibiscui, en **Lua natif** (aucun Ace3, aucun
LibStub externe). Fusion de plusieurs trackers autrefois séparés en une seule
suite modulaire, sans perdre la progression des joueurs.

> Convention d'écriture du projet : français, ton premium et honnête, **jamais de
> tiret cadratin**. Toujours signaler qu'un code n'est pas testé en jeu réel :
> à valider par Tibiscui avec un `/reload`.

## Disposition

Chaque dossier de premier niveau est un **addon WoW autonome** (le dossier donne
son nom au fichier SavedVariables). `TibiSuite/` est le **core**. Modules :
DailyTracker, DgnTracker, LairLens, LegTracker, LvlHistory, MiniHub, Opacity,
PostBox, RenTracker, RepBar, SkillTracker, Stats, WeeklyCompass, XPBar.

- Core : `TibiSuite/Core/TibiSuiteCore.lua`
- Options (cases à cocher) : `TibiSuite/Core/TibiSuiteOptions.lua`
- Socle UI partagé : `TibiSuite/Core/TibiSuiteUI.lua`
- TOC : `## Interface: 120100, 120007, 120005`, `## Version: 6.0`

Un module type contient : `<Nom>.toc`, `Core.lua` (logique + events), `UI.lua`,
`<Nom>_Module.lua` (glue TibiSuite, voir plus bas), une copie du socle sous
`Core/TibiSuiteUI.lua`, des `Locales/`, et parfois `data/`, `Libs/`, `medias/`.

## Règles strictes

1. **Anti-perte de données (absolu).** WoW nomme la sauvegarde d'après le dossier
   de l'addon. Ne JAMAIS renommer un dossier de module, ni regrouper les bases
   sous la SavedVariables du core. Chaque module déclare sa propre
   `## SavedVariables` dans son `.toc`. Le core ne déclare que `TibiSuiteDB`
   (`## SavedVariables`) et `TibiSuiteCharDB` (`## SavedVariablesPerCharacter`).
2. **On ne travaille QUE dans "TibiSuite - Unifié".** Les dépôts autonomes
   (`Documents\GitHub\XPBar`, `RenTracker`, `TibiSuite`, etc.) sont les anciennes
   versions standalone pré-fusion : NE PAS les modifier.
3. **Mode double.** Chaque module marche en suite (LoadOnDemand piloté par le
   core, pas de bouton minimap propre, onglet dans la barre unifiée) ET en addon
   indépendant (même dossier, charge sa copie du socle, crée son propre bouton
   minimap). Détection à l'exécution via `HasCore()` (`_G.TibiSuite.RegisterModule`
   présent). La SavedVariables ne change jamais entre les deux modes. Référence :
   RepBar, Stats.

## SavedVariables par module

Daily=DailyTrackerDB, Dgn=DgnTrackerDB, Leg=LegTrackerDB, Rep=RenTrackerDB,
Lvl=LvlHistoryDB, Weekly=WeeklyCompassDB, MiniHub=MiniHubDB, XPBar=XPBarDB,
Lair=LairLensDB (+LairLensCharDB), Skill=SkillTrackerDB, Stats=StatsDB,
RepBar=RepBarDB, PostBox=PostBoxDB, Opacity=OpacityDB. Core=TibiSuiteDB (+TibiSuiteCharDB).

## Architecture du core (`TibiSuiteCore.lua`)

Deux surfaces d'enregistrement coexistent :

1. **Catalogue statique `MODULES`** (dans le core) : une entrée par module, avec
   `key`, `addonName`, `label`, `frameGlobal`, `mmBtnGlobal`, `toggleFn`,
   `optionsFn`, `col` (couleur d'onglet {r,g,b}), `curseUrl`, `saved` (liste des
   SavedVariables à effacer lors d'une réinstallation), `escClose` (Échap ferme la
   fenêtre). Les éléments permanents (XPBar, RepBar, MiniHub) n'ont pas `escClose`.
2. **`TibiSuite.RegisterModule(spec)`** appelé à l'exécution par chaque
   `<Nom>_Module.lua` : `spec = { key, label, accent={r,g,b}, onOpen=fn,
   onOptions=fn, searchProvider=fn }`. Inscrit l'onglet et (si `searchProvider`)
   le fournisseur de recherche via `UI.RegisterSearch`.

API publique du core (`_G.TibiSuite.*`) : `RegisterModule`, `GetCatalog`,
`IsModuleEnabled(key)`, `SetModuleEnabled(key,on)` (charge immédiatement si coché ;
décocher prend effet au `/reload`), `LoadModule(key)`, `ModuleExists(key)`,
`ReinstallModule(key)` (wipe des SavedVariables du module + reload, jamais
TibiSuiteDB), `ReinstallCore()` (wipe TibiSuiteDB/TibiSuiteCharDB seulement, SV
modules intactes), `SetTabBadge(key,count)`, `SetMinimapBadge(count)`,
`IsCtrlHidden`/`SetCtrlHidden`/`ApplyCtrlVisibility`.

Défaut non destructif : `TibiSuiteDB.enabledModules == nil` => tous les modules
présents sont actifs. Chargement au login : `LoadEnabledModules` via
`C_AddOns.LoadAddOn` sous pcall.

**Activation réelle (depuis 7.1.5.32).** Aucun module n'est LoadOnDemand (mode
double), donc WoW les charge tous. Décocher appelle `C_AddOns.DisableAddOn`
(zéro mémoire après `/reload`), cocher `EnableAddOn` puis `LoadAddOn`
(refusé pour un non-LOD pas en mémoire => état « reload »). La case TibiSuite est
la source de vérité, réappliquée à la liste d'addons à chaque login.
`SetModuleEnabled` renvoie `"loaded" | "reload" | "off" | "absent"` ;
`TibiSuite.pendingReload[key]`, `NeedsReload()`, `Reload()`, `IsEnabledInWoW(name)`.
Autres API ajoutées : `ApplyBarSettings{vertical,scale,cols,rows,corner(1-9),open,
logoSize,locked}`, `GetBarCorner()`, `SetMinimapHidden(bool)`, `ExportProfile()` /
`DecodeProfile(code)` / `ApplyProfile(prof, skipModules)` (codes `TS1:` = Base64
+ djb2, réglages de suite seulement), `RunDoctor()`, `RunPerf()`. Nouvelles clés
`TibiSuiteDB` : `mmHidden`, `loginMsg` ("full"|"one"|"none"), `statsAutoExport`
(lu par `Stats/Core.lua` au `PLAYER_LOGOUT`), `lastSeenVersion`, `wowSyncDone`.
Slash ajoutés : `/ts doctor|perf|profile|setup|news|minimap`.

**Installation (`TibiSuiteOptions.lua`).** Installateur 6 étapes
(`TibiSuite.RunSetup()`, relançable sans rien effacer), fenêtre « Quoi de neuf »
(`ShowWhatsNew`, une fois par version, table `WHATSNEW` indexée par version du
core : **ajouter une entrée à chaque release**, sinon rien ne s'affiche), fenêtre
de profils (`OpenProfileWindow`). L'installateur pose `postBoxEnableMigrated` et
`opacityEnableMigrated` pour que les migrations ponctuelles du core n'écrasent pas
le choix de l'utilisateur. Logos par module : table `MODULE_LOGO`. Un seul bouton minimap + entrée AddonCompartment,
créés uniquement par le core ; les boutons minimap individuels sont masqués.

Slash : `/tibisuite` et `/ts` (sous-commandes dont `/ts modules`). Chaque module
garde aussi son propre slash (ex. `/stats`).

## Socle UI (`TibiSuiteUI.lua`, global `_G.TibiMidnight`, alias `_G.TibiSuiteUI`)

Chargé une seule fois : garde de version `NS_VERSION` (façon LibStub, no-op si une
version égale ou supérieure est déjà chargée). Helpers principaux :

- Palette : `UI.C` (couleurs), `UI.Hex(r,g,b)`.
- Recherche : `UI.Normalize(s)`, `UI.Match(haystack,needle)`,
  `UI.RegisterSearch(key,label,fn)`, `UI.RunGlobalSearch(query)` (entrelace les
  résultats de tous les modules inscrits), `UI.AttachSearch`, `UI.MakeSearchField`,
  `UI.CreateSearchPopup`.
- Fenêtres : `UI.FlatBackdrop`/`UI.Backdrop`, `UI.SetLisere(f,accent)` (liseré
  d'accent en haut), `UI.SkinFrame(f,accent,bg)`, `UI.FitHeight(frame,
  contentHeight,{chrome=,min=,margin=80,apply=true})` (auto-hauteur centralisée),
  `UI.AddHeaderLogo`, `UI.HeaderIcon`, `UI.MakeButton`, `UI.CreateOptionsPanel`.
- En-tête : `UI.AddHeaderControls(frame,cfg)` pose les boutons flottants Options
  (roue) et Recherche (loupe) au coin haut-droit, applique l'état masqué dès la
  création via `_G.TibiSuite.IsCtrlHidden`, et câble Maj+clic droit -> `cfg.onOptions`.
- Personnage : `UI.ClassColor(token)`, `UI.CharBannerText(data)`, `UI.CharBanner`.

## Patron d'un `<Nom>_Module.lua`

```lua
local ADDON, SX = ...
local function HasCore() return _G.TibiSuite and _G.TibiSuite.RegisterModule and true or false end
if HasCore() and IsEnabledByCore() then
  TibiSuite.RegisterModule({ key="Stats", label="Stats", accent=SX.ACCENT,
    onOpen=function() SX.Toggle() end,
    onOptions=function() if SX.OpenOptions then SX.OpenOptions() end end })
end
HideOwnMinimap()  -- masque le bouton minimap propre quand le core est là
SLASH_TIBISTATS1 = "/stats"; SlashCmdList["TIBISTATS"] = function() SX.Toggle() end
```

## Boutons flottants masquables

Cases DANS le panneau d'options de chaque module (deux cases séparées Options /
Recherche), persistées dans `TibiSuiteDB.floatHidden[frameName] = {options=,
search=}`. Frames concernées (Options+Recherche sauf indication) : Daily
`DTMainFrame`, Dgn `DGNMainFrame`, Lvl `LvlHistoryMainFrame`, Weekly
`WeeklyCompassFrame`, Rep `RNTMainFrame`, Lair `LairLensAuditFrame`, Leg
`LegTrackerMainFrame` ; XPBar `XPBarContainer` et RepBar `RepBarContainer`
(Options seul). SkillTracker et MiniHub n'ont pas de boutons flottants.
Le raccourci Maj+clic droit ouvre les options ; il est câblé UNIQUEMENT par le
socle (ne pas le re-câbler dans le core, sinon double-toggle).

## Identité visuelle

Accent de la suite = **rouge de marque `#C41F3B`** = `{0.769, 0.122, 0.231}` (le
violet/lavande d'origine a été purgé, y compris les `|cFF9480FF` des prints). Chaque
module garde sa propre couleur d'accent (`col` dans le catalogue, `accent` au
RegisterModule ; ex. Stats = or `{1,0.843,0}`, Daily = cyan `#16C4FC`). Palette
socle : fond plat sombre, bordure fine quasi noire, séparateurs blancs à 10 %,
liseré d'accent en haut. Défauts d'install (si `TibiSuiteDB.<k> == nil`) :
scale 0.90, grille toggles 2x5, mmAngle 200, locked false, vertical false.

## Pièges connus

- **Taint / Échap (résolu, à respecter).** Ne JAMAIS combiner `UISpecialFrames` +
  hook `OnHide` (contamine `ToggleGameMenu` => popup Blizzard "action réservée à
  l'IU de Blizzard"), ni capter Échap soi-même (`OnKeyDown` +
  `SetPropagateKeyboardInput` : bloqué dès qu'un autre addon réagit aussi à Échap).
  État actuel du core (`WireEscapeFor`) : les fenêtres `escClose` sont seulement
  inscrites dans `UISpecialFrames`, SANS aucun hook ; c'est Blizzard qui ferme.
  Contrepartie assumée : Échap ne referme plus la barre en même temps.
  Ne jamais écrire non plus dans `StaticPopupDialogs` (fenêtres maison
  `TibiSuite.ShowConfirm` / `ShowURL`).
- **Fichier socle refusé en écriture** : si SEUL `TibiSuiteUI.lua` est refusé alors
  que ses voisins passent, c'est l'attribut Windows "Lecture seule" ou un handle
  ouvert, pas Controlled Folder Access.
- Aucun module ne touche de code secure/verrouillé en combat (lecteurs de données
  uniquement) : pas de problème de taint sur les données elles-mêmes.

## Module Opacity (transparence des fenêtres)

Accent bleu glacier `#7FD4E8` = `{0.498, 0.831, 0.910}`, slash `/opacity` et
`/opa`, raccourcis dans `Opacity/Bindings.xml`. Règle centrale : **lire et
multiplier, ne jamais écraser**. Un `hooksecurefunc(frame, "SetAlpha")` mémorise
l'alpha posé par les autres (Blizzard, mode Édition, ElvUI, EllesmereUI) comme
« base », et Opacity affiche `base * facteur`. On n'écrit **jamais** dans le mode
Édition (`C_EditMode`) : taint + conflit avec EllesmereUI qui y écrit déjà.
Frames d'ElvUI / EllesmereUI intouchées sauf case « Forcer ». Frames protégées :
si le client refuse un `SetAlpha` en combat (`ADDON_ACTION_BLOCKED`), file
d'attente jusqu'à `PLAYER_REGEN_ENABLED`. Piège des fondus qui **lisent**
`GetAlpha` à chaque image (fondu « carte en mouvement » de Blizzard) : ils
relisent notre valeur réduite et s'enfoncent vers ~5 %. Une rafale d'écritures
externes fait basculer la frame en mode « children » (facteur appliqué aux
enfants et régions, frame rendue à son propriétaire), sauf types qui dessinent
eux-mêmes (Minimap, EditBox, modèles...). Un seul moteur d'animation
(`Hover.lua`) qui s'endort quand rien ne bouge. Codes de profil `OPA1:` (LZW de
Stats copié dans `Opacity/Libs`, non lu par le site).

## Module PostBox (rétro-ingénierie de Postal, en chantier)

Réécriture de zéro en Lua natif style TibiSuite de l'addon Postal, compatible WoW
12.1 via API natives (`C_Mail`). On part des fonctions de Postal comme cahier des
charges, pas de son code. Défauts : dossier/addon PostBox, `PostBoxDB`, accent vert
émeraude `{0.20, 0.72, 0.55}`, onglet "PostBox". Fonctions à recréer : OpenAll
(ramassage masse, slots libres configurables, filtres AH), Express (Maj/Ctrl/Alt),
Select (cases/plages/par expéditeur), BlackBook (contacts/alts/autocomplétion),
Rake, Forward, CarbonCopy, TradeBlock, DoNotWant, QuickAttach. Tibiscui veut des
options "waouh" génératrices de téléchargements, à proposer AVANT d'intégrer.
Workflow validé : **présenter le PLAN avant d'écrire le code**.

## Vérification

Pas de client WoW ici. Syntaxe en **Lua 5.1** : `luac5.1 -p <fichier>.lua`
(installer : `apt-get install -y lua5.1`, ou `luajit`). Sous Windows sans Lua :
luaparse (copie en cache npx, appelée via node). Tests d'exécution : fengari
(Lua 5.3, entiers 32 bits : `%08x` d'un nombre > 2^31 échoue dans le mock mais
pas en jeu) + faux client WoW, reconstruit par session dans le scratchpad.

## Lien avec le site (Tibiscui.fr)

Le module **Stats** produit un code d'export (`SX.Export.Generate()`,
`Stats/Export.lua` : JSON schema 2, LZW `Stats/Libs/LZW.lua`, Base64, checksum
djb2). Au `PLAYER_LOGOUT` (couvre `/reload` et déconnexion), `Stats/Core.lua`
auto-persiste ce code dans `StatsDB.export`. Un companion PC et un fetcher API,
côté dépôt **Tibiscui.fr**, le consomment pour la page Dashboard-Tibi. Si tu
touches `LZW.lua` ou le format d'export, reporte-le dans
`Tibiscui.fr/dashboard-shared.js` (décodeur miroir bit à bit).
