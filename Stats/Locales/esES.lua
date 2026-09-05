-- =============================================================================
-- Stats - Locales/esES.lua
-- Surcharge ES. Ne s'applique que si le client tourne en espagnol.
-- =============================================================================

local ADDON, SX = ...
if GetLocale() ~= "esES" and GetLocale() ~= "esMX" then return end
local L = SX.L

L["WINDOW_TITLE"]        = "Stats"

L["CHAR_ACCOUNT"]        = "Cuenta (todos los personajes)"
L["PERIOD_DAY"]          = "Dia"
L["PERIOD_WEEK"]         = "Semana"
L["PERIOD_MONTH"]        = "Mes"
L["PERIOD_YEAR"]         = "Ano"
L["PERIOD_YEAR_LOCKED"]  = "Se desbloquea cuando tengas un ano completo de datos."
L["GRANULARITY_LABEL"]   = "Estadisticas por:"
L["GRANULARITY_DAY"]     = "dia"
L["GRANULARITY_WEEK"]    = "semana"
L["GRANULARITY_MONTH"]   = "mes"

L["CARD_QUESTS"]         = "Misiones"
L["CARD_GOLD"]           = "Oro"
L["CARD_GOLD_WEEK"]      = "Oro (semana)"
L["CARD_DUNGEONS"]       = "Mazmorras y M+"
L["CARD_PLAYED"]         = "Tiempo jugado"
L["WEEKLY_GOLD_NOTE"]    = "* Oro (semana) esta alineado con el reinicio semanal de las bandas, no con la semana natural."

L["DETAIL_MIN"]          = "Min"
L["DETAIL_MAX"]          = "Max"
L["DETAIL_AVG"]          = "Promedio"
L["DETAIL_BACK"]         = "Volver al resumen"

L["COMPARE_BUTTON"]      = "Comparar"
L["COMPARE_STOP"]        = "Dejar de comparar"
L["COMPARE_CUMULATIVE"]  = "Acumulado"
L["COMPARE_PICK"]        = "Comparar con..."
L["COMPARE_NO_OTHER"]    = "Ningun otro personaje tiene datos registrados todavia."

L["EXPORT_BUTTON"]       = "Generar mi codigo de exportacion"
L["EXPORT_TITLE"]        = "Codigo de exportacion"
L["EXPORT_HINT"]         = "Ctrl+C para copiar, luego pegalo en el panel web."
L["EXPORT_NO_DATA"]      = "Todavia no hay datos registrados para este personaje."

L["DUNGEONS_NORMAL"]     = "Mazmorras"
L["DUNGEONS_MPLUS"]      = "Mitica+"

L["OPT_TITLE"]           = "Ajustes"
L["SLASH_HELP"]          = "Comandos: /ts stats, /stats"
L["MM_TOOLTIP_TITLE"]    = "Stats"
L["MM_TOOLTIP_DESC"]     = "Seguimiento de misiones, oro, mazmorras y tiempo jugado."
