--[[----------------------------------------------------------------------------
    MiniHub - Localisation / Localization
    ------------------------------------------------------------------------
    Anglais par defaut, francais si le client est en frFR. Toute chaine
    manquante retombe sur sa cle (jamais de "nil" affiche).

    English by default, French when the client runs frFR. Any missing string
    falls back to its key (never displays "nil").
------------------------------------------------------------------------------]]

local ADDON_NAME, ns = ...

MiniHub = MiniHub or {}

--------------------------------------------------------------------------------
-- English (base)
--------------------------------------------------------------------------------
local enUS = {
    ADDON_SUBTITLE   = "Gathers your addon minimap icons into a single, tidy, collapsible container.",
    EMPTY            = "No button collected",
    EMPTY_CONFLICT   = "%s already manages minimap buttons on its own - MiniHub steps aside.",
    MSG_CONFLICT_LOGIN = "%s already manages minimap buttons - MiniHub stays out of the way (container hidden). Type /minihub to open it manually if you still want to use it.",

    -- Tooltips
    TT_LEFT_TOGGLE   = "Left-click: open / close",
    TT_RIGHT_OPTIONS = "Right-click: options",
    TT_MIDDLE_RESCAN = "Middle-click: rescan buttons",
    TT_DRAG_MOVE     = "Drag: move the button",

    -- Messages
    MSG_COMBAT_OPTIONS = "cannot open options in combat. Try again after combat.",
    MSG_RESCAN       = "rescan done (%d buttons collected).",
    MSG_RESET        = "container and main button positions reset.",
    MSG_BLOCK        = "\"%s\" is now ignored (type /reload).",
    MSG_UNBLOCK      = "\"%s\" is no longer ignored.",
    MSG_ADD          = "\"%s\" added manually.",
    MSG_IMPORT_OK    = "profile imported. Type /reload to apply.",
    MSG_IMPORT_FAIL  = "import failed: invalid string.",

    -- Slash help
    SLASH_HELP       = "commands:",
    SLASH_TOGGLE     = "open / close the container",
    SLASH_SCAN       = "rescan minimap buttons",
    SLASH_RESET      = "recenter the container and the main button",
    SLASH_CONFIG     = "open the options",
    SLASH_DEBUG      = "list the minimap children (diagnostic)",
    SLASH_BLOCK      = "ignore a button",
    SLASH_ADD        = "force-collect a button by name",

    -- Options: sections & labels
    OPT_GENERAL      = "General",
    OPT_LAYOUT       = "Layout",
    OPT_APPEARANCE   = "Appearance",
    OPT_BEHAVIOR     = "Behavior",
    OPT_ORIENTATION  = "Orientation: %s",
    OPT_VERTICAL     = "Vertical",
    OPT_HORIZONTAL   = "Horizontal",
    OPT_COLUMNS      = "Number of columns",
    OPT_ROWS         = "Number of rows",
    OPT_BUTTON_SIZE  = "Cell size",
    OPT_SPACING      = "Spacing",
    OPT_BG_OPACITY   = "Background opacity (%)",
    OPT_MAIN_SIZE    = "Main button size",
    OPT_MAIN_OPACITY = "Main button opacity (%)",
    OPT_SHOW_TITLE   = "Show the title bar",
    OPT_LOCK         = "Lock the container position",
    OPT_SHOW_MINIMAP = "Show the minimap button",
    OPT_HIDE_ZOOM    = "Hide Blizzard zoom buttons (+/-)",
    OPT_HIDE_ZOOM_TT = "Zoom stays available via the mouse wheel.",
    OPT_SHOW_MAIN    = "Show the movable main button (logo)",
    OPT_SHOW_MAIN_TT = "A logo button, movable anywhere in the UI, that opens/closes the container.",
    OPT_RESCAN       = "Rescan",
    OPT_RECENTER     = "Recenter",
    OPT_EXCL_TITLE   = "Leave on the minimap",
    OPT_EXCL_HINT    = "Tick a button to exclude it from the container.",

    -- Theme
    OPT_THEME        = "Theme: %s",
    THEME_DARK       = "WeeklyCompass dark",
    THEME_GOLD       = "TibiSuite gold",
    THEME_GLASS      = "Frosted glass",
    THEME_MINIMAL    = "Minimal",
    OPT_BG_COLOR     = "Background color",
    OPT_BORDER_COLOR = "Border color",

    -- Behavior
    OPT_HOVER_OPEN   = "Open on hover",
    OPT_HOVER_OPEN_TT= "Open the container when hovering the main button.",
    OPT_AUTO_CLOSE   = "Auto-close when the mouse leaves",
    OPT_ANIMATE      = "Fade animation on open",
    OPT_HIDE_COMBAT  = "Hide in combat",
    OPT_HIDE_INSTANCE= "Hide in dungeons/raids",
    OPT_HIDE_PETBATTLE = "Hide during pet battles",

    -- Assistant / profiles
    OPT_UNKNOWN_TITLE = "Unrecognized buttons",
    OPT_UNKNOWN_HINT  = "Buttons found on the minimap that were not collected. Tick to collect them.",
    OPT_NONE_UNKNOWN  = "None detected.",
    OPT_PROFILE_TITLE = "Profile sharing",
    OPT_EXPORT        = "Export",
    OPT_IMPORT        = "Import",
    OPT_EXPORT_HINT   = "Copy this string to share your configuration.",
    OPT_IMPORT_HINT   = "Paste a string then click Import.",

    -- Keybinding
    BINDING_HEADER    = "MiniHub",
    BINDING_TOGGLE    = "Open / close the container",
}

