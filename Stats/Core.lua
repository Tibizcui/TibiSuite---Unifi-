--[[============================================================================
  Stats - Core.lua
  ---------------------------------------------------------------------------
  Enregistreur autonome + modele de donnees + agregation. Ce fichier pose ses
  propres crochets sur les evenements du jeu : aucune dependance a un autre
  module de la suite (LairLens, PostBox...). Si ces modules sont presents,
  Stats reste fonctionnel a l'identique - voir SX.externalEnrichHooks plus
  bas pour le point d'extension inerte reserve a un futur enrichissement
  (jamais une condition de fonctionnement).
============================================================================]]

local ADDON, SX = ...
local L = SX.L

StatsDB = StatsDB or {}

-- ============================================================================
-- CLES DE DATE
-- ============================================================================
local function dateTable(t) return date("*t", t) end

function SX.DayKey(t) return date("%Y-%m-%d", t) end
function SX.TodayKey() return SX.DayKey(time()) end

function SX.ParseDayKey(k)
  local y, m, d = k:match("^(%d+)-(%d+)-(%d+)$")
  if not y then return nil end
  return time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 0, min = 0, sec = 0 })
end

function SX.StartOfDay(t)
  local dt = dateTable(t)
  dt.hour, dt.min, dt.sec = 0, 0, 0
  return time(dt)
end

function SX.StartOfWeek(t)
  -- Semaine calendaire, debut lundi (date("*t").wday : 1=dimanche..7=samedi)
  local dt = dateTable(t)
  local diffToMonday = (dt.wday == 1) and 6 or (dt.wday - 2)
  return SX.StartOfDay(t) - diffToMonday * 86400
end

-- Fenetre "Or (semaine)" calee sur le reset hebdomadaire des raids, pas sur
-- la semaine calendaire (tache 3.5). Repli sur la semaine calendaire si
-- l'API de reset est indisponible.
function SX.WeeklyGoldRange()
  local now = time()
  local secs = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset and C_DateAndTime.GetSecondsUntilWeeklyReset()
  if not secs then
    local start = SX.StartOfWeek(now)
    return start, start + 7 * 86400 - 1, false
  end
  local nextReset = now + secs
  return nextReset - 7 * 86400, nextReset - 1, true
end

-- Bornes [from, to] (inclusives) d'une periode, decalee de `offset` unites
-- (0 = periode courante, -1 = precedente, ...).
function SX.PeriodRange(period, offset)
  offset = offset or 0
  local now = time()
  if period == "day" then
    local start = SX.StartOfDay(now) + offset * 86400
    return start, start + 86399
  elseif period == "week" then
    local start = SX.StartOfWeek(now) + offset * 7 * 86400
    return start, start + 7 * 86400 - 1
  elseif period == "month" then
    local dt = dateTable(now)
    dt.day, dt.hour, dt.min, dt.sec = 1, 0, 0, 0
    dt.month = dt.month + offset
    local start = time(dt)
    local dt2 = dateTable(start)
    dt2.month = dt2.month + 1
    return start, time(dt2) - 1
  elseif period == "year" then
    local dt = dateTable(now)
    dt.month, dt.day, dt.hour, dt.min, dt.sec = 1, 1, 0, 0, 0
    dt.year = dt.year + offset
    local start = time(dt)
    local dt2 = dateTable(start)
    dt2.year = dt2.year + 1
    return start, time(dt2) - 1
  end
  return SX.StartOfDay(now), SX.StartOfDay(now) + 86399
end

-- ============================================================================
-- MODELE DE DONNEES
-- ============================================================================
function SX.CurrentCharKey()
  return UnitName("player") .. "-" .. GetRealmName()
end

function SX.EnsureChar(key)
  local rec = StatsDB[key]
  if not rec then
    rec = { days = {} }
    StatsDB[key] = rec
  end
  rec.days = rec.days or {}
  return rec
end

function SX.EnsureDay(rec, dayKey)
  local d = rec.days[dayKey]
  if not d then
    d = { quests = 0, goldGain = 0, goldSpent = 0, played = 0, dungeons = 0, mplus = {} }
    rec.days[dayKey] = d
  end
  d.mplus = d.mplus or {}
  return d
end

