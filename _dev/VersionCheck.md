# Alerte de nouvelle version : plan (2026-10-16)

Objectif : afficher dans le chat, comme MapNotes, DBM ou BigWigs, une ligne du
type :

```
19:31 TibiSuite Nouvelle version 7.1.5.50 disponible, votre version 7.1.5.49 est obsolète !
```

Rien n'est écrit. Ce plan est à valider avant le code. Tout ce qui suit sera
à vérifier en jeu par Tibiscui avec un `/reload` (aucun nouveau fichier prévu,
donc pas de redémarrage complet).

---

## Principe

Un addon n'a aucun accès à Internet. La version la plus récente est apprise
**auprès des autres joueurs** :

1. Chaque copie de TibiSuite annonce sa version sur un canal addon invisible
   (`C_ChatInfo.SendAddonMessage`, préfixe `TibiSuite`).
2. Une copie qui reçoit une version plus récente que la sienne l'affiche une
   fois dans le chat.

Limite assumée : un joueur sans guilde ni groupe contenant un utilisateur de
TibiSuite à jour ne verra jamais l'alerte. La mémoire décrite plus bas (rappel
à la connexion suivante) atténue un peu ce point.

Amorce : l'alerte ne peut apparaître qu'une fois qu'au moins une personne de
l'entourage a une version qui embarque déjà ce code. La première release qui
le contient ne prévient donc personne : elle sert de point de départ.

---

## Où vit le code : le socle (v17)

Dans `TibiSuiteUI.lua`, pas dans le core, pour marcher dans les deux modes :

- **Suite** (core présent) : un seul émetteur pour toute la suite.
- **Module seul** (ex. PostBox installé sans le core) : le module charge sa
  copie du socle, l'émetteur marche quand même.

La garde `NS_VERSION` du socle garantit un seul émetteur même si 16 copies sont
chargées. Bump `NS_VERSION` 16 -> 17, recopie dans les 16 copies en gardant
leur bloc d'en-tête « COPIE EMBARQUEE (module X) ».

Nouveau bloc `UI.VersionCheck` en fin de socle, armé sur `PLAYER_LOGIN`.

---

## Quelle version annoncer

- On parcourt la liste fixe des 16 dossiers de la suite et on garde, pour ceux
  qui sont **chargés** (`C_AddOns.IsAddOnLoaded`), la version la plus haute lue
  par `C_AddOns.GetAddOnMetadata(nom, "Version")`. Aujourd'hui elles sont toutes
  identiques (`7.1.5.49`), mais un joueur peut avoir un module plus ancien que
  les autres.
- Nom affiché dans l'alerte : `TibiSuite` si le core est chargé, sinon le nom
  du module seul (le premier trouvé dans la liste, dans l'ordre alphabétique
  si plusieurs modules sont installés sans le core).
- Les modules plus anciens que la version annoncée par le joueur lui-même :
  hors périmètre de cette v1 (`/ts doctor` pourrait le signaler plus tard).

## Format du message addon

```
V1:7.1.5.49:S
```

- `V1` : version du protocole (pour pouvoir le changer sans casser les
  anciennes copies : tout ce qui ne commence pas par `V1:` est ignoré).
- Version : 2 à 4 nombres séparés par des points, rien d'autre.
- `S` = suite (core présent), `M` = module seul. Information seulement.

## Comparaison

- Découpe en nombres, comparaison champ par champ (`7.1.5.50` > `7.1.5.49`,
  `7.1.10` > `7.1.9`). Jamais en texte.
