# Changelog

## 7.1.5.19
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir WeeklyCompass 7.1.5.19 pour le detail : Grand Coffre calque sur la fenetre du jeu et recompense a recuperer).

## 7.1.5.18
- Le code d'export inclut maintenant la semaine WeeklyCompass de chaque personnage (Grand Coffre, Gouffres, Traque), si WeeklyCompass est installe. Ajout purement additif : le format du code ne change pas, les anciens codes restent lisibles.

## 7.1.5.17
- Rattrapage de l'extension des evenements enregistres avant la 7.1.5.16 (affiches "-" jusqu'ici). Lance automatiquement une fois apres la mise a jour, puis relancable depuis les options de Stats. Donjons, M+ et raids retrouves via le Guide de l'aventurier, gouffres via la carte, reputations via le panneau de reputation, metiers via la date. Quetes et expeditions : extension estimee d'apres la zone, affichee "~" dans l'addon et "≈" dans Tibi Companion et sur le site ; les capitales (Orgrimmar, Hurlevent...) restent a "-", une zone de capitale ne suffisant pas a savoir de quelle extension vient la quete.
- Correction manuelle : clic sur une cellule Extension de la liste d'evenements pour choisir l'extension. Le choix s'applique a tous les evenements du meme nom, sur tous les personnages, et remplace une estimation.
- Aide integree : une bulle au survol de chaque cellule Extension explique un "-" (extension inconnue) ou un "~" (extension estimee), et un rappel sous la liste indique comment choisir l'extension quand il reste des "-".
- Le rattrapage ne remplit que les evenements sans extension : il n'ecrase jamais une valeur lue en direct ni une correction manuelle. Les sous-zones ne sont reconnues que si le personnage les a explorees.

## 7.1.5.16
- Update and integration opacity - new addons.
- Nouvelle colonne Extension dans le detail des cartes Quetes, Expeditions, Donjons & M+, Raids, Gouffres, Reputation gagnee et Points de metier gagnes (ex. une quete faite a Legion, un raid de Midnight). L'extension est lue au moment de l'evenement : les evenements enregistres avant cette version affichent "-", l'historique ne peut pas etre reconstitue.
- Nouveau filtre par extension au-dessus de ces listes (Toutes, une extension precise, ou Non renseignee pour les anciens evenements).
- Nouveau journal des parties JcJ : une ligne par champ de bataille, arene, Blitz ou bagarre termine (carte, type, resultat, duree, extension d'origine de la carte), accessible via le bouton "Journal des parties" du panneau PVP. Il demarre a l'installation de cette version.
- Or et Temps joue n'ont pas de colonne Extension (listes regroupees par source ou activite).
- Egalement affiche dans Tibi Companion et sur le Dashboard-Tibi. Format d'export inchange.

## 7.1.5.15
- Nouvelle carte Expeditions (World Quests) : compte les expeditions terminees par jour, toutes extensions depuis Legion, avec courbe et detail au clic (expedition, zone, XP). Le compteur demarre a l'installation de cette version : aucune statistique Blizzard ne permet de reprendre l'historique. Egalement affichee dans Tibi Companion et sur le Dashboard-Tibi.

## 7.1.5.14
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir PostBox 7.1.5.14 pour le detail : correctifs de Tout ouvrir et de la suppression de courriers).

## 7.1.5.13
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir PostBox 7.1.5.13 pour le detail : correction de la pastille de courriers non lus fantome).

## 7.1.5.12
- Aucun changement fonctionnel dans l'addon : bump de version pour aligner le numero sur l'ensemble de la suite. Correctifs d'affichage cote Tibi Companion/Tibiscui.fr : icones sur les cartes (memes que l'addon), plus de "[?]" sur le profil Compte, glisser-deposer des personnages annonce par une astuce (fleches retirees).

## 7.1.5.11
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir Stats 7.1.5.11 pour le detail : correction d'un personnage fantome "charOrder" dans le selecteur et l'export).

