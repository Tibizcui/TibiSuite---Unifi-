-- ================================================================
--  SkillTracker  -  FishOverlay.lua  (overlay de session de peche)
--  Couche d'affichage : lit la session deja suivie par Fishing.lua
--  (SkillTrackerDB.fish.cur) et ne compte aucune prise lui-meme. Lecture
--  seule cote jeu : fenetre ordinaire, aucun bouton securise, aucun
--  UISpecialFrames.
--
--  TEMPS ACTIF : l'horloge de l'overlay ne tourne que pendant la peche (une
--  incantation ou une prise dans les 90 dernieres secondes). Quand tu t'arretes,
--  elle se fige (mention "pause") et les rythmes par heure ne se diluent plus.
--  Le temps actif est garde dans la session : s.active (secondes).
--
--  Reglages (ST.settings, tous facultatifs, valeurs par defaut ci-dessous) :
--    fishOverlay        false  overlay actif
--    fishOverlayAuto    true   visible seulement pendant la peche
--    fishOverlayCompact false  une seule ligne
--    fishOverlayScale   100    echelle en %
--    fishOverlayAlpha   92     opacite en %
--    fishOverlayPos     nil    { point, relPoint, x, y }
--  Deplacement : clic gauche maintenu, puis glisser. Fermeture : clic droit.
--  NON TESTE EN JEU : a valider par Tibiscui (nouveau fichier : redemarrage
--  complet du client).
-- ================================================================

local _, ST = ...
local UI = _G.TibiMidnight

local FR = (GetLocale and GetLocale() == "frFR")
local function T(fr, en) return FR and fr or en end

-- Textes (ST.FishText existe deja : Fishing.lua se charge avant ce fichier).
local FT = ST.FishText or {}
ST.FishText = FT
FT.ovSection  = T("Overlay de pêche", "Fishing overlay")
FT.ovNote     = T("Petite fenêtre en direct : durée active, prises, rythme, valeur, zone et objets les plus nombreux de la session en cours. Clic gauche pour la déplacer, clic droit pour la fermer.",
                  "Small live window: active time, catches, rate, value, zone and most numerous items of the current session. Left click to move it, right click to close it.")
FT.ovOpt      = T("Afficher l'overlay de pêche", "Show the fishing overlay")
FT.ovOptTT    = T("Sur l'overlay : clic gauche maintenu puis glisser pour le déplacer, clic droit pour le fermer. Pour le rouvrir : cette case ou /skt peche overlay.",
                  "On the overlay: hold left click then drag to move it, right click to close it. To reopen it: this box or /skt peche overlay.")
FT.ovAuto     = T("Afficher seulement pendant la pêche", "Show only while fishing")
FT.ovCompact  = T("Mode compact (une seule ligne)", "Compact mode (single line)")
FT.ovScale    = T("Taille de l'overlay (%)", "Overlay size (%)")
FT.ovAlpha    = T("Opacité de l'overlay (%)", "Overlay opacity (%)")
FT.ovReset    = T("Remettre l'overlay à sa place", "Reset the overlay position")
FT.ovSlash    = T("afficher / masquer l'overlay de pêche", "show / hide the fishing overlay")
local OV = {
  title   = T("Pêche", "Fishing"),
  waiting = T("En attente de la première prise", "Waiting for the first catch"),
  noSess  = T("Aucune session en cours", "No session in progress"),
  move    = T("Clic gauche : déplacer", "Left click: move"),
  close   = T("Clic droit : fermer", "Right click: close"),
  stats   = T("%d prises  ·  %d / h", "%d catches  ·  %d / h"),
  statsNo = T("%d prises", "%d catches"),
  value   = T("Valeur", "Value"),
  rate    = T("Rythme", "Rate"),
  perH    = T("/ h", "/ h"),
  sound   = T("sons", "sound"),
  pause   = T("pause", "paused"),
}

local ACC = ST.COLOR or { 0.0, 1.0, 0.596 }
local MIN_W = 210
local LINE_H = 15
local ROW_H = 17
local MAX_ROWS = 3
local CAST_WINDOW = 120   -- apres une incantation, l'overlay reste visible 2 min
local PAUSE_AFTER = 90    -- sans lancer ni prise depuis 90 s : l'horloge se fige

