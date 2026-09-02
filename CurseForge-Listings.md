# TibiSuite — CurseForge Listing Content

This file gathers everything needed to publish/update the CurseForge pages for
**TibiSuite** and its 13 addons. Each entry has:
- a **Short Summary** (English only — this is the one-liner shown in CurseForge
  search results / addon manager, keep it under ~200 characters),
- a **Full Description**, written first in **English**, then in **French**.

Every addon works **standalone** (its own minimap button, its own settings) **or**
as an integrated module of the **TibiSuite** suite (single shared minimap button,
unified tab bar, load-on-demand). Installing both the standalone addon and
TibiSuite is safe — they auto-detect each other and never duplicate UI.

---

## 0. TibiSuite (the Suite)

**Short Summary (English):**
The unified hub for the whole Tibiscui addon family — one minimap button, one tab bar, load only the modules you check.

### Full Description — English

TibiSuite is the shared core that ties every Tibiscui addon together into a
single, lightweight experience. Instead of a dozen separate minimap buttons
and windows, you get **one** minimap icon and **one** unified tab bar giving
access to every module you've enabled.

**Key features**
- Single minimap button + AddonCompartment entry for the whole suite.
- Unified, movable, lockable tab bar (vertical or horizontal), one accent
  color per module.
- **Load-on-demand**: only the modules you tick in the options actually load
  — unchecked ones cost zero memory/CPU.
- Central options panel to enable/disable every module, reinstall a module's
  saved data, and adjust shared settings (minimap angle, bar scale, lock).
- Global search bar that queries every loaded module at once.
- Any standalone Tibiscui addon (DailyTracker, PostBox, Stats, etc.)
  automatically detects TibiSuite if it's installed and merges into the
  shared bar instead of showing its own separate button — no conflict, no
  duplicate data, ever.

Install TibiSuite first, then tick the modules you want from its options
panel — or install any module standalone and add TibiSuite later, it will
pick it up automatically on the next reload.

### Full Description — Français

TibiSuite est le socle commun qui relie tous les addons Tibiscui en une seule
expérience légère. Plutôt qu'une dizaine de boutons et de fenêtres séparés,
vous obtenez **un seul** bouton minicarte et **une seule** barre d'onglets
unifiée donnant accès à tous les modules activés.

**Fonctionnalités principales**
- Un seul bouton minicarte + une entrée dans le compartiment d'addons pour
  toute la suite.
- Barre d'onglets unifiée, déplaçable, verrouillable (verticale ou
  horizontale), une couleur d'accent par module.
- **Chargement à la demande** : seuls les modules cochés dans les options se
  chargent réellement — les autres ne consomment ni mémoire ni CPU.
- Panneau d'options central pour activer/désactiver chaque module,
  réinstaller les données d'un module, et régler les paramètres communs
  (angle minicarte, échelle de la barre, verrouillage).
- Barre de recherche globale qui interroge tous les modules chargés en même
  temps.
- Tout addon Tibiscui installé en standalone (DailyTracker, PostBox, Stats,
  etc.) détecte automatiquement TibiSuite s'il est présent et vient s'ajouter
  à la barre commune au lieu d'afficher son propre bouton séparé — aucun
  conflit, aucune donnée dupliquée.

Installez TibiSuite en premier puis cochez les modules voulus dans ses
options — ou installez n'importe quel module en standalone et ajoutez
TibiSuite plus tard, il sera détecté automatiquement au reload suivant.

---

## 1. DailyTracker

**Short Summary (English):**
Automatic daily & weekly quest tracker for Midnight and The War Within, with manual entries and reset timers.

### Full Description — English

DailyTracker keeps track of your daily and weekly quests automatically,
detecting completion straight from `C_QuestLog` — no manual clicking
required for quests the game already knows about.

**Key features**
- Auto-detects completed daily & weekly quests for Midnight and The War
  Within.
- Three sections: Weekly / Daily / One-time.
- Faction filter, "still to do" filter, and collapsible groups (Main /
  Secondary / PvP).
