--[[----------------------------------------------------------------------------
    MiniHub - Localisation / Localization
    ------------------------------------------------------------------------
    Anglais = base pour toutes les langues, francais si le client est en frFR.
    Les autres langues (Locales\*.lua, chargees juste apres) surchargent la
    meme table. Toute chaine manquante retombe sur l'anglais, puis sur sa cle
    (jamais de "nil" affiche).

    English is the base for every language, French on frFR clients. Other
    languages (Locales\*.lua, loaded right after) patch the same table.
------------------------------------------------------------------------------]]

local ADDON_NAME, ns = ...

MiniHub = MiniHub or {}

--------------------------------------------------------------------------------
-- English (base)
--------------------------------------------------------------------------------
local enUS = {
    ADDON_SUBTITLE   = "Gathers your addon minimap icons into a single, tidy, collapsible container.",
    PAUSED_TEXT = "%s already sorts the minimap buttons. MiniHub is paused to avoid conflicts: it touches no button.",
    PAUSED_OVERRIDE = "Use MiniHub anyway",
    PAUSED_OVERRIDE_TT = "MiniHub takes the buttons back. Then turn off button sorting in the other addon, or both will fight over them.",
    MSG_OVERRIDE_ON = "MiniHub takes the buttons back despite %s (turn off its button sorting).",
    MSG_OVERRIDE_OFF = "MiniHub pauses again and leaves the buttons to %s (/reload for a clean state).",
    OPT_IGNORE_CONFLICT = "Use MiniHub even with EllesmereUI / ElvUI / Tukui",
    OPT_IGNORE_CONFLICT_TT = "By default MiniHub pauses when one of these addons already sorts the minimap buttons. Tick only if you turned off their button sorting.",
    MSG_CONFLICT_LOGIN = "%s already sorts the minimap buttons: MiniHub is paused to avoid conflicts. Its options let you use it anyway.",
    SEC_POSITION = "Position",
    OPT_SNAP_BOTTOM = "Place under the minimap",
    OPT_SNAP_LEFT = "Place left of the minimap",
    OPT_SNAP_RIGHT = "Place right of the minimap",
    OPT_POSITION_NOTE = "Follows the minimap where it really is. The hub then stays free: drag its title bar to move it (unless positions are locked).",
    EMPTY            = "No button collected",
    LOGIN_LOADED     = "loaded. Type |cFFFFD700/minihub|r to open it.",
    SEARCH_TITLE     = "Search",
    CAT_OTHER        = "Other",
    CAT_FAVORITES    = "Favorites",

    -- Tooltips
    TT_LEFT_TOGGLE   = "Left-click: open / close",
    TT_RIGHT_OPTIONS = "Right-click: options",
    TT_MIDDLE_RESCAN = "Middle-click: rescan buttons",
    TT_DRAG_MOVE     = "Drag: move the button",
    TT_COMPARTMENT   = "From the addon compartment",
    QB_TITLE         = "MiniHub - Quick bar",
    QB_HINT          = "Your favorite buttons, always visible. Drag the edge to move the bar.",

    -- Messages
    MSG_RESCAN       = "rescan done (%d buttons collected).",
    MSG_RESET        = "positions reset (under the minimap).",
    MSG_BLOCK        = "\"%s\" is back on the minimap.",
    MSG_UNBLOCK      = "\"%s\" goes back into the hub.",
    MSG_ADD          = "\"%s\" added manually.",
    MSG_IMPORT_OK    = "profile imported and applied.",
    MSG_IMPORT_FAIL  = "import failed: invalid string (it must start with MH1:).",
    MSG_COMPARTMENT_FAIL = "the compartment entry of %s did not respond.",

    -- Diagnostic
    DUMP_HEADER      = "minimap children (name | shown | collected | verdict):",
    DUMP_SHOWN       = "shown",
    DUMP_HIDDEN      = "hidden",
    DUMP_BUTTON      = "button",
    DUMP_IGNORED     = "ignored",

    -- Slash help
    SLASH_HELP       = "commands:",
    SLASH_TOGGLE     = "open / close the container",
    SLASH_MANAGE     = "button manager (favorites, order, minimap)",
    SLASH_SCAN       = "rescan minimap buttons",
    SLASH_RESET      = "put the container back under the minimap",
    SLASH_CONFIG     = "open the options",
    SLASH_DEBUG      = "list the minimap children (diagnostic)",
    SLASH_BLOCK      = "leave a button on the minimap",
    SLASH_UNBLOCK    = "put a button back into the hub",
    SLASH_ADD        = "force-collect a button by name",

    -- Options: sections
    OPT_TITLE        = "Options",
    SEC_BUTTONS      = "Buttons",
    SEC_DISPLAY      = "Display",
    OPT_APPEARANCE   = "Appearance",
    SEC_QUICKBAR     = "Favorites and quick bar",
    SEC_DRAWER       = "Drawer mode",
    OPT_BEHAVIOR     = "Behavior",
    SEC_SOURCES      = "Extra sources",
    SEC_FLOATING     = "Floating controls",
    SEC_MAIN_BUTTON  = "Minimap button and main button",
    OPT_PROFILE_TITLE = "Profile sharing",
    SEC_ACTIONS      = "Actions",

    -- Options: buttons section
    OPT_MANAGE       = "Manage buttons...",
    OPT_MANAGE_NOTE  = "Favorites, manual order, buttons to leave on the minimap and unrecognized buttons.",
    OPT_RESCAN       = "Rescan",
    OPT_OPEN_PANEL   = "Open the MiniHub options",

    -- Options: display
    OPT_VIEW         = "View: %s",
    VIEW_GRID        = "Icon grid",
    VIEW_LIST        = "List (icon + name)",
    OPT_ORIENTATION  = "Grid orientation: %s",
    OPT_VERTICAL     = "Vertical",
    OPT_HORIZONTAL   = "Horizontal",
    OPT_PER_LINE     = "Buttons per row / column",
    OPT_LIST_ROWS    = "Rows per column (list)",
    OPT_BUTTON_SIZE  = "Cell size",
    OPT_SPACING      = "Spacing",
    OPT_GROUP        = "Sort by addon category",
    OPT_GROUP_TT     = "Uses the category declared by each addon. In list view, every category gets its own heading.",
    OPT_SHOW_TITLE   = "Show the title bar",
    OPT_HIDE_ZOOM    = "Hide Blizzard zoom buttons (+/-)",
    OPT_HIDE_ZOOM_TT = "Zoom stays available via the mouse wheel.",

    -- Options: appearance
    OPT_THEME        = "Theme: %s",
    THEME_DARK       = "WeeklyCompass dark",
    THEME_GOLD       = "TibiSuite gold",
    THEME_GLASS      = "Frosted glass",
    THEME_MINIMAL    = "Minimal",
    OPT_BG_COLOR     = "Background color",
    OPT_BORDER_COLOR = "Border color",
    OPT_BG_OPACITY   = "Background opacity (%)",
    OPT_ANIMATE      = "Fade animation on open",

    -- Options: quick bar
    OPT_QUICKBAR     = "Favorites in a quick bar",
    OPT_QUICKBAR_TT  = "Your favorite buttons leave the hub and stay visible in a small bar, even when the hub is closed.",
    OPT_QUICKBAR_VERTICAL = "Vertical quick bar",
    OPT_QUICKBAR_NOTE = "Pick favorites with the star in the button manager. Without the quick bar, favorites come first in the hub.",

    -- Options: drawer
    OPT_DRAWER       = "Drawer mode",
    OPT_DRAWER_TT    = "The hub sticks to the edge of the minimap and slides out when the mouse hovers the minimap. It follows the minimap if you move it.",
    OPT_DRAWER_SIDE  = "Drawer side: %s",
    SIDE_LEFT        = "left",
    SIDE_BOTTOM      = "bottom",
    SIDE_RIGHT       = "right",

    -- Options: behavior
    OPT_LOCK         = "Lock positions",
    OPT_AUTO_CLOSE   = "Auto-close when the mouse leaves",
    OPT_HIDE_COMBAT  = "Hide in combat",
    OPT_HIDE_INSTANCE = "Hide in dungeons/raids",
    OPT_HIDE_PETBATTLE = "Hide during pet battles",

    -- Options: sources
    OPT_COLLECT_TS   = "Put the TibiSuite button in the hub",
    OPT_COLLECT_TS_TT = "The TibiSuite minimap button joins the other buttons in MiniHub.",
    OPT_COMPARTMENT  = "Include addon compartment entries",
    OPT_COMPARTMENT_TT = "Addons that only live in the Blizzard addon compartment get their own button in the hub. Addons already in the hub are not duplicated.",

    -- Options: floating controls / main button
    OPT_HIDE_FLOAT_OPTIONS = "Hide the floating Options button",
    OPT_HIDE_FLOAT_SEARCH  = "Hide the floating search field",
    OPT_SHOW_MINIMAP = "Show the minimap button",
    OPT_SHOW_MAIN    = "Show the movable main button (logo)",
    OPT_SHOW_MAIN_TT = "A logo button, movable anywhere in the UI, that opens/closes the container.",
    OPT_HOVER_OPEN   = "Open on hover",
    OPT_HOVER_OPEN_TT = "Open the container when hovering the main button.",
    OPT_MAIN_SIZE    = "Main button size",
    OPT_MAIN_OPACITY = "Main button opacity (%)",

    -- Options: profile / actions
    OPT_PROFILE_NOTE = "Layout and appearance only (not the button lists). Export, copy with Ctrl+C, or paste a code then Import.",
    OPT_EXPORT       = "Export",
    OPT_IMPORT       = "Import",
    OPT_RECENTER     = "Put back under the minimap",
    OPT_RESET_ORDER  = "Reset the manual order",

    -- Manager
    MGR_TITLE        = "Buttons",
    MGR_COUNT        = "(%d in the hub)",
    MGR_LEGEND       = "Star: favorite.  Arrows: order.  Box: leave on the minimap.",
    MGR_FAV_TT       = "Favorite: first in the hub, or in the quick bar if enabled.",
    MGR_UP           = "Move up",
    MGR_DOWN         = "Move down",
    MGR_KEEP_TT      = "Leave this button on the minimap (out of the hub).",
    MGR_ON_MINIMAP   = "left on the minimap",
    MGR_HIDDEN_BY_ADDON = "hidden by its addon",
    MGR_ADD          = "Add",
    OPT_UNKNOWN_TITLE = "Unrecognized buttons",
    OPT_UNKNOWN_HINT  = "Buttons found on the minimap that were not collected automatically.",
    OPT_NONE_UNKNOWN  = "None detected.",

    -- Keybinding
    BINDING_HEADER    = "MiniHub",
    BINDING_TOGGLE    = "Open / close the container",
}