--------------------------------------------------------------------------------
-- Francais
--------------------------------------------------------------------------------
local frFR = {
    ADDON_SUBTITLE   = "Regroupe les icones d'addon de la minicarte dans un conteneur unique, propre et retractable.",
    EMPTY            = "Aucun bouton collecte",
    EMPTY_CONFLICT   = "%s gere deja les boutons de la minicarte - MiniHub s'efface.",
    MSG_CONFLICT_LOGIN = "%s gere deja les boutons de la minicarte - MiniHub reste en retrait (conteneur masque). Tape /minihub pour l'ouvrir manuellement si tu veux quand meme l'utiliser.",

    TT_LEFT_TOGGLE   = "Clic gauche : ouvrir / fermer",
    TT_RIGHT_OPTIONS = "Clic droit : options",
    TT_MIDDLE_RESCAN = "Clic milieu : rescanner",
    TT_DRAG_MOVE     = "Glisser : deplacer le bouton",

    MSG_COMBAT_OPTIONS = "impossible d'ouvrir les options en combat. Reessaie apres le combat.",
    MSG_RESCAN       = "rescan effectue (%d boutons collectes).",
    MSG_RESET        = "positions du conteneur et du bouton principal reinitialisees.",
    MSG_BLOCK        = "\"%s\" est desormais ignore (fais /reload).",
    MSG_UNBLOCK      = "\"%s\" n'est plus ignore.",
    MSG_ADD          = "\"%s\" ajoute manuellement.",
    MSG_IMPORT_OK    = "profil importe. Fais /reload pour appliquer.",
    MSG_IMPORT_FAIL  = "import echoue : chaine invalide.",

    SLASH_HELP       = "commandes :",
    SLASH_TOGGLE     = "ouvrir / fermer le conteneur",
    SLASH_SCAN       = "rescanner les boutons de la minicarte",
    SLASH_RESET      = "recentrer le conteneur et le bouton principal",
    SLASH_CONFIG     = "ouvrir les options",
    SLASH_DEBUG      = "lister les enfants de la minicarte (diagnostic)",
    SLASH_BLOCK      = "ignorer un bouton",
    SLASH_ADD        = "forcer la collecte d'un bouton par son nom",

    OPT_GENERAL      = "General",
    OPT_LAYOUT       = "Disposition",
    OPT_APPEARANCE   = "Apparence",
    OPT_BEHAVIOR     = "Comportement",
    OPT_ORIENTATION  = "Orientation : %s",
    OPT_VERTICAL     = "Verticale",
    OPT_HORIZONTAL   = "Horizontale",
    OPT_COLUMNS      = "Nombre de colonnes",
    OPT_ROWS         = "Nombre de lignes",
    OPT_BUTTON_SIZE  = "Taille de cellule",
    OPT_SPACING      = "Espacement",
    OPT_BG_OPACITY   = "Opacite du fond (%)",
    OPT_MAIN_SIZE    = "Taille du bouton principal",
    OPT_MAIN_OPACITY = "Opacite du bouton principal (%)",
    OPT_SHOW_TITLE   = "Afficher la barre de titre",
    OPT_LOCK         = "Verrouiller la position du conteneur",
    OPT_SHOW_MINIMAP = "Afficher le bouton sur la minicarte",
    OPT_HIDE_ZOOM    = "Masquer les boutons de zoom Blizzard (+/-)",
    OPT_HIDE_ZOOM_TT = "Le zoom reste accessible a la molette de la souris.",
    OPT_SHOW_MAIN    = "Afficher le bouton principal deplacable (logo)",
    OPT_SHOW_MAIN_TT = "Un bouton logo, deplacable partout dans l'interface, qui ouvre/ferme le conteneur.",
    OPT_RESCAN       = "Rescanner",
    OPT_RECENTER     = "Recentrer",
    OPT_EXCL_TITLE   = "Laisser sur la minicarte",
    OPT_EXCL_HINT    = "Cochez un bouton pour l'exclure du conteneur.",

    OPT_THEME        = "Theme : %s",
    THEME_DARK       = "WeeklyCompass sombre",
    THEME_GOLD       = "TibiSuite dore",
    THEME_GLASS      = "Verre depoli",
    THEME_MINIMAL    = "Minimal",
    OPT_BG_COLOR     = "Couleur du fond",
    OPT_BORDER_COLOR = "Couleur de la bordure",

    OPT_HOVER_OPEN   = "Ouvrir au survol",
    OPT_HOVER_OPEN_TT= "Ouvre le conteneur au survol du bouton principal.",
    OPT_AUTO_CLOSE   = "Fermeture auto quand la souris quitte",
    OPT_ANIMATE      = "Animation de fondu a l'ouverture",
    OPT_HIDE_COMBAT  = "Masquer en combat",
    OPT_HIDE_INSTANCE= "Masquer en donjon/raid",
    OPT_HIDE_PETBATTLE = "Masquer pendant les combats de mascottes",

    OPT_UNKNOWN_TITLE = "Boutons non reconnus",
    OPT_UNKNOWN_HINT  = "Boutons trouves sur la minicarte mais non collectes. Cochez pour les collecter.",
    OPT_NONE_UNKNOWN  = "Aucun detecte.",
    OPT_PROFILE_TITLE = "Partage de profil",
    OPT_EXPORT        = "Exporter",
    OPT_IMPORT        = "Importer",
    OPT_EXPORT_HINT   = "Copiez cette chaine pour partager votre configuration.",
    OPT_IMPORT_HINT   = "Collez une chaine puis cliquez sur Importer.",

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

-- Libelles localises du raccourci clavier (lus par l'interface Blizzard).
_G["BINDING_HEADER_MINIHUB"]      = L["BINDING_HEADER"]
_G["BINDING_NAME_MINIHUB_TOGGLE"] = L["BINDING_TOGGLE"]
