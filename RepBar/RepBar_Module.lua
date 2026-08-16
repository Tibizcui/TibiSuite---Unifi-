--[[============================================================================
  RepBar - Glue module pour TibiSuite
  ---------------------------------------------------------------------------
  Ce fichier NE TOUCHE PAS a RepBarDB ni au code de la barre. Il se contente
  d'inscrire RepBar dans la suite :
    - RegisterModule : ajoute l'onglet "RepBar" (accent azur) a la barre
      unifiee. RepBar n'a pas de recherche propre (RenTracker fournit deja la
      recherche de factions), donc searchProvider reste nil.
    - rattrapage cosmetique : rebranche la roue crantee sur la barre, car le
      handler PLAYER_LOGIN de RepBar.lua ne se declenche plus en LoadOnDemand.
  RepBar n'a pas de bouton minimap propre : rien a masquer de ce cote.
  Charge en dernier par RepBar.toc, apres RepBar.lua.
============================================================================]]

local KEY    = "RepBar"
local LABEL  = "RepBar"
local ACCENT = { 0.36, 0.68, 0.96 }   -- azur d'identite RepBar
local FRAME  = "RepBarContainer"

local function GetUI() return _G.TibiMidnight end

-- Rattrapage cosmetique : habille la barre au style socle (roue crantee ->
-- options). Le handler PLAYER_LOGIN d'origine ne tourne plus en LoadOnDemand.
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

-- Inscription dans la suite. Le core est charge avant nous (## Dependencies:
-- TibiSuite), donc l'API existe. Pas de searchProvider.
if TibiSuite and TibiSuite.RegisterModule then
  TibiSuite.RegisterModule({
    key            = KEY,
    label          = LABEL,
    accent         = ACCENT,
    onOpen         = function() if _G.RepBar_Toggle then _G.RepBar_Toggle() end end,
    onOptions      = function() if _G.RepBar_OpenOptions then _G.RepBar_OpenOptions() end end,
    searchProvider = nil,
  })
end

-- La barre RepBarContainer est construite par RepBar.lua sur son ADDON_LOADED,
-- qui se declenche juste avant le chargement de ce fichier. On habille en
-- differe, avec quelques tentatives de secours.
C_Timer.After(0.2, Decorate)
C_Timer.After(1.0, Decorate)
C_Timer.After(3.0, Decorate)
