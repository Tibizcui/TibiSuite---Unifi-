--[[============================================================================
  XPBar - Glue module pour TibiSuite  (nouveau fichier, pas de _Suite existant)
  ---------------------------------------------------------------------------
  Ce fichier NE TOUCHE PAS a XPBarDB ni au code de la barre. Il se contente
  d'inscrire XPBar dans la suite :
    - RegisterModule : ajoute l'onglet "XPBar" (accent violet) a la barre
      unifiee. XPBar n'a pas de recherche, donc searchProvider reste nil.
    - masque le bouton minimap individuel : un seul bouton pour toute la suite.
    - rattrapage cosmetique : rebranche le bouton texte "Options" sur la barre, car le
      handler PLAYER_LOGIN de XPBar.lua ne se declenche plus en LoadOnDemand.
  Charge en dernier par XPBar.toc, apres XPBar.lua.
============================================================================]]

local KEY    = "XPBar"
local LABEL  = "XPBar"
local ACCENT = { 0.737, 0.220, 0.980 }   -- violet (logo #BC38FA)
local FRAME  = "XPBarContainer"

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
  C_Timer.After(10, function()
    print("|cFFC41F3BTibiSuite|r : plus d'infos sur |cFFFFD700https://www.tibiscui.fr|r")
  end)
end

local function IsEnabledByCore()
  if not (TibiSuiteDB and type(TibiSuiteDB.enabledModules) == "table") then return true end
  return TibiSuiteDB.enabledModules[KEY] == true
end

-- Un seul bouton minimap pour la suite EN MODE MODULE seulement : on masque
-- celui de XPBar (le core le re-masque aussi ; ceinture et bretelles).
-- En mode standalone, on le laisse visible : c'est le seul bouton disponible.
local function HideOwnMinimap()
  if not HasCore() then return end
  local btn = _G["LibDBIcon10_XPBar"]
  if btn and btn.Hide then
    btn:Hide()
    if not btn.__tibiHooked then
      btn.__tibiHooked = true
      -- Differe via C_Timer.After(0, ...) : eviter d'executer notre code de
      -- facon synchrone dans le script OnShow d'un bouton qui ne nous
      -- appartient pas (piege ADDON_ACTION_FORBIDDEN, voir TibiSuiteCore.lua).
      btn:HookScript("OnShow", function(self) C_Timer.After(0, function() self:Hide() end) end)
    end
  end
end

-- ============================================================================
-- MODE STANDALONE : XPBar n'a pas de bouton minimap propre (barre permanente,
-- pas de fenetre a ouvrir/fermer). On en construit un ici, uniquement quand
-- le core est absent, pour donner un point d'entree (afficher/masquer la
-- barre, ouvrir les options) sans dependre de la barre TibiSuite unifiee.
-- ============================================================================
local function BuildStandaloneMinimapButton()
  if _G.LibDBIcon10_XPBar then return end
  local btn = CreateFrame("Button", "LibDBIcon10_XPBar", Minimap)
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
  icon:SetTexture("Interface\\AddOns\\XPBar\\medias\\Logo")

  XPBarDB = XPBarDB or {}
  XPBarDB.minimapAngle = XPBarDB.minimapAngle or 200
  local function UpdatePosition()
    local angle = math.rad(XPBarDB.minimapAngle)
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
    XPBarDB.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
    UpdatePosition()
  end)

  btn:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
      if _G.XPBar_OpenOptions then _G.XPBar_OpenOptions() end
    elseif _G.XPBar_Toggle then
      _G.XPBar_Toggle()
    end
  end)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("XPBar")
    GameTooltip:AddLine("Clic gauche : afficher/masquer", 0.9, 0.9, 0.95)
    GameTooltip:AddLine("Clic droit : options", 0.9, 0.9, 0.95)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  UpdatePosition()
end

-- Rattrapage cosmetique : habille la barre XPBarContainer au style socle
-- (bouton texte "Options"). Le handler PLAYER_LOGIN d'origine (tibiEv dans
-- XPBar.lua) faisait ce travail, mais il ne tourne plus quand le module se
-- charge a la demande, PLAYER_LOGIN etant deja passe.
local function Decorate()
  local ui = GetUI(); local f = _G[FRAME]
  if not (ui and f) then return end
  if f._tibiControls then return end
  if ui.AddHeaderControls then
    ui.AddHeaderControls(f, {
      accent = ACCENT,
      onOptions = function() if _G.XPBar_OpenOptions then _G.XPBar_OpenOptions() end end,
    })
  end
end

-- MODE MODULE : inscription au catalogue, sauf si explicitement desactive.
-- Pas de searchProvider : XPBar n'expose aucune recherche.
-- MODE STANDALONE : construit son propre bouton minimap (XPBar.lua n'en cree
-- pas, c'est une barre permanente sans fenetre a ouvrir/fermer).
if HasCore() and IsEnabledByCore() then
  TibiSuite.RegisterModule({
    key           = KEY,
    label         = LABEL,
    accent        = ACCENT,
    onOpen        = function() if _G.XPBar_Toggle then _G.XPBar_Toggle() end end,
    onOptions     = function() if _G.XPBar_OpenOptions then _G.XPBar_OpenOptions() end end,
    searchProvider = nil,
  })
elseif not HasCore() then
  BuildStandaloneMinimapButton()
end

-- La barre XPBarContainer est construite par XPBar.lua sur son ADDON_LOADED,
-- qui se declenche juste avant le chargement de ce fichier. On masque le
-- bouton minimap et on habille en differe, avec quelques tentatives de secours.
C_Timer.After(0.2, function() HideOwnMinimap(); Decorate() end)
C_Timer.After(1.0, function() HideOwnMinimap(); Decorate() end)
C_Timer.After(3.0, function() HideOwnMinimap(); Decorate() end)
