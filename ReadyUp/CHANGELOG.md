# Changelog

## 7.6.6
- Version alignée sur la suite TibiSuite (chronomètre d'instance de LvlHistory), sans changement pour ce module.

## 7.6.5
- Version alignée sur la suite TibiSuite (correctif d'Opacity et de Standby), sans changement pour ce module.

## 7.6.4
- Version alignée sur la suite TibiSuite (prochain boss dans le chronomètre de LvlHistory), sans changement pour ce module.

## 7.6.3
- Version alignée sur la suite TibiSuite (correctifs de LegTracker et LvlHistory), sans changement pour ce module.

## 7.6.1
- Version alignée sur la suite TibiSuite (chronomètre d'instance de LvlHistory), sans changement pour ce module.

## 7.6.0
- Première version de ReadyUp : « suis-je prêt ? », vérifié pour toi avant le pull, sans rien configurer.
- Contrôles, chacun avec sa case dans les options :
  - Équipement : usure, enchantements, renfort d'armure, châsses vides (au niveau maximum, en raid, donjon mythique et arène ; enchantements et renfort décochés par défaut).
  - Consommables : nourriture, flacon ou élixir, potions, enchantement temporaire d'arme (poisons, huiles, pierres).
  - Classe et inventaire : améliorations de classe (aspect, armures, Feu intérieur, Robustesse, Intelligence des Arcanes, Marque du fauve, boucliers, auras...), familier, flèches ou balles, composants, place dans les sacs.
- Partout : solo, gouffre, donjon, donjon mythique, raid, champ de bataille et arène, chacun avec ses contrôles.
- Suivi continu : une alerte dès qu'un contrôle franchit son seuil, une fois par problème, jamais en combat. Ce qui ne va pas à la connexion est annoncé une fois. Rappel si le problème dure (10 minutes par défaut, en solo et en gouffre).
- Alerte à l'entrée en instance (« Avant le raid », « Prêt pour le donjon »...), à l'appel « Prêt ? » et chez un marchand qui répare.
- Alerte vivante : chaque ligne passe au vert quand tu règles le problème, puis « Tout est réglé ». Son discret (désactivable).
- Voyant permanent : une petite icône déplaçable reste à l'écran tant qu'il reste un problème, avec le nombre de points. Clic : détail.
- Seuils des alertes réglables dans les options : usure (alerte et critique), nourriture et flacon qui expirent bientôt, potions, enchantement d'arme qui expire, flèches ou balles, composants, fragments d'âme, place dans les sacs.
- Contrôle à chaque changement et toutes les 30 secondes ; `/readyup debug` explique pourquoi une alerte s'est affichée ou non.
- Si ReadyUp est décoché dans TibiSuite, /readyup le dit clairement.
- Aucune lecture en combat.
- Fonctionne seul ou dans la suite TibiSuite (onglet, badge, Centre, recherche).
- Un seul fichier .toc pour Midnight, Forever et Classic (Vanilla, TBC, Cata, Mists), plus un fichier pour Wrath.
