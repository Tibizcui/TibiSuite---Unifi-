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
    d = { quests = 0, worldQuests = 0, goldGain = 0, goldSpent = 0, played = 0, dungeons = 0, mplus = {}, raids = 0, repGained = 0, pvpKillsGained = 0, profGained = 0,
          bgPlayedGained = 0, bgWonGained = 0, arenaPlayedGained = 0, arenaWonGained = 0,
          questLog = {}, dungeonLog = {}, delveLog = {}, repLog = {}, raidLog = {},
          goldLog = {}, playtimeLog = {}, profLog = {}, pvpLog = {} }
    rec.days[dayKey] = d
  end
  d.mplus = d.mplus or {}
  d.questLog = d.questLog or {}
  d.dungeonLog = d.dungeonLog or {}
  d.delveLog = d.delveLog or {}
  d.repLog = d.repLog or {}
  d.raidLog = d.raidLog or {}
  d.goldLog = d.goldLog or {}
  d.playtimeLog = d.playtimeLog or {}
  d.profLog = d.profLog or {}
  d.pvpLog = d.pvpLog or {}
  return d
end

-- Ajoute un evenement detaille a un journal (mplus/questLog/dungeonLog/delveLog/
-- repLog) en plafonnant sa taille journaliere (SX.HISTORY_MAX_EVENTS_PER_DAY) :
-- au-dela, le plus ancien evenement DE CE JOUR est ecrase, jamais le jour lui-meme
-- (SX.PurgeOldDays reste seul responsable de la retention long terme par jour).
-- Renvoie l'entree inseree (utile pour la patcher plus tard par reference, ex.
-- le retry de palier de gouffre qui corrige le tier apres coup).
function SX.AppendDayEvent(list, entry)
  table.insert(list, entry)
  if #list > SX.HISTORY_MAX_EVENTS_PER_DAY then
    table.remove(list, 1)
  end
  return entry
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

-- ============================================================================
-- EXTENSION D'UN EVENEMENT (champ "exp" des journaux)
-- ----------------------------------------------------------------------------
-- Numero d'extension Blizzard (0 = Classic, 1 = Burning Crusade, ... 10 = The
-- War Within, 11 = Midnight), lu AU MOMENT de l'evenement : les journaux ne
-- gardent ni questID ni instanceID, donc impossible de le retrouver apres
-- coup. Les evenements anterieurs a cet ajout n'ont pas de champ "exp"
-- (affiche "-"). Un simple nombre pour ne pas alourdir l'export ; le libelle
-- est resolu a l'affichage (EXPANSION_NAMEx cote addon, table miroir dans
-- dashboard-shared.js cote site/Companion).
-- A VERIFIER EN JEU : aucune des API ci-dessous n'avait ete appelee dans ce
-- depot avant ce jour (GetQuestExpansion, 10e retour de GetInstanceInfo,
-- 9e retour de GetLFGDungeonInfo, MajorFactionData.expansionID).
-- ============================================================================
local function ValidExp(n)
  n = tonumber(n)
  if n and n >= 0 and n <= 30 and n == math.floor(n) then return n end
  return nil
end

-- Extension "en cours" du client (sert aux metiers, cf. DoProfessionRescan,
-- et de repli aux gouffres).
function SX.CurrentExpansionLevel()
  for _, fn in ipairs({ _G.GetServerExpansionLevel, _G.GetExpansionLevel }) do
    if fn then
      local ok, n = pcall(fn)
      n = ok and ValidExp(n)
      if n then return n end
    end
  end
  return nil
end

function SX.ExpansionForQuest(questID)
  if not (questID and GetQuestExpansion) then return nil end
  local ok, n = pcall(GetQuestExpansion, questID)
  if ok then return ValidExp(n) end
  return nil
end

-- Cartes JcJ (instanceID, 8e retour de GetInstanceInfo) -> extension
-- d'ORIGINE de la carte. Aucune API ne la donne pour un champ de bataille ou
-- une arene. A VERIFIER EN JEU : IDs ecrits de memoire, une carte absente ou
-- fausse affiche simplement "-" (jamais bloquant). Pour en ajouter une :
-- /dump select(8, GetInstanceInfo()) sur place.
local PVP_MAP_EXP = {
  -- Classic
  [30] = 0, [489] = 0, [529] = 0, [1681] = 0, [2106] = 0, [2107] = 0, [2197] = 0,
  -- Burning Crusade
  [566] = 1, [968] = 1, [559] = 1, [1505] = 1, [562] = 1, [1672] = 1, [572] = 1,
  -- Wrath of the Lich King
  [607] = 2, [628] = 2, [617] = 2, [618] = 2, [2118] = 2,
  -- Cataclysm
  [726] = 3, [761] = 3, [980] = 3,
  -- Mists of Pandaria
  [727] = 4, [998] = 4, [1105] = 4, [2245] = 4, [1134] = 4,
  -- Warlords of Draenor
  [1191] = 5,
  -- Legion
  [1504] = 6, [1552] = 6,
  -- Battle for Azeroth
  [1803] = 7, [1825] = 7, [1911] = 7, [2167] = 7,
  -- Shadowlands
  [2373] = 8, [2509] = 8,
  -- Dragonflight
  [2547] = 9, [2563] = 9,
  -- The War Within
  [2656] = 10, [2759] = 10,
}

