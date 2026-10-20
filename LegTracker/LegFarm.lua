-- ================================================================
--  LegTracker  -  LegFarm.lua  (legendaire epingle et temps de farm)
--  Plan : _dev/LegOverlay.md. Un legendaire epingle par personnage ; le
--  chronometre tourne seulement dans un raid de farm du legendaire
--  (item.raids, instanceID = 8e retour de GetInstanceInfo) ou dans la zone
--  de la quete en cours (q.mapID, carte du joueur ou une de ses parentes),
--  ou, si les donnees ont item.farm = { maps, fishing }, sur ces cartes et
--  pendant la peche (lancer ou prise de moins de 90 s : Pecheur de Terradiance).
--
--  Donnees (LegTrackerDB, rien d'existant n'est modifie) :
--    pin  = { ["Nom-Royaume"] = itemID }
--    farm = { ["Nom-Royaume"] = { [itemID] = {
--      total, runs, sessions (10), perRun = { [cle] = n }, doneAt,
--      cur = { start, active, last, place, kind, kills, seen, gains } } } }
--  Cle d'un composant : "i<itemID>" ou "c<currencyID>".
--  Seance : ouverte a l'entree, fermee apres 5 min hors du raid (10 min hors
--  de la zone de quete). Gain = hausse des compteurs pendant la seance
--  (une baisse, composant rendu a une quete, ne compte pas). Pause si /afk.
--  NON TESTE EN JEU : a valider par Tibiscui (nouveau fichier : redemarrage
--  complet du client).
-- ================================================================

local _, NS = ...

local FR = (GetLocale and GetLocale() == "frFR")
local function T(fr, en) return FR and fr or en end

