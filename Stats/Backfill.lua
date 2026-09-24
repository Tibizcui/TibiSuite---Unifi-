--[[============================================================================
  Stats - Backfill.lua
  ---------------------------------------------------------------------------
  Rattrapage de l'extension ("exp") des evenements enregistres AVANT la
  7.1.5.16, et correction manuelle depuis la liste d'evenements.

  Le probleme : ces anciens evenements ne gardent que des NOMS (titre de
  quete + sous-zone, nom d'instance, de faction, de metier, de gouffre),
  jamais d'identifiant. GetQuestExpansion & co. exigent un ID : on passe
  donc par des index nom -> extension construits EN JEU a partir des donnees
  locales du client (aucun appel serveur) :

    Donjons, M+, raids  Guide de l'aventurier : chaque palier (EJ tier) est une
                        extension, chaque instance y est rangee.     -> certain
    Reputation          Carte factionID -> extension deja utilisee pour les
                        nouveaux gains (Core.lua) + factions a renom.  -> certain
    Metiers             Le gain etait mesure sur le palier de l'extension EN
                        COURS a la date de l'evenement.               -> certain
    Gouffres            Nom de la carte du gouffre -> continent.        -> certain
                        repli : date (avant Midnight = The War Within). -> estime
    Quetes, expeditions Sous-zone (zones explorees) ou zone -> continent. -> estime

  Un resultat ESTIME porte expEst = true : l'addon, Tibi Companion et le site
  l'affichent "≈ Extension". Les continents ambigus (Kalimdor, Royaumes de
  l'Est, Maelstrom : Classic, Cataclysm et les refontes s'y melangent,
  capitales comprises) ne sont JAMAIS devines : l'evenement reste "-", a
  corriger a la main (clic sur la cellule Extension, cf. UI.lua).

  Le rattrapage ne remplit que les evenements SANS extension : il n'ecrase
  jamais une valeur lue en direct ni une correction manuelle. Lance une fois
  automatiquement (StatsDB.expBackfill), relancable depuis les options.
  Tourne par petits morceaux a chaque image (coroutine), en pause en combat.

  A VERIFIER EN JEU (aucun client disponible a l'ecriture) :
    - EJ_GetTierInfo renvoie des noms egaux a EXPANSION_NAMEn (sinon repli
      sur l'ordre des paliers) ;
    - C_MapExplorationInfo.GetExploredAreaIDsAtPosition sous 12.x ;
    - IDs de continents ci-dessous, et la regle "carte recente sous un
      continent ambigu = extension en cours" (ID > 2371) pour Midnight ;
    - date de sortie de Midnight (EXP_RELEASES).
============================================================================]]

local ADDON, SX = ...
local L = SX.L

SX.EXP_BACKFILL_VERSION = 1

local function Print(msg) print("|cFFFFD700Stats|r : " .. msg) end

-- ============================================================================
-- NORMALISATION DES NOMS (casse, accents, ponctuation, apostrophes typo)
-- ============================================================================
local function Norm(s)
  if type(s) ~= "string" or s == "" then return "" end
  local UI = _G.TibiMidnight
  s = (UI and UI.Normalize) and UI.Normalize(s) or s:lower()
  s = s:gsub("\226\128\153", ""):gsub("\194\160", ""):gsub("\226\128\175", "")
  s = s:gsub("[%s%p]", "")
  return s
end
SX.NormName = Norm

-- Nom d'extension Blizzard (EXPANSION_NAMEn, localise) -> numero.
local function HeaderExpMap()
  local m = {}
  for i = 0, 30 do
    local s = _G["EXPANSION_NAME" .. i]
    if type(s) == "string" and s ~= "" then m[Norm(s)] = i end
  end
  return m
end

-- Ajoute nom -> exp dans un index ; un meme nom rencontre avec deux
-- extensions differentes devient ambigu (false) et ne sera jamais utilise.
local function Put(idx, name, exp)
  local k = Norm(name)
  if k == "" or exp == nil then return end
  local cur = idx[k]
  if cur == nil then idx[k] = exp
  elseif cur ~= false and cur ~= exp then idx[k] = false end
end

local function Get(idx, name)
  local v = idx[Norm(name)]
  if v == false then return nil end
  return v
end

-- ============================================================================
-- DATES DE SORTIE (metiers, repli des gouffres)
-- Date UTC de sortie de chaque extension (1 = Burning Crusade ...).
-- ============================================================================
local EXP_RELEASES = {
  { 1168905600, 1 },   -- 2007-01-16 Burning Crusade
  { 1226534400, 2 },   -- 2008-11-13 Wrath of the Lich King
  { 1291680000, 3 },   -- 2010-12-07 Cataclysm
  { 1348531200, 4 },   -- 2012-09-25 Mists of Pandaria
  { 1415836800, 5 },   -- 2014-11-13 Warlords of Draenor
  { 1472515200, 6 },   -- 2016-08-30 Legion
  { 1534204800, 7 },   -- 2018-08-14 Battle for Azeroth
  { 1606089600, 8 },   -- 2020-11-23 Shadowlands
  { 1669593600, 9 },   -- 2022-11-28 Dragonflight
  { 1724630400, 10 },  -- 2024-08-26 The War Within
  { 1772409600, 11 },  -- 2026-03-02 Midnight (A VERIFIER)
}

local function ExpansionAtDate(ts)
  if not ts then return nil end
  local exp = 0
  for _, r in ipairs(EXP_RELEASES) do
    if ts >= r[1] then exp = r[2] end
  end
  local cur = SX.CurrentExpansionLevel()
  if cur and exp > cur then exp = cur end
  return exp
end
SX.ExpansionAtDate = ExpansionAtDate

-- ============================================================================
-- CARTES : continent -> extension
-- ============================================================================
local CONTINENT_EXP = {
  [101] = 1,               -- Outreterre
  [113] = 2,               -- Norfendre
  [424] = 4,               -- Pandarie
  [572] = 5,               -- Draenor
  [619] = 6,               -- Iles Brisees
  [875] = 7, [876] = 7,    -- Zandalar, Kul Tiras
  [1550] = 8,              -- Ombreterre
  [1978] = 9,              -- Iles aux Dragons
  [2274] = 10, [2346] = 10, [2371] = 10,  -- Khaz Algar, Terremine, K'aresh
}
-- Classic, Cataclysm et refontes melanges : jamais devines (capitales comprises).
local AMBIGUOUS_CONTINENT = { [12] = true, [13] = true, [948] = true }
local LAST_KNOWN_MAP_ID = 2371   -- au-dela : carte ajoutee apres The War Within

local UIMAP_CONTINENT = (Enum and Enum.UIMapType and Enum.UIMapType.Continent) or 2
local UIMAP_ZONE      = (Enum and Enum.UIMapType and Enum.UIMapType.Zone) or 3

-- Extension d'une carte en remontant ses parents. nil = inconnue ou ambigue.
local mapExpCache = {}
local function ExpForMap(mapID)
  if mapExpCache[mapID] ~= nil then return mapExpCache[mapID] or nil end
  local id, guard, result = mapID, 0, false
  while id and id ~= 0 and guard < 12 do
    if CONTINENT_EXP[id] then result = CONTINENT_EXP[id]; break end
    if AMBIGUOUS_CONTINENT[id] then
      -- Carte recente rangee sous un vieux continent (ex. zones de Midnight
      -- sous les Royaumes de l'Est) : extension en cours. A VERIFIER EN JEU.
      if mapID > LAST_KNOWN_MAP_ID then result = SX.CurrentExpansionLevel() or false end
      break
    end
    local ok, info = pcall(C_Map.GetMapInfo, id)
    if not (ok and info) then break end
    if info.mapType == UIMAP_CONTINENT and id > LAST_KNOWN_MAP_ID then
      result = SX.CurrentExpansionLevel() or false   -- continent inconnu et recent
      break
    end
    id = info.parentMapID
    guard = guard + 1
  end
  mapExpCache[mapID] = result
  return result or nil
end

-- ============================================================================
-- CONSTRUCTION DES INDEX (dans une coroutine : Yield rend la main au jeu)
-- ============================================================================
local budget = 0
local function Tick(cost)
  budget = budget + (cost or 1)
  if budget >= 400 then budget = 0; coroutine.yield() end
end

-- Guide de l'aventurier : nom d'instance -> extension du palier.
local function BuildInstanceIndex()
  local idx = {}
  if not (EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex and EJ_GetTierInfo) then return idx end
  local okN, n = pcall(EJ_GetNumTiers)
  if (not okN or not n or n == 0) and C_AddOns and C_AddOns.LoadAddOn then
    pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal")
    okN, n = pcall(EJ_GetNumTiers)
  end
  if not okN or not n or n == 0 then return idx end
  -- Ne jamais changer le palier sous les yeux du joueur.
  if _G.EncounterJournal and _G.EncounterJournal:IsShown() then return idx end
  local headers = HeaderExpMap()
  local cur = SX.CurrentExpansionLevel() or 30
  local okCur, savedTier = pcall(EJ_GetCurrentTier)
  for tier = 1, n do
    local okT, tierName = pcall(EJ_GetTierInfo, tier)
    local exp = okT and headers[Norm(tierName)]
    if exp == nil and tier - 1 <= cur then exp = tier - 1 end   -- repli : ordre des paliers
    if exp ~= nil then
      pcall(EJ_SelectTier, tier)
      for _, isRaid in ipairs({ false, true }) do
        for i = 1, 250 do
          local ok, id, name = pcall(EJ_GetInstanceByIndex, i, isRaid)
          if not (ok and id) then break end
          Put(idx, name, exp)
          -- Pas de Tick() ici : le palier selectionne doit etre restaure
          -- d'un seul tenant, sans rendre la main au jeu entre-temps.
        end
      end
    end
  end
  if okCur and savedTier then pcall(EJ_SelectTier, savedTier) end
  return idx
end

-- Cartes : nom de carte -> extension, et liste des zones a explorer.
local function BuildMapIndex()
  local idx, zones = {}, {}
  if not (C_Map and C_Map.GetMapInfo) then return idx, zones end
  for id = 1, 4500 do
    local ok, info = pcall(C_Map.GetMapInfo, id)
    if ok and info and info.name and info.name ~= "" then
      local exp = ExpForMap(id)
      if exp ~= nil then
        Put(idx, info.name, exp)
        if info.mapType == UIMAP_ZONE then zones[#zones + 1] = { id = id, exp = exp } end
      end
    end
    Tick()
  end
  return idx, zones
end

-- Sous-zones : on echantillonne chaque zone sur une grille et on recupere les
-- zones explorees a chaque point (nom de sous-zone -> extension de la zone).
-- Ne voit que les sous-zones EXPLOREES par ce personnage : le rattrapage des
-- alts peut donc rester partiel. A VERIFIER EN JEU.
local GRID = 12
local function BuildAreaIndex(zones)
  local idx = {}
  local api = C_MapExplorationInfo and C_MapExplorationInfo.GetExploredAreaIDsAtPosition
  if not (api and C_Map.GetAreaInfo and CreateVector2D) then return idx end
  for _, z in ipairs(zones) do
    local seen = {}
    for gx = 1, GRID do
      for gy = 1, GRID do
        local ok, ids = pcall(api, z.id, CreateVector2D((gx - .5) / GRID, (gy - .5) / GRID))
        if ok and type(ids) == "table" then
          for _, areaID in ipairs(ids) do
            if not seen[areaID] then
              seen[areaID] = true
              local okA, name = pcall(C_Map.GetAreaInfo, areaID)
              if okA then Put(idx, name, z.exp) end
            end
          end
        end
        Tick()
      end
    end
  end
  return idx
end

-- Reputation : nom de faction -> extension.
local function BuildFactionIndex()
  local idx = {}
  local ok, map = pcall(SX.BuildFactionExpansionMap)
  if ok and type(map) == "table" and C_Reputation and C_Reputation.GetFactionDataByID then
    for factionID, exp in pairs(map) do
      local okD, d = pcall(C_Reputation.GetFactionDataByID, factionID)
      if okD and d and d.name then Put(idx, d.name, exp) end
      Tick()
    end
  end
  if C_MajorFactions and C_MajorFactions.GetMajorFactionIDs and C_MajorFactions.GetMajorFactionData then
    for exp = 9, (SX.CurrentExpansionLevel() or 11) do
      local okI, ids = pcall(C_MajorFactions.GetMajorFactionIDs, exp)
      if okI and type(ids) == "table" then
        for _, fid in ipairs(ids) do
          local okD, d = pcall(C_MajorFactions.GetMajorFactionData, fid)
          if okD and d and d.name then Put(idx, d.name, exp) end
        end
      end
    end
  end
  return idx
end

-- M+ : "Tazavesh : Rues des merveilles" -> essaie aussi la partie avant ":".
local function InstanceExp(inst, name)
  local exp = Get(inst, name)
  if exp == nil and type(name) == "string" then
    local head = name:match("^(.-)%s*[:%-]")
    if head and head ~= "" then exp = Get(inst, head) end
  end
  return exp
end

-- ============================================================================
-- APPLICATION A TOUS LES PERSONNAGES
-- ============================================================================
local function ApplyAll(ix, stats)
  local function Set(e, exp, est)
    stats.total = stats.total + 1
    if exp == nil then return end
    e.exp = exp
    e.expEst = est and true or nil
    stats.found = stats.found + 1
    if est then stats.estimated = stats.estimated + 1 end
  end
  for _, key in ipairs(SX.GetCharKeys()) do
    local rec = StatsDB[key]
    if type(rec) == "table" and type(rec.days) == "table" then
      for _, d in pairs(rec.days) do
        for _, e in ipairs(d.questLog or {}) do
          if e.exp == nil then
            local exp = Get(ix.area, e.zone)
            if exp == nil then exp = Get(ix.map, e.zone) end
            Set(e, exp, true)
          end
        end
        for _, e in ipairs(d.mplus or {}) do
          if e.exp == nil then Set(e, InstanceExp(ix.inst, e.map), false) end
        end
        for _, list in ipairs({ d.dungeonLog or {}, d.raidLog or {} }) do
          for _, e in ipairs(list) do
            if e.exp == nil then
              local exp = InstanceExp(ix.inst, e.name)
              if exp ~= nil then Set(e, exp, false)
              else Set(e, Get(ix.map, e.name), true) end
            end
          end
        end
        for _, e in ipairs(d.delveLog or {}) do
          if e.exp == nil then
            local exp = Get(ix.map, e.name)
            if exp ~= nil then Set(e, exp, false)
            elseif e.ts and e.ts < EXP_RELEASES[#EXP_RELEASES][1] then Set(e, 10, true)   -- gouffres = TWW avant Midnight
            else Set(e, nil) end
          end
        end
        for _, e in ipairs(d.repLog or {}) do
          if e.exp == nil then Set(e, Get(ix.faction, e.faction), false) end
        end
        for _, e in ipairs(d.profLog or {}) do
          if e.exp == nil then Set(e, ExpansionAtDate(e.ts), false) end
        end
        Tick(4)
      end
    end
  end
end

-- ============================================================================
-- PILOTE : une coroutine avancee a chaque image, en pause en combat
-- ============================================================================
local driver = CreateFrame("Frame")
driver:Hide()
local running = nil

function SX.IsExpBackfillRunning() return running ~= nil end

function SX.RunExpBackfill(verbose)
  if running then
    if verbose then Print(L["EXP_BACKFILL_RUNNING"]) end
    return
  end
  if verbose then Print(L["EXP_BACKFILL_RUNNING"]) end
  budget = 0
  mapExpCache = {}
  running = coroutine.create(function()
    local ix, stats = {}, { total = 0, found = 0, estimated = 0 }
    ix.inst = BuildInstanceIndex()
    local zones
    ix.map, zones = BuildMapIndex()
    ix.area = BuildAreaIndex(zones)
    ix.faction = BuildFactionIndex()
    ApplyAll(ix, stats)
    return stats
  end)
  driver:Show()
end

driver:SetScript("OnUpdate", function(self)
  if not running then self:Hide(); return end
  if InCombatLockdown() then return end   -- pause pendant les combats
  local ok, result = coroutine.resume(running)
  if not ok then
    running = nil
    self:Hide()
    Print("|cFFFF6B6B" .. tostring(result) .. "|r")
    return
  end
  if coroutine.status(running) == "dead" then
    running = nil
    self:Hide()
    StatsDB.expBackfill = SX.EXP_BACKFILL_VERSION
    if type(result) == "table" and result.total > 0 then
      Print(string.format(L["EXP_BACKFILL_DONE_FMT"], result.found, result.total, result.estimated))
    end
    if SX.RefreshDashboard then pcall(SX.RefreshDashboard) end
  end
end)

-- Premier passage automatique, une seule fois par version de l'algorithme,
-- 20 s apres la connexion (laisse le jeu finir de charger ses donnees).
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  C_Timer.After(20, function()
    if type(StatsDB) == "table" and StatsDB.expBackfill ~= SX.EXP_BACKFILL_VERSION then
      SX.RunExpBackfill(false)
    end
  end)
end)

-- ============================================================================
-- CORRECTION MANUELLE (clic sur une cellule Extension, cf. UI.lua)
-- La valeur choisie s'applique a TOUS les evenements portant le meme nom,
-- sur tous les personnages, et remplace une estimation. exp = nil efface.
-- ============================================================================
local ASSIGN_TARGETS = {
  quests      = { { "questLog", "quest" } },
  worldQuests = { { "questLog", "quest" } },
  dungeons    = { { "mplus", "map" }, { "dungeonLog", "name" } },
  raids       = { { "raidLog", "name" } },
  delves      = { { "delveLog", "name" } },
  repGained   = { { "repLog", "faction" } },
  profGained  = { { "profLog", "profession" } },
  pvpMatches  = { { "pvpLog", "map" } },
}

-- Champ servant de nom pour une ligne affichee (donjons : M+ "map" ou "name").
function SX.AssignKeyValue(metric, row)
  local targets = ASSIGN_TARGETS[metric]
  if not (targets and row) then return nil end
  for _, t in ipairs(targets) do
    local v = row[t[2]]
    if type(v) == "string" and v ~= "" then return v end
  end
  return nil
end

function SX.AssignExpansion(metric, row, exp)
  local targets = ASSIGN_TARGETS[metric]
  local value = SX.AssignKeyValue(metric, row)
  if not (targets and value) then return 0, nil end
  local n = 0
  for _, key in ipairs(SX.GetCharKeys()) do
    local rec = StatsDB[key]
    if type(rec) == "table" and type(rec.days) == "table" then
      for _, d in pairs(rec.days) do
        for _, t in ipairs(targets) do
          for _, e in ipairs(d[t[1]] or {}) do
            if e[t[2]] == value then
              e.exp = exp
              e.expEst = nil
              n = n + 1
            end
          end
        end
      end
    end
  end
  return n, value
end
