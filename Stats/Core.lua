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

-- CORRECTIF confirme en jeu : StatsDB.export (chaine) et StatsDB.exportedAt
-- (nombre), ecrits a PLAYER_LOGOUT pour le companion Dashboard-Tibi (cf.
-- Core.lua plus bas), sont des cles de PREMIER NIVEAU au meme titre que les
-- "Nom-Royaume" - un simple `pairs(StatsDB)` les confondait avec des
-- personnages. Un personnage est TOUJOURS une table ; on ne garde donc que
-- ca, ce qui ecarte ces deux cles (et toute future cle non-personnage) sans
-- avoir a les nommer en dur.
function SX.GetCharKeys()
  local keys = {}
  for k, v in pairs(StatsDB) do
    if type(v) == "table" then keys[#keys + 1] = k end
  end
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
  SX.RefreshAchievementPoints(rec)
  rec.pvp = SX.CollectPvPSnapshot(rec)
  SX.RefreshDelveCompanion(rec)
  rec.torghast = SX.CollectTorghastSnapshot()
  SX.ScanTorghastAchievements(rec)
  return rec
end

-- ============================================================================
-- HAUTS FAITS + PVP : compteurs "instantanes" fournis directement par
-- Blizzard (pas d'historique jour par jour cote client, contrairement aux
-- quetes/or/donjons) - on stocke juste le dernier snapshot connu, rafraichi
-- au login, a chaque changement de spe/equipement/niveau, a chaque haut fait
-- obtenu et a chaque fin de partie PVP.
-- ============================================================================
function SX.RefreshAchievementPoints(rec)
  if not GetTotalAchievementPoints then return end
  local ok, pts = pcall(GetTotalAchievementPoints)
  if ok and type(pts) == "number" then rec.achievementPoints = pts end
end

-- CORRECTIF A VERIFIER EN JEU : l'ordre des brackets (1=Arene 2c2, 2=Arene
-- 3c3, 3=BG classe, 4=Melee solo, 5=Blitz) suit l'ordre d'ajout historique de
-- Blizzard (jamais reordonne au fil des extensions, seulement complete), mais
-- n'a pas ete confirme en jeu sur ce client - a valider par Tibiscui avec un
-- personnage ayant des cotes dans plusieurs brackets, puis ajuster ici si
-- besoin (rien d'autre a toucher : Export.lua/dashboard-shared.js lisent ces
-- cles telles quelles, pas les index).
local PVP_BRACKETS = {
  { key = "2v2",     index = 1 },
  { key = "3v3",     index = 2 },
  { key = "rbg",     index = 3 },
  { key = "shuffle", index = 4 },
  { key = "blitz",   index = 5 },
}

-- Honneur = devise 1792, Conquete = devise 1602 (stables depuis Battle for
-- Azeroth) - a verifier en jeu si les montants affiches semblent faux.
local HONOR_CURRENCY_ID = 1792
local CONQUEST_CURRENCY_ID = 1602

-- Brackets qui se jouent en arene (2c2/3c3/melee solo) - utilise pour le
-- cumul "arene" tous formats confondus, distinct des champs de bataille
-- classes (rbg) et de Blitz (bataille classee mais pas une arene).
local ARENA_BRACKET_KEYS = { "2v2", "3v3", "shuffle" }