--------------------------------------------------------------------------------
-- Francais
--------------------------------------------------------------------------------
local frFR = {
    ADDON_SUBTITLE   = "Regroupe les icônes d'addon de la minicarte dans un conteneur unique, propre et rétractable.",
    PAUSED_TEXT = "%s range déjà les boutons de la minicarte. MiniHub est en pause pour éviter les conflits : il ne touche à aucun bouton.",
    PAUSED_OVERRIDE = "Utiliser MiniHub quand même",
    PAUSED_OVERRIDE_TT = "MiniHub reprend les boutons. Désactive alors le rangement des boutons dans l'autre addon, sinon les deux se les disputent.",
    MSG_OVERRIDE_ON = "MiniHub reprend les boutons malgré %s (pense à désactiver son rangement de boutons).",
    MSG_OVERRIDE_OFF = "MiniHub repasse en pause et laisse les boutons à %s (/reload pour un état propre).",
    OPT_IGNORE_CONFLICT = "Utiliser MiniHub même avec EllesmereUI / ElvUI / Tukui",
    OPT_IGNORE_CONFLICT_TT = "Par défaut, MiniHub se met en pause quand un de ces addons range déjà les boutons de la minicarte. Coche seulement si tu as désactivé leur rangement de boutons.",
    MSG_CONFLICT_LOGIN = "%s range déjà les boutons de la minicarte : MiniHub se met en pause pour éviter les conflits. Ses options permettent de l'utiliser quand même.",
    SEC_POSITION = "Position",
    OPT_SNAP_BOTTOM = "Placer sous la minicarte",
    OPT_SNAP_LEFT = "Placer à gauche de la minicarte",
    OPT_SNAP_RIGHT = "Placer à droite de la minicarte",
    OPT_POSITION_NOTE = "Suit la minicarte là où elle se trouve vraiment. Le hub reste ensuite libre : glisse sa barre de titre pour le déplacer (sauf positions verrouillées).",
    EMPTY            = "Aucun bouton collecté",
    LOGIN_LOADED     = "chargé. Tape |cFFFFD700/minihub|r pour l'ouvrir.",
    SEARCH_TITLE     = "Recherche",
    CAT_OTHER        = "Autres",
    CAT_FAVORITES    = "Favoris",

    TT_LEFT_TOGGLE   = "Clic gauche : ouvrir / fermer",
    TT_RIGHT_OPTIONS = "Clic droit : options",
    TT_MIDDLE_RESCAN = "Clic milieu : rescanner",
    TT_DRAG_MOVE     = "Glisser : déplacer le bouton",
    TT_COMPARTMENT   = "Depuis le compartiment d'addons",
    QB_TITLE         = "MiniHub - Barre rapide",
    QB_HINT          = "Tes boutons favoris, toujours visibles. Glisse le bord pour déplacer la barre.",

    MSG_RESCAN       = "scan terminé (%d boutons collectés).",
    MSG_RESET        = "positions réinitialisées (sous la minicarte).",
    MSG_BLOCK        = "« %s » retourne sur la minicarte.",
    MSG_UNBLOCK      = "« %s » revient dans le hub.",
    MSG_ADD          = "« %s » ajouté manuellement.",
    MSG_IMPORT_OK    = "profil importé et appliqué.",
    MSG_IMPORT_FAIL  = "import impossible : code invalide (il doit commencer par MH1:).",
    MSG_COMPARTMENT_FAIL = "l'entrée de compartiment de %s n'a pas répondu.",

    DUMP_HEADER      = "enfants de la minicarte (nom | affiché | collecté | verdict) :",
    DUMP_SHOWN       = "affiché",
    DUMP_HIDDEN      = "masqué",
    DUMP_BUTTON      = "bouton",
    DUMP_IGNORED     = "ignoré",

    SLASH_HELP       = "commandes :",
    SLASH_TOGGLE     = "ouvrir / fermer le conteneur",
    SLASH_MANAGE     = "gestionnaire de boutons (favoris, ordre, minicarte)",
    SLASH_SCAN       = "rescanner les boutons de la minicarte",
    SLASH_RESET      = "replacer le conteneur sous la minicarte",
    SLASH_CONFIG     = "ouvrir les options",
    SLASH_DEBUG      = "lister les enfants de la minicarte (diagnostic)",
    SLASH_BLOCK      = "laisser un bouton sur la minicarte",
    SLASH_UNBLOCK    = "remettre un bouton dans le hub",
    SLASH_ADD        = "forcer la collecte d'un bouton par son nom",

    OPT_TITLE        = "Options",
    SEC_BUTTONS      = "Boutons",
    SEC_DISPLAY      = "Affichage",
    OPT_APPEARANCE   = "Apparence",
    SEC_QUICKBAR     = "Favoris et barre rapide",
    SEC_DRAWER       = "Mode tiroir",
    OPT_BEHAVIOR     = "Comportement",
    SEC_SOURCES      = "Sources supplémentaires",
    SEC_FLOATING     = "Contrôles flottants",
    SEC_MAIN_BUTTON  = "Bouton de minicarte et bouton principal",
    OPT_PROFILE_TITLE = "Partage de profil",
    SEC_ACTIONS      = "Actions",

    OPT_MANAGE       = "Gérer les boutons...",
    OPT_MANAGE_NOTE  = "Favoris, ordre manuel, boutons à laisser sur la minicarte et boutons non reconnus.",
    OPT_RESCAN       = "Rescanner",
    OPT_OPEN_PANEL   = "Ouvrir les options de MiniHub",

    OPT_VIEW         = "Vue : %s",
    VIEW_GRID        = "Grille d'icônes",
    VIEW_LIST        = "Liste (icône + nom)",
    OPT_ORIENTATION  = "Orientation de la grille : %s",
    OPT_VERTICAL     = "verticale",
    OPT_HORIZONTAL   = "horizontale",
    OPT_PER_LINE     = "Boutons par ligne / colonne",
    OPT_LIST_ROWS    = "Lignes par colonne (liste)",
    OPT_BUTTON_SIZE  = "Taille des cellules",
    OPT_SPACING      = "Espacement",
    OPT_GROUP        = "Trier par catégorie d'addon",
    OPT_GROUP_TT     = "Utilise la catégorie déclarée par chaque addon. En vue liste, chaque catégorie a son propre titre.",
    OPT_SHOW_TITLE   = "Afficher la barre de titre",
    OPT_HIDE_ZOOM    = "Masquer les boutons de zoom Blizzard (+/-)",
    OPT_HIDE_ZOOM_TT = "Le zoom reste disponible à la molette.",

    OPT_THEME        = "Thème : %s",
    THEME_DARK       = "Sombre WeeklyCompass",
    THEME_GOLD       = "Or TibiSuite",
    THEME_GLASS      = "Verre dépoli",
    THEME_MINIMAL    = "Minimal",
    OPT_BG_COLOR     = "Couleur du fond",
    OPT_BORDER_COLOR = "Couleur de la bordure",
    OPT_BG_OPACITY   = "Opacité du fond (%)",
    OPT_ANIMATE      = "Fondu à l'ouverture",

    OPT_QUICKBAR     = "Favoris dans une barre rapide",
    OPT_QUICKBAR_TT  = "Tes boutons favoris sortent du hub et restent visibles dans une petite barre, même hub fermé.",
    OPT_QUICKBAR_VERTICAL = "Barre rapide verticale",
    OPT_QUICKBAR_NOTE = "Choisis tes favoris avec l'étoile du gestionnaire de boutons. Sans barre rapide, les favoris passent en tête du hub.",

    OPT_DRAWER       = "Mode tiroir",
    OPT_DRAWER_TT    = "Le hub reste collé au bord de la minicarte et sort quand la souris survole la minicarte. Il suit la minicarte si tu la déplaces.",
    OPT_DRAWER_SIDE  = "Côté du tiroir : %s",
    SIDE_LEFT        = "gauche",
    SIDE_BOTTOM      = "dessous",
    SIDE_RIGHT       = "droite",

    OPT_LOCK         = "Verrouiller les positions",
    OPT_AUTO_CLOSE   = "Fermeture automatique quand la souris quitte",
    OPT_HIDE_COMBAT  = "Masquer en combat",
    OPT_HIDE_INSTANCE = "Masquer en donjon / raid",
    OPT_HIDE_PETBATTLE = "Masquer pendant les combats de mascottes",

    OPT_COLLECT_TS   = "Ranger le bouton TibiSuite dans le hub",
    OPT_COLLECT_TS_TT = "Le bouton de minicarte TibiSuite rejoint les autres boutons dans MiniHub.",
    OPT_COMPARTMENT  = "Inclure les addons du compartiment",
    OPT_COMPARTMENT_TT = "Les addons présents seulement dans le compartiment d'addons de Blizzard reçoivent leur propre bouton dans le hub. Les addons déjà présents ne sont pas dupliqués.",

    OPT_HIDE_FLOAT_OPTIONS = "Masquer le bouton flottant Options",
    OPT_HIDE_FLOAT_SEARCH  = "Masquer le champ de recherche flottant",
    OPT_SHOW_MINIMAP = "Afficher le bouton de minicarte",
    OPT_SHOW_MAIN    = "Afficher le bouton principal déplaçable (logo)",
    OPT_SHOW_MAIN_TT = "Un bouton logo, déplaçable partout dans l'interface, qui ouvre / ferme le conteneur.",
    OPT_HOVER_OPEN   = "Ouvrir au survol",
    OPT_HOVER_OPEN_TT = "Ouvre le conteneur au survol du bouton principal.",
    OPT_MAIN_SIZE    = "Taille du bouton principal",
    OPT_MAIN_OPACITY = "Opacité du bouton principal (%)",

    OPT_PROFILE_NOTE = "Disposition et apparence seulement (pas les listes de boutons). Exporte, copie avec Ctrl+C, ou colle un code puis Importer.",
    OPT_EXPORT       = "Exporter",
    OPT_IMPORT       = "Importer",
    OPT_RECENTER     = "Replacer sous la minicarte",
    OPT_RESET_ORDER  = "Réinitialiser l'ordre manuel",

    MGR_TITLE        = "Boutons",
    MGR_COUNT        = "(%d dans le hub)",
    MGR_LEGEND       = "Étoile : favori.  Flèches : ordre.  Case : laisser sur la minicarte.",
    MGR_FAV_TT       = "Favori : en tête du hub, ou dans la barre rapide si elle est activée.",
    MGR_UP           = "Monter",
    MGR_DOWN         = "Descendre",
    MGR_KEEP_TT      = "Laisser ce bouton sur la minicarte (hors du hub).",
    MGR_ON_MINIMAP   = "laissé sur la minicarte",
    MGR_HIDDEN_BY_ADDON = "masqué par son addon",
    MGR_ADD          = "Ajouter",
    OPT_UNKNOWN_TITLE = "Boutons non reconnus",
    OPT_UNKNOWN_HINT  = "Boutons trouvés sur la minicarte mais pas collectés automatiquement.",
    OPT_NONE_UNKNOWN  = "Aucun détecté.",

    BINDING_HEADER    = "MiniHub",
    BINDING_TOGGLE    = "Ouvrir / fermer le conteneur",
}

--------------------------------------------------------------------------------
-- Construction de la table L
--------------------------------------------------------------------------------
local L = {}
for k, v in pairs(enUS) do L[k] = v end
if GetLocale() == "frFR" then
    for k, v in pairs(frFR) do L[k] = v end
end
-- Chaine manquante -> on renvoie la cle (jamais nil).
setmetatable(L, { __index = function(_, k) return k end })

MiniHub.L = L
ns.L = L