## 7.1.5.10
- Nouveau : le selecteur de personnage principal permet desormais de reordonner ses personnages, via deux fleches (monter/descendre) a cote de chaque nom dans la liste deroulante. L'ordre choisi est memorise (StatsDB.charOrder) et remplace le tri alphabetique par defaut ; tout nouveau personnage detecte apparait en fin de liste tant qu'il n'a pas ete range manuellement. Absent du second selecteur (picker de comparaison), qui reste alphabetique pour eviter de reordonner silencieusement la liste principale par megarde.
- Cote Tibi Companion/Tibiscui.fr : meme fonctionnalite sur les "chips" de personnages du dashboard, avec un ordre memorise localement (independant de celui choisi en jeu, car l'export JSON du compte reste trie alphabetiquement pour un checksum stable).

## 7.1.5.9
- Correction : un donjon normal ("Recherche de groupe") pouvait ne jamais compter dans la carte "Donjons & M+" meme entierement termine (constat utilisateur : Scholomance fait a trois avec Tibiscui/Tibizcui/Tibispike, absent des trois dashboards). La version precedente exigeait, pour valider un donjon, que le DERNIER combat de boss reussi corresponde au dernier encounter connu du Bestiaire (C_EncounterJournal) - resolution qui echoue silencieusement sur certains donjons (route de boss non lineaire, mappage Bestiaire different sur un donjon classique remanie), bloquant le compteur a 0 pour tout le monde sur ce donjon. Le donjon compte desormais des qu'au moins un boss est tue pendant la session, meme regle deja appliquee aux Raids depuis la 7.1.5.7. Les runs deja effectues avant cette mise a jour ne peuvent pas etre retrouves retroactivement (rien n'avait ete enregistre au moment ou ils ont eu lieu) : seuls les prochains donjons remonteront correctement.

## 7.1.5.8
- Correction : les listes de detail evenement de Or, Temps joue, Reputation gagnee et Points de metier gagnes pouvaient accumuler des dizaines de micro-evenements par jour (chaque tick de reputation, chaque petit gain d'or, chaque segment "Monde" recoupe par un /reload), illisibles en liste plate. Ces 4 listes regroupent desormais les evenements par jour et par source/faction/activite/metier, avec une colonne "Nb" indiquant le nombre d'evenements regroupes. Quetes/Donjons & M+/Raids/Gouffres restent en detail evenement par evenement (chaque ligne porte des colonnes non additives comme le niveau ou la duree).

## 7.1.5.7
- Nouveau : les 7 cartes de la vue d'ensemble (Quetes, Or, Temps joue, Donjons & M+, Gouffres, Reputation gagnee, Points de metier gagnes) affichent desormais un detail evenement par evenement en plus du total journalier, via un nouveau bouton "Detail" sur chaque carte :
  - Quetes : nom, zone, XP gagne par quete.
  - Donjons & M+ : nom, niveau (M+), specialisation jouee, duree.
  - **Raids** : nouvelle carte dediee (le suivi ne portait avant que sur les donjons de type "Recherche de groupe"), meme detail que les donjons plus le nombre de boss tues - compte des qu'au moins un boss est tue dans la session, sans exiger un clear complet (une soiree de raid ne clot que rarement l'instance en entier).
  - Gouffres : nom, palier.
  - Reputation gagnee : detail par faction.
  - Or : source du gain (quete, marchand, hotel des ventes si le module PostBox est installe, ou autre).
  - Temps joue : repartition par activite (donjon, raid, gouffre, monde) en plus du total existant.
  - Points de metier gagnes : detail par metier.