-- rec est optionnel : sert a recuperer les compteurs suivis par l'addon
-- lui-meme (morts PVP, champs de bataille) - Blizzard n'expose aucun total
-- direct pour ceux-la, contrairement au reste de cette fonction.
function SX.CollectPvPSnapshot(rec)
  local ok, result = pcall(function()
    local brackets = {}
    for _, b in ipairs(PVP_BRACKETS) do
      local rating, seasonBest, weeklyBest, seasonPlayed, seasonWon = GetPersonalRatedInfo(b.index)
      if rating and seasonPlayed and seasonPlayed > 0 then
        brackets[b.key] = {
          rating = rating, seasonBest = seasonBest,
          seasonPlayed = seasonPlayed, seasonWon = seasonWon,
        }
      end
    end
    local arenaPlayed, arenaWon, hasArena = 0, 0, false
    for _, key in ipairs(ARENA_BRACKET_KEYS) do
      local b = brackets[key]
      if b then
        hasArena = true
        arenaPlayed = arenaPlayed + (b.seasonPlayed or 0)
        arenaWon = arenaWon + (b.seasonWon or 0)
      end
    end
    local honor, conquest
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
      local h = C_CurrencyInfo.GetCurrencyInfo(HONOR_CURRENCY_ID)
      local c = C_CurrencyInfo.GetCurrencyInfo(CONQUEST_CURRENCY_ID)
      honor = h and h.quantity
      conquest = c and c.quantity
    end
    -- Cumul VIE ENTIERE (pas juste la saison), fourni directement par
    -- Blizzard - confirme encore present et fonctionnel en 11.1.0 (2025).
    local honorableKills
    if GetPVPLifetimeStats then
      local ok2, hk = pcall(GetPVPLifetimeStats)
      if ok2 and type(hk) == "number" then honorableKills = hk end
    end
    local deathsByPlayers = rec and rec.pvpDeathsByPlayers
    local deathsByEnemyFaction = rec and rec.pvpDeathsByEnemyFaction
    local bgParticipation = rec and rec.bgParticipation
    local bgWinsTotal = rec and rec.bgWinsTotal
    local bgWinsByName = rec and rec.bgWinsByName
    if not next(brackets) and not honor and not conquest and not honorableKills
      and not deathsByPlayers and not deathsByEnemyFaction and not bgParticipation then
      return nil
    end
    return {
      brackets = brackets, honor = honor, conquest = conquest,
      honorableKills = honorableKills,
      deathsByPlayers = deathsByPlayers, deathsByEnemyFaction = deathsByEnemyFaction,
      arena = hasArena and { played = arenaPlayed, won = arenaWon } or nil,
      bgParticipation = bgParticipation, bgWinsTotal = bgWinsTotal, bgWinsByName = bgWinsByName,
    }
  end)
  if ok then return result end
  return nil
end

-- ============================================================================
-- CAUSE DES MORTS (qui a inflige le coup fatal) : Blizzard n'expose aucun
-- total direct - reconstruit en retenant la derniere source de degats recue
-- juste avant PLAYER_DEAD, via COMBAT_LOG_EVENT_UNFILTERED. Technique
-- standard des addons "qui m'a tue". COMBATLOG_OBJECT_TYPE_PLAYER et
-- COMBATLOG_OBJECT_REACTION_HOSTILE sont des constantes Blizzard stables de
-- longue date (utilisees par la plupart des addons de journal de combat).
-- A VERIFIER EN JEU : peut mal attribuer si le coup fatal est un DoT dont la
-- source a quitte l'instance, ou un degat environnemental juste apres un
-- dernier coup de joueur (cas limites assumes, pas de solution parfaite
-- cote client).
-- ============================================================================
local lastDamageSource -- { isPlayer=bool, isHostile=bool }
local DAMAGE_SUBEVENTS = {
  SWING_DAMAGE = true, RANGE_DAMAGE = true, SPELL_DAMAGE = true,
  SPELL_PERIODIC_DAMAGE = true, SPELL_BUILDING_DAMAGE = true,
  ENVIRONMENTAL_DAMAGE = true,
}

local function OnCombatLogEvent()
  local _, subEvent, _, sourceGUID, _, sourceFlags, _, destGUID = CombatLogGetCurrentEventInfo()
  if not DAMAGE_SUBEVENTS[subEvent] then return end
  if destGUID ~= UnitGUID("player") then return end
  if not sourceGUID or sourceGUID == "" then return end
  lastDamageSource = {
    isPlayer = sourceFlags and bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_PLAYER) ~= 0,
    isHostile = sourceFlags and bit.band(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) ~= 0,
  }
end

local function OnPlayerDead()
  local rec = SX.EnsureChar(SX.CurrentCharKey())
  if lastDamageSource and lastDamageSource.isPlayer then
    rec.pvpDeathsByPlayers = (rec.pvpDeathsByPlayers or 0) + 1
    if lastDamageSource.isHostile then
      rec.pvpDeathsByEnemyFaction = (rec.pvpDeathsByEnemyFaction or 0) + 1
    end
  end
  lastDamageSource = nil
  rec.pvp = SX.CollectPvPSnapshot(rec)