-- ---------------------------------------------------------------- reglages
local function S() return ST.settings or {} end
local function Enabled() return S().fishOverlay == true end
local function Auto()    return S().fishOverlayAuto ~= false end
local function Compact() return S().fishOverlayCompact == true end
local function Scale()   return math.max(0.5, math.min(2, (S().fishOverlayScale or 100) / 100)) end
local function Alpha()   return math.max(0.2, math.min(1, (S().fishOverlayAlpha or 92) / 100)) end

-- ---------------------------------------------------------------- outils
local function Dur(sec)
  sec = math.max(0, math.floor(sec or 0))
  local h, m, s = math.floor(sec / 3600), math.floor(sec / 60) % 60, sec % 60
  if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
  return string.format("%02d:%02d", m, s)
end

local function Money(c)
  if ST.Prices and ST.Prices.Money then return ST.Prices.Money(c) end
  return tostring(math.floor((c or 0) / 10000)) .. " po"
end

local function ItemName(id)
  local n
  if C_Item and C_Item.GetItemNameByID then n = C_Item.GetItemNameByID(id) end
  if not n and GetItemInfo then n = (GetItemInfo(id)) end
  if not n and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  return n
end

local function ItemIcon(id)
  if C_Item and C_Item.GetItemIconByID then
    local ok, ic = pcall(C_Item.GetItemIconByID, id)
    if ok and ic then return ic end
  end
  if GetItemIcon then local ok, ic = pcall(GetItemIcon, id); if ok then return ic end end
  return 134400   -- point d'interrogation
end

-- Lieu actuel "Zone · Sous-zone" (meme forme que les coins de peche).
local function CurrentPlace()
  local z = GetZoneText and GetZoneText()
  if not z or z == "" then return nil end
  if issecretvalue and issecretvalue(z) then return nil end
  local sz = GetSubZoneText and GetSubZoneText()
  if sz and sz ~= "" and sz ~= z and not (issecretvalue and issecretvalue(sz)) then return z .. " · " .. sz end
  return z
end

-- Epoch de la derniere activite de peche (prise ou incantation).
local function LastActivity(s)
  local a = s.last or s.start or time()
  if ST.FishLastCast then
    local ce = time() - (GetTime() - ST.FishLastCast)
    if ce > a then a = ce end
  end
  return a
end

-- ---------------------------------------------------------------- fenetre
local f, built
local rows = {}
local cache = { value = 0, top = {} }

