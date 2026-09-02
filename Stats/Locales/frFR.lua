-- =============================================================================
-- Stats - Locales/frFR.lua
-- Surcharge FR. Ne s'applique que si le client tourne en francais.
-- =============================================================================

local ADDON, SX = ...
if GetLocale() ~= "frFR" then return end
local L = SX.L

L["WINDOW_TITLE"]        = "Stats"

L["CHAR_ACCOUNT"]        = "Compte (tous personnages)"
L["PERIOD_DAY"]          = "Jour"
L["PERIOD_WEEK"]         = "Semaine"
L["PERIOD_MONTH"]        = "Mois"
L["PERIOD_YEAR"]         = "Annee"
L["PERIOD_YEAR_LOCKED"]  = "Se debloque avec une annee complete de donnees."
L["GRANULARITY_LABEL"]   = "Stats par :"
L["GRANULARITY_DAY"]     = "jour"
L["GRANULARITY_WEEK"]    = "semaine"
L["GRANULARITY_MONTH"]   = "mois"

L["CARD_QUESTS"]         = "Quetes"
L["CARD_GOLD"]           = "Or"
L["CARD_GOLD_WEEK"]      = "Or (semaine)"
L["CARD_DUNGEONS"]       = "Donjons & M+"
L["CARD_PLAYED"]         = "Heures jouees"
L["WEEKLY_GOLD_NOTE"]    = "* Or (semaine) est cale sur le reset hebdomadaire des raids, pas sur la semaine calendaire."

L["DETAIL_MIN"]          = "Min"
L["DETAIL_MAX"]          = "Max"
L["DETAIL_AVG"]          = "Moyenne"
L["DETAIL_BACK"]         = "Retour a la vue d'ensemble"

L["COMPARE_BUTTON"]      = "Comparer"
L["COMPARE_STOP"]        = "Arreter"
L["COMPARE_CUMULATIVE"]  = "Cumule"
L["COMPARE_PICK"]        = "Comparer avec..."
L["COMPARE_NO_OTHER"]    = "Aucun autre personnage n'a encore de donnees enregistrees."

L["EXPORT_BUTTON"]       = "Generer mon code d'export"
L["EXPORT_TITLE"]        = "Code d'export"
L["EXPORT_HINT"]         = "Ctrl+C pour copier, puis collez-le sur le dashboard web."
L["EXPORT_NO_DATA"]      = "Aucune donnee enregistree pour ce personnage."

L["DUNGEONS_NORMAL"]     = "Donjons"
L["DUNGEONS_MPLUS"]      = "Mythique+"

L["OPT_TITLE"]           = "Reglages"
L["SLASH_HELP"]          = "Commandes : /ts stats, /stats"
L["MM_TOOLTIP_TITLE"]    = "Stats"
L["MM_TOOLTIP_DESC"]     = "Suivi des quetes, de l'or, des donjons et du temps de jeu."
