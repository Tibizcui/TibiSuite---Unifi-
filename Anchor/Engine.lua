--[[============================================================================
  Anchor - Engine.lua
  ---------------------------------------------------------------------------
  Le moteur : crochets sur les fenetres du catalogue, glisser-deposer,
  magnetisme et reperes, grille, taille a la molette, annulation, reset.

  CYCLE D'UNE FENETRE
    1. Elle existe (au login ou quand Blizzard charge son addon) : on pose
       des crochets ADDITIFS (HookScript OnMouseDown / OnMouseUp, et
       hooksecurefunc SetPoint). Rien d'autre n'est ecrit sur la frame.
    2. Clic gauche maintenu : SetMovable + StartMoving (comme BlizzMove).
    3. Relache : on calcule le rect, on applique le magnetisme, on retient
       une ancre robuste (coin ou bord le plus proche) et on la pose.
    4. Quand Blizzard la repositionne (ouverture d'un panneau, mise en page),
       le crochet SetPoint NOTE la frame ; notre OnUpdate la remet en place
       a l'image suivante, hors de la pile d'appel de Blizzard.

  Raccourcis sur une fenetre : Maj + clic droit = position d'origine,
  Ctrl + clic droit = taille d'origine, Ctrl + molette = taille,
  Alt pendant le deplacement = sans magnetisme.
  Valide en jeu par Tibiscui le 2026-11-10 (7.5.0).
============================================================================]]

local ADDON, AN = ...
local T = AN.T
local Safe = AN.Safe

AN.hooked = setmetatable({}, { __mode = "k" })   -- [frame] = nom
AN.byName = {}                                     -- [nom] = frame
local handleHooked = setmetatable({}, { __mode = "k" })
local layoutHooked = setmetatable({}, { __mode = "k" })

local SCALE_MIN, SCALE_MAX, SCALE_STEP = 0.5, 1.6, 0.05
local UNDO_MAX = 20

-- Anchor a-t-il le droit d'agir sur cette fenetre en ce moment ?
function AN.CanAct(f)
  if not AN.IsRunning() then return false end
  if AN.Conflict() and not TibiAnchorDB.force then return false end
  local name = AN.hooked[f]
  if not name or AN.Refused(f) then return false end
  if AN.ManagedBy(name, f) then return false end
  return true
end

-- ============================================================================
-- PLACEMENT DIFFERE (une seule frame a nous, OnUpdate branche a la demande)
-- ============================================================================
local driver = CreateFrame("Frame")
local dirty = {}

local function PlaceSaved(f)
  if not AN.CanAct(f) then return end
  local st = AN.St(f)
  if st.moving then return end
  local name = AN.hooked[f]
  local e = AN.ENTRY[name]
  if e and e.skip and e.skip(f) then return end
  local pos = AN.GetPos(name)
  if pos and AN.Place(f, pos) then st.placed = true end
end

local function Flush()
  driver:SetScript("OnUpdate", nil)
  for f in pairs(dirty) do
    dirty[f] = nil
    PlaceSaved(f)
  end
end

function AN.MarkDirty(f)
  dirty[f] = true
  driver:SetScript("OnUpdate", Flush)
end

-- Crochet SetPoint : on lit, on note, on n'ecrit rien ici.
local function OnBlizzSetPoint(f)
  local st = AN.state[f]
  if not st or st.applying then return end
  AN.CaptureBlizzAnchor(f)
  if not st.moving and AN.GetPos(st.name) then AN.MarkDirty(f) end
end

-- Remet chaque fenetre a sa place apres un changement de disposition
-- (resolution, personnage, annulation...). Une fenetre qui n'a plus de
-- position dans la nouvelle disposition retrouve l'ancre de Blizzard.
function AN.ReapplyAll()
  for f, name in pairs(AN.hooked) do
    local st = AN.St(f)
    if AN.GetPos(name) then
      AN.MarkDirty(f)
    elseif st.placed then
      if st.scale0 then pcall(f.SetScale, f, st.scale0) end
      AN.RestoreBlizzAnchor(f)
      st.placed = false
    end
  end
end

-- Actif / suspendu. Suspendu : chaque fenetre deplacee retrouve l'ancre et
-- la taille du jeu, les positions restent en memoire.
function AN.SetEnabled(on)
  TibiAnchorDB.enabled = on and true or false
  if TibiAnchorDB.enabled then AN.ReapplyAll(); return end
  for f in pairs(AN.hooked) do
    local st = AN.St(f)
    if st.placed then
      if st.scale0 then pcall(f.SetScale, f, st.scale0) end
      AN.RestoreBlizzAnchor(f)
      st.placed = false
    end
  end
end

-- ============================================================================
-- CROCHETS
-- ============================================================================
local function HookHandle(handle, root)
  if handleHooked[handle] or AN.Refused(handle) then return end
  handleHooked[handle] = root
  handle:HookScript("OnMouseDown", function(_, button) AN.OnDown(root, button) end)
  handle:HookScript("OnMouseUp", function(_, button) AN.OnUp(root, button) end)
end

-- Poignees secondaires : sous-fenetres du catalogue et barres de titre des
-- modeles recents (lecture d'une cle Blizzard, aucune ecriture).
local TITLE_KEYS = { "TitleContainer", "TitleBar", "TitleButton" }
local function HookSubs(f, e)
  if e.place == "proxy" then return end
  if e.subs then
    for _, n in ipairs(e.subs) do
      local c = _G[n]
      if type(c) == "table" and c.HookScript then HookHandle(c, f) end
    end
  end
  for _, k in ipairs(TITLE_KEYS) do
    local c = f[k]
    if type(c) == "table" and type(c.HookScript) == "function" and type(c.IsMouseEnabled) == "function" then
      local ok, m = pcall(c.IsMouseEnabled, c)
      if ok and Safe(m) and m then HookHandle(c, f) end
    end
  end
end

-- Fenetre placee dans une colonne geree par Blizzard (lancers de des en
-- 12.x) : on la remet en place quand la mise en page de la colonne se
-- termine (post-crochet), pour que l'ancre de Blizzard ne soit jamais
-- dessinee. Meme methode qu'EllesmereUI.
local function HookLayoutParent(f)
  local lp = f.layoutParent
  if type(lp) ~= "table" or type(lp.Layout) ~= "function" or layoutHooked[lp] then return end
  layoutHooked[lp] = true
  hooksecurefunc(lp, "Layout", function()
    for frame in pairs(AN.hooked) do
      if frame.layoutParent == lp then PlaceSaved(frame) end
    end
  end)
end

function AN.HookFrame(name, f, e)
  if AN.hooked[f] then HookSubs(f, e); return true end
  if AN.Refused(f) then return false end
  AN.hooked[f] = name
  AN.byName[name] = f
  local st = AN.St(f)
  st.name = name
  local ok, s = pcall(f.GetScale, f)
  if ok and Safe(s) then st.scale0 = s end
  AN.CaptureBlizzAnchor(f)
  hooksecurefunc(f, "SetPoint", OnBlizzSetPoint)
  if e.place ~= "proxy" then HookHandle(f, f) end
  HookSubs(f, e)
  HookLayoutParent(f)
  if AN.GetPos(name) then AN.MarkDirty(f) end
  return true
end

function AN.Scan()
  if not TibiAnchorDB then return end
  for _, e in ipairs(AN.CATALOG) do
    local n = AN.NameOf(e)
    if n then AN.HookFrame(n, _G[n], e) end
  end
end

-- ============================================================================
-- ANNULATION (memoire de session, 20 pas)
-- ============================================================================
AN.history = {}

function AN.PushUndo(name, prev)
  local h = AN.history
  h[#h + 1] = { lk = AN.LayoutKey(), rk = AN.ResKey(), name = name, prev = AN.CopyPos(prev) or false }
  while #h > UNDO_MAX do table.remove(h, 1) end
end

function AN.Undo()
  local h = AN.history
  local last = h[#h]
  if not last then AN.Flash(T("UNDO_NONE", "rien à annuler")); return false end
  h[#h] = nil
  if last.lk ~= AN.LayoutKey() or last.rk ~= AN.ResKey() then
    AN.Flash(T("UNDO_OTHER", "dernier déplacement fait dans une autre disposition"))
    return false
  end
  local f = AN.byName[last.name]
  if last.prev then
    AN.SetPos(last.name, last.prev)
    if f then AN.MarkDirty(f) end
  else
    AN.SetPos(last.name, nil)
    if f then
      local st = AN.St(f)
      if st.scale0 then pcall(f.SetScale, f, st.scale0) end
      AN.RestoreBlizzAnchor(f)
      st.placed = false
    end
  end
  AN.Flash(T("UNDO_DONE", "déplacement annulé : ") .. AN.LabelOf(last.name))
  AN.OnChanged()
  return true
end

-- ============================================================================
-- RESET
-- ============================================================================
function AN.Reset(name, flash)
  local prev = AN.GetPos(name)
  if not prev then return false end
  AN.PushUndo(name, prev)
  AN.SetPos(name, nil)
  local f = AN.byName[name]
  if f and not AN.Refused(f) then
    local st = AN.St(f)
    if st.scale0 then pcall(f.SetScale, f, st.scale0) end
    AN.RestoreBlizzAnchor(f)
    st.placed = false
  end
  if flash then AN.Flash(T("RESET_ONE", "position d'origine : ") .. AN.LabelOf(name)) end
  AN.OnChanged()
  return true
end

function AN.ResetAll()
  local names = {}
  for name in pairs(AN.Positions()) do names[#names + 1] = name end
  for _, name in ipairs(names) do AN.Reset(name) end
  AN.Flash(string.format(T("RESET_ALL", "%d fenêtre(s) remises à leur place d'origine"), #names))
end

function AN.ResetScale(name)
  local pos = AN.GetPos(name)
  if not (pos and pos.s) then return end
  AN.PushUndo(name, pos)
  local np = AN.CopyPos(pos); np.s = nil
  AN.SetPos(name, np)
  local f = AN.byName[name]
  if f then
    local st = AN.St(f)
    if st.scale0 then pcall(f.SetScale, f, st.scale0) end
    AN.Place(f, np)
  end
  AN.Flash(T("RESET_SCALE", "taille d'origine : ") .. AN.LabelOf(name))
  AN.OnChanged()
end

-- ============================================================================
-- MAGNETISME
-- Renvoie le decalage a appliquer (dx, dy) et la ligne visee (lx, ly) pour
-- les reperes. Cibles : bords et centre de l'ecran, bords des autres
-- fenetres visibles (alignement et accolement).
-- ============================================================================
function AN.ComputeSnap(root, l, b, w, h)
  local d = TibiAnchorDB.snapDist or 12
  local W, H = UIParent:GetWidth(), UIParent:GetHeight()
  local bx, lx, by, ly
  local function tryX(mine, target)
    local delta = target - mine
    if math.abs(delta) <= d and (not bx or math.abs(delta) < math.abs(bx)) then bx, lx = delta, target end
  end
  local function tryY(mine, target)
    local delta = target - mine
    if math.abs(delta) <= d and (not by or math.abs(delta) < math.abs(by)) then by, ly = delta, target end
  end
  tryX(l, 0); tryX(l + w, W); tryX(l + w / 2, W / 2)
  tryY(b, 0); tryY(b + h, H); tryY(b + h / 2, H / 2)
  if TibiAnchorDB.snapWindows then
    for f, name in pairs(AN.hooked) do
      -- Les conteneurs places en mode Placement (lancers de des) sont des
      -- cadres sans fond, souvent vides : pas des cibles d'aimantation.
      local e = AN.ENTRY[name]
      if f ~= root and not (e and e.place == "proxy") then
        local okV, vis = pcall(f.IsVisible, f)
        if okV and Safe(vis) and vis then
          local ol, ob, ow, oh = AN.RectOf(f)
          if ol then
            tryX(l, ol); tryX(l, ol + ow); tryX(l + w, ol); tryX(l + w, ol + ow)
            tryY(b, ob); tryY(b, ob + oh); tryY(b + h, ob); tryY(b + h, ob + oh)
          end
        end
      end
    end
  end
  return bx or 0, by or 0, lx, ly
end

-- ============================================================================
-- CALQUE : reperes et grille (frame a nous, ne prend jamais la souris)
-- ============================================================================
local overlay, vLine, hLine
local gridTex, gridBuiltFor = {}, nil

local function EnsureOverlay()
  if overlay then return end
  overlay = CreateFrame("Frame", "TibiAnchorOverlay", UIParent)
  overlay:SetAllPoints(UIParent)
  overlay:SetFrameStrata("FULLSCREEN_DIALOG")
  overlay:EnableMouse(false)
  overlay:Hide()
  local a = AN.ACCENT
  vLine = overlay:CreateTexture(nil, "OVERLAY")
  vLine:SetColorTexture(a[1], a[2], a[3], 0.9); vLine:SetWidth(2); vLine:Hide()
  hLine = overlay:CreateTexture(nil, "OVERLAY")
  hLine:SetColorTexture(a[1], a[2], a[3], 0.9); hLine:SetHeight(2); hLine:Hide()
end

local function BuildGrid()
  local size = math.max(8, tonumber(TibiAnchorDB.gridSize) or 32)
  local W, H = UIParent:GetWidth(), UIParent:GetHeight()
  local key = size .. ":" .. math.floor(W) .. "x" .. math.floor(H)
  if gridBuiltFor == key then return end
  for _, t in ipairs(gridTex) do t:Hide() end
  local i = 0
  local function Line(vertical, off, strong)
    i = i + 1
    local t = gridTex[i]
    if not t then t = overlay:CreateTexture(nil, "BACKGROUND"); gridTex[i] = t end
    local a = AN.ACCENT
    if strong then t:SetColorTexture(a[1], a[2], a[3], 0.35) else t:SetColorTexture(1, 1, 1, 0.07) end
    t:ClearAllPoints()
    if vertical then
      t:SetPoint("TOPLEFT", overlay, "TOPLEFT", off, 0); t:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", off, 0); t:SetWidth(1)
    else
      t:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 0, off); t:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, off); t:SetHeight(1)
    end
    t:Show()
  end
  -- Depuis le centre, pour que la ligne centrale tombe juste.
  local cx, cy = W / 2, H / 2
  Line(true, cx, true); Line(false, cy, true)
  local k = 1
  while cx - k * size > 0 do Line(true, cx - k * size); Line(true, cx + k * size); k = k + 1 end
  k = 1
  while cy - k * size > 0 do Line(false, cy - k * size); Line(false, cy + k * size); k = k + 1 end
  gridBuiltFor = key
end

local function ShowGuides(lx, ly)
  if lx and TibiAnchorDB.guides then
    vLine:ClearAllPoints()
    vLine:SetPoint("TOPLEFT", overlay, "TOPLEFT", lx - 1, 0)
    vLine:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", lx - 1, 0)
    vLine:Show()
  else vLine:Hide() end
  if ly and TibiAnchorDB.guides then
    hLine:ClearAllPoints()
    hLine:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 0, ly - 1)
    hLine:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, ly - 1)
    hLine:Show()
  else hLine:Hide() end
end

-- Pendant un deplacement : reperes en direct, et fin de deplacement si la
-- fenetre disparait ou si le bouton a ete relache ailleurs (pas de crochet
-- OnHide sur les fenetres Blizzard : c'est notre calque qui surveille).
local function MoveUpdate()
  local f = AN.moving
  if not f then overlay:SetScript("OnUpdate", nil); return end
  local okV, vis = pcall(f.IsVisible, f)
  if not (okV and vis) or (IsMouseButtonDown and not IsMouseButtonDown("LeftButton")) then
    AN.FinishMove(f)
    return
  end
  local l, b, w, h = AN.RectOf(f)
  if l and TibiAnchorDB.snap and not IsAltKeyDown() then
    local _, _, lx, ly = AN.ComputeSnap(f, l, b, w, h)
    ShowGuides(lx, ly)
  else
    ShowGuides(nil, nil)
  end
end

local function StartGuides()
  EnsureOverlay()
  if TibiAnchorDB.grid then BuildGrid() else for _, t in ipairs(gridTex) do t:Hide() end; gridBuiltFor = nil end
  overlay:Show()
  overlay:SetScript("OnUpdate", MoveUpdate)
end

local function StopGuides()
  if not overlay then return end
  overlay:SetScript("OnUpdate", nil)
  vLine:Hide(); hLine:Hide()
  overlay:Hide()
end

-- ============================================================================
-- GLISSER-DEPOSER
-- ============================================================================
function AN.OnDown(root, button)
  if button ~= "LeftButton" or AN.moving or not AN.CanAct(root) then return end
  local mod = TibiAnchorDB.modifier
  if mod == "shift" and not IsShiftKeyDown() then return end
  if mod == "ctrl" and not IsControlKeyDown() then return end
  local name = AN.hooked[root]
  local e = AN.ENTRY[name]
  if e and e.skip and e.skip(root) then return end
  local st = AN.St(root)
  local okU, up = pcall(root.IsUserPlaced, root)
  st.wasUser = (okU and Safe(up) and up) and true or false
  st.before = AN.GetPos(name) and AN.CopyPos(AN.GetPos(name)) or false
  st.r0 = { AN.RectOf(root) }
  if not st.r0[1] then return end
  pcall(root.SetMovable, root, true)
  if TibiAnchorDB.clamp then pcall(root.SetClampedToScreen, root, true) end
  if not pcall(root.StartMoving, root) then return end
  pcall(root.SetUserPlaced, root, st.wasUser)
  st.moving = true
  AN.moving = root
  StartGuides()
end

function AN.FinishMove(root)
  local st = AN.St(root)
  pcall(root.StopMovingOrSizing, root)
  pcall(root.SetUserPlaced, root, st.wasUser and true or false)
  st.moving = false
  AN.moving = nil
  StopGuides()
  local name = AN.hooked[root]
  local l, b, w, h = AN.RectOf(root)
  if not (l and name) then return end
  local r0 = st.r0 or {}
  local moved = r0[1] and (math.abs(l - r0[1]) + math.abs(b - r0[2]) >= 2)
  if not moved then
    -- Simple clic : StopMovingOrSizing a pu remplacer l'ancre ; on remet
    -- l'etat d'avant tel quel.
    if st.before then AN.Place(root, st.before) else AN.RestoreBlizzAnchor(root) end
    return
  end
  if TibiAnchorDB.snap and not IsAltKeyDown() then
    local dx, dy = AN.ComputeSnap(root, l, b, w, h)
    l, b = l + dx, b + dy
  end
  local p, x, y = AN.AnchorFromRect(l, b, w, h)
  local pos = { p = p, x = x, y = y, s = st.before and st.before.s or nil }
  AN.PushUndo(name, st.before)
  AN.SetPos(name, pos)
  if AN.Place(root, pos) then st.placed = true end
  AN.OnChanged()
end

function AN.OnUp(root, button)
  if button == "LeftButton" then
    if AN.moving == root then AN.FinishMove(root) end
    return
  end
  if button ~= "RightButton" or not AN.CanAct(root) then return end
  local name = AN.hooked[root]
  if IsShiftKeyDown() and not IsControlKeyDown() then
    AN.Reset(name, true)
  elseif IsControlKeyDown() and not IsShiftKeyDown() then
    AN.ResetScale(name)
  end
end

-- ============================================================================
-- TAILLE : Ctrl + molette sur la fenetre survolee
-- Un capteur a nous se pose sur la fenetre le temps que Ctrl est tenu :
-- aucune molette activee sur les fenetres de Blizzard.
-- Valide en jeu (2026-11-10) : un frame qui a la molette active mais pas la
-- souris recoit bien la molette (les clics passent au travers).
-- ============================================================================
local catcher

function AN.Scale(name, delta)
  local f = AN.byName[name]
  if not f or not AN.CanAct(f) then return end
  local pos = AN.GetPos(name)
  local before = pos and AN.CopyPos(pos) or false
  if not pos then
    local l, b, w, h = AN.RectOf(f)
    if not l then return end
    local p, x, y = AN.AnchorFromRect(l, b, w, h)
    pos = { p = p, x = x, y = y }
  else
    pos = AN.CopyPos(pos)
  end
  local okS, cur = pcall(f.GetScale, f)
  cur = pos.s or ((okS and Safe(cur)) and cur) or 1
  local s = math.floor((cur + SCALE_STEP * delta) * 100 + 0.5) / 100
  if s < SCALE_MIN then s = SCALE_MIN elseif s > SCALE_MAX then s = SCALE_MAX end
  pos.s = s
  -- Une rafale de crans ne fait qu'une entree d'annulation.
  local h = AN.history[#AN.history]
  if not (h and h.name == name and h.scaleBurst and GetTime() - h.scaleBurst < 1.5) then
    AN.PushUndo(name, before)
    AN.history[#AN.history].scaleBurst = GetTime()
  else
    h.scaleBurst = GetTime()
  end
  AN.SetPos(name, pos)
  if AN.Place(f, pos) then AN.St(f).placed = true end
  AN.Flash(AN.LabelOf(name) .. " : " .. math.floor(s * 100 + 0.5) .. " %")
  AN.OnChanged()
end

local function HoveredWindow()
  local best, bestLevel
  for f, name in pairs(AN.hooked) do
    local e = AN.ENTRY[name]
    if not (e and e.place == "proxy") then
      local okV, vis = pcall(f.IsVisible, f)
      local okM, over = pcall(f.IsMouseOver, f)
      if okV and okM and Safe(vis, over) and vis and over and AN.CanAct(f) then
        local okL, lvl = pcall(f.GetFrameLevel, f)
        lvl = (okL and Safe(lvl) and lvl) or 0
        if not best or lvl > bestLevel then best, bestLevel = f, lvl end
      end
    end
  end
  return best
end

local function EnsureCatcher()
  if catcher then return end
  catcher = CreateFrame("Frame", "TibiAnchorWheelCatcher", UIParent)
  catcher:EnableMouse(false)
  catcher:EnableMouseWheel(true)
  catcher:Hide()
  catcher:SetScript("OnMouseWheel", function(self, delta)
    if self.target and IsControlKeyDown() then AN.Scale(AN.hooked[self.target], delta) end
  end)
  catcher:SetScript("OnUpdate", function(self, el)
    self.t = (self.t or 0) + el
    if self.t < 0.1 then return end
    self.t = 0
    if not IsControlKeyDown() then self:Hide(); self.target = nil; return end
    local f = HoveredWindow()
    if f ~= self.target then AN.ArmCatcher(f) end
  end)
end

function AN.ArmCatcher(f)
  EnsureCatcher()
  catcher.target = f
  if not f then catcher:ClearAllPoints(); catcher:SetSize(1, 1); catcher:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 10, -10); return end
  local okS, strata = pcall(f.GetFrameStrata, f)
  local okL, lvl = pcall(f.GetFrameLevel, f)
  catcher:SetFrameStrata((okS and Safe(strata) and strata) or "HIGH")
  catcher:SetFrameLevel(math.min(((okL and Safe(lvl) and lvl) or 1) + 100, 9000))
  catcher:ClearAllPoints()
  catcher:SetAllPoints(f)
  catcher:Show()
end

-- ============================================================================
-- EVENEMENTS
-- ============================================================================
local ev = CreateFrame("Frame")
local function Reg(e) pcall(ev.RegisterEvent, ev, e) end
Reg("ADDON_LOADED"); Reg("PLAYER_LOGIN"); Reg("DISPLAY_SIZE_CHANGED"); Reg("UI_SCALE_CHANGED")
Reg("MODIFIER_STATE_CHANGED")

local lastRes
ev:SetScript("OnEvent", function(_, event, a1, a2)
  if event == "ADDON_LOADED" then
    if a1 == ADDON then AN.InitDB() end
    if AN.ready then AN.Scan() end
  elseif event == "PLAYER_LOGIN" then
    if not TibiAnchorDB then AN.InitDB() end
    AN.ready = true
    lastRes = AN.ResKey()
    AN.Scan()
    if AN.Loot and AN.Loot.Init then AN.Loot.Init() end
    local c = AN.Conflict()
    if c and not TibiAnchorDB.force and AN.IsRunning() then
      AN.Print(string.format(T("MSG_CONFLICT", "%s est chargé : Anchor lui laisse les fenêtres (option « Forcer » dans les réglages)."), c))
    end
  elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
    if not AN.ready then return end
    local r = AN.ResKey()
    if r ~= lastRes then
      lastRes = r
      AN.Print(string.format(T("MSG_RES", "résolution %s : disposition correspondante appliquée."), r))
    end
    AN.ReapplyAll()
    if AN.Loot and AN.Loot.Refresh then AN.Loot.Refresh() end
  elseif event == "MODIFIER_STATE_CHANGED" then
    if (a1 == "LCTRL" or a1 == "RCTRL") and a2 == 1 and AN.ready and TibiAnchorDB.wheelScale and AN.IsRunning() then
      local f = HoveredWindow()
      if f then AN.ArmCatcher(f) end
    end
  end
end)

-- Rafraichissement de l'interface Anchor (UI.lua le remplace).
function AN.OnChanged() if AN.RefreshUI then AN.RefreshUI() end end
function AN.LabelOf(name)
  local e = AN.ENTRY[name]
  return (e and e.label) or tostring(name)
end
