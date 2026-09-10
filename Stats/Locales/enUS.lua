-- =============================================================================
-- Stats - Locales/enUS.lua  (base locale)
-- =============================================================================

local ADDON, SX = ...

-- Table de localisation remplie par ce fichier (base) puis par frFR.lua
-- (surcharge). Cle manquante -> on renvoie la cle elle-meme (jamais nil).
SX.L = setmetatable({}, {
  __index = function(t, k) return k end,
})
local L = SX.L

L["WINDOW_TITLE"]        = "Stats"

-- Filtre personnage / periode
L["CHAR_ACCOUNT"]        = "Account (all characters)"
L["PERIOD_DAY"]          = "Day"
L["PERIOD_WEEK"]         = "Week"
L["PERIOD_MONTH"]        = "Month"
L["PERIOD_YEAR"]         = "Year"
L["PERIOD_YEAR_LOCKED"]  = "Unlocks once you have a full year of data."
L["GRANULARITY_LABEL"]   = "Stats by:"
L["GRANULARITY_DAY"]     = "day"
L["GRANULARITY_WEEK"]    = "week"
L["GRANULARITY_MONTH"]   = "month"

-- Cartes de la vue d'ensemble
L["CARD_QUESTS"]         = "Quests"
L["CARD_GOLD"]           = "Gold"
L["CARD_GOLD_WEEK"]      = "Gold (week)"
L["CARD_DUNGEONS"]       = "Dungeons & M+"
L["CARD_PLAYED"]         = "Time played"
L["CARD_DELVES"]         = "Delves"
L["CARD_REP_GAINED"]     = "Reputation gained"
L["CARD_PVP_KILLS_GAINED"] = "Enemies killed"
L["CARD_PROF_GAINED"]      = "Profession points gained"
L["DELVES_TIER"]         = "Highest tier"
L["DELVES_COMPANION"]    = "Companion lvl."
L["DELVES_TOTAL"]        = "Total"
L["TILE_TIER"]           = "Tier"
L["TILE_COMPANION"]      = "Companion"
L["TILE_KILLS"]          = "Kills"
L["TILE_ASH"]            = "Soul Ash"
L["TILE_CINDERS"]        = "Cinders"
L["TABLE_BRACKET"]       = "Bracket"
L["TABLE_RATING"]        = "Rating"
L["TABLE_BEST"]          = "Best"
L["TABLE_RECORD"]        = "Record"
L["TABLE_NAME"]          = "Name"
L["TABLE_COUNT"]         = "Times"
L["TABLE_WINS"]          = "Wins"
L["DELVE_TYPES_TITLE"]   = "Delves"
L["DELVE_TYPES_NO_DATA"] = "No delve completed for this character."
L["DELVE_ALL_MAXED"]     = "Every delve encountered is at max tier!"
L["WEEKLY_GOLD_NOTE"]    = "* Gold (week) is aligned on the weekly raid reset, not the calendar week."

-- Detail
L["DETAIL_MIN"]          = "Min"
L["DETAIL_MAX"]          = "Max"
L["DETAIL_AVG"]          = "Average"
L["DETAIL_BACK"]         = "Back to overview"

-- Comparaison
L["COMPARE_BUTTON"]      = "Compare"
L["COMPARE_STOP"]        = "Stop comparing"
L["COMPARE_CUMULATIVE"]  = "Cumulative"
L["COMPARE_PICK"]        = "Compare with..."
L["COMPARE_NO_OTHER"]    = "No other character has recorded data yet."

-- Export
L["EXPORT_BUTTON"]       = "Generate my export code"
L["EXPORT_TITLE"]        = "Export code"
L["EXPORT_HINT"]         = "Ctrl+C to copy, then paste it on the web dashboard."
L["EXPORT_NO_DATA"]      = "No data recorded yet for this character."

-- Donjons / M+
L["DUNGEONS_NORMAL"]     = "Dungeons"
L["DUNGEONS_MPLUS"]      = "Mythic+"

