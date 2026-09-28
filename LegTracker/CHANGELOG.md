# Changelog

## 7.1.5.34
- Socle d'interface embarque passe en v12 : les barres de defilement des options et de la recherche sont habillees aux couleurs du module. Pour le reste, bump de version pour aligner le numero sur l'ensemble de la suite (voir DailyTracker 7.1.5.34 pour le detail : mise a jour 12.1, suivi par personnage, vue Personnages, liste A faire a l'ecran, rappel avant le reset, 10 langues).

## 7.1.5.33
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir RepBar 7.1.5.33 pour le detail : mise a jour 12.1, barre native de nouveau masquee, panneau d'options unique, 10 langues, reputation par heure et temps restant, coffres de Parangon, recompense du prochain renom, factions epinglees et historique au clic).

## 7.1.5.32
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir TibiSuite 7.1.5.32 pour le detail : nouvel installateur en 6 etapes, modules decoches reellement desactives dans WoW, /ts doctor, /ts perf et profils de suite).

## 7.1.5.32 (en preparation)
- Noms francais de deux raids alignes sur le client (Le Puits de soleil ; Aberrus, le creuset de l'Ombre), releves par /lt verify. Les 11 IDs de raids sont confirmes en jeu.

## 7.1.5.31
- Carte "Legendaires" sur le Dashboard (Tibiscui.fr et Tibi Companion) : LegTracker ecrit a chaque scan un resume du compte (statut, personnages detenteurs, etape en cours), que Stats ajoute a son code d'export.
- Vue Collection : les objets reserves a une seule classe affichent la classe (les quatre Atiesh se distinguent).
- Farm cette semaine : la fiche d'un legendaire non obtenu indique pour chaque raid utile s'il est libre ou deja verrouille cette semaine (difficulte et boss tues), avec les boss a viser.
- Vue Collection (bouton en haut de la fenetre ou `/lt collection`) : tous les legendaires du compte en une grille, une colonne par personnage, colonne Compte (tour de force, apparence), taux de collection et raids de farm encore libres cette semaine. Clic sur une ligne pour revenir a sa fiche.
- Alerte au butin : message a l'ecran, dans le chat et son (desactivables) quand un composant suivi entre dans les sacs ou qu'un legendaire est obtenu. Muette a l'ouverture de la banque.
- `/lt verify` controle aussi les IDs des raids.
- Midnight's Edge (patch 12.2) : fiche d'attente et gabarit prets pour l'ajout a la sortie du patch.
- Detection sur tout le compte : un legendaire est reconnu comme obtenu s'il est sur ce personnage, sur un autre personnage deja scanne, via son tour de force (compte) ou via son apparence apprise, meme s'il a ete vendu ou si le personnage n'a jamais lance LegTracker. La fiche indique comment il a ete detecte.
- Etapes de quetes : la suite est numerotee, l'etape en cours est mise en avant ("Etape 2/3"), et marquee "[Dans le journal]" quand la quete est acceptee. Accepter la quete suffit a passer l'objet "En cours".
- Infobulles : sur un composant (objet ou monnaie), une ligne LegTracker indique le legendaire concerne et la quantite possedee ; sur un legendaire suivi, son statut. Desactivable dans les options (section Infobulles).
- `/lt verify` controle aussi les tours de force.
- Donnees corrigees : Nasz'uro utilisait l'ID de Fyr'alath (un Guerrier qui possedait Fyr'alath voyait Nasz'uro obtenu). Nasz'uro = 204177, Fyr'alath = 206448.
- Anneaux de Warlords of Draenor : les 5 anneaux avec leurs bons noms (Thorasus et Etheralus manquaient, les autres etaient decales).
- Capes de Mists of Pandaria : les 6 capes (Qian-Le manquait, Qian-Ying etait nommee Jina-Kang).
- Shadowlands : Cendre d'ame, Scories d'ame et Flux cosmique sont suivis comme des monnaies. La progression restait bloquee a zero.
- The War Within et Midnight : fiches d'information claires (aucun legendaire en TWW, Midnight's Edge annonce pour le patch 12.2) au lieu d'emplacements vides.
- Corrections issues du premier `/lt verify` en jeu : noms alignes sur le client francais, composants faux retires ou remplaces (Lame-tonnerre, Sulfuras, Deuillelombre, Courroux du dragon, Crocs du pere, capes MoP, Nasz'uro), legendaires Legion inverses ou mal identifies corriges. Anneaux WoD marques "legacy" : leur suite de quetes a ete retiree avec Legion.
- Nouvelle commande `/lt verify` : controle en jeu de chaque ID d'objet, de monnaie et de quete, et signale les IDs inconnus ou les noms differents (client francais).
- Point de route sans TomTom : plus d'erreur sur les cartes d'instance (Ulduar, Citadelle de la Couronne de glace), un message l'explique.
- Performances : le panneau de droite ne recree plus ses elements a chaque rafraichissement (la memoire augmentait a chaque mise a jour des sacs, fenetre ouverte), et chaque objet n'est plus interroge qu'une fois par scan.
- Compatibilite 12.x : plus d'appel aux anciennes fonctions globales GetItemCount / GetItemInfoInstant quand l'API C_Item est disponible ; icone de secours corrigee.

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
- Relecture orthographe/grammaire/ponctuation : correction d'un accent errone et d'un accord de participe passe ("Donnees de compte reinitialisees").

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
