-- ================================================================
--  LegTracker  -  LegOverlay.lua  (overlay du legendaire epingle)
--  Couche d'affichage seulement : lit la seance tenue par LegFarm.lua et les
--  donnees de LegTracker.lua (composants, quetes, verrouillages). Fenetre
--  ordinaire, aucun bouton securise, aucun UISpecialFrames. Meme gabarit que
--  l'overlay de peche de SkillTracker.
--
--  Reglages (LegTrackerDB, tous facultatifs, valeurs par defaut) :
--    overlay        true   overlay actif quand un legendaire est epingle
--    overlayAuto    true   visible seulement en seance (raid, zone de quete)
--    overlayCompact false  une seule ligne
--    overlayFade    true   estompe en combat (45 %)
--    overlayScale   100    echelle en %
--    overlayAlpha   92     opacite en %
--    overlayPos     nil    { point, relPoint, x, y }
--  Souris : glisser = deplacer, clic gauche = ouvrir LegTracker sur le
--  legendaire, clic droit = fermer (ou retirer l'epingle une fois obtenu),
--  clic sur la ligne de quete = point de route.
--  NON TESTE EN JEU : a valider par Tibiscui (nouveau fichier : redemarrage
--  complet du client).
-- ================================================================

local _, NS = ...
local UI = _G.TibiMidnight

local FR = (GetLocale and GetLocale() == "frFR")
local function T(fr, en) return FR and fr or en end

local ACC = { 1.000, 0.427, 0.043 }
local MIN_W, MAX_W = 240, 380
local LINE_H, ROW_H = 15, 19
local MAX_COMPS, MAX_OBJ = 5, 3

local OV = {
  pause     = T("pause", "paused"),
  outFmt    = T("Hors du lieu de farm · fin de séance dans %s", "Away from the farm spot · session ends in %s"),
  fishOutFmt= T("Pêche arrêtée · fin de séance dans %s", "Fishing stopped · session ends in %s"),
  fishWait  = T("Lance ta ligne pour démarrer (%s)", "Cast your line to start (%s)"),
  idle      = T("Pas de séance en cours", "No session in progress"),
  sessFmt   = T("séance %d", "session %d"),
  bossFmt   = T("%d boss", "%d boss(es)"),
  totalFmt  = T("Total %s en %d séance(s)", "Total %s in %d session(s)"),
  questFmt  = T("Quête %d/%d : %s", "Quest %d/%d: %s"),
  quest1Fmt = T("Quête : %s", "Quest: %s"),
  takeFmt   = T("À prendre : %s", "To pick up: %s"),
  questsOk  = T("Quêtes terminées", "Quests completed"),
  critLeft  = T("Encore à faire :", "Still to do:"),
  critDone  = T("Déjà fait : %d", "Already done: %d"),
  raids     = T("Raids :", "Raids:"),
  free      = T("libre", "free"),
  locked    = T("verrouillé", "locked"),
  doneFmt   = T("Obtenu après %s en %d séance(s) !", "Obtained after %s in %d session(s)!"),
  doneHint  = T("Clic droit : retirer l'épingle", "Right click: unpin"),
  move      = T("Glisser : déplacer", "Drag: move"),
  open      = T("Clic gauche : ouvrir LegTracker", "Left click: open LegTracker"),
  close     = T("Clic droit : fermer", "Right click: close"),
  wpHint    = T("Clic : point de route", "Click: waypoint"),
  closed    = T("Overlay de farm fermé. Pour le rouvrir : /lt overlay, ou les options de LegTracker.",
                "Farm overlay closed. To reopen it: /lt overlay, or the LegTracker options."),
  on        = T("Overlay de farm activé.", "Farm overlay enabled."),
  onAuto    = T("En mode auto, il s'affiche dans les raids et la zone de quête du légendaire épinglé.",
                "In auto mode it shows in the raids and quest zone of the pinned legendary."),
  off       = T("Overlay de farm désactivé.", "Farm overlay disabled."),
  noPin     = T("Épingle d'abord un légendaire (punaise du panneau détail, clic droit sur une ligne, ou /lt pin).",
                "Pin a legendary first (pin button in the detail panel, right click on a row, or /lt pin)."),
}
NS.OV = OV

-- ---------------------------------------------------------------- reglages
local function DB() return LegTrackerDB or {} end
local function Enabled() return DB().overlay ~= false end
local function Auto()    return DB().overlayAuto ~= false end
local function Compact() return DB().overlayCompact == true end
local function Fade()    return DB().overlayFade ~= false end
local function Crit()    return DB().overlayCriteria ~= false end
local function Scale()   return math.max(0.5, math.min(2, (DB().overlayScale or 100) / 100)) end
local function Alpha()   return math.max(0.2, math.min(1, (DB().overlayAlpha or 92) / 100)) end

local function Hex(c) return string.format("|cFF%02X%02X%02X", c[1] * 255, c[2] * 255, c[3] * 255) end
local ACC_HEX = Hex(ACC)
local DIM, GREEN, WHITE = "|cFF9A9AA0", "|cFF44FF44", "|cFFFFFFFF"
local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t"   -- coche (la police du jeu n'a pas de glyphe)

-- ---------------------------------------------------------------- fenetre
local f, built
local texts, comps = {}, {}
local seps = {}
local questBtn
local inCombat = false

local function NewText(template)
  local t = f:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
  t:SetJustifyH("LEFT")
  t:SetWordWrap(false)
  return t
end

local function GetTextLine(i)
  local t = texts[i]
  if not t then t = NewText(); texts[i] = t end
  return t
end

local function GetSep(i)
  local s = seps[i]
  if not s then
    s = f:CreateTexture(nil, "ARTWORK")
    local c = (UI and UI.C and UI.C.SEP) or { 1, 1, 1, 0.1 }
    s:SetColorTexture(c[1], c[2], c[3], c[4] or 0.1)
    s:SetHeight(1)
    seps[i] = s
  end
  return s
end

local function ShowCompTooltip(owner, c)
  if not c then return end
  local tr = c.tr
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  if tr.achievementID then
    GameTooltip:SetText(c.name, ACC[1], ACC[2], ACC[3])
    GameTooltip:AddLine(c.have .. " / " .. c.need, 1, 1, 1)
    local miss = c.missing
    if miss and #miss > 0 then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(OV.critLeft, 0.95, 0.78, 0.35)
      for i = 1, math.min(#miss, 25) do
        local cr = miss[i]
        local qty = ((tonumber(cr.req) or 0) > 1) and ("  " .. (cr.q or 0) .. "/" .. cr.req) or ""
        GameTooltip:AddLine("  " .. cr.name .. qty, 1, 1, 1)
      end
    end
    if (c.doneN or 0) > 0 then
      GameTooltip:AddLine(string.format(OV.critDone, c.doneN), 0.6, 0.6, 0.65)
    end
  elseif tr.currencyID then
    GameTooltip:SetCurrencyByID(tr.currencyID)
  elseif tr.itemID then
    GameTooltip:SetItemByID(tr.itemID)
  end
  GameTooltip:Show()
end

local function GetComp(i)
  local r = comps[i]
  if r then return r end
  r = {}
  r.icon = f:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(14, 14)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.name = NewText()
  r.count = NewText()
  r.count:SetJustifyH("RIGHT")
  r.barBg = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  r.barBg:SetColorTexture(1, 1, 1, 0.08)
  r.barBg:SetHeight(2)
  r.bar = f:CreateTexture(nil, "ARTWORK")
  r.bar:SetHeight(2)
  -- Survol de la ligne : criteres restants d'un haut fait, sinon l'infobulle
  -- de l'objet ou de la monnaie. Clics et glisser renvoyes a l'overlay.
  r.hit = CreateFrame("Button", nil, f)
  r.hit:SetHeight(ROW_H)
  r.hit:RegisterForDrag("LeftButton")
  r.hit:SetScript("OnDragStart", function() f:GetScript("OnDragStart")(f) end)
  r.hit:SetScript("OnDragStop", function() f:GetScript("OnDragStop")(f) end)
  r.hit:SetScript("OnMouseDown", function(_, b) f:GetScript("OnMouseDown")(f, b) end)
  r.hit:SetScript("OnMouseUp", function(_, b) f:GetScript("OnMouseUp")(f, b) end)
  r.hit:SetScript("OnEnter", function(s) ShowCompTooltip(s, s.c) end)
  r.hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
  r.hit:Hide()
  comps[i] = r
  return r
end

local function Place()
  if not f then return end
  f:ClearAllPoints()
  local p = DB().overlayPos
  if type(p) == "table" and p[1] then
    f:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
  else
    f:SetPoint("RIGHT", UIParent, "RIGHT", -40, -80)
  end
end

local function ApplyLook()
  if not f then return end
  f:SetScale(Scale())
  f:SetAlpha(Alpha() * ((inCombat and Fade()) and 0.45 or 1))
  Place()
end

local function Build()
  if built or not UI then return end
  built = true
  f = CreateFrame("Frame", "LegTrackerOverlay", UIParent, "BackdropTemplate")
  f:SetSize(MIN_W, 100)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:Hide()
  UI.SkinFrame(f, ACC, UI.C.PANEL)

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.title:SetPoint("TOPLEFT", 10, -9)
  f.title:SetTextColor(ACC[1], ACC[2], ACC[3])
  f.title:SetWordWrap(false)
  f.state = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.state:SetPoint("LEFT", f.title, "RIGHT", 6, 0)
  f.time = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.time:SetPoint("TOPRIGHT", -10, -7)

  questBtn = CreateFrame("Button", nil, f)
  questBtn:SetHeight(LINE_H)
  questBtn:RegisterForClicks("LeftButtonUp")
  questBtn:SetScript("OnClick", function(s) if s.q and NS.AddWaypoint then NS.AddWaypoint(s.q) end end)
  questBtn:SetScript("OnEnter", function(s)
    if not s.q then return end
    GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
    GameTooltip:SetText(s.q.name or "?", 0.30, 0.60, 1.0)
    if s.q.npc then GameTooltip:AddLine(s.q.npc .. (s.q.zone and (" · " .. s.q.zone) or ""), 0.85, 0.85, 0.9) end
    if s.q.mapID then GameTooltip:AddLine(OV.wpHint, 0.85, 0.85, 0.9) end
    GameTooltip:Show()
  end)
  questBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Glisser = deplacer ; clic gauche sans deplacement = ouvrir la fenetre.
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint(1)
    if p and LegTrackerDB then LegTrackerDB.overlayPos = { p, rp or p, x, y } end
  end)
  f:SetScript("OnMouseDown", function(self)
    self._downX, self._downY = GetCursorPosition()
  end)
  f:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" then
      GameTooltip:Hide()
      local rec = NS.FarmRec and NS.FarmRec(NS.GetPinID())
      if rec and rec.doneAt then
        NS.Unpin(true)
      else
        NS.OverlaySetEnabled(false)
        print(NS.PREFIX .. OV.closed)
      end
      return
    end
    if button == "LeftButton" then
      local x, y = GetCursorPosition()
      local dx, dy = (x or 0) - (self._downX or 0), (y or 0) - (self._downY or 0)
      if dx * dx + dy * dy < 25 then
        GameTooltip:Hide()
        local id = NS.GetPinID()
        if id and NS.SelectItem then NS.SelectItem(id) end
      end
    end
  end)
  f:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("LegTracker", ACC[1], ACC[2], ACC[3])
    GameTooltip:AddLine(OV.move, 0.85, 0.85, 0.9)
    GameTooltip:AddLine(OV.open, 0.85, 0.85, 0.9)
    GameTooltip:AddLine(OV.close, 0.85, 0.85, 0.9)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- ---------------------------------------------------------------- contenu