-- Hauts faits / PVP
L["ACHIEV_POINTS_SUFFIX"] = "achievement points"
L["PVP_SECTION_TITLE"]   = "PVP"
L["PVP_BEST"]            = "best"
L["PVP_KILLS"]           = "Enemies killed"
L["PVP_DEATHS_BY_PLAYERS"] = "Killed by a player"
L["PVP_DEATHS_BY_ENEMY"] = "Killed by the enemy faction"
L["PVP_HONOR"]           = "Honor"
L["PVP_CONQUEST"]        = "Conquest"
L["PVP_RECORD_FMT"]      = "%d wins / %d losses (%d%%)"
L["PVP_NO_DATA"]         = "No rated PVP activity this season."
L["PVP_BRACKET_2V2"]     = "2v2 Arena"
L["PVP_BRACKET_3V3"]     = "3v3 Arena"
L["PVP_BRACKET_RBG"]     = "Rated BG"
L["PVP_BRACKET_SHUFFLE"] = "Solo Shuffle"
L["PVP_BRACKET_BLITZ"]   = "Blitz"
L["PVP_ARENA_TITLE"]     = "Arena (2v2+3v3+solo shuffle)"
L["PVP_ARENA_SUMMARY_FMT"] = "%d matches - %d wins (%d%%)"
L["PVP_BG_TITLE"]        = "Battlegrounds"
L["PVP_BG_SUMMARY_FMT"]  = "%d played - %d won (%d%%)"
L["PVP_BG_NO_DATA"]      = "No battleground played."

L["TORGHAST_SECTION_TITLE"] = "Torment"
L["TORGHAST_LAYER"]      = "Highest layer"
L["TORGHAST_ASH"]        = "Soul Ash"
L["TORGHAST_CINDERS"]    = "Soul Cinders"
L["TORGHAST_NO_DATA"]    = "No Torghast data for this character."
L["TORGHAST_TYPES_TITLE"] = "Torment - Tower of the Damned"
L["TORGHAST_TYPES_NO_DATA"] = "No Torment completed for this character."
L["TABLE_ECHELON"]       = "Highest echelon"
L["TABLE_ACHIEVEMENT"]   = "Achievement"

L["REPUTATION_SECTION_TITLE"] = "Reputations"
L["REP_TRACKED"]         = "Tracked"
L["REP_MAX_RANK"]        = "Highest rank"
L["REP_MAXED"]           = "Exalted"
L["REP_PARAGON_FMT"]     = "%d paragon box(es) available"
L["REP_ALL_MAXED"]       = "Every tracked faction is at max!"
L["REP_NO_DATA"]         = "No reputation tracked for this character."
L["REP_NO_RECENT_DATA"]  = "No recent reputation progress."
L["REP_TYPES_TITLE"]     = "Reputation"
L["REP_RENOWN"]          = "Renown"
L["TABLE_SYSTEM"]        = "System"
L["TABLE_PROGRESS"]      = "Progress"
L["TABLE_LEVEL"]         = "Level"

L["PROFESSIONS_SECTION_TITLE"] = "Professions"
L["PROF_TRACKED"]        = "Tracked"
L["PROF_MAXED"]          = "100%"
L["PROF_IN_PROGRESS"]    = "In progress"
L["PROF_ALL_MAXED"]      = "Every tracked profession is at 100%!"
L["PROF_NO_DATA"]        = "No profession tracked for this character."
L["PROF_NO_RECENT_DATA"] = "No recent profession progress."
L["PROF_TYPES_TITLE"]    = "Professions"

-- Divers
L["OPT_TITLE"]           = "Settings"
L["SLASH_HELP"]          = "Commands: /ts stats, /stats"
L["MM_TOOLTIP_TITLE"]    = "Stats"
L["MM_TOOLTIP_DESC"]     = "Quests, gold, dungeons and time played tracker."