end

-- ============================================================================
-- CHAMPS DE BATAILLE : participations + victoires (totales et par champ de
-- bataille), classes et non classes confondus - Blizzard ne distingue pas
-- cote client de maniere simple. GetBattlefieldWinner() retourne l'equipe
-- gagnante (0=Horde, 1=Alliance) - convention stable de longue date. A
-- VERIFIER EN JEU : le nom retourne par GetInstanceInfo() peut varier selon
-- la version/le mode (normal vs classe) d'un meme champ de bataille, ce qui
-- fractionnerait le detail par nom au lieu de le regrouper.
-- ============================================================================
local function OnBattlegroundComplete()
  local inInstance, instanceType = IsInInstance()
  if not inInstance or instanceType ~= "pvp" then return end
  local name = GetInstanceInfo()
  local rec = SX.EnsureChar(SX.CurrentCharKey())
  rec.bgParticipation = (rec.bgParticipation or 0) + 1

  local winnerFaction
  if GetBattlefieldWinner then
    local ok, winner = pcall(GetBattlefieldWinner)
    if ok then winnerFaction = winner end
  end
  local myFaction = UnitFactionGroup("player")
  local myFactionIndex = (myFaction == "Horde") and 0 or (myFaction == "Alliance" and 1 or nil)
  if winnerFaction ~= nil and myFactionIndex ~= nil and winnerFaction == myFactionIndex then
    rec.bgWinsTotal = (rec.bgWinsTotal or 0) + 1
    rec.bgWinsByName = rec.bgWinsByName or {}
    if name and name ~= "" then
      rec.bgWinsByName[name] = (rec.bgWinsByName[name] or 0) + 1
    end
  end
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
  local agg = { quests = 0, goldGain = 0, goldSpent = 0, played = 0, dungeons = 0, mplusCount = 0, mplusList = {}, delves = 0 }
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
      agg.delves    = agg.delves + (d.delves or 0)
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
  local agg = { quests = 0, goldGain = 0, goldSpent = 0, played = 0, dungeons = 0, mplusCount = 0, mplusList = {}, delves = 0 }
  -- SX.GetCharKeys() plutot que pairs(StatsDB) direct : ecarte StatsDB.export
  -- / StatsDB.exportedAt (cf. son commentaire) qui feraient planter
  -- SX.Aggregate en tentant de lire ".days" sur une chaine ou un nombre.
  for _, key in ipairs(SX.GetCharKeys()) do
    local a = SX.Aggregate(key, from, to)
    agg.quests    = agg.quests + a.quests
    agg.goldGain  = agg.goldGain + a.goldGain
    agg.goldSpent = agg.goldSpent + a.goldSpent
    agg.played    = agg.played + a.played
    agg.dungeons  = agg.dungeons + a.dungeons
    agg.mplusCount = agg.mplusCount + a.mplusCount
    agg.delves    = agg.delves + a.delves
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
  elseif metric == "delves" then return agg.delves
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
-- CORRECTIF confirme en jeu : sans le filtre type(rec)=="table", cette
-- fonction plantait des qu'elle atteignait StatsDB.exportedAt (un nombre,
-- cf. GetCharKeys plus haut) - "attempt to index a number value" sur
-- rec.days. Comme HasFullYearOfData() est appelee a CHAQUE ouverture du
-- tableau de bord (boutons de periode), l'erreur interrompait
-- RefreshDashboard() avant meme d'atteindre BuildOverview() : la fenetre
-- Stats s'ouvrait avec l'entete correct mais AUCUNE carte affichee.
function SX.HasFullYearOfData()
  local earliest = nil
  for _, rec in pairs(StatsDB) do
    if type(rec) == "table" then
      for dayKey in pairs(rec.days or {}) do
        local t = SX.ParseDayKey(dayKey)
        if t and (not earliest or t < earliest) then earliest = t end
      end
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
-- ENREGISTREUR : GOUFFRES (Delves)
-- ----------------------------------------------------------------------------
-- Aucune fonction Blizzard ne fournit un compteur "gouffres completes" ou un
-- "palier max atteint" (verifie en jeu le 2026-09-07 : liste complete de
-- C_DelvesUI, rien de tel dedans). Reconstruit ici via SCENARIO_COMPLETED,
-- comme le font les addons de suivi de gouffres actuels (ex: DelveGuide).
-- A VERIFIER EN JEU : rien ne garantit que SCENARIO_COMPLETED ne se
-- declenche QUE pour un gouffre - d'ou le filtre HasActiveDelve/IsInLair
-- avant de compter quoi que ce soit, pour ecarter les autres scenarios
-- (montee de niveau, donjons scenarises, etc.).
-- ============================================================================
-- Palier "max" a considerer complet dans le suivi par type (SX.DelveAllMaxed
-- ci-dessous) - 8 est le plafond a la sortie de The War Within, a ajuster si
-- une extension future en ajoute davantage.
SX.DELVE_MAX_TIER = 8

