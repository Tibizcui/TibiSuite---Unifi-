-- =============================================================================
-- RenTracker - Locale/enUS.lua
-- Surcharge EN. Le francais est le texte par defaut embarque directement dans
-- RenTracker.lua / RenTracker_Module.lua (T(key, default)) : cette table ne
-- fournit que ce qui differe.
-- =============================================================================

if GetLocale() ~= "enUS" and GetLocale() ~= "enGB" then return end
RenTrackerL = RenTrackerL or {}
local L = RenTrackerL

-- Rangs de reputation
L["REN_EXALTED"]     = "Exalted"
L["REN_REVERED"]     = "Revered"
L["REN_HONORED"]     = "Honored"
L["REN_FRIENDLY"]    = "Friendly"
L["REN_NEUTRAL_PLUS"]= "Familiar"
L["REN_NEUTRAL"]     = "Neutral"
L["REN_HOSTILE"]     = "Hostile"
L["REN_UNFRIENDLY"]  = "Unfriendly"
L["REN_PARAGON"]     = "Paragon"
L["UNKNOWN"]         = "Unknown"
L["MAX_LABEL"]       = "Max"
L["RENOWN_WORD"]     = "Renown"
L["REP_WORD"]        = "rep"
L["REP_LABEL"]       = "Rep:"

-- Fenetre principale
L["OPTIONS_LABEL"] = "Options"
L["DRAG_HINT"]      = "Drag to move  -  /rt"
L["SYS_RENOWN"]     = "Renown System"
L["SYS_CLASSIC"]    = "Classic System"
L["PARAGON_ON"]     = "Paragon active"
L["PARAGON_OFF"]    = "No Paragon"
L["FACTIONS_PLURAL"]= "factions"
L["FACTION_SINGULAR"]="faction"
L["EXTENSIONS_LABEL"]= "Expansions"
L["CAT_MAIN"]       = "Main"
L["CAT_SECONDARY"]  = "Secondary"
L["ZONE_LABEL"]     = "Zone:"
L["QUESTS_AVAILABLE"] = "Available quests"
L["TAG_WEEKLY"]  = "[Weekly]"
L["TAG_ONETIME"] = "[One-time]"
L["TAG_DAILY"]   = "[Daily]"
L["GLOBAL_LABEL"]   = "Global:"
L["AT_MAX"]         = "at max"
L["ACHIEV_LABEL"]   = "Ach:"
L["NO_FACTION_AVAILABLE"] = "No faction available."
L["REPUTATIONS_HEADER"]   = "Reputations"
L["QUARTERMASTER_LABEL"]  = "Quartermaster:"
L["LOCATION_LABEL"]       = "Location:"
L["QUESTS_WEEKLY"]  = "Weekly quests"
L["QUESTS_ONETIME"] = "One-time quests"
L["QUESTS_DAILY"]   = "Daily quests"
L["NPC_LABEL"]           = "NPC:"
L["ZONE_COORD_LABEL"]    = "Zone coord.:"
L["ITEMS_TO_COLLECT"]    = "Items to collect:"
L["IN_BAG"]              = "in bag"

-- Boutons / tooltips minimap
L["LEFT_CLICK_LABEL"] = "Left click"
L["CLICK_LABEL"]      = "Click"
L["DRAG_LABEL"]       = "Drag"
L["TOGGLE_HINT"]      = "open / close"
L["REPOSITION_HINT"]  = "reposition the icon"
L["MM_TT_SUBTITLE"]   = "Reputation tracker"

-- Options (panneau standalone + panneau socle)
L["OPT_AUTOTRACK"]        = "Automatic tracking by zone"
L["OPT_LOGINMSG"]         = "Login message in chat"
L["OPT_SOUND"]            = "Sound on Renown level up"
L["OPT_REOPEN_HINT"]      = "/rt config to reopen this panel"
L["OPT_SEC_WINDOW"]       = "Window"
L["OPT_TOGGLE"]           = "Open / close"
L["OPT_RECENTER"]         = "Recenter the window"
L["OPT_SEC_BEHAVIOR"]     = "Behavior"
L["OPT_LOGINMSG_2"]       = "Welcome message on login"
L["OPT_SOUND_2"]          = "Notification sound"
L["OPT_SEC_FLOATING"]     = "Floating buttons (TibiSuite bar)"
L["OPT_HIDE_OPTIONS_BTN"] = "Hide the Options button"
L["OPT_HIDE_SEARCH_BTN"]  = "Hide the Search field"
L["OPT_FLOATING_NOTE"]    = "The Options button and Search field overflow above the window. Even hidden, Shift+right-click on the window opens these options."
L["OPT_NOTE"]             = "Tip: right-clicking the Rep. tab in the TibiSuite bar also opens these options."

-- Divers
L["QUEST_SINGULAR"] = "quest"
L["MODULE_LABEL"]   = "Rep."
L["LOGIN_LOADED"]   = "loaded -- type"
L["LOGIN_TO_OPEN"]  = "to open."
