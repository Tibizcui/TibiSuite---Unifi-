-- =============================================================================
-- LvlHistory - Locale/enUS.lua
-- Surcharge EN. Le francais est le texte par defaut embarque directement dans
-- le code (Loc(key, default)/T(key, default)) : cette table ne fournit que ce
-- qui differe. Charge tout en debut de .toc, avant tous les autres fichiers,
-- car certaines chaines (ex: TAB_LABELS) sont construites une seule fois au
-- chargement du fichier.
-- =============================================================================

if GetLocale() ~= "enUS" and GetLocale() ~= "enGB" then return end
LvlHistory = LvlHistory or {}
LvlHistory.L = LvlHistory.L or {}
local L = LvlHistory.L

-- Utils.lua (devises)
L["CUR_GOLD"]   = "g"
L["CUR_SILVER"] = "s"
L["CUR_COPPER"] = "c"
L["ERROR_PREFIX"] = "ERROR:"

-- Core.lua
L["LOGIN_LOADED"]       = "loaded -- type"
L["LOGIN_TO_OPEN"]      = "to open."
L["MAX_LEVEL_REACHED"]  = "Max level reached — switching to FARMING mode"
L["RESET_CONFIRM_HINT"] = "Type |cffFFFFFF/lvlh reset confirm|r to confirm."
L["DATA_RESET_DONE"]    = "Data reset. Reload (/reload)."
L["SLASH_HELP"]         = "Commands: /lvlh | /lvlh options | /lvlh minimap | /lvlh debug | /lvlh reset"

-- Minimap.lua
L["TT_MODE"]         = "Mode"
L["TT_LEVEL"]        = "Level"
L["TT_GOLDH"]        = "Gold/h"
L["TT_SESSION"]      = "Session"
L["TT_LEFTCLICK"]    = "Left click"
L["TT_TOGGLE"]       = "Open/Close"
L["TT_RIGHTCLICK"]   = "Right click"
L["TT_OPTIONS"]      = "Options"
L["TT_DRAG"]         = "Drag"
L["TT_REPOSITION"]   = "Reposition"
L["MENU_TOGGLE"]     = "Open / Close"
L["MENU_DEBUG"]      = "Debug"
L["MENU_HIDE_BUTTON"]= "Hide the button"
L["BUTTON_HIDDEN_LOG"]= "Button hidden — /lvlh minimap to show it again"
L["MENU_RESET_CHAR"] = "Reset this character"

-- UI.lua
L["TAB_SESSION"]  = "Session"
L["TAB_ZONES"]    = "Zones"
L["TAB_ALTS"]     = "Alts"
L["TAB_DUNGEONS"] = "Dungeons"
L["TAB_STATS"]    = "Stats"

L["TT_EXPAND"]   = "Expand"
L["TT_COLLAPSE"] = "Collapse"
L["OPACITY_LABEL"] = "Opacity"

L["LBL_CURRENT_ZONE"] = "Current zone"
L["LBL_QUESTS"]       = "Quests"
L["LBL_GOLD_GAINED"]  = "Gold gained"
L["LBL_REPUTATION"]   = "Reputation"
L["LBL_GAINED"]       = "Gained"

L["LBL_XPH"]   = "XP / hour"
L["LBL_GOLDH"] = "Gold / hour"
L["LBL_ETA_PREFIX"] = "ETA lvl "
L["LBL_PCT_DONE"]   = "% done"
L["LBL_THIS_SESSION"]      = "this session"
L["LBL_SESSION_DURATION"]  = "Session duration"
L["LBL_TOTAL_SUFFIX"]      = " total"
L["LBL_LEVEL_PREFIX"]      = "Level "
L["LBL_GOLD_THIS_SESSION"] = "Gold gained this session"

L["LBL_ZONES_VISITED"] = "Zones visited"
L["LBL_TOTAL_TIME"]    = "Total time"
L["LBL_ZONE_RECORD"]   = "Zone record"
L["BTN_COLLAPSE_LIST"] = "- Collapse"
L["BTN_SHOW_MORE_FMT"] = "+ Show more (%d zones)"

L["LBL_ALTS_TRACKED"]     = "Alts tracked"
L["LBL_MAX_LEVEL"]        = "Max level"
L["LBL_TOTAL_TIME_CUMUL"] = "Cumulative time"
L["LBL_ALL_CHARS"]        = "all characters"
L["MODE_FARMING"]  = "Farming"
L["MODE_LEVELING"] = "Leveling"

L["LBL_TOP_DUNGEONS"] = "Most played dungeons"
L["COL_DIFF"] = "Diff."
L["COL_TIME"] = "Time"
L["LBL_TOTAL_COMPLETED"]  = "Total completed"
L["LBL_THIS_SESSION_CAP"] = "This session"
L["LBL_FAVORITE_DUNGEON"] = "Favorite dungeon"

L["LBL_RECORDS"]      = "Records"
L["LBL_BEST_XPH"]     = "Best XP/h"
L["LBL_AVG_XPH"]      = "Average XP/h"
L["LBL_TOTAL_SESSIONS"] = "Total sessions"
L["LBL_BEST_SESSION"] = "Best session"
L["LBL_FAVORITE_ZONE"]= "Favorite zone"
L["LBL_TOTAL_GOLD"]   = "Total gold gained"
L["LBL_BEST_GOLD_SESSION"] = "Best gold / session"
L["LBL_BEST_DGN_SESSION"]  = "Best dungeons / session"
L["LBL_SESSIONS_SUFFIX"] = "sessions"
L["LBL_TOTAL_QUESTS"]    = "Total quests"
L["LBL_TOTAL_DUNGEONS"]  = "Total dungeons"
L["AVG_PREFIX_FMT"] = "avg. %s"
L["LV_PREFIX_FMT"]  = "Lv %d"

L["FOOTER_SESSION_PREFIX"] = "Session  "
L["FOOTER_TOTAL_PREFIX"]   = "Total  "

L["LBL_DURATION"]        = "Duration"
L["LBL_ZONE_SHORT"]      = "Zone"
L["LBL_DURATION_RECORD"] = "Duration record"
L["LBL_TOP_CHAR"]        = "Top character"
L["LBL_TOTAL_SHORT"]     = "Total"
L["LBL_FAVORITE_SHORT"]  = "Favorite"
L["LBL_TIMES_PLAYED"]    = "Times played"
L["LBL_SESSIONS_SHORT"]  = "Sessions"

-- LvlHistory_Suite.lua (options + recherche)
L["OPT_SEC_WINDOW"]       = "Window"
L["OPT_TOGGLE"]           = "Open / close"
L["OPT_RECENTER"]         = "Recenter the window"
L["OPT_OPACITY"]          = "Opacity (%)"
L["OPT_SEC_FLOATING"]     = "Floating buttons (TibiSuite bar)"
L["OPT_HIDE_OPTIONS_BTN"] = "Hide the Options button"
L["OPT_HIDE_SEARCH_BTN"]  = "Hide the Search field"
L["OPT_FLOATING_NOTE"]    = "The Options button and Search field overflow above the window. Even hidden, Shift+right-click on the window opens these options."
L["OPT_NOTE"]             = "Tip: right-clicking the Lvl Hist tile in the TibiSuite bar also opens these options."
L["SEARCH_TITLE"]         = "Search"
L["MODULE_LABEL"]         = "Lvl Hist"