local function Build()
  if built or not UI then return end
  built = true
  f = CreateFrame("Frame", "SkillTrackerFishOverlay", UIParent, "BackdropTemplate")
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
  f.title:SetText(OV.title)

  f.snd = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.snd:SetPoint("LEFT", f.title, "RIGHT", 6, 0)

  f.time = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.time:SetPoint("TOPRIGHT", -10, -7)

  local function line()
    local l = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    l:SetJustifyH("LEFT")
    l:SetWordWrap(false)
    return l
  end
  f.line1, f.line2, f.line3 = line(), line(), line()
  f.zone = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.zone:SetJustifyH("LEFT")
  f.zone:SetWordWrap(false)

  f.sep = f:CreateTexture(nil, "ARTWORK")
  f.sep:SetColorTexture(UI.C.SEP[1], UI.C.SEP[2], UI.C.SEP[3], UI.C.SEP[4])
  f.sep:SetHeight(1)

  for i = 1, MAX_ROWS do
    local r = {}
    r.icon = f:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(14, 14)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.txt = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.txt:SetJustifyH("LEFT")
    r.txt:SetWordWrap(false)
    -- Zone de survol de la ligne : meme infobulle de prix que les noeuds de
    -- recolte (nom, prix HV ou vendeur, source et age du prix), plus la prise
    -- de la session. Glisser et clic droit restent ceux de la fenetre.
    r.hit = CreateFrame("Button", nil, f)
    r.hit:SetHeight(ROW_H)
    r.hit:RegisterForDrag("LeftButton")
    r.hit:SetScript("OnDragStart", function() local fn = f:GetScript("OnDragStart"); if fn then fn(f) end end)
    r.hit:SetScript("OnDragStop", function() local fn = f:GetScript("OnDragStop"); if fn then fn(f) end end)
    r.hit:SetScript("OnMouseUp", function(_, button) local fn = f:GetScript("OnMouseUp"); if fn then fn(f, button) end end)
    r.hit:SetScript("OnEnter", function(self)
      if not (GameTooltip and r.id) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      local name = ItemName(r.id) or ("#" .. tostring(r.id))
      local q = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(r.id)
      local qc = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
      -- Compact : une ligne par prix, libelle court a gauche, montant a droite.
      GameTooltip:SetText(name, qc and qc.r or 1, qc and qc.g or 0.82, qc and qc.b or 0)
      local P = ST.Prices or {}
      local ah, _, age
      if P.AH then ah, _, age = P.AH(r.id) end
      local vendor = P.Vendor and P.Vendor(r.id)
      local grey = 0.62
      if ah then
        local lbl = T("Hôtel des ventes", "Auction House")
        if type(age) == "number" and age >= 1 then lbl = lbl .. string.format(T(" · %d j", " · %d d"), age) end
        GameTooltip:AddDoubleLine(lbl, Money(ah), grey, grey, grey + 0.03, 1, 1, 1)
      end
      if vendor and vendor > 0 then
        GameTooltip:AddDoubleLine(T("Vendeur", "Vendor"), Money(vendor), grey, grey, grey + 0.03, 1, 1, 1)
      end
      local unit = ST.UnitPrice and ST.UnitPrice(r.id) or 0
      GameTooltip:AddDoubleLine(string.format(T("Session · x%d", "Session · x%d"), r.q or 0),
        (unit > 0) and Money(unit * (r.q or 0)) or "-", ACC[1], ACC[2], ACC[3], 1, 1, 1)
      GameTooltip:Show()
    end)
    r.hit:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    r.hit:Hide()
    rows[i] = r
  end

  -- Deplacement : clic gauche maintenu, puis glisser.
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint(1)
    if p and ST.settings then ST.settings.fishOverlayPos = { p, rp or p, x, y } end
  end)
  -- Clic droit : ferme l'overlay (l'option est decochee ; /skt peche overlay ou
  -- les options le rouvrent).
  f:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then
      if GameTooltip then GameTooltip:Hide() end
      ST.FishOverlaySetEnabled(false)
      print(ST.TAG .. " " .. T("Overlay de pêche fermé. Pour le rouvrir : /skt peche overlay, ou les options de SkillTracker.",
        "Fishing overlay closed. To reopen it: /skt peche overlay, or the SkillTracker options."))
    end
  end)
  f:SetScript("OnEnter", function(self)
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
      GameTooltip:SetText(OV.title, ACC[1], ACC[2], ACC[3])
      GameTooltip:AddLine(OV.move, 0.85, 0.85, 0.9)
      GameTooltip:AddLine(OV.close, 0.85, 0.85, 0.9)
      GameTooltip:Show()
    end
  end)
  f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

local function Place()
  if not f then return end
  f:ClearAllPoints()
  local p = S().fishOverlayPos
  if type(p) == "table" and p[1] then
    f:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
  else
    f:SetPoint("RIGHT", UIParent, "RIGHT", -40, 120)
  end
end

local function ApplyLook()
  if not f then return end
  f:SetScale(Scale())
  f:SetAlpha(Alpha())
  Place()
end

