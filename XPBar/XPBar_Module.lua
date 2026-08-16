--[[============================================================================
  XPBar - Glue module pour TibiSuite  (nouveau fichier, pas de _Suite existant)
  ---------------------------------------------------------------------------
  Ce fichier NE TOUCHE PAS a XPBarDB ni au code de la barre. Il se contente
  d'inscrire XPBar dans la suite :
    - RegisterModule : ajoute l'onglet "XPBar" (accent violet) a la barre
      unifiee. XPBar n'a pas de recherche, donc searchProvider reste nil.
    - masque le bouton minimap individuel : un seul bouton pour toute la suite.
    - rattrapage cosmetique : rebranche la roue crantee sur la barre, car le
      handler PLAYER_LOGIN de XPBar.lua ne se declenche plus en LoadOnDemand.
  Charge en dernier par XPBar.toc, apres XPBar.lua.
============================================================================]]

local KEY    = "XPBar"
local LABEL  = "XPBar"
local ACCENT = { 0.737, 0.220, 0.980 }   -- violet (logo #BC38FA)
local FRAME  = "XPBarContainer"

local function GetUI() return _G.TibiMidnight end

-- Un seul bouton minimap pour la suite : on masque celui de XPBar (LibDBIcon).
-- Le core le re-masque aussi ; ceinture et bretelles.
local function HideOwnMinimap()
  local btn = _G["LibDBIcon10_XPBar"]
  if btn and btn.Hide then
    btn:Hide()
    if not btn.__tibiHooked then
      btn.__tibiHooked = true
      btn:HookScript("OnShow", function(self) self:Hide() end)
    end
  end
end

-- Rattrapage cosmetique : habille la barre XPBarContainer au style socle
-- (roue crantee -> options). Le handler PLAYER_LOGIN d'origine (tibiEv dans
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

-- Inscription dans la suite. Le core est charge avant nous (## Dependencies:
-- TibiSuite), donc l'API existe. Pas de searchProvider : XPBar n'expose aucune
-- recherche.
if TibiSuite and TibiSuite.RegisterModule then
  TibiSuite.RegisterModule({
    key           = KEY,
    label         = LABEL,
    accent        = ACCENT,
    onOpen        = function() if _G.XPBar_Toggle then _G.XPBar_Toggle() end end,
    onOptions     = function() if _G.XPBar_OpenOptions then _G.XPBar_OpenOptions() end end,
    searchProvider = nil,
  })
end

-- La barre XPBarContainer est construite par XPBar.lua sur son ADDON_LOADED,
-- qui se declenche juste avant le chargement de ce fichier. On masque le
-- bouton minimap et on habille en differe, avec quelques tentatives de secours.
C_Timer.After(0.2, function() HideOwnMinimap(); Decorate() end)
C_Timer.After(1.0, function() HideOwnMinimap(); Decorate() end)
C_Timer.After(3.0, function() HideOwnMinimap(); Decorate() end)
