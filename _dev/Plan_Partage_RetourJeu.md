# Plans : carte « Ma semaine » à partager, mode « Retour au jeu »

Rédigé le 2026-11-13, validé par Tibiscui (« fais A en premier puis B »).

**État (2026-11-13)** :
- A fait : `dashboard-shared.js` du site (`renderShareCard` = `drawShareCard` /
  `openShareCard`, bouton `data-action="share-card"`), testé dans le navigateur
  (rendu, nom masqué ou affiché, repli « téléchargée à la place » quand la
  copie est refusée) ; mêmes ajouts reportés dans la copie de Companion (qui
  avait une version plus ancienne du fichier : seuls les 3 ajouts, rien
  d'autre), Companion 2.0.27 (version, WN_VERSION, Quoi de neuf). Carte Stats
  du site + `?v=` sur `dashboard-shared.js`. Rien de commité.
- B fait : fin de `TibiSuiteAdvisor.lua` (`TibiSuite.WelcomeBackSteps`,
  `ShowWelcomeBack`), case + bouton dans Centre > Suggestions, `/ts retour`,
  `welcomeBack` et `backDays` dans `SET_KEYS`, textes EN. Simulé (étapes,
  module absent, 4 cas de détection) ; non testé en jeu. Objectif commun :
faire connaître la suite à des joueurs qui ne l'ont pas encore, sans alourdir
le core ni ajouter de dossier d'addon.

---

## A. Carte « Ma semaine » à partager (site et Companion)

**Idée.** Depuis le Dashboard, un bouton « Partager ma semaine » produit une
image soignée (Grand coffre, or gagné, temps joué, M+ / gouffres / raids,
réputations, quêtes), avec le logo et l'adresse tibiscui.fr. Le joueur la
télécharge ou la copie, puis la colle sur Discord ou un réseau social.

**Pourquoi.** Chaque image partagée montre la suite à des joueurs qui ne la
connaissent pas : c'est de la publicité gratuite et crédible.

**Ce qui existe déjà.** `dashboard-shared.js` décode l'export de Stats et
calcule tous ces chiffres par période ; le presse-papiers est déjà utilisé
(copie du code). Companion embarque une copie de ce fichier
(`src/renderer/vendor/dashboard-shared.js`).

**Contraintes du site.** Aucun traceur, aucun cookie, aucun service externe :
l'image est dessinée dans le navigateur (canvas), rien n'est envoyé nulle part.

### Lots
1. **Rendu de la carte** (`dashboard-shared.js`) : `renderShareCard(profile,
   win)` dessine une image 1200 × 630 (format des aperçus Discord et réseaux)
   dans un canvas, avec les polices déjà livrées par le site et le rouge
   #C41F3B. Choix du personnage ou du compte, de la semaine en cours ou
   précédente.
2. **Boutons** : « Télécharger (PNG) » (`canvas.toBlob`) et « Copier l'image »
   (`navigator.clipboard.write` avec `ClipboardItem`, repli sur le
   téléchargement si le navigateur refuse). Textes FR et EN synchronisés.
3. **Confidentialité** : option « masquer le nom du personnage et le
   royaume », cochée par défaut.
4. **Companion** : recopie du fichier, version, fenêtre « Quoi de neuf », et
   textes du Microsoft Store en français et en anglais.
5. **Page du site** : une ligne dans la page Dashboard et une carte « Quoi de
   neuf ».

**À vérifier.** `ClipboardItem` pour une image : pris en charge par Chrome et
Edge (donc Companion, qui tourne sous Electron) ; sur Firefox, support récent,
à tester. Le repli par téléchargement couvre les autres cas.

**Effort.** Moyen, uniquement côté site et Companion : aucun addon touché.

---

## B. Mode « Retour au jeu » (core, Conseiller)

**Idée.** À la connexion d'un personnage resté longtemps sans jouer, une
fenêtre « Bon retour » propose un parcours court et personnalisé : quoi faire
d'abord, avec un clic vers le bon module.

**Pourquoi.** À chaque patch, beaucoup de joueurs reviennent et ne savent pas
par où reprendre. C'est le public qui installe le plus d'addons.

**Ce qui existe déjà.** Le Conseiller (`TibiSuiteAdvisor.lua`, contrat
`suggestFn`, fenêtre « Tes propositions du jour ») ; la session précédente de
chaque personnage dans Stats (`rec.lastSession`) ; les API des modules
(`DgnTrackerAPI`, `LegTrackerAPI`, API de Stats, WeeklyCompass).

**Règle de prudence.** Aucun fait de jeu écrit en dur (pas de « il faut tel
ilvl pour tel contenu ») : le parcours se base uniquement sur ce que le client
donne (niveau, niveau d'objet moyen, quêtes, verrous, réputations) et sur les
données déjà vérifiées des modules.

### Lots
1. **Détection** : absence d'au moins 30 jours sur ce personnage (date de la
   dernière session de Stats, sinon un horodatage léger dans
   `TibiSuiteCharDB`). Seuil réglable, désactivable dans le Centre.
2. **Étapes calculées** (5 au plus, dans cet ordre, chacune seulement si elle
   s'applique) :
   - niveau inférieur au maximum : reprendre la campagne (LvlHistory) ;
   - niveau d'objet bas par rapport à ses autres personnages : donjons de la
     saison (DgnTracker, vue Saison) ;
   - Grand coffre de la semaine vide : ce qui le remplit le plus vite
     (WeeklyCompass) ;
   - réputations de l'extension en cours peu avancées (RenTracker) ;
   - connaissances de métier non dépensées (SkillTracker).
3. **Fenêtre** : même style que « Tes propositions du jour », un bouton par
   étape qui ouvre le module au bon endroit, une case « ne plus afficher pour
   ce personnage ».
4. **Modules absents** : une étape dont le module n'est pas installé n'est
   pas affichée (jamais d'invitation à installer quoi que ce soit en jeu).
5. **Site** : une carte « Quoi de neuf » et une ligne dans la FAQ.

**À vérifier en jeu.** La fiabilité de `GetAverageItemLevel` sur un
personnage qui vient de se connecter (valeur parfois incomplète au tout
premier instant : lecture différée de quelques secondes prévue).

**Effort.** Moyen. Un seul fichier du core touché (Conseiller) ; aucune
nouvelle SavedVariables (une clé dans `TibiSuiteCharDB`).

---

## Ordre conseillé

A d'abord (aucun risque pour les addons, effet visible dès la mise en ligne),
puis B pour la prochaine version de la suite.
