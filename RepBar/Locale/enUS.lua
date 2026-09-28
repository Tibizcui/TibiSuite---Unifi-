-- =============================================================================
-- RepBar - Locale/enUS.lua
-- Base ANGLAISE de tout client non francais. Le francais est le texte par
-- defaut embarque directement dans RepBar.lua (table RepBarL, helper D(cle,
-- valeur)) : il ne remplit que les cles restees vides.
-- Ordre de chargement (RepBar.toc) : enUS.lua, puis le fichier de la langue du
-- client (deDE.lua, esES.lua...) qui surcharge, puis RepBar.lua. Une cle
-- oubliee dans une traduction retombe donc sur l'anglais, pas sur le francais.
-- =============================================================================

if GetLocale() == "frFR" then return end
RepBarL = RepBarL or {}
local L = RepBarL

for k, v in pairs({
    -- Bar and tooltip
    FACTION = "Faction", STANDING = "Standing", PROGRESS = "Progress",
    REMAINING = "Remaining", ZONE = "Zone", RENOWN = "Renown", PARAGON = "Paragon",
    NO_FACTION = "No faction tracked", MAX = "Max",
    WARBAND = "Warband reputation", WARBAND_SHORT = "Warband",
    SESSION_GAIN = "Gained this session", REP_PER_HOUR = "Reputation per hour",
    PER_HOUR = "/h", TIME_LEFT = "Next rank in", GAINS_LEFT = "Gains left (estimate)",
    NEXT_RANK = "Rank %d:",
    CHEST_READY = "Chest ready!", CHEST_READY_TT = "Paragon chest waiting to be claimed",
    CHESTS_HEADER = "Paragon chests waiting:", CHEST_ALERT = "Paragon chest ready: %s",
    CHEST_CLICK = "|cffFFD700Click|r waypoint to the first quartermaster",
    QM = "Quartermaster", WAYPOINT_SET = "Waypoint: %s (%.1f, %.1f)",
    NO_WAYPOINT = "No known quartermaster for this faction (RenTracker data).",
    RECENT_HEADER = "Recent factions:", CURRENT = "tracked",
    NO_RECENT = "No other recent faction: earn reputation elsewhere to fill the list.",
    PINNED_ADD = "Faction pinned: %s", PINNED_DEL = "Faction unpinned: %s",
    PINNED_FULL = "Already %d pinned factions: remove one first (Alt+click its bar).",
    PIN_HINT = "|cffFFD700Click|r track  ·  |cffFFD700Alt+Click|r unpin",
    HINT = "|cffFFD700Shift+Drag|r move  ·  |cffFFD700Shift+Right-click|r options",
    HINT_CLICK = "|cffFFD700Click|r next faction  ·  |cffFFD700Right-click|r previous",
    HINT_ALT = "|cffFFD700Alt+Click|r pin  ·  |cffFFD700Ctrl+Click|r quartermaster waypoint",
    POS_SAVED = "Position saved.", POS_RESET = "Position reset.",
    SESSION_RESET = "Session reset.", SWITCH_QUEST = "Now tracking: ",
    SNAP_OFF = "Snap under XPBar turned off (bar moved by hand).",
    -- Slash / login
    SLASH_HIDDEN = "Hidden. /repbar show to display it again.",
    SLASH_HELP = " /repbar - options  |  /repbar hide/show  |  /repbar pin/unpin  |  /repbar session  |  /repbar reset",
    LOGIN_LOADED = "loaded -- type", LOGIN_TO_OPEN = "for options.",
    NO_SOCLE = "Options panel unavailable: the TibiSuite base is not loaded.",
    MM_TT_LEFT = "Left-click: show/hide", MM_TT_RIGHT = "Right-click: options",
    -- Options panel
    OPT_TITLE = "RepBar - Options",
    OPT_HINT = "|cffFFD700Shift+Drag|r the bar to move it, |cffFFD700Shift+Right-click|r to open or close this panel.",
    OPT_SEC_PRESETS = "Ready-made styles", OPT_PRESET_THIN = "Thin style (8 px)",
    OPT_PRESET_CLASSIC = "Classic style", OPT_PRESET_VERTICAL = "Vertical style",
    OPT_SEC_DIMENSIONS = "Dimensions", OPT_WIDTH = "Width", OPT_HEIGHT = "Height",
    OPT_SEC_APPEARANCE = "Appearance", OPT_OPACITY = "Background opacity (%)",
    OPT_FONTSIZE = "Text size", OPT_COL_BAR = "Fixed bar color",
    OPT_STANDCOL = "Color by standing", OPT_TICKS = "Ticks every 10%",
    OPT_SEC_DISPLAY = "Display", OPT_SHOWZONE = "Faction zone (bottom line)",
    OPT_SHOWNUM = "Values (x / y)", OPT_SHOWPCT = "Percentage",
    OPT_RATE = "Reputation per hour and time left", OPT_FLOAT = "Floating text on each gain",
    OPT_WARBAND = "Warband badge", OPT_RENOWN_REWARD = "Next renown rank reward (tooltip)",
    OPT_SEC_PARAGON = "Paragon", OPT_PARAGON_ALERT = "Flag chests waiting to be claimed",
    OPT_PARAGON_ALL = "Watch every expansion",
    OPT_PARAGON_ALL_TT = "Default: current expansion, tracked faction and pinned factions. Old expansions sometimes keep a chest waiting for years.",
    OPT_SEC_PINS = "Pinned factions",
    OPT_PINS_NOTE = "Up to 3 factions, as thin bars under the main bar. Alt+click the main bar to pin the tracked faction, Alt+click a pinned bar to remove it.",
    OPT_SHOWPINS = "Show pinned bars", OPT_PINHEIGHT = "Pinned bar height",
    OPT_PIN_CURRENT = "Pin / unpin the tracked faction", OPT_PIN_CLEAR = "Remove all pins",
    OPT_SEC_BEHAVIOR = "Behavior", OPT_SWITCHQ = "Switch on quest turn-in",
    OPT_CLICKCYCLE = "Click the bar: cycle through recent factions",
    OPT_SNAP = "Snap under XPBar",
    OPT_SNAP_TT = "The bar sits under XPBar and follows it. Moving it by hand (Shift+Drag) turns snapping off.",
    OPT_SEC_VISIBILITY = "Visibility", OPT_HIDENOFAC = "Hide when no faction is tracked",
    OPT_HIDENATIVE = "Hide the default reputation bar",
    OPT_HIDENATIVE_TT = "At max level, reputation uses Blizzard's main slot: that slot is hidden too. If XPBar already hides the default bars, RepBar leaves it to XPBar.",
    OPT_HIDECOMBAT = "Hide in combat", OPT_MOUSEOVER = "Show on mouseover only",
    OPT_SEC_ORIENTATION = "Orientation", OPT_VERTBAR = "Vertical bar",
    OPT_VERTTEXT = "Text next to the bar (vertical)", OPT_VTHICK = "Thickness (vertical)",
    OPT_VLENGTH = "Length (vertical)",
    OPT_SEC_SESSION = "Session and position", OPT_RESETSESS = "Reset session",
    OPT_RESETPOS = "Reset position",
    OPT_SEC_FLOATING = "Floating button", OPT_HIDE_OPTIONS_BTN = "Hide the Options button",
}) do L[k] = v end
