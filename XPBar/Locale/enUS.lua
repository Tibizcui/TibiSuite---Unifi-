-- =============================================================================
-- XPBar - Locale/enUS.lua
-- Surcharge EN. Le francais est le texte par defaut embarque directement dans
-- XPBar.lua (table XPBarL, motif "L.CLE = L.CLE or valeur") : ce fichier ne
-- fournit que ce qui differe. Peut se charger avant ou apres XPBar.lua, dans
-- n'importe quel ordre (voir commentaire dans XPBar.lua).
-- =============================================================================

if GetLocale() ~= "enUS" and GetLocale() ~= "enGB" then return end
XPBarL = XPBarL or {}
local L = XPBarL

L["LEVEL"]            = "Level"
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

-- Options (panneau standalone)
L["OPT_TITLE"]       = "XPBar - Options"
L["OPT_TAB"]         = "Options"
L["OPT_HINT"]        = "|cffFFD700Shift+Drag|r to move   |cffFFD700Shift+Right-click|r to open/close"
L["OPT_WIDTH"]       = "Width:"
L["OPT_HEIGHT"]      = "Height:"
L["OPT_COLORS"]      = "Colors"
L["OPT_COL_BAR"]     = "XP bar"
L["OPT_COL_QUEST"]   = "Quests"
L["OPT_COL_RESTED"]  = "Rested"
L["OPT_COL_INC"]     = "Incomplete"
L["OPT_OPACITY"]     = "Background opacity:"
L["OPT_FONTSIZE"]    = "Text size:"
L["OPT_DISPLAY"]     = "Display"
L["OPT_PLAYED"]      = "Time played"
L["OPT_SESSION"]     = "Session time"
L["OPT_LEVELING"]    = "Time left & XP/hour"
L["OPT_COMPLETED"]   = "Completed quests & Rested"
L["OPT_ROLLING"]     = "XP/h over recent period"
L["OPT_INCBAR"]      = "Incomplete quests bar"
L["OPT_MAXLEVEL"]    = "Show at max level"
L["OPT_RESETRELOAD"] = "Reset session on /reload"
L["OPT_HIDENATIVE"]  = "Hide native XP bar"
L["OPT_HIDECOMBAT"]  = "Hide in combat"
L["OPT_HIDEVEHICLE"] = "Hide in vehicle"
L["OPT_MOUSEOVER"]   = "Show on mouseover only"
L["OPT_CLOSE"]       = "Close"
L["OPT_RESETPOS"]    = "Reset position"
L["OPT_RESETSESS"]   = "Reset session"
L["OPT_SEC_ORIENTATION"] = "Orientation"
L["OPT_VERTBAR"]         = "Vertical bar"
L["OPT_VERTTEXT"]        = "Text next to bar (vertical)"
L["OPT_VTHICK"]          = "Thickness:"
L["OPT_VLENGTH"]         = "Length:"

-- Slash / login / debug
L["SLASH_HIDDEN"]   = "Hidden. /xpbar show to show it again."
L["SLASH_HELP"]      = " /xpbar - options  |  /xpbar hide/show  |  /xpbar session  |  /xpbar reset"
L["SLASH_HELP_DBG"] = "  /xpbar debug - identify native XP frames"
L["LOGIN_LOADED"]   = "loaded -- type"
L["LOGIN_TO_OPEN"]  = "for the options."
L["DEBUG_HEADER"]   = "Detected XP frames:"
L["DEBUG_HIDDEN"]   = "hidden"
L["DEBUG_MISSING"]  = "missing"
L["DEBUG_CHILDREN"] = "MainMenuBar children:"

-- Options (panneau integre TibiSuite "Midnight")
L["OPT_SEC_DIMENSIONS"] = "Dimensions"
L["OPT_WIDTH_2"]        = "Width"
L["OPT_HEIGHT_2"]       = "Height"
L["OPT_PLAYED_2"]       = "Total played time"
L["OPT_LEVELING_2"]     = "Estimated time to level"
L["OPT_COMPLETED_2"]    = "Completed quests"
L["OPT_ROLLING_2"]      = "Rolling XP/h"
L["OPT_INCBAR_2"]       = "Incomplete XP bar"
L["OPT_SEC_VISIBILITY"] = "Visibility"
L["OPT_VERTTEXT_2"]     = "Text next to bar (vertical mode)"
L["OPT_VTHICK_2"]       = "Thickness (vertical)"
L["OPT_VLENGTH_2"]      = "Length (vertical)"
L["OPT_SEC_FLOATING"]   = "Floating button"
L["OPT_HIDE_OPTIONS_BTN"] = "Hide the Options button"

-- Bouton minimap (mode standalone uniquement)
L["MM_TT_LEFT"]  = "Left click: show/hide"
L["MM_TT_RIGHT"] = "Right click: options"