- Ces nouveaux journaux ne couvrent que les evenements enregistres a partir de cette version : rien n'est reconstitue retroactivement pour les jours deja enregistres.
- Correction : le palier d'un gouffre pouvait ne jamais s'enregistrer dans son detail evenement (colonne vide) - le palier est desormais aussi lu en continu pendant le gouffre, pas seulement a la toute fin, ou le jeu semble parfois avoir deja referme le contexte necessaire pour le lire.
- Style : les tableaux de detail par evenement se rapprochent desormais de ceux de Tibi Companion/Tibiscui.fr - en-tetes de colonnes cliquables pour trier (avec indicateur de sens), fine ligne de separation sous les en-tetes et entre chaque ligne, decompte du nombre d'evenements affiches.
- Correction : le mini-graphique des cartes de la vue d'ensemble affichait exactement le meme contenu (7 jours) pour les periodes "Jour" et "Semaine" - "Semaine" affiche desormais une tendance par semaines, distincte de "Jour".
- Refonte visuelle de la vue d'ensemble (demande utilisateur) : "Temps joue" passe en premiere carte, grille sur 4 colonnes au lieu de 2 (cartes plus etroites), chaque carte reprend sa propre couleur (meme palette que le graphique "Toutes les metriques") pour la bordure/le chiffre/le mini-graphique au lieu d'un or uniforme, plus une icone devant chaque titre. Icones choisies parmi des textures Blizzard tres anciennes/stables mais jamais verifiees dans ce client precis - a signaler si l'une d'elles s'affiche en carre rouge "?".
- Nouveau : la fenetre est desormais redimensionnable (poignee en bas a droite, meme mecanisme que LegTracker) - la taille choisie est memorisee d'une ouverture a l'autre.
- Correction : a l'etroit (fenetre a sa taille minimale), le titre d'une carte pouvait deborder sous son bouton "Detail" (ex. "Reputation gagnee", "Points de metier gagnes") - le titre se tronque desormais proprement au lieu de chevaucher le bouton.
- Correction : des barres pouvaient s'afficher deformees (en parallelogramme) sur n'importe quelle carte, notamment "Heures jouees" - une texture de barre recyclee gardait parfois la rotation d'un ancien segment de courbe (bascule entre granularites "ligne" et "barre" sur le meme graphique). La reinitialisation de rotation est desormais systematique.
- Refonte des sections du bas (demande utilisateur) : PVP, Gouffres+Tourments (desormais une seule section combinee), Reputations et Metiers sont repliees par defaut - cliquer sur la tuile deplie son detail complet. Corrige "ca ne fait rien au clic" (Metiers, Reputations) et la sensation de carte en double (une tuile resume ET un tableau toujours affiche en dessous, sans lien entre les deux).
- Habillage plus premium des 4 sections du bas (demande utilisateur) : chaque section reprend sa propre couleur (comme les cartes du haut) sur sa bordure, son titre, ses chiffres et ses liens de haut fait, plus une icone sur sa tuile ; les 6 tableaux internes (brackets PVP, champs de bataille, gouffres, tourments, reputations, metiers) affichent desormais une fine ligne de separation entre chaque ligne.
- Correction : le detail deplie d'une section du bas (PVP, Gouffres+Tourments, Reputations, Metiers) s'affichait toujours apres les 2 lignes de tuiles, meme pour une section de la 1ere ligne (PVP) - il apparait desormais juste apres sa propre ligne. Les tuiles repliees se grisent des qu'une section est depliee, pour la mettre en valeur (bordure/titre en gris neutre, icone desaturee - un simple ajustement d'opacite restait trop discret sur fond deja tres sombre, retour utilisateur). La carte "Detail" d'une metrique (et sa liste d'evenements) reprend maintenant la couleur de la carte d'origine (ex. Raids en orange) au lieu de passer a l'or generique.

## 7.1.5.5
- Correction : dans "Toutes les metriques" et le detail par metrique, un segment de courbe (granularite Mois/Annee) pouvait s'afficher loin de sa position reelle, jusqu'a sortir du cadre du graphique, des qu'une metrique variait brutalement d'un point a l'autre - mauvais pivot de rotation du segment, corrige.
- Correction : passer le filtre de periode sur "Jour" grisait a tort les granularites Semaine/Mois de "Toutes les metriques" et du detail par metrique, qui ne dependent pourtant pas de ce filtre (chacun parcourt son propre historique complet).
- Relecture orthographe/grammaire/ponctuation des textes du module.

