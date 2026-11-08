-- =============================================================================
-- Stats - Constants.lua
-- Identite visuelle et petites constantes partagees par Core.lua / UI.lua / Export.lua.
-- =============================================================================

local ADDON, SX = ...

-- ============================================================================
-- SONDE « action bloquee » (2026-11-08, WoW Forever) : le jeu affiche « Stats
-- a ete bloque a cause d'une action qui n'est utilisable que par l'IU de
-- Blizzard » sans dire laquelle. ADDON_ACTION_BLOCKED / FORBIDDEN portent
-- (addon, fonction). Posee ici, AVANT Core.lua, pour voir aussi un refus
-- survenu pendant le chargement. Note la fonction (10 dernieres) dans
-- StatsDB.blockLog (cle sans tiret : jamais prise pour un personnage, cf.
-- SX.GetCharKeys) et l'ecrit une fois par session dans le chat (differe a la
-- connexion si le chat n'est pas pret). StatsDB n'existe qu'apres
-- ADDON_LOADED : les refus anterieurs attendent dans `pending`.
-- ============================================================================
do
  local probe = CreateFrame("Frame")
  pcall(probe.RegisterEvent, probe, "ADDON_ACTION_BLOCKED")
  pcall(probe.RegisterEvent, probe, "ADDON_ACTION_FORBIDDEN")
  pcall(probe.RegisterEvent, probe, "ADDON_LOADED")
  pcall(probe.RegisterEvent, probe, "PLAYER_LOGIN")
  local pending, said, ready = {}, {}, false
  local function flush()
    local keep = {}
    for _, e in ipairs(pending) do
      if not e.saved and type(StatsDB) == "table" then
        StatsDB.blockLog = type(StatsDB.blockLog) == "table" and StatsDB.blockLog or {}
        local log = StatsDB.blockLog
        log[#log + 1] = { at = e.at, ev = e.ev, fn = e.fn, where = e.where, combat = e.combat, build = e.build }
        while #log > 10 do table.remove(log, 1) end
        e.saved = true
      end
      if not e.told and ready then
        e.told = true
        if not said[e.fn] then
          said[e.fn] = true
          print("|cFFFFD700[Stats]|r " .. e.ev .. " : |cFFFF6B6B" .. e.fn .. "|r")
          print("|cFFFFD700[Stats]|r origine : |cFFAAAAAA" .. tostring(e.where) .. "|r")
        end
      end
      if not (e.saved and e.told) then keep[#keep + 1] = e end
    end
    pending = keep
  end
  probe:SetScript("OnEvent", function(_, event, who, fn)
    if event == "ADDON_LOADED" then if who == ADDON then flush() end return end
    if event == "PLAYER_LOGIN" then ready = true; C_Timer.After(5, flush) return end
    if who ~= ADDON then return end
    -- L'evenement part PENDANT l'appel fautif : la pile d'appels contient
    -- donc la ligne de Stats responsable (meme technique que BugGrabber).
    -- On garde les lignes qui citent nos fichiers, sinon le haut de la pile.
    local stack = (debugstack and debugstack(2, 20, 0)) or ""
    local ours = {}
    for line in stack:gmatch("[^\n]+") do
      if line:find("AddOns[/\\]Stats[/\\]") or line:find("Stats/") then ours[#ours + 1] = line end
    end
    local where = #ours > 0 and table.concat(ours, " | ", 1, math.min(#ours, 4)) or stack:sub(1, 400)
    pending[#pending + 1] = { at = time(), ev = event, fn = tostring(fn or "?"), where = where,
      combat = InCombatLockdown() and true or false, build = select(4, GetBuildInfo()) }
    if type(StatsDB) == "table" then flush() end
  end)
end

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