- Manual tracking entries for anything the game doesn't expose through the
  quest log.
- Reset countdown timers (daily and weekly), global completion counter.
- Built for performance: pooled frames (no memory leaks) and throttled
  refresh.
- Full French/English localization.

Slash commands: `/dt` or `/daily`.

### Full Description — Français

DailyTracker suit vos quêtes quotidiennes et hebdomadaires automatiquement,
en détectant leur validation directement via `C_QuestLog` — aucun clic
manuel n'est nécessaire pour les quêtes déjà connues du jeu.

**Fonctionnalités principales**
- Détection automatique des quêtes quotidiennes et hebdomadaires terminées,
  pour Midnight et The War Within.
- Trois sections : Hebdomadaire / Quotidien / Ponctuel.
- Filtre par faction, filtre "à faire", groupes repliables (Principale /
  Secondaire / PvP).
- Suivi manuel pour tout ce que le jeu n'expose pas via le journal de
  quêtes.
- Minuteurs de reset (quotidien et hebdomadaire), compteur global de
  complétion.
- Pensé pour la performance : pool de frames (sans fuite mémoire) et
  rafraîchissement limité.
- Localisation complète français/anglais.

Commandes : `/dt` ou `/daily`.

---

## 2. DgnTracker

**Short Summary (English):**
Tracks every dungeon, raid, delve and Torghast entrance across all expansions, from Vanilla to Midnight.

### Full Description — English

DgnTracker is your one-stop log of instance entrances — dungeons, raids,
delves and Torghast — covering **every expansion from Vanilla to Midnight**.

**Key features**
- Tabs for Dungeons, Raids, Delves, Torghast and Torment content.
- Full expansion coverage, with collapsible groups per expansion.
- Optional automatic waypoint (TomTom-compatible) placed when you enter a
  tracked instance.
- Clean, compact list view designed for quick lookups.

Slash commands: `/dg` or `/tibidgn`.

### Full Description — Français

DgnTracker est votre journal centralisé des entrées d'instances — donjons,
raids, gouffres et Torghast — couvrant **toutes les extensions, de Vanilla à
Midnight**.

**Fonctionnalités principales**
- Onglets Donjons, Raids, Gouffres, Torghast et contenu de Tourment.
- Couverture complète de toutes les extensions, groupes repliables par
  extension.
- Pose automatique et optionnelle d'un point de repère (compatible TomTom) à
  l'entrée d'une instance suivie.
- Vue en liste compacte, pensée pour une consultation rapide.

Commandes : `/dg` ou `/tibidgn`.

---

## 3. LairLens

**Short Summary (English):**
Real-time group audit and reward-relevance overlay for Lairs (patch 12.1) — see who's pulling their weight.

### Full Description — English

LairLens brings clarity to group Lair runs: a live audit panel plus a
history dashboard so you always know what happened and whether the loot was
worth it.

**Key features**
- Live group audit panel during Lair encounters (patch 12.1 content).
- Auto-hides outside of Lairs, fades out in combat to stay unobtrusive.
- Reward-relevance check: quickly see if what dropped actually matters for
  your characters.
- Run history dashboard, account-wide (each run is tagged by owning
  character).
- Movable, lockable, resizable panel.

Slash commands: `/lairlens` or `/ll`.

### Full Description — Français

LairLens apporte de la clarté à vos runs de groupe en Repaire : un panneau
d'audit en direct et un tableau de bord d'historique, pour toujours savoir ce
qui s'est passé et si le butin en valait la peine.

**Fonctionnalités principales**
- Panneau d'audit de groupe en direct pendant les rencontres de Repaire
  (contenu du patch 12.1).
- Masquage automatique hors des Repaires, s'estompe en combat pour rester
  discret.
- Vérification de la pertinence des récompenses : voyez en un coup d'œil si
  ce qui est tombé est utile pour vos personnages.
- Tableau de bord d'historique des runs, à l'échelle du compte (chaque run
  est associé au personnage propriétaire).
- Panneau déplaçable, verrouillable et redimensionnable.

