-- =============================================================================
-- RepBar - Locale/enUS.lua
-- Surcharge EN. Le francais est le texte par defaut embarque directement dans
-- RepBar.lua (table RepBarL, motif "L.CLE = L.CLE or valeur") : ce fichier ne
-- fournit que ce qui differe. Peut se charger avant ou apres RepBar.lua, dans
-- n'importe quel ordre (voir commentaire dans RepBar.lua).
-- =============================================================================

if GetLocale() ~= "enUS" and GetLocale() ~= "enGB" then return end
RepBarL = RepBarL or {}
local L = RepBarL

L["FACTION"]      = "Faction"
L["STANDING"]     = "Standing"
L["PROGRESS"]     = "Progress"
L["REMAINING"]    = "Remaining"
L["ZONE"]         = "Zone"
L["RENOWN"]       = "Renown"
L["PARAGON"]      = "Paragon"
L["NO_FACTION"]   = "No faction tracked"
L["HINT"]         = "|cffFFD700Shift+Drag|r move  ·  |cffFFD700Shift+Right-click|r options"
L["POS_SAVED"]    = "Position saved."
L["POS_RESET"]    = "Position reset."
L["SWITCH_QUEST"] = "Tracked faction: "

-- Options (panneau standalone)
L["OPT_TITLE"]      = "RepBar - Options"
L["OPT_TAB"]        = "Options"
L["OPT_HINT"]       = "|cffFFD700Shift+Drag|r to move   |cffFFD700Shift+Right-click|r to open/close"
L["OPT_WIDTH"]      = "Width:"
L["OPT_HEIGHT"]     = "Height:"
L["OPT_COLORS"]     = "Colors"
L["OPT_COL_BAR"]    = "Bar (fixed color)"
L["OPT_OPACITY"]    = "Background opacity:"
L["OPT_FONTSIZE"]   = "Text size:"
L["OPT_DISPLAY"]    = "Display"
L["OPT_STANDCOL"]   = "Color by standing"
L["OPT_SHOWZONE"]   = "Show faction zone"
L["OPT_SHOWNUM"]    = "Show values (x / y)"
L["OPT_SHOWPCT"]    = "Show percentage"
L["OPT_HIDENOFAC"]  = "Hide if no faction tracked"
L["OPT_SWITCHQ"]    = "Switch on quest turn-in"
L["OPT_HIDENATIVE"] = "Hide native reputation bar"
L["OPT_HIDECOMBAT"] = "Hide in combat"
L["OPT_MOUSEOVER"]  = "Show on mouseover only"
L["OPT_CLOSE"]      = "Close"
L["OPT_RESETPOS"]   = "Reset position"
L["OPT_VERTBAR"]          = "Vertical bar"
L["OPT_VERTMODE_HEADER"]  = "Vertical mode"
L["OPT_VERTTEXT"]         = "Text next to the bar"
L["OPT_VTHICK"]           = "Thickness:"
L["OPT_VLENGTH"]          = "Length:"

-- Slash / login
L["SLASH_HIDDEN"]  = "Hidden. /repbar show to show it again."
L["SLASH_HELP"]    = " /repbar - options  |  /repbar hide/show  |  /repbar reset"
L["LOGIN_LOADED"]  = "loaded -- type"
L["LOGIN_TO_OPEN"] = "for the options."

-- Options (panneau integre TibiSuite "Midnight")
L["OPT_SEC_DIMENSIONS"]   = "Dimensions"
L["OPT_WIDTH_2"]          = "Width"
L["OPT_HEIGHT_2"]         = "Height"
L["OPT_SEC_BEHAVIOR"]     = "Behavior"
L["OPT_HIDENATIVE_2"]     = "Hide native bar"
L["OPT_SEC_ORIENTATION"]  = "Orientation"
L["OPT_VERTTEXT_2"]       = "Text next to bar (vertical mode)"
L["OPT_VTHICK_2"]         = "Thickness (vertical)"
L["OPT_VLENGTH_2"]        = "Length (vertical)"
L["OPT_SEC_FLOATING"]     = "Floating button"
L["OPT_HIDE_OPTIONS_BTN"] = "Hide the Options button"

-- Bouton minimap (mode standalone uniquement)
L["MM_TT_LEFT"]  = "Left click: show/hide"
L["MM_TT_RIGHT"] = "Right click: options"
