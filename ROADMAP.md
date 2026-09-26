# TibiSuite (Unifié) — Feuille de route

> Document de suivi vivant : statut par module, chantiers en cours, points en
> attente de validation en jeu. Complète `CLAUDE.md` (qui décrit l'architecture)
> et `CurseForge-Listings.md` (qui décrit le contenu des pages publiques).
> Mis à jour manuellement au fil des sessions — à tenir à jour à chaque
> changement de statut significatif plutôt que de laisser dériver.
>
> Dernière reconstitution : 2026-09-22, à partir de l'historique git, de
> `CLAUDE.md` et de la mémoire des sessions précédentes.

## Vue d'ensemble

- **Version courante de la suite : 7.1.5.21**, synchronisée sur les 15
  addons (14 modules + le core `TibiSuite`).
- Écosystème élargi autour de la suite (dépôts séparés) :
  - **Tibiscui.fr** — site web, héberge le Dashboard qui décode le code
    d'export du module Stats.
  - **Tibi-Companion** — app Electron desktop, même rôle que le Dashboard
    web mais en local, distribuée publiquement (voir plus bas).
- Convention du projet à respecter partout : français, jamais de tiret
  cadratin, tout code non testé en jeu doit être signalé explicitement
  (`à valider par Tibiscui avec un /reload`).

---

## État par module

| Module | Statut | Dernières évolutions notables |
|---|---|---|
| **TibiSuite (core)** | Stable | Catalogue de modules, chargement à la demande, bouton minicarte unique, recherche globale. |
| **DailyTracker** | Stable | Détection auto des quêtes quotidiennes/hebdo, filtres, sections repliables. |
| **DgnTracker** | Stable | Accordéon par extension nettoyé (commit `4f1dc30`), code mort/doublons retirés. |
| **LairLens** | Stable | Audit de groupe en direct + historique de runs (contenu patch 12.1). |
| **LegTracker** | Stable | Panneau Options migré vers le socle unifié (plus de bouton engrenage propre). |
| **LvlHistory** | Stable | Suivi Leveling/Farm, historique persistant, autosave 5 min. |
| **MiniHub** | Stable | Regroupement des icônes minicarte, détection ElvUI/Tukui/EllesmereUI. |
| **PostBox** | **En chantier actif** | Voir section dédiée ci-dessous — c'est le module le plus mouvant en ce moment. |
| **RenTracker** | Stable | Suivi de réputation sur 13 extensions, bascule auto par zone. |
| **RepBar** | Stable | Remplace la barre de réputation native, bascule auto via RenTracker. |
| **SkillTracker** | Stable | Trois vues (extension courante / toutes / compte), pas de boutons flottants. |
| **Stats** | Stable, dernière grosse feature livrée | Détail par événement (Phase 1+2) livré et confirmé en jeu le 2026-09-13. Voir section dédiée. |
| **WeeklyCompass** | Stable | Dashboard hebdo unifié Saison 1/2. |
| **XPBar** | Stable | Barre d'XP enrichie (repos, XP/h, temps restant estimé). |

---

## Chantier en cours : PostBox

Réécriture from scratch de Postal en Lua natif (API `C_Mail`, WoW 12.1),
Postal servant de cahier des charges fonctionnel, pas de code repris.
**Règle de travail validée : toujours présenter le plan avant d'écrire le
code**, surtout pour les options "waouh" génératrices de téléchargements.

**Fonctions déjà implémentées :**
- Open All (ramassage en masse, un tick à la fois — voir piège API ci-dessous)
- Express (Maj/Ctrl/Alt sur un courrier)
- Sélection multiple (plages Maj, même expéditeur Ctrl) + suppression groupée
- BlackBook (carnet de contacts, fichier dédié `PostBox_BlackBook.lua`)
- Rake (compteur de session, bouton reset dans les options)
- Do Not Want (retour auto à l'expéditeur)
- Dashboard de statistiques courrier (`PostBox_Stats.lua`)
- Badge de courrier non lu sur l'onglet TibiSuite

**Pas encore implémentées (backlog du cahier des charges Postal) :**
- Forward
- CarbonCopy
- TradeBlock
- QuickAttach

**Historique récent (2026-09-21/22) — stabilisation Open All / suppression :**
une série de correctifs a été nécessaire car l'API mail de WoW 12.x se
comporte différemment de ce qui était supposé au départ (une seule prise
acceptée par tick, en-têtes non rafraîchis tant que la boîte reste ouverte,
parcours à faire du dernier courrier au premier). Comportement maintenant
confirmé en jeu et documenté pour éviter de reproduire les mêmes essais/
erreurs sur un futur module qui toucherait une API serveur asynchrone
similaire.

---

## Chantier récent : Stats — détail par événement

Fonctionnalité livrée en v7.1.5.6 (commit `efabe56`), avec effet miroir
obligatoire sur `Tibiscui.fr/dashboard-shared.js` et la copie vendue dans
Tibi-Companion à chaque changement du format d'export.

- **Phase 1** (Quêtes/Donjons/Raids/Gouffres/Réputation) : implémentée et
  **entièrement validée en jeu le 2026-09-13**.
- **Phase 2** (Or par source, temps joué par activité, détail métiers) :
  codée et livrée dans le même commit. **Points encore non confirmés en
  jeu** : heuristique fenêtre marchand (or par source), lecture AH via
  `PostBoxDB`, classification temps joué gouffre vs donjon.

**Zones ajoutées sans accès client (PVP, Gouffres, Tourments, 2026-09-07)** —
construites par recherche externe (Wowhead/Warcraft Wiki), pas par test en
jeu direct. Une partie a été confirmée depuis (points de haut fait, panneau
PVP, palier Torghast 8), le reste reste marqué "à vérifier en jeu" dans le
code : mapping des brackets PVP, déclenchement des Gouffres sur
`SCENARIO_COMPLETED`, nom du champ niveau de compagnon de Gouffre, IDs de
haut fait Torghast intermédiaires (14597-14602), attribution de cause de
mort, gagnant de champ de bataille, nom de gouffre spécifique.

---

## Écosystème lié à Stats

### Tibi-Companion (dépôt séparé, Electron)
- v0.1 : installé et confirmé fonctionnel de bout en bout (2026-09-02).
- v2.0.0 : publié publiquement sur `tibiscui.fr/tibi-companion.html`.
- **Bloqueur de distribution actif** : l'app n'est pas signée
  (Smart App Control de Windows bloque l'installateur téléchargé, sans
  bouton "exécuter quand même"). Une soumission Microsoft Store est en
  cours (Product ID `9PBH67800875`) : un premier rejet (règle 10.1.1.11,
  tuiles par défaut) a été corrigé en générant les assets `build/appx/`
  manquants — **non encore reconfirmé** par un nouveau build CI + une
  resoumission à Partner Center.
- Format d'export : miroir à 3 emplacements obligatoire
  (`Stats/Export.lua` + `Stats/Libs/LZW.lua` → `Tibiscui.fr/dashboard-shared.js`
  → copie vendue dans Tibi-Companion). Un bug de checksum UTF-8 a déjà été
  corrigé aux 2 endroits web (2026-09-02) ; à revérifier si le format
  d'export change à nouveau.

### Tibiscui.fr (dépôt séparé, site web)
- Héberge le Dashboard qui décode le code d'export Stats côté navigateur,
  rien n'est envoyé à un serveur.

---

## Pipeline de publication (CurseForge)

`.github/workflows/release.yml` publie chacun des 14 dossiers d'addon
indépendamment (un tag `<Module>-vX.Y.Z` par module), via
`BigWigsMods/packager@v2`. Changelog automatisé depuis le 2026-09-07 via
`.pkgmeta` + `CHANGELOG.md` par module (mise à jour manuelle obligatoire à
chaque bump de version, sinon CurseForge affiche un changelog périmé).

**Règle de sécurité établie :** je ne pousse jamais moi-même les tags de
release — je fournis toujours les commandes (PowerShell, sans `&&`) et
c'est Tibiscui qui les exécute.

**Incident résolu (2026-09-06/07) :** upload manuel en double sur 3 projets
CurseForge (PostBox, RepBar, Stats) → approuvé manuellement par Tibiscui,
root cause confirmée comme l'upload manuel seul (pas la CI). Le garde-fou
de sérialisation ajouté par précaution a été retiré ensuite.

**Statut facturation GitHub Actions : résolu (2026-09-17).** Un blocage de
quota (2000 min/mois dépassées, pas de moyen de paiement enregistré)
empêchait les workflows de démarrer (`queued` sans runner assigné) mi-
septembre. Les runs repassent normalement depuis le 2026-09-17 — à
revérifier si le symptôme (run bloqué en `queued` plus de ~2 min)
réapparaît.

---

## Dette technique & pièges connus à ne pas réintroduire

- **Échap / taint (résolu, définitif) :** ne jamais fermer une fenêtre à
  Échap via `UISpecialFrames` + hook `OnHide` (contamine `ToggleGameMenu`).
  Utiliser `EnableKeyboard` + `SetPropagateKeyboardInput` + `OnKeyDown` sur
  chaque fenêtre `escClose`, câblé uniquement par le socle UI.
- **Dossier AddOns en jeu = copie, pas un lien symbolique.** Le dossier
  live `Interface/AddOns/<Module>` peut dériver silencieusement du dépôt
  (déjà arrivé sur Stats : `Core.lua` en retard d'une fonctionnalité
  entière). Diffuser d'abord avant de suspecter un bug de code si le
  comportement en jeu ne correspond pas au dépôt.
- **Un gestionnaire d'addons (CurseForge app / WowUp) écrase les
  déploiements manuels.** Une resynchronisation auto peut restaurer la
  dernière version *publiée* par-dessus un déploiement direct fait pour
  tester une fonctionnalité non encore sortie. Signature : tous les
  fichiers du dossier live ont exactement le même mtime.
- **Texte client français et espace insécable (U+00A0).** `%s` en Lua ne
  matche jamais l'espace insécable que le client FR insère avant
  `: ! ? ;`. Utiliser des ancres ASCII strictes (`string.find` en mode
  plain), jamais un pattern sur l'espace ou les caractères accentués.
- **API courrier WoW 12.x :** une seule prise (`TakeInboxItem`/
  `TakeInboxMoney`) acceptée par tick, en-têtes non rafraîchis tant que la
  boîte reste ouverte, parcours à faire du dernier courrier au premier.
- Aucun module ne touche du code sécurisé/verrouillé en combat (lecteurs
  de données uniquement) : pas de risque de taint sur les données elles-
  mêmes, seulement sur la fermeture de fenêtre (cf. point Échap).

---

## Points ouverts — à valider par Tibiscui avec un `/reload`

Liste consolidée de ce qui est codé mais pas encore confirmé en jeu, à
traiter en priorité la prochaine fois que ces zones sont touchées :

1. PostBox : Forward, CarbonCopy, TradeBlock, QuickAttach — non codés,
   backlog du cahier des charges Postal.
2. Stats Phase 2 : heuristique or par source (fenêtre marchand), lecture
   AH via `PostBoxDB`, classification temps joué gouffre vs donjon.
3. Stats PVP/Gouffres/Tourments : mapping des brackets PVP, déclenchement
   `SCENARIO_COMPLETED` pour les gouffres, nom du champ niveau de
   compagnon, IDs de haut fait Torghast 14597-14602, attribution de cause
   de mort, gagnant de champ de bataille, nom de gouffre spécifique.
4. Tibi-Companion : build `appx` régénéré avec les nouvelles tuiles +
   resoumission Microsoft Store Partner Center, à confirmer après le
   rejet du 2026-09-16.
5. Tibi-Companion : build macOS jamais tenté (pas de Mac disponible).

---

## Idées non validées (à proposer avant d'intégrer)

Tibiscui veut, pour PostBox en particulier, des options "waouh"
génératrices de téléchargements. Aucune n'est encore actée : toujours
présenter le plan avant d'écrire le code pour ce module.
