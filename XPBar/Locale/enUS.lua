-- =============================================================================
-- XPBar - Locale/enUS.lua
-- Base ANGLAISE de tout client non francais. Le francais est le texte par
-- defaut embarque directement dans XPBar.lua (table XPBarL, motif
-- "L.CLE = L.CLE or valeur") : il ne remplit que les cles restees vides.
-- Ordre de chargement (XPBar.toc) : enUS.lua, puis le fichier de la langue du
-- client (deDE.lua, esES.lua...) qui surcharge, puis XPBar.lua. Une cle
-- oubliee dans une traduction retombe donc sur l'anglais, pas sur le francais.
-- =============================================================================

if GetLocale() == "frFR" then return end
XPBarL = XPBarL or {}
local L = XPBarL

L["LEVEL"]            = "Level"
L["LEVEL_SHORT"]       = "Lv"
L["XP"]                = "XP"
L["PROGRESS"]          = "Progress"
L["REMAINING"]         = "Remaining"
L["RESTED"]            = "Rested"
L["QUESTS"]            = "Quests"
L["QUESTS_DONE"]       = "Quests completed"
L["SESSION"]           = "Session"
L["XP_PER_HOUR"]       = "XP/hour"
L["XP_PER_HOUR_ROLL"]  = "XP/h (recent)"
L["TIME_LEFT"]         = "Time left"
L["PLAYED"]            = "Played"
L["LEVELS_GAINED"]     = "Levels gained"
L["QUESTS_TURNED"]     = "Quests turned in"
L["HINT"]              = "|cffFFD700Shift+Drag|r move  ·  |cffFFD700Shift+Right-click|r options"
L["POS_SAVED"]         = "Position saved."
L["POS_RESET"]         = "Position reset."
L["SESSION_RESET"]     = "Session reset."
L["XP_DISABLED"]       = "XP locked"
L["COLON"]             = ": "

-- Options (ancien panneau, conserve en secours)
L["OPT_TAB"]         = "Options"
L["OPT_WIDTH"]       = "Width:"
L["OPT_HEIGHT"]      = "Height:"
L["OPT_COLORS"]      = "Colors"
L["OPT_OPACITY"]     = "Background opacity:"
L["OPT_FONTSIZE"]    = "Text size:"
L["OPT_PLAYED"]      = "Time played"
L["OPT_LEVELING"]    = "Time left & XP/hour"
L["OPT_COMPLETED"]   = "Completed quests & Rested"
L["OPT_ROLLING"]     = "XP/h over recent period"
L["OPT_INCBAR"]      = "Incomplete quests bar"
L["OPT_CLOSE"]       = "Close"
L["OPT_VERTTEXT"]    = "Text next to bar (vertical)"
L["OPT_VTHICK"]      = "Thickness:"
L["OPT_VLENGTH"]     = "Length:"
L["DEBUG_CHILDREN"]  = "MainMenuBar children:"

