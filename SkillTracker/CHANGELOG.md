# Changelog

## 7.1.5.42
- Socle d'interface v13 : le panneau d'options du module peut s'afficher dans le nouveau Centre TibiSuite (fenetre unique de reglages), sans aucun changement dans le module lui-meme. Centre ferme, la roue d'options et Maj+clic droit rouvrent le panneau flottant comme avant ; en addon independant, rien ne change.

## 7.1.5.41
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir Stats 7.1.5.41 : export des absences de Standby, carte Absences du Dashboard).

## 7.1.5.40
- SkillTrackerAPI.GetFullConcentrations() (lecture seule) : concentrations pleines de tous les personnages, lue par la tuile Mes personnages de Standby. Non teste en jeu.

## 7.1.5.39
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir TibiSuite 7.1.5.39 pour le detail : installateur repense).

## 7.1.5.38
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir TibiSuite 7.1.5.38 : la fenetre Quoi de neuf presente la synthese de la semaine, versions 7.1.5.26 a 7.1.5.38, une ligne par module).

## 7.1.5.37
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir PostBox, MiniHub, Opacity et LairLens 7.1.5.37 pour le detail : mises a jour 12.1, mule automatique et journal HV, gestionnaire de boutons et barre rapide, profils et reglage a la molette, fiche du Repaire, 10 langues).

## 7.1.5.36
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir DgnTracker 7.1.5.36 pour le detail : emplacements verifies en jeu, donnees lues dans le jeu, vues Saison / Pres de moi / Favoris, 10 langues).

## 7.1.5.35
- Nouveau : vue Concentration. La concentration de tous tes personnages, même déconnectés, projetée à l'instant : « pleine dans 14 h » ou « PLEINE depuis 2 j ». La vitesse de recharge est apprise à partir de tes propres relevés (aucune valeur inventée). Alerte à la connexion pour les alts à la concentration pleine, et pastille sur l'onglet de la suite.
- Nouveau : la concentration se relit à la connexion, sans ouvrir le métier, une fois la monnaie du métier connue.
- Nouveau : vue Semaine. Sources de connaissances par personnage et par métier (quête, traité, butins, Foire de Sombrelune), la Foire étant détectée automatiquement ; les autres se cochent à la main et se décochent seules au reset hebdo.
- Nouveau : rangs dépensés dans les arbres de spécialisation du métier.
- Nouveau : « Qui sait crafter ça ? ». Les recettes apprises de chaque personnage sont enregistrées à l'ouverture de ses métiers (extension en cours par défaut, option pour toutes). Vue Recettes avec recherche, résultats dans la loupe de la suite, /skt recipe <texte>, et ligne « Tes personnages savent le fabriquer » dans l'info-bulle des objets. Clic pour ouvrir la recette, Maj+clic pour la lier dans la discussion.
- Nouveau : recherche globale par nom de personnage, commandes /skt conc, /skt week, /skt check, /skt mark et /skt diff.
- Nouveau : SkillTracker disponible en 10 langues.
- Synergie : la fiche personnage de WeeklyCompass affiche les métiers (niveau, concentration, semaine) ; l'export Stats envoie la concentration et la semaine au Dashboard et à Tibi Companion.
- Correction 12.1 : la vue « Toutes les extensions » affichait « Extension 11 » pour The War Within et Midnight ; elle utilise maintenant le nom fourni par le jeu et range les paliers par extension.
- Correction : la concentration et les connaissances ne sont plus effacées à chaque connexion (le cache est conservé quand le jeu ne les fournit pas).
- Correction : l'export multi-comptes tient sur une seule ligne (l'ancien format était tronqué au collage) ; les anciens exports restent lisibles.
- Correction : noms d'extension reconnus en allemand, espagnol, italien, portugais et russe, avec déduction de secours pour les paliers récents.
- Correction : suppression d'un hook sur la fermeture de la fenêtre qui pouvait provoquer la fenêtre « action réservée à l'IU de Blizzard » avec Échap.

## 7.1.5.34
- Socle d'interface embarque passe en v12 : les barres de defilement des options et de la recherche sont habillees aux couleurs du module. Pour le reste, bump de version pour aligner le numero sur l'ensemble de la suite (voir DailyTracker 7.1.5.34 pour le detail : mise a jour 12.1, suivi par personnage, vue Personnages, liste A faire a l'ecran, rappel avant le reset, 10 langues).

## 7.1.5.33
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir RepBar 7.1.5.33 pour le detail : mise a jour 12.1, barre native de nouveau masquee, panneau d'options unique, 10 langues, reputation par heure et temps restant, coffres de Parangon, recompense du prochain renom, factions epinglees et historique au clic).

## 7.1.5.32
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir TibiSuite 7.1.5.32 pour le detail : nouvel installateur en 6 etapes, modules decoches reellement desactives dans WoW, /ts doctor, /ts perf et profils de suite).

## 7.1.5.31
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir LegTracker 7.1.5.31 pour le detail : donnees des legendaires verifiees en jeu, detection sur tout le compte, vue Collection, farm de la semaine, alertes au butin et nouvelle carte Legendaires du Dashboard).

## 7.1.5.30
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir XPBar 7.1.5.30 pour le detail : XP reelle des quetes, historique par niveau, styles, panneau d'options unique, 10 langues).

