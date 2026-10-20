--[[============================================================================
  TibiSuiteGroup.lua  -  Partage en groupe (7.3, lot C)
  ---------------------------------------------------------------------------
  Entre joueurs de la suite d'un meme groupe : qui est deja sauvegarde sur
  quel boss de l'instance, qui farme quel legendaire, qui n'a pas encore
  quelle monture de cette instance.

  DESACTIVE PAR DEFAUT : TibiSuiteDB.groupShare = true pour l'activer (case de
  la fenetre Groupe, SET_KEYS). Coupe = rien n'est envoye NI ecoute.

  Protocole (prefixe TibiSuiteG, 255 octets au plus par message) :
    G1:L:<instanceMapID>,<difficultyID>,<bits>   boss tues de l'instance
                                                  courante (1 = tue, ordre
                                                  du jeu)
    G1:P:<itemID>                                 legendaire epingle (LegTracker)
    G1:M:<instanceMapID>,<id>.<id>...             montures manquantes ici
                                                  (DgnTracker, 25 au plus)
    G1:Q                                          demande : « envoyez vos infos »
    G1:X                                          plus rien a partager (reset)
  Envoi : a l'entree en instance, a l'arrivee dans un groupe (avec une
  demande Q), en reponse a Q (30 s au plus une fois), apres un boss tue.
  Regle du verrouillage (sonde du 2026-10-20 : code 11 pendant une
  rencontre) : rien ne part tant que C_ChatInfo.InChatMessagingLockdown()
  est vrai ou en combat. Les messages attendent dans une file (un seul par
  type, le plus recent), videe a la fin de la rencontre / du combat, un
  message toutes les 1,5 s.
  Reception : en memoire seulement (rien n'est sauvegarde sur les autres),
  oubliee quand le joueur quitte le groupe.
  API : TibiSuite.GroupShareOn(), SetGroupShare(on), GetGroupPeers(),
        ShowGroupWindow(), ToggleGroupWindow(), OnGroupChanged(fn).
  Slash : /ts groupe. NON TESTE EN JEU (nouveau fichier : redemarrage complet).
============================================================================]]

local L = TibiSuiteL or {}
TibiSuiteL = L
local function D(k, v) if L[k] == nil then L[k] = v end end
D("GRP_TITLE",       "Groupe")
D("GRP_SUB_OFF",     "Partage coupé : rien n'est envoyé ni reçu.")
D("GRP_SUB_ON",      "Visible seulement par les joueurs de ton groupe qui ont TibiSuite.")
D("GRP_SHARE",       "Partager mes infos avec le groupe")
D("GRP_NOGROUP",     "Tu n'es pas en groupe.")
D("GRP_NOPEER",      "Personne dans le groupe n'a encore partagé ses infos (TibiSuite 7.3 et partage activé).")
D("GRP_PENDING",     "Envoi en attente : fin de la rencontre en cours.")
D("GRP_LOCK_FMT",    "%d / %d boss déjà tués ici")
D("GRP_LOCK_NONE",   "pas encore sauvegardé ici")
D("GRP_PIN_FMT",     "farme %s")
D("GRP_MOUNT_FMT",   "%d monture(s) d'ici à obtenir")
D("GRP_MOUNT_NONE",  "a déjà toutes les montures d'ici")
D("GRP_ME",          "toi")
D("GRP_REFRESH",     "Redemander")
D("GRP_NOTE",        "Partagé : boss déjà tués de l'instance, légendaire épinglé, montures manquantes ici. Rien n'est envoyé pendant une rencontre de boss : les infos partent à la fin.")
D("HELP_GROUP",      "partage en groupe (qui est sauvegardé, qui farme quoi)")
D("PAL_C_GROUP",     "Groupe : qui est sauvegardé, qui farme quoi")
D("CTR_Q_GROUP",     "Groupe")

local PREFIX = "TibiSuiteG"
local GAP = 1.5          -- secondes entre deux envois
local REPLY_GAP = 30     -- reponse a une demande Q : 30 s au plus une fois
local MAX_MOUNTS = 25

