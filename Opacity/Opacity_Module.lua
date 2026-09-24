--[[============================================================================
  Opacity - Glue module pour TibiSuite
  ---------------------------------------------------------------------------
  MODE MODULE (core present) : inscrit l'onglet "Opacity" (accent bleu glacier)
  dans la barre unifiee ; pas de bouton minimap propre.
  MODE STANDALONE (core absent) : construit son propre bouton minimap.
  Dans les deux cas : slash /opacity et /opa. OpacityDB ne change jamais
  entre les deux modes.
  Charge en dernier par Opacity.toc.
============================================================================]]

local ADDON, OP = ...
local T = OP.T
local KEY = "Opacity"

local function HasCore()
  return _G.TibiSuite and _G.TibiSuite.RegisterModule and true or false
end

if not HasCore() then
  C_Timer.After(45, function()
    print("|cFFC41F3BTibiSuite|r : plus d'infos sur |cFFFFD700https://www.tibiscui.fr|r")
    print("|cFFC41F3BTibiSuite|r : télécharge Tibi-Companion sur |cFFFFD700https://tibiscui.fr/tibi-companion.html|r")
  end)
end

-- Meme regle que OP.SuiteDisabled (Core.lua), vue depuis l'inscription :
-- au tout premier login apres l'ajout du module, la cle n'existe pas encore
-- (la migration du core la pose sur PLAYER_LOGIN, apres ce fichier) ; on
-- s'inscrit quand meme pour que l'onglet soit la des la premiere session.
local function IsEnabledByCore()
  if not (TibiSuiteDB and type(TibiSuiteDB.enabledModules) == "table") then return true end
  if TibiSuiteDB.enabledModules[KEY] then return true end
  return not TibiSuiteDB.opacityEnableMigrated
end

-- ============================================================================
-- MODE STANDALONE : bouton minimap (meme construction que RepBar)
-- ============================================================================
local function BuildStandaloneMinimapButton()
  if _G.OpacityMinimapBtn then return end
  local btn = CreateFrame("Button", "OpacityMinimapBtn", Minimap)
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
  icon:SetTexture(OP.LOGO)

  local function Angle()
    return (OpacityDB and tonumber(OpacityDB.minimapAngle)) or 200
  end
  local function UpdatePosition()
    local angle = math.rad(Angle())
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 105, math.sin(angle) * 105)
  end

  btn:SetScript("OnDragStart", function(self) self.dragging = true end)
  btn:SetScript("OnDragStop", function(self) self.dragging = false end)
  btn:SetScript("OnUpdate", function(self)
    if not self.dragging or not OpacityDB then return end
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    OpacityDB.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
    UpdatePosition()
  end)
  btn:SetScript("OnClick", function(_, button)
    if button == "RightButton" then Opacity_OpenOptions() else Opacity_Toggle() end
  end)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Opacity")
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
    label          = "Opacity",
    accent         = OP.ACCENT,
    onOpen         = function() Opacity_Toggle() end,
    onOptions      = function() Opacity_OpenOptions() end,
    searchProvider = nil,
  })
elseif not HasCore() then
  -- Le bouton lit OpacityDB : on attend le login (SavedVariables chargees).
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:SetScript("OnEvent", function(self) self:UnregisterAllEvents(); BuildStandaloneMinimapButton() end)
end

-- ============================================================================
-- SLASH : /opacity [pick | shot | on | off | options | reset | help]
-- ============================================================================
SLASH_TIBIOPACITY1 = "/opacity"
SLASH_TIBIOPACITY2 = "/opa"
SlashCmdList["TIBIOPACITY"] = function(msg)
  local cmd = (msg or ""):lower():match("^%s*(%S*)")
  if cmd == "" then Opacity_Toggle()
  elseif cmd == "pick" or cmd == "pipette" then OP.StartPicker()
  elseif cmd == "shot" or cmd == "capture" then Opacity_ToggleScreenshot()
  elseif cmd == "on" then OP.SetEnabled(true); OP.Print(T("FLASH_ON", "activé"))
  elseif cmd == "off" then OP.SetEnabled(false); OP.Print(T("FLASH_OFF", "suspendu (fenêtres rendues à leur opacité d'origine)"))
  elseif cmd == "options" or cmd == "config" then Opacity_OpenOptions()
  elseif cmd == "reset" then OP.ResetProfile()
  else
    OP.Print(T("HELP", "commandes : /opacity (fenêtre), pick (pipette), shot (capture d'écran), on, off, options, reset"))
  end
end