local function OnScenarioCompleted()
  if not C_DelvesUI then return end
  local inDelve = (C_DelvesUI.HasActiveDelve and C_DelvesUI.HasActiveDelve())
    or (C_DelvesUI.IsInLair and C_DelvesUI.IsInLair())
  if not inDelve then return end
  local tier
  if C_DelvesUI.GetActiveDelveTier then
    local ok, t = pcall(C_DelvesUI.GetActiveDelveTier)
    if ok and type(t) == "number" then tier = t end
  end
  local rec = SX.EnsureChar(SX.CurrentCharKey())
  local d = SX.EnsureDay(rec, SX.TodayKey())
  d.delves = (d.delves or 0) + 1
  if tier and (not rec.delveHighestTier or tier > rec.delveHighestTier) then
    rec.delveHighestTier = tier
  end

  -- Detail par type de gouffre (ex: "La Folie Fongique") : Blizzard n'expose
  -- pas le nom du gouffre actif directement (C_Scenario.GetInfo() renvoie le
  -- nom generique "Delves", confirme par recherche externe, pas par test en
  -- jeu) - repli sur le texte de sous-zone, les gouffres etant des lieux
  -- geographiques du monde comme les autres. A VERIFIER EN JEU : peut
  -- renvoyer une chaine vide/inattendue selon le moment exact de l'evenement.
  local delveName = GetSubZoneText and GetSubZoneText()
  if not delveName or delveName == "" then delveName = GetZoneText and GetZoneText() end
  if delveName and delveName ~= "" then
    rec.delveTypes = rec.delveTypes or {}
    local entry = rec.delveTypes[delveName] or { count = 0, highestTier = 0 }
    entry.count = entry.count + 1
    if tier and tier > entry.highestTier then entry.highestTier = tier end
    rec.delveTypes[delveName] = entry
  end
end