Commandes : `/lairlens` ou `/ll`.

---

## 4. LegTracker

**Short Summary (English):**
Account-wide legendary item tracker across every expansion — status, quest chains and components, at a glance.

### Full Description — English

LegTracker keeps track of every legendary item across every expansion, for
your **entire account** at once — no more wondering which alt has which
legendary.

**Key features**
- Vertical tabs by expansion (Midnight at the top), each with its expansion
  icon.
- Full account-wide scan: shows exactly which of your known characters
  currently holds each legendary.
- Status per item (obtained / missing), quest-chain progress, and a
  component checklist.
- "How to obtain" notes for each component, right inside the detail panel.
- Special-case handling for tricky legendaries (e.g. Sulfuras): checks
  equipped slot, bags, bank and reagent bank, not just one location.

Slash commands: `/lt`.

### Full Description — Français

LegTracker suit tous les objets légendaires de toutes les extensions, pour
**l'ensemble de votre compte** en une seule fois — plus besoin de deviner
quel personnage détient quelle légendaire.

**Fonctionnalités principales**
- Onglets verticaux par extension (Midnight en haut), chacun avec son icône
  d'extension.
- Scan complet du compte : indique précisément lequel de vos personnages
  connus détient actuellement chaque légendaire.
- Statut par objet (obtenu / manquant), progression de la chaîne de quêtes,
  et liste des composants.
- Notes "comment obtenir" pour chaque composant, directement dans le
  panneau de détail.
- Gestion des cas particuliers (ex. Sulfuras) : vérifie l'emplacement
  équipé, les sacs, la banque et la banque de réactifs, pas un seul
  emplacement.

Commandes : `/lt`.

---

## 5. LvlHistory

**Short Summary (English):**
Session tracker for leveling and farming — XP/hour, zones, dungeon runs, best M+ keys, all logged automatically.

### Full Description — English

LvlHistory logs your leveling and farming sessions in detail, so you can
look back at exactly how (and how fast) you progressed.

**Key features**
- Two tracking modes: Leveling and Farming, switchable per character.
- Session log: XP/hour, zones visited, total time played.
- Dungeon tracking: run counts, a detailed log per run, your best Mythic+
  key per dungeon and your best timed run.
- Persistent history that survives reloads and relogs, with incremental
  autosave every 5 minutes.

Slash commands: `/lvlh`.

### Full Description — Français

LvlHistory enregistre vos sessions de leveling et de farm en détail, pour
pouvoir revoir précisément comment (et à quelle vitesse) vous avez progressé.

**Fonctionnalités principales**
- Deux modes de suivi : Leveling et Farm, permutables par personnage.
- Journal de session : XP/heure, zones visitées, temps de jeu total.
- Suivi des donjons : nombre de runs, journal détaillé par run, meilleure
  clé Mythique+ par donjon et meilleur temps chronométré.
- Historique persistant qui survit aux reloads et reconnexions, avec
  sauvegarde incrémentale toutes les 5 minutes.

Commandes : `/lvlh`.

---

## 6. MiniHub

**Short Summary (English):**
Gathers every addon's minimap icon into one tidy, collapsible container — a cleaner minimap in one click.

### Full Description — English

MiniHub cleans up your minimap by collecting every third-party addon icon
into a single, retractable panel — no more icon soup around the minimap.

**Key features**
- Smart, whitelist-pattern detection of real addon buttons (plus direct
  LibDBIcon integration), while leaving map "pin" addons (TomTom,
  HandyNotes, Questie...) untouched.
- Configurable grid: orientation, columns/rows, cell size, spacing, 4
  built-in visual themes.
- Movable and lockable panel, optional auto-close on mouse-leave, optional
  hover-to-open.
- Can hide the Blizzard zoom buttons (mouse wheel zoom still works).
- Export/import your visual profile as a simple string to share your setup.
- **Smart with other UI packs**: automatically detects ElvUI, Tukui or
  EllesmereUI and steps aside instead of fighting them for the same
  buttons, since they already manage minimap icons themselves.

