--[[============================================================================
  ReadyUp - Toast.lua
  ---------------------------------------------------------------------------
  Les moments ou ReadyUp previent, et l'alerte qui s'affiche alors.
    - entree dans un donjon, raid, gouffre, champ de bataille ou arene
      (une fois par instance), avec « Pret pour... » si tout va bien ;
    - appel « Pret ? » du groupe (READY_CHECK) ;
    - marchand qui repare, si l'usure est sous le seuil ;
    - SUIVI CONTINU, partout : des qu'un controle franchit son seuil (sacs,
      fleches, familier, usure, flacon qui expire...), une fois par
      probleme, apres 3 s de persistance, jamais en combat. Les problemes
      deja la au demarrage sont annonces une fois, 8 s apres la connexion.
      Rappel d'un probleme qui dure (remindMin) en solo et en gouffre.
  L'alerte est VIVANTE : chaque ligne passe au vert quand le probleme est
  regle, puis « Tout est regle » et elle se ferme.
  NON TESTE EN JEU (2026-11-15).
============================================================================]]

local ADDON, RU = ...
local T = RU.T

local toast
local TOAST_W, ROW_H, MAX_ROWS = 340, 20, 7

local function After(sec, fn)
  if C_Timer and C_Timer.After then C_Timer.After(sec, fn) else fn() end
end

-- ============================================================================
-- ALERTE
-- ============================================================================
local function SavePos(f)
  local p, _, rp, x, y = f:GetPoint(1)
  if p then TibiReadyUpDB.toastPos = { point = p, relPoint = rp, x = x, y = y } end
end

