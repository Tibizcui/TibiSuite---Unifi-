-- =============================================================================
-- Stats - Locales/deDE.lua
-- Surcharge DE. Ne s'applique que si le client tourne en allemand.
-- =============================================================================

local ADDON, SX = ...
if GetLocale() ~= "deDE" then return end
local L = SX.L

L["WINDOW_TITLE"]        = "Stats"

L["CHAR_ACCOUNT"]        = "Account (alle Charaktere)"
L["PERIOD_DAY"]          = "Tag"
L["PERIOD_WEEK"]         = "Woche"
L["PERIOD_MONTH"]        = "Monat"
L["PERIOD_YEAR"]         = "Jahr"
L["PERIOD_YEAR_LOCKED"]  = "Wird freigeschaltet, sobald ein volles Jahr an Daten vorliegt."
L["GRANULARITY_LABEL"]   = "Statistik nach:"
L["GRANULARITY_DAY"]     = "Tag"
L["GRANULARITY_WEEK"]    = "Woche"
L["GRANULARITY_MONTH"]   = "Monat"

L["CARD_QUESTS"]         = "Quests"
L["CARD_GOLD"]           = "Gold"
L["CARD_GOLD_WEEK"]      = "Gold (Woche)"
L["CARD_DUNGEONS"]       = "Dungeons & M+"
L["CARD_PLAYED"]         = "Spielzeit"
L["CARD_DELVES"]         = "Hoehlen"
L["DELVES_TIER"]         = "Hoechste Stufe"
L["DELVES_COMPANION"]    = "Begleiter-Stufe"
L["WEEKLY_GOLD_NOTE"]    = "* Gold (Woche) richtet sich nach dem woechentlichen Raid-Reset, nicht nach der Kalenderwoche."

L["DETAIL_MIN"]          = "Min"
L["DETAIL_MAX"]          = "Max"
L["DETAIL_AVG"]          = "Durchschnitt"
L["DETAIL_BACK"]         = "Zurueck zur Uebersicht"

L["COMPARE_BUTTON"]      = "Vergleichen"
L["COMPARE_STOP"]        = "Vergleich beenden"
L["COMPARE_CUMULATIVE"]  = "Kumuliert"
L["COMPARE_PICK"]        = "Vergleichen mit..."
L["COMPARE_NO_OTHER"]    = "Kein anderer Charakter hat bisher Daten aufgezeichnet."

L["EXPORT_BUTTON"]       = "Meinen Exportcode erzeugen"
L["EXPORT_TITLE"]        = "Exportcode"
L["EXPORT_HINT"]         = "Strg+C zum Kopieren, dann im Web-Dashboard einfuegen."
L["EXPORT_NO_DATA"]      = "Fuer diesen Charakter wurden noch keine Daten aufgezeichnet."

L["DUNGEONS_NORMAL"]     = "Dungeons"
L["DUNGEONS_MPLUS"]      = "Mythisch+"

L["ACHIEV_POINTS_SUFFIX"] = "Erfolgspunkte"
L["PVP_SECTION_TITLE"]   = "PVP"
L["PVP_BEST"]            = "beste"
L["PVP_KILLS"]           = "Gegner getoetet"
L["PVP_DEATHS"]          = "PVP-Tode"
L["PVP_HONOR"]           = "Ehre"
L["PVP_CONQUEST"]        = "Eroberung"
L["PVP_RECORD_FMT"]      = "%d Siege / %d Niederlagen"
L["PVP_NO_DATA"]         = "Keine gewertete PVP-Aktivitaet diese Saison."
L["PVP_BRACKET_2V2"]     = "2v2-Arena"
L["PVP_BRACKET_3V3"]     = "3v3-Arena"
L["PVP_BRACKET_RBG"]     = "Gewertetes Schlachtfeld"
L["PVP_BRACKET_SHUFFLE"] = "Solo-Rotation"
L["PVP_BRACKET_BLITZ"]   = "Blitz"

L["TORGHAST_SECTION_TITLE"] = "Qual"
L["TORGHAST_LAYER"]      = "Hoechste Ebene"
L["TORGHAST_ASH"]        = "Seelenasche"
L["TORGHAST_CINDERS"]    = "Seelenglut"
L["TORGHAST_NO_DATA"]    = "Keine Torghast-Daten fuer diesen Charakter."

L["OPT_TITLE"]           = "Einstellungen"
L["SLASH_HELP"]          = "Befehle: /ts stats, /stats"
L["MM_TOOLTIP_TITLE"]    = "Stats"
L["MM_TOOLTIP_DESC"]     = "Verfolgt Quests, Gold, Dungeons und Spielzeit."
