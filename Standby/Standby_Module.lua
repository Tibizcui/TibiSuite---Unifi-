--[[============================================================================
  Standby - Glue module pour TibiSuite
  ---------------------------------------------------------------------------
  MODE MODULE (core present) : inscrit l'onglet "Standby" (accent rose aube)
  dans la barre unifiee ; pas de bouton minimap propre.
  MODE STANDALONE (core absent) : construit son propre bouton minimap.
  Dans les deux cas : slash /standby et /afkscreen. StandbyDB ne change
  jamais entre les deux modes.
  Charge en dernier par Standby.toc.
============================================================================]]

local ADDON, SB = ...
local T = SB.T
local KEY = SB.KEY

local function HasCore()
  return _G.TibiSuite and _G.TibiSuite.RegisterModule and true or false
end

if not HasCore() then
  C_Timer.After(45, function()
    print("|cFFC41F3BTibiSuite|r : plus d'infos sur |cFFFFD700https://www.tibiscui.fr|r")
    print("|cFFC41F3BTibiSuite|r : télécharge Tibi-Companion sur |cFFFFD700https://tibiscui.fr/tibi-companion.html|r")
  end)
end

-- Decision validee : pas de migration ponctuelle (decoche pour les joueurs
-- existants). enabledModules == nil = suite jamais configuree = tout actif.
local function IsEnabledByCore()
  if not (TibiSuiteDB and type(TibiSuiteDB.enabledModules) == "table") then return true end
  return TibiSuiteDB.enabledModules[KEY] and true or false
end

-- ============================================================================
-- MODE STANDALONE : bouton minimap (meme construction qu'Opacity)
-- ============================================================================
local function BuildStandaloneMinimapButton()
  if _G.StandbyMinimapBtn then return end
  local btn = CreateFrame("Button", "StandbyMinimapBtn", Minimap)
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
  icon:SetTexture(SB.LOGO)

  local function Angle() return (StandbyDB and tonumber(StandbyDB.minimapAngle)) or 200 end
  local function UpdatePosition()
    local angle = math.rad(Angle())
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 105, math.sin(angle) * 105)
  end
  local function OnDragUpdate()
    if not StandbyDB then return end
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    StandbyDB.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
    UpdatePosition()
  end
  btn:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnDragUpdate) end)
  btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  btn:SetScript("OnClick", function(_, button)
    if button == "RightButton" then SB.Preview() else Standby_Toggle() end
  end)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Standby")
    GameTooltip:AddLine(T("MM_TT_LEFT", "Clic gauche : options"), 0.9, 0.9, 0.95)
    GameTooltip:AddLine(T("MM_TT_RIGHT", "Clic droit : aperçu de l'écran"), 0.9, 0.9, 0.95)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  UpdatePosition()
end

if HasCore() and IsEnabledByCore() then
  TibiSuite.RegisterModule({
    key            = KEY,
    label          = "Standby",
    accent         = SB.ACCENT,
    onOpen         = function() Standby_Toggle() end,
    onOptions      = function() Standby_OpenOptions() end,
    searchProvider = SB.SearchProvider,   -- Bridge.lua
  })
elseif not HasCore() then
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:SetScript("OnEvent", function(self) self:UnregisterAllEvents(); BuildStandaloneMinimapButton() end)
end

-- ============================================================================
-- SLASH : /standby [test | options | status | on | off | probe | help]
-- ============================================================================
SLASH_TIBISTANDBY1 = "/standby"
SLASH_TIBISTANDBY2 = "/afkscreen"
SlashCmdList["TIBISTANDBY"] = function(msg)
  local cmd = ((msg or ""):match("^%s*(%S*)") or ""):lower()
  if cmd == "" or cmd == "options" or cmd == "config" then Standby_Toggle()
  elseif cmd == "test" or cmd == "apercu" or cmd == "preview" then SB.Preview()
  elseif cmd == "on" then SB.SetEnabled(true); SB.Print(T("ST_ON", "actif"))
  elseif cmd == "off" then SB.SetEnabled(false); SB.Print(T("ST_OFF", "désactivé"))
  elseif cmd == "probe" or cmd == "sonde" then SB.RunProbe()
  elseif cmd == "status" or cmd == "etat" then SB.PrintStatus()
  else
    SB.Print(T("HELP", "commandes : /standby (options), test (aperçu 15 s), status (pourquoi l'écran s'affiche ou non), on, off, probe (vérification en jeu)"))
  end
end