local function BuildToast()
  local UI = _G.TibiMidnight
  local f = CreateFrame("Button", "TibiReadyUpToast", UIParent, "BackdropTemplate")
  f:SetSize(TOAST_W, 40)
  f:SetFrameStrata("HIGH")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(s) s:StopMovingOrSizing(); SavePos(s) end)
  local pos = TibiReadyUpDB.toastPos
  if type(pos) == "table" and pos.point then
    f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, tonumber(pos.x) or 0, tonumber(pos.y) or 0)
  else
    f:SetPoint("TOP", UIParent, "TOP", 0, -160)
  end
  if UI and UI.SkinFrame then UI.SkinFrame(f, RU.ACCENT, UI.C.BG) end

  f.logo = f:CreateTexture(nil, "ARTWORK")
  f.logo:SetSize(18, 18); f.logo:SetPoint("TOPLEFT", 10, -9)
  f.logo:SetTexture(RU.LOGO)
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.title:SetPoint("LEFT", f.logo, "RIGHT", 6, 0)
  f.title:SetPoint("RIGHT", f, "RIGHT", -10, 0)
  f.title:SetJustifyH("LEFT")

  f.rows = {}
  for i = 1, MAX_ROWS do
    local r = CreateFrame("Frame", nil, f)
    r:SetSize(TOAST_W - 20, ROW_H)
    r:SetPoint("TOPLEFT", 10, -32 - (i - 1) * ROW_H)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(16, 16); r.icon:SetPoint("LEFT", 0, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.text:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    f.rows[i] = r
  end

  f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.hint:SetJustifyH("LEFT")
  f.hint:SetText(T("TOAST_HINT", "Clic : détail  |  clic droit : fermer"))

  f:SetScript("OnClick", function(s, button)
    s:Hide()
    if button ~= "RightButton" and RU.ShowMain then RU.ShowMain() end
  end)
  f:SetScript("OnEnter", function(s) s.hold = true end)
  f:SetScript("OnLeave", function(s) s.hold = false; s.left = math.max(s.left or 0, 2) end)
  f:SetScript("OnUpdate", function(s, el)
    if s.hold then s:SetAlpha(1); return end
    s.left = (s.left or 0) - el
    if s.left <= 0 then s.ids = nil; s:Hide(); return end
    s:SetAlpha(s.left < 1 and s.left or 1)
  end)
  f:Hide()
  return f
end

-- Priorite a niveau egal (critique passe toujours avant alerte) : ce qui
-- bloque le jeu d'abord, ce qui gene seulement (sacs) en dernier. Sert a
-- l'ordre des lignes de l'alerte et a l'icone du voyant.
local PRIORITY = {
  pet = 1, ammo = 2, weapon = 3, selfbuff = 4, food = 5, flask = 6, potion = 7,
  dur = 8, reagents = 9, enchant = 10, armorkit = 11, gems = 12, bags = 13,
}
local function MoreUrgent(a, b)
  local ra, rb = RU.RANK[a.state] or 0, RU.RANK[b.state] or 0
  if ra ~= rb then return ra > rb end
  return (PRIORITY[a.id] or 99) < (PRIORITY[b.id] or 99)
end
RU.MoreUrgent = MoreUrgent

local function ColorHex(r, g, b) return string.format("|cFF%02X%02X%02X", r * 255, g * 255, b * 255) end

local function Line(r)
  local s = r.label .. " : " .. ColorHex(RU.StateColor(r.state)) .. tostring(r.value or "") .. "|r"
  if r.detail and r.state ~= "ok" then s = s .. "  |cFFAAAAAA" .. r.detail .. "|r" end
  return s
end

local function FixedLine(label)
  return label .. " : " .. RU.Hex() .. T("VAL_FIXED", "réglé") .. "|r"
end

local function Layout(n)
  toast.hint:ClearAllPoints()
  toast.hint:SetPoint("TOPLEFT", 10, -34 - n * ROW_H)
  toast:SetHeight(34 + n * ROW_H + 20)
end

local function Title(ctx, n)
  return RU.ContextTitle(ctx) .. " : " .. string.format(T("TOAST_ISSUES", "%d point(s) à revoir"), n)
end

local function PlayAlert()
  if not (TibiReadyUpDB and TibiReadyUpDB.sound and _G.PlaySound) then return end
  local id = (SOUNDKIT and SOUNDKIT.TELL_MESSAGE) or 3081   -- son d'un message prive : discret
  pcall(PlaySound, id)
end

-- Affiche l'alerte. okMessage : montrer « Pret pour... » s'il n'y a rien.
-- onlyIds (facultatif) : ne montrer que ces controles.
function RU.ShowToast(ev, okMessage, onlyIds)
  if not (ev and TibiReadyUpDB) then return end
  toast = toast or BuildToast()
  local shown = {}
  for _, r in ipairs(ev.results) do
    if (r.state == "warn" or r.state == "fail") and (not onlyIds or onlyIds[r.id]) then shown[#shown + 1] = r end
  end
  table.sort(shown, MoreUrgent)
  if #shown == 0 then
    if not okMessage then return end
    toast.ids = nil
    toast.title:SetText(RU.Hex() .. RU.ContextReady(ev.context) .. "|r")
    for i = 1, MAX_ROWS do toast.rows[i]:Hide() end
    Layout(0)
    toast.left = 3
    toast:SetAlpha(1)
    toast:Show()
    return
  end
  local n = math.min(#shown, MAX_ROWS)
  toast.ids, toast.order, toast.ctx = {}, {}, ev.context
  for i = 1, MAX_ROWS do
    local row, r = toast.rows[i], shown[i]
    if i <= n then
      row.icon:SetTexture(r.icon or RU.LOGO)
      row.text:SetText(Line(r))
      row.label = r.label
      row:Show()
      toast.ids[r.id] = true
      toast.order[i] = r.id
    else
      row:Hide()
    end
  end
  toast.title:SetText(Title(ev.context, #shown))
  Layout(n)
  toast.left = TibiReadyUpDB.toastTime or 12
  toast:SetAlpha(1)
  toast:Show()
  PlayAlert()
end

-- Alerte vivante : a chaque nouvelle evaluation, les lignes affichees
-- suivent l'etat reel ; quand tout est regle, « Tout est regle » et fermeture.
RU.listeners[#RU.listeners + 1] = function()
  if not (toast and toast:IsShown() and toast.ids and RU.last) then return end
  local by = {}
  for _, r in ipairs(RU.last.results) do by[r.id] = r end
  local remaining = 0
  for i, id in ipairs(toast.order) do
    local r, row = by[id], toast.rows[i]
    if r and (r.state == "warn" or r.state == "fail") then
      remaining = remaining + 1
      row.text:SetText(Line(r))
    else
      row.text:SetText(FixedLine(row.label or id))
    end
  end
  if remaining == 0 then
    toast.title:SetText(RU.Hex() .. T("TOAST_ALL_FIXED", "Tout est réglé") .. "|r")
    toast.ids = nil
    toast.left = math.min(toast.left or 3, 2.5)
  else
    toast.title:SetText(Title(toast.ctx, remaining))
  end
end

-- ============================================================================
-- JOURNAL DE DIAGNOSTIC (/readyup debug)
-- Les 40 dernieres decisions du suivi : alerte montree, bloquee (et
-- pourquoi), erreur attrapee. En memoire seulement, jamais sauvegarde.
-- ============================================================================
local journal = {}
function RU.Log(msg)
  journal[#journal + 1] = { t = GetTime(), msg = tostring(msg) }
  if #journal > 40 then table.remove(journal, 1) end
end
RU.journal = journal

-- ============================================================================
-- SUIVI CONTINU (2026-11-15, regle simplifiee)
--   watched[id] = { state, at } : probleme deja annonce (ou montre a
--   l'entree en instance / au ready check).
--   Un probleme nouveau est annonce tout de suite, sauf le familier qui doit
--   manquer 5 s (rappel apres un vol, une monture...).
--   Controle a chaque changement (sacs, fleches, familier, auras, fin de
--   combat) et toutes les 30 s.
-- ============================================================================
local watched, seen = {}, {}
local loginAt = GetTime and GetTime() or 0
local LOGIN_GRACE, PET_GRACE = 5, 5
local Touch
RU.watched = watched

local function MarkShown(ev, onlyIds)
  if not ev then return end
  local now = GetTime()
  for _, r in ipairs(ev.results) do
    if (r.state == "warn" or r.state == "fail") and (not onlyIds or onlyIds[r.id]) then
      watched[r.id] = { state = r.state, at = now }
    end
  end
end

local function Watch(ev)
  if not (ev and TibiReadyUpDB) then return end
  local db = TibiReadyUpDB
  local now = GetTime()
  local current = {}
  for _, r in ipairs(ev.results) do
    if r.state == "warn" or r.state == "fail" then current[r.id] = r.state end
  end
  for id in pairs(watched) do if not current[id] then watched[id] = nil end end
  for id in pairs(seen) do if not current[id] then seen[id] = nil end end

  local remind = (tonumber(db.remindMin) or 0) * 60
  local canRemind = remind > 0 and (ev.context == "solo" or ev.context == "delve")
  local fresh, waiting = {}, false
  for id, st in pairs(current) do
    local w = watched[id]
    if not w or RU.RANK[st] > RU.RANK[w.state] then
      if id == "pet" then
        seen[id] = seen[id] or now
        if now - seen[id] >= PET_GRACE then fresh[id] = st else waiting = true end
      else
        fresh[id] = st
      end
    elseif canRemind and now - w.at >= remind then
      fresh[id] = st
    end
  end
  if waiting then After(PET_GRACE + 0.5, function() Touch() end) end
  if not next(fresh) then return end
  local ids = {}
  for id in pairs(fresh) do ids[#ids + 1] = id end
  table.sort(ids)
  local list = table.concat(ids, ", ")
  if not db.onSolo then RU.Log("bloquee (option « Pendant le jeu » decochee) : " .. list); return end
  if now - loginAt < LOGIN_GRACE then
    RU.Log("en attente du demarrage : " .. list)
    After(LOGIN_GRACE + 0.5 - (now - loginAt), function() Touch() end)
    return
  end
  if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then RU.Log("bloquee (fantome) : " .. list); return end
  for id, st in pairs(fresh) do watched[id] = { state = st, at = now } end
  RU.ShowToast(ev, false, fresh)
  RU.Log("ALERTE montree (" .. ev.context .. ") : " .. list)
end
RU.Watch = Watch

-- Rafraichissement (fenetre, badge, voyant, alerte vivante, suivi continu),
-- une fois par seconde au plus et jamais en combat. Toute erreur est
-- attrapee et notee dans le journal, au lieu de bloquer l'alerte en silence.
local dirty = false
local lastSkip
local function Skip(why)
  if lastSkip ~= why then lastSkip = why; if why then RU.Log(why) end end
end
Touch = function()
  if dirty then return end
  dirty = true
  After(1, function()
    dirty = false
    if not RU.IsRunning() then
      Skip(RU.SuiteDisabled() and "suivi arrete : decoche dans TibiSuite" or "suivi arrete : ReadyUp inactif")
      return
    end
    if InCombatLockdown and InCombatLockdown() then Skip("en combat : controle a la fin du combat"); return end
    Skip(nil)
    local ok, err = pcall(function() Watch(RU.Evaluate("refresh")) end)
    if not ok then RU.Log("ERREUR : " .. tostring(err)) end
  end)
end
RU.Touch = Touch

-- ============================================================================
-- VOYANT PERMANENT (TibiReadyUpBeacon)
-- Petite icone deplacable, a l'ecran tant qu'il reste un probleme : nombre
-- de points et couleur (orange, rouge). Clic : detail ; clic droit :
-- options ; survol : la liste. Visible sans toucher la souris.
-- ============================================================================
local beacon

local function BeaconTooltip(self)
  local ev = RU.last
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
  GameTooltip:AddLine("ReadyUp", RU.ACCENT[1], RU.ACCENT[2], RU.ACCENT[3])
  if ev then
    for _, r in ipairs(ev.results) do
      if r.state == "warn" or r.state == "fail" then
        local cr, cg, cb = RU.StateColor(r.state)
        GameTooltip:AddDoubleLine(r.label, tostring(r.value or ""), 1, 1, 1, cr, cg, cb)
        if r.detail then GameTooltip:AddLine("  " .. r.detail, 0.67, 0.67, 0.67, true) end
      end
    end
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(T("BEACON_HINT", "Clic : détail  |  clic droit : options  |  glisser : déplacer"), 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end

-- Forme ronde : masque circulaire du jeu (portrait). HYPOTHESE a verifier en
-- jeu : CreateMaskTexture et ce masque existent sur les trois familles de
-- clients ; sinon le voyant reste carre, sans erreur.
local CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local function Round(frame, tex)
  if not frame.CreateMaskTexture then return end
  local ok, mask = pcall(frame.CreateMaskTexture, frame)
  if not ok or not mask then return end
  mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(tex)
  pcall(tex.AddMaskTexture, tex, mask)
end

local function BuildBeacon()
  local f = CreateFrame("Button", "TibiReadyUpBeacon", UIParent)
  f:SetSize(42, 42)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(s)
    s:StopMovingOrSizing()
    local p, _, rp, x, y = s:GetPoint(1)
    if p then TibiReadyUpDB.beaconPos = { point = p, relPoint = rp, x = x, y = y } end
  end)
  local pos = TibiReadyUpDB.beaconPos
  if type(pos) == "table" and pos.point then
    f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, tonumber(pos.x) or 0, tonumber(pos.y) or 0)
  else
    f:SetPoint("TOP", UIParent, "TOP", 0, -110)
  end
  -- Halo (pulsation), anneau de couleur, fond sombre, icone du probleme :
  -- quatre disques empiles, chacun un peu plus petit que le precedent.
  f.glow = f:CreateTexture(nil, "BACKGROUND", nil, -1)
  f.glow:SetPoint("TOPLEFT", -6, 6); f.glow:SetPoint("BOTTOMRIGHT", 6, -6)
  f.glow:SetColorTexture(1, 0.7, 0.28, 1)
  f.glow:SetAlpha(0)
  Round(f, f.glow)
  f.ring = f:CreateTexture(nil, "BACKGROUND")
  f.ring:SetAllPoints()
  Round(f, f.ring)
  f.bg = f:CreateTexture(nil, "BORDER")
  f.bg:SetPoint("TOPLEFT", 3, -3); f.bg:SetPoint("BOTTOMRIGHT", -3, 3)
  f.bg:SetColorTexture(0.06, 0.07, 0.09, 1)
  Round(f, f.bg)
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetPoint("TOPLEFT", 5, -5); f.icon:SetPoint("BOTTOMRIGHT", -5, 5)
  f.icon:SetTexture(RU.LOGO)
  f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  Round(f, f.icon)
  -- Pastille rouge du nombre de points, en haut a droite.
  f.badge = CreateFrame("Frame", nil, f)
  f.badge:SetSize(20, 20)
  f.badge:SetPoint("CENTER", f, "TOPRIGHT", -4, -4)
  f.badge:SetFrameLevel((f:GetFrameLevel() or 1) + 3)
  f.badgeBg = f.badge:CreateTexture(nil, "ARTWORK")
  f.badgeBg:SetAllPoints()
  f.badgeBg:SetColorTexture(0.89, 0.29, 0.29, 1)
  Round(f.badge, f.badgeBg)
  f.count = f.badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.count:SetPoint("CENTER", 0, 0)
  -- Pulsation de 2 s a l'apparition d'un nouveau probleme.
  if f.CreateAnimationGroup then
    local ok, ag = pcall(f.CreateAnimationGroup, f)
    if ok and ag then
      local fade = ag:CreateAnimation("Alpha")
      pcall(fade.SetTarget, fade, f.glow)
      if fade.SetFromAlpha then fade:SetFromAlpha(0); fade:SetToAlpha(0.7) end
      fade:SetDuration(0.5)
      if fade.SetSmoothing then fade:SetSmoothing("IN_OUT") end
      ag:SetLooping("BOUNCE")
      f.pulse = ag
    end
  end
  f:SetScript("OnClick", function(_, button)
    if button == "RightButton" then TibiReadyUp_OpenOptions() elseif RU.ShowMain then RU.ShowMain() end
  end)
  f:SetScript("OnEnter", BeaconTooltip)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f:Hide()
  return f
end

local function UpdateBeacon()
  local db = TibiReadyUpDB
  local ev = RU.last
  local want = db and db.beacon and RU.IsRunning() and ev and ev.issues > 0
  if not want then
    if beacon then beacon:Hide(); beacon.lastIssues, beacon.lastTop, beacon.lastSig = 0, nil, nil end
    return
  end
  beacon = beacon or BuildBeacon()
  -- Le probleme le plus urgent donne l'icone (critique avant alerte, puis
  -- la table PRIORITY).
  local top
  for _, r in ipairs(ev.results) do
    if (r.state == "warn" or r.state == "fail") and (not top or MoreUrgent(r, top)) then top = r end
  end
  local cr, cg, cb = RU.StateColor(ev.worst)
  beacon.ring:SetColorTexture(cr, cg, cb, 1)
  beacon.glow:SetColorTexture(cr, cg, cb, 1)
  beacon.icon:SetTexture((top and top.icon) or RU.LOGO)
  beacon.count:SetText(tostring(ev.issues))
  beacon:Show()
  -- Pulsation seulement quand un probleme NOUVEAU apparait (pas a chaque
  -- controle), arretee au bout de 2 s.
  local sig = (top and top.id or "") .. ":" .. ev.issues
  local grew = (not beacon.lastIssues) or ev.issues > beacon.lastIssues or (top and top.id ~= beacon.lastTop)
  beacon.lastIssues, beacon.lastTop = ev.issues, top and top.id
  if grew and beacon.pulse and beacon.lastSig ~= sig then
    pcall(beacon.pulse.Play, beacon.pulse)
    After(2, function() if beacon.pulse then pcall(beacon.pulse.Stop, beacon.pulse); beacon.glow:SetAlpha(0) end end)
  end
  beacon.lastSig = sig
end
RU.UpdateBeacon = UpdateBeacon
RU.listeners[#RU.listeners + 1] = UpdateBeacon

function RU.ResetBeacon()
  if TibiReadyUpDB then TibiReadyUpDB.beaconPos = nil end
  if beacon then beacon:ClearAllPoints(); beacon:SetPoint("TOP", UIParent, "TOP", 0, -110) end
end

-- ============================================================================
-- /readyup debug : etat du suivi et dernieres decisions.
-- ============================================================================
function RU.PrintDebug()
  local db = TibiReadyUpDB or {}
  local now = GetTime()
  local yes = function(v) return v and "oui" or "non" end
  RU.Print("diagnostic")
  print(string.format("  actif : %s | coche dans TibiSuite : %s | option « Pendant le jeu » : %s | voyant : %s",
    yes(RU.IsRunning()), yes(not RU.SuiteDisabled()), yes(db.onSolo), yes(db.beacon)))
  print(string.format("  en combat : %s | depuis la connexion : %d s | alerte affichee : %s",
    yes(InCombatLockdown and InCombatLockdown()), math.floor(now - loginAt), yes(toast and toast:IsShown())))
  local ev = RU.last
  if ev then
    print(string.format("  dernier controle : il y a %d s, contexte %s, %d point(s)", time() - (ev.at or time()), ev.context, ev.issues))
    for _, r in ipairs(ev.results) do
      if r.state ~= "ok" then
        local w = watched[r.id]
        print(string.format("   - %s : %s (%s)%s", r.id, r.state, tostring(r.value),
          w and string.format(", annonce il y a %d s", math.floor(now - w.at)) or ", pas encore annonce"))
      end
    end
  else
    print("  aucun controle encore fait")
  end
  local from = math.max(1, #journal - 9)
  if #journal == 0 then print("  journal vide") end
  for i = from, #journal do
    local e = journal[i]
    print(string.format("  [-%ds] %s", math.floor(now - e.t), e.msg))
  end
end

-- ============================================================================
-- MOMENTS
-- ============================================================================
local pending        -- raison en attente de la fin du combat
local lastInstance   -- instance deja annoncee (session)

local function Run(reason)
  if not RU.IsRunning() then return end
  if InCombatLockdown and InCombatLockdown() then pending = reason; return end
  local db = TibiReadyUpDB
  local ev = RU.Evaluate(reason)
  if not ev then return end
  RU.Log(string.format("moment « %s » : %d point(s) (%s)", reason, ev.issues, ev.context))
  if reason == "ready" then
    if db.onReadyCheck then RU.ShowToast(ev, db.okOnReady); MarkShown(ev) end
  elseif reason == "merchant" then
    if db.onMerchant then RU.ShowToast(ev, false, { dur = true }); MarkShown(ev, { dur = true }) end
  elseif reason == "instance" then
    if db.onInstance then RU.ShowToast(ev, db.okOnEnter); MarkShown(ev) end
  end
end
RU.Run = Run

local INSTANCE_TYPES = { party = true, raid = true, scenario = true, pvp = true, arena = true }

local function OnEnteringWorld()
  local ok, inInst, iType = pcall(IsInInstance)
  if not ok or not inInst or not INSTANCE_TYPES[iType] then
    lastInstance = nil
    Touch()
    return
  end
  local id = select(8, GetInstanceInfo())
  local diff = select(3, GetInstanceInfo())
  local key = tostring(id) .. ":" .. tostring(diff)
  if key == lastInstance then return end
  lastInstance = key
  -- Laisse le temps au familier, aux ameliorations et aux sacs de se charger.
  After(4, function() Run("instance") end)
end

-- ============================================================================
-- EVENEMENTS
-- ============================================================================
local ev = CreateFrame("Frame")
local function Reg(e) pcall(ev.RegisterEvent, ev, e) end
Reg("ADDON_LOADED")
Reg("PLAYER_LOGIN")

local function RegisterGameEvents()
  Reg("PLAYER_ENTERING_WORLD")
  Reg("ZONE_CHANGED_NEW_AREA")
  Reg("READY_CHECK")
  Reg("MERCHANT_SHOW")
  Reg("PLAYER_REGEN_ENABLED")
  Reg("PLAYER_UNGHOST")
  Reg("PLAYER_ALIVE")
  Reg("UPDATE_INVENTORY_DURABILITY")
  Reg("BAG_UPDATE_DELAYED")
  Reg("UNIT_PET")
  Reg("UNIT_INVENTORY_CHANGED")
  Reg("PLAYER_EQUIPMENT_CHANGED")
  if ev.RegisterUnitEvent then pcall(ev.RegisterUnitEvent, ev, "UNIT_AURA", "player") else Reg("UNIT_AURA") end
end

ev:SetScript("OnEvent", function(self, e, arg1)
  if e == "ADDON_LOADED" then
    if arg1 == ADDON then RU.InitDB() end
    return
  end
  if e == "PLAYER_LOGIN" then
    if not TibiReadyUpDB then RU.InitDB() end
    loginAt = GetTime()
    RegisterGameEvents()
    RU.WarmReagents()
    -- Bilan de depart : les problemes deja la sont annonces une fois.
    After(LOGIN_GRACE + 1, function() Touch() end)
    -- Controle toutes les 30 s (filet de securite et rappels), hors combat.
    if C_Timer and C_Timer.NewTicker then
      C_Timer.NewTicker(30, function() Touch() end)
    end
    RU.Log("connexion")
    return
  end
  if e == "PLAYER_ENTERING_WORLD" then OnEnteringWorld(); return end
  if e == "READY_CHECK" then Run("ready"); return end
  if e == "MERCHANT_SHOW" then
    if CanMerchantRepair and CanMerchantRepair() then Run("merchant") end
    return
  end
  if e == "PLAYER_REGEN_ENABLED" then
    if pending then local r = pending; pending = nil; After(1, function() Run(r) end) end
    Touch()   -- fin de combat : familier mort, usure, fleches
    return
  end
  if e == "UNIT_AURA" and arg1 ~= "player" then return end
  if (e == "UNIT_PET" or e == "UNIT_INVENTORY_CHANGED") and arg1 ~= "player" then return end
  Touch()
end)
