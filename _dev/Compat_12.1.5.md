# TibiSuite face à la mise à jour 12.1.5 « La Promesse de demain »

Analyse du 2026-10-14, faite sur le dépôt (commit 492f885, 7.1.5.46), sans
client WoW. Rien de ce qui suit n'a été vérifié en jeu : à valider par
Tibiscui avec un `/reload`.

Sources :
- Annonce officielle (FR) : https://worldofwarcraft.blizzard.com/fr-fr/news/24307306
- Notes de mise à jour (EN) : https://worldofwarcraft.blizzard.com/en-us/news/24304162
- Changements d'API : https://warcraft.wiki.gg/wiki/Patch_12.1.5/API_changes

## Verdict

**Pas compatible en l'état, mais presque.** Deux points bloquants, faciles à
corriger. Le reste du code a déjà été écrit défensivement (`C_Item.*` en
priorité, global en secours sous garde) et passe sans changement.

| Gravité | Sujet | Addons |
|---|---|---|
| Bloquant | TOC `120105` absent : les 16 addons sont « obsolètes » | tous |
| Bloquant | `GetCoinTextureString` supprimé, appelé sans garde | PostBox |
| Contenu | Nouveau raid, Labyrinthe, plafonds levés, invasion Aqir | DgnTracker, WeeklyCompass, DailyTracker, LairLens, Stats |
| Visuel | Coordonnées sous la minicarte | MiniHub |
| Aucun impact | Auras, PvP Training Grounds, DamageMeter, arène, Cooldown | aucun module ne les utilise |

## 1. Bloquant : numéro d'interface

La 12.1.5 passe en `## Interface: 120105`. Nos `.toc` déclarent au mieux
`120100`. Résultat : WoW marque les 16 addons « Obsolète » et ne les charge
que si le joueur coche « Charger les addons obsolètes ».

Cas particuliers relevés :
- `LairLens/LairLens.toc` : `120100` seul.
- `WeeklyCompass/WeeklyCompass.toc` : `120007, 120100` (sans 120005).
- `LvlHistory`, `MiniHub` : ordre inversé (sans effet).

**Correctif :** passer les 16 `.toc` à `## Interface: 120105, 120100, 120007`
(on garde 120100 pour qui n'aurait pas encore patché, on peut retirer 120005).

## 2. ~~Bloquant~~ Démenti en jeu : `GetCoinTextureString` (PostBox)

**Test du 2026-10-14 :** `GetCoinTextureString` et
`C_CurrencyInfo.GetCoinTextureString` renvoient la même fonction. Le global
existe donc toujours, en alias : PostBox ne cassait pas. Le passage par
`C_CurrencyInfo` est gardé en 7.1.5.47 par prudence.

La 12.1.5 supprime les 11 addons `Blizzard_Deprecated*`, donc tous les
anciens globaux qu'ils maintenaient, dont `GetCoinTextureString`,
`GetItemInfo`, `GetItemCount`, `GetItemIcon`, `GetDetailedItemLevelInfo`...

Appels **sans garde** (erreur Lua `attempt to call a nil value`) :
- `PostBox/PostBox.lua:47` : `local function Coin(c)` utilisée 12 fois dans
  le fichier, plus `P.Coin` dans `PostBox_Alts.lua` (4) et
  `PostBox_Ledger.lua`. La fenêtre de courrier, la boîte des persos et le
  journal HV tombent dès qu'un montant s'affiche.
- `PostBox/PostBox_Stats.lua:148, 149, 162 à 168, 173, 189` : page Statistiques.

**Correctif :** un seul helper dans `PostBox.lua`
(`C_CurrencyInfo.GetCoinTextureString` en priorité, global en secours,
format texte en dernier recours) et faire passer `PostBox_Stats.lua` par
`P.Coin`. À contrôler en jeu avant d'écrire :
`/run print(GetCoinTextureString, C_CurrencyInfo.GetCoinTextureString)`.

## 3. Déjà protégé (rien à faire, simple contrôle)

Ces appels testent l'existence de la fonction ou passent d'abord par `C_Item` :

| Fichier | Appel | Comportement 12.1.5 |
|---|---|---|
| `SkillTracker/Gathering.lua:57, 369` et `UI.lua:998` | `C_Item.GetItemInfo(Instant)` sinon global | OK |
| `SkillTracker/Gathering.lua:116` | `GetCoinTextureString` si présent | repli texte « x po yy pa » : **moins joli**, à basculer sur le helper `C_CurrencyInfo` |
| `RenTracker/RenTracker.lua:2097` | `C_Item.GetItemCount` sinon global | OK |
| `LegTracker/LegTracker.lua:211` | `C_Item.GetItemCount` sinon global | OK |
| `WeeklyCompass/Data/Activities/GreatVault.lua:106, 112` | `C_Item.*` sinon global | OK |
| `DgnTracker/Collections.lua:437, 539` | `C_Item.*` en premier, global sous garde | OK (le repli devient nil) |
| `PostBox/PostBox.lua:1266`, `PostBox_Mule.lua:49` | global sous garde | OK, mais lien/icône éventuellement vide : passer sur `C_Item` |
| Socle v16 (16 copies), ligne 137/145 | `UnitCastingInfo("player")` | OK : minuscules, la casse compte désormais |
| `Standby/Screen.lua:388` | `GetMoneyString` sous pcall | OK |

Les aides FrameXML retirées (`Round`, `Clamp`, `tContains`, `CountTable`...)
deviennent des fonctions natives du client : toujours présentes.
Seul `StringContains` disparaît, et nous ne l'utilisons pas.

## 4. API modifiées que nous n'utilisons pas

Recherche faite sur tout le dépôt (hors `Libs/` et `.claude/worktrees`) :
- AuraButton (`AddDispelTypeTexture`, `AddPandemicRegion`) : absent.
- `C_PvP.GetRandomTrainingGroundRewards` / `HasRandomTrainingGroundWinToday`
  / `JoinRandomTrainingGroundBattleground` (supprimés) : absent de Stats.
- `C_DamageMeter` (sourceGUID secret), `GetArenaOpponentSpec` (secret) : absent.
- `Cooldown:SetCooldown` sur frame protégée : absent.
- `C_TableUtil.FindIndexedMismatch` : absent.
- Onglets de chat sans `UIFrameFlash` : absent.

## 5. Contenu à intégrer (non bloquant, fonctionne mais incomplet)

1. **DgnTracker** (`data/Midnight.lua`, `data/Access_*.lua`) : ajouter le raid
   à boss unique « Le Déliement de Kith'ix » (histoire, normal, héroïque,
   mythique flexible 15 à 25) et le « Labyrinthe de Kindo'jan » (bois des
   Chants éternels, nord du passage des Amani, ou débarcadère de Tokka). Le
   `jid`, la `mapID` et les coordonnées viennent de la sonde en jeu.
   Collections : le catalogue se reconstruit tout seul (clé `build`), vérifier
   qu'il intègre le nouveau raid.