local ACC = { 1.000, 0.427, 0.043 }   -- orange LegTracker (#FF6D0B)
local GRACE = { raid = 300, quest = 600, fish = 600 }
local FISH_WINDOW = 90       -- peche « en cours » : lancer ou prise de moins de 90 s
local FISHING_SPELL = 131474
local MAX_SESSIONS = 10

local FT = {
  pinTT        = T("Épingler ce légendaire", "Pin this legendary"),
  unpinTT      = T("Retirer l'épingle", "Unpin"),
  pinNote      = T("Affiche l'overlay de farm : temps passé, composants, quête en cours.",
                   "Shows the farm overlay: time spent, components, current quest."),
  rowHint      = T("Clic droit : épingler (overlay de farm)", "Right click: pin (farm overlay)"),
  rowHintOff   = T("Clic droit : retirer l'épingle", "Right click: unpin"),
  noLegacy     = T("Plus obtenable : rien à farmer.", "No longer obtainable: nothing to farm."),
  noIncomplete = T("Fiche incomplète.", "Incomplete entry."),
  noClass      = T("Réservé à d'autres classes.", "Reserved for other classes."),
  noOwned      = T("Déjà obtenu.", "Already obtained."),
  noTrack      = T("Ni raid, ni quête, ni composant à suivre.", "No raid, quest or component to track."),
  noSel        = T("Ouvre LegTracker et sélectionne un légendaire, puis /lt pin.", "Open LegTracker and select a legendary, then /lt pin."),
  pinned       = T("Légendaire épinglé : %s. L'overlay de farm s'affiche dans ses raids et dans la zone de sa quête.",
                   "Legendary pinned: %s. The farm overlay shows in its raids and in its quest zone."),
  unpinned     = T("Épingle retirée (le temps de farm est gardé).", "Unpinned (farm time is kept)."),
  noPin        = T("Aucun légendaire épinglé.", "No pinned legendary."),
  summaryFmt   = T("Temps de farm : %s en %d séance(s)", "Farm time: %s in %d session(s)"),
  runsFmt      = T(", %d passage(s)", ", %d run(s)"),
  estFmt       = T("~%d passage(s) restant(s)", "~%d run(s) left"),
  estFishFmt   = T("~%d séance(s) de pêche restante(s)", "~%d fishing session(s) left"),
  pinnedFish   = T("Légendaire épinglé : %s. L'overlay de farm s'affiche quand tu pêches dans ses zones.",
                   "Legendary pinned: %s. The farm overlay shows when you fish in its zones."),
  sessDone     = T("%s : %s, %d boss", "%s: %s, %d boss(es)"),
  sessQuest    = T("%s : %s", "%s: %s"),
  sessFish     = T("pêche, %s", "fishing, %s"),
  doneFmt      = T("%s obtenu après %s de farm en %d séance(s) !", "%s obtained after %s of farming in %d session(s)!"),
  farmHdr      = T("Farm de %s", "Farm of %s"),
  farmLast     = T("  %s · %s · %s", "  %s · %s · %s"),
  farmNone     = T("  Aucune séance pour l'instant.", "  No session yet."),
  boss         = T("boss", "boss"),
}
NS.FT = FT

-- ---------------------------------------------------------------- outils
local function Secret(v) return issecretvalue and issecretvalue(v) or false end

function NS.CharKey()
  local n = UnitName and UnitName("player")
  local r = GetRealmName and GetRealmName()
  if not n or Secret(n) or not r or Secret(r) then return nil end
  return n .. "-" .. r
end

-- 1:12:40 / 05:12 (chronometre)
function NS.Clock(sec)
  sec = math.max(0, math.floor(sec or 0))
  local h, m, s = math.floor(sec / 3600), math.floor(sec / 60) % 60, sec % 60
  if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
  return string.format("%02d:%02d", m, s)
end

-- 4 h 05 / 12 min (durees cumulees)
function NS.HM(sec)
  sec = math.max(0, math.floor(sec or 0))
  local h, m = math.floor(sec / 3600), math.floor(sec / 60) % 60
  if h > 0 then return string.format("%d h %02d", h, m) end
  return string.format("%d min", m)
end

-- Nom court : avant la premiere virgule (« Sulfuras, Main de Ragnaros »)
function NS.ShortName(item)
  local n = NS.DisplayName and NS.DisplayName(item) or (item and item.name) or "?"
  return (n:match("^([^,]+),") or n)
end

local function TrKey(tr)
  if tr.achievementID then return "a" .. tr.achievementID end
  if tr.currencyID then return "c" .. tr.currencyID end
  if tr.itemID then return "i" .. tr.itemID end
end
NS.TrKey = TrKey

local function WeeklyResetAt()
  if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
    local ok, s = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
    if ok and type(s) == "number" and s > 0 then return time() + s end
  end
end

-- Pastille de punaise (meme atlas que les cartes de Ma semaine)
function NS.SetPinTexture(tex)
  local atlas
  for _, name in ipairs({ "Waypoint-MapPin-Untracked", "Waypoint-MapPin-Tracked", "Waypoint-MapPin-ChatIcon" }) do
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) then atlas = name; break end
  end
  if atlas then tex:SetAtlas(atlas) else tex:SetTexture("Interface\\Buttons\\UI-CheckBox-Check") end
end

-- ---------------------------------------------------------------- donnees
local function FarmRoot()
  if not LegTrackerDB then return nil end
  local k = NS.CharKey()
  if not k then return nil end
  LegTrackerDB.farm = LegTrackerDB.farm or {}
  LegTrackerDB.farm[k] = LegTrackerDB.farm[k] or {}
  return LegTrackerDB.farm[k]
end

-- Fiche de farm d'un legendaire (creee si create)
function NS.FarmRec(itemID, create)
  if not itemID then return nil end
  local root = create and FarmRoot() or (LegTrackerDB and LegTrackerDB.farm and NS.CharKey() and LegTrackerDB.farm[NS.CharKey()])
  if not root then return nil end
  local rec = root[itemID]
  if not rec and create then
    rec = { total = 0, runs = 0, sessions = {}, perRun = {} }
    root[itemID] = rec
  end
  return rec
end

function NS.GetPinID()
  local p = LegTrackerDB and LegTrackerDB.pin
  local k = p and NS.CharKey()
  return k and p[k] or nil
end

function NS.GetPinnedItem()
  local id = NS.GetPinID()
  if not id then return nil end
  return (NS.FindItem(id))
end

-- Temps total (seances closes + seance en cours)
function NS.TotalTime(rec)
  if not rec then return 0 end
  return (rec.total or 0) + ((rec.cur and rec.cur.active) or 0)
