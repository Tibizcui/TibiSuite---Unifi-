# TibiSuite : modules Opacity, Standby, PostBox, Anchor et ReadyUp

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

## Module ReadyUp (« suis-je prêt ? », 2026-11-14, non testé en jeu)

Accent vert « feu vert » `#4CD964` = `{0.298, 0.851, 0.392}`, clé de module
`ReadyUp`, groupe « À faire » du Panneau vivant. Slash `/readyup` et `/rdy`
(`check`, `on`, `off`, `options`). Slug CurseForge `readyup` libre au
14 novembre 2026, projet à créer (identifiant à reporter dans le `.toc` :
[ID-CURSEFORGE-READYUP]). **Tous les noms globaux portent le préfixe
`TibiReadyUp`** (`TibiReadyUpDB`, `TibiReadyUpMainFrame`, `TibiReadyUpOptions`,
`TibiReadyUpToast`, `TibiReadyUp_Toggle`...). Même règle d'activation que
Standby et Anchor (pas de migration ponctuelle). Multi-versions : `.toc`
principal plus `ReadyUp_Wrath.toc`.

Positionnement (étude de marché du 14 novembre 2026) : assistant personnel
sans configuration. Preflight (listes à construire soi-même) et PrepCheck
(audit de groupe pour le chef de raid) occupent les deux autres créneaux :
pas d'éditeur de listes ni d'audit de groupe dans ReadyUp.

Fichiers : `Core.lua` (sauvegarde, couche de compatibilité `RU.API` : sacs,
améliorations, sorts connus, objets, contexte), `Checks.lua` (les contrôles et
`RU.Evaluate`), `Toast.lua` (moments et alerte), `UI.lua` (fenêtre, options),
`Bridge.lua` (`statusFn`, `overviewFn`, badge d'onglet, recherche,
`TibiReadyUp_DoctorNote`), `ReadyUp_Module.lua` (glue, minicarte, slash).

Contrôles (une case chacun, regroupés Équipement / Consommables / Classe et
inventaire) : usure ; enchantements, renfort d'armure (jambes) et châsses
vides (niveau maximum, raid, donjon mythique, arène ; enchantements et renfort
décochés par défaut, table `ENCHANT_SLOTS` par extension via
`GetClassicExpansionLevel` sinon `GetExpansionLevel`, liste Midnight à
vérifier) ; nourriture et flacon (raid et donjon mythique au niveau maximum,
options donjon normal et gouffre, arène) ; potions dans les sacs (sous-classe
1 ou mot-clé `KW_POTION`) ; enchantement temporaire d'arme (poisons du voleur,
y compris en solo ; expiration sous 10 min) ; améliorations de classe sur soi
(`SELF_BUFFS` : aspects, armures, Feu intérieur, Robustesse, Intelligence des
Arcanes, Marque du fauve, boucliers, auras, Bénédiction du bronze) ; familier ;
flèches ou balles (seulement si `GetInventorySlotInfo("AmmoSlot")` répond) ;
composants Classic (seulement si l'infobulle du sort cite l'objet) ; place
dans les sacs (famille 0, ignorée en champ de bataille et arène).

Contextes (`RU.API.Context`) : `solo`, `delve` (scénario de difficulté 208,
hypothèse), `dungeon`, `keystone`, `raid`, `pvp`, `arena`. Table `RU.WANT`
des contextes par contrôle.

Moments (2026-11-15) : **suivi continu partout** (`onSolo`) : alerte dès qu'un
contrôle franchit son seuil, une fois par problème (de nouveau s'il disparaît
puis revient, ou s'aggrave), tout de suite (familier : 5 s de persistance),
jamais en combat ni en fantôme. Contrôle à chaque changement et toutes les
30 s (ticker). Plus de silence au départ : ce qui ne va pas est annoncé une
fois, 5 s après la connexion (l'option « À la connexion » a été retirée). Rappel
d'un problème qui dure (`remindMin`, 10 min, 0 = jamais) en solo et en
gouffre, via un ticker d'une minute. Entrée en instance (y compris champ de
bataille et arène), `READY_CHECK`, `MERCHANT_SHOW` : ce qui y est montré est
noté comme annoncé. Alerte **vivante** : titre par contexte (« Avant le
raid »), lignes qui passent à « réglé », puis « Tout est réglé » ;
« Prêt pour le donjon » en entrant si tout va bien (`okOnEnter`) ; son
`SOUNDKIT.TELL_MESSAGE` (`sound`). Décoché dans TibiSuite : `/readyup` et la
fenêtre le disent (`MSG_SUITE_OFF`). **Voyant permanent** `TibiReadyUpBeacon`
(`beacon`, position `beaconPos`) tant qu'il reste un problème. **Diagnostic**
`/readyup debug` : état du suivi et journal des 40 dernières décisions
(`RU.Log`, mémoire seulement) ; toute erreur du suivi est attrapée et notée.
Tout est dans `Toast.lua` (aucun nouveau fichier : pas de redémarrage client).

Seuils réglables (section « Seuils des alertes ») : `durWarn` (30 %),
`durCrit` (10 %, rouge), `buffExpireMin` (5 min, nourriture et flacon qui
expirent, 0 = coupé), `potionWarn` (1), `weaponMin` (10 min, 0 = coupé),
`ammoWarn` (200), `reagentWarn` (5), `shardWarn` (3), `bagWarn` (4). Ordre de
priorité à niveau égal (`PRIORITY` dans `Toast.lua`, `RU.MoreUrgent`) :
familier, flèches, arme, amélioration de classe, nourriture, flacon, potions,
usure, composants, enchantements, renfort, châsses, sacs.

Règles : **aucune lecture en combat** (`RU.Evaluate` renvoie nil ; un moment
reçu en combat attend `PLAYER_REGEN_ENABLED`) ; toute valeur secrète ou
lecture impossible donne l'état « inconnu », jamais une alerte. Hypothèses à
vérifier en jeu : nom localisé du sort 19705 ou icône 136000 pour la
nourriture, mots-clés localisés pour flacons, poisons et potions (`KW_FLASK`,
`KW_POISON`, `KW_POTION` dans les Locales), identifiants des améliorations de classe, identifiants de sorts et d'objets des
composants, ligne de composants dans l'infobulle des sorts Classic.

Logo : `medias/Logo.tga` = emblème Tibi Addons décliné en vert #4CD964 (teinte du logo du core recolorée, 128 px, 2026-11-15), pas encore de `.blp`
DXT5 ; `Logo.tga` reste donc dans l'archive (voir `.pkgmeta`).
