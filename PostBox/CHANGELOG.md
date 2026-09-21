# Changelog

## 7.1.5.14
- Correction : "Tout ouvrir" ne traitait qu'un courrier (ou une seule piece jointe par courrier). Cause : les courriers "Objet trouve" du Maitre de poste, tous identiques, partageaient une meme cle, et le serveur n'accepte qu'UNE prise a la fois (les suivantes, envoyees dans la meme frame, sont ignorees). La boite est maintenant parcourue du dernier au premier courrier, une piece jointe (ou l'or) par tick de 0,6 s, en lisant les emplacements en direct puisque les en-tetes ne sont pas rafraichis boite ouverte. Un emplacement est retente 3 fois au plus.
- Correction : la suppression verifie que le courrier disparait vraiment (retente une fois, puis affiche la raison du refus dans le chat), lit le courrier avant de le supprimer et utilise C_Mail.DeleteInboxItem si disponible.
- Nouveau : /pb debug active une trace de Tout ouvrir et de la suppression (une ligne par courrier), desactivee par defaut.

## 7.1.5.13
- Correction : la pastille rouge de courriers non lus pouvait rester affichee ("1") alors que la boite aux lettres etait vide. Le cache de la boite n'est qu'un instantane pris a la boite : hors de la boite, plus rien ne le rafraichissait, donc un courrier deja traite restait compte indefiniment. Le compteur exact n'est desormais affiche que boite ouverte ; boite fermee, seule la pastille "!" du core (HasNewMail, comme l'icone de courrier Blizzard) signale un nouveau courrier. Nouveau : /pb badge affiche l'etat vu par PostBox et par Blizzard (aide au diagnostic).

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
