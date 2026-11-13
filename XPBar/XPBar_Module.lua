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
local L      = XPBarL or {}
local function T(key, default) return L[key] or default end

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
  -- Construit par le socle v23 (UI.MinimapButton, audit poids 2026-11-13,
  -- lot 5) : position, glisser (OnUpdate pose seulement pendant le
  -- deplacement) et collecteurs MiniHub / EllesmereUI geres au meme endroit.
  local UIm = _G.TibiMidnight
  if not (UIm and UIm.MinimapButton) then return end
  local btn = UIm.MinimapButton({
    name = "LibDBIcon10_XPBar", style = "compact", default = 200,
    icon = "Interface\\AddOns\\XPBar\\medias\\Logo",
    getAngle = function() if not (XPBarDB and XPBarDB.minimapMoved) then return 200 end return XPBarDB.minimapAngle end,
    setAngle = function(a) XPBarDB = XPBarDB or {}; XPBarDB.minimapAngle = a; XPBarDB.minimapMoved = true end,
    onClick = function(button)
      if button == "RightButton" then
        if _G.XPBar_OpenOptions then _G.XPBar_OpenOptions() end
      elseif _G.XPBar_Toggle then
        _G.XPBar_Toggle()
      end
    end,
    tooltip = function(tt)
      tt:AddLine("XPBar")
      tt:AddLine(T("MM_TT_LEFT", "Clic gauche : afficher/masquer"), 0.9, 0.9, 0.95)
      tt:AddLine(T("MM_TT_RIGHT", "Clic droit : options"), 0.9, 0.9, 0.95)
    end,
  })
  return btn
end

-- Rattrapage cosmetique : habille la barre XPBarContainer au style socle
-- (bouton texte "Options"). Le handler PLAYER_LOGIN d'origine (tibiEv dans
-- XPBar.lua) faisait ce travail, mais il ne tourne plus quand le module se
-- charge a la demande, PLAYER_LOGIN etant deja passe.
-- Un seul code d'habillage : celui de XPBar.lua (XPBar_Decorate, idempotent).
local function Decorate()
  if _G.XPBar_Decorate then _G.XPBar_Decorate() end
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
  -- Construit a la connexion : a la lecture de ce fichier, XPBarDB n'est pas
  -- encore chargee (la position deplacee n'etait jamais restauree).
  if IsLoggedIn and IsLoggedIn() then
    BuildStandaloneMinimapButton()
  else
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function(self) self:UnregisterAllEvents(); BuildStandaloneMinimapButton() end)
  end
end

-- La barre XPBarContainer est construite par XPBar.lua sur son ADDON_LOADED,
-- qui se declenche juste avant le chargement de ce fichier. On masque le
-- bouton minimap et on habille en differe, avec quelques tentatives de secours.
C_Timer.After(0.2, function() HideOwnMinimap(); Decorate() end)
C_Timer.After(1.0, function() HideOwnMinimap(); Decorate() end)
C_Timer.After(3.0, function() HideOwnMinimap(); Decorate() end)
