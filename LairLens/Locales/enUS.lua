-- =============================================================================
-- LairLens - Locales/enUS.lua  (base locale)
-- =============================================================================

local ADDON, LL = ...
local L = LL.L

-- Panneau d'audit
L["AUDIT_TITLE"]        = "Group audit"
L["AUDIT_NO_GROUP"]     = "Not in a group"
L["AUDIT_NO_LAIR"]      = "Not in a Lair"

L["DIFF_WORLD"]         = "World"
L["DIFF_NORMAL"]        = "Normal"
L["DIFF_HEROIC"]        = "Heroic"
L["DIFF_MYTHIC"]        = "Mythic"

L["ROLES"]              = "Roles"
L["TANKS"]              = "Tanks"
L["HEALERS"]            = "Healers"
L["COMBAT_REZ"]         = "Combat rez"
L["LUST"]               = "Lust / Hero"
L["INTERRUPTS"]         = "Interrupts"
L["DISPELS"]            = "Dispels"

L["DISPEL_MAGIC"]       = "Magic"
L["DISPEL_CURSE"]       = "Curse"
L["DISPEL_POISON"]      = "Poison"
L["DISPEL_DISEASE"]     = "Disease"

L["PRESENT"]            = "Present"
L["ABSENT"]             = "Absent"
L["NONE"]               = "None"

-- Verdicts
L["VERDICT_VIABLE"]     = "Group viable"
L["VERDICT_RISKY"]      = "Playable, but thin"
L["VERDICT_MISSING"]    = "Missing: %s"

L["MISS_TANK"]          = "a tank"
L["MISS_HEALER"]        = "healers (%d/%d)"
L["MISS_COMBAT_REZ"]    = "combat rez"
L["MISS_LUST"]          = "Lust"
L["MISS_INTERRUPT"]     = "interrupts"

-- Recompenses (module 2)
L["REWARD_TITLE"]       = "Reward relevance"
L["REWARD_WORTH"]       = "Worth it"
L["REWARD_SKIP"]        = "You can skip"
L["REWARD_DONE_WEEK"]   = "Already cleared this week"
L["REWARD_NO_DATA"]     = "Loot data not available yet"

-- Dashboard (historique des runs)
L["DASH_TITLE"]           = "Lair history"
L["DASH_RUNS"]            = "Runs"
L["DASH_TIME"]            = "Time"
L["DASH_ATTEMPTS"]        = "Attempts"
L["DASH_KILLS"]           = "Kills"
L["DASH_FILTER_OWNER"]    = "Char"
L["DASH_FILTER_DIFF"]     = "Difficulty"
L["DASH_FILTER_INSTANCE"] = "Lair"
L["DASH_ALL"]             = "All"
L["DASH_SEARCH"]          = "Search..."
L["DASH_EMPTY"]           = "No run recorded yet."
L["DASH_COL_DATE"]        = "Date"
L["DASH_COL_LAIR"]        = "Lair"
L["DASH_COL_DIFF"]        = "Diff."
L["DASH_COL_TIME"]        = "Time"
L["DASH_COL_TRIES"]       = "Att."
L["DASH_COL_RESULT"]      = "Result"
L["DASH_ILVL"]            = "ilvl"
L["DASH_OPEN_TT"]         = "Open the run dashboard (history)."
L["DASH_CLEAR"]           = "Clear history"
L["DASH_CLEAR_CONFIRM"]   = "Click again to confirm"
L["RUN_KILL"]             = "Kill"
L["RUN_INCOMPLETE"]       = "Incomplete"

-- Options / slash
L["SLASH_HELP"]         = "Commands: /ll config, /ll show, /ll dash, /ll sim, /ll lock, /ll reset, /ll debug"
L["FRAME_LOCKED"]       = "Panel locked."
L["FRAME_UNLOCKED"]     = "Panel unlocked (drag to move)."

-- Options
L["OPT_TITLE"]          = "Settings"
L["OPT_ENABLED"]        = "Enable LairLens"
L["OPT_ENABLED_TT"]     = "Master switch for the addon."
L["OPT_HIDE_OUT"]       = "Hide outside a Lair"
L["OPT_HIDE_OUT_TT"]    = "Only show the panel while inside a Lair."
L["OPT_FADE_COMBAT"]    = "Fade in combat"
L["OPT_FADE_COMBAT_TT"] = "Dim the panel during combat to stay discreet."
L["OPT_LOCK"]           = "Lock position"
L["OPT_LOCK_TT"]        = "Prevent the panel from being dragged."
L["OPT_SCALE"]          = "Scale"
L["OPT_UNAVAILABLE"]    = "Settings panel unavailable on this client. Use slash commands."
