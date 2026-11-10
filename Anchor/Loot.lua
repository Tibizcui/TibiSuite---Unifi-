--[[============================================================================
  Anchor - Loot.lua  (mode Placement du butin)
  ---------------------------------------------------------------------------
  La fenetre de butin (LootFrame) se deplace a la souris comme les autres.
  Les lancers de des (GroupLootContainer, ou GroupLootFrame1 sur les clients
  qui n'ont pas le conteneur) et le jet de bonus ne prennent pas la souris et
  n'apparaissent que quelques secondes : on les place donc avec des cadres
  fantomes A NOUS, affiches en mode Placement (/anchor loot). La position
  retenue est ensuite posee sur la vraie fenetre par le moteur (crochet
  SetPoint + placement differe, Engine.lua), sans rien ecrire sur elle
  entre-temps.

  Pas d'Echap pour quitter (aucun UISpecialFrames + OnHide : piege de taint
  documente dans le core) : bouton « Terminer », clic droit sur la barre, ou
  /anchor loot.
  Valide en jeu par Tibiscui le 2026-11-10 (7.5.0).
============================================================================]]

local ADDON, AN = ...
local T = AN.T

AN.Loot = {}
local movers = {}
local bar
local active = false

local function Entries()
  local out = {}
  for _, e in ipairs(AN.CATALOG) do
    if e.place == "proxy" then out[#out + 1] = e end
  end
  return out
end

-- Pose un fantome a la position sauvegardee, sinon sur la vraie fenetre,
-- sinon a la place par defaut (bas de l'ecran).
local function PlaceMover(m)
  local e, name = m.entry, m.name
  local pos = AN.GetPos(name)
  m:ClearAllPoints()
  if pos then
    m:SetPoint(pos.p, UIParent, pos.p, pos.x or 0, pos.y or 0)
    return
  end
  local f = _G[name]
  if type(f) == "table" and not AN.Refused(f) then
    local l, b, w, h = AN.RectOf(f)
    if l and w > 20 and h > 20 then
      m:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
      return
    end
  end
  m:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, e.defY or 300)
end

local function MakeMover(e)
  local UI = _G.TibiMidnight
  local name = AN.NameOf(e) or e.names[1]
  local m = movers[name]
  if m then return m end
  m = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  m.entry, m.name = e, name
  m:SetFrameStrata("DIALOG")
  m:SetClampedToScreen(true)
  m:SetMovable(true); m:EnableMouse(true)
  m:RegisterForDrag("LeftButton")
  local a = AN.ACCENT
  if UI and UI.FlatBackdrop then m:SetBackdrop(UI.FlatBackdrop()) end
  if m.SetBackdropColor then
    m:SetBackdropColor(a[1] * 0.25, a[2] * 0.25, a[3] * 0.25, 0.75)
    m:SetBackdropBorderColor(a[1], a[2], a[3], 1)
  end
  local fs = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("CENTER", 0, 6)
  fs:SetTextColor(1, 1, 1)
  fs:SetText(e.label)
  local hint = m:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("TOP", fs, "BOTTOM", 0, -4)
  hint:SetText(T("LOOT_HINT", "glisser pour placer, clic droit : position d'origine"))
  m.state = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  m.state:SetPoint("BOTTOM", 0, 4)

  m:SetScript("OnDragStart", function(s) s:StartMoving() end)
  m:SetScript("OnDragStop", function(s)
    s:StopMovingOrSizing()
    local l, b, w, h = AN.RectOf(s)
    if not l then return end
    if TibiAnchorDB.snap and not IsAltKeyDown() then
      local dx, dy = AN.ComputeSnap(s, l, b, w, h)
      l, b = l + dx, b + dy
    end
    local p, x, y = AN.AnchorFromRect(l, b, w, h)
    local prev = AN.GetPos(s.name)
    AN.PushUndo(s.name, prev)
    AN.SetPos(s.name, { p = p, x = x, y = y })
    PlaceMover(s)
    local f = AN.byName[s.name]
    if f then AN.MarkDirty(f) end
    AN.OnChanged()
  end)
  m:SetScript("OnMouseUp", function(s, button)
    if button == "RightButton" then
      AN.Reset(s.name, true)
      PlaceMover(s)
    end
  end)
  movers[name] = m
  return m
end

local function EnsureBar()
  if bar then return end
  local UI = _G.TibiMidnight
  bar = CreateFrame("Frame", "TibiAnchorLootBar", UIParent, "BackdropTemplate")
  bar:SetSize(460, 54)
  bar:SetPoint("TOP", UIParent, "TOP", 0, -120)
  bar:SetFrameStrata("DIALOG")
  bar:EnableMouse(true)
  if UI and UI.SkinFrame then UI.SkinFrame(bar, AN.ACCENT, UI.C.PANEL) end
  local tt = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  tt:SetPoint("TOPLEFT", 12, -10)
  tt:SetText(AN.Hex() .. "Anchor|r : " .. T("LOOT_TITLE", "placement du butin"))
  local sub = bar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  sub:SetPoint("TOPLEFT", tt, "BOTTOMLEFT", 0, -4)
  sub:SetWidth(330); sub:SetJustifyH("LEFT")
  sub:SetText(T("LOOT_SUB", "Les cadres colorés montrent où apparaîtront les fenêtres."))
  local done
  if UI and UI.MakeButton then
    done = UI.MakeButton(bar, 96, 24, T("BTN_DONE", "Terminer"))
  else
    done = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate"); done:SetSize(96, 24); done:SetText(T("BTN_DONE", "Terminer"))
  end
  done:SetPoint("RIGHT", -12, 0)
  done:SetScript("OnClick", function() AN.Loot.Stop() end)
  bar:SetScript("OnMouseUp", function(_, b) if b == "RightButton" then AN.Loot.Stop() end end)
  bar:Hide()
end

function AN.Loot.IsActive() return active end

function AN.Loot.Start()
  if not AN.IsRunning() then AN.Print(T("MSG_OFF", "Anchor est désactivé.")); return end
  EnsureBar()
  active = true
  for _, e in ipairs(Entries()) do
    local m = MakeMover(e)
    local f = _G[m.name]
    local w, h = e.defW or 300, e.defH or 80
    if type(f) == "table" and not AN.Refused(f) then
      local l, b, fw, fh = AN.RectOf(f)
      if l and fw > 20 and fh > 20 then w, h = fw, fh end
    end
    m:SetSize(w, h)
    PlaceMover(m)
    local by = AN.ManagedBy(m.name, type(f) == "table" and f or nil)
    if by then
      m.state:SetText("|cFFFF7F7F" .. T("TAG_MANAGED", "gérée par ") .. by .. "|r")
    elseif type(f) ~= "table" then
      m.state:SetText("|cFF888888" .. T("TAG_ABSENT", "absente de cette version du jeu") .. "|r")
    else
      m.state:SetText("")
    end
    m:Show()
  end
  bar:Show()
end

function AN.Loot.Stop()
  active = false
  for _, m in pairs(movers) do m:Hide() end
  if bar then bar:Hide() end
end

function AN.Loot.Toggle()
  if active then AN.Loot.Stop() else AN.Loot.Start() end
end

function AN.Loot.Refresh()
  if not active then return end
  for _, m in pairs(movers) do PlaceMover(m) end
end

function AN.Loot.Init()
  -- Rien a construire tant que le joueur n'ouvre pas le mode Placement.
end
