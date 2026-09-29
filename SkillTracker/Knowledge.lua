-- ================================================================
--  SkillTracker  -  Knowledge.lua
--  Connaissances de metier : liste de la semaine par personnage et par
--  metier principal, arbres de specialisation, outils de verification.
--
--  HONNETETE DES DONNEES :
--  - Foire de Sombrelune : questID historiques (29506...29520), stables
--    depuis Cataclysm, verifiables en jeu par /skt check. Detection auto.
--  - Quete hebdo, traite, butins hebdo de Midnight : AUCUN questID n'est
--    code ici tant qu'il n'a pas ete releve en jeu (les ID TWW de
--    DailyTracker etaient tous faux). Ces sources sont cochees a la main,
--    par personnage, et se decochent seules au reset hebdo. Pour relever un
--    ID : /skt mark, faire l'action (lire le traite...), puis /skt diff.
--    Les ID releves se placent dans ST.KNOW_IDS ci-dessous : la source
--    devient alors automatique.
-- ================================================================

local _, ST = ...
local L = ST.L

-- Metiers principaux (skillLine parent du grimoire).
local ALCH, BS, ENCH, ENG, HERB, INSC, JC, LW, MINE, SKIN, TAIL =
  171, 164, 333, 202, 182, 773, 755, 165, 186, 393, 197

-- Quetes de metier de la Foire de Sombrelune (mensuelles).
ST.DMF_QUESTS = {
  [ALCH] = 29506, [BS] = 29508, [ENCH] = 29510, [ENG] = 29511, [HERB] = 29514,
  [INSC] = 29515, [JC] = 29516, [LW] = 29517, [MINE] = 29518, [SKIN] = 29519,
  [TAIL] = 29520,
}

-- questID releves en jeu pour les sources hebdo de l'extension en cours.
-- Forme : ST.KNOW_IDS[parent] = { quest = { id, ... }, treatise = { id }, drops = { id, ... } }
-- Une source est "faite" des qu'UN de ses ID est valide cette semaine
-- (sauf drops : faite quand TOUS ses ID le sont). Vide = suivi manuel.
ST.KNOW_IDS = {}

-- Sources de la semaine, dans l'ordre d'affichage.
ST.KNOW_SOURCES = {
  { key = "quest",    reset = "weekly"  },
  { key = "treatise", reset = "weekly"  },
  { key = "drops",    reset = "weekly"  },
  { key = "dmf",      reset = "monthly" },
}

-- ================================================================
-- CALENDRIER : debut de la semaine en cours, Foire active ou non
-- ================================================================
function ST.WeekStart(now)
  now = now or time()
  local left = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
    and C_DateAndTime.GetSecondsUntilWeeklyReset()
  if type(left) ~= "number" then return now - 7 * 86400 end
  return now + left - 7 * 86400
end

-- La Foire ouvre le premier dimanche du mois, pour 7 jours. Renvoie
-- (active, debutEpoch) calcule sur la date du calendrier du jeu.
function ST.DarkmoonState()
  if not (C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime) then return false, nil end
  local ok, d = pcall(C_DateAndTime.GetCurrentCalendarTime)
  if not ok or type(d) ~= "table" or not d.monthDay or not d.weekday then return false, nil end
  -- weekday : 1 = dimanche. Jour de semaine du 1er du mois, puis 1er dimanche.
  local wd1 = ((d.weekday - 1 - (d.monthDay - 1)) % 7) + 1
  local firstSunday = 1 + ((1 - wd1) % 7)
  local active = d.monthDay >= firstSunday and d.monthDay <= firstSunday + 6
  local startT = time({ year = d.year, month = d.month, day = firstSunday, hour = 0, min = 0, sec = 0 })
  return active, startT
end

local function Flagged(id)
  return C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
    and C_QuestLog.IsQuestFlaggedCompleted(id) and true or false
end

local function SourceIDs(parent, key)
  if key == "dmf" then
    local id = ST.DMF_QUESTS[parent]
    return id and { id } or nil
  end
  local t = ST.KNOW_IDS[parent]
  local ids = t and t[key]
  if type(ids) == "table" and #ids > 0 then return ids end
  return nil
end
ST.SourceIDs = SourceIDs