2. **WeeklyCompass** : plafonds d'écus levés la semaine du 21 octobre
   (`GetCurrencyCaps` sur `ns.SheetCurrencies = {3442..3446}`) ; vérifier que
   `maxWeeklyQuantity = 0` ne déclenche pas « plafond atteint » à tort. Venithes
   ascendantes (monnaie ou objet ? ID à sonder) et noyau du Vide nébuleux
   supplémentaire. Traque : rattrapage de renom (4000 sous rang 4, 2000 du 4
   au 9) sans effet sur `HuntRanks` piloté par la donnée, à contrôler. Grande
   Chambre forte : le boss de Kith'ix compte-t-il dans la rangée raid ?
3. **DailyTracker** : invasion des Aqir (10 min par heure, Chants éternels
   ou Zul'Aman, boss final). Candidat pour la vue Rares / boss mondiaux ; risque
   que `R.KindOf` classe mal son boss s'il porte le tag 289.
4. **LairLens / Stats** : le Labyrinthe est « proche des Gouffres ». Voir si
   Stats le compte comme gouffre (`delveBest`) et si LairLens le confond avec
   un Repaire.
5. **RenTracker / RepBar** : réputations Legion et BFA désormais de bataillon.
   Déjà géré dynamiquement par `C_Reputation.IsAccountWideReputation`, contrôle
   visuel seulement.
6. **Stats** : nouveau haut fait « Saga mythique de Midnight : saison 2 » (cote
   3600), aucune action, il apparaîtra dans `NearAchievements`.
7. **MiniHub** : Blizzard affiche maintenant les coordonnées sous la minicarte
   (CVar `minimapShowPlayerCoords`). MiniHub ancré en bas (`SnapToMinimap
   ("BOTTOM")`) peut les chevaucher : décaler l'ancrage si la CVar est active.

## 6. Plan d'action

**Lot 0, aujourd'hui (release 7.1.5.47)**
- 16 `.toc` : `## Interface: 120105, 120100, 120007`, `## Version: 7.1.5.47`.
- PostBox : helper `P.Coin` sur `C_CurrencyInfo.GetCoinTextureString`,
  `PostBox_Stats.lua` branché dessus.
- SkillTracker `Prices.Money` : même helper.
- PostBox `GetItemIcon` / `GetItemInfo` : passer sur `C_Item`.
- `WHATSNEW["7.1.5.47"]` + `CHANGELOG.md`.
- Vérif syntaxe luaparse sur les fichiers touchés.

**Lot 1, test en jeu par Tibiscui (après `/reload`, sans case « obsolètes »)**
- `/ts doctor` : les 16 modules chargés, aucun obsolète.
- Boîte aux lettres : liste, boîte des persos, journal HV, Statistiques.
- SkillTracker : valeur des sacs, prix des récoltes.
- `/run print(GetItemInfo, GetCoinTextureString)` pour confirmer les retraits.
- BugSack / `/console scriptErrors 1` ouvert pendant une session normale.

**Lot 2, contenu (après sondes en jeu)**
- Sondes : `/dg loot` + journal pour Kith'ix et Kindo'jan, `/wc` pour les
  venithes et les plafonds, `/dt probe` pendant une invasion Aqir.
- Données DgnTracker, WeeklyCompass, DailyTracker, puis Stats / LairLens.
- MiniHub : décalage sous les coordonnées.

**Lot 3, facultatif**
- `C_Intl.FormatNumber` / `FormatCurrency` pour les montants localisés.
- Événement `WEATHER_CHANGED` / `C_Weather` pour Standby (ambiance).

## Suivi (2026-10-14)

- Lot 0 / 7.1.5.47 : validé en jeu, tout fonctionne.
- MiniHub : pas de chevauchement avec les coordonnées de la minicarte, rien à faire.
- DgnTracker : fiches Kith'ix (2613, 73.1 9.4) et Kindo'jan (2395, 63.0 72.2) recalées sur relevés en jeu ; le jeu ne publie aucune entrée pour elles (sonde 02:02). Kith'ix absent du journal d'aventure (tous paliers, vérifié le 2026-10-14) : pas de jid possible pour l'instant. Grotte des Marées : jid 1317 ajouté.
- WeeklyCompass : contrôle des plafonds après le reset du 21 octobre.
- DailyTracker, invasion des Aqir : non testable par Tibiscui, mis de côté.