-- ---------------------------------------------------------------- contenu
local function Collect(s)
  cache.value = (s and ST.ItemsValue) and ST.ItemsValue(s.items) or 0
  local list = {}
  if s then
    for id, q in pairs(s.items or {}) do list[#list + 1] = { id = tonumber(id), q = q } end
    table.sort(list, function(a, b) if a.q ~= b.q then return a.q > b.q end return (a.id or 0) < (b.id or 0) end)
  end
  cache.top = list
end

local function Session()
  if ST.FishActive then return ST.FishActive() end
end

local previewUntil = 0   -- apercu de 20 s quand on active l'overlay (mode auto)
local errShown = false

local function ShouldShow(s)
  if not Enabled() then return false end
  if not Auto() then return true end
  if GetTime() < previewUntil then return true end
  if s then return true end
  return ST.FishLastCast and (GetTime() - ST.FishLastCast) <= CAST_WINDOW or false
end

-- Largeur : la fenetre epouse le texte le plus long (rien ne depasse).
local function FitWidth()
  if not f then return end
  local w
  if Compact() then
    w = f.time:GetStringWidth() + 24
  else
    w = MIN_W
    local function m(x) if x and x > w then w = x end end
    m(f.title:GetStringWidth() + f.snd:GetStringWidth() + f.time:GetStringWidth() + 44)
    for _, l in ipairs({ f.line1, f.line2, f.line3, f.zone }) do
      if l:IsShown() then m(l:GetStringWidth() + 22) end
    end
    for i = 1, MAX_ROWS do
      local r = rows[i]
      if r.txt:IsShown() then m(10 + 14 + 6 + r.txt:GetStringWidth() + 14) end
    end
  end
  w = math.ceil(w)
  if math.abs(w - f:GetWidth()) > 1 then f:SetWidth(w) end
end

local function Layout(s)
  if not f then return end
  local compact = Compact()
  local showRows = (not compact) and s and #cache.top > 0
  f.title:SetShown(not compact)
  f.snd:SetShown(not compact)
  f.sep:SetShown(showRows and true or false)

  f.time:ClearAllPoints()
  local h
  if compact then
    f.time:SetPoint("LEFT", f, "LEFT", 10, 0)
    f.line1:Hide(); f.line2:Hide(); f.line3:Hide(); f.zone:Hide()
    h = 30
  else
    f.time:SetPoint("TOPRIGHT", -10, -7)
    local prev, n = nil, 0
    for _, l in ipairs({ f.line1, f.line2, f.line3, f.zone }) do
      if l:IsShown() then
        l:ClearAllPoints()
        if prev then l:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -3)
        else l:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -30) end
        prev = l; n = n + 1
      end
    end
    h = 30 + n * LINE_H + 2
  end

  local last = 0
  for i = 1, MAX_ROWS do
    local r, e = rows[i], cache.top[i]
    if showRows and e then
      r.icon:ClearAllPoints()
      r.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -(h + 4 + (i - 1) * ROW_H))
      r.txt:ClearAllPoints()
      r.txt:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
      r.icon:SetTexture(ItemIcon(e.id)); r.icon:Show()
      r.txt:SetText("|cFFFFFFFFx" .. e.q .. "|r  " .. (ItemName(e.id) or ("#" .. tostring(e.id)))); r.txt:Show()
      r.id, r.q = e.id, e.q
      r.hit:ClearAllPoints()
      r.hit:SetPoint("LEFT", r.icon, "LEFT", -2, 0)
      r.hit:SetPoint("RIGHT", f, "RIGHT", -8, 0)
      r.hit:Show()
      last = i
    else
      r.icon:Hide(); r.txt:Hide(); r.hit:Hide()
      r.id, r.q = nil, nil
    end
  end
  if showRows then
    f.sep:ClearAllPoints()
    f.sep:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -h)
    f.sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -h)
    h = h + 4 + last * ROW_H
  end
  f:SetHeight(h + 8)
  f._key = (s and 1 or 0) + (f.line3:IsShown() and 2 or 0) + (f.zone:IsShown() and 4 or 0) + (compact and 8 or 0)
end

-- Suivi du temps actif : cumule dans s.active tant que la peche est en cours.
local tracked, lastT
local function Active(s)
  if s ~= tracked then tracked = s; lastT = time() end
  s.active = s.active or math.max(0, (s.last or s.start or time()) - (s.start or time()))
  local now = time()
  local dt = now - (lastT or now)
  lastT = now
  local paused = (now - LastActivity(s)) > PAUSE_AFTER
  if dt > 0 and dt <= 5 and not paused then s.active = s.active + dt end
  return s.active, paused
end