-- Met a jour, pour le perso connecte, l'etat des sources a questID connus
-- (stocke avec la date : les alts restent lisibles une fois deconnectes).
function ST.UpdateWeeklyAuto(char)
  char = char or ST.CurrentRec()
  if not char then return end
  char.weekly = char.weekly or {}
  local now = time()
  for parent, prof in pairs(char.professions or {}) do
    if prof.isPrimary then
      for _, src in ipairs(ST.KNOW_SOURCES) do
        local ids = SourceIDs(parent, src.key)
        if ids then
          local done
          if src.key == "drops" then
            done = true
            for _, id in ipairs(ids) do if not Flagged(id) then done = false break end end
          else
            done = false
            for _, id in ipairs(ids) do if Flagged(id) then done = true break end end
          end
          char.weekly[parent] = char.weekly[parent] or {}
          local w = char.weekly[parent]
          if done then
            -- On garde la date d'origine tant que la case reste valide.
            local prev = w[src.key]
            if not (type(prev) == "table" and prev.auto) then w[src.key] = { t = now, auto = true } end
          elseif type(w[src.key]) == "table" and w[src.key].auto then
            w[src.key] = nil
          end
        end
      end
    end
  end
end

-- Etat d'une source pour un perso : "done", "todo" ou "closed" (Foire fermee).
function ST.WeeklyState(rec, parent, key, now)
  now = now or time()
  local w = rec and rec.weekly and rec.weekly[parent]
  local entry = w and w[key]
  local t = type(entry) == "table" and entry.t or nil
  if key == "dmf" then
    local active, startT = ST.DarkmoonState()
    if not active then return "closed" end
    if t and startT and t >= startT then return "done" end
    return "todo"
  end
  if t and t >= ST.WeekStart(now) then return "done" end
  return "todo"
end

-- (faites, total) pour un metier d'un perso ; la Foire fermee ne compte pas.
function ST.WeeklyCount(rec, parent)
  local done, total = 0, 0
  local now = time()
  for _, src in ipairs(ST.KNOW_SOURCES) do
    local st = ST.WeeklyState(rec, parent, src.key, now)
    if st ~= "closed" then
      total = total + 1
      if st == "done" then done = done + 1 end
    end
  end
  return done, total
end

-- Bascule manuelle d'une source (sources sans questID, ou correction).
function ST.ToggleWeekly(rec, parent, key)
  if not rec then return end
  rec.weekly = rec.weekly or {}
  rec.weekly[parent] = rec.weekly[parent] or {}
  local w = rec.weekly[parent]
  if ST.WeeklyState(rec, parent, key) == "done" then
    w[key] = nil
  else
    w[key] = { t = time(), manual = true }
  end
end

-- ================================================================
-- ARBRES DE SPECIALISATION : rangs achetes / rangs possibles
-- Chaine d'API en pcall : un maillon absent => nil, jamais d'erreur.
-- ================================================================
function ST.ReadSpecTree(skillLineID)
  if not (C_ProfSpecs and C_Traits and C_ProfSpecs.GetConfigIDForSkillLine
          and C_ProfSpecs.GetSpecTabIDsForSkillLine and C_Traits.GetTreeNodes
          and C_Traits.GetNodeInfo) then
    return nil
  end
  local ok, spent, max = pcall(function()
    local configID = C_ProfSpecs.GetConfigIDForSkillLine(skillLineID)
    if not configID or configID == 0 then return nil end
    local tabs = C_ProfSpecs.GetSpecTabIDsForSkillLine(skillLineID)
    if type(tabs) ~= "table" or #tabs == 0 then return nil end
    local s, m = 0, 0
    for _, treeID in ipairs(tabs) do
      for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
        local ni = C_Traits.GetNodeInfo(configID, nodeID)
        if ni and (ni.maxRanks or 0) > 0 then
          s = s + (ni.ranksPurchased or ni.currentRank or 0)
          m = m + ni.maxRanks
        end
      end
    end
    if m <= 0 then return nil end
    return s, m
  end)
  if ok and spent then return spent, max end
  return nil
end

-- ================================================================
-- /skt check : verifie tous les questID connus (titre renvoye par le serveur)
-- ================================================================
local checkIDs, loadResult, checkRunning = {}, {}, false

local function Title(id)
  return C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id) or nil
end

function ST.OnQuestDataLoad(id, success)
  if id and checkIDs[id] then loadResult[id] = success and true or false end
end

local function ProfName(parent)
  local rec = ST.CurrentRec()
  local prof = rec and rec.professions and rec.professions[parent]
  if prof and prof.name then return prof.name end
  local info = C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID
    and C_TradeSkillUI.GetProfessionInfoBySkillLineID(parent)
  return (info and info.professionName ~= "" and info.professionName) or tostring(parent)