end

-- Seances gardees (compteur, la liste n'en garde que 10) + celle en cours
function NS.SessionCount(rec)
  if not rec then return 0 end
  return (rec.nSess or #(rec.sessions or {})) + (rec.cur and 1 or 0)
end

-- ---------------------------------------------------------------- abonnes
local listeners = {}
function NS.OnFarmChanged(fn) if type(fn) == "function" then listeners[#listeners + 1] = fn end end
local fireT
local function Fire(now)
  local function run()
    fireT = nil
    for _, fn in ipairs(listeners) do pcall(fn) end
    local TS = _G.TibiSuite
    if TS and TS.RefreshStatus then pcall(TS.RefreshStatus) end
  end
  if now then run() return end
  if not fireT then fireT = C_Timer.NewTimer(0.3, run) end
end
NS.FireFarm = Fire

-- ---------------------------------------------------------------- epingle
function NS.CanPin(item)
  if not item or item.placeholder or not item.itemID or item.itemID <= 0 then return false, FT.noIncomplete end
  if item.legacy then return false, FT.noLegacy end
  if NS.HasClass and not NS.HasClass(item) then return false, FT.noClass end
  if item._status == "OBTAINED" or (NS.Owned and NS.Owned(item.itemID)) then return false, FT.noOwned end
  local any = (item.raids and #item.raids > 0) or (item.quests and #item.quests > 0) or (item.trackers and #item.trackers > 0)
  if not any then return false, FT.noTrack end
  return true
end

local CloseSession   -- defini plus bas

function NS.SetPin(itemID, verbose)
  if not LegTrackerDB then return end
  local k = NS.CharKey()
  if not k then return end
  local old = NS.GetPinID()
  if old == itemID then return end
  if old then
    local rec = NS.FarmRec(old)
    if rec and rec.cur then CloseSession(rec, old) end
  end
  LegTrackerDB.pin = LegTrackerDB.pin or {}
  LegTrackerDB.pin[k] = itemID
  local rec = NS.FarmRec(itemID, true)
  rec.doneAt = nil
  NS.placeDirty = true
  if verbose then
    local item = NS.FindItem(itemID)
    local fmt = (item and item.farm and item.farm.fishing) and FT.pinnedFish or FT.pinned
    print(NS.PREFIX .. string.format(fmt, item and NS.ShortName(item) or ("#" .. itemID)))
  end
  if NS.OverlayPreview then NS.OverlayPreview() end
  local TS = _G.TibiSuite
  if TS and TS.InvalidateSuggestions then pcall(TS.InvalidateSuggestions) end
  if NS.RefreshWindow then NS.RefreshWindow() end
  Fire(true)
end

function NS.Unpin(verbose)
  local id = NS.GetPinID()
  if not id then
    if verbose then print(NS.PREFIX .. FT.noPin) end
    return
  end
  local rec = NS.FarmRec(id)
  if rec and rec.cur then CloseSession(rec, id) end
  LegTrackerDB.pin[NS.CharKey()] = nil
  if verbose then print(NS.PREFIX .. FT.unpinned) end
  local TS = _G.TibiSuite
  if TS and TS.InvalidateSuggestions then pcall(TS.InvalidateSuggestions) end
  if NS.RefreshWindow then NS.RefreshWindow() end
  Fire(true)
end

function NS.TogglePin(item, verbose)
  if not item then return end
  if NS.GetPinID() == item.itemID then NS.Unpin(verbose) return end
  local ok, why = NS.CanPin(item)
  if not ok then
    if verbose then print(NS.PREFIX .. (why or "")) end
    return
  end
  NS.SetPin(item.itemID, verbose)
end

function NS.PinSelected(item)
  if not item then print(NS.PREFIX .. FT.noSel) return end
  if NS.GetPinID() == item.itemID then return end
  NS.TogglePin(item, true)
end

-- Aspect de la punaise du panneau detail
function NS.PaintPin(btn, item)
  if not (btn and item) then return end
  local on = NS.GetPinID() == item.itemID
  local can = on or NS.CanPin(item)
  if on then
    btn.tex:SetVertexColor(ACC[1], ACC[2], ACC[3]); btn:SetAlpha(1)
  else
    btn.tex:SetVertexColor(0.85, 0.85, 0.85); btn:SetAlpha(can and 0.5 or 0.18)
  end
end

function NS.PinTooltip(owner, item)
  if not item then return end
  GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
  local on = NS.GetPinID() == item.itemID
  GameTooltip:SetText(on and FT.unpinTT or FT.pinTT, ACC[1], ACC[2], ACC[3])
  if on then
    local s = NS.FarmSummary(item.itemID, true)
    if s then GameTooltip:AddLine(s, 0.9, 0.9, 0.9, true) end
  else
    local ok, why = NS.CanPin(item)
    if ok then GameTooltip:AddLine(FT.pinNote, 0.9, 0.9, 0.9, true)
    else GameTooltip:AddLine(why, 1, 0.4, 0.4, true) end
  end
  GameTooltip:Show()
end

function NS.PinRowHint(tt, item)
  local on = NS.GetPinID() == item.itemID
  if not on and not NS.CanPin(item) then return end
  tt:AddLine(" ")
  tt:AddLine(on and FT.rowHintOff or FT.rowHint, ACC[1], ACC[2], ACC[3])
end

-- ---------------------------------------------------------------- estimation
-- Passages restants : moyenne de gain par passage (2 passages au moins),
-- composant le plus long. nil si on ne sait pas (pas de chiffre invente).
-- Pour un farm de peche, un « passage » est une seance de peche.
function NS.Estimate(item, rec)
  if not (item and rec) or (rec.runs or 0) < 2 then return nil end
  local worst
  for _, tr in ipairs(item.trackers or {}) do
    local key = TrKey(tr)
    if key then
      local left = (tr.need or 1) - NS.TrackerCount(tr)
      local got = (rec.perRun or {})[key] or 0
      if left > 0 and got > 0 then
        local n = math.ceil(left / (got / rec.runs))
        if not worst or n > worst then worst = n end
      end
    end
  end
  return worst
end

-- Ligne de resume (panneau detail, infobulle de la punaise)
function NS.FarmSummary(itemID, plain)
  local rec = NS.FarmRec(itemID)
  if not rec then return nil end
  local tot = NS.TotalTime(rec)
  if tot < 60 then return nil end
  local s = string.format(FT.summaryFmt, NS.HM(tot), NS.SessionCount(rec))
  local item = NS.FindItem(itemID)
  local fishing = item and item.farm and item.farm.fishing
  if (rec.runs or 0) > 0 and not fishing then s = s .. string.format(FT.runsFmt, rec.runs) end
  local est = NS.Estimate(item, rec)
  if est then s = s .. " · " .. string.format(fishing and FT.estFishFmt or FT.estFmt, est) end
  if plain then return s end
  return "|cFFFF9A40" .. s .. "|r"
end

-- Progression globale du legendaire epingle (0..1) : composants (plafonnes)
-- et quetes a part egale. nil si rien de mesurable.
function NS.PinProgress(item)
  if not item then return nil end
  local done, total = 0, 0
  for _, tr in ipairs(item.trackers or {}) do
    if tr.itemID or tr.currencyID or tr.achievementID then
      local need = tr.need or 1
      done = done + math.min(1, NS.TrackerCount(tr) / need)
      total = total + 1
    end
  end
  local _, qDone, qTotal = NS.Scan(item)
  if (qTotal or 0) > 0 then done, total = done + qDone, total + qTotal end
  if total == 0 then return nil end
  return done / total
end

-- ---------------------------------------------------------------- lieu
local placeKind, placeName, placeAt = nil, nil, 0
NS.placeDirty = true

-- Quete en cours du legendaire : quete, etape, dans le journal
local function CurrentQuest(item)
  local _, _, _, _, _, _, step, onQuest = NS.Scan(item)
  return step and item.quests and item.quests[step] or nil, step, onQuest
end
NS.CurrentQuest = CurrentQuest

local function OnMapOrParent(mapID)
  if not (mapID and C_Map and C_Map.GetBestMapForUnit) then return false end
  local m = C_Map.GetBestMapForUnit("player")
  for _ = 1, 8 do
    if not m or Secret(m) then return false end
    if m == mapID then return true end
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(m)
    m = info and info.parentMapID
    if m == 0 then return false end
  end
  return false
end

-- Peche : derniere activite (lancer ou prise), en GetTime()
local lastFish = 0
function NS.FishingNow() return GetTime() - lastFish <= FISH_WINDOW end

local function ZoneLabel(fallback)
  local z = GetZoneText and GetZoneText()
  if z and z ~= "" and not Secret(z) then return z end
  return fallback or "?"
end

local function OnAnyMap(maps)
  for _, m in ipairs(maps or {}) do
    if OnMapOrParent(m) then return true end
  end
  return false
end

local function ComputePlace(item)
  if not item then return nil end
  -- Farm hors raid declare dans les donnees (peche aux Iles Brisees)
  local farm = item.farm
  if farm and farm.maps and OnAnyMap(farm.maps) and (not farm.fishing or NS.FishingNow()) then
    return farm.fishing and "fish" or "quest", ZoneLabel(farm.label)
  end
  local inInst = IsInInstance and IsInInstance()
  if inInst then
    local name, _, _, _, _, _, _, instID = GetInstanceInfo()
    if Secret(instID) then return nil end
    for _, raid in ipairs(item.raids or {}) do
      if raid.instanceID == instID then
        local label = raid.name
        if not label and name and not Secret(name) then label = name end
        return "raid", label or "?"
      end
    end
    return nil
  end
  -- Zone de quete : seulement quete dans le journal et hors ville / auberge
  -- (la 1re etape de Courroux du dragon est a Hurlevent : pas du farm).
  local q, _, onQuest = CurrentQuest(item)
  local resting = IsResting and IsResting()
  if Secret(resting) then resting = true end
  if q and q.mapID and onQuest and not resting and OnMapOrParent(q.mapID) then
    return "quest", q.zone or q.name or "?"
  end
  return nil
end

function NS.CurrentPlace() return placeKind, placeName end

-- ---------------------------------------------------------------- seance
local function Snapshot(item)
  local seen = {}
  for _, tr in ipairs(item.trackers or {}) do
    local key = TrKey(tr)
    if key then seen[key] = NS.TrackerCount(tr) end
  end
  return seen
end

local function OpenSession(rec, item, kind, name)
  rec.cur = { start = time(), active = 0, last = time(), place = name, kind = kind,
              kills = 0, seen = Snapshot(item), gains = {} }
  Fire()
end

local function Feed(text, opts)
  local TS = _G.TibiSuite
  if TS and TS.Notify then pcall(TS.Notify, "Leg", text, opts or { toast = false }) end
end

local function GainsText(item, gains)
  local parts = {}
  for _, tr in ipairs((item and item.trackers) or {}) do
    local key = TrKey(tr)
    local n = key and gains and gains[key]
    if n and n > 0 then parts[#parts + 1] = "+" .. n .. " " .. (tr.name or key) end
  end
  return table.concat(parts, ", ")
end
NS.GainsText = GainsText

CloseSession = function(rec, itemID, endAt)
  local cur = rec and rec.cur
  if not cur then return end
  rec.cur = nil
  local gainsAny = next(cur.gains or {}) ~= nil
  local dur = cur.active or 0
  if dur < 60 and (cur.kills or 0) == 0 and not gainsAny then Fire() return end
  rec.total = (rec.total or 0) + dur
  rec.sessions = rec.sessions or {}
  table.insert(rec.sessions, { start = cur.start, dur = dur, place = cur.place, kind = cur.kind,
                               kills = cur.kills, gains = cur.gains, at = endAt or time() })
  while #rec.sessions > MAX_SESSIONS do table.remove(rec.sessions, 1) end
  rec.nSess = (rec.nSess or (#rec.sessions - 1)) + 1
  if (cur.kind == "raid" and (cur.kills or 0) > 0) or cur.kind == "fish" then
    rec.runs = (rec.runs or 0) + 1
    rec.perRun = rec.perRun or {}
    for k, n in pairs(cur.gains or {}) do rec.perRun[k] = (rec.perRun[k] or 0) + n end
  end
  local item = NS.FindItem(itemID)
  if item and dur >= 60 then
    local g = GainsText(item, cur.gains)
    local txt
    if cur.kind == "raid" then
      txt = string.format(FT.sessDone, cur.place or "?", NS.HM(dur), cur.kills or 0)
    elseif cur.kind == "fish" then
      txt = string.format(FT.sessFish, NS.HM(dur))
    else
      txt = string.format(FT.sessQuest, cur.place or "?", NS.HM(dur))
    end
    if g ~= "" then txt = txt .. ", " .. g end
    Feed(NS.ShortName(item) .. " · " .. txt)
  end
  Fire()
end

-- Compteurs : une hausse pendant la seance = gain ; une baisse ne fait que
-- remettre la reference. muteUntil : donnees de banque qui arrivent.
local muteUntil = 0
local function UpdateGains()
  local id = NS.GetPinID()
  local rec = NS.FarmRec(id)
  local cur = rec and rec.cur
  local item = id and NS.FindItem(id)
  if not (cur and item) then return end
  local mute = GetTime() < muteUntil
  local changed = false
  cur.seen = cur.seen or {}
  cur.gains = cur.gains or {}
  for _, tr in ipairs(item.trackers or {}) do
    local key = TrKey(tr)
    if key then
      local n = NS.TrackerCount(tr)
      local was = cur.seen[key]
      if was and n > was and not mute then
        cur.gains[key] = (cur.gains[key] or 0) + (n - was)
        changed = true
      end
      if was ~= n then cur.seen[key] = n; changed = true end
    end
  end
  if changed then Fire() end
end

function NS.OnBankData()
  muteUntil = GetTime() + 2.5
  C_Timer.After(2.6, function() pcall(UpdateGains) end)
end

-- Legendaire epingle obtenu (CheckLoot de LegTracker.lua)
function NS.OnLegendaryCheck(legs)
  local id = NS.GetPinID()
  if not (id and legs and legs[id]) then return end
  local rec = NS.FarmRec(id, true)
  if rec.doneAt then return end
  if rec.cur then CloseSession(rec, id) end
  rec.doneAt = time()
  local item = NS.FindItem(id)
  local txt = string.format(FT.doneFmt, item and NS.ShortName(item) or ("#" .. id), NS.HM(rec.total or 0), NS.SessionCount(rec))
  print(NS.PREFIX .. "|cFFFFD700" .. txt .. "|r")
  Feed(txt, { toast = true })
  if NS.OverlayPreview then NS.OverlayPreview() end
  Fire(true)
end

-- ---------------------------------------------------------------- horloge
local lastT
local function Tick()
  local id = NS.GetPinID()
  local rec = id and NS.FarmRec(id, true)
  local now = time()
  local dt = now - (lastT or now)
  lastT = now
  if not rec or rec.doneAt then return end
  local item = NS.FindItem(id)
  if not item then return end

  if NS.placeDirty or GetTime() - placeAt > ((item.farm and item.farm.fishing) and 1 or 10) then
    NS.placeDirty = false
    placeAt = GetTime()
    placeKind, placeName = ComputePlace(item)
  end

  local cur = rec.cur
  if placeKind then
    if not cur then
      OpenSession(rec, item, placeKind, placeName)
      cur = rec.cur
    elseif cur.kind ~= placeKind and placeKind == "raid" then
      -- De la zone de quete au raid : le raid l'emporte (passages comptes)
      cur.kind = "raid"
    end
    if placeName and cur.place ~= placeName and placeKind == cur.kind then cur.place = placeName end
    local paused = UnitIsAFK and UnitIsAFK("player")
    if Secret(paused) then paused = false end
    cur.paused = paused and true or nil
    if dt > 0 and dt <= 5 and not paused then cur.active = (cur.active or 0) + dt end
    cur.last = now
  elseif cur then
    cur.paused = nil
    if now - (cur.last or now) > (GRACE[cur.kind] or 300) then CloseSession(rec, id, cur.last) end
  end
end

-- Secondes avant la fermeture de la seance (hors du lieu), nil sinon
function NS.GraceLeft()
  local rec = NS.FarmRec(NS.GetPinID())
  local cur = rec and rec.cur
  if not cur or placeKind then return nil end
  return math.max(0, (GRACE[cur.kind] or 300) - (time() - (cur.last or time())))
end

local acc = 0
local clock = CreateFrame("Frame")
clock:SetScript("OnUpdate", function(_, elapsed)
  acc = acc + elapsed
  if acc < 1 then return end
  acc = 0
  if not NS.GetPinID() then lastT = nil return end
  local ok, err = pcall(Tick)
  if not ok and not NS._farmErr then
    NS._farmErr = true
    print(NS.PREFIX .. T("Erreur du suivi de farm : ", "Farm tracking error: ") .. tostring(err))
  end
end)

-- ---------------------------------------------------------------- chat
function NS.PrintFarm()
  local item = NS.GetPinnedItem()
  if not item then print(NS.PREFIX .. FT.noPin) return end
  local rec = NS.FarmRec(item.itemID, true)
  print(NS.PREFIX .. string.format(FT.farmHdr, NS.ShortName(item)))
  print("  " .. (NS.FarmSummary(item.itemID, true) or string.format(FT.summaryFmt, NS.HM(NS.TotalTime(rec)), NS.SessionCount(rec))))
  local list = rec.sessions or {}
  if #list == 0 then print(FT.farmNone) end
  for i = #list, math.max(1, #list - 4), -1 do
    local s = list[i]
    local when = date and date("%d/%m %H:%M", s.start or 0) or ""
    local what = NS.HM(s.dur) .. ((s.kind == "raid") and (", " .. (s.kills or 0) .. " " .. FT.boss) or "")
    local g = GainsText(item, s.gains)
    print(string.format(FT.farmLast, when, s.place or "?", what) .. (g ~= "" and (" · " .. g) or ""))
  end
end

-- ---------------------------------------------------------------- suite
-- Ligne d'etat du Panneau vivant : le legendaire epingle et sa progression.
function NS.PinStatus()
  local item = NS.GetPinnedItem()
  if not item then return nil end
  local rec = NS.FarmRec(item.itemID)
  if rec and rec.doneAt then return nil end
  local p = NS.PinProgress(item) or 0
  local SL = _G.TibiSuiteL or {}
  return { text = string.format(SL.ST_LEG_PIN_FMT or "%s · %d %%", NS.ShortName(item), math.floor(p * 100)),
           progress = p, color = ACC }
end

-- Premiere ligne de l'apercu du Centre
function NS.PinOverviewLine()
  local item = NS.GetPinnedItem()
  if not item then return nil end
  local rec = NS.FarmRec(item.itemID)
  if rec and rec.doneAt then return nil end
  local tot = NS.TotalTime(rec)
  local SL = _G.TibiSuiteL or {}
  return { text = (SL.OV_LEG_PIN or "Épinglé") .. " : " .. NS.ShortName(item),
           value = tot >= 60 and NS.HM(tot) or (math.floor((NS.PinProgress(item) or 0) * 100) .. " %"),
           progress = NS.PinProgress(item), color = ACC, target = "pin" }
end

-- Conseiller : raids de farm du legendaire epingle encore libres cette semaine
function LegTracker_Suggest()
  local item = NS.GetPinnedItem()
  if not item or not item.raids then return {} end
  local rec = NS.FarmRec(item.itemID)
  if rec and rec.doneAt then return {} end
  local SL = _G.TibiSuiteL or {}
  local out = {}
  local p = NS.PinProgress(item) or 0
  local short = NS.ShortName(item)
  for _, raid in ipairs(item.raids) do
    if #NS.GetRaidLockouts(raid.instanceID) == 0 then
      local rname = NS.RaidName(raid)
      out[#out + 1] = {
        id = "leg:" .. item.itemID .. ":" .. raid.instanceID, kind = "legendary", tag = "raid",
        text = rname, proximity = math.max(0.5, p), weight = 1.2, endsAt = WeeklyResetAt(),
        target = "pin",
        why = SL.SUG_L_FMT and string.format(SL.SUG_L_FMT, short) or nil,
        steps = function()
          local st = {}
          for _, tr in ipairs(item.trackers or {}) do
            if tr.itemID or tr.currencyID or tr.achievementID then
              local n, need = NS.TrackerCount(tr), tr.need or 1
              st[#st + 1] = { text = tr.name or "?", done = n >= need, value = n .. " / " .. need }
              if #st >= 4 then break end
            end
          end
          if raid.bosses then st[#st + 1] = { text = raid.bosses } end
          return st
        end,
      }
    end
  end
  return out
end

function LegTracker_OpenPinned()
  local id = NS.GetPinID()
  if not id then return false end
  return NS.SelectItem(id)
end

-- ---------------------------------------------------------------- evenements
local gainPending = false
local function RequestGains()
  if gainPending then return end
  gainPending = true
  C_Timer.After(0.5, function() gainPending = false; pcall(UpdateGains) end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterEvent("ZONE_CHANGED")
ev:RegisterEvent("ZONE_CHANGED_INDOORS")
ev:RegisterEvent("ENCOUNTER_END")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
ev:RegisterEvent("QUEST_TURNED_IN")
ev:RegisterEvent("QUEST_ACCEPTED")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:RegisterEvent("CRITERIA_UPDATE")
ev:RegisterEvent("ACHIEVEMENT_EARNED")
ev:RegisterEvent("LOOT_READY")
ev:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
ev:SetScript("OnEvent", function(_, event, a1, a2, a3, a4, a5)
  if event == "PLAYER_LOGIN" then
    -- Seance laissee ouverte au dernier logout : reprise si recente,
    -- sinon close a la derniere presence.
    muteUntil = GetTime() + 5
    C_Timer.After(2, function()
      local id = NS.GetPinID()
      local rec = id and NS.FarmRec(id)
      local cur = rec and rec.cur
      if cur and time() - (cur.last or 0) > (GRACE[cur.kind] or 300) then
        pcall(CloseSession, rec, id, cur.last)
      elseif cur then
        cur.seen = nil   -- recalee sans gain par UpdateGains
      end
      NS.placeDirty = true
    end)
    C_Timer.After(5.5, function()
      local id = NS.GetPinID()
      local rec = id and NS.FarmRec(id)
      local item = id and NS.FindItem(id)
      if rec and rec.cur and item then rec.cur.seen = Snapshot(item) end
    end)
  elseif event == "PLAYER_LOGOUT" then
    local rec = NS.FarmRec(NS.GetPinID())
    if rec and rec.cur and placeKind then rec.cur.last = time() end
  elseif event == "ENCOUNTER_END" then
    local success = a5
    if Secret(success) or success ~= 1 then return end
    local rec = NS.FarmRec(NS.GetPinID())
    if rec and rec.cur and rec.cur.kind == "raid" and placeKind == "raid" then
      rec.cur.kills = (rec.cur.kills or 0) + 1
      Fire()
    end
  elseif event == "BAG_UPDATE_DELAYED" or event == "CURRENCY_DISPLAY_UPDATE"
      or event == "CRITERIA_UPDATE" or event == "ACHIEVEMENT_EARNED" then
    if NS.GetPinID() then RequestGains() end
  elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
    -- a1 = unite, a3 = sort. Peche : ID connu, ou meme nom de sort (rangs).
    local spellID = a3
    if a1 ~= "player" or Secret(spellID) then return end
    local fishing = spellID == FISHING_SPELL
    if not fishing and C_Spell and C_Spell.GetSpellName then
      local n, ref = C_Spell.GetSpellName(spellID), C_Spell.GetSpellName(FISHING_SPELL)
      fishing = n ~= nil and ref ~= nil and not Secret(n) and n == ref
    end
    if fishing then
      lastFish = GetTime()
      NS.placeDirty = true
    end
  elseif event == "LOOT_READY" then
    if IsFishingLoot and IsFishingLoot() then
      lastFish = GetTime()
      NS.placeDirty = true
    end
  elseif event == "QUEST_TURNED_IN" or event == "QUEST_ACCEPTED" then
    NS.placeDirty = true
    if NS.GetPinID() then Fire() end
  else
    NS.placeDirty = true
  end
end)

-- Partage en groupe de TibiSuite (7.3, lot C) : objet epingle du perso
-- connecte (itemID) ou nil. Lecture seule.
function LegTracker_PinnedItemID()
  return NS.GetPinID and NS.GetPinID() or nil
end