-- true si au moins un type de gouffre a ete rencontre ET que tous ont
-- atteint SX.DELVE_MAX_TIER - ne pretend pas connaitre la liste officielle
-- complete des gouffres existants, seulement ceux effectivement rencontres
-- par ce personnage (une liste incomplete de types "tous maxes" resterait
-- vraie tant que de nouveaux types non-maxes n'ont pas encore ete tentes).
function SX.DelveAllMaxed(rec)
  if not rec or not rec.delveTypes or not next(rec.delveTypes) then return false end
  for _, entry in pairs(rec.delveTypes) do
    if (entry.highestTier or 0) < SX.DELVE_MAX_TIER then return false end
  end
  return true
end

-- Niveau du compagnon de gouffre (Brann Bronzebeard) - snapshot instantane,
-- rafraichi comme les points de hauts faits (pas lie a une completion
-- particuliere). A VERIFIER EN JEU : le nom du champ "niveau" dans la table
-- retournee par GetCompanionInfoForActivePlayer() n'a pas ete confirme,
-- plusieurs noms plausibles sont essayes par prudence.
function SX.RefreshDelveCompanion(rec)
  if not (C_DelvesUI and C_DelvesUI.GetCompanionInfoForActivePlayer) then return end
  local ok, info = pcall(C_DelvesUI.GetCompanionInfoForActivePlayer)
  if not ok or type(info) ~= "table" then return end
  local level = info.level or info.companionLevel or info.CompanionLevel
  if type(level) == "number" then rec.delveCompanionLevel = level end
end

-- ============================================================================
-- TOURMENTS (Torghast) : contenu ancien (Ombreterre). Pas d'evenement de fin
-- de run identifie ni de compteur Blizzard pour un nombre de runs - on se
-- limite aux monnaies encore lisibles (Cendres d'ame / Cendres d'ames
-- noires) et au palier le plus haut valide via les hauts faits de suivi de
-- palier. A VERIFIER EN JEU : la plage d'identifiants (14596-14604, paliers
-- 1 a 9) n'est confirmee que pour les paliers 1, 8 et 9 - les autres sont
-- une extrapolation (suite consecutive probable, pas verifiee), et rien
-- au-dela du palier 9 n'est couvert.
-- ============================================================================
local SOUL_ASH_CURRENCY_ID = 1828
local SOUL_CINDERS_CURRENCY_ID = 1906
local TORGHAST_LAYER_ACHIEVEMENTS = {
  [1] = 14596, [2] = 14597, [3] = 14598, [4] = 14599, [5] = 14600,
  [6] = 14601, [7] = 14602, [8] = 14603, [9] = 14604,
}

function SX.CollectTorghastSnapshot()
  local ok, result = pcall(function()
    local ash, cinders
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
      local a = C_CurrencyInfo.GetCurrencyInfo(SOUL_ASH_CURRENCY_ID)
      local c = C_CurrencyInfo.GetCurrencyInfo(SOUL_CINDERS_CURRENCY_ID)
      ash = a and a.quantity
      cinders = c and c.quantity
    end
    local highestLayer
    if GetAchievementInfo then
      for layer, achID in pairs(TORGHAST_LAYER_ACHIEVEMENTS) do
        local ok2, _, _, _, completed = pcall(GetAchievementInfo, achID)
        if ok2 and completed and (not highestLayer or layer > highestLayer) then
          highestLayer = layer
        end
      end
    end
    if not ash and not cinders and not highestLayer then return nil end
    return { soulAsh = ash, soulCinders = cinders, highestLayer = highestLayer }
  end)
  if ok then return result end
  return nil
end

-- ============================================================================
-- TOURMENT PAR DONJON : difficulte "Tourment" appliquee a des donjons
-- classiques, avec un haut fait distinct par donjon/echelon (ex: "Tourment :
-- Couloirs Distordus (echelon 6)", confirme en jeu le 2026-09 par Tibiscui -
-- different de la tour Torghast/Ombreterre suivie plus haut, malgre le meme
-- mot "Tourment"). Capte via ACHIEVEMENT_EARNED (evenements futurs) ET un
-- scan retroactif au login (hauts faits deja obtenus avant l'ajout de ce
-- suivi, qui ne redeclenchent jamais ACHIEVEMENT_EARNED).
-- ============================================================================