-- Extension de l'instance ou se trouve le joueur : table JcJ ci-dessus, puis
-- l'entree de recherche de groupe de l'instance (GetLFGDungeonInfo porte le
-- niveau d'extension). A appeler PENDANT l'instance (a l'entree, ou a la fin
-- d'un M+/gouffre/match), jamais apres la sortie.
function SX.ExpansionForCurrentInstance()
  if not GetInstanceInfo then return nil end
  local ok, _, _, _, _, _, _, _, instanceID, _, lfgDungeonID = pcall(GetInstanceInfo)
  if not ok then return nil end
  if instanceID and PVP_MAP_EXP[instanceID] then return PVP_MAP_EXP[instanceID] end
  if lfgDungeonID and lfgDungeonID ~= 0 and GetLFGDungeonInfo then
    local r = { pcall(GetLFGDungeonInfo, lfgDungeonID) }
    if r[1] then return ValidExp(r[10]) end
  end
  return nil
end

-- Repli geographique (gouffres) : zone ou continent ancetre connu. A
-- VERIFIER EN JEU : IDs de carte TWW ecrits de memoire.
local MAP_EXP = { [2274] = 10, [2346] = 10, [2371] = 10 }  -- Khaz Algar, Terremine, K'aresh

function SX.ExpansionForCurrentMap()
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo) then return nil end
  local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
  local guard = 0
  while ok and mapID and mapID ~= 0 and guard < 10 do
    if MAP_EXP[mapID] then return MAP_EXP[mapID] end
    local okI, info = pcall(C_Map.GetMapInfo, mapID)
    if not (okI and info) then break end
    mapID = info.parentMapID
    guard = guard + 1
  end
  return nil
end

-- Faction -> extension, par ordre de fiabilite : expansionID des factions a
-- renom, puis les donnees par extension de RenTracker (si le module est
-- charge), puis l'en-tete d'extension sous lequel la faction est rangee dans
-- le panneau Reputation (seuls les en-tetes deplies sont parcourus). Pas de
-- cache : appele seulement quand un gain de reputation est detecte.
local RENTRACKER_EXP = {
  Vanilla = 0, TheBurningCrusade = 1, WrathOfTheLichKing = 2, Cataclysme = 3,
  MistsOfPandaria = 4, WarlordsOfDraenor = 5, Legion = 6, BattleForAzeroth = 7,
  Shadowlands = 8, Dragonflight = 9, TheWarWithin = 10, Midnight = 11,
}

function SX.BuildFactionExpansionMap()
  local map = {}
  if type(_G.RenTrackerData) == "table" then
    for key, ext in pairs(_G.RenTrackerData) do
      local n = RENTRACKER_EXP[key]
      if n and type(ext) == "table" and type(ext.factions) == "table" then
        for _, fac in ipairs(ext.factions) do
          if fac.id and map[fac.id] == nil then map[fac.id] = n end
        end
      end
    end
  end
  if C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetFactionDataByIndex then
    local headerExp = {}
    for i = 0, 30 do
      local s = _G["EXPANSION_NAME" .. i]
      if type(s) == "string" and s ~= "" then headerExp[s] = i end
    end
    local ok, num = pcall(C_Reputation.GetNumFactions)
    local current
    if ok and type(num) == "number" then
      for i = 1, num do
        local okD, d = pcall(C_Reputation.GetFactionDataByIndex, i)
        if okD and d then
          if d.isHeader and not d.isChild then
            current = headerExp[d.name]
          elseif current and d.factionID and d.factionID ~= 0 and map[d.factionID] == nil then
            map[d.factionID] = current
          end
        end
      end
    end
  end
  return map
end

function SX.ExpansionForFaction(factionID, expMap)
  if not factionID then return nil end
  if C_MajorFactions and C_MajorFactions.GetMajorFactionData then
    local ok, d = pcall(C_MajorFactions.GetMajorFactionData, factionID)
    if ok and type(d) == "table" and ValidExp(d.expansionID) then return ValidExp(d.expansionID) end
  end
  return expMap and expMap[factionID] or nil
end

-- CORRECTIF confirme en jeu : StatsDB.export (chaine) et StatsDB.exportedAt
-- (nombre), ecrits a PLAYER_LOGOUT pour le companion Dashboard-Tibi (cf.
-- Core.lua plus bas), sont des cles de PREMIER NIVEAU au meme titre que les
-- "Nom-Royaume" - un simple `pairs(StatsDB)` les confondait avec des
-- personnages. Un personnage est TOUJOURS une table ; on ne garde donc que
-- ca, ce qui ecarte ces deux cles (et toute future cle non-personnage) sans
-- avoir a les nommer en dur.
-- Ordre personnalise (fleches haut/bas sur le selecteur, demande utilisateur
-- 2026-09-17) : StatsDB.charOrder est une liste persistee de cles "Nom-
-- Royaume". Un personnage absent de charOrder (jamais reordonne, ou nouveau
-- personnage detecte depuis) est ajoute a la fin par ordre alphabetique -
-- jamais perdu, juste pas encore positionne manuellement. Sans charOrder
-- (installation neuve ou jamais touchee), comportement inchange : purement
-- alphabetique.
function SX.GetCharKeys()
  local existing, known = {}, {}
  for k, v in pairs(StatsDB) do
    -- StatsDB.charOrder est lui aussi une table (liste de cles) : sans le test
    -- sur le tiret, il etait pris pour un personnage fantome (export, selecteur).
    -- Une cle de personnage est toujours "Nom-Royaume".
    if type(v) == "table" and type(k) == "string" and k:find("-", 1, true) then
      existing[#existing + 1] = k; known[k] = true
    end
  end
  table.sort(existing)

  local order = StatsDB.charOrder
  if not order then return existing end

  local keys, seen = {}, {}
  for _, k in ipairs(order) do
    if known[k] and not seen[k] then
      keys[#keys + 1] = k
      seen[k] = true
    end
  end
  for _, k in ipairs(existing) do
    if not seen[k] then keys[#keys + 1] = k end
  end
  return keys
end

-- Echange un personnage avec son voisin immediat dans l'ordre courant
-- (direction = -1 pour monter, +1 pour descendre) et persiste le resultat
-- dans StatsDB.charOrder (initialise a l'ordre courant au premier appel).
-- No-op silencieux en butee (deja premier/dernier) ou si key est introuvable.
function SX.MoveCharKey(key, direction)
  local keys = SX.GetCharKeys()
  local idx
  for i, k in ipairs(keys) do
    if k == key then idx = i break end
  end
  if not idx then return end
  local swapWith = idx + direction
  if swapWith < 1 or swapWith > #keys then return end
  keys[idx], keys[swapWith] = keys[swapWith], keys[idx]
  StatsDB.charOrder = keys
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
  SX.ScanDelveTierAchievement(rec)
  SX.ScanDelveLifetimeStatistics(rec)
  rec.torghast = SX.CollectTorghastSnapshot()
  SX.ScanTorghastAchievements(rec)
  SX.CollectReputationSnapshot(rec)
  SX.CollectProfessionSnapshot(rec)
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

-- Suivi quotidien des adversaires tues (honorableKills, cumul VIE ENTIERE
-- via GetPVPLifetimeStats - toujours croissant, jamais de "palier" a gerer
-- contrairement au renom : diff simple entre deux lectures). Baseline EN
-- MEMOIRE (non sauvegardee) : premiere lecture de la session = initialisation
-- silencieuse, aucun delta compte. A VERIFIER EN JEU : PLAYER_PVP_KILLS_CHANGED
-- (evenement declencheur) n'a jamais ete exerce dans ce depot.
local pvpKillsBaseline = nil

local function OnPvpKillsChanged()
  if not GetPVPLifetimeStats then return end
  local ok, hk = pcall(GetPVPLifetimeStats)
  if not (ok and type(hk) == "number") then return end
  if pvpKillsBaseline and hk > pvpKillsBaseline then
    local rec = SX.EnsureChar(SX.CurrentCharKey())
    local d = SX.EnsureDay(rec, SX.TodayKey())
    d.pvpKillsGained = (d.pvpKillsGained or 0) + (hk - pvpKillsBaseline)
  end
  pvpKillsBaseline = hk
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
  local d = SX.EnsureDay(rec, SX.TodayKey())
  d.bgPlayedGained = (d.bgPlayedGained or 0) + 1

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
    d.bgWonGained = (d.bgWonGained or 0) + 1
  end
end

-- ============================================================================
-- JOURNAL JCJ (d.pvpLog) : une ligne par partie terminee (champ de bataille,
-- arene, Blitz, bagarre), pour le detail de la carte JcJ. Les compteurs
-- existants (bgParticipation, bgWinsByName, arenaPlayedGained...) restent
-- calcules comme avant, ce journal s'ajoute sans rien remplacer.
-- A VERIFIER EN JEU :
--  - PVP_MATCH_COMPLETE est suppose transmettre (winner, duration) ; repli
--    sur GetBattlefieldWinner() si winner est absent. duration est supposee
--    en secondes (affichee "-" si absente ou incoherente).
--  - L'equipe du joueur est lue via GetBattlefieldArenaFaction() (couvre les
--    champs de bataille inter-factions, ou l'equipe peut differer de la
--    faction) avec repli sur la faction du personnage.
--  - Melee solo : pas de vainqueur unique (6 manches), resultat "-".
--  - C_PvP.IsSoloShuffle/IsRatedArena/IsRatedSoloRBG/IsRatedBattleground/
--    IsInBrawl : chacune sous pcall, une API absente ne casse rien.
-- ============================================================================
local function PvPFlag(fnName)
  local f = C_PvP and C_PvP[fnName]
  if not f then return false end
  local ok, v = pcall(f)
  return ok and v and true or false
end

local function PvPMatchKind(instanceType)
  if PvPFlag("IsInBrawl") then return "brawl" end
  if instanceType == "arena" then
    if PvPFlag("IsSoloShuffle") then return "shuffle" end
    if PvPFlag("IsRatedArena") then return "arena" end
    return "skirmish"
  end
  if PvPFlag("IsRatedSoloRBG") then return "blitz" end
  if PvPFlag("IsRatedBattleground") then return "rbg" end
  return "bg"
end

local function OnPvPMatchLog(eventWinner, eventDuration)
  local inInstance, instanceType = IsInInstance()
  if not inInstance or (instanceType ~= "pvp" and instanceType ~= "arena") then return end
  local name = GetInstanceInfo()
  local kind = PvPMatchKind(instanceType)

  local winner = eventWinner
  if winner == nil and GetBattlefieldWinner then
    local ok, w = pcall(GetBattlefieldWinner)
    if ok then winner = w end
  end
  local myTeam
  if GetBattlefieldArenaFaction then
    local ok, t = pcall(GetBattlefieldArenaFaction)
    if ok and type(t) == "number" then myTeam = t end
  end
  if myTeam == nil then
    local f = UnitFactionGroup("player")
    myTeam = (f == "Horde") and 0 or (f == "Alliance" and 1 or nil)
  end
  local won
  if kind ~= "shuffle" and type(winner) == "number" and myTeam ~= nil then
    won = (winner == myTeam)
  end

  local duration = tonumber(eventDuration)
  if duration and (duration <= 0 or duration > 6 * 3600) then duration = nil end

  local rec = SX.EnsureChar(SX.CurrentCharKey())
  local d = SX.EnsureDay(rec, SX.TodayKey())
  SX.AppendDayEvent(d.pvpLog, { ts = time(), map = name, kind = kind, won = won,
                                time = duration and math.floor(duration + 0.5) or nil,
                                exp = SX.ExpansionForCurrentInstance() })
end

-- Suivi quotidien Arene (parties jouees/gagnees) : pas d'evenement "fin de
-- partie d'arene" distinct expose simplement cote client - diff entre deux
-- lectures des compteurs SAISON cumulatifs de GetPersonalRatedInfo (2v2+3v3+
-- melee solo, deja sommes dans SX.CollectPvPSnapshot -> rec.pvp.arena),
-- meme technique que les autres compteurs "gagne aujourd'hui" de ce fichier.
-- Baseline EN MEMOIRE : premiere lecture de la session = initialisation
-- silencieuse. Ces compteurs remettent a zero a chaque nouvelle saison PVP -
-- une chute de la baseline (nouvelle saison) est traitee comme un simple
-- reset silencieux, pas une perte a soustraire.
local arenaBaseline = nil

local function DoArenaRescan(rec)
  local arena = rec and rec.pvp and rec.pvp.arena
  if not arena then return end
  local played, won = arena.played or 0, arena.won or 0
  if arenaBaseline and played >= arenaBaseline.played then
    local d = SX.EnsureDay(rec, SX.TodayKey())
    d.arenaPlayedGained = (d.arenaPlayedGained or 0) + (played - arenaBaseline.played)
    d.arenaWonGained = (d.arenaWonGained or 0) + math.max(0, won - arenaBaseline.won)
  end
  arenaBaseline = { played = played, won = won }
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
-- Aplatit un journal d'evenements (mplus/questLog/dungeonLog/delveLog/repLog)
-- present dans plusieurs jours vers une seule liste - meme principe que
-- mplus/mplusList ci-dessous, factorise pour les 4 nouveaux journaux.
local function FlattenDayLog(d, key, out)
  local list = d[key]
  if not list then return end
  for _, entry in ipairs(list) do
    out[#out + 1] = entry
  end
end

function SX.Aggregate(charKey, from, to)
  local agg = { quests = 0, worldQuests = 0, goldGain = 0, goldSpent = 0, played = 0, dungeons = 0, mplusCount = 0, mplusList = {}, raids = 0, delves = 0, repGained = 0, pvpKillsGained = 0, profGained = 0,
                bgPlayedGained = 0, bgWonGained = 0, arenaPlayedGained = 0, arenaWonGained = 0,
                questLog = {}, dungeonLog = {}, delveLog = {}, repLog = {}, raidLog = {},
                goldLog = {}, playtimeLog = {}, profLog = {}, pvpLog = {} }
  local rec = StatsDB[charKey]
  if not rec or not rec.days then return agg end
  for dayKey, d in pairs(rec.days) do
    local t = SX.ParseDayKey(dayKey)
    if t and t >= from and t <= to then
      agg.quests    = agg.quests + (d.quests or 0)
      agg.worldQuests = agg.worldQuests + (d.worldQuests or 0)
      agg.goldGain  = agg.goldGain + (d.goldGain or 0)
      agg.goldSpent = agg.goldSpent + (d.goldSpent or 0)
      agg.played    = agg.played + (d.played or 0)
      agg.dungeons  = agg.dungeons + (d.dungeons or 0)
      agg.raids     = agg.raids + (d.raids or 0)
      agg.delves    = agg.delves + (d.delves or 0)
      agg.repGained = agg.repGained + (d.repGained or 0)
      agg.pvpKillsGained = agg.pvpKillsGained + (d.pvpKillsGained or 0)
      agg.profGained = agg.profGained + (d.profGained or 0)
      agg.bgPlayedGained = agg.bgPlayedGained + (d.bgPlayedGained or 0)
      agg.bgWonGained = agg.bgWonGained + (d.bgWonGained or 0)
      agg.arenaPlayedGained = agg.arenaPlayedGained + (d.arenaPlayedGained or 0)
      agg.arenaWonGained = agg.arenaWonGained + (d.arenaWonGained or 0)
      agg.achPoints = (agg.achPoints or 0) + (d.achPoints or 0)
      agg.sessions = (agg.sessions or 0) + (d.sessions or 0)
      agg.sessionTime = (agg.sessionTime or 0) + (d.sessionTime or 0)
      if d.mplus then
        for _, run in ipairs(d.mplus) do
          agg.mplusCount = agg.mplusCount + 1
          agg.mplusList[#agg.mplusList + 1] = run
        end
      end
      FlattenDayLog(d, "questLog", agg.questLog)
      FlattenDayLog(d, "dungeonLog", agg.dungeonLog)
      FlattenDayLog(d, "delveLog", agg.delveLog)
      FlattenDayLog(d, "repLog", agg.repLog)
      FlattenDayLog(d, "raidLog", agg.raidLog)
      FlattenDayLog(d, "goldLog", agg.goldLog)
      FlattenDayLog(d, "playtimeLog", agg.playtimeLog)
      FlattenDayLog(d, "profLog", agg.profLog)
      FlattenDayLog(d, "pvpLog", agg.pvpLog)
    end
  end
  -- Session en cours (7.1.5.45) : comptee dans sa journee de depart tant
  -- qu'elle n'est pas close (elle sera ecrite dans la journee a la prochaine
  -- connexion, cf. SessionClose).
  local s = rec.liveSession
  if type(s) == "table" and not s.ended and s.start and s.start >= from and s.start <= to then
    local dur = (s.last or s.start) - s.start
    if dur >= 60 then
      agg.sessions = (agg.sessions or 0) + 1
      agg.sessionTime = (agg.sessionTime or 0) + dur
    end
  end
  return agg
end

function SX.AggregateAccount(from, to)
  local agg = { quests = 0, worldQuests = 0, goldGain = 0, goldSpent = 0, played = 0, dungeons = 0, mplusCount = 0, mplusList = {}, raids = 0, delves = 0, repGained = 0, pvpKillsGained = 0, profGained = 0,
                bgPlayedGained = 0, bgWonGained = 0, arenaPlayedGained = 0, arenaWonGained = 0,
                questLog = {}, dungeonLog = {}, delveLog = {}, repLog = {}, raidLog = {},
                goldLog = {}, playtimeLog = {}, profLog = {}, pvpLog = {} }
  -- SX.GetCharKeys() plutot que pairs(StatsDB) direct : ecarte StatsDB.export
  -- / StatsDB.exportedAt (cf. son commentaire) qui feraient planter
  -- SX.Aggregate en tentant de lire ".days" sur une chaine ou un nombre.
  for _, key in ipairs(SX.GetCharKeys()) do
    local a = SX.Aggregate(key, from, to)
    agg.quests    = agg.quests + a.quests
    agg.worldQuests = agg.worldQuests + a.worldQuests
    agg.goldGain  = agg.goldGain + a.goldGain
    agg.goldSpent = agg.goldSpent + a.goldSpent
    agg.played    = agg.played + a.played
    agg.dungeons  = agg.dungeons + a.dungeons
    agg.mplusCount = agg.mplusCount + a.mplusCount
    agg.raids     = agg.raids + a.raids
    agg.delves    = agg.delves + a.delves
    agg.repGained = agg.repGained + a.repGained
    agg.pvpKillsGained = agg.pvpKillsGained + a.pvpKillsGained
    agg.profGained = agg.profGained + a.profGained
    agg.bgPlayedGained = agg.bgPlayedGained + a.bgPlayedGained
    agg.bgWonGained = agg.bgWonGained + a.bgWonGained
    agg.arenaPlayedGained = agg.arenaPlayedGained + a.arenaPlayedGained
    agg.arenaWonGained = agg.arenaWonGained + a.arenaWonGained
    agg.achPoints = (agg.achPoints or 0) + (a.achPoints or 0)
    agg.sessions = (agg.sessions or 0) + (a.sessions or 0)
    agg.sessionTime = (agg.sessionTime or 0) + (a.sessionTime or 0)
    for _, run in ipairs(a.mplusList) do agg.mplusList[#agg.mplusList + 1] = run end
    for _, e in ipairs(a.questLog) do agg.questLog[#agg.questLog + 1] = e end
    for _, e in ipairs(a.dungeonLog) do agg.dungeonLog[#agg.dungeonLog + 1] = e end
    for _, e in ipairs(a.delveLog) do agg.delveLog[#agg.delveLog + 1] = e end
    for _, e in ipairs(a.repLog) do agg.repLog[#agg.repLog + 1] = e end
    for _, e in ipairs(a.raidLog) do agg.raidLog[#agg.raidLog + 1] = e end
    for _, e in ipairs(a.goldLog) do agg.goldLog[#agg.goldLog + 1] = e end
    for _, e in ipairs(a.playtimeLog) do agg.playtimeLog[#agg.playtimeLog + 1] = e end
    for _, e in ipairs(a.profLog) do agg.profLog[#agg.profLog + 1] = e end
    for _, e in ipairs(a.pvpLog) do agg.pvpLog[#agg.pvpLog + 1] = e end
  end
  return agg
end

function SX.AggregateFor(charKey, from, to)
  if charKey == "__account__" then return SX.AggregateAccount(from, to) end
  return SX.Aggregate(charKey, from, to)
end

function SX.MetricValue(agg, metric)
  if metric == "quests" then return agg.quests
  elseif metric == "worldQuests" then return agg.worldQuests
  elseif metric == "gold" then return agg.goldGain - agg.goldSpent
  elseif metric == "dungeons" then return agg.dungeons + agg.mplusCount
  elseif metric == "raids" then return agg.raids
  elseif metric == "played" then return agg.played
  elseif metric == "delves" then return agg.delves
  elseif metric == "repGained" then return agg.repGained
  elseif metric == "pvpKillsGained" then return agg.pvpKillsGained
  elseif metric == "profGained" then return agg.profGained
  elseif metric == "bgPlayedGained" then return agg.bgPlayedGained
  elseif metric == "bgWonGained" then return agg.bgWonGained
  elseif metric == "arenaPlayedGained" then return agg.arenaPlayedGained
  elseif metric == "arenaWonGained" then return agg.arenaWonGained
  elseif metric == "achPoints" then return agg.achPoints or 0
  elseif metric == "sessions" then return agg.sessions or 0
  elseif metric == "delveBest" then
    local best = 0
    for _, e in ipairs(agg.delveLog or {}) do
      local t = tonumber(e.tier)
      if t and t > best then best = t end
    end
    return best
  elseif metric == "repFactions" or metric == "profCount" then
    local log, field = agg.repLog, "faction"
    if metric == "profCount" then log, field = agg.profLog, "profession" end
    local seen, n = {}, 0
    for _, e in ipairs(log or {}) do
      local k = e[field]
      if k and not seen[k] then seen[k] = true; n = n + 1 end
    end
    return n
  end
  return 0
end

-- Debut de l'historique des compteurs ajoutes en 7.1.5.45 (points de hauts
-- faits, sessions) : rec.histSince, pose a la premiere connexion. Pour le
-- compte, le plus ancien des personnages.
function SX.HistorySince(charKey)
  if charKey == "__account__" then
    local best
    for _, key in ipairs(SX.GetCharKeys()) do
      local r = StatsDB[key]
      local t = type(r) == "table" and r.histSince
      if t and (not best or t < best) then best = t end
    end
    return best
  end
  local r = StatsDB[charKey]
  return type(r) == "table" and r.histSince or nil
end

-- Serie de `count` points se terminant a la periode courante, granularite
-- day/week/month/year. Utilisee pour les mini-courbes et le detail par metrique.
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
    elseif granularity == "year" then
      local dt = dateTable(now)
      dt.month, dt.day, dt.hour, dt.min, dt.sec = 1, 1, 0, 0, 0
      dt.year = dt.year - i
      from = time(dt)
      local dt2 = dateTable(from)
      dt2.year = dt2.year + 1
      to = time(dt2) - 1
      label = date("%Y", from)
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

-- Timestamp du jour le plus ancien enregistre pour un personnage (ou le plus
-- ancien tous personnages confondus pour "__account__"). Sert a construire la
-- timeline complete du graphique "Toutes les metriques" (defilable). Renvoie
-- nil si aucune donnee. Meme garde type(rec)=="table" que HasFullYearOfData
-- (ecarte StatsDB.export / StatsDB.exportedAt).
function SX.EarliestDay(charKey)
  local earliest = nil
  local function scan(rec)
    if type(rec) ~= "table" or not rec.days then return end
    for dayKey in pairs(rec.days) do
      local t = SX.ParseDayKey(dayKey)
      if t and (not earliest or t < earliest) then earliest = t end
    end
  end
  if charKey == "__account__" then
    for _, key in ipairs(SX.GetCharKeys()) do scan(StatsDB[key]) end
  else
    scan(StatsDB[charKey])
  end
  return earliest
end

-- Nombre de buckets d'historique (du plus ancien jour enregistre jusqu'a la
-- periode courante, incluse) pour une granularite donnee. Borne en bas par
-- minCount (au moins la fenetre visible) et en haut par un plafond de securite
-- par granularite : au-dela, le cout d'agregation (AggregateFor par bucket)
-- deviendrait sensible et l'historique n'est de toute facon pas exploitable a
-- l'oeil. Utilise par la timeline defilable de "Toutes les metriques".
local OVERLAY_BUCKET_CAP = { day = 366, week = 157, month = 120, year = 30 }
function SX.OverlayBucketCount(charKey, granularity, minCount)
  minCount = minCount or 1
  local earliest = SX.EarliestDay(charKey)
  local now = time()
  local count = minCount
  if earliest then
    if granularity == "day" then
      count = math.floor((SX.StartOfDay(now) - SX.StartOfDay(earliest)) / 86400) + 1
    elseif granularity == "week" then
      count = math.floor((SX.StartOfWeek(now) - SX.StartOfWeek(earliest)) / (7 * 86400)) + 1
    elseif granularity == "year" then
      count = (dateTable(now).year - dateTable(earliest).year) + 1
    else -- month
      local a, b = dateTable(now), dateTable(earliest)
      count = (a.year - b.year) * 12 + (a.month - b.month) + 1
    end
  end
  local cap = OVERLAY_BUCKET_CAP[granularity] or 120
  if count < minCount then count = minCount end
  if count > cap then count = cap end
  return count
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

-- Detail par source (d.goldLog, en plus du total d.goldGain/d.goldSpent
-- inchange ci-dessus) : seuls les GAINS sont detailles, pas les depenses.
-- 3 sources reconnues + 1 fourre-tout "autre", reconciliees sans double
-- comptage (cf. FlushGoldSourceBucket) :
--  - quete : exact, gratuit (moneyReward de QUEST_TURNED_IN, deja disponible
--    en parametre mais jamais lu jusqu'ici).
--  - marchand : heuristique - MerchantFrame ouvert au moment du gain. Peut se
--    tromper si un autre gain (butin, etc.) tombe par coincidence pendant que
--    la fenetre marchand est ouverte - accepte, pas verifiable sans jeu.
--  - hotel des ventes : les ventes HV arrivent toujours par courrier, jamais
--    en direct via PLAYER_MONEY - lu depuis PostBoxDB (module soeur) si
--    present, cf. SX.ReadPostBoxAHDeltaToday ci-dessous. Degrade a 0 si
--    PostBox n'est pas installe (meme principe que le cross-read SkillTrackerDB
--    des metiers, Export.lua).
--  - autre : le reste (butin, quete mondiale, bonus, tout ce qui n'est ni
--    marchand ni identifie comme venant de l'hotel des ventes ou d'une quete).
local pendingQuestGold = 0
local pendingVendorDelta = 0
local pendingOtherDelta = 0
local goldBucketPending = false

-- Lit le delta de vente HV du jour depuis PostBoxDB (cross-read en lecture
-- seule, jamais ecrit) contre une baseline SAUVEGARDEE (pas en memoire : un
-- baseline en memoire serait perdu au /reload, ce qui recompterait tout le
-- total du jour comme "nouveau" a chaque reload). Baseline stockee en 2 cles
-- SCALAIRES de premier niveau de StatsDB (pas une sous-table) pour ne pas
-- perturber SX.GetCharKeys(), qui filtre StatsDB par type(v)=="table" pour
-- ecarter StatsDB.export/exportedAt (cf. son propre commentaire) - une
-- baseline en sous-table serait a tort traitee comme un personnage.
-- A VERIFIER EN JEU : jamais teste avec PostBox reellement installe.
function SX.ReadPostBoxAHDeltaToday()
  if not _G.PostBoxDB then return 0 end
  local ok, delta = pcall(function()
    local today = SX.TodayKey()
    local history = _G.PostBoxDB.stats and _G.PostBoxDB.stats.history
    local soldToday = (history and history[today] and history[today].auctionSold) or 0
    local sameDay = StatsDB.postboxAHBaselineDay == today
    local baseline = sameDay and StatsDB.postboxAHBaselineAmount or 0
    StatsDB.postboxAHBaselineDay = today
    StatsDB.postboxAHBaselineAmount = soldToday
    return math.max(0, soldToday - baseline)
  end)
  if ok and type(delta) == "number" then return delta end
  return 0
end

local function FlushGoldSourceBucket()
  goldBucketPending = false
  local vendorAmt, otherAmt = pendingVendorDelta, pendingOtherDelta
  pendingVendorDelta, pendingOtherDelta = 0, 0

  -- Le delta HV est RETRANCHE de "autre" (jamais ajoute a part) : il fait
  -- deja partie du delta PLAYER_MONEY brut compte plus haut dans goldGain,
  -- on ne fait que le RECLASSER hors du fourre-tout. Une course rare (signal
  -- PostBox arrivant hors de cette fenetre de 0.5s) fait juste perdre cette
  -- fraction dans "autre" au lieu de la compter en double - accepte.
  local ahAmt = SX.ReadPostBoxAHDeltaToday()
  otherAmt = math.max(0, otherAmt - ahAmt)

  -- L'or de quete a deja sa propre entree (OnQuestTurnedIn, avec nom/zone) -
  -- ici on ne fait que le SOUSTRAIRE du fourre-tout pour ne pas le compter
  -- deux fois, jamais une deuxieme entree.
  local fromQuest = math.min(pendingQuestGold, otherAmt)
  pendingQuestGold = pendingQuestGold - fromQuest
  otherAmt = otherAmt - fromQuest

  local rec = SX.EnsureChar(SX.CurrentCharKey())
  local d = SX.EnsureDay(rec, SX.TodayKey())
  local now = time()
  if vendorAmt > 0 then SX.AppendDayEvent(d.goldLog, { ts = now, source = "vendor", amount = vendorAmt }) end
  if ahAmt > 0 then SX.AppendDayEvent(d.goldLog, { ts = now, source = "ah", amount = ahAmt }) end
  if otherAmt > 0 then SX.AppendDayEvent(d.goldLog, { ts = now, source = "other", amount = otherAmt }) end
end

local function OnPlayerMoney()
  local now = GetMoney()
  if lastMoney ~= nil then
    local delta = now - lastMoney
    if delta ~= 0 then
      local rec = SX.EnsureChar(SX.CurrentCharKey())
      local d = SX.EnsureDay(rec, SX.TodayKey())
      if delta > 0 then
        d.goldGain = (d.goldGain or 0) + delta
        if MerchantFrame and MerchantFrame:IsShown() then
          pendingVendorDelta = pendingVendorDelta + delta
        else
          pendingOtherDelta = pendingOtherDelta + delta
        end
        if not goldBucketPending then
          goldBucketPending = true
          C_Timer.After(0.5, FlushGoldSourceBucket)
        end
      else d.goldSpent = (d.goldSpent or 0) + (-delta) end
    end
  end
  lastMoney = now
end

-- ============================================================================
-- ENREGISTREUR : QUETES
-- ============================================================================
-- Spe active du joueur, meme paire d'appels que SX.RefreshCharMeta - factorisee
-- ici car reutilisee par les enregistreurs quete/donjon/M+.
local function CurrentSpecName()
  local specIndex = GetSpecialization and GetSpecialization()
  if not specIndex then return nil end
  local _, specName = GetSpecializationInfo(specIndex)
  return specName
end

-- A VERIFIER EN JEU : QUEST_TURNED_IN est suppose fournir (questID, xpReward,
-- moneyReward) sur le client retail actuel - jamais exerce dans ce fichier
-- jusqu'ici (aucun de ces arguments n'etait lu, juste un compteur incremente).
-- GetTitleForQuestID peut renvoyer nil si la quete est deja purgee du log au
-- moment ou l'event se declenche - traite en nil-safe cote UI (affiche "?").
-- Expeditions (= World Quests, nom du client francais) : A VERIFIER EN JEU.
-- C_QuestLog.IsWorldQuest lit le type de la quete (donnee statique par
-- questID), suppose donc encore valide au moment de QUEST_TURNED_IN alors
-- que la quete vient de quitter le journal. Repli sur GetQuestTagInfo
-- (worldQuestType renseigne uniquement pour une expedition).
local function IsWorldQuestID(questID)
  if not (questID and C_QuestLog) then return false end
  if C_QuestLog.IsWorldQuest then
    local ok, isWQ = pcall(C_QuestLog.IsWorldQuest, questID)
    if ok and isWQ then return true end
  end
  if C_QuestLog.GetQuestTagInfo then
    local ok, info = pcall(C_QuestLog.GetQuestTagInfo, questID)
    if ok and type(info) == "table" and info.worldQuestType then return true end
  end
  return false
end

local function OnQuestTurnedIn(questID, xpReward, moneyReward)
  local rec = SX.EnsureChar(SX.CurrentCharKey())
  local d = SX.EnsureDay(rec, SX.TodayKey())
  d.quests = (d.quests or 0) + 1
  -- Une expedition reste AUSSI comptee dans "Quetes" (c'est une quete) :
  -- la carte Expeditions en est un sous-ensemble, pas une categorie a part.
  local isWQ = IsWorldQuestID(questID)
  if isWQ then d.worldQuests = (d.worldQuests or 0) + 1 end
  local questName = questID and C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
  local zone = GetSubZoneText()
  if not zone or zone == "" then zone = GetZoneText() end
  -- wq = true seulement pour une expedition (champ absent sinon, pour ne pas
  -- alourdir l'export) : le detail de la carte Expeditions filtre questLog
  -- sur ce drapeau au lieu d'un journal dedie en double.
  SX.AppendDayEvent(d.questLog, { ts = time(), quest = questName, zone = zone, xp = xpReward, wq = isWQ or nil,
                                   exp = SX.ExpansionForQuest(questID) })
  -- L'or de recompense de quete est deja compte dans d.goldGain via le delta
  -- PLAYER_MONEY correspondant - ici on l'accumule seulement pour que
  -- FlushGoldSourceBucket (ENREGISTREUR : OR ci-dessus) le retranche du
  -- fourre-tout "autre" et lui donne sa propre entree source="quest".
  if moneyReward and moneyReward > 0 then
    pendingQuestGold = pendingQuestGold + moneyReward
  end
end

-- ============================================================================
-- ENREGISTREUR : MYTHIQUE+
-- ============================================================================
-- Lecture de la fin de cle. GetCompletionInfo a disparu en 11.0 (confirme en
-- jeu le 2026-09-28 : /dump renvoie nil, la fonction sortait donc des la
-- premiere ligne et plus aucune cle n'etait enregistree). Remplacee par
-- GetChallengeCompletionInfo(), qui renvoie une TABLE. L'ancienne API reste
-- en repli (valeurs multiples : mapID, level, time, onTime).
local function ReadChallengeCompletion()
  local CM = C_ChallengeMode
  if not CM then return nil end
  if CM.GetChallengeCompletionInfo then
    local ok, info = pcall(CM.GetChallengeCompletionInfo)
    if ok and type(info) == "table" and info.mapChallengeModeID then
      return info.mapChallengeModeID, info.level, info.time, info.onTime
    end
  end
  if CM.GetCompletionInfo then
    local ok, mapID, level, ms, onTime = pcall(CM.GetCompletionInfo)
    if ok then return mapID, level, ms, onTime end
  end
  return nil
end

local function OnChallengeModeCompleted()
  local mapID, level, time_, onTime = ReadChallengeCompletion()
  if not mapID then return end
  local mapName = mapID
  if C_ChallengeMode.GetMapUIInfo then
    local n = C_ChallengeMode.GetMapUIInfo(mapID)
    if n then mapName = n end
  end
  local rec = SX.EnsureChar(SX.CurrentCharKey())
  local d = SX.EnsureDay(rec, SX.TodayKey())
  -- time_ (GetCompletionInfo) est en MILLISECONDES (API Blizzard) - converti
  -- en secondes ici pour rester dans la meme unite que dungeonLog.time
  -- (calcule via time(), Core.lua plus bas) : rien d'autre dans ce depot ne
  -- lit mplus[].time (verifie), donc ce changement d'unite est sans risque.
  SX.AppendDayEvent(d.mplus, { map = mapName, level = level, time = math.floor((time_ or 0) / 1000), done = onTime and true or false,
                                ts = time(), spec = CurrentSpecName(), exp = SX.ExpansionForCurrentInstance() })
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

-- Palier du gouffre actif, rafraichi en continu PENDANT le gouffre (cf.
-- CurrentPlaytimeActivity plus bas, meme detection HasActiveDelve/IsInLair).
-- Sert de repli pour OnScenarioCompleted ci-dessous : lire
-- C_DelvesUI.GetActiveDelveTier() SEULEMENT au moment ou le scenario se
-- termine echoue trop souvent en pratique (constat utilisateur du
-- 2026-09-13 : palier 11 jamais capture, ni a l'instant T ni via le reessai
-- a 2s - le contexte "gouffre actif" semble deja se refermer). En le lisant
-- aussi PENDANT le gouffre (zone deja chargee, bien avant la fin), la valeur
-- est disponible plus tot et plus fiablement.
local cachedDelveTier = nil

-- Vrai Gouffre en cours. VU EN JEU (sonde LairLens du 2026-10-03) : dans un
-- Repaire 12.1 (La grotte des Marees), HasActiveDelve ET IsInLair repondent
-- vrai alors que ce n'est pas un Gouffre. Un Repaire est une instance de type
-- "raid", un Gouffre un "scenario" : on ecarte donc le type "raid", sinon le
-- temps passe dans un Repaire tombait dans le compteur Gouffres.
local function InRealDelve()
  if not C_DelvesUI then return false end
  local _, instType = GetInstanceInfo()
  if instType == "raid" then return false end
  return ((C_DelvesUI.HasActiveDelve and C_DelvesUI.HasActiveDelve())
    or (C_DelvesUI.IsInLair and C_DelvesUI.IsInLair())) and true or false
end

-- Applique un palier lu (immediatement ou via le repli retarde ci-dessous)
-- au record : tuile "Palier max" (global) ET entree du gouffre nomme
-- concerne (tableau "Detail par gouffre").
local function ApplyDelveTier(rec, delveName, tier)
  if not tier then return end
  if not rec.delveHighestTier or tier > rec.delveHighestTier then
    rec.delveHighestTier = tier
  end
  if delveName and delveName ~= "" then
    rec.delveTypes = rec.delveTypes or {}
    local entry = rec.delveTypes[delveName]
    if entry and tier > entry.highestTier then entry.highestTier = tier end
  end
end

local function OnScenarioCompleted()
  if not C_DelvesUI then return end
  local inDelve = InRealDelve()
  if not inDelve then return end
  local tier
  if C_DelvesUI.GetActiveDelveTier then
    local ok, t = pcall(C_DelvesUI.GetActiveDelveTier)
    if ok and type(t) == "number" then
      tier = t
    elseif ok and type(t) == "table" then
      -- DEBUG TEMPORAIRE : confirme le 2026-09-13 que GetActiveDelveTier()
      -- renvoie une TABLE, pas un nombre (mauvaise hypothese initiale) -
      -- affiche son contenu pour trouver le bon champ plutot que deviner.
      local parts = {}
      for k, v in pairs(t) do parts[#parts + 1] = tostring(k) .. "=" .. tostring(v) end
      print("|cFFFFCC00[Stats DEBUG]|r delve tier table (fin) : " .. table.concat(parts, ", "))
    end
  end
  -- Repli immediat sur la derniere lecture reussie PENDANT le gouffre (cf.
  -- cachedDelveTier ci-dessus) avant meme d'essayer le reessai a 2s plus bas.
  tier = tier or cachedDelveTier
  local rec = SX.EnsureChar(SX.CurrentCharKey())
  local d = SX.EnsureDay(rec, SX.TodayKey())
  d.delves = (d.delves or 0) + 1

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
    rec.delveTypes[delveName] = rec.delveTypes[delveName] or { count = 0, highestTier = 0 }
    rec.delveTypes[delveName].count = rec.delveTypes[delveName].count + 1
  end
  ApplyDelveTier(rec, delveName, tier)
  -- Herite des deux incertitudes documentees ci-dessus (nom = repli zone/sous-
  -- zone, palier pas toujours dispo a l'instant T) - patchee par reference par
  -- le reessai ci-dessous si le palier arrive apres coup.
  -- Extension : instance d'abord, puis carte (Khaz Algar...), puis extension
  -- en cours - les gouffres n'existent que depuis The War Within.
  local delveExp = SX.ExpansionForCurrentInstance() or SX.ExpansionForCurrentMap() or SX.CurrentExpansionLevel()
  local delveLogEntry = SX.AppendDayEvent(d.delveLog, { ts = time(), name = delveName, tier = tier, exp = delveExp })
  -- Consomme le cache : evite qu'un gouffre suivant, lance tres vite apres
  -- celui-ci, ne reutilise par erreur un palier perime.
  cachedDelveTier = nil

  -- Dernier repli : GetActiveDelveTier() peut ne pas encore repondre a
  -- l'instant precis de SCENARIO_COMPLETED (meme constat deja fait ailleurs
  -- dans ce fichier sur d'autres API Blizzard, cf. PVP_MATCH_COMPLETE) ET le
  -- cache ci-dessus peut ne jamais avoir ete rempli (gouffre commence avant
  -- le premier PLAYER_ENTERING_WORLD/ZONE_CHANGED_NEW_AREA suivant le
  -- /reload, par exemple). Un seul reessai, 2s plus tard, si le palier n'a
  -- toujours pas ete lu.
  if not tier and C_DelvesUI.GetActiveDelveTier then
    local charKey = SX.CurrentCharKey()
    C_Timer.After(2, function()
      local ok2, t2 = pcall(C_DelvesUI.GetActiveDelveTier)
      if ok2 and type(t2) == "number" then
        ApplyDelveTier(SX.EnsureChar(charKey), delveName, t2)
        delveLogEntry.tier = t2
      end
    end)
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

-- ----------------------------------------------------------------------------
-- Rattrapage retroactif du "Total" et du "Palier max" (tuile Gouffres) via
-- les Statistiques Blizzard - confirme en jeu le 2026-09-08 (capture
-- d'ecran du panneau Hauts faits > Statistiques > Gouffres) : la categorie
-- contient "Gouffres du niveau N termines" (N=1..11, compteur A VIE, toutes
-- saisons/extensions confondues) et "Gouffres termines" (total a vie).
-- Contrairement au tableau "Detail par gouffre" (par NOM de gouffre, aucune
-- statistique equivalente trouvee), ces compteurs sont globaux et donc
-- reconstructibles retroactivement, y compris pour des runs faits avant
-- que l'addon ne suive quoi que ce soit. Ancrage texte volontairement
-- prudent : uniquement des prefixes ASCII confirmes par la capture d'ecran
-- ("Gouffres du niveau ", "Gouffres termin"), jamais de caractere accentue
-- dans le pattern (cf. le piege NBSP deja rencontre sur le francais,
-- meme si aucune ponctuation a risque n'apparait ici).
-- ----------------------------------------------------------------------------
local function FindStatisticsCategoryID(nameSubstr)
  if not (GetStatisticsCategoryList and GetCategoryInfo) then return nil end
  local ok, cats = pcall(GetStatisticsCategoryList)
  if not ok or type(cats) ~= "table" then return nil end
  for _, catID in ipairs(cats) do
    local okInfo, name = pcall(GetCategoryInfo, catID)
    if okInfo and type(name) == "string" and name:find(nameSubstr, 1, true) then
      return catID
    end
  end
  return nil
end

function SX.ScanDelveLifetimeStatistics(rec)
  if not (GetCategoryNumAchievements and GetAchievementInfo and GetStatistic) then return end
  local catID = FindStatisticsCategoryID("Gouffres")
  if not catID then return end
  local okNum, num = pcall(GetCategoryNumAchievements, catID)
  if not okNum or type(num) ~= "number" then return end

  -- Espacement autour du nombre insere ("niveau 11") suppose non-ASCII par
  -- la localisation francaise (meme classe de piege que le NBSP devant
  -- ":"/"!" deja rencontre, cf. feedback_wow_french_nbsp_patterns) : aucun
  -- caractere d'espacement litteral dans le pattern, ".-" (n'importe quels
  -- octets, y compris une sequence UTF-8 multi-octets) comble l'ecart entre
  -- les mots-cles ASCII surs ("niveau", "termin", "Gouffres").
  local highestTier
  for i = 1, num do
    local okInfo, id, name = pcall(GetAchievementInfo, catID, i)
    if okInfo and type(id) == "number" and type(name) == "string" then
      local okStat, value = pcall(GetStatistic, id)
      local n = okStat and tonumber(value)
      if name:find("niveau", 1, true) and name:find("termin", 1, true) then
        local lvl = tonumber(name:match("niveau.-(%d+).-termin"))
        if lvl and n and n > 0 and (not highestTier or lvl > highestTier) then
          highestTier = lvl
        end
      elseif name:find("Gouffres", 1, true) and name:find("termin", 1, true) then
        if n then rec.delveCompletedLifetime = n end
      end
    end
  end

  if highestTier and (not rec.delveHighestTier or highestTier > rec.delveHighestTier) then
    rec.delveHighestTier = highestTier
  end
end

-- ----------------------------------------------------------------------------
-- Haut fait de palier de gouffre, lie a la tuile "Palier max" (pas au
-- tableau "Detail par gouffre" : contrairement aux Tourments, il n'existe
-- pas de haut fait par TYPE de gouffre, un seul par PALIER atteint, valable
-- pour n'importe quel gouffre). Volontairement AUCUN ID code en dur
-- (contrairement a TORGHAST_LAYER_ACHIEVEMENTS plus bas, ecrit avant qu'on
-- tire cette lecon) : ces hauts faits sont ajoutes/renouveles CHAQUE SAISON
-- ("Gouffres ... : palier N (saison X)") - une liste fixe se perimerait des
-- la saison suivante. A la place on enumere en jeu la categorie "Gouffres"
-- ET toutes ses sous-categories (saisons/extensions, ex. "Midnight"), sans
-- jamais supposer de nom de sous-categorie ni d'ID - le scan reste valable
-- pour les saisons futures sans modification de code. On ne tente pas non
-- plus d'extraire le numero de palier depuis le nom du haut fait (piege
-- NBSP deja rencontre sur le francais, cf. ExtractTourmentDungeon) : parmi
-- les hauts faits de palier COMPLETES trouves, on retient celui qui a le
-- plus de points (les paliers eleves rapportent plus de points chez
-- Blizzard) comme "meilleur palier obtenu", et on affiche son nom/ID tels
-- quels - jamais besoin d'en reparser un numero.
-- A VERIFIER EN JEU : GetCategoryList/GetCategoryInfo/GetCategoryNumAchievements/
-- GetAchievementInfo(categorie,index) sont l'API classique de scan complet
-- (utilisee par des addons comme AllTheThings) mais jamais exercee dans ce
-- depot - proteger par pcall partout, echouer proprement si l'API differe.
-- ----------------------------------------------------------------------------
local function FindDelveCategoryIDs()
  if not (GetCategoryList and GetCategoryInfo) then return nil end
  local ok, cats = pcall(GetCategoryList)
  if not ok or type(cats) ~= "table" then return nil end

  local rootID
  for _, catID in ipairs(cats) do
    local okInfo, name = pcall(GetCategoryInfo, catID)
    if okInfo and type(name) == "string" and name:find("Gouffres", 1, true) then
      rootID = catID
      break
    end
  end
  if not rootID then return nil end

  local ids = { rootID }
  for _, catID in ipairs(cats) do
    local okInfo, _, parentID = pcall(GetCategoryInfo, catID)
    if okInfo and parentID == rootID then
      ids[#ids + 1] = catID
    end
  end
  return ids
end

function SX.ScanDelveTierAchievement(rec)
  if not (GetCategoryNumAchievements and GetAchievementInfo) then return end
  local catIDs = FindDelveCategoryIDs()
  if not catIDs then return end

  local best
  for _, catID in ipairs(catIDs) do
    local okNum, num = pcall(GetCategoryNumAchievements, catID)
    if okNum and type(num) == "number" then
      for i = 1, num do
        local okInfo, id, name, points, completed = pcall(GetAchievementInfo, catID, i)
        if okInfo and completed and type(id) == "number" then
          points = tonumber(points) or 0
          if not best or points > best.points then
            best = { id = id, name = name, points = points }
          end
        end
      end
    end
  end

  if best then
    rec.delveTierAchievementID = best.id
    rec.delveTierAchievementName = best.name
  end
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
  -- Nom du compagnon (Brann Bronzebeard, Valeera Sanguinar...) - sert
  -- UNIQUEMENT a l'exclure de la liste des reputations (cf.
  -- SX.CollectReputationSnapshot ci-dessous : le lien du compagnon utilise
  -- l'API "amitie" des reputations cote Blizzard, ce qui le faisait
  -- apparaitre a tort dans le tableau Reputations alors qu'il a deja son
  -- propre affichage dans la tuile Gouffres). A VERIFIER EN JEU : nom de
  -- champ non confirme, plusieurs noms plausibles essayes par prudence.
  local name = info.name or info.companionName or info.Name
  if type(name) == "string" and name ~= "" then rec.delveCompanionName = name end
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
  if echelonNum > entry.highestEchelon then
    entry.highestEchelon = echelonNum
    -- ID + nom du haut fait de l'echelon max : l'ID sert au vrai lien de
    -- haut fait cote addon (icone/infobulle/clic natifs), le nom sert de
    -- repli texte cote site/Companion (pas de tooltip WoW possible en dehors
    -- du jeu).
    entry.highestAchievementID = achievementID
    entry.highestAchievementName = name
  end
  rec.torghastByDungeon[dungeonName] = entry
end

local function OnAchievementEarned(achievementID)
  local rec = SX.EnsureChar(SX.CurrentCharKey())
  SX.RefreshAchievementPoints(rec)
  -- 7.1.5.45 : points gagnes ce jour-la (carte Hauts faits).
  if achievementID and GetAchievementInfo then
    local ok, _, _, points, _, _, _, _, _, _, _, _, isGuild = pcall(GetAchievementInfo, achievementID)
    if ok and type(points) == "number" and points > 0 and not isGuild then
      local d = SX.EnsureDay(rec, SX.TodayKey())
      d.achPoints = (d.achPoints or 0) + points
    end
  end
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
        if (entry.highestEchelon or 0) > existing.highestEchelon then
          existing.highestEchelon = entry.highestEchelon
          existing.highestAchievementID = entry.highestAchievementID
          existing.highestAchievementName = entry.highestAchievementName
        end
      else
        cleaned[cleanName] = {
          count = entry.count or 0, highestEchelon = entry.highestEchelon or 0,
          highestAchievementID = entry.highestAchievementID,
          highestAchievementName = entry.highestAchievementName,
        }
      end
    end
  end
  rec.torghastByDungeon = cleaned
end

-- Comble highestAchievementID/Name pour les entrees deja enregistrees AVANT
-- l'ajout de ce suivi (2026-09-08) : ces 8 ID sont deja dans
-- seenAchievementIDs, donc RecordTorghastAchievement ne les retraitera
-- jamais - sans repasser explicitement dessus ici, "Couloirs Distordus"
-- resterait pour toujours prive de lien de haut fait cliquable. Ne
-- fonctionne que pour les donjons dont on connait la liste d'ID (donc pas
-- "Epreuve du Geolier" et les autres captes seulement via
-- ACHIEVEMENT_EARNED) - ceux-la se completeront naturellement des que le
-- joueur validera un nouvel echelon pour ce donjon.
local function BackfillTorghastAchievementInfo(rec)
  if not rec.torghastByDungeon or not GetAchievementInfo then return end
  for _, achID in ipairs(TWISTING_CORRIDORS_ACHIEVEMENTS) do
    local ok, _, name = pcall(GetAchievementInfo, achID)
    if ok and type(name) == "string" then
      local dungeonName, echelon = ExtractTourmentDungeon(name)
      if dungeonName and echelon then
        dungeonName = dungeonName:sub(1, 1):upper() .. dungeonName:sub(2)
        dungeonName = dungeonName:gsub(string.char(194, 160), " "):gsub("^%s+", ""):gsub("%s+$", "")
        local entry = rec.torghastByDungeon[dungeonName]
        if entry and not entry.highestAchievementID and tonumber(echelon) == entry.highestEchelon then
          entry.highestAchievementID = achID
          entry.highestAchievementName = name
        end
      end
    end
  end
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
  BackfillTorghastAchievementInfo(rec)
end

-- ============================================================================
-- REPUTATIONS : instantane (palier/renom/amitie par faction) + suivi
-- quotidien de la reputation gagnee. Lecture universelle adaptee de
-- RepBar/RepBar.lua (ReadReputation) et RenTracker/RenTracker.lua
-- (GetRenownData) - meme logique de detection amitie/renom/classique,
-- reecrite ici de facon autonome pour que Stats reste complet seul (cf. le
-- "point d'extension inerte" plus haut : aucune fusion de donnees inter-
-- modules non testee).
-- ============================================================================

-- Liste des factionID a interroger. Deux sources cumulees, jamais l'une
-- requise pour l'autre :
-- 1) RenTrackerData (si RenTracker est charge) - lecture seule, meme
--    principe deja utilise par RepBar pour ses infobulles de zone. Donne
--    une liste organisee par extension, la plus complete.
-- 2) Le panneau Reputation natif (C_Reputation.GetNumFactions/
--    GetFactionDataByIndex) - toujours execute, garantit que Stats
--    fonctionne seul sans RenTracker installe.
-- Mise en cache pour la session (une nouvelle faction debloquee en cours de
-- session n'apparaitra qu'au prochain /reload - limite mineure acceptee
-- plutot que de re-scanner cette liste a chaque UPDATE_FACTION).
local knownFactionIDsCache = nil

local function CollectKnownFactionIDs()
  if knownFactionIDsCache then return knownFactionIDsCache end
  local ids, seen = {}, {}
  if type(_G.RenTrackerData) == "table" then
    for _, ext in pairs(_G.RenTrackerData) do
      if type(ext) == "table" and type(ext.factions) == "table" then
        for _, fac in ipairs(ext.factions) do
          if fac.id and not seen[fac.id] then
            seen[fac.id] = true
            ids[#ids + 1] = fac.id
          end
        end
      end
    end
  end
  if C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetFactionDataByIndex then
    local ok, num = pcall(C_Reputation.GetNumFactions)
    if ok and type(num) == "number" then
      for i = 1, num do
        local okD, d = pcall(C_Reputation.GetFactionDataByIndex, i)
        if okD and d and not d.isHeader and d.factionID and d.factionID ~= 0 and not seen[d.factionID] then
          seen[d.factionID] = true
          ids[#ids + 1] = d.factionID
        end
      end
    end
  end
  knownFactionIDsCache = ids
  return ids
end

-- Lecture universelle d'une faction : amitie (paliers nommes) -> renom
-- (Major Factions, SL/DF/TWW/Midnight) -> classique (BfA et avant), avec
-- paragon au renom plafonne ou a l'exalte classique. A VERIFIER EN JEU :
-- la signature a 4 retours de GetFactionParagonInfo (le 4e, "recompense en
-- attente", n'a jamais ete exerce dans ce depot - RepBar n'utilise que les
-- deux premiers).
local function ReadReputationInfo(factionID)
  if not factionID or factionID == 0 then return nil end
  local out = { factionID = factionID }

  if C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
    local ok, fr = pcall(C_GossipInfo.GetFriendshipReputation, factionID)
    if ok and fr and fr.friendshipFactionID and fr.friendshipFactionID ~= 0 then
      out.system = "friendship"
      out.name = fr.name
      out.label = fr.reaction or ""
      local cur, minv, maxv = fr.standing or 0, fr.reactionThreshold or 0, fr.nextThreshold or 0
      if maxv and maxv > minv then
        out.cur, out.max = cur - minv, maxv - minv
        out.pct = out.max > 0 and (out.cur / out.max) or 1
      else
        out.cur, out.max, out.pct, out.maxed = 1, 1, 1, true
      end
      return out
    end
  end

  if C_MajorFactions and C_MajorFactions.GetMajorFactionData then
    local ok, d = pcall(C_MajorFactions.GetMajorFactionData, factionID)
    if ok and d and (d.renownLevel or d.renownLevelThreshold) then
      out.system = "renown"
      out.name = d.name
      out.rank = d.renownLevel or 0
      out.cur = d.renownReputationEarned or 0
      out.max = d.renownLevelThreshold or 1
      out.pct = (out.max > 0) and math.min(1, out.cur / out.max) or 0
      local isCap = false
      if C_MajorFactions.HasMaximumRenown then
        local cok, c = pcall(C_MajorFactions.HasMaximumRenown, factionID)
        isCap = cok and c
      end
      if isCap then
        out.maxed = true
        out.cur, out.pct = out.max, 1
        if C_Reputation and C_Reputation.IsFactionParagon and C_Reputation.GetFactionParagonInfo then
          local pok, isP = pcall(C_Reputation.IsFactionParagon, factionID)
          if pok and isP then
            local gok, val, thr, _, pending = pcall(C_Reputation.GetFactionParagonInfo, factionID)
            if gok and val and thr and thr > 0 then out.paragonReady = pending == true end
          end
        end
      end
      return out
    end
  end

  if C_Reputation and C_Reputation.GetFactionDataByID then
    local ok, d = pcall(C_Reputation.GetFactionDataByID, factionID)
    if ok and d and d.name then
      out.system = "classic"
      out.name = d.name
      local reaction = d.reaction or 4
      out.reaction = reaction
      out.label = _G["FACTION_STANDING_LABEL" .. reaction] or ""
      local minv, maxv, val = d.currentReactionThreshold or 0, d.nextReactionThreshold or 0, d.currentStanding or 0
      if maxv and maxv > minv then
        out.cur, out.max = val - minv, maxv - minv
        out.pct = out.max > 0 and (out.cur / out.max) or 1
      else
        out.cur, out.max, out.pct, out.maxed = 1, 1, 1, true
      end
      if reaction >= 8 then
        out.maxed = true
        out.pct = 1
        if C_Reputation.IsFactionParagon and C_Reputation.GetFactionParagonInfo then
          local pok, isP = pcall(C_Reputation.IsFactionParagon, factionID)
          if pok and isP then
            local gok, val2, thr2, _, pending = pcall(C_Reputation.GetFactionParagonInfo, factionID)
            if gok and val2 and thr2 and thr2 > 0 then out.paragonReady = pending == true end
          end
        end
      end
      return out
    end
  end

  return nil
end

-- Instantane complet, rafraichi a chaque login (SX.RefreshCharMeta) et a
-- chaque UPDATE_FACTION debounce (DoFactionRescan ci-dessous). Chaque entree
-- recoit aussi lastGainAt (timestamp, sauvegarde dans rec.repRecentGain) si
-- connu - permet au tableau "Detail par reputation" de mettre en avant les
-- factions recemment progressees plutot qu'un mur de factions exaltees de
-- longue date (constat utilisateur : le tri par % remontait uniquement des
-- factions a 100% sans interet immediat).
function SX.CollectReputationSnapshot(rec)
  local ok, result = pcall(function()
    local ids = CollectKnownFactionIDs()
    local list, seenName = {}, {}
    local maxedCount, paragonReady, highestRenownRank = 0, 0, nil
    for _, id in ipairs(ids) do
      local info = ReadReputationInfo(id)
      -- Le lien avec le compagnon de gouffre (Brann Bronzebeard, Valeera
      -- Sanguinar...) utilise l'API "amitie" des reputations cote Blizzard -
      -- exclu ici car il a deja son propre affichage (tuile Gouffres,
      -- rec.delveCompanionLevel) et n'est pas une vraie faction.
      local isCompanion = info and rec.delveCompanionName and info.name == rec.delveCompanionName
      if info and info.name and info.name ~= "" and not isCompanion and not seenName[info.name] then
        seenName[info.name] = true
        info.lastGainAt = rec.repRecentGain and rec.repRecentGain[id]
        list[#list + 1] = info
        if info.maxed then maxedCount = maxedCount + 1 end
        if info.paragonReady then paragonReady = paragonReady + 1 end
        if info.system == "renown" and info.rank and (not highestRenownRank or info.rank > highestRenownRank) then
          highestRenownRank = info.rank
        end
      end
    end
    return {
      list = list,
      summary = { tracked = #list, maxedCount = maxedCount, paragonReady = paragonReady, highestRenownRank = highestRenownRank },
    }
  end)
  if ok then rec.reputations = result end
end

-- Suivi quotidien de la reputation gagnee (UPDATE_FACTION) --------------
-- UPDATE_FACTION ne transporte aucune information (ni faction, ni delta) -
-- seul moyen fiable : re-lire l'etat de chaque faction connue et comparer a
-- la derniere lecture memorisee. Baseline EN MEMOIRE uniquement (jamais
-- sauvegardee) : au premier passage de la session, aucune baseline n'existe
-- encore pour aucune faction, donc aucun delta n'est compte, seulement une
-- initialisation silencieuse - evite un faux pic au login. Un changement de
-- palier (renom qui monte, seuils qui changent) reinitialise simplement la
-- baseline SANS compter de delta pour cette transition precise (limite
-- acceptee plutot que de deviner un delta a travers un changement de
-- systeme de seuils). Debounce de 1s : UPDATE_FACTION peut se declencher en
-- rafale (ramassage en masse), pas de raison de rescanner a chaque tick.
-- rec.repRecentGain (SAUVEGARDE, contrairement a repBaseline) : timestamp du
-- dernier gain detecte par faction, persiste d'une session a l'autre pour
-- que "recemment progressee" reste vrai apres un /reload.
local repBaseline = {}

local function DoFactionRescan()
  local rec = SX.EnsureChar(SX.CurrentCharKey())
  rec.repRecentGain = rec.repRecentGain or {}
  local now = time()
  local ids = CollectKnownFactionIDs()
  local totalGain = 0
  local gains = {}
  for _, id in ipairs(ids) do
    local info = ReadReputationInfo(id)
    if info and info.cur and info.max then
      local base = repBaseline[id]
      if base and base.max == info.max and info.cur > base.cur then
        local delta = info.cur - base.cur
        totalGain = totalGain + delta
        gains[#gains + 1] = { faction = info.name, amount = delta, factionID = id }
        rec.repRecentGain[id] = now
      end
      repBaseline[id] = { cur = info.cur, max = info.max }
    end
  end
  if totalGain > 0 then
    local d = SX.EnsureDay(rec, SX.TodayKey())
    d.repGained = (d.repGained or 0) + totalGain
    -- Le debounce de 1s ci-dessous (OnFactionUpdate) regroupe une salve de
    -- gains sur la meme faction en une seule ligne, pas une ligne par quete
    -- rendue - acceptable, pas un bug si une ligne semble "trop grosse".
    local expMap = SX.BuildFactionExpansionMap()
    for _, g in ipairs(gains) do
      SX.AppendDayEvent(d.repLog, { ts = now, faction = g.faction, amount = g.amount,
                                    exp = SX.ExpansionForFaction(g.factionID, expMap) })
    end
  end
  SX.CollectReputationSnapshot(rec)
end

local factionUpdatePending = false
local function OnFactionUpdate()
  if factionUpdatePending then return end
  factionUpdatePending = true
  C_Timer.After(1, function()
    factionUpdatePending = false
    DoFactionRescan()
  end)
end

-- ============================================================================
-- METIERS : instantane (niveau/max) + progression recente + suivi quotidien
-- des points gagnes, meme principe que REPUTATIONS ci-dessus. Contrairement
-- au reste de l'export "professions" (rec.professions, alimente par
-- Export.lua en lecture seule depuis SkillTrackerDB - un AUTRE addon, avec
-- son decoupage par extension deja resolu et conserve tel quel), cette
-- partie lit directement l'API Blizzard (GetProfessions/GetProfessionInfo,
-- meme API que SkillTracker/Constants.lua documente deja utiliser) pour
-- ajouter la couche "recent"/"quotidien" que SkillTrackerDB n'a pas.
-- A VERIFIER EN JEU : Stats n'a jamais appele GetProfessions() lui-meme
-- avant ce jour (seul SkillTracker l'exerce dans ce depot).
-- ============================================================================
function SX.CollectProfessionSnapshot(rec)
  local ok, result = pcall(function()
    if not (GetProfessions and GetProfessionInfo) then return nil end
    local indices = { GetProfessions() }
    local list, seenName = {}, {}
    local maxedCount = 0
    for _, index in ipairs(indices) do
      if index then
        local name, _, cur, max = GetProfessionInfo(index)
        if name and name ~= "" and type(cur) == "number" and type(max) == "number" and max > 0 and not seenName[name] then
          seenName[name] = true
          local maxed = cur >= max
          if maxed then maxedCount = maxedCount + 1 end
          list[#list + 1] = {
            name = name, cur = cur, max = max, pct = math.min(1, cur / max), maxed = maxed,
            lastGainAt = rec.profRecentGain and rec.profRecentGain[name],
          }
        end
      end
    end
    return { list = list, summary = { tracked = #list, maxedCount = maxedCount } }
  end)
  if ok then rec.professionsNative = result end
end

-- Suivi quotidien des points de metier gagnes : diff simple sur le niveau
-- courant (jamais decroissant, contrairement a une monnaie) - seul un
-- changement du "max" (nouveau contenu de metier debloque) reinitialise la
-- baseline sans compter de delta pour cette transition, meme garde-fou que
-- le renom. Baseline EN MEMOIRE (non sauvegardee) ; rec.profRecentGain
-- (SAUVEGARDE) retient la derniere date de gain par metier, pour le
-- tableau "Detail par metier" (progression recente uniquement, comme les
-- reputations).
local profBaseline = {}

local function DoProfessionRescan()
  if not (GetProfessions and GetProfessionInfo) then return end
  local rec = SX.EnsureChar(SX.CurrentCharKey())
  rec.profRecentGain = rec.profRecentGain or {}
  local now = time()
  local indices = { GetProfessions() }
  local totalGain = 0
  local gains = {}
  for _, index in ipairs(indices) do
    if index then
      local name, _, cur, max = GetProfessionInfo(index)
      if name and name ~= "" and type(cur) == "number" and type(max) == "number" then
        local base = profBaseline[name]
        if base and base.max == max and cur > base.cur then
          local delta = cur - base.cur
          totalGain = totalGain + delta
          gains[#gains + 1] = { profession = name, amount = delta }
          rec.profRecentGain[name] = now
        end
        profBaseline[name] = { cur = cur, max = max }
      end
    end
  end
  if totalGain > 0 then
    local d = SX.EnsureDay(rec, SX.TodayKey())
    d.profGained = (d.profGained or 0) + totalGain
    -- GetProfessionInfo lit le palier de l'extension EN COURS (celui du
    -- grimoire depuis Dragonflight) : c'est donc sur ce palier que le gain
    -- est mesure. Monter un ancien palier chez un maitre ne change pas ce
    -- niveau-la et n'est de toute facon pas detecte ici.
    local profExp = SX.CurrentExpansionLevel()
    for _, g in ipairs(gains) do
      SX.AppendDayEvent(d.profLog, { ts = now, profession = g.profession, amount = g.amount, exp = profExp })
    end
  end
  SX.CollectProfessionSnapshot(rec)
end

local profUpdatePending = false
local function OnSkillLinesChanged()
  if profUpdatePending then return end
  profUpdatePending = true
  C_Timer.After(1, function()
    profUpdatePending = false
    DoProfessionRescan()
  end)
end

-- ============================================================================
-- ENREGISTREUR : DONJONS NORMAUX ET RAIDS (heuristique boss tue)
-- ---------------------------------------------------------------------------
-- Pas d'evenement Blizzard "donjon/raid termine" fiable pour les groupes hors
-- Recherche de groupe. A la sortie d'une instance de type "party" ou "raid",
-- MEME heuristique pour les deux types (EvaluateDungeonCompletion) : un seul
-- boss tue pendant la session suffit (bossKillCount > 0).
-- CORRECTIF (constat utilisateur, 2026-09-16) : Scholomance fait a trois
-- (Tibiscui/Tibizcui/Tibispike) ne remontait dans aucun dashboard. La
-- version precedente exigeait, pour un DONJON specifiquement, que le
-- DERNIER combat de boss reussi corresponde au DERNIER encounter du
-- Bestiaire (C_EncounterJournal/EJ_GetEncounterInfoByIndex) - resolution qui
-- echoue silencieusement (finalID nil, cf. ResolveFinalEncounterID
-- supprimee) sur les donjons classiques remanies comme Scholomance (route de
-- boss non lineaire, pas forcement mappe pareil dans le Bestiaire retail) :
-- le compteur restait alors bloque a 0 pour TOUT le monde sur ce donjon,
-- meme donjon termine. Meme probleme de fond, et meme correctif, que celui
-- deja applique aux Raids le 2026-09-13 (une soiree de raid/donjon peut ne
-- tuer qu'une partie des boss listes au Bestiaire sans que ce soit un signe
-- d'echec du suivi).
-- ============================================================================
local instanceSession = nil  -- { mapID = , name = , enteredAt = , instanceType = , bossKillCount = }

-- ============================================================================
-- ENREGISTREUR : TEMPS DE JEU PAR ACTIVITE (d.playtimeLog)
-- ---------------------------------------------------------------------------
-- MECANISME DIFFERENT de d.played (le scalaire ticker 60s plus bas dans ce
-- fichier) : bascule sur changement d'activite, horloge murale time() - les
-- totaux des deux ne sont PAS garantis identiques a la seconde pres, ce n'est
-- pas un bug si un ecart existe. Place ici (avant OnEnteringWorld) car cette
-- derniere doit pouvoir appeler OnPlaytimeActivityCheck ci-dessous, et lit
-- deja instanceSession juste au-dessus - meme portee lexicale, pas de
-- plomberie supplementaire necessaire.
-- Pas de detection AFK (aucune API native utilisee nulle part dans ce depot) :
-- le temps immobile reste compte dans le bucket d'activite en cours, meme
-- simplification deja acceptee pour la duree des donjons/raids ci-dessus.
-- ============================================================================
local playtimeActivity = nil
local playtimeEnteredAt = nil

-- A VERIFIER EN JEU : le gouffre est verifie EN PREMIER, avant instanceSession -
-- rien ne confirme que IsInInstance() renvoie un instanceType different de
-- "party" a l'interieur d'un gouffre ; sans cette priorite, un gouffre
-- pourrait etre classe "donjon" par erreur.
local function CurrentPlaytimeActivity()
  if InRealDelve() then
    -- Rafraichit cachedDelveTier (cf. section GOUFFRES plus haut) tant que le
    -- gouffre est actif, pour qu'OnScenarioCompleted ait deja une valeur
    -- disponible au moment ou le gouffre se termine.
    if C_DelvesUI.GetActiveDelveTier then
      local ok, t = pcall(C_DelvesUI.GetActiveDelveTier)
      if ok and type(t) == "number" then
        cachedDelveTier = t
      elseif ok and type(t) == "table" then
        local parts = {}
        for k, v in pairs(t) do parts[#parts + 1] = tostring(k) .. "=" .. tostring(v) end
        print("|cFFFFCC00[Stats DEBUG]|r delve tier table (pendant) : " .. table.concat(parts, ", "))
      end
    end
    return "delve"
  end
  if instanceSession then
    if instanceSession.instanceType == "raid" then return "raid" end
    if instanceSession.instanceType == "party" then return "dungeon" end
  end
  return "world"
end

local function CloseOutPlaytimeBucket()
  if not playtimeActivity or not playtimeEnteredAt then return end
  local elapsed = math.max(0, time() - playtimeEnteredAt)
  if elapsed <= 0 then return end
  local rec = SX.EnsureChar(SX.CurrentCharKey())
  local d = SX.EnsureDay(rec, SX.TodayKey())
  SX.AppendDayEvent(d.playtimeLog, { ts = time(), activity = playtimeActivity, time = elapsed })
end

local function OnPlaytimeActivityCheck()
  local activity = CurrentPlaytimeActivity()
  if activity == playtimeActivity then return end
  CloseOutPlaytimeBucket()
  playtimeActivity, playtimeEnteredAt = activity, time()
end

local function EvaluateDungeonCompletion(session)
  if not session then return end
  if not (session.bossKillCount and session.bossKillCount > 0) then return end
  -- Duree = temps ecoule entre l'entree dans l'instance et la sortie/le
  -- dernier boss tue - contrairement au temps M+ (chrono precis de
  -- Blizzard), ceci inclut tout temps mort (AFK, discussion, wipes et
  -- reessais) : un temps "brut" de session, pas un temps de run pur.
  local duration = session.enteredAt and math.max(0, time() - session.enteredAt) or nil
  local rec = SX.EnsureChar(SX.CurrentCharKey())
  local d = SX.EnsureDay(rec, SX.TodayKey())
  if session.instanceType == "raid" then
    d.raids = (d.raids or 0) + 1
    SX.AppendDayEvent(d.raidLog, { ts = time(), name = session.name, spec = CurrentSpecName(),
                                    time = duration, bossKills = session.bossKillCount, exp = session.exp })
  else
    d.dungeons = (d.dungeons or 0) + 1
    SX.AppendDayEvent(d.dungeonLog, { ts = time(), name = session.name, spec = CurrentSpecName(), time = duration, exp = session.exp })
  end
end

local function OnEnteringWorld()
  local inInstance, instanceType = IsInInstance()
  if inInstance and (instanceType == "party" or instanceType == "raid") then
    local name, _, _, _, _, _, _, mapID = GetInstanceInfo()
    if not instanceSession or instanceSession.mapID ~= mapID then
      -- Nouvelle session : evalue l'ancienne (si on vient d'une autre instance) puis ouvre la nouvelle
      if instanceSession then EvaluateDungeonCompletion(instanceSession) end
      -- exp lu a l'ENTREE : la session est souvent evaluee apres la sortie
      -- de l'instance, quand GetInstanceInfo ne la decrit plus.
      instanceSession = { mapID = mapID, name = name, enteredAt = time(), instanceType = instanceType, bossKillCount = 0,
                          exp = SX.ExpansionForCurrentInstance() }
    end
  else
    if instanceSession then
      EvaluateDungeonCompletion(instanceSession)
      instanceSession = nil
    end
  end
  OnPlaytimeActivityCheck()
end

local function OnEncounterEnd(encounterID, _, _, _, success)
  if instanceSession and success == 1 then
    instanceSession.bossKillCount = (instanceSession.bossKillCount or 0) + 1
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
evFrame:RegisterEvent("UPDATE_FACTION")
evFrame:RegisterEvent("PLAYER_PVP_KILLS_CHANGED")
evFrame:RegisterEvent("SKILL_LINES_CHANGED")
evFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

evFrame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    local addonName = ...
    if addonName ~= "Stats" then return end
    StatsDB = StatsDB or {}

  elseif event == "PLAYER_LOGIN" then
    lastMoney = GetMoney()
    lastFlush = GetTime()
    playtimeActivity, playtimeEnteredAt = CurrentPlaytimeActivity(), time()
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
    OnQuestTurnedIn(...)

  elseif event == "CHALLENGE_MODE_COMPLETED" then
    OnChallengeModeCompleted()

  elseif event == "PLAYER_ENTERING_WORLD" then
    OnEnteringWorld()

  elseif event == "ENCOUNTER_END" then
    OnEncounterEnd(...)

  elseif event == "ZONE_CHANGED_NEW_AREA" then
    OnPlaytimeActivityCheck()

  elseif event == "PLAYER_LOGOUT" then
    FlushPlayed()
    CloseOutPlaytimeBucket()
    -- Auto-persistance de l'export (companion Dashboard-Tibi) : ecrit le
    -- dernier code d'export dans StatsDB pour que le fichier Stats.lua
    -- contienne toujours la derniere version, lisible meme le jeu ferme.
    -- PLAYER_LOGOUT couvre a la fois /reload et la deconnexion.
    -- Coupable depuis l'installateur TibiSuite (TibiSuiteDB.statsAutoExport =
    -- false) ; sans le core, ou tant que rien n'est choisi, l'export reste actif.
    local tdb = _G.TibiSuiteDB
    local autoExport = not (type(tdb) == "table" and tdb.statsAutoExport == false)
    if autoExport and SX.Export and SX.Export.Generate then
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
    OnPvPMatchLog(...)
    OnBattlegroundComplete()
    C_Timer.After(2, function()
      local rec = SX.EnsureChar(SX.CurrentCharKey())
      rec.pvp = SX.CollectPvPSnapshot(rec)
      DoArenaRescan(rec)
    end)

  elseif event == "SCENARIO_COMPLETED" then
    OnScenarioCompleted()
    local rec = SX.EnsureChar(SX.CurrentCharKey())
    rec.torghast = SX.CollectTorghastSnapshot()

  elseif event == "PLAYER_DEAD" then
    OnPlayerDead()

  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    OnCombatLogEvent()

  elseif event == "UPDATE_FACTION" then
    OnFactionUpdate()

  elseif event == "PLAYER_PVP_KILLS_CHANGED" then
    OnPvpKillsChanged()

  elseif event == "SKILL_LINES_CHANGED" then
    OnSkillLinesChanged()
  end
end)

-- ============================================================================
-- HAUTS FAITS : PARCOURS BUDGETE (7.1.5.45 lot 6, puis Conseiller lot 2)
-- ----------------------------------------------------------------------------
-- Un seul parcours sert deux listes :
--   * SX.NearAchievements() : hauts faits a 80 % ou plus (5 gardes), carte et
--     tuile « Hauts faits » de Stats, apercu du Centre. Format inchange :
--     { { id, name, icon, points, pct, done, total, remaining = { textes } } }
--   * SX.AdvisorSuggestions() : candidats du Conseiller de TibiSuite (30 % ou
--     plus, 8 au plus par tag), voir _dev/Conseiller.md.
-- Budget de 5 ms par image avec reprise au milieu d'une categorie (la sonde
-- du 2026-10-14 a mesure 150 ms pour une seule categorie), jamais en combat.
-- Parcours complet a la demande puis toutes les 30 min ; entre deux, mise a
-- jour des seuls hauts faits affiches a ACHIEVEMENT_EARNED / CRITERIA_UPDATE.
-- Hors guilde, statistiques et hauts faits a 0 point.
-- ============================================================================
local ACH_MIN, ACH_KEEP = 0.8, 5
local ADV_MIN, ADV_PER_TAG = 0.3, 8
local BUDGET_MS, RESCAN = 5, 1800

-- Racine -> type de contenu (ID stables, releves par la sonde).
local ROOT_TAG = {
  [96] = "quest", [97] = "explore", [15522] = "delve", [95] = "pvp", [168] = "dungeon",
  [169] = "prof", [201] = "rep", [155] = "event", [15117] = "pet", [15246] = "collect",
  [15301] = "feature",   -- fief, visions, vol dynamique... : pas des quetes du monde (vu en jeu)
}
-- Tours de force, Heritage, Personnages, Logis : jamais proposes.
local SKIP_ROOT = { [81] = true, [15234] = true, [92] = true, [15606] = true }
local EVENT_ROOT = 155
local RAID_CAT = {
  [14922] = true, [15068] = true, [15107] = true, [15231] = true, [15255] = true, [15286] = true,
  [15438] = true, [15468] = true, [15526] = true, [15566] = true,
}
-- Sous-categorie -> extension (0 Classique ... 11 Midnight). Une categorie
-- absente de la table n'a pas d'extension connue (traitee comme recente).
local CUR_EXP = 11
local EXP_OF = {
  -- Quetes
  [14861] = 0, [15081] = 0, [14862] = 1, [14863] = 2, [15070] = 3, [15110] = 4, [15220] = 5,
  [15252] = 6, [15284] = 7, [15422] = 8, [15455] = 9, [15506] = 10, [15547] = 11,
  -- Exploration
  [14777] = 0, [14778] = 0, [14779] = 1, [14780] = 2, [15069] = 3, [15113] = 4, [15235] = 5,
  [15257] = 6, [15298] = 7, [15436] = 8, [15465] = 9, [15521] = 10, [15553] = 11,
  -- Gouffres
  [15523] = 10, [15571] = 11,
  -- Donjons et raids
  [14808] = 0, [14805] = 1, [14806] = 2, [14922] = 2, [15067] = 3, [15068] = 3, [15106] = 4,
  [15107] = 4, [15228] = 5, [15231] = 5, [15254] = 6, [15255] = 6, [15285] = 7, [15286] = 7,
  [15428] = 8, [15438] = 8, [15467] = 9, [15468] = 9, [15524] = 10, [15526] = 10,
  [15541] = 11, [15566] = 11,
  -- Reputation
  [14864] = 0, [14865] = 1, [14866] = 2, [15072] = 3, [15114] = 4, [15232] = 5, [15258] = 6,
  [15305] = 7, [15439] = 8, [15466] = 9, [15530] = 10, [15600] = 11,
  -- Contenu d'extension
  [14941] = 2, [15075] = 3, [15302] = 4, [15222] = 4, [15303] = 5, [15304] = 6, [15307] = 7,
  [15308] = 7, [15417] = 7, [15426] = 7, [15440] = 8, [15441] = 8, [15462] = 9, [15546] = 10,
  [15605] = 11, [15610] = 11, [15608] = 11,
}

local achCache, achAt = nil, 0      -- liste « presque finis »
local advList, advAt = nil, 0       -- candidats du Conseiller
local nearMap, candMap = {}, {}     -- id -> entree (listes affichees)
local catInfo = {}                  -- cat -> { root, parent, title }
local holidays = {}                 -- cat d'evenement actif -> heure de fin
local metaOf = {}                   -- haut fait enfant -> nom de la meta
local maxed = false
local scan                          -- parcours en cours (nil sinon)

local function AchProgress(id)
  local n = GetAchievementNumCriteria and GetAchievementNumCriteria(id) or 0
  if n == 0 then return nil end
  if n == 1 then
    local text, _, completed, qty, req = GetAchievementCriteriaInfo(id, 1)
    if completed then return nil end
    if not req or req <= 1 then return nil end   -- tout ou rien : pas de progression
    return (qty or 0) / req, qty or 0, req, { (text and text ~= "") and text or nil }, 0, nil, true
  end
  local done, remaining, n8, kids = 0, {}, 0, nil
  for i = 1, n do
    local text, ctype, completed, _, _, _, _, assetID = GetAchievementCriteriaInfo(id, i)
    if ctype == 8 then
      n8 = n8 + 1
      if not completed and assetID and assetID > 0 then kids = kids or {}; kids[#kids + 1] = assetID end
    end
    if completed then done = done + 1 elseif #remaining < 3 and text and text ~= "" then remaining[#remaining + 1] = text end
  end
  return done / n, done, n, remaining, n8, kids, false
end

local function Norm(s) return type(s) == "string" and s:lower() or "" end

local function CalTime(t)
  if type(t) ~= "table" or not t.year then return nil end
  return time({ year = t.year, month = t.month, day = t.monthDay, hour = t.hour or 0, min = t.minute or 0 })
end

-- Categories d'evenements mondiaux dont l'evenement est en cours (calendrier
-- du jour). Seulement les enfants de 155, et seulement « titre de categorie
-- contenu dans le titre de l'evenement » (evite « bonus Champs de bataille »
-- -> « Bataille » des mascottes, vu par la sonde).
local function ReadHolidays()
  local out = {}
  if not (C_Calendar and C_Calendar.GetNumDayEvents and C_Calendar.GetDayEvent and C_DateAndTime) then return out end
  if C_Calendar.OpenCalendar and not SX._calOpened then SX._calOpened = true; pcall(C_Calendar.OpenCalendar) end
  local ok, today = pcall(C_DateAndTime.GetCurrentCalendarTime)
  if not ok or type(today) ~= "table" then return out end
  local okN, n = pcall(C_Calendar.GetNumDayEvents, 0, today.monthDay)
  for i = 1, (okN and tonumber(n) or 0) do
    local okE, e = pcall(C_Calendar.GetDayEvent, 0, today.monthDay, i)
    if okE and type(e) == "table" and e.calendarType == "HOLIDAY" and type(e.title) == "string"
       and not (issecretvalue and issecretvalue(e.title)) then
      local ht, ends = Norm(e.title), CalTime(e.endTime)
      for cat, ci in pairs(catInfo) do
        local ct = Norm(ci.title)
        if ci.parent == EVENT_ROOT and #ct >= 4 and ht:find(ct, 1, true) then
          if not out[cat] or (ends and ends > out[cat]) then out[cat] = ends or (time() + 86400) end
        end
      end
    end
  end
  return out
end

-- Evalue un haut fait. Renvoie l'entree « presque fini » et l'entree
-- « candidat » (l'une ou l'autre peut etre nil). Les enfants des metas sont
-- notes dans metaOf.
local function Evaluate(id, cat)
  local ok, aid, name, points, completed, _, _, _, _, _, icon, _, isGuild, _, _, isStatistic = pcall(GetAchievementInfo, id)
  if not ok or not aid or completed or isGuild or isStatistic or (points or 0) == 0 then return nil end
  local okP, pct, d, t, rem, n8, kids, single = pcall(AchProgress, id)
  if not okP or not pct or pct >= 1 then return nil end
  if kids then for _, k in ipairs(kids) do metaOf[k] = metaOf[k] or name end end
  local near
  if pct >= ACH_MIN then
    near = { id = id, name = name, icon = icon, points = points, pct = pct, done = d, total = t, remaining = rem }
  end
  if pct < ADV_MIN then return near end
  if not cat and GetAchievementCategory then
    local okC, c = pcall(GetAchievementCategory, id)
    cat = okC and c or nil
  end
  local info = cat and catInfo[cat]
  local root = info and info.root
  local tag = root and ROOT_TAG[root]
  if not tag or SKIP_ROOT[root] then return near end
  if n8 and t and n8 * 2 >= t then return near end        -- meta : on propose ses enfants
  local endsAt
  if root == EVENT_ROOT then
    endsAt = holidays[cat]
    if not endsAt then return near end                    -- evenement pas en cours
  end
  if GetPreviousAchievement then                          -- chaine : une seule etape
    local okp, prev = pcall(GetPreviousAchievement, id)
    if okp and prev then
      local okc, _, _, _, pdone = pcall(GetAchievementInfo, prev)
      if okc and not pdone then return near end
    end
  end
  if root == 168 then tag = RAID_CAT[cat] and "raid" or "dungeon" end
  local exp = EXP_OF[cat] or (info.parent and EXP_OF[info.parent])
  local group = false
  if tag == "raid" then group = not (exp and exp < CUR_EXP and maxed)
  elseif tag == "dungeon" then group = not (exp and exp < CUR_EXP) end
  local cand = { id = id, name = name, icon = icon, pct = pct, done = d, total = t, tag = tag, exp = exp,
                 group = group, endsAt = endsAt, rem = (not single) and rem or nil, cat = cat }
  return near, cand
end

local function Rebuild()
  local SL = _G.TibiSuiteL or {}
  local near = {}
  for _, e in pairs(nearMap) do near[#near + 1] = e end
  table.sort(near, function(a, b) return a.pct > b.pct end)
  while #near > ACH_KEEP do table.remove(near) end
  achCache, achAt = near, GetTime()

  local byTag, list = {}, {}
  for _, c in pairs(candMap) do
    byTag[c.tag] = byTag[c.tag] or {}
    table.insert(byTag[c.tag], c)
  end
  local keep = {}
  for _, arr in pairs(byTag) do
    table.sort(arr, function(a, b) return a.pct > b.pct end)
    for i = 1, math.min(ADV_PER_TAG, #arr) do
      local c = arr[i]
      if metaOf[c.id] and SL.SUG_NOTE_META_FMT then c.note = string.format(SL.SUG_NOTE_META_FMT, metaOf[c.id])
      elseif c.rem and #c.rem > 0 then c.note = table.concat(c.rem, ", ") end
      list[#list + 1] = c; keep[c.id] = c
    end
  end
  candMap = keep                       -- seuls les affiches sont suivis entre deux parcours
  local keepNear = {}
  for _, e in ipairs(near) do keepNear[e.id] = e end
  nearMap = keepNear
  advList, advAt = list, GetTime()
  if SX.RefreshDashboard then pcall(SX.RefreshDashboard) end
  if _G.TibiSuite and _G.TibiSuite.InvalidateSuggestions then pcall(_G.TibiSuite.InvalidateSuggestions) end
end

-- Derniere erreur du parcours (diagnostic, /ts conseil l'affiche) : une
-- erreur saute la categorie en cours au lieu de figer le parcours sur
-- « en cours » pour toute la session (vu en jeu le 2026-10-14).
local lastErr

local function StepBody()
  local t0 = debugprofilestop()
  while debugprofilestop() - t0 < BUDGET_MS do
    local cat = scan.cats[scan.ci]
    if not cat then
      nearMap, candMap = scan.near, scan.cand
      local cbs = scan.onDone
      scan = nil
      local okR, errR = pcall(Rebuild)
      if not okR then
        lastErr = tostring(errR)
        advList, advAt = advList or {}, GetTime()   -- pas de relance en boucle
        achCache, achAt = achCache or {}, GetTime()
      end
      for _, fn in ipairs(cbs) do pcall(fn, achCache) end
      return
    end
    if scan.ai == 0 then
      local okN, total = pcall(GetCategoryNumAchievements, cat, true)
      scan.nCat = okN and tonumber(total) or 0
    end
    scan.ai = scan.ai + 1
    if scan.ai > scan.nCat then
      scan.ci, scan.ai = scan.ci + 1, 0
    else
      local ok, id = pcall(GetAchievementInfo, cat, scan.ai)
      if ok and id then
        local okE, near, cand = pcall(Evaluate, id, cat)
        if okE then
          if near then scan.near[id] = near end
          if cand then scan.cand[id] = cand end
        end
      end
    end
  end
end

local function Step()
  if not scan then return end
  if InCombatLockdown() then scan.wait = true; C_Timer.After(2, Step); return end
  scan.wait = false
  local ok, err = pcall(StepBody)
  if not ok then
    lastErr = tostring(err)
    if scan then scan.ci, scan.ai, scan.errs = scan.ci + 1, 0, (scan.errs or 0) + 1 end
  end
  if scan then C_Timer.After(0, Step) end
end

-- Etat du parcours pour le Conseiller de TibiSuite (diagnostic).
function Stats_AdvisorState()
  return {
    running = scan ~= nil,
    pct = scan and #scan.cats > 0 and math.floor((scan.ci - 1) / #scan.cats * 100) or nil,
    combat = scan and scan.wait or false,
    errs = scan and scan.errs or 0,
    err = lastErr,
    ready = advList ~= nil,
  }
end

function SX.ScanAchievements(onDone)
  if scan then
    if onDone then table.insert(scan.onDone, onDone) end
    return
  end
  if not (GetCategoryList and GetCategoryInfo and GetCategoryNumAchievements and GetAchievementInfo) then return end
  local okC, cats = pcall(GetCategoryList)
  if not okC or type(cats) ~= "table" then return end
  catInfo = {}
  for _, id in ipairs(cats) do
    local okI, title, parent = pcall(GetCategoryInfo, id)
    if okI then catInfo[id] = { title = title, parent = parent } end
  end
  for id, ci in pairs(catInfo) do
    local r, guard = id, 0
    while catInfo[r] and catInfo[r].parent and catInfo[r].parent ~= -1 and catInfo[catInfo[r].parent] and guard < 10 do
      r = catInfo[r].parent; guard = guard + 1
    end
    ci.root = r
  end
  holidays = ReadHolidays()
  metaOf = {}
  local maxL = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()
  maxed = maxL and UnitLevel("player") >= maxL or false
  scan = { cats = cats, ci = 1, ai = 0, nCat = 0, near = {}, cand = {}, onDone = { onDone } }
  C_Timer.After(0, Step)
end

function SX.IsScanningAchievements() return scan ~= nil end

function SX.NearAchievements()
  if (not achCache or GetTime() - achAt > RESCAN) and not scan then SX.ScanAchievements() end
  return achCache
end

-- Criteres d'un haut fait pour la fiche du Conseiller, comme la fenetre des
-- hauts faits de Blizzard : TOUS les criteres dans l'ordre du jeu (faits et
-- pas faits), 40 au plus, plus la description et les points (vu en jeu le
-- 2026-10-15 : la liste « restants seulement » ne ressemblait pas au haut
-- fait officiel). Renvoie { { text, done, value } }, { desc, points }.
function SX.AchSteps(id)
  local SL = _G.TibiSuiteL or {}
  local out = {}
  local okN, n = pcall(GetAchievementNumCriteria, id)
  n = okN and tonumber(n) or 0
  for i = 1, n do
    local ok, text, _, completed, qty, req, _, _, _, qstr = pcall(GetAchievementCriteriaInfo, id, i)
    if ok then
      local val
      if req and req > 1 then
        val = (type(qstr) == "string" and qstr ~= "") and qstr or (tostring(qty or 0) .. " / " .. tostring(req))
      end
      local t = (type(text) == "string" and text ~= "") and text
        or (val and string.format(SL.SUG_ST_PROGRESS_FMT or "%s", val)) or nil
      if t then
        if #out >= 40 then
          out[#out + 1] = { text = string.format(SL.SUG_ST_MORE_FMT or "+%d", n - i + 1) }
          break
        end
        local value = val
        if t ~= text then value = nil end    -- deja dans le texte (« Progression : 310 / 400 »)
        out[#out + 1] = { text = t, done = completed and true or false, value = value }
      end
    end
  end
  local okI, _, _, points, _, _, _, _, desc = pcall(GetAchievementInfo, id)
  return out, { desc = okI and type(desc) == "string" and desc ~= "" and desc or nil, points = okI and points or nil }
end

-- Candidats du Conseiller (contrat suggestFn de TibiSuite). Renvoie
-- liste, pending.
function SX.AdvisorSuggestions()
  if (not advList or GetTime() - advAt > RESCAN) and not scan then SX.ScanAchievements() end
  if not advList then return {}, true end
  local out, now = {}, time()
  for _, c in ipairs(advList) do
    if not (c.endsAt and c.endsAt < now) then
      local id = c.id
      out[#out + 1] = { id = "ach:" .. id, kind = "ach", text = c.name, icon = c.icon, tag = c.tag,
        proximity = c.pct, done = c.done, total = c.total, endsAt = c.endsAt, group = c.group,
        note = c.note, open = function() SX.OpenAchievement(id) end,
        steps = function() return SX.AchSteps(id) end }
    end
  end
  return out, scan ~= nil
end

-- Mise a jour ciblee entre deux parcours : seulement les hauts faits
-- affiches (une trentaine au plus), regroupee a 5 s, hors combat.
local refreshT, refreshExtra = nil, {}
local function RefreshShown()
  refreshT = nil
  if scan or not advList then return end
  if InCombatLockdown() then refreshT = C_Timer.NewTimer(5, RefreshShown); return end
  local ids = {}
  for id in pairs(nearMap) do ids[id] = true end
  for id in pairs(candMap) do ids[id] = true end
  for id in pairs(refreshExtra) do ids[id] = true end
  refreshExtra = {}
  for id in pairs(ids) do
    local cat = candMap[id] and candMap[id].cat
    local ok, near, cand = pcall(Evaluate, id, cat)
    nearMap[id] = ok and near or nil
    candMap[id] = ok and cand or nil
  end
  Rebuild()
end
local function QueueRefresh()
  if not refreshT then refreshT = C_Timer.NewTimer(5, RefreshShown) end
end

local achEv = CreateFrame("Frame")
achEv:RegisterEvent("ACHIEVEMENT_EARNED")
achEv:RegisterEvent("CRITERIA_UPDATE")
achEv:RegisterEvent("PLAYER_ENTERING_WORLD")
achEv:SetScript("OnEvent", function(_, event, id)
  -- Parcours lance 30 s apres le chargement (une fois), seulement quand le
  -- Conseiller de TibiSuite est actif : sinon la premiere demande (/ts
  -- conseil) le lancait et repondait « en cours » (vu en jeu le 2026-10-14).
  if event == "PLAYER_ENTERING_WORLD" then
    achEv:UnregisterEvent("PLAYER_ENTERING_WORLD")
    C_Timer.After(30, function()
      local TS = _G.TibiSuite
      if TS and TS.SuggestOn and TS.SuggestOn() and not advList and not scan then SX.ScanAchievements() end
    end)
    return
  end
  if event == "ACHIEVEMENT_EARNED" and type(id) == "number" then
    nearMap[id], candMap[id] = nil, nil
    -- L'etape suivante d'une chaine devient proposable.
    if GetNextAchievement then
      local ok, nxt = pcall(GetNextAchievement, id)
      if ok and nxt then refreshExtra[nxt] = true end
    end
  end
  if advList or achCache then QueueRefresh() end
end)

-- Ouvre le haut fait dans la fenetre de Blizzard.
function SX.OpenAchievement(id)
  if not AchievementFrame and UIParentLoadAddOn then pcall(UIParentLoadAddOn, "Blizzard_AchievementUI") end
  if OpenAchievementFrameToAchievement then pcall(OpenAchievementFrameToAchievement, id) end
end

-- ============================================================================
-- SONDE DU CONSEILLER (lot 0, _dev/Conseiller.md)
-- ----------------------------------------------------------------------------
-- /stats probe adv          lance le releve (une categorie par image)
-- /stats probe adv report   resume dans le chat
-- /stats probe adv clear    efface le releve
-- Lecture seule. Resultat dans StatsDB[perso].advProbe (jamais une cle de
-- premier niveau de StatsDB : elle serait prise pour un personnage).
-- Releve : arbre des categories, types de criteres, criteres « haut fait »
-- (type 8, metas), chaines precedent / suivant, hauts faits de compte, cout
-- du parcours, evenements du calendrier rapproches des categories.
-- ============================================================================
local ADV_P = "|cFFFFD700[Stats sonde]|r "
local advRunning = false

local function AdvRec()
  local key = SX.CurrentCharKey and SX.CurrentCharKey()
  return key and StatsDB and StatsDB[key]
end

local function AdvNorm(s)
  return type(s) == "string" and s:lower():gsub("%s+", " ") or ""
end

local function AdvHolidays()
  local out = {}
  if not (C_Calendar and C_Calendar.GetNumDayEvents and C_Calendar.GetDayEvent and C_DateAndTime) then return out end
  if C_Calendar.OpenCalendar then pcall(C_Calendar.OpenCalendar) end
  local ok, today = pcall(C_DateAndTime.GetCurrentCalendarTime)
  if not ok or type(today) ~= "table" then return out end
  local okN, n = pcall(C_Calendar.GetNumDayEvents, 0, today.monthDay)
  for i = 1, (okN and tonumber(n) or 0) do
    local okE, e = pcall(C_Calendar.GetDayEvent, 0, today.monthDay, i)
    if okE and type(e) == "table" and e.calendarType == "HOLIDAY" and type(e.title) == "string"
       and not (issecretvalue and issecretvalue(e.title)) then
      out[#out + 1] = { title = e.title, eventID = e.eventID }
    end
  end
  return out
end

local function AdvRun()
  local rec = AdvRec()
  if not rec then print(ADV_P .. "personnage pas encore connu de Stats, reessaie dans quelques secondes."); return end
  if advRunning then print(ADV_P .. "deja en cours."); return end
  if not (GetCategoryList and GetCategoryInfo and GetCategoryNumAchievements and GetAchievementInfo) then
    print(ADV_P .. "API des hauts faits absente."); return
  end
  local okC, cats = pcall(GetCategoryList)
  if not okC or type(cats) ~= "table" then print(ADV_P .. "GetCategoryList a echoue."); return end

  advRunning = true
  local _, build = GetBuildInfo()
  local P = {
    at = time(), build = build, locale = GetLocale(), level = UnitLevel("player"),
    maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or nil,
    cats = {}, critTypes = {}, critByRoot = {}, critSamples = {},
    meta = {}, chains = {}, legacy = {},
    ach = { total = 0, done = 0, doneByAlt = 0, accountFlag = 0, guild = 0, statistic = 0, zero = 0, incomplete = 0,
            withCrit = 0, critRead = 0 },
    cost = { frames = 0, ms = 0, maxFrameMs = 0 },
    holidays = AdvHolidays(), holidayMatch = {},
  }
  print(ADV_P .. string.format("parcours de %d categories, une par image...", #cats))

  -- Arbre d'abord (rapide) : titre, parent, ordre, nombre de hauts faits.
  for o, id in ipairs(cats) do
    local okI, title, parent, flags = pcall(GetCategoryInfo, id)
    local okN, total, done = pcall(GetCategoryNumAchievements, id, true)
    P.cats[id] = { t = okI and title or nil, p = okI and parent or nil, f = okI and flags or nil, o = o,
                   n = okN and total or nil, d = okN and done or nil }
  end
  local function RootOf(id)
    local guard = 0
    while P.cats[id] and P.cats[id].p and P.cats[id].p ~= -1 and P.cats[P.cats[id].p] and guard < 10 do
      id = P.cats[id].p; guard = guard + 1
    end
    return id
  end

  local ACC = 0x00020000   -- ACHIEVEMENT_FLAGS_ACCOUNT
  local band = bit and bit.band
  local ci, startMs = 0, debugprofilestop()
  local function step()
    if InCombatLockdown() then C_Timer.After(1, step); return end
    ci = ci + 1
    local cat = cats[ci]
    if not cat then
      P.cost.ms = math.floor(debugprofilestop() - startMs)
      -- Evenements du calendrier rapproches des titres de categories.
      for _, h in ipairs(P.holidays) do
        local hn, hits = AdvNorm(h.title), {}
        for id, c in pairs(P.cats) do
          local cn = AdvNorm(c.t)
          if cn ~= "" and (hn:find(cn, 1, true) or cn:find(hn, 1, true)) then hits[#hits + 1] = id end
        end
        P.holidayMatch[h.title] = hits
      end
      rec.advProbe = P
      advRunning = false
      print(ADV_P .. string.format("termine : %d hauts faits, %d criteres lus, %d ms au total (%d images, pire image %d ms). /stats probe adv report",
        P.ach.total, P.ach.critRead, P.cost.ms, P.cost.frames, math.floor(P.cost.maxFrameMs)))
      return
    end
    local t0 = debugprofilestop()
    local root = RootOf(cat)
    local okN, total = pcall(GetCategoryNumAchievements, cat, true)
    for i = 1, (okN and tonumber(total) or 0) do
      local ok, id, name, points, completed, _, _, _, _, flags, _, _, isGuild, wasEarnedByMe, _, isStatistic = pcall(GetAchievementInfo, cat, i)
      if ok and id then
        local A = P.ach
        A.total = A.total + 1
        if completed then A.done = A.done + 1 end
        if completed and wasEarnedByMe == false then A.doneByAlt = A.doneByAlt + 1 end
        if band and flags and band(flags, ACC) ~= 0 then A.accountFlag = A.accountFlag + 1 end
        if isGuild then A.guild = A.guild + 1 end
        if isStatistic then A.statistic = A.statistic + 1 end
        if (points or 0) == 0 then A.zero = A.zero + 1 end
        if not completed then A.incomplete = A.incomplete + 1 end
        -- Chaines (precedent / suivant), quelques exemples.
        if #P.chains < 15 and GetPreviousAchievement then
          local okP, prev = pcall(GetPreviousAchievement, id)
          if okP and prev then
            local okX, nxt = pcall(GetNextAchievement or function() end, id)
            P.chains[#P.chains + 1] = { id = id, name = name, prev = prev, nxt = okX and nxt or nil }
          end
        end
        -- Criteres : seulement des hauts faits pas finis (comme le futur parcours).
        if not completed and not isGuild and not isStatistic then
          local okC2, nc = pcall(GetAchievementNumCriteria, id)
          nc = okC2 and tonumber(nc) or 0
          if nc > 0 then A.withCrit = A.withCrit + 1 end
          for k = 1, nc do
            local okK, text, ctype, cdone, qty, req, _, _, assetID = pcall(GetAchievementCriteriaInfo, id, k)
            if okK then
              A.critRead = A.critRead + 1
              ctype = ctype or -1
              P.critTypes[ctype] = (P.critTypes[ctype] or 0) + 1
              local br = P.critByRoot[root] or {}
              br[ctype] = (br[ctype] or 0) + 1
              P.critByRoot[root] = br
              if #P.critSamples < 40 and not P.critSamples["t" .. ctype] then
                P.critSamples["t" .. ctype] = true
                P.critSamples[#P.critSamples + 1] = { ach = id, i = k, type = ctype, asset = assetID, text = text, qty = qty, req = req }
              end
              -- Type 8 : le critere est-il un autre haut fait ? (metas)
              if ctype == 8 and #P.meta < 20 and assetID and assetID > 0 then
                local okM, mid, mname, _, mdone = pcall(GetAchievementInfo, assetID)
                P.meta[#P.meta + 1] = { ach = id, achName = name, asset = assetID, text = text, done = cdone,
                                        assetIsAch = okM and mid == assetID or false, assetName = okM and mname or nil, assetDone = okM and mdone or nil }
              end
            end
          end
        end
      end
    end
    -- Titres qui ressemblent a « Heritage » / « Legacy » (contenu disparu).
    local ct = AdvNorm(P.cats[cat] and P.cats[cat].t)
    if ct:find("h\195\169ritage", 1, true) or ct:find("legacy", 1, true) or ct:find("tours de force", 1, true) or ct:find("feats of strength", 1, true) then
      P.legacy[#P.legacy + 1] = cat
    end
    local dt = debugprofilestop() - t0
    P.cost.frames = P.cost.frames + 1
    if dt > P.cost.maxFrameMs then P.cost.maxFrameMs = dt end
    C_Timer.After(0, step)
  end
  step()
end

local function AdvReport()
  local rec = AdvRec()
  local P = rec and rec.advProbe
  if not P then print(ADV_P .. "aucun releve. Lance d'abord /stats probe adv"); return end
  print(ADV_P .. string.format("releve du %s, build %s, %s, niveau %s / %s",
    date("%d/%m %H:%M", P.at), tostring(P.build), tostring(P.locale), tostring(P.level), tostring(P.maxLevel)))
  local A = P.ach
  print(ADV_P .. string.format("hauts faits %d (finis %d, dont par un autre perso %d, drapeau compte %d, guilde %d, stats %d, 0 point %d, pas finis %d)",
    A.total, A.done, A.doneByAlt, A.accountFlag, A.guild, A.statistic, A.zero, A.incomplete))
  print(ADV_P .. string.format("cout : %d ms, %d images, pire image %d ms, %d criteres lus",
    P.cost.ms, P.cost.frames, math.floor(P.cost.maxFrameMs), A.critRead))
  -- Racines.
  local roots = {}
  for id, c in pairs(P.cats) do if c.p == -1 then roots[#roots + 1] = id end end
  table.sort(roots, function(a, b) return (P.cats[a].o or 0) < (P.cats[b].o or 0) end)
  for _, id in ipairs(roots) do
    local kids = 0
    for _, c in pairs(P.cats) do if c.p == id then kids = kids + 1 end end
    print(ADV_P .. string.format("  racine %d  %s  (%d sous-categories, %s hauts faits)", id, tostring(P.cats[id].t), kids, tostring(P.cats[id].n)))
  end
  -- Gouffres.
  for id, c in pairs(P.cats) do
    local t = AdvNorm(c.t)
    if t:find("gouffre", 1, true) or t:find("delve", 1, true) then
      print(ADV_P .. string.format("  gouffres ? %d  %s  (parent %s)", id, tostring(c.t), tostring(c.p)))
    end
  end
  -- Types de criteres les plus frequents.
  local types = {}
  for t, n in pairs(P.critTypes) do types[#types + 1] = { t = t, n = n } end
  table.sort(types, function(a, b) return a.n > b.n end)
  local parts = {}
  for i = 1, math.min(10, #types) do parts[#parts + 1] = types[i].t .. "=" .. types[i].n end
  print(ADV_P .. "types de criteres : " .. table.concat(parts, ", "))
  -- Metas.
  local ok8 = 0
  for _, m in ipairs(P.meta) do if m.assetIsAch then ok8 = ok8 + 1 end end
  print(ADV_P .. string.format("criteres type 8 : %d exemples, %d pointent bien vers un haut fait", #P.meta, ok8))
  for i = 1, math.min(3, #P.meta) do
    local m = P.meta[i]
    print(ADV_P .. string.format("    %s -> %s (%s)", tostring(m.achName), tostring(m.assetName), tostring(m.asset)))
  end
  print(ADV_P .. string.format("chaines : %d exemples ; categories heritage / tours de force : %d", #P.chains, #P.legacy))
  if #P.holidays == 0 then
    print(ADV_P .. "aucun evenement du calendrier aujourd'hui")
  else
    for _, h in ipairs(P.holidays) do
      local hits = P.holidayMatch[h.title] or {}
      local names = {}
      for _, id in ipairs(hits) do names[#names + 1] = tostring(P.cats[id] and P.cats[id].t) .. " (" .. id .. ")" end
      print(ADV_P .. string.format("evenement « %s » -> %s", h.title, #names > 0 and table.concat(names, ", ") or "aucune categorie"))
    end
  end
  print(ADV_P .. "detail complet dans le fichier SavedVariables Stats.lua apres /reload ou deconnexion.")
end

function SX.ProbeAdv(arg)
  arg = (arg or ""):lower()
  if arg == "report" then AdvReport()
  elseif arg == "clear" then
    local rec = AdvRec()
    if rec then rec.advProbe = nil end
    print(ADV_P .. "releve efface.")
  else AdvRun() end
end

-- ============================================================================
-- BILAN DE SESSION (7.1.5.45, feuille de route lot 6)
-- ----------------------------------------------------------------------------
-- Une session = du login a la deconnexion ; un /reload (moins de 5 min
-- d'ecart) la prolonge. Gardee dans le personnage : rec.liveSession, puis
-- rec.lastSession. A la connexion suivante, la session precedente (10 min
-- au moins) est resumee dans le fil d'activite de TibiSuite.
-- Compteurs = difference des journees de Stats depuis le debut de session
-- (fonctionne a cheval sur minuit) ; or = difference de GetMoney().
-- ============================================================================
local SESSION_GAP, SESSION_MIN = 300, 600

local function DayStart(ts)
  local d = date("*t", ts)
  d.hour, d.min, d.sec = 0, 0, 0
  return time(d)
end

local function Counters(key, from, to)
  local ok, a = pcall(SX.Aggregate, key, from, to)
  if not ok or type(a) ~= "table" then return {} end
  return { quests = a.quests or 0, dungeons = (a.dungeons or 0) + (a.mplusCount or 0), delves = a.delves or 0,
           raids = a.raids or 0, rep = a.repGained or 0 }
end

-- Etat d'une session : duree, or, compteurs depuis son debut.
function SX.SessionNow(s, key)
  if type(s) ~= "table" then return nil end
  local now = s.ended or time()
  local cur = Counters(key, DayStart(s.start), now)
  local out = { start = s.start, dur = math.max(0, (s.last or now) - s.start),
                gold = (s.moneyEnd or (GetMoney and GetMoney()) or 0) - (s.money or 0) }
  for k, v in pairs(cur) do out[k] = math.max(0, v - ((s.base or {})[k] or 0)) end
  if _G.SkillTracker_GatheredSince then
    local okG, n = pcall(SkillTracker_GatheredSince, s.start)
    if okG then out.gathered = n end
  end
  return out
end

function SX.SessionText(r)
  local L = SX.L
  local TS = _G.TibiSuite
  local dur = (TS and TS.FmtDuration) and TS.FmtDuration(r.dur) or (math.floor(r.dur / 60) .. " min")
  local gold = (TS and TS.FmtGold) and (TS.FmtGold(r.gold) .. " " .. L["SESSION_GOLD_UNIT"]) or tostring(math.floor(r.gold / 10000))
  local parts = { dur, gold }
  if (r.quests or 0) > 0 then parts[#parts + 1] = string.format(L["SESSION_QUESTS_FMT"], r.quests) end
  if (r.dungeons or 0) > 0 then parts[#parts + 1] = string.format(L["SESSION_DUNGEONS_FMT"], r.dungeons) end
  if (r.delves or 0) > 0 then parts[#parts + 1] = string.format(L["SESSION_DELVES_FMT"], r.delves) end
  if (r.raids or 0) > 0 then parts[#parts + 1] = string.format(L["SESSION_RAIDS_FMT"], r.raids) end
  if (r.gathered or 0) > 0 then parts[#parts + 1] = string.format(L["SESSION_GATHER_FMT"], r.gathered) end
  return table.concat(parts, "  ·  ")
end

local function SessionStart(rec, key)
  local now = time()
  local d0 = DayStart(now)
  rec.liveSession = { start = now, last = now, money = GetMoney and GetMoney() or 0,
                      base = Counters(key, d0, now) }
end

local function SessionTick(final)
  local key = SX.CurrentCharKey and SX.CurrentCharKey()
  local rec = key and StatsDB and StatsDB[key]
  local s = rec and rec.liveSession
  if not s then return end
  s.last = time()
  s.moneyEnd = GetMoney and GetMoney() or s.moneyEnd
end
SX.SessionTick = SessionTick

local sessionFrame = CreateFrame("Frame")
sessionFrame:RegisterEvent("PLAYER_LOGIN")
sessionFrame:RegisterEvent("PLAYER_LOGOUT")
sessionFrame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGOUT" then pcall(SessionTick, true); return end
  C_Timer.After(3, function()
    local key = SX.CurrentCharKey and SX.CurrentCharKey()
    local rec = key and StatsDB and StatsDB[key]
    if type(rec) ~= "table" then return end
    rec.histSince = rec.histSince or time()
    local s = rec.liveSession
    local now = time()
    if s and now - (s.last or 0) <= SESSION_GAP then
      -- /reload ou deconnexion breve : la session continue.
    else
      -- Compteurs de la carte Session (7.1.5.45) : toute session d'une
      -- minute au moins, ecrite dans sa journee de depart.
      if s and s.start and (s.last or s.start) - s.start >= 60 then
        local okD, d = pcall(SX.EnsureDay, rec, SX.DayKey(s.start))
        if okD and d then
          d.sessions = (d.sessions or 0) + 1
          d.sessionTime = (d.sessionTime or 0) + ((s.last or s.start) - s.start)
        end
      end
      if s and (s.last or s.start) - s.start >= SESSION_MIN then
        s.ended = s.last
        local okR, r = pcall(SX.SessionNow, s, key)
        if okR and r then
          rec.lastSession = r
          local TS = _G.TibiSuite
          if TS and TS.Notify then
            TS.Notify("Stats", string.format(SX.L["SESSION_NOTIFY_FMT"], date("%d/%m %H:%M", s.start), SX.SessionText(r)),
              { toast = false })
          end
        end
      end
      SessionStart(rec, key)
    end
    C_Timer.NewTicker(60, function() pcall(SessionTick) end)
  end)
end)
