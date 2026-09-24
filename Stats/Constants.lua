-- =============================================================================
-- Stats - Constants.lua
-- Identite visuelle et petites constantes partagees par Core.lua / UI.lua / Export.lua.
-- =============================================================================

local ADDON, SX = ...

-- Accent dore : Stats est un module transverse (pas teinte comme les modules
-- thematiques), il reprend l'accent GOLD de la palette commune du socle.
SX.ACCENT = { 1.000, 0.843, 0.000 }

-- Teinte du second personnage en mode Comparer (distincte de l'or du perso principal)
SX.COMPARE_ACCENT = { 0.580, 0.502, 1.000 }  -- lavande, UI.C.LAV

-- v2 : l'export passe d'un seul personnage (data.stats.days + data.char) a
-- TOUT le compte en un code (data.chars["Nom-Royaume"] = {char,days,professions}) -
-- voir Export.lua / SX.CollectExportData. Le site (Tibiscui.fr/dashboard-shared.js)
-- doit lire les deux schemas.
SX.SCHEMA_VERSION = 2

-- Plafond de jours conserves par personnage (borne la taille des SavedVariables,
-- meme principe que PostBox : purge des plus anciens au-dela).
SX.HISTORY_MAX_DAYS = 400

-- Plafond d'evenements detailles par jour et par journal (mplus, questLog,
-- dungeonLog, delveLog, repLog, raidLog, goldLog, playtimeLog, profLog, pvpLog) :
-- au-dela, le plus ancien de la journee est ecrase
-- (SX.AppendDayEvent, Core.lua). Une grosse session de farm/quete peut generer
-- bien plus d'evenements par jour qu'un M+ classique ; ce plafond evite de faire
-- exploser la taille de l'export sans jamais faire perdre les journees passees
-- (SX.PurgeOldDays reste le seul garant de la retention long terme).
SX.HISTORY_MAX_EVENTS_PER_DAY = 200

SX.PERIODS = { "day", "week", "month", "year" }
SX.GRANULARITIES = { "day", "week", "month", "year" }

SX.METRICS = { "quests", "gold", "dungeons", "played" }
