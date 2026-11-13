# Audit du poids de la suite (2026-11-13, base 7.5.6)

Audit en lecture seule puis lots appliqués en l'absence de Tibiscui, sur sa
demande (« prends les décisions »). Rien n'est commité. Ce qui est marqué
« validé en jeu » l'a été par Tibiscui ; tout le reste est non testé en jeu.

## Mesures de départ (archive livrée estimée, ~8,4 Mo)

| Catégorie | Poids | Part |
|---|---|---|
| Code Lua | 3,4 Mo | 40 % |
| Textures TGA (128x128 RGBA non compressé, 64 Ko chacune) | 2,1 Mo | 25 % |
| Locales | 1,1 Mo | 13 % |
| 16 copies du socle | 1,1 Mo | 13 % |
| Données, 72 `.toc`, bibliothèques | 0,7 Mo | 9 % |

Le poids disque n'est pas le poids en jeu : commentaires, autres langues
(retour anticipé sur `GetLocale()`) et copies du socle (garde `NS_VERSION`)
ne coûtent presque rien en mémoire après le chargement.

## Lots

| Lot | Contenu | État |
|---|---|---|
| 0 | Mesure en jeu (`/ts perf`, taille des SavedVariables) | À faire par Tibiscui : seule base fiable pour chiffrer les gains mémoire |
| 1 | `TibiSuiteIcon.tga` 128 -> 64 px dans les 16 modules (~770 Ko) | Fait, **validé en jeu** (launcher et liste en jeu) |
| 1 bis | 33 textures en BLP2 DXT5 avec mipmaps (encodeur maison en Python, aucun outil téléchargé, relu par le décodeur de Pillow : pire écart 28 dB, moyen ~35 dB) : 1 345 Ko -> 486 Ko. Les `.tga` restent dans le dépôt ; dans le dossier de jeu ils sont renommés `.tga.bak` pour le test | Fait, **en attente du test en jeu**. Après validation : exclure les `.tga` dans les `.pkgmeta` |
| 2 | Fenêtre construite à la première ouverture : DgnTracker, DailyTracker, LegTracker, RenTracker (`EnsureUI`) ; bouton minimap propre créé seulement en autonome | Fait, simulé (fengari). **Validé en jeu** le 2026-11-13 sur les quatre modules (DgnTracker : ouverture, habillage, position conservée, `/dg ara-kara` ouvre la fiche ; Daily, Leg, Ren : fonctionnent) |
| 3 | Core : vérifier la création différée | Vérifié : déjà différée (seules des frames d'événements au chargement). Rien à changer |
| 4 | Sondes hors archive : `TibiSuiteGroupProbe.lua` (marqueurs `#@do-not-package@` dans les 6 `.toc` + `.pkgmeta ignore`), sonde « action bloquée » de `Stats/Constants.lua` (`--@do-not-package@`) | Fait. Syntaxe vérifiée dans la documentation du packager BigWigs (lignes entre marqueurs retirées, marqueurs compris, en .lua et .toc) et simulée localement. Essai à blanc réel possible seulement après commit et push (le workflow lit le dépôt GitHub) |
| 5 | Bouton minimap mutualisé : `UI.MinimapButton` (socle v23, 17 copies), styles « compact » et « tracker » ; 15 modules migrés sur 16 (noms globaux et clés d'angle inchangés), dont LvlHistory (menu au clic droit conservé) et WeeklyCompass (options `radiusPad` et `texCoord` ajoutées au constructeur). MiniHub garde volontairement son bouton LibDBIcon : la bibliothèque lui est indispensable pour regrouper les autres boutons, la migration n'apporterait rien. Bonus : plus d'OnUpdate permanent sur XPBar, RepBar, LairLens, PostBox | Fait le 2026-11-13 à la demande de Tibiscui, simulé (13 modules, aucune régression), non testé en jeu en autonome |
| 6 | Un `.toc` principal (Midnight, Forever, Vanilla, TBC, Cata, Mists) + un `_Wrath.toc` par module multi-versions : 72 -> 28 fichiers. Wrath gardé à part : client 3.4 antérieur aux listes à virgules (10.2.7 / 4.4.0, d'après warcraft.wiki.gg) | Fait le 2026-11-13, non testé sur un client Classic |
| 7 | Micro : Stats (journal de combat sans table par coup), Opacity (plus de closure 20 fois/s) | Fait. SkillTracker laissé tel quel (tables de langue libérées après chargement) |

## Modèle `EnsureUI` (lot 2)

- `BuildUI()` n'est plus appelé à `ADDON_LOADED`. `EnsureUI()` construit la
  fenêtre au premier besoin, restaure position (et taille et options pour
  LegTracker), puis applique l'habillage du socle (`DgnTracker_Decorate`,
  `NS.Decorate`, `LTNS.Decorate`, `RenTracker_Decorate`).
- Toute ouverture passe par `EnsureUI()` ; tout rafraîchissement sur
  événement garde `if mainFrame and mainFrame:IsShown()`.
- L'ouverture automatique au login (`open` de DailyTracker, `autoOpen` de
  LegTracker) construit la fenêtre à ce moment-là, comme avant.
- Les filets `C_Timer.After(..., Decorate)` des `_Module.lua` restent : ils
  sont sans effet si la fenêtre n'existe pas encore.

## Points relevés, non corrigés

- `CLAUDE.md`, règle 3 « LoadOnDemand piloté par le core » contredit
  « Aucun module n'est LoadOnDemand » ; même chose dans `Notes-frFR` de
  `TibiSuite.toc`.
- MiniHub embarque LibStub, LibDBIcon, CallbackHandler et LibDataBroker
  (exception légitime à « aucun LibStub externe », à documenter).
- LegTracker : `RefreshCollection` et `ApplyViewMode` semblaient globales ;
  vérifié ensuite, elles sont déclarées `local` en avance (ligne 1320). Pas
  de fuite, relevé erroné.
- Versions : les CHANGELOG portent « 7.5.7 (non publiée) » ; les `.toc`, les
  chaînes de version, `WHATSNEW` et `site-facts.js` restent en 7.5.6.

## Suites du 2026-11-13

- **Recherche des boss (DgnTracker)** : le fournisseur de recherche lit les
  boss dans le journal d'aventure (`Live.Bosses`, cache par instance), à
  partir de 3 lettres, après les instances, 30 au plus. Clic = fiche de
  l'instance. La fiche affiche aussi les boss quand seul `inst.jid` est connu.
  Premier essai en jeu : aucun boss (`EJ_GetEncounterInfoByIndex(i, jid)`
  vide sans instance sélectionnée). Correctif : `EJ_SelectInstance(jid)`
  puis lecture, palier d'origine remis, jamais journal ouvert. **Validé en
  jeu** le 2026-11-13 (recherche des boss, Les Mortemines, boutons de
  minicarte).
- **Instances absentes** : comparaison de la sonde `/dg probe` de Tibiscui
  (SavedVariables) avec les `jid` des fiches. Ajoutées : Les Mortemines (63),
  Le Donjon d'Ombrecroc (64), Les Cavernes des Lamentations (240), Les
  Profondeurs de Brassenoire (227), Hache-Tripes (230), Les Salles Écarlates
  (311, position relevée), Le Monastère des Pandashan (312, position
  relevée), Le Caveau d'Archavon (753). `jid` ajouté à Antorus (946) et
  Ny'alotha (1180). Positions sans relevé : `approx=true`, zones ajoutées aux
  `scanMaps` pour que le jeu les corrige. **Non ajoutée** : Les Profondeurs de
  Rochenoire (228), entrée inconnue avec certitude ; à relever en jeu.
- **Stats allégé (pistes A, B, C, 2026-11-13, validé en jeu par Tibiscui)**. Relevé
  `/ts perf` : Stats 4,5 Mo sur 17,9 Mo. Sauvegarde 1,23 Mo : code d'export
  414 Ko, journaux 547 Ko (goldLog 3 573 lignes), réputations 214 Ko,
  advProbe 35 Ko.
  - A : `StatsDB.export` vidé à PLAYER_LOGIN (si l'export auto est actif),
    recalculé à PLAYER_LOGOUT comme avant. Risque assumé : si la génération
    échoue à la déconnexion, la sauvegarde n'a plus de code (avant, l'ancien
    restait).
  - B : `SX.AppendGoldEvent` fusionne les entrées d'or de même source à
    moins de 5 min (`SX.GOLD_MERGE_WINDOW`).
  - C : `SX.CompactOldDays` (à la connexion, tous personnages) regroupe, au-
    delà de 60 jours (`SX.COMPACT_AFTER_DAYS`), goldLog par source,
    playtimeLog par activité, repLog et profLog par nom + extension. Sommes
    conservées, format d'entrée identique (addon, Dashboard et Companion
    inchangés, vérifié dans `dashboard-shared.js` : listes, pas de comptage).
    Journaux comptés (quêtes, donjons, raids, gouffres, M+, JcJ) intacts.
  - Simulé sur une copie de la vraie sauvegarde : 0 écart de somme ou de
    compte, idempotent, 257 lignes retirées aujourd'hui (seuil 2026-09-14) ;
    sur tout l'historique les 4 journaux passeraient de 5 860 à 884 lignes.
  - Sauvegarde avant changement : `WTF\...\SavedVariables\Stats.lua.avant-allegement`.
  - Non fait : réputations de bataillon en double (format d'export à changer),
    advProbe (35 Ko, commande d'effacement existante).
- **Parcours des hauts faits de Stats (2026-11-13, validé en jeu par
  Tibiscui : « tout est bon », sans chiffre de mémoire communiqué)**.
  Constat en jeu : Stats 4,7 Mo après /reload, 7 Mo une minute plus tard
  (parcours lancé 30 s après la connexion pour le Conseiller). Changements :
  `KeepTop` ne garde pendant le parcours que les 5 « presque finis » et les
  8 candidats par tag (au lieu de tous les hauts faits à 30 % ou plus) ;
  titres de catégories effacés après `ReadHolidays` ; `metaOf` réduit aux
  candidats affichés après `Rebuild`. Simulé (3 600 hauts faits factices) :
  listes identiques à l'ancien code ; en cas d'égalité de progression, le
  départage peut différer (il était déjà aléatoire). Le parcours prend un peu
  plus d'images (même budget de 5 ms par image).
  - Compactage : `SX.CompactDay` ne copie plus rien quand un jour n'a rien à
    regrouper (évitait des centaines de tables jetées à chaque connexion).
- **Réputations de bataillon de Stats (après la 7.5.7, non testé en jeu)**.
  Mesure : 209 Ko, 1 207 lignes pour 162 factions, 104 présentes chez les 10
  personnages. `SX.SplitWarbandReps` (après chaque collecte) range les
  factions `C_Reputation.IsAccountWideReputation` dans `StatsDB.repWarband`
  (une fois), `SX.StripWarbandFromAlts` nettoie les autres personnages,
  `SX.RepFull` réunit les deux pour l'UI et l'export (format inchangé, dates
  de progression par personnage via `repRecentGain`). Simulé sur une copie
  de la sauvegarde (hypothèse : les 104 communes sont de bataillon) :
  1 207 -> 271 lignes, 0 faction manquante, 0 entrée propre ou résumé
  modifié, idempotent. Sauvegarde : `Stats.lua.avant-reputations`.
- Correctifs de documentation : contradiction LoadOnDemand (CLAUDE.md et
  `Notes` du core), exception MiniHub aux bibliothèques externes.
