--[[============================================================================
  RepBar - Glue module pour TibiSuite
  ---------------------------------------------------------------------------
  Ce fichier NE TOUCHE PAS a RepBarDB ni au code de la barre. Il se contente
  d'inscrire RepBar dans la suite :
    - RegisterModule : ajoute l'onglet "RepBar" (accent azur) a la barre
      unifiee. RepBar n'a pas de recherche propre (RenTracker fournit deja la
      recherche de factions), donc searchProvider reste nil.
    - rattrapage cosmetique : rebranche le bouton texte "Options" sur la barre, car le
      handler PLAYER_LOGIN de RepBar.lua ne se declenche plus en LoadOnDemand.
  RepBar n'a pas de bouton minimap propre : rien a masquer de ce cote.
  Charge en dernier par RepBar.toc, apres RepBar.lua.
============================================================================]]

local KEY    = "RepBar"
local LABEL  = "RepBar"
local ACCENT = { 0.36, 0.68, 0.96 }   -- azur d'identite RepBar
local FRAME  = "RepBarContainer"
local L      = RepBarL or {}
local function T(key, default) return L[key] or default end

local function GetUI() return _G.TibiMidnight end

-- MODE DOUBLE : le core est-il present et fonctionnel ?
local function HasCore()
  return _G.TibiSuite and _G.TibiSuite.RegisterModule and true or false
end

-- Rappel du site officiel, 10s apres le login, UNIQUEMENT en mode standalone
-- (sans core) : si TibiSuite est present, c'est LUI qui affiche ce message
-- une seule fois (voir TibiSuiteCore.lua) - sinon il apparaitrait jusqu'a
-- 12 fois, une par module.
if not HasCore() then
  C_Timer.After(45, function()
    print("|cFFC41F3BTibiSuite|r : plus d'infos sur |cFFFFD700https://www.tibiscui.fr|r")
    print("|cFFC41F3BTibiSuite|r : télécharge Tibi-Companion sur |cFFFFD700https://tibiscui.fr/tibi-companion.html|r")
  end)
end

local function IsEnabledByCore()
  if not (TibiSuiteDB and type(TibiSuiteDB.enabledModules) == "table") then return true end
  return TibiSuiteDB.enabledModules[KEY] == true
end

-- Rattrapage cosmetique : habille la barre au style socle (bouton texte
-- "Options"). Le handler PLAYER_LOGIN d'origine ne tourne plus en LoadOnDemand.
local function Decorate()
  local ui = GetUI() ; local f = _G[FRAME]
  if not (ui and f) then return end
  if f._tibiControls then return end
  if ui.AddHeaderControls then
    ui.AddHeaderControls(f, {
      accent = ACCENT,
      onOptions = function() if _G.RepBar_OpenOptions then _G.RepBar_OpenOptions() end end,
    })
  end
end

-- ============================================================================
-- MODE STANDALONE : RepBar n'a pas de bouton minimap propre (barre permanente,
-- pas de fenetre a ouvrir/fermer). On en construit un ici, uniquement quand
-- le core est absent.
-- ============================================================================
local function BuildStandaloneMinimapButton()
  if _G.RepBarMinimapBtn then return end
  local btn = CreateFrame("Button", "RepBarMinimapBtn", Minimap)
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
  icon:SetTexture("Interface\\AddOns\\RepBar\\medias\\Logo")

  RepBarDB = RepBarDB or {}
  RepBarDB.minimapAngle = RepBarDB.minimapAngle or 200
  local function UpdatePosition()
    local angle = math.rad(RepBarDB.minimapAngle)
    local radius = 105
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
  end

  btn:SetScript("OnDragStart", function(self) self.dragging = true end)
  btn:SetScript("OnDragStop", function(self) self.dragging = false end)
  btn:SetScript("OnUpdate", function(self)
    if not self.dragging then return end
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    RepBarDB.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
    UpdatePosition()
  end)

  btn:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
      if _G.RepBar_OpenOptions then _G.RepBar_OpenOptions() end
    elseif _G.RepBar_Toggle then
      _G.RepBar_Toggle()
    end
  end)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("RepBar")
    GameTooltip:AddLine(T("MM_TT_LEFT", "Clic gauche : afficher/masquer"), 0.9, 0.9, 0.95)
    GameTooltip:AddLine(T("MM_TT_RIGHT", "Clic droit : options"), 0.9, 0.9, 0.95)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  UpdatePosition()
end

-- MODE MODULE : inscription au catalogue, sauf si explicitement desactive.
-- Pas de searchProvider (RenTracker fournit deja la recherche de factions).
-- MODE STANDALONE : construit son propre bouton minimap.
if HasCore() and IsEnabledByCore() then
  TibiSuite.RegisterModule({
    key            = KEY,
    label          = LABEL,
    accent         = ACCENT,
    onOpen         = function() if _G.RepBar_Toggle then _G.RepBar_Toggle() end end,
    onOptions      = function() if _G.RepBar_OpenOptions then _G.RepBar_OpenOptions() end end,
    searchProvider = nil,
  })
elseif not HasCore() then
  BuildStandaloneMinimapButton()
end

-- La barre RepBarContainer est construite par RepBar.lua sur son ADDON_LOADED,
-- qui se declenche juste avant le chargement de ce fichier. On habille en
-- differe, avec quelques tentatives de secours.
C_Timer.After(0.2, Decorate)
C_Timer.After(1.0, Decorate)
C_Timer.After(3.0, Decorate)
