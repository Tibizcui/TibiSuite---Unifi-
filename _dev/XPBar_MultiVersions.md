# XPBar sur WoW Forever et Classic (2026-11-08, non testé en jeu)

Un seul addon, un seul code, un seul projet CurseForge. Le client WoW lit le
`.toc` à son suffixe s'il existe, sinon `XPBar.toc`. Tous ont le même contenu,
seule la ligne `## Interface` change.

| Fichier | Jeu | Interface |
|---|---|---|
| `XPBar.toc` | Midnight + WoW Forever | 120105, 120100, 120007, 16001 |
| `XPBar_Vanilla.toc` | Classic Era (et Hardcore, SoD) | 11509, 11508 |
| `XPBar_TBC.toc` | TBC Anniversary | 20506, 20505 |
| `XPBar_Wrath.toc` | Wrath (Titan Reforged, Chine) | 38002, 30405 |
| `XPBar_Cata.toc` | Cataclysm Classic | 40402, 40401 |
| `XPBar_Mists.toc` | Mists Classic | 50504, 50503 |

Sources des numéros : client Forever installé (1.60.1, 16001, comme
EllesmereUI), `.toc` Classic des addons du dossier Retail (DBM, Auctionator...).
Toute modification de la liste de fichiers d'un `.toc` est à reporter dans les
5 autres. Wrath et Cata ajoutés sans aucun client pour les tester.

Sur Classic et Forever, le core TibiSuite ne se charge pas (ses `.toc` ne
déclarent que Midnight) : XPBar y tourne en autonome, avec son bouton minimap.

## Replis dans `XPBar.lua` (choix par présence de la fonction, jamais par version)

- Événements inconnus du client (`MAJOR_FACTION_RENOWN_LEVEL_CHANGED`,
  véhicules) inscrits sous pcall. Sans ça, l'ancien code plantait dès le
  chargement sur Classic (constaté dans le faux client).
- Journal de quêtes : `GetNumQuestLogEntries` + `GetQuestLogTitle` si
  `C_QuestLog.GetInfo` manque. Pas d'XP de récompense en Classic.
- Réputation suivie : `GetWatchedFactionInfo` si `C_Reputation.GetWatchedFactionData` manque.
- Niveau max : `GetMaxPlayerLevel`, puis `GetMaxLevelForPlayerExpansion`, puis `MAX_PLAYER_LEVEL`.
- Barre native : `MainMenuExpBar` et `ReputationWatchBar` ajoutées (alpha et souris).
- Version au login : `GetAddOnMetadata` si `C_AddOns` manque.

## Vérifié ici

- luaparse (Lua 5.1) sur `XPBar.lua` et `XPBar_Module.lua`.
- Faux client fengari, Classic Era et Retail : chargement, login, XP, quêtes,
  réputation au niveau max, masquage de la barre native, infobulle, slash et
  options, logout. 0 erreur ; l'ancien code échoue sur Classic.

## À tester en jeu

Forever (dossier copié dans `_forever_\Interface\AddOns\XPBar`, nouveau
dossier => redémarrage complet du client) :
1. XPBar apparaît dans la liste des addons sans « Périmé », aucune erreur Lua.
2. La barre suit l'XP, l'infobulle s'affiche, `/xpbar` ouvre les options.
3. Bouton minimap propre présent (pas de core sur Forever).
4. Option « masquer la barre XP de Blizzard » : la barre native disparaît et revient.
5. `/dump select(4, GetBuildInfo())` doit répondre 16001.

Retail (XPBar.lua et XPBar.toc copiés, `/reload` suffit) : rien ne doit avoir changé.

Classic (aucun client installé sur ce PC) : mêmes points 1 à 4, plus le compte
des quêtes terminées dans l'infobulle et la réputation au niveau max.

## Publication (après le test)

Monter la version des `.toc` (les 6), remplacer « Prochaine version » dans
`CHANGELOG.md`, dry run du workflow pour XPBar, puis tag. Côté CurseForge,
vérifier que le fichier est coché pour Classic Era, TBC, Mists et Forever.

## RepBar (même schéma, 2026-11-08, non testé en jeu)

`RepBar.toc` (Midnight + Forever) et `RepBar_Vanilla.toc`, `RepBar_TBC.toc`, `RepBar_Wrath.toc`, `RepBar_Cata.toc`,
`RepBar_Mists.toc`. En tête de `RepBar.lua`, copie locale de `C_Reputation`
qui reconstruit les fonctions absentes avec `GetFactionInfo`,
`GetFactionInfoByID`, `SetWatchedFactionIndex`. Barre native Classic :
`ReputationWatchBar`. Sans RenTracker (absent de Classic / Forever), pas de
suivi de faction par zone. Faux client Era : faction suivie lue (« Orgrimmar,
Amical 1500 / 6000 »), 46 clics sur les cases, 0 erreur.

À tester en jeu (Classic Era et Forever, nouveau dossier => redémarrage
complet) : la barre affiche la faction suivie, gain de réputation pris en
compte, clic pour changer de faction suivie, `/repbar`, centrage en bas.

## Stats (lot 1 « en jeu seul », 2026-11-08, non testé en jeu)

