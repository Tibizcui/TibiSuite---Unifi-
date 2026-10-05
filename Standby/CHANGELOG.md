# Changelog

## 7.1.5.41
- Aucun changement fonctionnel dans ce module : bump de version pour aligner le numero sur l'ensemble de la suite (voir Stats 7.1.5.41 : export des absences de Standby, carte Absences du Dashboard).

## 7.1.5.40
Premiere version de Standby, l'ecran d'absence de TibiSuite.

**Ecran**
- Se declenche quand le personnage passe Absent, apres un delai reglable (1 s par defaut).
- Quatre mises en page : Vitrine (horloge, messages recus, tuiles, carte du personnage), Fiche, Epuree, Economie (noir, images par seconde bridees).
- Trois fonds : Scene (le monde visible, camera qui tourne lentement, interface masquee), illustration d'extension (images du journal des aventures du jeu, rien n'est embarque dans l'addon), noir.
- Tuiles : grande chambre forte, experience et repos (XP/h via XPBar), concentration (via SkillTracker), cle mythique, reputation suivie, reinitialisations, courrier.
- Journal des messages recus pendant l'absence (chuchotements, Battle.net, guilde, groupe), jamais sauvegarde sur le disque.

**Suite**
- Tuile A faire ce soir : quetes hebdo et quotidiennes (DailyTracker), hebdos de reputation (RenTracker), sources de connaissance de metier (SkillTracker), raids encore libres pour un legendaire (LegTracker).
- Tuile Mes personnages : les autres personnages qui attendent quelque chose (recompense de la grande chambre forte via WeeklyCompass, concentration pleine via SkillTracker, repos plein via LvlHistory).
- Diaporama (option) : alternance Vitrine / Fiche, et nouvelle illustration toutes les N minutes.

**Fiche du personnage**
- Nouvelle mise en page Fiche : grand personnage au centre, equipement en deux colonnes (icone, nom a la couleur de la qualite, niveau d'objet, enchantement, gemmes, chasses vides signalees) et panneau de statistiques.
- Vitrine : titre sous le nom, specialisation, niveau d'objet et statistiques secondaires sous la carte du personnage (options).
- Personnage en 3D plus grand, affiche a pied meme quand le joueur est sur sa monture.

**Securite**
- S'ecarte tout seul : file prete, champ de bataille, appel, convocation, invitation, duel, echange, combat, mort, ecran de chargement, cinematique, et toute fenetre Blizzard importante (menu du jeu, fenetres de confirmation).
- Jamais d'entree en combat. Pas de capture du clavier ni d'Echap (pieges de taint connus).
- Reglages d'origine (images par seconde, son d'ambiance, camera) notes avant toute modification et retablis au retour, a la deconnexion et au login suivant en cas de crash.
- Mode sur automatique si le jeu refuse de masquer l'interface : un voile la recouvre a la place.
- Se met en retrait quand l'ecran d'absence d'ElvUI est actif.

**Suite**
- Onglet dans la barre TibiSuite, recherche globale, ligne /ts doctor, StandbyAPI (IsActive, GetTotals).
- Commandes : /standby (options), /standby test (apercu 15 s), on, off, probe (verification en jeu).
- 10 langues. Non teste dans un vrai client WoW : a valider en jeu.