- **Garde-fous** contre les messages farfelus ou malveillants :
  - format strict (motif `^%d+%.%d+[%.%d]*$`, 4 champs max, chaque champ < 1000) ;
  - on ignore une version dont le premier nombre dépasse le nôtre de plus de 1 ;
  - on ignore ses propres messages (nom de l'émetteur = nous).
- Une version reçue n'est retenue que si elle dépasse la nôtre ET la plus haute
  déjà vue dans la session.

---

## Quand on émet

- `PLAYER_ENTERING_WORLD` (première fois), après 10 s.
- `GROUP_JOINED` / `GROUP_ROSTER_UPDATE` (quand le nombre de membres augmente),
  après 5 s.
- `PLAYER_GUILD_UPDATE` à l'arrivée dans une guilde.
- Canaux : `GUILD` si en guilde, `INSTANCE_CHAT` si groupe d'instance
  (`LE_PARTY_CATEGORY_INSTANCE`), sinon `RAID` ou `PARTY`. Pas de `YELL` ni de
  chuchotement.
- Limite de débit : au plus un envoi par canal toutes les 60 s ; un envoi en
  attente est regroupé, jamais empilé.
- **Jamais en combat** (`InCombatLockdown`) : on reporte à
  `PLAYER_REGEN_ENABLED`.
- Midnight restreint la communication addon dans certains contenus d'instance :
  envoi sous `pcall`, code de retour (`Enum.SendAddonMessageResult`) lu et
  ignoré en silence. Point à vérifier en jeu : si un donjon ou un gouffre bloque
  l'envoi, il n'y a rien à corriger, l'annonce partira en guilde plus tard.

## Quand on affiche

- Une seule ligne par session, dès qu'une version plus récente est reçue,
  sauf en combat (reportée à la sortie de combat).
- Format (FR, EN pour les autres langues, textes dans le socle via `GetLocale`
  puisqu'un module seul n'a pas les locales du core) :
  - FR : `|cFFC41F3BTibiSuite|r Nouvelle version |cFF00FF007.1.5.50|r disponible, votre version |cFFFF55557.1.5.49|r est obsolète !`
  - EN : `|cFFC41F3BTibiSuite|r New version 7.1.5.50 available, your version 7.1.5.49 is out of date!`
- Le nom reste en rouge de marque (règle d'identité : le nom « TibiSuite » ne
  suit pas la couleur d'accent). Pour un module seul, son nom dans sa couleur
  d'accent si elle est connue du socle, sinon le rouge.
- En suite : aussi une entrée dans le fil d'activité
  (`TibiSuite.Notify("TibiSuite", texte, { toast = false, once = "ver:7.1.5.50" })`).

## Mémoire (suite seulement)

- `TibiSuiteDB.verSeen = { v = "7.1.5.50", at = time() }` : plus haute version
  vue. À la connexion suivante, si elle dépasse encore la version installée, on
  rappelle la ligne une fois (même sans personne en ligne pour la redire).
- Effacée dès que la version installée l'atteint ou la dépasse (mise à jour
  faite).
- En module seul : pas de SavedVariables propre au socle, donc pas de mémoire ;
  alerte de session seulement. On ne touche pas aux SavedVariables des modules.

## Réglage

- `TibiSuiteDB.versionCheck` (nil = actif, `false` = coupé). Coupé = on
  n'affiche plus rien **et** on n'émet plus rien.
- Case dans Centre > Barre et accès, section « Messages » à côté de `loginMsg`.
- Ajouter `versionCheck` à `SET_KEYS` (`TibiSuiteComfort.lua`) ; `verSeen` n'y
  va pas (c'est une donnée, pas un réglage).
- Le réglage `loginMsg = "none"` ne coupe pas l'alerte : ce n'est pas un
  message de connexion, c'est un avertissement. À confirmer.
- Module seul : toujours actif (rien pour mémoriser un choix).

## Commande

- `/ts version` : version installée, plus haute version vue (et quand), nombre
  de joueurs entendus dans la session par version (table en mémoire, jamais
  sauvegardée, aucun nom affiché). Ajout dans l'aide de `/ts`.
- Ligne dans `/ts doctor` : « Annonce de version : active / coupée, dernière
  version vue ».

---

## Fichiers touchés

| Fichier | Changement |
| --- | --- |
| `TibiSuite/Core/TibiSuiteUI.lua` | v17 : bloc `UI.VersionCheck` (préfixe, émission, réception, comparaison, affichage) |
| 15 copies `*/Core/TibiSuiteUI.lua` | recopie du socle v17, en-têtes gardés |
| `TibiSuite/Core/TibiSuiteCore.lua` | `/ts version`, ligne doctor, branchement `verSeen` et `Notify` |
| `TibiSuite/Core/TibiSuiteCentre.lua` | case « Prévenir quand une nouvelle version est disponible » |
| `TibiSuite/Core/TibiSuiteComfort.lua` | `versionCheck` dans `SET_KEYS` |
| `TibiSuite/Locales/*` | libellé de la case et de `/ts version` (FR + EN) |
| `TibiSuite/Core/TibiSuiteOptions.lua` | entrée `WHATSNEW` de la release |

## Vérification

- Syntaxe : luaparse sur les 17 fichiers.
- Exécution : fengari + faux client (préfixe, réception de `V1:7.1.5.50:S`,
  `V1:99.0:S` ignoré, `abc` ignoré, combat reporté, une seule ligne par session).
- En jeu (Tibiscui) : il faut **deux clients** avec des versions différentes,
  dans la même guilde ou le même groupe. Méthode simple : sur le 2e compte,
  monter à la main `## Version` de `TibiSuite.toc` à `7.1.5.99`, `/reload`, et
  voir l'alerte arriver sur le 1er. Vérifier aussi en module seul (core
  désactivé) et dans un donjon.

---

## Questions ouvertes

1. Message unique « TibiSuite » en suite (proposé), ou une ligne par module ?
2. L'alerte doit-elle passer outre `loginMsg = "none"` (proposé : oui) ?
3. Ajouter un lien cliquable vers CurseForge dans la ligne (ouvre
   `TibiSuite.ShowURL`) ?