Slash commands: `/minihub` or `/mh`.

### Full Description — Français

MiniHub nettoie votre minicarte en regroupant toutes les icônes d'addons
tiers dans un panneau unique et rétractable — fini la soupe d'icônes autour
de la minicarte.

**Fonctionnalités principales**
- Détection intelligente par motifs (liste blanche) des vrais boutons
  d'addon, plus une intégration directe LibDBIcon, tout en laissant
  tranquilles les addons de "pins" cartographiques (TomTom, HandyNotes,
  Questie...).
- Grille configurable : orientation, colonnes/lignes, taille de cellule,
  espacement, 4 thèmes visuels intégrés.
- Panneau déplaçable et verrouillable, fermeture automatique optionnelle
  quand la souris quitte la zone, ouverture au survol optionnelle.
- Peut masquer les boutons de zoom Blizzard (le zoom à la molette reste
  disponible).
- Export/import de votre profil visuel sous forme de simple chaîne de
  texte, pour partager votre configuration.
- **Compatible avec les autres UI complètes** : détecte automatiquement
  ElvUI, Tukui ou EllesmereUI et s'efface au lieu d'entrer en conflit avec
  eux sur les mêmes boutons, puisqu'ils gèrent déjà eux-mêmes les icônes de
  la minicarte.

Commandes : `/minihub` ou `/mh`.

---

## 7. PostBox

**Short Summary (English):**
Advanced mailbox manager: mass-open everything, bulk delete, a contact book and full mail statistics.

### Full Description — English

PostBox is a full rewrite of the mailbox experience: open everything in one
click, manage your contacts, and track exactly how much gold moves through
your mailbox.

**Key features**
- **Open All**: takes every attached gold and item across your inbox in
  one go, with a bag-space safety check and a do-not-want auto-return list.
- Multi-select mail (Shift for a range, Ctrl for "same sender"), then
  process or delete the selection in bulk.
- Contact book ("Black Book") with saved contact presets and a "recently
  used" recipients list for faster sending.
- Full mail statistics dashboard: gold received/sent, auction sold/bought,
  top senders, and a 7-day history chart.
- Do-Not-Want list: items you never want to keep get auto-returned to
  sender instead of cluttering your bags.
- Unread-mail badge shown directly on the TibiSuite tab.

Slash commands: `/postbox` or `/pb`.

### Full Description — Français

PostBox est une réécriture complète de la gestion du courrier : tout ouvrir
en un clic, gérer vos contacts, et suivre précisément l'or qui transite par
votre boîte aux lettres.

**Fonctionnalités principales**
- **Tout ouvrir** : récupère tout l'or et tous les objets joints de la boîte
  de réception en une fois, avec vérification de la place en sacs et retour
  automatique des objets indésirables.
