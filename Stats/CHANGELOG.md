# Changelog

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
