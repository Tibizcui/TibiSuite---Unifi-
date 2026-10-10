--[[============================================================================
  TibiSuiteWidgets.lua  -  Widgets epinglables
  ---------------------------------------------------------------------------
  N'importe quelle ligne d'etat d'un module (statusFn, celle de Ma semaine et
  du Panneau vivant) peut etre epinglee a l'ecran en petite carte flottante :
  icone, nom, etat, barre de progression. Mise a jour en direct
  (TibiSuite.OnStatusChanged), aucun ticker propre hors estompage.

  Stockage : TibiSuiteDB.widgets[cle] = { p = point, x = , y = } (presence =
  epingle), TibiSuiteDB.widgetsLocked, TibiSuiteDB.widgetScale (%).
  Les widgets suivent le masquage automatique de la barre (combat,
  instance...) via TibiSuite.ApplyAutoWidgets, appele par le core.

  Souris : glisser = deplacer (si deverrouille), clic = ouvrir le module,
  clic droit = ses options, Maj + clic droit = desepingler.
============================================================================]]

local L = TibiSuiteL or {}
TibiSuiteL = L
local function D(k, v) if L[k] == nil then L[k] = v end end
D("WID_OFF",        "Module inactif")
D("WID_TT_CLICK",   "Clic : ouvrir le module")
D("WID_TT_RCLICK",  "Clic droit : ses options")
D("WID_TT_DRAG",    "Glisser : déplacer")
D("WID_TT_UNPIN",   "Maj + clic droit : désépingler")
D("WID_PINNED_FMT", "%s épinglé à l'écran.")
D("WID_UNPINNED_FMT", "%s désépinglé.")
D("MENU_OPEN",      "Ouvrir")
D("MENU_OPTIONS",   "Options")
D("MENU_PIN",       "Épingler à l'écran")

local K
local W, H = 214, 46
local frames = {}            -- cle -> frame
local autoMode               -- nil | "fade" | "hide" (fourni par le core)
local fadeTicker

local function DB()
  TibiSuiteDB.widgets = TibiSuiteDB.widgets or {}
  return TibiSuiteDB.widgets
end

local function ModOf(key)
  for _, m in ipairs(TibiSuite.GetCatalog()) do if m.key == key then return m end end
end

local function ModCol(mod)
  local c = mod and mod.col or { r = 0.6, g = 0.6, b = 0.6 }
  return { c.r, c.g, c.b }
end

local function SavePos(f)
  local p, _, _, x, y = f:GetPoint()
  local d = DB()[f.key]
  if d then d.p, d.x, d.y = p or "CENTER", math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5) end
end

local function Place(f)
  local d = DB()[f.key] or {}
  f:ClearAllPoints()
  f:SetPoint(d.p or "CENTER", UIParent, d.p or "CENTER", d.x or 0, d.y or 0)
end

local function Skin(f)
  -- Fond plat + bordure fine (textures : pas de SetBackdropColor au 1er affichage).
  local edge = f:CreateTexture(nil, "BACKGROUND", nil, -1); edge:SetAllPoints(); edge:SetColorTexture(0, 0, 0, 0.95)
  local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetPoint("TOPLEFT", 1, -1); bg:SetPoint("BOTTOMRIGHT", -1, 1)
  bg:SetColorTexture(0.055, 0.063, 0.082, 0.92)
  f.bar = f:CreateTexture(nil, "ARTWORK"); f.bar:SetPoint("TOPLEFT", 1, -1); f.bar:SetPoint("BOTTOMLEFT", 1, 1); f.bar:SetWidth(3)
  f.urg = f:CreateTexture(nil, "ARTWORK"); f.urg:SetPoint("TOPLEFT", 1, -1); f.urg:SetPoint("TOPRIGHT", -1, -1); f.urg:SetHeight(2)
  f.ico = f:CreateTexture(nil, "ARTWORK"); f.ico:SetSize(24, 24); f.ico:SetPoint("LEFT", 10, 1)
  f.name = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.name:SetPoint("TOPLEFT", 42, -7); f.name:SetPoint("RIGHT", -8, 0); f.name:SetJustifyH("LEFT")
  f.txt = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.txt:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -3); f.txt:SetPoint("RIGHT", -8, 0)
  f.txt:SetJustifyH("LEFT"); f.txt:SetWordWrap(false)
  f.pbg = f:CreateTexture(nil, "ARTWORK"); f.pbg:SetPoint("BOTTOMLEFT", 42, 6); f.pbg:SetPoint("BOTTOMRIGHT", -8, 6)
  f.pbg:SetHeight(3); f.pbg:SetColorTexture(1, 1, 1, 0.08)
  f.pfill = f:CreateTexture(nil, "ARTWORK", nil, 1); f.pfill:SetPoint("TOPLEFT", f.pbg); f.pfill:SetPoint("BOTTOMLEFT", f.pbg)
  local hl = f:CreateTexture(nil, "HIGHLIGHT"); hl:SetPoint("TOPLEFT", 1, -1); hl:SetPoint("BOTTOMRIGHT", -1, 1)
  hl:SetColorTexture(1, 1, 1, 0.04)

