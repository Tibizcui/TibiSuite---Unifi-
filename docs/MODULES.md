# TibiSuite : modules Opacity, Standby, PostBox et Anchor

> Extrait de CLAUDE.md, déplacé tel quel (texte non modifié). À lire quand on travaille sur ce sujet.

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

## Module Standby (écran d'absence, depuis 7.1.5.40)

Accent rose aube `#F2789F` = `{0.949, 0.471, 0.624}`, clé de module `Standby`,
slash `/standby` et `/afkscreen` (`test`, `on`, `off`, `probe`). Pas de
migration ponctuelle dans le core : décoché pour les joueurs existants, actif
pour une nouvelle installation (`enabledModules == nil`). `StandbyMainFrame` est
la fenêtre d'options (onglet, `escClose`) ; l'écran lui-même est `StandbyScreen`,
frame **sans parent**, strate FULLSCREEN_DIALOG, calée sur UIParent, pour rester
visible quand UIParent est masquée. Fichiers : `Core.lua` (drapeau Absent,
garde-fous, alertes, journal des messages en mémoire seulement), `Scene.lua`
(UIParent, caméra, CVars, illustrations), `Tiles.lua`, `Sheet.lua` (titre, stats,
équipement de la mise en page Fiche), `Screen.lua`, `UI.lua`,
`Bridge.lua` (`StandbyAPI`, recherche, `Standby_DoctorNote`, sonde).
Règles : jamais d'entrée en combat, sortie à `PLAYER_REGEN_DISABLED` ; **aucune
sortie par Échap captée par nous** (ni UISpecialFrames + OnHide, ni OnKeyDown) :
quand UIParent est masquée, Échap la fait réapparaître côté Blizzard et un
ticker d'une seconde le constate. Les fenêtres Blizzard importantes (menu,
StaticPopup, file prête...) sont scrutées par `IsShown`, sans crochet. Toute
modification (CVars `maxFPS`/`maxFPSBk`/`useMaxFPS*`/`Sound_EnableAmbience`,
rotation `MoveViewLeftStart`, UIParent) est notée dans `StandbyDB.restore`
AVANT d'être faite, rejouée au retour, au logout et au login suivant.
Fond « illustration » : images lues dans le journal des aventures
(`EJ_GetInstanceByIndex`, loreImage puis bgImage), jamais embarquées (droits +
poids). `ADDON_ACTION_BLOCKED` au nom de Standby => `safeMode` (voile au lieu de
masquer UIParent). Chat : valeurs secrètes de Midnight neutralisées par
`issecretvalue` avant toute opération.

## Module PostBox (courrier, inspiré du cahier des charges de Postal)

Lua natif, pas de code de Postal. `PostBoxDB`, clé de module `Post`, accent
**laiton** `{0.72, 0.47, 0.22}` (catalogue du core identique), slash `/pb`.
Fichiers : `PostBox.lua` (cache, moteur, fenêtre, options), `PostBox_BlackBook.lua`
(carnet, autocomplétion, Alt+clic, transfert, envoi multiple, modèles),
`PostBox_Ledger.lua` (journal HV), `PostBox_Alts.lua` (boîte de tous les persos),
`PostBox_Mule.lua` (mule automatique), `PostBox_Stats.lua`, `Locales/` (10 langues,
chargées AVANT `PostBox_Locale.lua` qui porte la base anglaise).
Règles confirmées en jeu : une seule prise serveur à la fois, en-têtes figés tant
que la boîte reste ouverte (lire `GetInboxItemLink` en direct), parcours du dernier
au premier index. **Toute prise passe par `P.OpenAll(opts)`** (keys / categories /
moneyOnly / allowCOD / silent / onDone) ; jamais de boucle synchrone de `Take*`.
L'or ne compte qu'à `PLAYER_MONEY`. Les envois se suivent via `P.OnSendResult`
(MAIL_SEND_SUCCESS / MAIL_FAILED). Workflow validé : **présenter le PLAN avant
d'écrire le code**.


## Module Anchor (déplacer les fenêtres, depuis 7.5.0)

Accent indigo `#6E72F0` = `{0.431, 0.447, 0.941}`, clé de module `Anchor`,
juste après XPBar dans le catalogue et le groupe Interface. Slash `/anchor` et
`/anc` (`loot`, `undo`, `reset`, `probe`, `on`, `off`, `options`). Projet
CurseForge 1795734. Ancien nom de prototype « Nomad », abandonné car un addon
Nomad existe déjà sur CurseForge. **Tous les noms globaux portent le préfixe
`TibiAnchor`** (sauvegarde `TibiAnchorDB`, `TibiAnchorMainFrame`,
`TibiAnchorOptions`, `TibiAnchor_Toggle`...) : « Anchor » est trop générique.
Même règle d'activation que Standby (pas de migration ponctuelle).

Fichiers : `Core.lua` (sauvegarde, dispositions, géométrie, refus des frames
protégées, interdites, à ancrage restreint ou à valeur secrète), `Frames.lua`
(catalogue multi-versions, cohabitation), `Engine.lua` (crochets, glisser,
magnétisme, grille, molette, annulation), `Loot.lua` (mode Placement),
`UI.lua`, `Bridge.lua` (recherche, `/ts doctor`, aperçu, sonde).

Règles : jamais de `SetScript` sur une frame Blizzard (`HookScript`,
`hooksecurefunc` seulement), jamais de clé écrite sur elle (état externe à clés
faibles). Le crochet `SetPoint` ne fait que **noter** la frame : le placement
se fait depuis notre `OnUpdate`, hors de la pile d'appel de Blizzard. Une
colonne gérée (`layoutParent`, lancers de dés en 12.x) est replacée en
post-crochet de son `Layout`, comme EllesmereUI. `SetUserPlaced` est remis tel
qu'on l'a trouvé. Pas de crochet `OnHide` sur les fenêtres Blizzard : la fin
d'un glisser est surveillée par notre calque. Ctrl + molette passe par un
capteur à nous posé sur la fenêtre le temps que Ctrl est tenu.

Positions : `TibiAnchorDB.layouts[disposition][résolution][fenêtre] = {p, x, y,
s}`, disposition `"*"` (compte) ou `Nom-Royaume`, résolution `"2560x1440"`
(`GetPhysicalScreenSize`) ou `"*"`. Ancre choisie par tiers d'écran (coin ou
bord le plus proche) sur UIParent.

Cohabitation : BlizzMove ou MoveAny chargés => Anchor en retrait (option
« Forcer »). Shifter d'EllesmereUI actif (`EllesmereUIDB.shifterEnabled`) =>
ses fenêtres (liste recopiée de `EllesmereUIQoL_Shifter.lua` 9.8.3, **à relire
à chaque mise à jour d'EllesmereUI**) ; `shifterLootUnlock` => lancers de dés
et jet de bonus. ElvUI : `ElvLootFrame` présent => butin, lancers de dés
toujours, `ElvUI_ContainerFrame` => sacs, frame ancrée sur un « Mover » ElvUI.
Limite connue : `PVEFrame` (Recherche de groupe Retail) est protégée, donc non
prise en charge (pas de poignée sécurisée).

Validé en jeu par Tibiscui le 10 novembre 2026. Textes CurseForge :
`_dev/Anchor_CurseForge.md`.
