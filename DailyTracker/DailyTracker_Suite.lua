--[[============================================================================
  DailyTracker - Intégration TibiSuite (options, recherche, habillage)
  ---------------------------------------------------------------------------
    - panneau d'Options flottant du socle (DailyTracker_OpenOptions)
    - bouton texte "Options" + champ de recherche dans l'en-tête de la fenêtre
    - recherche locale + inscription à la recherche globale de TibiSuite
      (un clic sur un résultat ouvre la faction et défile jusqu'à la quête)
    - habillage de la fenêtre à la couleur d'identité de l'addon
  C'est le SEUL fichier qui habille DTMainFrame (DailyTracker_Module.lua ne
  le fait plus : doublon retiré).
============================================================================]]

local ADDON, NS = ...
NS = NS or {}
local L = NS.L or setmetatable({}, {__index=function(_, k) return k end})

local FRAME    = "DTMainFrame"
local ACCENT   = { 0.086, 0.769, 0.988 }   -- cyan (logo #16C4FC)
local LOGO     = "Interface\\AddOns\\DailyTracker\\medias\\DailyTracker"
local KEY      = "Daily"

local function GetUI() return _G.TibiMidnight end
local function DB() return _G.DailyTrackerDB or {} end
local function Refresh() if NS.RefreshAll then NS.RefreshAll() end end

-- ---------------------------------------------------------------- Options
local panel
local function BuildOptions()
  local ui = GetUI(); if not ui then return nil end
  if panel then return panel end
  panel = ui.CreateOptionsPanel({
    name = "DailyTrackerOptionsMidnight",
    title = L.OPT_TITLE, accent = ACCENT })

  panel:Section(L.OPT_WINDOW)
  panel:Button(L.OPT_TOGGLE, function()
    if _G.DailyTracker_Toggle then _G.DailyTracker_Toggle() end
  end)
  panel:Button(L.OPT_RECENTER, function()
    local f = _G[FRAME]; if f then f:ClearAllPoints(); f:SetPoint("CENTER") end
  end)
  panel:Button(L.OPT_ALTS_OPEN, function()
    local db = _G.DailyTrackerDB; if not db then return end
    db.view = "alts"
    local f = _G[FRAME]
    if f then f:Show(); db.open = true; if f.RefreshContent then f:RefreshContent() end end
  end)

  panel:Section(L.OPT_DISPLAY)
  panel:Check(L.OPT_HIDEDONE,
    function() return DB().hideCompleted end,
    function(v) if _G.DailyTrackerDB then _G.DailyTrackerDB.hideCompleted = v end; Refresh() end)
  panel:Check(L.OPT_RENOWN,
    function() return DB().showRenown ~= false end,
    function(v) if _G.DailyTrackerDB then _G.DailyTrackerDB.showRenown = v end; Refresh() end)
  panel:Check(L.OPT_WQ,
    function() return DB().showWQ ~= false end,
    function(v) if _G.DailyTrackerDB then _G.DailyTrackerDB.showWQ = v end; Refresh() end,
    L.WQ_HINT)

  panel:Section(L.OPT_TODO)
  panel:Check(L.OPT_TODO_SHOW,
    function() return DB().todo and DB().todo.shown end,
    function(v) if NS.SetTodoShown then NS.SetTodoShown(v) end end)
  panel:Check(L.OPT_TODO_DAILY,
    function() return DB().todo and DB().todo.daily end,
    function(v)
      local db = _G.DailyTrackerDB; if not db then return end
      db.todo = db.todo or {}; db.todo.daily = v; Refresh()
    end)
  panel:Check(L.OPT_TODO_LOCK,
    function() return DB().todo and DB().todo.locked end,
    function(v)
      local db = _G.DailyTrackerDB; if not db then return end
      db.todo = db.todo or {}; db.todo.locked = v
    end)

  panel:Section(L.OPT_RARES)
  panel:Button(L.OPT_RARES_OPEN, function() if _G.DailyTracker_OpenRares then _G.DailyTracker_OpenRares() end end)
  panel:Check(L.OPT_RARE_ALERT,
    function() return DB().rareAlert ~= false end,
    function(v) if _G.DailyTrackerDB then _G.DailyTrackerDB.rareAlert = v end end)
  panel:Check(L.OPT_RARE_TOAST,
    function() return DB().rareToast ~= false end,
    function(v) if _G.DailyTrackerDB then _G.DailyTrackerDB.rareToast = v end end)

  panel:Section(L.OPT_REMIND_SECTION)
  panel:Slider(L.OPT_REMIND, 0, 48, 1,
    function() local h = tonumber(DB().remindHours); if h == nil then h = 12 end; return h end,
    function(v) if _G.DailyTrackerDB then _G.DailyTrackerDB.remindHours = v end end)
  panel:Button(L.OPT_REMIND_TEST, function() if NS.CheckReminderNow then NS.CheckReminderNow() end end)

  panel:Section(L.OPT_SUITE)
  panel:Check(L.OPT_BADGE,
    function() return DB().badge ~= false end,
    function(v) if _G.DailyTrackerDB then _G.DailyTrackerDB.badge = v end; Refresh() end)
  panel:Check(L.OPT_HIDE_OPTS,
    function() return TibiSuite and TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden(FRAME, "options") end,
    function(v) if TibiSuite and TibiSuite.SetCtrlHidden then TibiSuite.SetCtrlHidden(FRAME, "options", v) end end)
  panel:Check(L.OPT_HIDE_SEARCH,
    function() return TibiSuite and TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden(FRAME, "search") end,
    function(v) if TibiSuite and TibiSuite.SetCtrlHidden then TibiSuite.SetCtrlHidden(FRAME, "search", v) end end)
  panel:Note(L.OPT_FLOAT_NOTE)
  panel:Note(L.OPT_TIP_NOTE)
  return panel
end

function DailyTracker_OpenOptions()
  local p = BuildOptions(); if p then p:Toggle() end
end

-- ---------------------------------------------------------------- Recherche
local function Open(extKey, facName, questName)
  if _G.DailyTracker_ShowFaction then
    _G.DailyTracker_ShowFaction(extKey, facName, questName)
  else
    local f = _G[FRAME]
    if _G.DailyTracker_Toggle and (not f or not f:IsShown()) then _G.DailyTracker_Toggle() end
  end
end

local function provider(q)
  local out, ui = {}, GetUI()
  local data = _G.DailyTrackerData
  if not ui or type(data) ~= "table" then return out end
  for extKey, ext in pairs(data) do
    if type(ext) == "table" and ext.factions then
      for _, fac in ipairs(ext.factions) do
        if fac.name and ui.Match(fac.name, q) then
          out[#out + 1] = {
            text = fac.name .. "  |cff808080" .. L.SEARCH_FACTION .. " · " .. tostring(ext.label or extKey) .. "|r",
            onClick = function() Open(extKey, fac.name) end }
        end
        for _, quest in ipairs(fac.quests or {}) do
          -- Nom des donnees OU titre du client (langue du jeu)
          local shown = (NS.DisplayName and NS.DisplayName(quest)) or quest.name
          if quest.name and (ui.Match(quest.name, q) or (shown ~= quest.name and ui.Match(shown, q))) then
            out[#out + 1] = {
              text = shown .. "  |cff808080" .. (fac.name or extKey) .. "|r",
              onClick = function() Open(extKey, fac.name, quest.name) end }
            if #out >= 60 then return out end
          end
        end
      end
    end
  end
  return out
end

local searchPopup
local function OpenSearch()
  local ui = GetUI(); if not ui then return end
  if not searchPopup then
    searchPopup = ui.CreateSearchPopup({
      name = "DailyTrackerSearchPopup",
      title = "|cFF16C4FCDailyTracker|r  " .. L.SEARCH_TITLE, accent = ACCENT, logo = LOGO, provider = provider })
  end
  searchPopup.Toggle()
end
NS.OpenSearch = OpenSearch

-- ---------------------------------------------------------- Attache & skin
local function Decorate()
  local ui = GetUI(); local f = _G[FRAME]
  if not (ui and f) then return end
  if not f._tibiSkinned then
    ui.SkinFrame(f, ACCENT)
    f._tibiSkinned = true
  end
  if f._tibiControls then return end
  ui.AddHeaderControls(f, {
    accent = ACCENT,
    onOptions = function() DailyTracker_OpenOptions() end,
    provider = provider,
  })
end

-- Inscription immediate au registre de recherche globale
-- (le provider lit les donnees a la volee ; plus fiable que PLAYER_LOGIN seul)
do local _u = GetUI(); if _u and _u.RegisterSearch then _u.RegisterSearch(KEY, "Daily", provider) end end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  local ui = GetUI()
  if ui and ui.RegisterSearch then ui.RegisterSearch(KEY, "Daily", provider) end
  C_Timer.After(1.0, Decorate)
  C_Timer.After(3.0, Decorate)  -- 2e passe si la fenetre est construite tardivement
end)

