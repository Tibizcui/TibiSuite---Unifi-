-- =============================================================================
-- DgnTracker - Locales/enUS.lua
-- Surcharge EN. Le francais est le texte par defaut embarque directement dans
-- DgnTracker.lua / DgnTracker_Suite.lua / DgnTracker_Module.lua (T(key,
-- default)) : cette table ne fournit que ce qui differe.
-- =============================================================================

if GetLocale() ~= "enUS" and GetLocale() ~= "enGB" then return end
DgnTrackerL = DgnTrackerL or {}
local L = DgnTrackerL

L["WP_NO_COORDS"]        = "coordinates unavailable for"
L["WP_TOMTOM_LABEL"]     = "waypoint"
L["WP_MAP_LABEL"]        = "waypoint"
L["WP_MAP_WORD"]         = "map"
L["WP_OPEN_MAP_HINT"]    = "(open the map to see it)"
L["WP_NATIVE_FAIL"]      = "could not place a native waypoint in this zone. Install |cFFFFD700TomTom|r for a full pointer."
L["WP_NONE_AVAILABLE"]   = "no waypoint system available. Install |cFFFFD700TomTom|r."
L["DRAG_HINT"]           = "Drag to move"
L["INSTANCES_WORD"]      = "instance(s)"
L["SEARCH_PLACEHOLDER"]  = "Search..."
L["EXTENSION_LABEL"]     = "Expansion:"
L["LEFT_CLICK_LABEL"]    = "Left click"
L["CLOSE_WORD"]          = "close"
L["SHOW_PATH_WORD"]      = "show the path"
L["RIGHT_CLICK_LABEL"]   = "Right click"
L["SET_WAYPOINT_HINT"]   = "set a waypoint"
L["NO_RESULT_FOR"]       = "No result for"
L["NO_INSTANCE_CATEGORY"]= "No instance available for this category."
L["ACCESS_HEADER"]       = "-- Access (shortest path):"
L["TIPS_HEADER"]         = "-- Tips:"
L["MM_TT_SUBTITLE"]      = "Dungeon & raid tracker"
L["TOGGLE_HINT"]         = "open / close"
L["DRAG_LABEL"]          = "Drag"
L["REPOSITION_HINT"]     = "reposition the icon"
L["CLICK_LABEL"]         = "Click"

L["HELP_COMMANDS_LABEL"] = "commands:"
L["HELP_TOGGLE"]         = "Open/close the window"
L["HELP_OPTIONS"]        = "Open the options"
L["HELP_MAP_ON"]         = "Auto waypoint when opening an instance"
L["HELP_MAP_OFF"]        = "Disable the auto waypoint"
L["HELP_EXTENSION"]      = "Go to an expansion (e.g.: tww, df, sl, van)"
L["HELP_EXPAND"]         = "Expand all (active expansion)"
L["HELP_RESET"]          = "Collapse all (accordion)"
L["HELP_TIP"]            = "Tip: right-click an instance to set a waypoint."

L["ACCORDION_RESET"]     = "accordion reset."
L["EXPANDED_ALL_FOR"]    = "expanded all for"
L["AUTO_WAYPOINT_LABEL"] = "auto waypoint"
L["ENABLED_WORD"]        = "enabled"
L["ON_INSTANCE_OPEN"]    = "(when opening an instance)"
L["DISABLED_WORD"]       = "disabled"
L["EXTENSION_ARROW"]     = "expansion ->"
L["UNKNOWN_COMMAND"]     = "unknown command. Type |cFFFFD700/dg help|r."
L["LOGIN_LOADED"]        = "loaded --"
L["LOGIN_TO_OPEN"]       = "to open."

-- Options (DgnTracker_Suite.lua) et libelle du module
L["OPT_SEC_WINDOW"]      = "Window"
L["OPT_TOGGLE"]          = "Open / close"
L["OPT_RECENTER"]        = "Recenter the window"
L["OPT_SEC_BEHAVIOR"]    = "Behavior"
L["OPT_AUTO_WAYPOINT"]   = "Auto waypoint when opening an instance"
L["OPT_SEC_FLOATING"]    = "Floating buttons (TibiSuite bar)"
L["OPT_HIDE_OPTIONS_BTN"]= "Hide the Options button"
L["OPT_HIDE_SEARCH_BTN"] = "Hide the Search field"
L["OPT_FLOATING_NOTE"]   = "The Options button and Search field overflow above the window. Even hidden, Shift+right-click on the window opens these options."
L["OPT_NOTE"]            = "Tip: right-clicking the Dungeons tile in the TibiSuite bar also opens these options."
L["SEARCH_TITLE"]        = "Search"
L["MODULE_LABEL"]        = "Dungeons"
