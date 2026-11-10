# Anchor : textes CurseForge

Dossier `_dev/` : jamais publié (les tags ne publient que le dossier du module).
À coller dans le formulaire de création du projet CurseForge, puis à reporter
`X-Curse-Project-ID` dans les 6 `.toc` d'Anchor et l'adresse dans le catalogue
du core (`curseUrl`) et sur le site (`home.js`, JSON-LD d'`index.html`).

## Fiche

- **Nom du projet** : Anchor
- **Catégorie principale** : Miscellaneous (ou User Interface si proposée) ; secondaires : Bags & Inventory, Map & Minimap
- **Versions du jeu** : Retail (Midnight 12.x), Classic Era, TBC, Wrath, Cataclysm, Mists, WoW Forever
- **Licence** : la même que les autres modules de la suite
- **Logo** : `Anchor/medias/Logo.png` (emblème indigo) ; image d'origine fournie par Tibiscui

## Résumé (anglais, 228 caractères sur 255)

```
Move any Blizzard window: snapping with live alignment guides, grid, undo, one layout per screen resolution and per character, loot and loot roll placement. Retail, Classic and WoW Forever. Works alongside ElvUI and EllesmereUI.
```

## Description (anglais)

```markdown
# Anchor

**Put every game window exactly where you want it.**

Anchor lets you drag the windows of the game (character sheet, bags, world map, mail, merchant, professions, collections, loot and many more) and remembers where you left them. It is built to stay out of your way: it only adds to Blizzard's own windows, never replaces them.

## What makes it different

- **Snapping with live guides**: windows snap to the screen edges and center, and to the other open windows. Alignment guides show where the window will land. Hold **Alt** to drop freely.
- **Alignment grid** while you move, with an adjustable step.
- **Undo**: the last 20 moves and size changes, one click away.
- **One layout per screen resolution**: your laptop and your desktop monitor each keep their own positions, and the right layout applies itself when you switch.
- **Account layout or per character**, with a button to copy the account layout to a character.
- **Loot placement**: the loot window drags like any other, and a Place mode shows ghost frames for the loot rolls (Need / Greed) and the bonus roll, which only appear for a few seconds.
- **Status list**: see at a glance which windows are moved, original, not loaded yet, protected or handled by another addon, and reset any of them.

## Shortcuts

- **Drag** a window: move it (Alt: no snapping)
- **Shift + right-click**: original position
- **Ctrl + mouse wheel**: window size
- **Ctrl + right-click**: original size

Commands: `/anchor` (window), `/anchor loot` (place loot), `/anchor undo`, `/anchor reset`, `/anchor probe` (check), `/anchor on|off`. Short form: `/anc`.

## Plays nice with your UI

- **ElvUI**: Anchor leaves ElvUI its loot window, loot rolls, bags and anything anchored to an ElvUI mover.
- **EllesmereUI**: when the Shifter is on, Anchor leaves it the windows of its list and keeps the others (such as the loot window).
- **BlizzMove / MoveAny**: if one of them is loaded, Anchor steps aside (a "Force" option exists, not recommended).

Protected windows are never touched, and Edit Mode elements (action bars, unit frames) are left to Edit Mode.

## Game versions

One install for Retail (Midnight), every Classic version (Classic Era, TBC, Wrath, Cataclysm, Mists) and WoW Forever: the game picks the right file. Windows that do not exist in your version are simply skipped.

## Part of TibiSuite

Anchor works on its own, with its own minimap button. Install [TibiSuite](https://www.curseforge.com/wow/addons/tibisuite) to get it as a tab of the unified bar, in the Centre and in the global search, with one single minimap button for all modules. Your settings never change between the two modes.

Languages: English, French, German, Spanish, Italian, Portuguese, Russian, Korean, Simplified and Traditional Chinese.

More on [tibiscui.fr](https://www.tibiscui.fr).
```

## Description (français)

```markdown
# Anchor

**Chaque fenêtre du jeu exactement là où tu la veux.**

Anchor te laisse glisser les fenêtres du jeu (fiche du personnage, sacs, carte du monde, courrier, marchand, métiers, collections, butin et bien d'autres) et retient où tu les as posées. Il est conçu pour rester discret : il s'ajoute aux fenêtres de Blizzard, il ne les remplace jamais.

## Ce qui le distingue

- **Magnétisme avec repères en direct** : les fenêtres s'aimantent aux bords et au centre de l'écran, et aux autres fenêtres ouvertes. Des repères montrent où la fenêtre va se poser. Tiens **Alt** pour poser librement.
- **Grille d'alignement** pendant le déplacement, avec un pas réglable.
- **Annuler** : les 20 derniers déplacements et changements de taille, en un clic.
- **Une disposition par résolution d'écran** : ton portable et ton écran de bureau gardent chacun leurs positions, et la bonne disposition s'applique toute seule quand tu changes d'écran.
- **Disposition du compte ou propre à un personnage**, avec un bouton pour copier celle du compte sur un personnage.
- **Placement du butin** : la fenêtre de butin se glisse comme les autres, et un mode Placement affiche des cadres fantômes pour les lancers de dés (Besoin / Cupidité) et le jet de bonus, qui n'apparaissent que quelques secondes.
- **Liste d'état** : tu vois d'un coup d'œil quelles fenêtres sont déplacées, d'origine, pas encore chargées, protégées ou gérées par un autre addon, et tu remets n'importe laquelle à sa place.

## Raccourcis

- **Glisser** une fenêtre : la déplacer (Alt : sans aimant)
- **Maj + clic droit** : position d'origine
- **Ctrl + molette** : taille de la fenêtre
- **Ctrl + clic droit** : taille d'origine

Commandes : `/anchor` (fenêtre), `/anchor loot` (placer le butin), `/anchor undo`, `/anchor reset`, `/anchor probe` (vérification), `/anchor on|off`. Forme courte : `/anc`.

## Respecte ton interface

- **ElvUI** : Anchor lui laisse sa fenêtre de butin, ses lancers de dés, ses sacs et tout ce qui est accroché à un « mover » ElvUI.
- **EllesmereUI** : quand le Shifter est actif, Anchor lui laisse les fenêtres de sa liste et garde les autres (la fenêtre de butin, par exemple).
- **BlizzMove / MoveAny** : si l'un d'eux est chargé, Anchor se met en retrait (une option « Forcer » existe, déconseillée).

Les fenêtres protégées ne sont jamais touchées, et les éléments du mode Édition (barres d'action, cadres d'unité) restent au mode Édition.

## Versions du jeu

Une seule installation pour Retail (Midnight), toutes les versions Classic (Classic Era, TBC, Wrath, Cataclysm, Mists) et WoW Forever : le jeu choisit le bon fichier. Les fenêtres absentes de ta version sont simplement ignorées.

## Membre de TibiSuite

Anchor marche seul, avec son propre bouton minimap. Installe [TibiSuite](https://www.curseforge.com/wow/addons/tibisuite) pour le retrouver en onglet de la barre unifiée, dans le Centre et dans la recherche globale, avec un seul bouton minimap pour tous les modules. Tes réglages ne changent jamais entre les deux modes.

Langues : anglais, français, allemand, espagnol, italien, portugais, russe, coréen, chinois simplifié et traditionnel.

Plus d'infos sur [tibiscui.fr](https://www.tibiscui.fr).
```
