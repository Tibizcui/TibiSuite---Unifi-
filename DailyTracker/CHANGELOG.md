# Changelog

## 7.1.5.35
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir LvlHistory et SkillTracker 7.1.5.35 pour le detail : LvlHistory mis a jour pour la 12.1 avec l'onglet Niveaux, l'origine de l'XP, les Gouffres et les alts reposes ; SkillTracker avec la concentration projetee, les connaissances de la semaine et "Qui sait crafter ca ?" ; cles M+ de nouveau enregistrees dans Stats).

## 7.1.5.34
Mise à jour 12.1 complète, en trois lots.

**Données et fiabilité 12.1**
- Forces de Zul'Jarra enfin suivies automatiquement : ID de faction 2772, carte de l'Île annelée, quêtes méta hebdo *Purging the Vaults* et *Turn Back the Surge* reconnues seules, repaire de Nymrissa, coffres de Gouffre, trésors, rares et objets de lore (valeurs alignées sur RenTracker).
- Nouvelle faction : Capitaine Tokka (réputation amitié de pêche).
- La quête de donjon hebdo, commune à plusieurs factions, se coche une fois et ne compte plus qu'une fois.
- Les quêtes « au choix » (Pierres-Runes de Lune-d'Argent, Pactes des Fils Tranchés) comptent pour une seule activité : faire l'une valide les autres, la faction peut enfin atteindre 100 %.
- Le suivi manuel est désormais propre à chaque personnage (avant, cocher sur un perso cochait pour tous). Les anciennes coches sont confiées au premier personnage connecté.
- Point de passage natif de la carte quand TomTom n'est pas installé.
- The War Within : les 8 questID d'origine étaient faux (2 inexistants, 6 pointant vers des quêtes sans rapport, qui cochaient ou décochaient les lignes au hasard). Troupe de théâtre, Éveil de la Machine et Spreading the Light utilisent maintenant les IDs vérifiés sur Wowhead ; Pactes, coffre Bountiful et Défense de Beledar repassent en suivi manuel.
- Noms des quêtes Midnight alignés sur les titres du client français (« En haute estime », « Renforcement des pierres runiques », « Légendes oubliées »...). La recherche trouve aussi le titre affiché par le jeu.
- Les quêtes suivies par questID s'affichent sous leur vrai titre, dans la langue du client (ex. « Nettoyage des caveaux », « Assaut de Fulgarion »).
- `/dt check` fiable : il attend la réponse du serveur avant de conclure et distingue les IDs valides, les quêtes cachées (valides mais sans titre), les IDs introuvables et l'absence de réponse, avec un bilan chiffré. Il signale aussi un « titre suspect » quand le jeu renvoie une quête sans rapport avec la ligne (client français). Avant, un ID valide mais pas encore chargé apparaissait à tort « non résolu ».
- Message de connexion aligné sur le réglage de la suite (complet / une ligne / aucun) ; version lue dans le .toc.
- Couleur violette d'origine retirée, socle embarqué synchronisé en v12 (barres de défilement habillées).

**Optimisation**
- Cache de complétion et listes de factions triées une seule fois par extension.
- Événements de zone inutiles retirés ; minuteur des resets actif seulement fenêtre ouverte.
- Hauteur des conseils mesurée (et non plus estimée sur les octets, que les accents faussaient).
- Un seul fichier habille la fenêtre (doublon retiré).

**Synergie avec la suite**
- Pont de données avec RenTracker : les IDs qui nous manquent sont complétés depuis ses données, et `/dt check` signale toute divergence.
- Badge sur l'onglet Daily : nombre d'activités hebdo restantes.
- La recherche globale ouvre directement la faction et défile jusqu'à la quête.

**Nouveautés**
- Vue Personnages (onglet ALTS, `/dt alts`) : progression hebdo et quotidienne de chaque perso, ce qu'il reste à faire en infobulle, détection d'un reset passé.
- Liste « À faire » compacte à épingler à l'écran (onglet LISTE, `/dt todo`).
- Renom réel (ou rang d'amitié) affiché sur chaque faction.
- Nombre de quêtes du monde disponibles compté en direct par zone.
- Rappel avant le reset hebdo s'il reste des activités (réglable, 0 = désactivé).
- Interface en 10 langues (traductions hors FR/EN non relues par des natifs).
- Nouveau fichier `Locales.lua` : redémarrage complet du client requis la première fois.

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
- Relecture orthographe/grammaire/ponctuation : rien a corriger dans ce module. Bump de version pour aligner le numero sur l'ensemble de la suite (voir Stats 7.1.5.5 pour le detail des corrections de bug).

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