- Sélection multiple de courriers (Maj pour une plage, Ctrl pour "même
  expéditeur"), puis traitement ou suppression groupée de la sélection.
- Carnet de contacts ("Black Book") avec préréglages enregistrés et liste
  des destinataires récents pour envoyer plus vite.
- Tableau de bord statistique complet : or reçu/envoyé, ventes/achats
  d'enchères, meilleurs expéditeurs, et un historique sur 7 jours.
- Liste "objets indésirables" : les objets que vous ne voulez jamais garder
  sont automatiquement retournés à l'expéditeur au lieu d'encombrer vos
  sacs.
- Badge de courrier non lu affiché directement sur l'onglet TibiSuite.

Commandes : `/postbox` ou `/pb`.

---

## 8. RenTracker

**Short Summary (English):**
Reputation tracker spanning 13 expansions, from Vanilla to Midnight, with auto zone-based tracking.

### Full Description — English

RenTracker follows every faction reputation you care about, across **13
expansions** — from Vanilla all the way to Midnight.

**Key features**
- Collapsible groups: Main, Secondary and PvP factions.
- Mini progress bars per faction, with full Renown and Paragon support.
- Automatically switches the tracked faction based on the zone you're in.
- Checklist for weekly, unique and daily reputation-granting quests.

Slash commands: `/rt`.

### Full Description — Français

RenTracker suit toutes les réputations de faction qui vous intéressent, sur
**13 extensions** — de Vanilla jusqu'à Midnight.

**Fonctionnalités principales**
- Groupes repliables : factions Principales, Secondaires et JcJ.
- Mini-barres de progression par faction, avec prise en charge complète du
  Renom et du Paragon.
- Bascule automatique de la faction suivie selon la zone où vous vous
  trouvez.
- Liste des quêtes de réputation hebdomadaires, uniques et quotidiennes.

Commandes : `/rt`.

---

## 9. RepBar

**Short Summary (English):**
A smarter reputation bar that replaces the native one and auto-switches faction by zone and on quest turn-in.

### Full Description — English

RepBar replaces Blizzard's native reputation bar with one that actually
follows what you're doing: it switches faction automatically based on your
zone (via RenTracker) and whenever you turn in a quest.

**Key features**
- Drop-in replacement for the native reputation bar.
- Auto-switches the tracked faction by zone and on quest completion.
- Supports Renown, Friendship, Paragon and the classic reputation system.
- Shift+Drag to reposition, Shift+Right-click to open options.

Slash commands: `/repbar`.

### Full Description — Français

RepBar remplace la barre de réputation native de Blizzard par une barre qui
suit vraiment ce que vous faites : elle change de faction automatiquement
selon votre zone (via RenTracker) et à chaque validation de quête.

**Fonctionnalités principales**
- Remplacement direct de la barre de réputation native.
- Bascule automatique de la faction suivie selon la zone et à la
  validation d'une quête.
- Prend en charge le Renom, l'Amitié, le Paragon et le système de
  réputation classique.
- Maj+Glisser pour déplacer, Maj+Clic droit pour ouvrir les options.

Commandes : `/repbar`.

---

## 10. SkillTracker (Métiers)

**Short Summary (English):**
Tracks profession progress per expansion for every character on your account, current tier or the full picture.

### Full Description — English

SkillTracker follows your professions expansion by expansion, for **every
character** on your account, so you always know exactly what's left to max
out.

**Key features**
- Three views: current expansion, all expansions (expandable per
  profession), and a full account overview.
- Progress shown as current/max and percentage, per profession and per
  expansion.
- Unspent Knowledge Points tracked and broken down by expansion when spread
  across several tiers.
- Multi-select expansion filter on the "still to finish" list.

Slash commands: `/skilltracker` or `/skt`.

### Full Description — Français

SkillTracker suit vos métiers extension par extension, pour **tous les
personnages** de votre compte, afin de toujours savoir précisément ce qu'il
reste à maximiser.

**Fonctionnalités principales**
- Trois vues : extension en cours, toutes les extensions (dépliables par
  métier), et une vue d'ensemble du compte.
- Progression affichée en actuel/maximum et en pourcentage, par métier et
  par extension.
- Points de compétence non dépensés suivis, avec répartition par extension
  quand ils sont répartis sur plusieurs paliers.
- Filtre à sélection multiple par extension sur la liste "à finir".

Commandes : `/skilltracker` ou `/skt`.

---

## 11. Stats

**Short Summary (English):**
Autonomous per-character daily tracker — quests, gold, dungeons, playtime — with a full dashboard and web export.

### Full Description — English

Stats quietly records your activity every day, per character: quests
completed, gold gained/spent, dungeons & Mythic+ runs, and time played. It
then turns that history into a real dashboard, not just a number.

**Key features**
- Fully autonomous event-driven tracker — nothing to configure, it just
  works from the moment it's loaded.
- Dashboard with an overview grid, a detailed per-metric view (with
  min/max/average), and character-vs-character comparison.
- Cumulative view with class-colored, stacked bar charts showing exactly
  who contributed what.
- Weekly gold aligned to the actual raid reset, not the calendar week.
- **One-click, account-wide export code**: generates a single code covering
  every character on your account — no need to log into each alt separately
  to build your web dashboard.
- Paste that code on [tibiscui.fr/Dashboard.html](https://tibiscui.fr) for a
  full browser-based dashboard — nothing is ever sent to a server, the code
  is decoded and rendered entirely in your own browser.

Slash commands: `/stats` (or `/ts stats` through TibiSuite).

### Full Description — Français

Stats enregistre discrètement votre activité chaque jour, par personnage :
quêtes terminées, or gagné/dépensé, donjons & Mythique+, et temps de jeu.
Cet historique devient ensuite un vrai tableau de bord, pas juste un
chiffre.

**Fonctionnalités principales**
- Suivi entièrement autonome, piloté par les événements du jeu — rien à
  configurer, ça fonctionne dès le chargement.
- Tableau de bord avec vue d'ensemble en grille, vue détaillée par
  métrique (avec min/max/moyenne), et comparaison entre personnages.
- Vue cumulée avec graphiques en colonnes empilées et colorées par classe,
  montrant précisément qui a contribué quoi.
- Or hebdomadaire calé sur le vrai reset des raids, pas sur la semaine
  calendaire.
- **Code d'export compte en un clic** : génère un seul code couvrant tous
  les personnages de votre compte — plus besoin de se reconnecter sur
  chaque personnage pour construire son tableau de bord web.
- Collez ce code sur [tibiscui.fr/Dashboard.html](https://tibiscui.fr) pour
  un tableau de bord complet dans le navigateur — rien n'est jamais envoyé à
  un serveur, le code est décodé et affiché entièrement dans votre propre
  navigateur.

Commandes : `/stats` (ou `/ts stats` via TibiSuite).

---

## 12. WeeklyCompass

**Short Summary (English):**
One unified weekly dashboard showing exactly what's left to do to maximize your weekly rewards.

### Full Description — English

WeeklyCompass answers one question at a glance: "what do I still need to do
this week?" — across every system that matters, for every character on your
account.

**Key features**
- Single, unified weekly dashboard covering Season 1 and Season 2 content.
- Account-wide view: see every character's weekly status in one place.
- Replaces checking half a dozen separate systems/addons with one glance.

Slash commands: `/wc` or `/weeklycompass`.

### Full Description — Français

WeeklyCompass répond à une seule question en un coup d'œil : "que me
reste-t-il à faire cette semaine ?" — pour tous les systèmes qui comptent,
sur tous les personnages de votre compte.

**Fonctionnalités principales**
- Tableau de bord hebdomadaire unique et unifié, couvrant le contenu des
  Saisons 1 et 2.
- Vue à l'échelle du compte : le statut hebdomadaire de chaque personnage en
  un seul endroit.
- Remplace la vérification d'une demi-douzaine de systèmes/addons séparés
  par un seul coup d'œil.

Commandes : `/wc` ou `/weeklycompass`.

---

## 13. XPBar

**Short Summary (English):**
Advanced XP bar with rested XP, session stats, XP/hour and a time-to-level estimate.

### Full Description — English

XPBar replaces the default Blizzard XP bar with one that actually tells you
something useful about how your leveling session is going.

**Key features**
- Level, XP, Rested XP and quest-XP tracking.
- Session stats: XP/hour (instant and rolling average), estimated time
  left to level up, quests turned in, levels gained, and time played.
- Shift+Drag to reposition, Shift+Right-click to open options.

Slash commands: `/xpbar`.

### Full Description — Français

XPBar remplace la barre d'XP par défaut de Blizzard par une barre qui vous
donne vraiment des informations utiles sur le déroulement de votre session
de leveling.

**Fonctionnalités principales**
- Suivi du niveau, de l'XP, de l'XP de repos et de l'XP de quête.
- Statistiques de session : XP/heure (instantané et moyenne glissante),
  temps restant estimé avant le niveau suivant, quêtes rendues, niveaux
  gagnés, et temps joué.
- Maj+Glisser pour déplacer, Maj+Clic droit pour ouvrir les options.

Commandes : `/xpbar`.
