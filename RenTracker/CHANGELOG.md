# Changelog

## 7.1.5.44
- Socle d'interface v16 : les options du module s'ouvrent dans le Centre TibiSuite (roue, Maj+clic droit, clic droit sur l'onglet, commande), le dernier reglage change peut etre annule, et la palette de commandes trouve et modifie ses reglages sur place.

## 7.1.5.43
- Panneau vivant de TibiSuite (nouveau style de barre), ligne d'etat : coffres de Paragon a recuperer, sinon hebdos de reputation restantes.
- Logo refait : 128 px, meme cadrage que toute la suite, emblème sans texte, fond transparent.

## 7.1.5.42
- Socle d'interface v13 : le panneau d'options du module peut s'afficher dans le nouveau Centre TibiSuite (fenetre unique de reglages), sans aucun changement dans le module lui-meme. Centre ferme, la roue d'options et Maj+clic droit rouvrent le panneau flottant comme avant ; en addon independant, rien ne change.

## 7.1.5.41
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir Stats 7.1.5.41 : export des absences de Standby, carte Absences du Dashboard).

## 7.1.5.40
- RenTrackerAPI.GetWeeklyRemaining() (lecture seule) : quetes hebdo de reputation restantes, lue par la tuile A faire ce soir de Standby. Non teste en jeu.

## 7.1.5.39
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir TibiSuite 7.1.5.39 pour le detail : installateur repense).

## 7.1.5.38
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir TibiSuite 7.1.5.38 : la fenetre Quoi de neuf presente la synthese de la semaine, versions 7.1.5.26 a 7.1.5.38, une ligne par module).

## 7.1.5.37
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir PostBox, MiniHub, Opacity et LairLens 7.1.5.37 pour le detail : mises a jour 12.1, mule automatique et journal HV, gestionnaire de boutons et barre rapide, profils et reglage a la molette, fiche du Repaire, 10 langues).

## 7.1.5.36
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir DgnTracker 7.1.5.36 pour le detail : emplacements verifies en jeu, donnees lues dans le jeu, vues Saison / Pres de moi / Favoris, 10 langues).

## 7.1.5.35
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir LvlHistory et SkillTracker 7.1.5.35 pour le detail : LvlHistory mis a jour pour la 12.1 avec l'onglet Niveaux, l'origine de l'XP, les Gouffres et les alts reposes ; SkillTracker avec la concentration projetee, les connaissances de la semaine et "Qui sait crafter ca ?" ; cles M+ de nouveau enregistrees dans Stats).

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
- Nouveau : checklist hebdo automatique. Compteur "faites / suivies" sur chaque ligne de faction et dans l'en-tete des quetes hebdomadaires, total des hebdos restantes dans le recap. Les 4 Pierres-Runes de la Cour comptent pour une seule hebdo (les autres variantes s'affichent "autre choix fait").
- Nouveau : estimation du temps restant. Rythme de gain moyen (jours joues des 7 derniers jours) et delai jusqu'au prochain rang, au Renom max ou au prochain coffre de Paragon. Reputations de Bataillon mesurees au niveau du compte, les autres par personnage. Estimation affichee apres 2 jours de jeu avec gain.

## 7.1.5.28
- Nouveau : coffre de Paragon pret. Badge sur l'onglet Rep. (ou sur le bouton minimap en mode autonome), icone sur la ligne de la faction, mention sur la barre de reputation et alerte dans le chat (desactivable dans /rt config).
- Nouveau : bouton Itineraire vers le quartier-maitre (factions Midnight), point de passage natif sans addon. Le clic sur une quete place aussi un point de passage natif si TomTom est absent.
- Optimisation : les lignes de la fenetre sont reutilisees au lieu d'etre recreees a chaque rafraichissement (memoire stable sur les longues sessions).

## 7.1.5.27
- Mise a jour 12.1 : suivi auto par zone etendu a l'Ile annelee (bascule sur Forces de Zul'Jarra).
- Hauts faits 12.1 ajoutes : Champion des Forces de Zul'Jarra, L'equipage du capitaine Tokka, Tresors des damnes.
- Compteur d'objets a collecter : passage a l'API C_Item.GetItemCount (12.x), ancienne fonction en secours.
- Traduction : "Ile lovee" corrige en "Ile annelee", le nom officiel du client francais.

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
- Relecture orthographe/grammaire/ponctuation : correction de plusieurs fautes dans les noms et descriptions de quetes/hauts faits/zones (ex : Gardiens du Caveau, Ravenholdt, Oeuf mysterieux, Gagner des ressources...), d'un mot duplique et d'un accord de genre.

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
- Correction de bugs de langue et d'interface (UI).

## 7.0.2
- Correction de bugs d'affichage.