## 7.1.5.29
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir RenTracker 7.1.5.29 pour le detail : checklist hebdo automatique et estimation du temps restant).

## 7.1.5.28
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir RenTracker 7.1.5.28 pour le detail : coffres de Paragon, itineraire vers le quartier-maitre, optimisation memoire).

## 7.1.5.27
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir RenTracker 7.1.5.27 pour le detail : mise a jour 12.1 et traduction de l'Ile annelee).

## 7.1.5.26
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir Stats et WeeklyCompass 7.1.5.26 : cartes Personnages et Fiche repliables sur le Dashboard web et dans Tibi Companion).

## 7.1.5.25
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir WeeklyCompass 7.1.5.25 pour le detail : WeeklyCompass - Alts & Weekly, disponible en 10 langues).

## 7.1.5.24
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir Stats 7.1.5.24 pour le detail : l'onglet Personnages et la fiche detaillee de WeeklyCompass partent sur le Dashboard TibiSuite et dans Tibi Companion).

## 7.1.5.23
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir WeeklyCompass 7.1.5.23 pour le detail : talents dans la fiche detaillee, bouton Copier le build).

## 7.1.5.22
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir WeeklyCompass 7.1.5.22 pour le detail : fiche detaillee du personnage au clic sur son nom).

## 7.1.5.21
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir WeeklyCompass 7.1.5.21 pour le detail : nouvel onglet Personnages avec niveau d'objet, or, verrouillages de raid, tri et ligne de total).

## 7.1.5.20
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir WeeklyCompass 7.1.5.20 pour le detail : infobulles, masquage des personnages, homonymes distingues et recompense du Grand Coffre deduite).

## 7.1.5.19
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir WeeklyCompass 7.1.5.19 pour le detail : Grand Coffre calque sur la fenetre du jeu et recompense a recuperer).

## 7.1.5.18
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir WeeklyCompass 7.1.5.18 pour le detail : suivi des Gouffres et de la Traque, semaine du Bataillon sur le Dashboard).

## 7.1.5.17
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir Stats 7.1.5.17 pour le detail : rattrapage de l'extension des anciens evenements et correction manuelle).

## 7.1.5.16
- Update and integration opacity - new addons.
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (nouveau module Opacity : transparence de toutes les fenetres ; Stats 7.1.5.16 : colonne Extension et journal des parties JcJ).

## 7.1.5.15
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir Stats 7.1.5.15 pour le detail : nouvelle carte Expeditions).

## 7.1.5.14
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir PostBox 7.1.5.14 pour le detail : correctifs de Tout ouvrir et de la suppression de courriers).

## 7.1.5.13
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir PostBox 7.1.5.13 pour le detail : correction de la pastille de courriers non lus fantome).

## 7.1.5.12
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir Stats 7.1.5.12 pour le detail : correctifs d'affichage du dashboard Tibi Companion/Tibiscui.fr).

## 7.1.5.11
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir Stats 7.1.5.11 pour le detail : correction d'un personnage fantome "charOrder" dans le selecteur et l'export).

## 7.1.5.10
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir Stats 7.1.5.10 pour le detail : possibilite de reordonner ses personnages dans le selecteur, via deux fleches monter/descendre).

## 7.1.5.9
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir Stats 7.1.5.9 pour le detail : correction du suivi des donjons normaux, qui pouvaient ne jamais compter dans la carte "Donjons & M+" sur certains donjons comme Scholomance, meme entierement termine).

## 7.1.5.8
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir Stats 7.1.5.8 pour le detail : regroupement par jour des listes de detail evenement bruyantes - Or, Temps joue, Reputation gagnee, Points de metier gagnes).

## 7.1.5.7
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir Stats 7.1.5.7 pour le detail : refonte de l'interface Stats (grille de cartes couleurs/icones, fenetre redimensionnable, sections PVP/Gouffres+Tourments/Reputations/Metiers repliables), plus le miroir des memes couleurs sur le dashboard Tibiscui.fr/Tibi Companion).

## 7.1.5.5
- Relecture orthographe/grammaire/ponctuation : correction d'une faute de frappe ("liinnere" -> "liseré").

## 7.1.5.4
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero de version sur l'ensemble de la suite (voir Stats 7.1.5.4 pour le detail : correction d'affichage sur le graphique "Toutes les metriques" - echelle de dates et scroll bar).

## 7.1.5.3
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero de version sur l'ensemble de la suite (voir Stats 7.1.5.3 pour le detail des changements de cette version).

## 7.1.5.2
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero de version sur l'ensemble de la suite (voir Stats 7.1.5.2 pour le detail des changements de cette version).

## 7.1.5.1
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero de version sur l'ensemble de la suite (voir Stats 7.1.5.1 pour le detail des changements de cette version).

## 7.1.5
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero de version sur l'ensemble de la suite (voir Stats 7.1.5 pour le detail des changements de cette version).

## 7.1.0
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numéro de version sur l'ensemble de la suite (voir Stats 7.1.0 pour le détail des changements de cette version).

## 7.0.3
- Correction de categorie : le module se range maintenant sous TibiSuite dans la liste d'addons au lieu d'apparaitre a la racine.
- Correction de bugs de langue et d'interface (UI).

## 7.0.2
- Correction de bugs d'affichage.
