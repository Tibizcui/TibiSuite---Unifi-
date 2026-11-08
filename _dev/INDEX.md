# TibiSuite : index du projet

> Point d'entrée unique pour retrouver le code, les plans et les conversations.
> Reconstitué le 2026-11-08 à partir de l'historique git, des tags, de la mémoire
> de Claude et de la liste des sessions. `CLAUDE.md` décrit l'architecture,
> `ROADMAP.md` est figé à la 7.1.5.40 (garder pour l'historique, ne plus s'y fier
> pour l'état courant).

## Où est quoi

| Élément | Emplacement | Rôle |
|---|---|---|
| Suite d'addons (16 addons) | `Documents\GitHub\TibiSuite - Unifié` (ce dépôt) | Seul dépôt de travail des addons |
| Site | `Documents\GitHub\Tibiscui.fr` | Site + Dashboard (`dashboard-shared.js`, `site-facts.js`) |
| Tibi Companion | `Documents\GitHub\Tibi-Companion` | App Electron, Store 9PBH67800875, build par `build-windows.yml` |
| Builds et archives | `Documents\GitHub\_archives\TibiSuite` | Installeurs Companion 2.0.26, vieille archive zip d'août |
| Anciennes versions autonomes | `Documents\GitHub\XPBar`, `RenTracker`, `TibiSuite`, `TibiSuite -v4.1.2`... | Pré-fusion, **ne pas modifier** |
| Sonde d'API | `_dev/TibiProbe` | Addon de sonde en jeu |
| Fiches CurseForge | `CurseForge-Listings.md` | Texte des pages publiques |
| Hors TibiSuite | `Foyer.tibiscui.fr`, `mariage-2027`, jeux (Pong, Snake...) | Projets séparés, groupes à part dans la barre latérale |

## Plans de conception (`_dev/`)

| Fichier | Sujet | État |
|---|---|---|
| `Compat_12.1.5.md` | Compatibilité patch 12.1.5 (interface 120105) | Lot 1 publié en 7.1.5.47, lot 2 (contenu) en partie fait en 7.1.5.48 |
| `Conseiller.md` | Suggestions et fenêtre des propositions | Publié en 7.1.5.49, validé en jeu |
| `VersionCheck.md` | Alerte de nouvelle version dans le chat | Publié en 7.1.5.50 |
| `LegOverlay.md` | Légendaire épinglé et overlay de farm | Publié en 7.2.0, validé en jeu |
| `Plan_7.3.md` | Session guidée, patrimoine, bilan, M+, visite, groupe | Publié en 7.3.0 ; liste de contrôle en jeu en fin de fichier |

## Chronologie des versions

| Version | Date | Commit | Contenu |
|---|---|---|---|
| 7.0 à 7.1.5.14 | août à 2026-09-21 | | Fusion des trackers, pipeline CurseForge, Stats (journal d'événements), PostBox |
| 7.1.5.15 | 2026-09-23 | `621a9b0` | Stats : carte Expéditions |
| 7.1.5.16 | 2026-09-24 | `52ebccf` | Nouveau module Opacity |
| 7.1.5.18 à .25 | 2026-09-25/26 | `4e730bd`..`0ae89eb` | WeeklyCompass : Gouffres, Grand Coffre, alts, fiche, 10 langues |
| 7.1.5.27 à .29 | 2026-09-28 | `d3a1d69`..`b5ce8cd` | RenTracker 12.1 (Parangon, itinéraire, checklist) |
| 7.1.5.30 | 2026-09-28 | `188058d` | XPBar refondu |
| 7.1.5.31 | 2026-09-28 | `255d175` | LegTracker 12.1 |
| 7.1.5.32 | 2026-09-28 | `62b5986` | Installateur premium, désactivation réelle, doctor/perf/profils |
| 7.1.5.33 | 2026-09-28 | `38b1555` | RepBar refondu |
| 7.1.5.34 | 2026-09-28 | `88fd504` | DailyTracker 12.1 |
| 7.1.5.35 | 2026-09-29 | `caf3473` | LvlHistory et SkillTracker 12.1 |
| 7.1.5.36 | 2026-09-29 | `e3b0fb8` | DgnTracker 12.1 |
| 7.1.5.37 | 2026-10-03 | `6881ecd` | PostBox, MiniHub, Opacity, LairLens 12.1 |
| 7.1.5.38/.39 | 2026-10-03/04 | `7e45c4d`, `7b028e9` | Quoi de neuf hebdo, installateur repensé |
| 7.1.5.40 | 2026-10-04 | `f936641` | Nouveau module Standby |
| 7.1.5.41 | 2026-10-05 | `98c933a` | Stats exporte les absences |
| 7.1.5.42 | 2026-10-06 | `af6ebc6` | Centre TibiSuite |
| 7.1.5.43 | 2026-10-06 | `1efed36` | Styles de barre Dock et Panneau vivant |
| 7.1.5.44 | 2026-10-10 | `cc48052` | Centre premium (Ma semaine, palette, fil, widgets, annuler...) |
| 7.1.5.45 | 2026-10-12 | `7258b0e` | Aperçus, objectifs, récoltes, rares, collections, tableau de bord Stats |
| 7.1.5.46 | 2026-10-13 | `492f885` | Versions alignées, refonte du site |
| 7.1.5.47/.48 | 2026-10-14 | `52cc50e`, `adc4601` | Compatibilité 12.1.5, DgnTracker 12.1.5 |
| 7.1.5.49 | 2026-10-15 | `f5daf33` | Le Conseiller |
| 7.1.5.50 | 2026-10-16 | `eeb5b75` | Alerte de nouvelle version |
| 7.1.5.51 à .53 | 2026-10-18 | `c195ea9`..`9563390` | Pêche, temps de farm par métier, overlay de pêche |
| 7.2.0 | 2026-10-18 | `6ae7238` | Légendaire épinglé |
| 7.2.1 | 2026-10-18 | `a071e4d` | Récolte au niveau de la pêche |
| 7.3.0 | 2026-10-20 | `631660a` | Chat unifié, session guidée, patrimoine, bilan, M+, visite, partage en groupe |
| 7.3.1/7.3.2 | 2026-10-31 | `85aeb4f`, `316ae2e` | Correctifs (affichage) |
| 7.3.3 | 2026-11-07 | `5fe1c80` | LvlHistory raids et temps en instance, centrage XPBar/RepBar |

## État par module (au 2026-11-08)

| Module | SavedVariables | Dernier gros chantier | Validé en jeu |
|---|---|---|---|
| TibiSuite (core) | TibiSuiteDB, TibiSuiteCharDB | Centre, Conseiller, 7.3 (session, patrimoine, bilan, groupe) | Centre, Conseiller, partage en groupe : oui. Planner, visite : à confirmer |
| DailyTracker | DailyTrackerDB | 12.1, rares et boss mondiaux (lot 7) | Oui pour le lot 7 (publié 7.1.5.45) |
| DgnTracker | DgnTrackerDB | Collections, 12.1.5 | Oui |
| LairLens | LairLensDB, LairLensCharDB | 12.1 (détection FR, fiche Repaire) | Non confirmé |
| LegTracker | LegTrackerDB | Épingle et overlay, farm de pêche | Oui |
| LvlHistory | LvlHistoryDB | Onglet Raids, temps en instance (7.3.3) | **Non testé en jeu** |
| MiniHub | MiniHubDB | 12.1, pause EllesmereUI/ElvUI | Oui |
| Opacity | OpacityDB | Profils v2, groupes liés, contextes | Oui |
| PostBox | PostBoxDB | Moteur de prise unique, mule, alts | Oui |
| RenTracker | RenTrackerDB | Parangon, checklist hebdo | Oui |
| RepBar | RepBarDB | Refonte 12.1, centrage (7.3.3) | Centrage : à confirmer |
| SkillTracker | SkillTrackerDB | Prix des récoltes, pêche, récolte, valeur des sacs | Pêche et récolte : oui ; valeur des sacs : à confirmer |
| Standby | StandbyDB | Écran d'absence | En partie |
| Stats | StatsDB | Tableau de bord KPI, hauts faits, session, export | En partie |
| WeeklyCompass | WeeklyCompassDB | Alts, M+ (onglet Mythique+), plafonds | M+ : oui (7.3.0) |
| XPBar | XPBarDB | Refonte 12.1, centrage, fermeture auto | Centrage : à confirmer |

## Chantiers ouverts

- **7.3.3 en jeu** : vérifier l'onglet Raids et la colonne « Passé » de LvlHistory, le centrage de XPBar et RepBar, avec un `/reload`.
- **CurseForge 7.3.3** : les 16 tags ont été relancés deux fois le 2026-11-07 (toutes les exécutions réussies). Vérifier sur CurseForge qu'il n'y a pas de fichiers en double.
- **Tibi Companion 2.0.26** : installeur direct en ligne sur le site (`1ff1601`) ; soumission au Store à confirmer. Dossier `dist_download/` non suivi dans le dépôt Companion.
- **Vénithes ascendantes** (WeeklyCompass) : toujours reconnues par leur nom (`id = nil` dans `Data/Activities.lua`), l'itemID réel reste à relever en jeu puis à écrire en dur.
- **Lot 3 pêche** (lancer au double-clic) : reporté volontairement (code sécurisé).
- **WoW Forever** : rien à faire tant qu'il n'y a pas d'accès client.

## Conversations (barre latérale de Claude)

Groupes de la barre latérale, rangés le 2026-11-08. Les sessions archivées
gardent leur ancien groupe (l'application ne permet pas de les déplacer) : on
les retrouve avec la recherche ou en les désarchivant.

### TibiSuite · Core et Centre
- Optimisation et fonctionnalités (plan 7.3) : claude://claude.ai/epitaxy/local_44cff5fd-b555-4407-9bae-df7046993f16
- Analyse historique et recommandations (Conseiller) : claude://claude.ai/epitaxy/local_5dfdac3c-5594-4d7b-b152-f203aec44739
- Format de message pour les addons (alerte de version) : claude://claude.ai/epitaxy/local_ef5b0fde-54b6-40c2-8022-96964ecf116a
- Compatibilité 12.1.5 : claude://claude.ai/epitaxy/local_0a6ee9bf-5899-46db-8f24-3ac1d13218b2
- Vérifier les addons après 12.1.5 : claude://claude.ai/epitaxy/local_df08fe22-f109-46d0-98c9-85f3f4ba4dd4
- TibiSuite addon 12.1 (aperçus, lots premium) : claude://claude.ai/epitaxy/local_7226ee37-a261-48ce-a6a3-eee4c87c16fc
- Compatibilité WoW Forever : claude://claude.ai/epitaxy/local_f3973295-bcac-438c-bd50-15e6a7a780fc
- Archivées : Interface unifiée, Présentation UI premium, TOC et chat, Claude RC, Restructuration, Développement modulaire

### TibiSuite · Modules
- XPBar fermeture automatique : claude://claude.ai/epitaxy/local_a425330d-aff7-4264-80b0-fd1cf8a05ca3
- Fishing Buddy (pêche SkillTracker) : claude://claude.ai/epitaxy/local_61c23713-813a-4451-84eb-c69de38c9087
- Overlay légendaires : claude://claude.ai/epitaxy/local_98675ed6-a6e5-4eb4-843b-537da932ae7a
- Archivées : une session « 12.1 update » par module (Daily, Dgn, Lair, Leg, Lvl, MiniHub, Opacity, PostBox, Rep, RepBar, Skill, Standby, Weekly, XPBar), Weekly V2, Addon Opacity, carte Expéditions, SpellStopCasting

### TibiSuite · Releases et CurseForge
- Archivées : Auto-packaging et déploiement CurseForge, Suivi CurseForge + prépa 7.0.1 (deux)

### Tibiscui.fr et Tibi Companion
- Site Web : Tibiscui.fr : claude://claude.ai/epitaxy/local_1b967111-4900-4957-adbb-a55d82391281
- Cartes Patrimoine et Bilan du Dashboard : claude://claude.ai/epitaxy/local_0bd87c34-de59-417d-9ec6-c7fa2ca221fb
- Analyse et mise à jour du design (refonte du site) : claude://claude.ai/epitaxy/local_486ade3e-8783-4ce5-89eb-6d308c8e091e
- Archivées : Nouveau site Web V3, Liste des automatisations

## Règles qui ne bougent pas

- Ne jamais renommer un dossier de module (perte des SavedVariables).
- Ne jamais pousser les tags en lot (plus de 3 tags = aucune exécution) : un par un.
- Les tags de release sont donnés à Tibiscui, Claude ne les pousse pas.
- Nouveau fichier ou nouvelle entrée `.toc` = redémarrage complet du client.
- Le dossier AddOns en jeu est une copie, pas un lien : comparer avant de déboguer.
