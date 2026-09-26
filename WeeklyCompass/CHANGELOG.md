# Changelog

## 7.1.5.22
- Nouvelle fiche detaillee : clic gauche sur le nom d'un personnage. Panneau accole au tableau, fleches pour passer d'un personnage a l'autre, Echap pour fermer.
- En-tete : modele 3D anime du personnage connecte (glisser pour le tourner), bandeau classe et race pour les autres, niveau, specialisation, niveau d'objet.
- Equipement : les 16 emplacements, niveau d'objet colore par piste d'amelioration, infobulle de l'objet au survol. Enchantement manquant et chasse vide signales en rouge.
- Ensemble de raid : nom, pieces portees (ex. 4/5), bonus 2 et 4 pieces, raid d'origine et extension, badge "saison en cours" ou "saison precedente".
- Statistiques secondaires, grille du Grand Coffre (niveau d'objet de chaque emplacement debloque), verrouillages de raid et monnaies de la saison.
- Banque de Bataillon : le montant n'est lu que sur un personnage qui y a acces (suite de quetes validee), ce qui evite les faux zeros.
- Correction : la piste d'amelioration "Mythe" n'etait pas reconnue sur un client francais (couleur du niveau d'objet du Grand Coffre).

## 7.1.5.21
- Nouvel onglet "Personnages" : niveau, specialisation, niveau d'objet equipe, or, XP de repos, cle mythique+, score M+ et verrouillages de raid de tous tes personnages, sur une seule vue. Ces donnees ne sont pas remises a zero au reset : chaque personnage garde sa derniere fiche.
- Verrouillages de raid : une case "N raids", et le detail boss par boss avec le temps restant avant le reset dans l'infobulle. Un verrouillage expire disparait de lui-meme, meme si le personnage ne s'est pas reconnecte.
- Ligne de total : or de tous les personnages, plus la banque de Bataillon (relevee a son ouverture), nombre de raids verrouilles.
- Tri : clic sur un en-tete de colonne pour trier (niveau d'objet, or, score...), second clic pour inverser.
- Clic droit sur un en-tete pour masquer une colonne. Nouvelle section "Tableau" dans les options : grouper les personnages par royaume, reafficher toutes les colonnes.
- Cle et score M+ : affiches seulement quand le jeu renvoie une vraie valeur, jamais de zero invente.
- Infobulles plus lisibles, avec leur propre mise en forme : raids en gras, progression alignee a droite (verte si complete), difficulte en couleur (Mythique, Heroique, Normal, Outil de raids), une seule ligne de reset commune.
- Ligne de total mise en valeur (bandeau, montants en or) et icone de piece d'or a la place de "po".
- Gouffres et Traque : le rang s'affiche directement dans la case, ex. "1775/4200 (R3)".
- Banque de Bataillon : un releve a 0 n'est plus jamais retenu (le jeu renvoyait 0 banque pleine), le total indique alors d'ouvrir la banque plutot qu'un faux montant.

## 7.1.5.20
- Infobulles sur toutes les cases : libelle complet, statut, recompense et date de mise a jour. Sur le Grand Coffre, le detail de chaque emplacement et ce qu'il reste a faire pour le prochain (ex. "encore 1 donjon").
- Clic droit sur le nom d'un personnage : le masquer, le reafficher, ou l'oublier (il revient a sa prochaine connexion). Nouvelle section "Personnages" dans les options pour afficher les masques ou tout reafficher.
- Deux personnages du meme nom sur des royaumes differents sont enfin distingues : le royaume s'affiche en gris a cote du nom.
- Recompense du Grand Coffre deduite pour les personnages pas reconnectes depuis le reset : s'ils avaient debloque au moins un emplacement, la case affiche "A recuperer ?", signalee comme une deduction.
- La colonne Repaires disparait : le jeu n'expose aucun compteur hebdomadaire pour eux, elle restait toujours a "?".
- Panneau d'options traduit dans toutes les langues de l'addon, et accents retablis dans les textes francais.

## 7.1.5.19
- Grand Coffre calque sur la fenetre du jeu : la colonne "Mythique+" devient "Donjons", car la ligne de Blizzard compte aussi les donjons heroiques, mythiques et des Marcheurs du temps, pas seulement les cles M+.
- La colonne "Suivi" disparait : c'etait une ligne interne du Grand Coffre que la fenetre du jeu n'affiche jamais. Elle est aussi retiree chez les rerolls pas reconnectes.
- Nouvelle colonne "Recompense" : "A recuperer" s'affiche pour chaque personnage qui a une recompense du Grand Coffre en attente de choix. La colonne n'apparait que si au moins un personnage est concerne, et la case se vide des que le choix est fait.
- Les en-tetes de colonnes reprennent toujours le libelle le plus recent, meme si un reroll pas reconnecte garde un ancien nom en memoire.
- Une case sans compteur affiche son texte (ex. "A recuperer", "Rang 20") au lieu d'un simple statut.
- Dashboard TibiSuite et Tibi Companion : memes corrections d'en-tetes sur la carte "Cette semaine".

## 7.1.5.18
- Gouffres : suivi des Fragments de cle de coffre face au plafond hebdomadaire (ex. 35/600) et du renom de Gouffres de la saison.
- Traque : suivi de la progression du rang de Traque.
- Repaires : toujours en attente, le jeu n'expose pas encore de compteur hebdomadaire pour eux (affiches "?", jamais de chiffre invente).
- Les activites sont desormais pilotees par la donnee : les identifiants de monnaies et de renom sont declares dans un seul fichier, ce qui permettra de suivre les prochaines saisons sans reecrire le code.
- Correction : les rerolls pas reconnectes n'affichent plus d'anciennes colonnes "?" en double a cote des nouvelles.
- La semaine de tout le Bataillon est incluse dans le code d'export de Stats : elle apparait sur le Dashboard TibiSuite (tibiscui.fr) et dans Tibi Companion, avec les personnages pas revus depuis le reset signales comme "a rafraichir".
- Textes mis a jour : plus aucune reference a une saison precise dans les messages de connexion et les descriptions.

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
- Relecture orthographe/grammaire/ponctuation : correction d'un accord au pluriel dans un texte affiche.

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