-- ================================================================
-- SONDE RARES ET BOSS MONDIAUX (7.1.5.45, feuille de route lot 7)
-- ----------------------------------------------------------------
-- Outil de diagnostic, lecture seule. /dt probe : demarre la sonde pour
-- la session (aussi relancee a la connexion tant qu'elle est active),
-- /dt probe report : resume dans la discussion, /dt probe off, /dt probe
-- clear. Tout est garde dans DailyTrackerDB.rareProbe :
--   vig    = vignettes vues (par vignetteID) : nom, atlas, type, carte,
--            rewardQuestID, PNJ, valeurs secretes ;
--   rares  = cibles rares / elites rares / boss mondiaux (par PNJ) ;
--   kills  = quetes cachees passees a « faite » apres la mort d'un rare
--            (difference de C_QuestLog.GetAllCompletedQuestIDs) ;
--   wb     = boss mondiaux verrouilles (GetSavedWorldBossInfo) ;
--   ej     = boss mondiaux du journal des aventures (instance raid de
--            l'extension) ;
--   tags   = types de quetes du monde vus sur les cartes de Midnight.
-- ================================================================
local MID_MAPS = { 2395, 2437, 2405, 2413, 2512, 2372 }
local probeFrame
local ACCENT_HEX_PROBE = "|cFF16C4FC"

local function PDB()
  DailyTrackerDB = DailyTrackerDB or {}
  local p = DailyTrackerDB.rareProbe
  if type(p) ~= "table" then p = {}; DailyTrackerDB.rareProbe = p end
  p.vig = p.vig or {}; p.rares = p.rares or {}; p.kills = p.kills or {}; p.tags = p.tags or {}
  return p
end

local function IsSecret(v) return issecretvalue and issecretvalue(v) or false end
local function Clean(v) if IsSecret(v) then return "<secret>" end return v end
local function NpcID(guid)
  if type(guid) ~= "string" or IsSecret(guid) then return nil end
  local kind, _, _, _, _, id = strsplit("-", guid)
  if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end
local function CurMap()
  local ok, m = pcall(C_Map.GetBestMapForUnit, "player")
  return ok and m or nil
end
local function Count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end

-- Vignettes de la carte courante.
local function ScanVignettes()
  if not (C_VignetteInfo and C_VignetteInfo.GetVignettes) then return end
  local p = PDB()
  local okL, list = pcall(C_VignetteInfo.GetVignettes)
  if not okL or type(list) ~= "table" then return end
  local map = CurMap()
  for _, guid in ipairs(list) do
    local ok, info = pcall(C_VignetteInfo.GetVignetteInfo, guid)
    if ok and type(info) == "table" and info.vignetteID and not IsSecret(info.vignetteID) then
      local e = p.vig[info.vignetteID]
      if not e and Count(p.vig) < 300 then
        e = { name = Clean(info.name), atlas = Clean(info.atlasName), type = Clean(info.type),
              unique = Clean(info.isUnique), onMap = Clean(info.onWorldMap), rq = Clean(info.rewardQuestID),
              npc = NpcID(info.objectGUID), guidSecret = IsSecret(info.objectGUID) or nil,
              map = map, seen = 0 }
        if map and C_VignetteInfo.GetVignettePosition then
          local okP, pos = pcall(C_VignetteInfo.GetVignettePosition, guid, map)
          if okP and pos and pos.GetXY then
            local x, y = pos:GetXY()
            if x and not IsSecret(x) then e.x, e.y = math.floor(x * 1000) / 10, math.floor(y * 1000) / 10 end
          end
        end
        if type(e.rq) == "number" then
          e.rqDone = C_QuestLog.IsQuestFlaggedCompleted(e.rq) and true or false
        end
        p.vig[info.vignetteID] = e
      end
      if e then e.seen = e.seen + 1; e.last = time(); if info.isDead and not IsSecret(info.isDead) then e.dead = true end end
    end
  end
end

-- Quetes faites : instantane, puis difference apres une mort.
local baseline, baseAt
local function Snapshot()
  if not (C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs) then return end
  local ok, ids = pcall(C_QuestLog.GetAllCompletedQuestIDs)
  if not ok or type(ids) ~= "table" then return end
  baseline, baseAt = {}, GetTime()
  for _, id in ipairs(ids) do baseline[id] = true end
end
local function DiffSince(tag, npc, name)
  if not baseline then return end
  local ok, ids = pcall(C_QuestLog.GetAllCompletedQuestIDs)
  if not ok or type(ids) ~= "table" then return end
  local new = {}
  for _, id in ipairs(ids) do if not baseline[id] then new[#new + 1] = id; baseline[id] = true end end
  if #new == 0 then return end
  local p = PDB()
  if #p.kills < 60 then
    p.kills[#p.kills + 1] = { at = time(), npc = npc, name = name, when = tag, quests = new, map = CurMap() }
  end
end

local lastRare   -- { npc, name, guid }
local function OnTarget()
  local okC, class = pcall(UnitClassification, "target")
  if not okC or IsSecret(class) then return end
  if class ~= "rare" and class ~= "rareelite" and class ~= "worldboss" then return end
  local guid = UnitGUID("target")
  local npc = NpcID(guid)
  local name = Clean(UnitName("target"))
  local p = PDB()
  local key = npc or name
  if key and not IsSecret(key) then
    local r = p.rares[key] or { name = name, class = class, map = CurMap(), seen = 0, guidSecret = IsSecret(guid) or nil }
    r.seen = r.seen + 1
    local okD, dead = pcall(UnitIsDead, "target")
    if okD and dead and not IsSecret(dead) then r.deadSeen = true end
    p.rares[key] = r
  end
  lastRare = { npc = npc, name = name }
  if not baseline or GetTime() - (baseAt or 0) > 300 then Snapshot() end
end

-- Boss mondiaux : verrous et journal des aventures.
local function ScanWorldBosses()
  local p = PDB()
  p.wb = {}
  if GetNumSavedWorldBosses then
    local okN, n = pcall(GetNumSavedWorldBosses)
    for i = 1, (okN and n or 0) do
      local ok, name, id, reset = pcall(GetSavedWorldBossInfo, i)
      if ok then p.wb[#p.wb + 1] = { name = Clean(name), id = Clean(id), reset = Clean(reset) } end
    end
  end
  p.ej = nil
  if EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex then
    pcall(function()
      local tier = EJ_GetNumTiers()
      EJ_SelectTier(tier)
      local tierName = EJ_GetTierInfo and EJ_GetTierInfo(tier)
      local out = { tier = tierName, raids = {} }
      for i = 1, 20 do
        local instID, iname = EJ_GetInstanceByIndex(i, true)
        if not instID then break end
        local r = { id = instID, name = iname, bosses = {} }
        EJ_SelectInstance(instID)
        for b = 1, 20 do
          local bname, _, encID, _, _, _, dungeonEncID = EJ_GetEncounterInfoByIndex(b, instID)
          if not bname then break end
          r.bosses[#r.bosses + 1] = { name = bname, enc = encID, dEnc = dungeonEncID }
        end
        out.raids[#out.raids + 1] = r
      end
      p.ej = out
    end)
  end
end

-- Quetes du monde des cartes de Midnight : combinaisons de types vues.
local function ScanTags()
  if not (C_TaskQuest and C_TaskQuest.GetQuestsOnMap and C_QuestLog.GetQuestTagInfo) then return end
  local p = PDB()
  for _, map in ipairs(MID_MAPS) do
    local ok, list = pcall(C_TaskQuest.GetQuestsOnMap, map)
    if ok and type(list) == "table" then
      for _, q in ipairs(list) do
        local qid = q.questID or q.questId
        if qid then
          local okT, tag = pcall(C_QuestLog.GetQuestTagInfo, qid)
          if okT and type(tag) == "table" then
            local k = tostring(tag.tagID) .. ":" .. tostring(tag.worldQuestType)
            local e = p.tags[k]
            if not e then
              local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(qid)
              e = { tagID = Clean(tag.tagID), tagName = Clean(tag.tagName), wqType = Clean(tag.worldQuestType),
                    elite = Clean(tag.isElite), quality = Clean(tag.quality), ex = qid, exTitle = Clean(title), map = map, n = 0 }
              p.tags[k] = e
            end
            -- Une quete n'est comptee qu'une fois, meme sur plusieurs scans.
            e.q = e.q or {}
            if not e.q[qid] then e.q[qid] = true; e.n = e.n + 1 end
          end
        end
      end
    end
  end
end

local function StartProbe(silent)
  local p = PDB()
  p.on = true
  if not probeFrame then
    probeFrame = CreateFrame("Frame")
    probeFrame:SetScript("OnEvent", function(_, event, unit)
      if event == "PLAYER_TARGET_CHANGED" then pcall(OnTarget)
      elseif event == "VIGNETTES_UPDATED" or event == "VIGNETTE_MINIMAP_UPDATED" then pcall(ScanVignettes)
      elseif event == "UNIT_HEALTH" and unit == "target" then
        local okD, dead = pcall(UnitIsDead, "target")
        if okD and dead and not IsSecret(dead) and lastRare and not lastRare.dying then
          lastRare.dying = true
          local r = lastRare
          C_Timer.After(3, function() pcall(DiffSince, "mort+3s", r.npc, r.name) end)
        end
      elseif event == "LOOT_CLOSED" then
        local r = lastRare
        C_Timer.After(1, function() pcall(DiffSince, "butin", r and r.npc, r and r.name) end)
      elseif event == "ZONE_CHANGED_NEW_AREA" then
        pcall(ScanVignettes); pcall(ScanTags)
      end
    end)
  end
  for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "VIGNETTES_UPDATED", "VIGNETTE_MINIMAP_UPDATED",
                       "UNIT_HEALTH", "LOOT_CLOSED", "ZONE_CHANGED_NEW_AREA" }) do
    pcall(probeFrame.RegisterEvent, probeFrame, e)
  end
  pcall(ScanVignettes); pcall(ScanWorldBosses); pcall(ScanTags); Snapshot()
  if not silent then
    print(ACCENT_HEX_PROBE .. "DailyTracker|r sonde des rares active. Cible quelques rares, tues-en un ou deux, puis tape /dt probe report.")
  end
end

local function StopProbe()
  PDB().on = nil
  if probeFrame then probeFrame:UnregisterAllEvents() end
  print(ACCENT_HEX_PROBE .. "DailyTracker|r sonde des rares arretee (donnees gardees).")
end

local function Report()
  pcall(ScanVignettes); pcall(ScanWorldBosses); pcall(ScanTags)
  local p = PDB()
  local H = ACCENT_HEX_PROBE .. "DT sonde|r "
  -- Vignettes : par atlas, avec ou sans quete de recompense.
  local atl, withRQ, rqDone, secretGuid, withNpc = {}, 0, 0, 0, 0
  for _, e in pairs(p.vig) do
    atl[tostring(e.atlas)] = (atl[tostring(e.atlas)] or 0) + 1
    if type(e.rq) == "number" and e.rq > 0 then withRQ = withRQ + 1; if e.rqDone then rqDone = rqDone + 1 end end
    if e.guidSecret then secretGuid = secretGuid + 1 end
    if e.npc then withNpc = withNpc + 1 end
  end
  local parts = {}
  for a, n in pairs(atl) do parts[#parts + 1] = a .. "=" .. n end
  print(H .. string.format("vignettes %d (PNJ lus %d, GUID secrets %d, quete de recompense %d dont %d faites)",
    Count(p.vig), withNpc, secretGuid, withRQ, rqDone))
  print(H .. "atlas : " .. table.concat(parts, ", "))
  local nr, secretR, classes = 0, 0, {}
  for _, r in pairs(p.rares) do
    nr = nr + 1
    if r.guidSecret then secretR = secretR + 1 end
    classes[r.class] = (classes[r.class] or 0) + 1
  end
  local cp = {}
  for c, n in pairs(classes) do cp[#cp + 1] = c .. "=" .. n end
  print(H .. string.format("rares cibles %d (GUID secrets %d) %s", nr, secretR, table.concat(cp, ", ")))
  for i = math.max(1, #p.kills - 2), #p.kills do
    local k = p.kills[i]
    if k then
      local q = {}
      for j = 1, math.min(6, #k.quests) do q[#q + 1] = k.quests[j] end
      print(H .. string.format("mort %s (%s, %s) -> quetes %s", tostring(k.name), tostring(k.npc), k.when, table.concat(q, " ")))
    end
  end
  if #p.kills == 0 then print(H .. "aucune quete cachee relevee apres une mort pour l'instant") end
  local wb = {}
  for _, w in ipairs(p.wb or {}) do wb[#wb + 1] = tostring(w.name) .. "#" .. tostring(w.id) end
  print(H .. "boss mondiaux verrouilles : " .. (#wb > 0 and table.concat(wb, ", ") or "aucun"))
  if p.ej then
    local rr = {}
    for _, r in ipairs(p.ej.raids) do rr[#rr + 1] = tostring(r.name) .. "(" .. #r.bosses .. ")" end
    print(H .. "journal " .. tostring(p.ej.tier) .. " : " .. table.concat(rr, ", "))
  else
    print(H .. "journal des aventures illisible")
  end
  local tp = {}
  for _, t in pairs(p.tags) do tp[#tp + 1] = string.format("%s/%s/%s x%d", tostring(t.tagID), tostring(t.tagName), tostring(t.wqType), t.n) end
  print(H .. "types de quetes du monde : " .. (#tp > 0 and table.concat(tp, " ; ") or "aucun"))
end

function DailyTracker_RareProbe(arg)
  arg = (arg or ""):lower()
  if arg == "report" or arg == "rapport" then Report()
  elseif arg == "off" or arg == "stop" then StopProbe()
  elseif arg == "clear" then DailyTrackerDB.rareProbe = nil; print(ACCENT_HEX_PROBE .. "DailyTracker|r donnees de la sonde effacees.")
  else StartProbe() end
end

-- Relance silencieuse a la connexion tant que la sonde est active.
local probeLogin = CreateFrame("Frame")
probeLogin:RegisterEvent("PLAYER_LOGIN")
probeLogin:SetScript("OnEvent", function()
  C_Timer.After(5, function()
    if type(DailyTrackerDB) == "table" and type(DailyTrackerDB.rareProbe) == "table" and DailyTrackerDB.rareProbe.on then
      StartProbe(true)
    end
  end)
end)