-- Deux formats confirmes en jeu le 2026-09-08 (meme donjon "Couloirs
-- Distordus", brackets d'echelons differents) :
--   "Tourment : couloirs Distordus (echelon 6)"   (echelons 6-8, ID >= 14568)
--   "Couloirs Distordus : echelon 1"              (echelons 1-5, ID <= 14472,
--                                                   pas de prefixe "Tourment",
--                                                   pas de parentheses)
-- CORRECTIF confirme en jeu (2026-09-08) : une premiere version basee sur
-- %s*/le mot "echelon" accentue echouait silencieusement sur les 8 hauts
-- faits reels malgre un test reussi hors jeu sur les memes chaines - cause
-- la plus probable : l'espace juste avant ":" dans "Tourment :" n'est pas
-- un espace ASCII normal (probablement une espace insecable, convention
-- typographique francaise avant ":"), que %s ne reconnait pas, et/ou un
-- encodage different de "e" accentue (NFC/NFD) entre le fichier addon et le
-- texte du client. Repli total sur des ancres ASCII exactes (":", "(",
-- "chelon", chiffres) via string.find en mode texte brut - aucune
-- dependance a un espace ou un octet accentue precis, quel que soit
-- l'encodage/la typographie autour.
local function ExtractTourmentDungeon(name)
  if not name:find("chelon", 1, true) then return nil, nil end
  local echelon = name:match("chelon%D-(%d+)")
  if not echelon then return nil, nil end

  local colonPos = name:find(":", 1, true)
  if not colonPos then return nil, nil end

  local dungeonName
  if name:find("^[Tt]ourment") then
    -- Format "Tourment : <donjon> (echelon N)" - le donjon est entre ":" et "(".
    local parenPos = name:find("(", colonPos, true)
    if not parenPos then return nil, nil end
    dungeonName = name:sub(colonPos + 1, parenPos - 1)
  else
    -- Format "<donjon> : echelon N" - le donjon est avant ":".
    dungeonName = name:sub(1, colonPos - 1)
  end
  -- Normalise toute espace insecable (U+00A0, octets 194 160 en UTF-8) en
  -- espace normale avant de trimmer - confirme en jeu (2026-09-08) : une
  -- espace insecable juste avant la parenthese ouvrante restait invisible a
  -- l'affichage mais empechait la fusion de "couloirs Distordus" (echelons
  -- 6-8) avec "Couloirs Distordus" (echelons 1-5) en une seule entree.
  dungeonName = dungeonName:gsub(string.char(194, 160), " ")
  dungeonName = dungeonName:gsub("^%s+", ""):gsub("%s+$", "")
  if dungeonName == "" then return nil, nil end
  return dungeonName, echelon
end

-- Traite UN haut fait "Tourment" - partage par le gestionnaire d'evenement
-- et le scan retroactif. Dedoublonne par ID de haut fait (definitif : jamais
-- recompte, meme si ACHIEVEMENT_EARNED se declenche deux fois pour le meme
-- haut fait, constate en jeu).
local function RecordTorghastAchievement(rec, achievementID)
  if not achievementID or not GetAchievementInfo then return end
  rec.seenAchievementIDs = rec.seenAchievementIDs or {}
  if rec.seenAchievementIDs[achievementID] then return end

  local ok, _, name, _, completed = pcall(GetAchievementInfo, achievementID)
  if not ok or type(name) ~= "string" then return end
  if completed == false then return end -- nil (ancienne signature) accepte, false refuse explicitement
  local dungeonName, echelon = ExtractTourmentDungeon(name)
  if not dungeonName or dungeonName == "" or not echelon then return end
  -- Normalise la casse de la premiere lettre (ASCII) : les deux formats
  -- observes different sur ce point ("Couloirs" vs "couloirs") et creeraient
  -- sinon deux entrees separees pour le meme donjon.
  dungeonName = dungeonName:sub(1, 1):upper() .. dungeonName:sub(2)

  rec.seenAchievementIDs[achievementID] = true
  rec.torghastByDungeon = rec.torghastByDungeon or {}
  local entry = rec.torghastByDungeon[dungeonName] or { count = 0, highestEchelon = 0 }
  entry.count = entry.count + 1
  local echelonNum = tonumber(echelon) or 0
  if echelonNum > entry.highestEchelon then entry.highestEchelon = echelonNum end
  rec.torghastByDungeon[dungeonName] = entry
end

local function OnAchievementEarned(achievementID)
  local rec = SX.EnsureChar(SX.CurrentCharKey())
  SX.RefreshAchievementPoints(rec)
  RecordTorghastAchievement(rec, achievementID)
end