local peers = {}          -- [nom-royaume] = { L = {map, diff, bits, at}, P = {item, at}, M = {map, ids, at} }
local queue = {}          -- [type] = message ; ordre d'envoi dans `order`
local order = {}
local lastSend, lastReply = 0, 0
local registered = false
local listeners = {}

function TibiSuite.GroupShareOn() return TibiSuiteDB ~= nil and TibiSuiteDB.groupShare == true end

local function Changed()
  for _, fn in ipairs(listeners) do pcall(fn) end
end
function TibiSuite.OnGroupChanged(fn) if type(fn) == "function" then listeners[#listeners + 1] = fn end end

local function Channel()
  if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
  if IsInRaid and IsInRaid() then return "RAID" end
  if IsInGroup and IsInGroup() then return "PARTY" end
  return nil
end

-- Verrouillage du client (rencontre de boss, cle) ou combat : on attend.
local function Locked()
  if InCombatLockdown and InCombatLockdown() then return true end
  if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
    local ok, lock = pcall(C_ChatInfo.InChatMessagingLockdown)
    if ok and lock then return true end
  end
  return false
end
TibiSuite.GroupLocked = Locked

local function Register()
  if registered or not (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) then return end
  pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
  registered = true
end

local function MyKey()
  local name, realm
  if UnitFullName then name, realm = UnitFullName("player") end
  name = name or (UnitName and UnitName("player"))
  if not realm or realm == "" then realm = GetRealmName and GetRealmName() end
  return tostring(name) .. "-" .. tostring(realm or ""):gsub("%s", "")
end

-- ── File d'attente ──────────────────────────────────────────────────
local Flush
local flushPending = false

local function Enqueue(kind, msg)
  if not queue[kind] then order[#order + 1] = kind end
  queue[kind] = msg
  if not flushPending then
    flushPending = true
    C_Timer.After(0.5, function() flushPending = false; Flush() end)
  end
end

function Flush()
  if not TibiSuite.GroupShareOn() or #order == 0 then return end
  local ch = Channel()
  if not ch then wipe(queue); wipe(order); return end
  if Locked() then return end   -- videe a ENCOUNTER_END / PLAYER_REGEN_ENABLED
  local wait = GAP - (GetTime() - lastSend)
  if wait > 0 then
    if not flushPending then
      flushPending = true
      C_Timer.After(wait + 0.05, function() flushPending = false; Flush() end)
    end
    return
  end
  local kind = table.remove(order, 1)
  local msg = queue[kind]
  queue[kind] = nil
  Register()
  local ok, res = pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, ch)
  lastSend = GetTime()
  -- Refus du client (verrouillage apparu entre-temps) : on remet en file.
  if not ok or (type(res) == "number" and res ~= 0) then
    if not queue[kind] then table.insert(order, 1, kind) end
    queue[kind] = queue[kind] or msg
    C_Timer.After(5, Flush)
    return
  end
  if #order > 0 and not flushPending then
    flushPending = true
    C_Timer.After(GAP + 0.05, function() flushPending = false; Flush() end)
  end
end

-- ── Ce que l'on partage ─────────────────────────────────────────────
local function MyLockout()
  if not (GetInstanceInfo and GetNumSavedInstances and GetSavedInstanceInfo) then return nil end
  local _, itype, diff, _, _, _, _, mapID = GetInstanceInfo()
  if not mapID or itype == "none" or not diff then return nil end
  local bits = ""
  for i = 1, (GetNumSavedInstances() or 0) do
    local ok, _, _, _, d, locked, _, _, _, _, _, numEnc, _, _, instID = pcall(GetSavedInstanceInfo, i)
    if ok and instID == mapID and d == diff and locked then
      for j = 1, (numEnc or 0) do
        local okE, _, _, killed = pcall(GetSavedInstanceEncounterInfo, i, j)
        bits = bits .. ((okE and killed) and "1" or "0")
      end
      break
    end
  end
  return string.format("%d,%d,%s", mapID, diff, bits)
end

local function MyMounts()
  if not _G.DgnTracker_MissingMountsHere then return nil end
  local ok, ids = pcall(DgnTracker_MissingMountsHere)
  if not ok or type(ids) ~= "table" then return nil end
  local _, _, _, _, _, _, _, mapID = GetInstanceInfo()
  local parts = {}
  for i = 1, math.min(#ids, MAX_MOUNTS) do parts[#parts + 1] = tostring(ids[i]) end
  return tostring(mapID) .. "," .. table.concat(parts, ".")
end

local function MyPin()
  if not _G.LegTracker_PinnedItemID then return nil end
  local ok, id = pcall(LegTracker_PinnedItemID)
  return ok and tonumber(id) or nil
end

-- Pose dans la file tout ce que l'on a a dire (et une demande si `ask`).
local function ShareAll(ask)
  if not TibiSuite.GroupShareOn() or not Channel() then return end
  local l = MyLockout()
  if l then Enqueue("L", "G1:L:" .. l) end
  local m = MyMounts()
  if m then Enqueue("M", "G1:M:" .. m) end
  local p = MyPin()
  Enqueue("P", p and ("G1:P:" .. p) or "G1:X")
  if ask then Enqueue("Q", "G1:Q") end
end
TibiSuite.GroupShareNow = ShareAll

-- ── Reception ───────────────────────────────────────────────────────
local function Secret(v) return issecretvalue and issecretvalue(v) or false end

local function OnMessage(prefix, msg, _, sender)
  if prefix ~= PREFIX or not TibiSuite.GroupShareOn() then return end
  if Secret(msg) or Secret(sender) or type(msg) ~= "string" then return end
  local who = tostring(sender or "")
  if not who:find("-", 1, true) then who = who .. "-" .. tostring(GetRealmName and GetRealmName() or ""):gsub("%s", "") end
  if who == MyKey() then return end
  local kind, data = msg:match("^G1:(%u):?(.*)$")
  if not kind then return end
  local p = peers[who] or {}
  peers[who] = p
  local now = time()
  if kind == "Q" then
    if GetTime() - lastReply > REPLY_GAP then lastReply = GetTime(); ShareAll(false) end
    return
  elseif kind == "L" then
    local map, diff, bits = data:match("^(%d+),(%d+),([01]*)$")
    if map then p.L = { map = tonumber(map), diff = tonumber(diff), bits = bits, at = now } end
  elseif kind == "M" then
    local map, list = data:match("^(%d+),(.*)$")
    if map then
      local ids = {}
      for id in list:gmatch("%d+") do ids[#ids + 1] = tonumber(id) end
      p.M = { map = tonumber(map), ids = ids, at = now }
    end
  elseif kind == "P" then
    local id = tonumber(data)
    if id then p.P = { item = id, at = now } end
  elseif kind == "X" then
    p.P = nil
  end
  Changed()
end

-- Joueurs partis du groupe : oublies.
local function Prune()
  local inGroup = {}
  local n = GetNumGroupMembers and GetNumGroupMembers() or 0
  local unit = (IsInRaid and IsInRaid()) and "raid" or "party"
  for i = 1, n do
    local name, realm = UnitName(unit .. i)
    if name and not Secret(name) then
      if not realm or realm == "" then realm = GetRealmName and GetRealmName() end
      inGroup[name .. "-" .. tostring(realm or ""):gsub("%s", "")] = true
    end
  end
  for k in pairs(peers) do if not inGroup[k] then peers[k] = nil end end
end

-- Pairs tries, avec ce qui concerne l'instance courante seulement :
-- { { key, name, lock = {killed, total} | false, pin = itemID, mounts = {ids} } }.
function TibiSuite.GetGroupPeers()
  local _, itype, diff, _, _, _, _, mapID = GetInstanceInfo()
  local here = itype ~= "none" and mapID or nil
  local out = {}
  for key, p in pairs(peers) do
    local e = { key = key, name = key:match("^(.-)%-") or key }
    if here and p.L and p.L.map == here and p.L.diff == diff then
      local k = select(2, p.L.bits:gsub("1", ""))
      e.lock = (#p.L.bits > 0) and { killed = k, total = #p.L.bits } or false
    end
    if p.P then e.pin = p.P.item end
    if here and p.M and p.M.map == here then e.mounts = p.M.ids end
    out[#out + 1] = e
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

function TibiSuite.SetGroupShare(on)
  TibiSuiteDB.groupShare = on and true or nil
  if on then Register(); ShareAll(true) else wipe(peers); wipe(queue); wipe(order) end
  Changed()
end

-- ── Fenetre ─────────────────────────────────────────────────────────
local f, rows = nil, {}
local K
local function Kit() K = K or TibiSuite._kit; return K ~= nil end
local function Acc() return TibiSuite.ACCENT or { 0.769, 0.122, 0.231 } end
local W = 460
local Refresh

local function ItemName(id)
  local n = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
  if not n and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  return n or ("#" .. tostring(id))
end

local function Build()
  if f or not Kit() then return f end
  f = CreateFrame("Frame", "TibiSuiteGroup", UIParent, "BackdropTemplate")
  f:SetSize(W, 200)
  f:SetPoint("CENTER", 260, 80)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if K.SkinLikeSuite then K.SkinLikeSuite(f, K.ACC) end
  table.insert(UISpecialFrames, "TibiSuiteGroup")
  f.title = K.Text(f, "GameFontNormalLarge", L.GRP_TITLE, Acc())
  f.title:SetPoint("TOPLEFT", 16, -14)
  f.sub = K.Text(f, "GameFontHighlightSmall", "", K.COL.MUT, W - 60)
  f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
  f.sub:SetJustifyH("LEFT")
  f.close = K.Btn(f, 24, 24, "X", "ghost")
  f.close:SetPoint("TOPRIGHT", -8, -8)
  f.close:SetScript("OnClick", function() f:Hide() end)
  f.share = K.Btn(f, 300, 24, "", "ghost")
  f.share:SetPoint("TOPLEFT", 10, -56)
  f.share._label:ClearAllPoints(); f.share._label:SetPoint("LEFT", 6, 0)
  f.share:SetScript("OnClick", function() TibiSuite.SetGroupShare(not TibiSuite.GroupShareOn()) end)
  f.ask = K.Btn(f, 120, 24, L.GRP_REFRESH)
  f.ask:SetPoint("TOPRIGHT", -14, -56)
  f.ask:SetScript("OnClick", function() ShareAll(true) end)
  f.msg = K.Text(f, "GameFontHighlight", "", K.COL.MUT, W - 40)
  f.msg:SetJustifyH("LEFT")
  f.note = K.Text(f, "GameFontDisableSmall", L.GRP_NOTE, K.COL.DIM, W - 32)
  f.note:SetJustifyH("LEFT")
  f:Hide()
  return f
end

local function Row(i)
  local r = rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, f)
  r:SetSize(W - 28, 40)
  r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:SetColorTexture(1, 1, 1, 0.035)
  r.name = K.Text(r, "GameFontNormal", "", K.COL.TXT); r.name:SetPoint("TOPLEFT", 10, -5)
  r.l1 = K.Text(r, "GameFontHighlightSmall", "", K.COL.TXT); r.l1:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
  r.l1:SetWidth(W - 50); r.l1:SetJustifyH("LEFT"); r.l1:SetWordWrap(false)
  r:SetScript("OnEnter", function(s)
    if not (s.e and s.e.mounts and #s.e.mounts > 0) then return end
    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
    GameTooltip:AddLine(s.e.name, 1, 1, 1)
    for _, id in ipairs(s.e.mounts) do GameTooltip:AddLine(ItemName(id), 0.8, 0.8, 0.85) end
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  rows[i] = r
  return r
end

function Refresh()
  if not (f and f:IsShown()) then return end
  local on = TibiSuite.GroupShareOn()
  f.title:SetTextColor(Acc()[1], Acc()[2], Acc()[3])
  local box = on and "|TInterface\\Buttons\\UI-CheckBox-Check:16:16|t" or "|TInterface\\Buttons\\UI-CheckBox-Up:16:16|t"
  f.share._label:SetText(box .. " " .. L.GRP_SHARE)
  f.sub:SetText(on and L.GRP_SUB_ON or L.GRP_SUB_OFF)
  f.ask:SetShown(on and Channel() ~= nil)
  for _, r in ipairs(rows) do r:Hide() end
  local y = -90
  local list = on and TibiSuite.GetGroupPeers() or {}
  local msg
  if not on then msg = nil
  elseif not Channel() then msg = L.GRP_NOGROUP
  elseif #list == 0 then msg = L.GRP_NOPEER end
  if on and #order > 0 and Locked() then msg = (msg and (msg .. "\n") or "") .. L.GRP_PENDING end
  for i, e in ipairs(list) do
    local r = Row(i)
    r.e = e
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 14, y)
    local nm = TibiSuite.SafeName and TibiSuite.SafeName(e.name) or e.name
    r.name:SetText(nm)
    local parts = {}
    if e.lock then parts[#parts + 1] = string.format(L.GRP_LOCK_FMT, e.lock.killed, e.lock.total)
    elseif e.lock == false then parts[#parts + 1] = L.GRP_LOCK_NONE end
    if e.pin then parts[#parts + 1] = string.format(L.GRP_PIN_FMT, ItemName(e.pin)) end
    if e.mounts then
      parts[#parts + 1] = (#e.mounts > 0) and string.format(L.GRP_MOUNT_FMT, #e.mounts) or L.GRP_MOUNT_NONE
    end
    r.l1:SetText(#parts > 0 and table.concat(parts, "  ·  ") or "-")
    r:Show()
    y = y - 44
  end
  f.msg:SetShown(msg ~= nil)
  if msg then
    f.msg:SetText(msg)
    f.msg:ClearAllPoints(); f.msg:SetPoint("TOPLEFT", 18, y - 4)
    y = y - (f.msg:GetStringHeight() or 16) - 14
  end
  f.note:ClearAllPoints(); f.note:SetPoint("TOPLEFT", 16, y - 6)
  y = y - (f.note:GetStringHeight() or 30) - 18
  f:SetHeight(-y)
end

TibiSuite.OnGroupChanged(function() if Refresh then Refresh() end end)

function TibiSuite.ShowGroupWindow()
  if not Build() then return false end
  if TibiSuite.ApplyUIScaleTo then TibiSuite.ApplyUIScaleTo(f) end
  f:Show()
  Refresh()
  return true
end

function TibiSuite.ToggleGroupWindow()
  if f and f:IsShown() then f:Hide() else TibiSuite.ShowGroupWindow() end
end

-- ── Evenements ──────────────────────────────────────────────────────
local groupSize = 0
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE", "ENCOUNTER_END",
  "PLAYER_REGEN_ENABLED", "BOSS_KILL", "UPDATE_INSTANCE_INFO" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e, ...)
  if not TibiSuite.GroupShareOn() then return end
  if e == "CHAT_MSG_ADDON" then OnMessage(...); return end
  if e == "PLAYER_ENTERING_WORLD" then
    Register()
    -- Nouvelle instance : les verrouillages se relisent apres RequestRaidInfo.
    if RequestRaidInfo then pcall(RequestRaidInfo) end
    C_Timer.After(4, function() ShareAll(true) end)
  elseif e == "GROUP_ROSTER_UPDATE" then
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    if n > groupSize then C_Timer.After(2, function() ShareAll(true) end) end
    groupSize = n
    Prune()
    Changed()
  elseif e == "BOSS_KILL" then
    if RequestRaidInfo then pcall(RequestRaidInfo) end
  elseif e == "UPDATE_INSTANCE_INFO" then
    -- Verrouillages a jour (apres un boss ou l'entree en instance).
    local l = MyLockout()
    if l and Channel() then Enqueue("L", "G1:L:" .. l) end
  elseif e == "ENCOUNTER_END" or e == "PLAYER_REGEN_ENABLED" then
    -- Fin du verrouillage : la file part (le client peut le lever un peu
    -- apres l'evenement, d'ou la seconde tentative).
    C_Timer.After(1, Flush)
    C_Timer.After(6, Flush)
  end
  if f and f:IsShown() then Refresh() end
end)