end

function ST.RunQuestCheck()
  if checkRunning then return end
  checkRunning = true
  wipe(checkIDs)
  local rows = {}
  for parent, id in pairs(ST.DMF_QUESTS) do
    checkIDs[id] = true
    rows[#rows + 1] = { parent = parent, key = "dmf", id = id }
  end
  for parent, t in pairs(ST.KNOW_IDS) do
    for key, ids in pairs(t) do
      for _, id in ipairs(ids) do
        checkIDs[id] = true
        rows[#rows + 1] = { parent = parent, key = key, id = id }
      end
    end
  end
  table.sort(rows, function(a, b)
    if a.parent ~= b.parent then return a.parent < b.parent end
    return a.id < b.id
  end)
  print(ST.TAG .. " " .. L.CHECK_HEADER)
  print("  |cFF888888" .. L.CHECK_WAIT .. "|r")
  for id in pairs(checkIDs) do
    if not Title(id) and C_QuestLog and C_QuestLog.RequestLoadQuestByID then
      pcall(C_QuestLog.RequestLoadQuestByID, id)
    end
  end

  local tries = 0
  local function Report()
    checkRunning = false
    local nOK, nBad, nWait = 0, 0, 0
    for _, r in ipairs(rows) do
      local title = Title(r.id)
      local head = string.format("[%d] %s / %s", r.id, ProfName(r.parent), L["SRC_" .. r.key:upper()])
      if title and title ~= "" then
        nOK = nOK + 1
        print("  |cFF44CC44" .. L.CHECK_OK .. "|r " .. head .. " -> " .. title
          .. (Flagged(r.id) and ("  |cFF888888(" .. L.WEEK_DONE .. ")|r") or ""))
      elseif loadResult[r.id] == false then
        nBad = nBad + 1
        print("  |cFFFF5555" .. L.CHECK_INVALID .. "|r " .. head)
      else
        nWait = nWait + 1
        print("  |cFFFFAA33" .. L.CHECK_NORESP .. "|r " .. head)
      end
    end
    print(ST.TAG .. " " .. string.format(L.CHECK_SUMMARY, nOK, nBad, nWait))
  end
  local function Poll()
    tries = tries + 1
    local pending = false
    for id in pairs(checkIDs) do
      if loadResult[id] == nil and not Title(id) then pending = true break end
    end
    if pending and tries < 6 then C_Timer.After(1, Poll) else Report() end
  end
  C_Timer.After(1, Poll)
end

-- ================================================================
-- /skt mark puis /skt diff : releve des questID caches qui viennent de
-- passer a "fait" (lire un traite, rendre la quete hebdo...). Sert a
-- completer ST.KNOW_IDS sans rien deviner.
-- ================================================================
local marked

local function CompletedSet()
  if not (C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs) then return nil end
  local ok, list = pcall(C_QuestLog.GetAllCompletedQuestIDs)
  if not ok or type(list) ~= "table" then return nil end
  local set = {}
  for _, id in ipairs(list) do set[id] = true end
  return set
end

function ST.QuestMark()
  marked = CompletedSet()
  if not marked then print(ST.TAG .. " " .. L.DIFF_NOAPI) return end
  print(ST.TAG .. " " .. L.DIFF_MARKED)
end

function ST.QuestDiff()
  if not marked then print(ST.TAG .. " " .. L.DIFF_NOMARK) return end
  local now = CompletedSet()
  if not now then print(ST.TAG .. " " .. L.DIFF_NOAPI) return end
  local new = {}
  for id in pairs(now) do if not marked[id] then new[#new + 1] = id end end
  table.sort(new)
  if #new == 0 then print(ST.TAG .. " " .. L.DIFF_NONE) return end
  for _, id in ipairs(new) do
    if not Title(id) and C_QuestLog.RequestLoadQuestByID then pcall(C_QuestLog.RequestLoadQuestByID, id) end
  end
  C_Timer.After(1.5, function()
    print(ST.TAG .. " " .. string.format(L.DIFF_HEADER, #new))
    for _, id in ipairs(new) do
      print(string.format("  |cFFFFD700%d|r  %s", id, Title(id) or ("|cFF888888" .. L.DIFF_HIDDEN .. "|r")))
    end
  end)
end