-- Purge les jours les plus anciens au-dela du plafond (borne la taille des
-- SavedVariables, meme principe que PostBox).
function SX.PurgeOldDays(rec)
  local keys = {}
  for k in pairs(rec.days) do keys[#keys + 1] = k end
  if #keys <= SX.HISTORY_MAX_DAYS then return end
  table.sort(keys)
  for i = 1, #keys - SX.HISTORY_MAX_DAYS do rec.days[keys[i]] = nil end
end

function SX.GetCharKeys()
  local keys = {}
  for k in pairs(StatsDB) do keys[#keys + 1] = k end
  table.sort(keys)
  return keys
end

-- Bandeau perso (tache 2) : donnees stockees, mises a jour a chaque login/
-- changement de spe/equipement - permet au bandeau de rester correct pour un
-- personnage hors-ligne (liste Stats, comparaison).
function SX.RefreshCharMeta()
  local key = SX.CurrentCharKey()
  local rec = SX.EnsureChar(key)
  rec.class = select(2, UnitClass("player"))
  rec.level = UnitLevel("player")
  rec.realm = GetRealmName()
  rec.name = UnitName("player")
  rec.spec = nil
  local specIndex = GetSpecialization and GetSpecialization()
  if specIndex then
    local _, specName = GetSpecializationInfo(specIndex)
    rec.spec = specName
  end
  if GetAverageItemLevel then
    local _, avgEquipped = GetAverageItemLevel()
    if avgEquipped then rec.ilvl = math.floor(avgEquipped + 0.5) end
  end
  return rec
end

function SX.CharBannerData(charKey)
  local rec = StatsDB[charKey]
  if not rec then return nil end
  local name, realm = charKey:match("^(.-)%-(.+)$")
  return {
    name = rec.name or name, realm = rec.realm or realm,
    class = rec.class, level = rec.level, ilvl = rec.ilvl, spec = rec.spec,
  }
end

-- ============================================================================
-- AGREGATION
-- ============================================================================
function SX.Aggregate(charKey, from, to)
  local agg = { quests = 0, goldGain = 0, goldSpent = 0, played = 0, dungeons = 0, mplusCount = 0, mplusList = {} }
  local rec = StatsDB[charKey]
  if not rec or not rec.days then return agg end
  for dayKey, d in pairs(rec.days) do
    local t = SX.ParseDayKey(dayKey)
    if t and t >= from and t <= to then
      agg.quests    = agg.quests + (d.quests or 0)
      agg.goldGain  = agg.goldGain + (d.goldGain or 0)
      agg.goldSpent = agg.goldSpent + (d.goldSpent or 0)
      agg.played    = agg.played + (d.played or 0)
      agg.dungeons  = agg.dungeons + (d.dungeons or 0)
      if d.mplus then
        for _, run in ipairs(d.mplus) do
          agg.mplusCount = agg.mplusCount + 1
          agg.mplusList[#agg.mplusList + 1] = run
        end
      end
    end
  end
  return agg
end

function SX.AggregateAccount(from, to)
  local agg = { quests = 0, goldGain = 0, goldSpent = 0, played = 0, dungeons = 0, mplusCount = 0, mplusList = {} }
  for key in pairs(StatsDB) do
    local a = SX.Aggregate(key, from, to)
    agg.quests    = agg.quests + a.quests
    agg.goldGain  = agg.goldGain + a.goldGain
    agg.goldSpent = agg.goldSpent + a.goldSpent
    agg.played    = agg.played + a.played
    agg.dungeons  = agg.dungeons + a.dungeons
    agg.mplusCount = agg.mplusCount + a.mplusCount
  end
  return agg
end

function SX.AggregateFor(charKey, from, to)
  if charKey == "__account__" then return SX.AggregateAccount(from, to) end
  return SX.Aggregate(charKey, from, to)
end

function SX.MetricValue(agg, metric)
  if metric == "quests" then return agg.quests
  elseif metric == "gold" then return agg.goldGain - agg.goldSpent
  elseif metric == "dungeons" then return agg.dungeons + agg.mplusCount
  elseif metric == "played" then return agg.played
  end
  return 0
end

-- Serie de `count` points se terminant a la periode courante, granularite
-- day/week/month. Utilisee pour les mini-courbes et le detail par metrique.
function SX.BuildSeries(charKey, metric, granularity, count)
  local series = {}
  local now = time()
  for i = count - 1, 0, -1 do
    local from, to, label
    if granularity == "day" then
      from = SX.StartOfDay(now) - i * 86400
      to = from + 86399
      label = date("%d/%m", from)
    elseif granularity == "week" then
      from = SX.StartOfWeek(now) - i * 7 * 86400
      to = from + 7 * 86400 - 1
      label = date("%d/%m", from)
    else -- month
      local dt = dateTable(now)
      dt.day, dt.hour, dt.min, dt.sec = 1, 0, 0, 0
      dt.month = dt.month - i
      from = time(dt)
      local dt2 = dateTable(from)
      dt2.month = dt2.month + 1
      to = time(dt2) - 1
      label = date("%m/%y", from)
    end
    local agg = SX.AggregateFor(charKey, from, to)
    series[#series + 1] = { label = label, value = SX.MetricValue(agg, metric), from = from, to = to }
  end
  return series
end

function SX.MinMaxAvg(series)
  local minV, maxV, sum, n = nil, nil, 0, 0
  for _, p in ipairs(series) do
    if minV == nil or p.value < minV then minV = p.value end
    if maxV == nil or p.value > maxV then maxV = p.value end
    sum = sum + p.value
    n = n + 1
  end
  return minV or 0, maxV or 0, (n > 0 and sum / n or 0)
end

-- La periode "annee" ne se debloque qu'avec un an de donnees accumulees.
function SX.HasFullYearOfData()
  local earliest = nil
  for _, rec in pairs(StatsDB) do
    for dayKey in pairs(rec.days or {}) do
      local t = SX.ParseDayKey(dayKey)
      if t and (not earliest or t < earliest) then earliest = t end
    end
  end
  if not earliest then return false end
  return (time() - earliest) >= 365 * 86400
end

-- ============================================================================
-- ENREGISTREUR : OR
-- ============================================================================
local lastMoney = nil

local function OnPlayerMoney()
  local now = GetMoney()
  if lastMoney ~= nil then
    local delta = now - lastMoney
    if delta ~= 0 then
      local rec = SX.EnsureChar(SX.CurrentCharKey())
      local d = SX.EnsureDay(rec, SX.TodayKey())
      if delta > 0 then d.goldGain = (d.goldGain or 0) + delta
      else d.goldSpent = (d.goldSpent or 0) + (-delta) end
    end
  end
  lastMoney = now
end

-- ============================================================================
-- ENREGISTREUR : QUETES
-- ============================================================================
local function OnQuestTurnedIn()
  local rec = SX.EnsureChar(SX.CurrentCharKey())
  local d = SX.EnsureDay(rec, SX.TodayKey())
  d.quests = (d.quests or 0) + 1
end

-- ============================================================================
-- ENREGISTREUR : MYTHIQUE+
-- ============================================================================
local function OnChallengeModeCompleted()
  if not (C_ChallengeMode and C_ChallengeMode.GetCompletionInfo) then return end
  local ok, mapID, level, time_, onTime = pcall(C_ChallengeMode.GetCompletionInfo)
  if not ok or not mapID then return end
  local mapName = mapID
  if C_ChallengeMode.GetMapUIInfo then
    local n = C_ChallengeMode.GetMapUIInfo(mapID)
    if n then mapName = n end
  end
  local rec = SX.EnsureChar(SX.CurrentCharKey())
  local d = SX.EnsureDay(rec, SX.TodayKey())
  d.mplus = d.mplus or {}
  table.insert(d.mplus, { map = mapName, level = level, time = time_, done = onTime and true or false })
end

-- ============================================================================
-- ENREGISTREUR : DONJONS NORMAUX (heuristique zone + boss)
-- ---------------------------------------------------------------------------
-- Pas d'evenement Blizzard "donjon termine" fiable pour les groupes hors
-- Recherche de groupe. Heuristique : a la sortie d'une instance de type
-- "party", si le DERNIER combat de boss reussi (ENCOUNTER_END, success=1)
-- correspond au DERNIER encounter connu du Bestiaire (C_EncounterJournal)
-- pour cette instance, on compte un donjon termine. Resolution dynamique du
-- "boss final" - pas de table a maintenir a la main.
-- A VERIFIER EN JEU : noms de fonctions C_EncounterJournal / EJ_* contre
-- l'API Midnight en cours (non exerce dans le reste du depot). Toute la
-- resolution est protegee par pcall : en cas d'API differente, on echoue
-- proprement (le compteur "donjons" reste simplement a 0, sans erreur).
-- ============================================================================
local instanceSession = nil  -- { mapID = , lastEncounterID = }

local function ResolveFinalEncounterID(mapID)
  if not (mapID and C_EncounterJournal) then return nil end
  local ok, result = pcall(function()
    local journalInstanceID
    if C_EncounterJournal.GetInstanceForGameMapID then
      journalInstanceID = C_EncounterJournal.GetInstanceForGameMapID(mapID)
    end
    if not journalInstanceID then return nil end
    if EJ_SelectInstance then EJ_SelectInstance(journalInstanceID) end
    local lastID
    local i = 1
    while true do
      local name, _, encounterID = EJ_GetEncounterInfoByIndex(i, journalInstanceID)
      if not name then break end
      lastID = encounterID
      i = i + 1
      if i > 40 then break end -- garde-fou
    end
    return lastID
  end)
  if ok then return result end
  return nil
end

local function EvaluateDungeonCompletion(session)
  if not session or not session.lastEncounterID then return end
  local finalID = ResolveFinalEncounterID(session.mapID)
  if finalID and finalID == session.lastEncounterID then
    local rec = SX.EnsureChar(SX.CurrentCharKey())
    local d = SX.EnsureDay(rec, SX.TodayKey())
    d.dungeons = (d.dungeons or 0) + 1
  end
end

local function OnEnteringWorld()
  local inInstance, instanceType = IsInInstance()
  if inInstance and instanceType == "party" then
    local _, _, _, _, _, _, _, mapID = GetInstanceInfo()
    if not instanceSession or instanceSession.mapID ~= mapID then
      -- Nouvelle session : evalue l'ancienne (si on vient d'une autre instance) puis ouvre la nouvelle
      if instanceSession then EvaluateDungeonCompletion(instanceSession) end
      instanceSession = { mapID = mapID, lastEncounterID = nil }
    end
  else
    if instanceSession then
      EvaluateDungeonCompletion(instanceSession)
      instanceSession = nil
    end
  end
end

local function OnEncounterEnd(encounterID, _, _, _, success)
  if instanceSession and success == 1 then
    instanceSession.lastEncounterID = encounterID
  end
end

-- ============================================================================
-- ENREGISTREUR : TEMPS DE JEU
-- ============================================================================
local lastFlush = nil

local function FlushPlayed()
  if not lastFlush then lastFlush = GetTime(); return end
  local now = GetTime()
  local elapsed = now - lastFlush
  lastFlush = now
  if elapsed <= 0 then return end
  local rec = SX.EnsureChar(SX.CurrentCharKey())
  local d = SX.EnsureDay(rec, SX.TodayKey())
  d.played = (d.played or 0) + elapsed
end

-- ============================================================================
-- POINT D'EXTENSION INERTE (jamais une condition de fonctionnement)
-- Si LairLens/PostBox sont presents, un futur enrichissement pourra
-- s'inscrire ici. Volontairement vide pour l'instant : mieux vaut aucune
-- fusion de donnees inter-modules non testee qu'une heuristique de double-
-- comptage silencieuse. Stats reste correct et complet seul.
-- ============================================================================
SX.externalEnrichHooks = SX.externalEnrichHooks or {}

-- ============================================================================
-- CADRE D'EVENEMENTS
-- ============================================================================
local evFrame = CreateFrame("Frame")
evFrame:RegisterEvent("ADDON_LOADED")
evFrame:RegisterEvent("PLAYER_LOGIN")
evFrame:RegisterEvent("PLAYER_MONEY")
evFrame:RegisterEvent("QUEST_TURNED_IN")
evFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
evFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
evFrame:RegisterEvent("ENCOUNTER_END")
evFrame:RegisterEvent("PLAYER_LOGOUT")
evFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
evFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
evFrame:RegisterEvent("PLAYER_LEVEL_UP")

evFrame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    local addonName = ...
    if addonName ~= "Stats" then return end
    StatsDB = StatsDB or {}

  elseif event == "PLAYER_LOGIN" then
    lastMoney = GetMoney()
    lastFlush = GetTime()
    SX.RefreshCharMeta()
    local rec = SX.EnsureChar(SX.CurrentCharKey())
    SX.PurgeOldDays(rec)
    C_Timer.NewTicker(60, FlushPlayed)

  elseif event == "PLAYER_MONEY" then
    OnPlayerMoney()

  elseif event == "QUEST_TURNED_IN" then
    OnQuestTurnedIn()

  elseif event == "CHALLENGE_MODE_COMPLETED" then
    OnChallengeModeCompleted()

  elseif event == "PLAYER_ENTERING_WORLD" then
    OnEnteringWorld()

  elseif event == "ENCOUNTER_END" then
    OnEncounterEnd(...)

  elseif event == "PLAYER_LOGOUT" then
    FlushPlayed()
    -- Auto-persistance de l'export (companion Dashboard-Tibi) : ecrit le
    -- dernier code d'export dans StatsDB pour que le fichier Stats.lua
    -- contienne toujours la derniere version, lisible meme le jeu ferme.
    -- PLAYER_LOGOUT couvre a la fois /reload et la deconnexion.
    if SX.Export and SX.Export.Generate then
      local ok, code = pcall(SX.Export.Generate)
      if ok and type(code) == "string" and code ~= "" then
        StatsDB.export = code
        StatsDB.exportedAt = time()
      end
    end

  elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_LEVEL_UP" then
    SX.RefreshCharMeta()
  end
end)