-- Donnees lourdes (scan, compteurs, objectifs, verrouillages) : recalculees
-- sur evenement ou toutes les 5 s. Le chronometre seul bouge chaque seconde.
local data, dataAt, dirty = nil, 0, true

local function TrackerName(tr)
  if tr.name then return tr.name end
  if tr.itemID and C_Item and C_Item.GetItemNameByID then
    local n = C_Item.GetItemNameByID(tr.itemID)
    if n then return n end
  end
  if tr.currencyID and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
    local info = C_CurrencyInfo.GetCurrencyInfo(tr.currencyID)
    if info and info.name then return info.name end
  end
  return "#" .. tostring(tr.itemID or tr.currencyID or "?")
end

local function Objectives(questID)
  local out = {}
  if not (questID and C_QuestLog and C_QuestLog.GetQuestObjectives) then return out end
  local ok, list = pcall(C_QuestLog.GetQuestObjectives, questID)
  if not ok or type(list) ~= "table" then return out end
  for _, o in ipairs(list) do
    local txt = o.text
    if txt and not (issecretvalue and issecretvalue(txt)) and txt ~= "" then
      out[#out + 1] = { text = txt, done = o.finished and true or false }
      if #out >= MAX_OBJ then break end
    end
  end
  return out
end

local function Collect()
  local id = NS.GetPinID()
  local item = id and NS.FindItem(id)
  if not item then data = nil return end
  local d = { item = item, rec = NS.FarmRec(id, true), comps = {}, raids = {} }
  for _, tr in ipairs(item.trackers or {}) do
    local key = NS.TrKey(tr)
    if key then
      local c = { tr = tr, key = key, name = TrackerName(tr), have = NS.TrackerCount(tr),
                  need = tr.need or 1, icon = NS.GetTrackerIcon(tr) }
      -- Haut fait en cours (etape d'obtention) : ses criteres manquants
      if tr.achievementID and c.have < c.need and Crit() and NS.CriteriaList then
        c.missing, c.doneN = {}, 0
        for _, cr in ipairs(NS.CriteriaList(tr.achievementID)) do
          if cr.done then c.doneN = c.doneN + 1 else c.missing[#c.missing + 1] = cr end
        end
      end
      d.comps[#d.comps + 1] = c
      if #d.comps >= MAX_COMPS then break end
    end
  end
  local _, qDone, qTotal, _, _, _, step, onQuest = NS.Scan(item)
  d.qDone, d.qTotal, d.step, d.onQuest = qDone or 0, qTotal or 0, step, onQuest
  d.q = step and item.quests and item.quests[step] or nil
  d.obj = (d.q and onQuest) and Objectives(d.q.id) or {}
  for _, raid in ipairs(item.raids or {}) do
    d.raids[#d.raids + 1] = { name = NS.RaidName(raid), locked = #NS.GetRaidLockouts(raid.instanceID) > 0 }
  end
  d.est = NS.Estimate(item, d.rec)
  data, dataAt, dirty = d, GetTime(), false
end

local previewUntil = 0
local errShown = false

local function ShouldShow()
  if not Enabled() then return false end
  local id = NS.GetPinID()
  if not id then return false end
  if not Auto() then return true end
  if GetTime() < previewUntil then return true end
  local rec = NS.FarmRec(id)
  return rec and (rec.cur or rec.doneAt) and true or false
end

-- Lignes de texte : { text } ; separateurs : { sep = true } ;
-- composants : { comp = c } ; quete : { text, quest = q }.
local function BuildEntries(d)
  local e = {}
  local rec, cur = d.rec, d.rec and d.rec.cur
  if rec.doneAt then
    e[#e + 1] = { text = GREEN .. string.format(OV.doneFmt, NS.HM(rec.total or 0), NS.SessionCount(rec)) .. "|r" }
    e[#e + 1] = { text = DIM .. OV.doneHint .. "|r" }
    return e
  end
  -- Lieu et seance
  if cur then
    local kind = NS.CurrentPlace()
    if kind then
      local s = (cur.place or "?") .. "  " .. DIM .. "·|r  " .. string.format(OV.sessFmt, NS.SessionCount(rec))
      if cur.kind == "raid" then s = s .. "  " .. DIM .. "·|r  " .. string.format(OV.bossFmt, cur.kills or 0) end
      e[#e + 1] = { text = s }
    else
      local left = NS.GraceLeft()
      local fmt = (cur.kind == "fish") and OV.fishOutFmt or OV.outFmt
      e[#e + 1] = { text = DIM .. string.format(fmt, NS.Clock(left or 0)) .. "|r" }
    end
  else
    local fishing = d.item.farm and d.item.farm.fishing
    local idle = fishing and string.format(OV.fishWait, d.item.farm.label or "?") or OV.idle
    e[#e + 1] = { text = DIM .. idle .. "|r" }
  end
  -- Cumul et estimation
  local tot = NS.TotalTime(rec)
  if tot >= 60 or d.est then
    local s = DIM .. string.format(OV.totalFmt, NS.HM(tot), NS.SessionCount(rec))
    local efmt = (d.item.farm and d.item.farm.fishing) and NS.FT.estFishFmt or NS.FT.estFmt
    if d.est then s = s .. "  ·  |r" .. ACC_HEX .. string.format(efmt, d.est) end
    e[#e + 1] = { text = s .. "|r" }
  end
  -- Composants
  if #d.comps > 0 then
    e[#e + 1] = { sep = true }
    for _, c in ipairs(d.comps) do e[#e + 1] = { comp = c, gain = cur and cur.gains and cur.gains[c.key] } end
  end
  -- Quete
  if d.qTotal > 0 then
    e[#e + 1] = { sep = true }
    if d.q then
      local title = (d.qTotal > 1) and string.format(OV.questFmt, d.step, d.qTotal, d.q.name or "?")
                    or string.format(OV.quest1Fmt, d.q.name or "?")
      e[#e + 1] = { text = "|cFF4D99FF" .. title .. "|r", quest = d.q }
      if d.onQuest then
        for _, o in ipairs(d.obj) do
          e[#e + 1] = { text = "   " .. (o.done and GREEN or WHITE) .. "· " .. o.text .. "|r" }
        end
      else
        local who = d.q.npc and (d.q.npc .. (d.q.zone and (", " .. d.q.zone) or "")) or (d.q.zone or "?")
        e[#e + 1] = { text = "   " .. DIM .. string.format(OV.takeFmt, who) .. "|r" }
      end
    else
      e[#e + 1] = { text = GREEN .. OV.questsOk .. "|r" }
    end
  end
  -- Raids de la semaine
  if #d.raids > 0 then
    local parts = {}
    for _, r in ipairs(d.raids) do
      parts[#parts + 1] = r.name .. " " .. (r.locked and ("|cFFFF8800" .. OV.locked .. "|r") or (GREEN .. OV.free .. "|r"))
    end
    e[#e + 1] = { text = DIM .. OV.raids .. "|r " .. table.concat(parts, DIM .. "  ·  |r") }
  end
  return e
end

-- Composant le moins avance (mode compact)
local function WorstComp(d)
  local worst, wr
  for _, c in ipairs(d.comps) do
    local r = c.have / c.need
    if r < 1 and (not wr or r < wr) then worst, wr = c, r end
  end
  return worst
end

local function Render()
  if not (f and data) then return end
  local d = data
  local rec = d.rec
  local cur = rec.cur
  local compact = Compact()
  local paused = cur and cur.paused
  local tsec = cur and (cur.active or 0) or NS.TotalTime(rec)
  local tcol = (cur and not paused) and WHITE or "|cFF8C8C94"

  -- Tout masquer, puis placer ce qui sert
  for _, t in ipairs(texts) do t:Hide() end
  for _, s in ipairs(seps) do s:Hide() end
  for _, r in ipairs(comps) do r.icon:Hide(); r.name:Hide(); r.count:Hide(); r.barBg:Hide(); r.bar:Hide(); r.hit:Hide(); r.hit.c = nil end
  questBtn:Hide(); questBtn.q = nil

  if compact then
    f.title:Hide(); f.state:Hide()
    local parts = { ACC_HEX .. NS.ShortName(d.item) .. "|r" }
    if rec.doneAt then
      parts[#parts + 1] = CHECK
    else
      local w = WorstComp(d)
      if w then parts[#parts + 1] = w.have .. "/" .. w.need .. " " .. w.name end
      parts[#parts + 1] = tcol .. NS.Clock(tsec) .. "|r"
    end
    f.time:ClearAllPoints()
    f.time:SetPoint("LEFT", f, "LEFT", 10, 0)
    f.time:SetFontObject("GameFontHighlightSmall")
    f.time:SetText(table.concat(parts, "  " .. DIM .. "·|r  "))
    local w = math.ceil(f.time:GetStringWidth() + 22)
    f:SetSize(math.max(120, w), 28)
    return
  end

  f.title:Show(); f.state:Show()
  f.title:SetText(NS.ShortName(d.item))
  f.state:SetText(paused and ("|cFF8C8C94(" .. OV.pause .. ")|r") or "")
  f.time:ClearAllPoints()
  f.time:SetPoint("TOPRIGHT", -10, -7)
  f.time:SetFontObject("GameFontNormalLarge")
  f.time:SetText(rec.doneAt and "" or (tcol .. NS.Clock(tsec) .. "|r"))

  local width = math.max(MIN_W, f.title:GetStringWidth() + f.state:GetStringWidth() + f.time:GetStringWidth() + 44)
  local y = 30
  local nt, ns, nc = 0, 0, 0
  for _, en in ipairs(BuildEntries(d)) do
    if en.sep then
      ns = ns + 1
      local s = GetSep(ns)
      s:ClearAllPoints()
      s:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -(y + 3))
      s:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -(y + 3))
      s:Show()
      y = y + 7
    elseif en.comp then
      nc = nc + 1
      local r, c = GetComp(nc), en.comp
      local full = c.have >= c.need
      r.icon:ClearAllPoints(); r.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -(y + 1))
      r.icon:SetTexture(c.icon); r.icon:Show()
      r.name:ClearAllPoints(); r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
      r.name:SetText((full and GREEN or WHITE) .. c.name .. "|r"); r.name:Show()
      local cnt = (full and GREEN or WHITE) .. math.min(c.have, 9999) .. " / " .. c.need .. "|r"
      if en.gain and en.gain > 0 then cnt = cnt .. "  " .. ACC_HEX .. "(+" .. en.gain .. ")|r" end
      if full then cnt = cnt .. " " .. CHECK end
      r.count:ClearAllPoints(); r.count:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -(y + 2))
      r.count:SetText(cnt); r.count:Show()
      r.barBg:ClearAllPoints()
      r.barBg:SetPoint("TOPLEFT", f, "TOPLEFT", 30, -(y + 16))
      r.barBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -(y + 16))
      r.barBg:Show()
      local p = math.max(0, math.min(1, c.have / c.need))
      r.bar:ClearAllPoints()
      r.bar:SetPoint("TOPLEFT", r.barBg, "TOPLEFT", 0, 0)
      r.bar:SetColorTexture(full and 0.27 or ACC[1], full and 1 or ACC[2], full and 0.27 or ACC[3], 0.9)
      r._p = p
      r.bar:SetShown(p > 0)
      width = math.max(width, 10 + 14 + 6 + r.name:GetStringWidth() + 16 + r.count:GetStringWidth() + 10)
      r.hit.c = c
      r.hit:ClearAllPoints()
      r.hit:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -y)
      r.hit:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -y)
      r.hit:Show()
      y = y + ROW_H
    else
      nt = nt + 1
      local t = GetTextLine(nt)
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -y)
      t:SetText(en.text); t:Show()
      width = math.max(width, t:GetStringWidth() + 22)
      if en.quest then
        questBtn.q = en.quest
        questBtn:ClearAllPoints()
        questBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -(y - 1))
        questBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -(y - 1))
        questBtn:Show()
      end
      y = y + LINE_H
    end
  end
  width = math.min(MAX_W, math.ceil(width))
  f.title:SetWidth(math.max(60, math.min(f.title:GetStringWidth() + 2, width - f.state:GetStringWidth() - f.time:GetStringWidth() - 40)))
  for _, t in ipairs(texts) do if t:IsShown() then t:SetWidth(width - 20) end end
  f:SetSize(width, y + 8)
  -- Barres : largeur connue seulement une fois la fenetre dimensionnee
  for i = 1, nc do
    local r = comps[i]
    r.bar:SetWidth(math.max(1, (width - 40) * (r._p or 0)))
  end
end

-- look : reapplique taille, opacite et position (jamais a chaque seconde :
-- re-ancrer la fenetre pendant un glisser la ferait sauter).
local function Refresh(look)
  if not UI then return end
  if not ShouldShow() then
    if f then f:Hide() end
    return
  end
  Build()
  if not f then return end
  if dirty or not data or GetTime() - dataAt > 5 then Collect() end
  if not data then f:Hide() return end
  if look or not f:IsShown() then ApplyLook() end
  f:Show()
  Render()
end

-- ---------------------------------------------------------------- API
function NS.OverlayUpdate(full, look)
  if full then dirty = true end
  local ok, err = pcall(Refresh, look)
  if not ok and not errShown then
    errShown = true
    print(NS.PREFIX .. T("Erreur de l'overlay de farm : ", "Farm overlay error: ") .. tostring(err))
  end
end

-- Apercu de 20 s (epingle posee, legendaire obtenu, overlay active)
function NS.OverlayPreview()
  previewUntil = GetTime() + 20
  NS.OverlayUpdate(true)
end

function NS.OverlaySetEnabled(v)
  if LegTrackerDB then LegTrackerDB.overlay = v and true or false end
  if v then previewUntil = GetTime() + 20 end
  NS.OverlayUpdate(true)
end

function NS.OverlayToggle()
  if not NS.GetPinID() then
    if LegTrackerDB then LegTrackerDB.overlay = true end
    print(NS.PREFIX .. OV.noPin)
    return
  end
  NS.OverlaySetEnabled(not Enabled())
  if Enabled() then
    print(NS.PREFIX .. OV.on .. (Auto() and (" " .. OV.onAuto) or ""))
  else
    print(NS.PREFIX .. OV.off)
  end
end

function NS.OverlayResetPos()
  if LegTrackerDB then LegTrackerDB.overlayPos = nil end
  NS.OverlayUpdate(false, true)
end

-- Reglage d'aspect change (options) : taille, opacite, mode compact
function NS.OverlayRelook() NS.OverlayUpdate(true, true) end

NS.OnFarmChanged(function() NS.OverlayUpdate(true) end)

-- ---------------------------------------------------------------- vie
local acc = 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, dt)
  acc = acc + dt
  if acc < 1 then return end
  acc = 0
  if not NS.GetPinID() then
    if f and f:IsShown() then f:Hide() end
    return
  end
  -- Apparition / disparition en mode auto (seance ouverte ou close)
  if (f and f:IsShown()) or ShouldShow() then NS.OverlayUpdate(false) end
end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("QUEST_LOG_UPDATE")
ev:RegisterEvent("UPDATE_INSTANCE_INFO")
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
local pending = false
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    C_Timer.After(3, function() NS.OverlayUpdate(true) end)
  elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
    inCombat = (event == "PLAYER_REGEN_DISABLED")
    if f and f:IsShown() then f:SetAlpha(Alpha() * ((inCombat and Fade()) and 0.45 or 1)) end
  elseif f and f:IsShown() and not pending then
    -- Rafale d'evenements : un seul recalcul groupe.
    pending = true
    C_Timer.After(0.5, function() pending = false; NS.OverlayUpdate(true) end)
  end
end)