end

local function Build(key)
  K = K or TibiSuite._kit
  local f = CreateFrame("Button", "TibiSuiteWidget_" .. key, UIParent)
  f.key = key
  f:SetSize(W, H)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  Skin(f)

  f:SetScript("OnDragStart", function(s) if not TibiSuiteDB.widgetsLocked then s:StartMoving() end end)
  f:SetScript("OnDragStop", function(s) s:StopMovingOrSizing(); SavePos(s) end)
  f:SetScript("OnClick", function(s, btn)
    if btn == "RightButton" then
      if IsShiftKeyDown() then TibiSuite.PinWidget(s.key, false)
      elseif TibiSuite.OpenCentre then TibiSuite.OpenCentre(s.key) end
    elseif TibiSuite.OpenModule then TibiSuite.OpenModule(s.key) end
  end)
  f:SetScript("OnEnter", function(s)
    local mod = ModOf(s.key)
    GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
    local c = ModCol(mod)
    GameTooltip:AddLine(mod and mod.addonName or s.key, c[1], c[2], c[3])
    if s.stText and s.stText ~= "" then GameTooltip:AddLine(s.stText, 1, 1, 1, true) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.WID_TT_CLICK, 0.6, 0.6, 0.65)
    GameTooltip:AddLine(L.WID_TT_RCLICK, 0.6, 0.6, 0.65)
    if not TibiSuiteDB.widgetsLocked then GameTooltip:AddLine(L.WID_TT_DRAG, 0.6, 0.6, 0.65) end
    GameTooltip:AddLine(L.WID_TT_UNPIN, 0.6, 0.6, 0.65)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frames[key] = f
  return f
end

local function Fill(f)
  K = K or TibiSuite._kit
  local mod = ModOf(f.key)
  local c = ModCol(mod)
  local st = TibiSuite.GetModuleStatus and TibiSuite.GetModuleStatus(f.key)
  f.bar:SetColorTexture(c[1], c[2], c[3], 1)
  f.ico:SetTexture(TibiSuite.MODULE_LOGO and TibiSuite.MODULE_LOGO[f.key] or (K and K.LOGO))
  f.name:SetText(mod and mod.addonName or f.key)
  f.name:SetTextColor(c[1], c[2], c[3])
  f.stText = st and st.text
  if st then
    local sc = st.color or { 0.925, 0.918, 0.902 }
    f.txt:SetText(st.text or ""); f.txt:SetTextColor(sc[1] or 1, sc[2] or 1, sc[3] or 1)
  else
    f.txt:SetText(L.WID_OFF); f.txt:SetTextColor(0.384, 0.380, 0.420)
  end
  if st and st.urgent then f.urg:SetColorTexture(1, 0.604, 0.235, 1); f.urg:Show() else f.urg:Hide() end
  local prog = st and tonumber(st.progress)
  if prog then
    prog = math.max(0, math.min(1, prog))
    f.pbg:Show(); f.pfill:Show()
    f.pfill:SetWidth(math.max(1, ((f:GetWidth() or W) - 50) * prog))
    if prog >= 1 then f.pfill:SetColorTexture(0.310, 0.820, 0.420, 1) else f.pfill:SetColorTexture(c[1], c[2], c[3], 1) end
  else
    f.pbg:Hide(); f.pfill:Hide()
  end
end

local function StopFade()
  if fadeTicker then fadeTicker:Cancel(); fadeTicker = nil end
  for _, f in pairs(frames) do f:SetAlpha(1) end
end

local function StartFade()
  local low = math.max(0, math.min(0.6, (tonumber(TibiSuiteDB.autoFade) or 20) / 100))
  local function tick()
    for _, f in pairs(frames) do
      if f:IsShown() then f:SetAlpha(f:IsMouseOver() and 1 or low) end
    end
  end
  tick()
  if not fadeTicker then fadeTicker = C_Timer.NewTicker(0.15, tick) end
end

-- Cree, remplit, place et affiche les widgets epingles ; cache les autres.
function TibiSuite.ApplyWidgets()
  if not TibiSuiteDB then return end
  local pinned = DB()
  local scale = math.max(0.5, math.min(2, (tonumber(TibiSuiteDB.widgetScale) or 100) / 100))
  if TibiSuite.GetUIScale then scale = scale * TibiSuite.GetUIScale() end
  for key in pairs(pinned) do
    local mod = ModOf(key)
    if mod and TibiSuite.ModuleExists(mod.addonName) then
      local f = frames[key] or Build(key)
      f:SetScale(scale)
      Place(f)
      Fill(f)
      f:SetShown(autoMode ~= "hide")
    end
  end
  for key, f in pairs(frames) do
    if not pinned[key] then f:Hide() end
  end
  if autoMode == "fade" then StartFade() else StopFade() end
