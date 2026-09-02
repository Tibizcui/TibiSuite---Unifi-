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

-- Divers
L["OPT_TITLE"]           = "Settings"
L["SLASH_HELP"]          = "Commands: /ts stats, /stats"
L["MM_TOOLTIP_TITLE"]    = "Stats"
L["MM_TOOLTIP_DESC"]     = "Quests, gold, dungeons and time played tracker."
