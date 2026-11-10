--[[============================================================================
  Anchor - Glue module pour TibiSuite
  ---------------------------------------------------------------------------
  MODE MODULE (core present) : inscrit l'onglet « Anchor » (accent indigo)
  dans la barre unifiee ; pas de bouton minimap propre.
  MODE AUTONOME (core absent) : construit son propre bouton minimap.
  Dans les deux cas : slash /anchor et /anc. TibiAnchorDB ne change jamais entre
  les deux modes. Charge en dernier par Anchor.toc.
============================================================================]]

local ADDON, AN = ...
local T = AN.T
local KEY = AN.KEY

local function HasCore()
  return _G.TibiSuite and _G.TibiSuite.RegisterModule and true or false
end

-- Meme regle que Standby : coche dans TibiSuite, ou table absente.
local function IsEnabledByCore()
  if not (TibiSuiteDB and type(TibiSuiteDB.enabledModules) == "table") then return true end
  return TibiSuiteDB.enabledModules[KEY] and true or false
end

-- ============================================================================
-- MODE AUTONOME : bouton minimap (meme construction qu'Opacity)
-- ============================================================================
local function BuildStandaloneMinimapButton()
  if _G.TibiAnchorMinimapBtn then return end
  local btn = CreateFrame("Button", "TibiAnchorMinimapBtn", Minimap)
  btn:SetSize(31, 31)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel(8)
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:RegisterForDrag("LeftButton")
  btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local overlay = btn:CreateTexture(nil, "OVERLAY")
  overlay:SetSize(53, 53)
  overlay:SetPoint("TOPLEFT", 0, 0)
  overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  local icon = btn:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER", 0, 1)
  icon:SetTexture(AN.LOGO)

  local function UpdatePosition()
    local angle = math.rad((TibiAnchorDB and tonumber(TibiAnchorDB.minimapAngle)) or 200)
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 105, math.sin(angle) * 105)
  end
  local function OnDragUpdate()
    if not TibiAnchorDB then return end
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    TibiAnchorDB.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
    UpdatePosition()
  end
  btn:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnDragUpdate) end)
  btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  btn:SetScript("OnClick", function(_, button)
    if button == "RightButton" then TibiAnchor_OpenOptions() else TibiAnchor_Toggle() end
  end)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Anchor")
    GameTooltip:AddLine(T("MM_TT_LEFT", "Clic gauche : ouvrir / fermer"), 0.9, 0.9, 0.95)
    GameTooltip:AddLine(T("MM_TT_RIGHT", "Clic droit : options"), 0.9, 0.9, 0.95)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  UpdatePosition()
end

if HasCore() and IsEnabledByCore() then
  TibiSuite.RegisterModule({
    key            = KEY,
    label          = "Anchor",
    accent         = AN.ACCENT,
    onOpen         = function() TibiAnchor_Toggle() end,
    onOptions      = function() TibiAnchor_OpenOptions() end,
    searchProvider = AN.SearchProvider,   -- Bridge.lua
    overviewFn     = function() if AN.Overview then return AN.Overview() end end,
  })
elseif not HasCore() then
  local f = CreateFrame("Frame")
  pcall(f.RegisterEvent, f, "PLAYER_LOGIN")
  f:SetScript("OnEvent", function(self) self:UnregisterAllEvents(); BuildStandaloneMinimapButton() end)
end

-- ============================================================================
-- SLASH : /anchor [loot | undo | reset | probe | on | off | options | help]
-- ============================================================================
SLASH_TIBIANCHOR1 = "/anchor"
SLASH_TIBIANCHOR2 = "/anc"
SlashCmdList["TIBIANCHOR"] = function(msg)
  local cmd = ((msg or ""):match("^%s*(%S*)") or ""):lower()
  if not TibiAnchorDB then return end
  if cmd == "" then TibiAnchor_Toggle()
  elseif cmd == "loot" or cmd == "butin" then AN.Loot.Toggle()
  elseif cmd == "undo" or cmd == "annuler" then AN.Undo()
  elseif cmd == "reset" then AN.ResetAll()
  elseif cmd == "probe" or cmd == "sonde" then AN.RunProbe()
  elseif cmd == "on" then AN.SetEnabled(true); AN.Print(T("FLASH_ON", "activé"))
  elseif cmd == "off" then
    AN.SetEnabled(false)
    AN.Print(T("FLASH_OFF", "suspendu (fenêtres rendues à leur place d'origine)"))
  elseif cmd == "options" or cmd == "config" then TibiAnchor_OpenOptions()
  else
    AN.Print(T("HELP", "commandes : /anchor (fenêtre), loot (placer le butin), undo (annuler), reset (tout remettre), "
      .. "probe (vérification), on, off, options"))
  end
  AN.OnChanged()
end