## 7.1.5.4
- Graphique "Toutes les metriques" : ajout d'une echelle de temps defilable. L'axe affiche desormais les dates (jour 11/09/2026, semaine, mois 09/2026, annee 2026) et une scroll bar horizontale (ou la molette) permet de remonter dans tout l'historique, avec la plage affichee rappelee sous le graphique. Fenetre par defaut calee sur la periode la plus recente : ~1 mois de jours, ~6 mois de semaines, 1 an de mois.

## 7.1.5.3
- Superposition des courbes (Evolution "Toutes les metriques" + graphique PVP) : legende desormais cliquable pour afficher/masquer chaque metrique, avec un message d'aide dedie.
- Correction : les courbes superposees zigzaguaient meme filtrees a une seule metrique - passage en barres pour les granularites Jour et Semaine (compteurs trop eparses pour une ligne lisible), la ligne restant reservee a Mois/Annee.
- Ajout de la granularite Annee aux boutons "Stats par" (deja presente sur le site/Tibi Companion).
- Correction des messages de version affiches dans le chat au chargement (plusieurs modules affichaient encore v7.0).

## 7.1.5.2
- Correction : le compagnon de gouffre (Brann Bronzebeard/Valeera Sanguinar) n'apparait plus a tort dans le tableau Reputations (il utilisait l'API "amitie" des reputations cote Blizzard).
- Correction : le "Palier max" par gouffre nomme pouvait rester bloque a 0 malgre un gouffre bien compte - reessai automatique ajoute.
- Icone officielle des hauts faits ajoutee devant le total de points, dans le bandeau personnage.

## 7.1.5.1
- PVP separe du graphique Evolution general dans son propre graphique dedie "PVP dans le temps" (granularite Jour/Semaine/Mois/Annee independante).
- Suivi quotidien ajoute pour les champs de bataille (joues/gagnes) et les arenes (jouees/gagnees), en plus des adversaires tues deja suivis.

## 7.1.5
- Reputations : suivi natif ajoute (tuile resume Suivies/Rang max/Exaltees + tableau des 10 dernieres progressions recentes), integre a l'Evolution quotidienne.
- Metiers : suivi natif ajoute (tuile resume + progressions recentes + courbe quotidienne), en miroir de la refonte visuelle du site et de Tibi Companion (icones, tri par extension du plus recent au plus ancien, regroupement des metiers a 100%).
- PVP (adversaires tues) : suivi quotidien ajoute aux cartes d'Evolution.
- Cartes d'Evolution reorganisees (statistiques generales d'abord, puis une carte par categorie dans le meme ordre que les tuiles resume).
- Detail PVP / Gouffres / Tourments / Reputation / Metiers : presentation en cartes separees, avec titre toujours visible (y compris sans donnee).

## 7.1.0
- Gouffres : total et palier max désormais rétroactifs (Statistiques Blizzard "Gouffres terminés"/"Gouffres du niveau N terminés"), avec le haut fait de palier le plus élevé affiché et cliquable sur la tuile.
- Tourments : le haut fait "échelon max" par donjon est désormais réellement cliquable (ouvre le panneau des Hauts faits) et son nom est affiché dans une colonne dédiée du tableau "Détail par Tourment".
- Détail par Tourment : correction d'un bug d'extraction du nom de donjon cassé par un espace insécable du client français (fusionnait/perdait des lignes).

## 7.0.3
- Ajout de l'icone d'addon (elle manquait, affichait un point d'interrogation dans la liste).
- Correction de bugs de langue et d'interface (UI).

## 7.0.2
- Correction de bugs d'affichage.