-- IDs confirmes (Wowhead, 2026-09) pour "Tourment : Couloirs Distordus"
-- echelons 1-8 - le seul donjon "Tourment" identifie a ce jour avec un haut
-- fait par echelon (les autres ailes visibles sur la carte, ex: Forges des
-- Ames, Mort'Regar, ne semblent pas avoir ce systeme repetable). A COMPLETER
-- si un autre donjon "Tourment" avec echelons est confirme en jeu.
local TWISTING_CORRIDORS_ACHIEVEMENTS = { 14468, 14469, 14470, 14471, 14472, 14568, 14569, 14570 }

-- Fusionne les entrees deja enregistrees sous des cles legerement
-- differentes (espace insecable residuelle avant le correctif du
-- 2026-09-08, cf. ExtractTourmentDungeon) - rejoue le meme nettoyage sur les
-- CLES deja stockees, pour les personnages qui avaient deja utilise
-- l'ancienne version buguee (sinon la fusion ne se ferait jamais : les
-- hauts faits concernes sont deja dans seenAchievementIDs, donc plus jamais
-- retraites).
local function CleanupTorghastByDungeon(rec)
  if not rec.torghastByDungeon then return end
  local cleaned = {}
  for name, entry in pairs(rec.torghastByDungeon) do
    local cleanName = name:gsub(string.char(194, 160), " "):gsub("^%s+", ""):gsub("%s+$", "")
    if cleanName ~= "" then
      local existing = cleaned[cleanName]
      if existing then
        existing.count = existing.count + (entry.count or 0)
        if (entry.highestEchelon or 0) > existing.highestEchelon then existing.highestEchelon = entry.highestEchelon end
      else
        cleaned[cleanName] = { count = entry.count or 0, highestEchelon = entry.highestEchelon or 0 }
      end
    end
  end
  rec.torghastByDungeon = cleaned
end

-- Scan retroactif : les hauts faits deja obtenus avant l'ajout de ce suivi
-- ne redeclenchent jamais ACHIEVEMENT_EARNED, donc rien ne les capte sans
-- repasser explicitement dessus. Appele au login (SX.RefreshCharMeta) -
-- RecordTorghastAchievement se dedoublonne lui-meme, sans risque a rappeler
-- a chaque fois.
function SX.ScanTorghastAchievements(rec)
  CleanupTorghastByDungeon(rec)
  for _, achID in ipairs(TWISTING_CORRIDORS_ACHIEVEMENTS) do
    RecordTorghastAchievement(rec, achID)
  end
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
evFrame:RegisterEvent("PVP_MATCH_COMPLETE")
evFrame:RegisterEvent("ACHIEVEMENT_EARNED")
evFrame:RegisterEvent("SCENARIO_COMPLETED")
evFrame:RegisterEvent("PLAYER_DEAD")
evFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

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
    -- Rescan retarde : les donnees de hauts faits ne semblent pas toujours
    -- completement chargees a l'instant precis de PLAYER_LOGIN (constat
    -- similaire deja fait sur d'autres API Blizzard dans ce fichier, cf.
    -- PVP_MATCH_COMPLETE) - le scan synchrone dans RefreshCharMeta ci-dessus
    -- peut donc rater des hauts faits pourtant deja obtenus. Sans risque a
    -- rappeler : RecordTorghastAchievement se dedoublonne lui-meme.
    C_Timer.After(5, function()
      SX.ScanTorghastAchievements(SX.EnsureChar(SX.CurrentCharKey()))
    end)

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

  elseif event == "ACHIEVEMENT_EARNED" then
    OnAchievementEarned(...)

  elseif event == "PVP_MATCH_COMPLETE" then
    -- OnBattlegroundComplete() lit GetInstanceInfo()/GetBattlefieldWinner()
    -- tout de suite (encore dans l'instance) ; le rafraichissement du
    -- snapshot (cotes/saison) est retarde car ces compteurs Blizzard ne
    -- semblent pas toujours a jour a l'instant precis de l'evenement
    -- (constat sur d'autres API similaires, pas verifie specifiquement ici).
    OnBattlegroundComplete()
    C_Timer.After(2, function()
      local rec = SX.EnsureChar(SX.CurrentCharKey())
      rec.pvp = SX.CollectPvPSnapshot(rec)
    end)

  elseif event == "SCENARIO_COMPLETED" then
    OnScenarioCompleted()
    local rec = SX.EnsureChar(SX.CurrentCharKey())
    rec.torghast = SX.CollectTorghastSnapshot()

  elseif event == "PLAYER_DEAD" then
    OnPlayerDead()

  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    OnCombatLogEvent()
  end
end)