`Stats.toc` (Midnight + Forever) et `Stats_Vanilla/TBC/Wrath/Cata/Mists.toc`.
Toutes les inscriptions d'événements sous pcall (l'ancien code s'arrêtait au
chargement sur Classic : `CHALLENGE_MODE_COMPLETED` inconnu) ; le reste des
API Retail était déjà protégé (pcall ou test d'existence). Faux client, les
6 versions : connexion, or, quête, niveau, mort, zone, rencontre, fenêtre
`/stats` (62 clics), survols, export à la déconnexion, 0 erreur.

À tester en jeu (Classic Era et Forever, nouveau dossier => redémarrage
complet) : `/stats` s'ouvre, la journée enregistre or, quêtes, niveau, morts,
donjons ; la session apparaît ; après une déconnexion, `StatsDB.export`
existe dans `WTF\Account\CRJ07\SavedVariables\Stats.lua` du client.
Non couvert : métiers en Classic Era / TBC / Wrath (pas de `GetProfessions`,
il faudrait lire `GetSkillLineInfo`), Dashboard (lot 2).

## Core TibiSuite et MiniHub (2026-11-08, non testé en jeu)

`TibiSuite_*.toc` et `MiniHub_*.toc` (6 chacun). Inscriptions d'événements sous
pcall (Renom, combats de mascottes absents de Classic). Faux client Era et
Retail, core seul : toutes les sous-commandes `/ts`, 12 pages du Centre, 751
clics, 0 erreur ; suite complète (core + XPBar + RepBar + Stats + MiniHub) :
1 141 clics, seule erreur = LibDBIcon dans le faux client (identique sur
Retail, où MiniHub marche en jeu). `C_AddOns` : présent sur Classic (DBM).

À tester en jeu (Classic Era et Forever, nouveaux dossiers => redémarrage
complet) : installateur au 1er lancement, barre (Classique / Dock / Panneau)
avec les 4 modules, bouton minimap unique (les boutons XPBar / RepBar / Stats
doivent s'effacer), Centre (Accueil, Barre et accès, pages des modules),
MiniHub qui range les boutons de la minicarte Classic (MiniMapTracking,
GameTimeFrame...) sans casser la minicarte, `/ts doctor`.

## Opacity, Standby, SkillTracker (2026-11-08, non testé en jeu)

`*_Vanilla/TBC/Wrath/Cata/Mists.toc` (6 chacun), inscriptions sous pcall.
Faux client Era et Retail (connexion, 21 événements courants, toutes les
commandes slash avec 13 arguments, tous les clics, survols, OnUpdate,
déconnexion) : Opacity 286 clics, Standby 66, SkillTracker 112, 0 erreur.
SkillTracker en Classic Era / TBC / Wrath : vue des niveaux de métier vide
(pas de `GetProfessions`), le reste fonctionne.

À tester en jeu : Opacity (cadres Classic différents : vérifier qu'il les
trouve et ne casse rien), Standby (`/standby test` : rotation, interface
masquée puis rendue, illustration absente en Classic Era faute de journal
d'aventure), SkillTracker (récolte, pêche, `/skt peche`, valeur des sacs).

## LvlHistory (2026-11-08, non testé en jeu)

`LvlHistory_*.toc` (6), inscriptions sous pcall (y compris celles suivies
d'un commentaire), repli `MAX_PLAYER_LEVEL` pour `GetMaxPlayerLevel` (appelé
sans garde dans `T.MaxLevel` et l'onglet Alts). Faux client : 7 onglets,
gain d'XP, quête, montée de niveau, rencontre, sortie d'instance, 42 clics,
0 erreur sur les 6 versions ; données enregistrées identiques à Retail
(xpGain, xpSrc.quest, questCount, levelStart).

À tester en jeu (Classic Era et Forever, nouveau dossier => redémarrage
complet) : session de leveling (XP/h, temps restant), onglets Zones, Alts,
Donjons, Raids (Molten Core, etc.), Niveaux ; bouton minimap.

## RenTracker (2026-11-08, non testé en jeu)

`RenTracker_*.toc` (6). Copie locale de `C_Reputation` (même bloc que RepBar ;
`SetWatchedFactionByID` reconstruit renvoie false au lieu d'une erreur, aussi
corrigé dans RepBar). Onglets d'extension filtrés par numéro d'interface
(Era / Forever : Vanilla ; TBC : + TBC ; Wrath : + WotLK ; Mists : jusqu'à MoP ;
Retail : 12), extension sauvegardée ramenée à la première proposée, suivi par
zone ignoré pour une extension absente (identifiants de carte Retail).
Mention « conseils écrits pour le jeu actuel » sur les fiches hors Retail.
Faux client (Era, TBC, Wrath, Mists avec l'ancienne API, Forever, Retail) :
0 erreur, onglets attendus, faction suivie lue (Orgrimmar).

À tester en jeu : onglet Vanilla seul, barres des factions Vanilla (valeurs
réelles), clic pour suivre une faction, suivi auto par zone en Classic
(cartes Classic absentes de la table : rien ne doit basculer à tort).
Plus tard : relecture des fiches Vanilla / TBC pour le Classic (contenu).