-- Options (panneau unifie)
L["OPT_TITLE"]           = "XPBar - Options"
L["OPT_HINT"]            = "|cffFFD700Shift+Drag|r on the bar to move it, |cffFFD700Shift+Right-click|r to open or close this panel."
L["OPT_SEC_DIMENSIONS"]  = "Dimensions"
L["OPT_WIDTH_2"]         = "Width"
L["OPT_HEIGHT_2"]        = "Height"
L["OPT_SEC_APPEARANCE"]  = "Appearance"
L["OPT_OPACITY_2"]       = "Background opacity (%)"
L["OPT_FONTSIZE_2"]      = "Text size"
L["OPT_COL_BAR"]         = "XP bar color"
L["OPT_COL_QUEST"]       = "Completed quests color"
L["OPT_COL_RESTED"]      = "Rested color"
L["OPT_COL_INC"]         = "Incomplete quests color"
L["OPT_DISPLAY"]         = "Display"
L["OPT_PLAYED_2"]        = "Total played time"
L["OPT_SESSION"]         = "Session time"
L["OPT_XPPERHOUR"]       = "XP per hour"
L["OPT_LEVELING_2"]      = "Estimated time to next level"
L["OPT_ROLLING_2"]       = "XP/h over the last 15 minutes"
L["OPT_COMPLETED_2"]     = "Completed quests (%)"
L["OPT_RESTED_TXT"]      = "Rested XP (%)"
L["OPT_INCBAR_2"]        = "Incomplete quests bar"
L["OPT_SEC_VISIBILITY"]  = "Visibility"
L["OPT_SHOWBAR"]         = "Show the bar"
L["OPT_MAXLEVEL"]        = "Show at max level"
L["OPT_HIDENATIVE"]      = "Hide native bars (XP and reputation)"
L["OPT_HIDECOMBAT"]      = "Hide in combat"
L["OPT_HIDEVEHICLE"]     = "Hide in vehicle"
L["OPT_MOUSEOVER"]       = "Show on mouseover only"
L["OPT_SEC_ORIENTATION"] = "Orientation"
L["OPT_VERTBAR"]         = "Vertical bar"
L["OPT_VERTTEXT_2"]      = "Text next to the bar (vertical)"
L["OPT_VTHICK_2"]        = "Thickness (vertical)"
L["OPT_VLENGTH_2"]       = "Length (vertical)"
L["OPT_SEC_SESSION"]     = "Session"
L["OPT_RESETRELOAD"]     = "Reset session on every /reload"
L["OPT_RESETSESS"]       = "Reset session"
L["OPT_RESETPOS"]        = "Reset position"
L["OPT_SEC_FLOATING"]    = "Floating button"
L["OPT_HIDE_OPTIONS_BTN"] = "Hide the Options button"

-- Slash / login / debug
L["SLASH_HIDDEN"]   = "Hidden. /xpbar show to show it again."
L["SLASH_HELP"]     = " /xpbar - options  |  /xpbar hide/show  |  /xpbar session  |  /xpbar reset"
L["SLASH_HELP_DBG"] = "  /xpbar debug - inspect the native XP frames"
L["LOGIN_LOADED"]   = "loaded -- type"
L["LOGIN_TO_OPEN"]  = "for the options."
L["DEBUG_HEADER"]   = "Native XP frames:"
L["DEBUG_HIDDEN"]   = "hidden"
L["DEBUG_MISSING"]  = "missing"

-- Bouton minimap (mode standalone uniquement)
L["MM_TT_LEFT"]  = "Left click: show/hide"
L["MM_TT_RIGHT"] = "Right click: options"

-- Lot 3 : progression enrichie, historique, reputation au niveau max, styles
for k, v in pairs({
    QUEST_XP = "Completed quests XP", PROJ_XP = "In-progress quests XP",
    QUEST_LEVELUP = "Turning in your completed quests is enough to level up!",
    LEVEL_TIME = "Time on this level", PREV_LEVEL = "Level %d completed in",
    KILLS_LEFT = "Kills left (estimate)", QUESTS_LEFT = "Quests left (estimate)",
    LEVEL_REACHED = "Level %d reached: level %d took %s of played time.",
    HISTORY_HEADER = "Played time per level (%s):",
    HISTORY_EMPTY = "No level recorded for this character yet (level up once with XPBar enabled).",
    NO_WATCHED_REP = "No reputation watched", PARAGON = "Paragon", RENOWN = "Renown",
    OPT_SEC_PROGRESS = "Progress",
    OPT_QUESTXP = "Real XP of completed quests (orange)",
    OPT_PROJECTION = "In-progress quests projection",
    OPT_RESTZONE = "Rested bonus zone and marker",
    OPT_TICKS = "Ticks every 10%", OPT_FLOATXP = "Floating text on each XP gain",
    OPT_ESTIMATES = "Kills and quests left (tooltip)",
    OPT_REPATMAX = "Watched reputation at max level",
    OPT_REPATMAX_TT = "At max level, the bar shows your watched reputation (the one ticked in the Reputation panel) instead of disappearing.",
    OPT_CLASSCOLOR = "Bar in your class color",
    OPT_SEC_PRESETS = "Ready-made styles", OPT_PRESET_THIN = "Thin style (8 px)",
    OPT_PRESET_CLASSIC = "Classic style", OPT_PRESET_VERTICAL = "Vertical style",
    OPT_COL_INC = "In-progress quests color",
    SLASH_HELP = " /xpbar - options  |  /xpbar hide/show  |  /xpbar session  |  /xpbar history  |  /xpbar reset",
}) do L[k] = v end