-- Texte qui change chaque seconde (temps, rythmes) : le reste est en cache.
local function Tick()
  if not (f and f:IsShown()) then return end
  local s = Session()
  local compact = Compact()
  local place = CurrentPlace()
  if not s then
    f.snd:SetText("")
    f.time:SetText("|cFF6E6E74--:--|r")
    if compact then
      f.time:SetText("|cFF9A9AA0" .. OV.noSess .. "|r")
    else
      local waiting = ST.FishLastCast and GetTime() - ST.FishLastCast <= CAST_WINDOW
      f.line1:SetText("|cFF9A9AA0" .. (waiting and OV.waiting or OV.noSess) .. "|r"); f.line1:Show()
      f.line2:Hide(); f.line3:Hide()
      f.zone:SetText(place or ""); f.zone:SetShown(place ~= nil)
    end
  else
    local el, paused = Active(s)
    local n = s.nodes or 0
    local perH = (el >= 300) and (n / el * 3600) or nil
    local tcol = paused and "|cFF8C8C94" or "|cFFFFFFFF"
    if compact then
      f.time:SetText(string.format("%s%s|r  |cFF9A9AA0·|r  %d  |cFF9A9AA0·|r  %s", tcol, Dur(el), n, Money(cache.value)))
    else
      f.time:SetText(tcol .. Dur(el) .. "|r")
      f.snd:SetText(paused and ("|cFF8C8C94(" .. OV.pause .. ")|r")
        or ((ST.FishModeOn and ST.FishModeOn()) and ("|cFF6E6E74(" .. OV.sound .. ")|r") or ""))
      f.line1:SetText(perH and string.format(OV.stats, n, math.floor(perH + 0.5)) or string.format(OV.statsNo, n)); f.line1:Show()
      f.line2:SetText("|cFF9A9AA0" .. OV.value .. "|r  " .. Money(cache.value)); f.line2:Show()
      f.line3:Hide()   -- le rythme en po/h a ete retire a la demande de Tibiscui
      local z = place or (ST.FarmTopZone and ST.FarmTopZone(s))
      f.zone:SetText(z or ""); f.zone:SetShown(z ~= nil)
    end
  end
  -- La structure change (ligne de rythme apparue, zone, session) : on remet en page.
  local key = (s and 1 or 0) + (f.line3:IsShown() and 2 or 0) + (f.zone:IsShown() and 4 or 0) + (compact and 8 or 0)
  if key ~= f._key then Layout(s) end
  FitWidth()
end

local function Refresh()
  if not UI then return end
  if not Enabled() then
    if f then f:Hide() end
    return
  end
  Build()
  if not f then return end
  local s = Session()
  if not ShouldShow(s) then f:Hide(); return end
  Collect(s)
  ApplyLook()
  f:Show()
  Tick()
  Layout(s)
  FitWidth()
end

-- ---------------------------------------------------------------- API
function ST.FishOverlayUpdate()
  local ok, err = pcall(Refresh)
  if not ok and not errShown then
    errShown = true   -- une seule fois, pour ne pas inonder le chat
    print(ST.TAG .. " " .. T("Erreur de l'overlay de pêche : ", "Fishing overlay error: ") .. tostring(err))
  end
  return ok
end

function ST.FishOverlaySetEnabled(v)
  if ST.settings then ST.settings.fishOverlay = v and true or false end
  if v then previewUntil = GetTime() + 20 end
  ST.FishOverlayUpdate()
end

function ST.FishOverlayToggle()
  ST.FishOverlaySetEnabled(not Enabled())
  if Enabled() then
    print(ST.TAG .. " " .. T("Overlay de pêche activé (aperçu de 20 s).", "Fishing overlay enabled (20 s preview).")
      .. (Auto() and (" " .. T("En mode auto, il réapparaît à ton prochain lancer.", "In auto mode it shows again on your next cast.")) or ""))
  else
    print(ST.TAG .. " " .. T("Overlay de pêche désactivé.", "Fishing overlay disabled."))
  end
end

function ST.FishOverlayResetPos()
  if ST.settings then ST.settings.fishOverlayPos = nil end
  ST.FishOverlayUpdate()
end

-- ---------------------------------------------------------------- vie
local acc = 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, dt)
  if not (f and f:IsShown()) then return end
  acc = acc + dt
  if acc < 1 then return end
  acc = 0
  local ok, err = pcall(Tick)
  if not ok and not errShown then
    errShown = true
    print(ST.TAG .. " " .. T("Erreur de l'overlay de pêche : ", "Fishing overlay error: ") .. tostring(err))
  end
  -- Fin de la fenetre d'attente sans prise : on referme en mode auto.
  if Auto() and not Session() and GetTime() >= previewUntil
     and not (ST.FishLastCast and GetTime() - ST.FishLastCast <= CAST_WINDOW) then
    pcall(Refresh)
  end
end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
local pendingInfo = false
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    C_Timer.After(2, function() ST.FishOverlayUpdate() end)
  elseif event == "GET_ITEM_INFO_RECEIVED" then
    -- Noms d'objets arrives : un seul rafraichissement groupe.
    if f and f:IsShown() and not pendingInfo then
      pendingInfo = true
      C_Timer.After(0.5, function() pendingInfo = false; ST.FishOverlayUpdate() end)
    end
  end
end)
