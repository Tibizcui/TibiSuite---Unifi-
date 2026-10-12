-- ================================================================
-- DailyTracker - Rares et boss mondiaux (7.1.5.45, feuille de route lot 7)
-- ----------------------------------------------------------------
-- Moteur, lecture seule. Constats de la sonde (2026-10-11) :
--   * vignettes de la minicarte lisibles (nom, atlas, PNJ, position),
--     sans quete de recompense : l'icone ne dit pas si le rare est tue ;
--   * tuer un rare passe une ou deux quetes cachees a « faite » (difference
--     de C_QuestLog.GetAllCompletedQuestIDs) : on les apprend ;
--   * boss mondial de la semaine = quete du monde de type 289 (« Boss hors
--     instance », worldQuestType 18) sur les cartes de Midnight ;
--   * journal des aventures : instance raid au nom de l'extension.
-- Donnees :
--   DailyTrackerDB.rares[npcID] = { name, map, x, y, q = { [questID] =
--     true | "rep" }, kills, learned }   ("rep" = vue redevenir a faire
--     apres un reset : quete repetable, seule a compter des qu'on la connait)
--   DailyTrackerDB.wb = { week, q = { [questID] = { title, map, ends } } }
--   DailyTrackerDB.chars[perso].rareQ = { [questID] = true }  (vu fait)
--   DailyTrackerDB.chars[perso].wb    = { week, done = { [questID] = true } }
-- Reglages : rareAlert (nil = actif), rareToast (nil = actif).
-- API : NS.Rares.* (vue Rares de DailyTracker.lua, apercu, personnages).
-- ================================================================
local ADDON, NS = ...
NS = NS or {}
local L = NS.L or setmetatable({}, { __index = function(_, k) return k end })
local R = {}
NS.Rares = R

local MID_MAPS = { 2395, 2437, 2405, 2413, 2512, 2372 }
local WB_TAG, WB_TYPE = 289, 18
local HEX = "|cFF16C4FC"

local function IsSecret(v) return issecretvalue and issecretvalue(v) or false end
local function NpcID(guid)
  if type(guid) ~= "string" or IsSecret(guid) then return nil end
  local kind, _, _, _, _, id = strsplit("-", guid)
  if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end
local function Done(q)
  local ok, v = pcall(C_QuestLog.IsQuestFlaggedCompleted, q)
  return ok and v and true or false
end
local function CurMap()
  local ok, m = pcall(C_Map.GetBestMapForUnit, "player")
  return ok and m or nil
end
local function MapName(map)
  local ok, info = pcall(C_Map.GetMapInfo, map)
  return ok and type(info) == "table" and info.name or ("#" .. tostring(map))
end
local function DB()
  DailyTrackerDB = DailyTrackerDB or {}
  local d = DailyTrackerDB
  if type(d.rares) ~= "table" then d.rares = {} end
  return d
end
local function MyKey()
  local name = UnitName and UnitName("player")
  if not name or name == "" or name == UNKNOWNOBJECT then return nil end
  return name .. "-" .. ((GetRealmName and GetRealmName()) or "?")
end
local function CharRec()
  local k = MyKey(); if not k then return nil end
  local db = DB()
  db.chars = db.chars or {}
  local c = db.chars[k]
  if not c then c = {}; db.chars[k] = c end
  return c
end
local function WeekStamp()
  local ok, s = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
  if not ok or type(s) ~= "number" then return nil end
  return math.floor((time() + s) / 3600)
end
local function Notify(text, toast)
  local TS = _G.TibiSuite
  if TS and TS.Notify then TS.Notify("Daily", text, { toast = toast and true or false })
  else print(HEX .. "DailyTracker|r " .. text) end
end
local function RequestRefresh()
  local db = DB()
  if db.view == "rares" and NS.RequestRefresh then NS.RequestRefresh() end
end

-- ----------------------------------------------------------------
-- Etat d'un rare appris
-- ----------------------------------------------------------------
-- Renvoie true (tue), false (disponible) ou nil (aucune quete connue).
-- Des qu'une quete repetable est connue, seules les repetables comptent :
-- une quete unique (premier kill, haut fait) resterait faite pour toujours.
function R.IsKilled(r)
  if type(r) ~= "table" or type(r.q) ~= "table" or not next(r.q) then return nil end
  local rep = false
  for _, k in pairs(r.q) do if k == "rep" then rep = true break end end
  for qid, k in pairs(r.q) do
    if (not rep or k == "rep") and Done(qid) then return true end
  end
  return false
end
-- Le type de reset est-il connu (au moins une quete repetable) ?
function R.IsSure(r)
  for _, k in pairs(r.q or {}) do if k == "rep" then return true end end
  return false
end

-- Une quete deja vue faite par ce personnage et redevenue a faire est
-- repetable (reset quotidien ou hebdo passe).
function R.CheckRepeat()
  local c = CharRec(); if not c then return end
  c.rareQ = c.rareQ or {}
  for _, r in pairs(DB().rares) do
    for qid in pairs(r.q or {}) do
      if Done(qid) then c.rareQ[qid] = true
      elseif c.rareQ[qid] then c.rareQ[qid] = nil; r.q[qid] = "rep" end
    end
  end
end

-- ----------------------------------------------------------------
-- Apprentissage : quetes passees a « faite » apres la mort d'un rare
-- ----------------------------------------------------------------
local baseline, baseAt, lastRare
local function Snapshot()
  local ok, ids = pcall(C_QuestLog.GetAllCompletedQuestIDs)
  if not ok or type(ids) ~= "table" then return end
  baseline, baseAt = {}, GetTime()
  for _, id in ipairs(ids) do baseline[id] = true end
end

local function Learn(rare)
  if not (baseline and rare and rare.npc) then return end
  local ok, ids = pcall(C_QuestLog.GetAllCompletedQuestIDs)
  if not ok or type(ids) ~= "table" then return end
  local new = {}
  for _, id in ipairs(ids) do
    if not baseline[id] then new[#new + 1] = id; baseline[id] = true end
  end
  -- Plus de 6 quetes d'un coup : autre chose s'est termine en meme temps
  -- (rendu de quete, evenement), on n'attribue rien plutot que du bruit.
  if #new == 0 or #new > 6 then return end
  local db = DB()
  local r = db.rares[rare.npc]
  local isNew = not r
  if isNew then r = { name = rare.name, q = {}, kills = 0, learned = time() }; db.rares[rare.npc] = r end
  r.name = rare.name or r.name
  r.map = r.map or rare.map
  if not r.x and rare.x then r.x, r.y = rare.x, rare.y end
  local c = CharRec()
  if c then c.rareQ = c.rareQ or {} end
  for _, q in ipairs(new) do
    r.q[q] = r.q[q] or true
    if c then c.rareQ[q] = true end
  end
  r.kills = (r.kills or 0) + 1
  r.last = time()
  if isNew then Notify(string.format(L.RARES_LEARNED_FMT, tostring(r.name)), false) end
  RequestRefresh()
end

local function OnTarget()
  local okC, class = pcall(UnitClassification, "target")
  if not okC or IsSecret(class) or (class ~= "rare" and class ~= "rareelite") then return end
  local npc = NpcID(UnitGUID("target"))
  if not npc then return end
  local name = UnitName("target")
  if IsSecret(name) then name = nil end
  if lastRare and lastRare.npc == npc then return end
  local map = CurMap()
  local x, y
  if map and C_Map.GetPlayerMapPosition then
    local okP, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
    if okP and pos and pos.GetXY then
      local px, py = pos:GetXY()
      if px and not IsSecret(px) then x, y = math.floor(px * 1000) / 10, math.floor(py * 1000) / 10 end
    end
  end
  lastRare = { npc = npc, name = name, map = map, x = x, y = y }
  if not baseline or GetTime() - (baseAt or 0) > 300 then Snapshot() end
end

local function OnTargetHealth()
  if not lastRare or lastRare.deadAt then return end
  local okD, dead = pcall(UnitIsDead, "target")
  if not okD or IsSecret(dead) or not dead then return end
  if NpcID(UnitGUID("target")) ~= lastRare.npc then return end
  lastRare.deadAt = GetTime()
  local r = lastRare
  C_Timer.After(3, function() pcall(Learn, r) end)
end

local function OnLootClosed()
  local r = lastRare
  if r and r.deadAt and GetTime() - r.deadAt < 60 then
    C_Timer.After(1, function() pcall(Learn, r) end)
  end
end

-- Oublie un rare appris (Maj + clic droit dans la vue).
function R.Forget(npc)
  DB().rares[npc] = nil
  RequestRefresh()
end

-- ----------------------------------------------------------------
-- Vignettes : rares presents sur la minicarte
-- ----------------------------------------------------------------
local visible = {}
local alerted = {}
function R.ScanVignettes()
  local out = {}
  if not (C_VignetteInfo and C_VignetteInfo.GetVignettes) then visible = out; return end
  local okL, list = pcall(C_VignetteInfo.GetVignettes)
  if not okL or type(list) ~= "table" then visible = out; return end
  local map = CurMap()
  local db = DB()
  for _, guid in ipairs(list) do
    local ok, info = pcall(C_VignetteInfo.GetVignetteInfo, guid)
    local atlas = ok and type(info) == "table" and info.atlasName
    if type(atlas) == "string" and not IsSecret(atlas) and atlas:find("VignetteKill") then
      local npc = NpcID(info.objectGUID)
      local name = info.name
      if IsSecret(name) then name = nil end
      local e = { npc = npc, name = name, map = map }
      if map and C_VignetteInfo.GetVignettePosition then
        local okP, pos = pcall(C_VignetteInfo.GetVignettePosition, guid, map)
        if okP and pos and pos.GetXY then
          local x, y = pos:GetXY()
          if x and not IsSecret(x) then e.x, e.y = math.floor(x * 1000) / 10, math.floor(y * 1000) / 10 end
        end
      end
      local r = npc and db.rares[npc]
      if r then
        -- La vignette donne une position plus juste que celle du joueur.
        if e.x then r.x, r.y, r.map = e.x, e.y, map end
        e.killed = R.IsKilled(r)
        e.learned = true
        if e.killed == false and db.rareAlert ~= false and GetTime() - (alerted[npc] or -1e9) > 600 then
          alerted[npc] = GetTime()
          Notify(string.format(L.RARES_SPAWN_FMT, tostring(name or r.name)), db.rareToast ~= false)
        end
      end
      out[#out + 1] = e
    end
  end
  visible = out
end
function R.GetVisible() return visible end

-- ----------------------------------------------------------------
-- Boss mondiaux
-- ----------------------------------------------------------------
function R.ScanBosses()
  local db = DB()
  local wk = WeekStamp()
  if not wk then return end
  if type(db.wb) ~= "table" or db.wb.week ~= wk then db.wb = { week = wk, q = {} } end
  if C_TaskQuest and C_TaskQuest.GetQuestsOnMap and C_QuestLog.GetQuestTagInfo then
    for _, map in ipairs(MID_MAPS) do
      local ok, list = pcall(C_TaskQuest.GetQuestsOnMap, map)
      if ok and type(list) == "table" then
        for _, q in ipairs(list) do
          local qid = q.questID or q.questId
          local okT, tag
          if qid then okT, tag = pcall(C_QuestLog.GetQuestTagInfo, qid) end
          if okT and type(tag) == "table" and (tag.tagID == WB_TAG or tag.worldQuestType == WB_TYPE) then
            local e = db.wb.q[qid] or { map = map }
            local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(qid)
            if type(title) == "string" and title ~= "" and not IsSecret(title) then e.title = title end
            local okS, left = pcall(C_TaskQuest.GetQuestTimeLeftSeconds, qid)
            if okS and type(left) == "number" and left > 0 then e.ends = time() + left end
            db.wb.q[qid] = e
          end
        end
      end
    end
  end
  -- Etat du personnage : quete faite, ou boss verrouille du meme nom.
  local c = CharRec(); if not c then return end
  local saved = {}
  if GetNumSavedWorldBosses then
    local okN, n = pcall(GetNumSavedWorldBosses)
    for i = 1, (okN and n or 0) do
      local okI, name = pcall(GetSavedWorldBossInfo, i)
      if okI and type(name) == "string" then saved[name] = true end
    end
  end
  if type(c.wb) ~= "table" or c.wb.week ~= wk then c.wb = { week = wk, done = {} } end
  for qid, e in pairs(db.wb.q) do
    if Done(qid) or (e.title and saved[e.title]) then c.wb.done[qid] = true end
  end
end

-- Le type de quete 289 couvre les boss mondiaux ET les Repaires (constat en
-- jeu 2026-10-12 : « Repaire : Nymrissa Mande-vagues »). Boss mondial = titre
-- qui contient un nom de boss du journal ; sinon Repaire. nil = journal
-- illisible, impossible de trancher (tout reste « boss »).
local function Norm(s) return (tostring(s or ""):lower():gsub("\226\128\153", "'")) end
function R.KindOf(title)
  local ej = R.EJBosses()
  if type(ej) ~= "table" or #ej == 0 then return nil end
  local t = Norm(title)
  for _, n in ipairs(ej) do
    if t:find(Norm(n), 1, true) then return "wb" end
  end
  return "lair"
end

-- { { qid, title, zone, map, ends, done, kind } } pour le personnage connecte.
function R.GetBosses()
  local db, c = DB(), CharRec()
  local wk = WeekStamp()
  local out = {}
  if type(db.wb) ~= "table" or db.wb.week ~= wk then return out end
  local done = (c and type(c.wb) == "table" and c.wb.week == wk and c.wb.done) or {}
  for qid, e in pairs(db.wb.q) do
    out[#out + 1] = { qid = qid, title = e.title or ("#" .. qid), zone = MapName(e.map), map = e.map,
                      ends = e.ends, done = done[qid] or Done(qid), kind = e.title and R.KindOf(e.title) or nil }
  end
  table.sort(out, function(a, b) return a.title < b.title end)
  return out
end

-- Boss faits / connus pour un personnage enregistre (vue Personnages).
function R.CharBosses(c)
  local db, wk = DB(), WeekStamp()
  if type(db.wb) ~= "table" or db.wb.week ~= wk then return 0, 0 end
  local total, d = 0, 0
  local cd = (type(c) == "table" and type(c.wb) == "table" and c.wb.week == wk and c.wb.done) or {}
  for qid, e in pairs(db.wb.q) do
    if not (e.title and R.KindOf(e.title) == "lair") then
      total = total + 1
      if cd[qid] then d = d + 1 end
    end
  end
  return d, total
end

-- Boss mondiaux de l'extension lus dans le journal des aventures (instance
-- raid au nom de l'extension). Lu une fois par session, jamais quand le
-- journal est ouvert (on lui rend son palier d'origine).
local ejCache
function R.EJBosses()
  if ejCache then return ejCache end
  if not (EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex and EJ_GetEncounterInfoByIndex) then return nil end
  if EncounterJournal and EncounterJournal.IsShown and EncounterJournal:IsShown() then return nil end
  local wanted = {}
  local lvl = LE_EXPANSION_LEVEL_CURRENT
  if lvl and _G["EXPANSION_NAME" .. lvl] then wanted[_G["EXPANSION_NAME" .. lvl]] = true end
  wanted["Midnight"] = true
  local out
  pcall(function()
    local before = EJ_GetCurrentTier and EJ_GetCurrentTier()
    EJ_SelectTier(EJ_GetNumTiers())
    for i = 1, 20 do
      local instID, iname = EJ_GetInstanceByIndex(i, true)
      if not instID then break end
      if wanted[iname] then
        out = {}
        for b = 1, 12 do
          local bname = EJ_GetEncounterInfoByIndex(b, instID)
          if not bname then break end
          out[#out + 1] = bname
        end
        break
      end
    end
    if before then EJ_SelectTier(before) end
  end)
  ejCache = out or {}
  return ejCache
end

-- ----------------------------------------------------------------
-- Rares appris, ranges par zone
-- ----------------------------------------------------------------
function R.GetLearned()
  local groups, byMap = {}, {}
  for npc, r in pairs(DB().rares) do
    local key = r.map or 0
    local g = byMap[key]
    if not g then g = { map = r.map, zone = r.map and MapName(r.map) or "?", list = {} }; byMap[key] = g; groups[#groups + 1] = g end
    g.list[#g.list + 1] = { npc = npc, r = r, killed = R.IsKilled(r), sure = R.IsSure(r) }
  end
  local cur = CurMap()
  table.sort(groups, function(a, b)
    if (a.map == cur) ~= (b.map == cur) then return a.map == cur end
    return a.zone < b.zone
  end)
  for _, g in ipairs(groups) do
    table.sort(g.list, function(a, b)
      if (a.killed == false) ~= (b.killed == false) then return a.killed == false end
      return tostring(a.r.name) < tostring(b.r.name)
    end)
  end
  return groups
end

-- Resume pour l'apercu : boss faits / total, rares appris disponibles / total.
function R.Summary()
  local bd, bt = 0, 0
  for _, b in ipairs(R.GetBosses()) do
    if b.kind ~= "lair" then bt = bt + 1; if b.done then bd = bd + 1 end end
  end
  local known, avail = 0, 0
  for _, r in pairs(DB().rares) do
    known = known + 1
    if R.IsKilled(r) == false then avail = avail + 1 end
  end
  return { bossDone = bd, bossTotal = bt, known = known, avail = avail }
end

-- ----------------------------------------------------------------
-- Evenements
-- ----------------------------------------------------------------
local ev = CreateFrame("Frame")
local vigPending = false
ev:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_TARGET_CHANGED" then pcall(OnTarget)
  elseif event == "UNIT_HEALTH" then pcall(OnTargetHealth)
  elseif event == "LOOT_CLOSED" then pcall(OnLootClosed)
  elseif event == "VIGNETTES_UPDATED" or event == "VIGNETTE_MINIMAP_UPDATED" then
    if vigPending then return end
    vigPending = true
    C_Timer.After(0.5, function()
      vigPending = false
      pcall(R.ScanVignettes)
      RequestRefresh()
    end)
  elseif event == "ZONE_CHANGED_NEW_AREA" then
    pcall(R.ScanVignettes); pcall(R.ScanBosses); RequestRefresh()
  elseif event == "QUEST_TURNED_IN" then
    C_Timer.After(2, function() pcall(R.ScanBosses); RequestRefresh() end)
  elseif event == "PLAYER_LOGIN" then
    C_Timer.After(4, function()
      pcall(R.CheckRepeat); pcall(R.ScanBosses); pcall(R.ScanVignettes)
    end)
  end
end)
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_TARGET_CHANGED", "LOOT_CLOSED", "VIGNETTES_UPDATED",
                     "VIGNETTE_MINIMAP_UPDATED", "ZONE_CHANGED_NEW_AREA", "QUEST_TURNED_IN" }) do
  pcall(ev.RegisterEvent, ev, e)
end
if ev.RegisterUnitEvent then pcall(ev.RegisterUnitEvent, ev, "UNIT_HEALTH", "target")
else pcall(ev.RegisterEvent, ev, "UNIT_HEALTH") end