end

local function RefreshWidgets()
  for key, f in pairs(frames) do
    if DB()[key] and f:IsShown() then Fill(f) end
  end
end

-- Appele par le core a chaque changement de contexte (combat, instance...).
function TibiSuite.ApplyAutoWidgets(mode)
  if mode == autoMode then return end
  autoMode = mode
  TibiSuite.ApplyWidgets()
end

function TibiSuite.IsWidgetPinned(key) return TibiSuiteDB and DB()[key] ~= nil or false end

function TibiSuite.PinWidget(key, on)
  if not key or not ModOf(key) then return end
  local d = DB()
  if on then
    if not d[key] then
      -- Empile les nouveaux widgets a droite du centre de l'ecran.
      local n = 0
      for _ in pairs(d) do n = n + 1 end
      d[key] = { p = "CENTER", x = 360, y = 160 - n * (H + 6) }
    end
  else
    d[key] = nil
  end
  TibiSuite.ApplyWidgets()
  if TibiSuite._WidgetsChanged then TibiSuite._WidgetsChanged() end
  local mod = ModOf(key)
  if TibiSuite.ShowToast and mod then
    TibiSuite.ShowToast(string.format(on and L.WID_PINNED_FMT or L.WID_UNPINNED_FMT, mod.addonName))
  end
end

function TibiSuite.ToggleWidget(key) TibiSuite.PinWidget(key, not TibiSuite.IsWidgetPinned(key)) end

function TibiSuite.UnpinAllWidgets()
  TibiSuiteDB.widgets = {}
  TibiSuite.ApplyWidgets()
  if TibiSuite._WidgetsChanged then TibiSuite._WidgetsChanged() end
end

function TibiSuite.SetWidgetsLocked(v)
  TibiSuiteDB.widgetsLocked = v and true or nil
  if TibiSuite._WidgetsChanged then TibiSuite._WidgetsChanged() end
end

-- Modules pouvant etre epingles : ceux qui ont une ligne d'etat.
function TibiSuite.PinnableModules()
  local out = {}
  for _, g in ipairs(TibiSuite.PANEL_GROUPS or {}) do
    if not g.icons then
      for _, key in ipairs(g.keys) do
        local mod = ModOf(key)
        if mod and TibiSuite.ModuleExists(mod.addonName) then out[#out + 1] = mod end
      end
    end
  end
  return out
end

-- Apercu (page Widgets du Centre) : meme carte, sans deplacement ni clic.
function TibiSuite.MakeWidgetPreview(parent, key)
  local f = CreateFrame("Frame", nil, parent)
  f.key = key
  f:SetSize(W, H)
  Skin(f)
  function f:Refresh() Fill(self) end
  Fill(f)
  return f
end

-- Menu contextuel d'un module (clic droit sur la barre Dock / Panneau /
-- Classique). MenuUtil = menus natifs du client ; absent => false et le core
-- garde son comportement d'origine (options).
function TibiSuite.ShowModuleMenu(owner, mod)
  if not (mod and MenuUtil and MenuUtil.CreateContextMenu) then return false end
  local pinnable = false
  for _, m in ipairs(TibiSuite.PinnableModules()) do if m.key == mod.key then pinnable = true end end
  local ok = pcall(MenuUtil.CreateContextMenu, owner, function(_, root)
    root:CreateTitle(mod.addonName or mod.key)
    root:CreateButton(L.MENU_OPEN, function() TibiSuite.OpenModule(mod.key) end)
    root:CreateButton(L.MENU_OPTIONS, function() TibiSuite.OpenCentre(mod.key) end)
    if pinnable then
      root:CreateCheckbox(L.MENU_PIN, function() return TibiSuite.IsWidgetPinned(mod.key) end,
        function() TibiSuite.ToggleWidget(mod.key) end)
    end
  end)
  return ok
end

local pinListeners = {}
function TibiSuite.OnWidgetsChanged(fn) if type(fn) == "function" then pinListeners[#pinListeners + 1] = fn end end
local function WidgetsChanged() for _, fn in ipairs(pinListeners) do pcall(fn) end end
TibiSuite._WidgetsChanged = WidgetsChanged

if TibiSuite.OnStatusChanged then TibiSuite.OnStatusChanged(RefreshWidgets) end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  -- Les modules s'inscrivent pendant le chargement : un instant plus tard.
  C_Timer.After(2, function() TibiSuite.ApplyWidgets() end)
end)
