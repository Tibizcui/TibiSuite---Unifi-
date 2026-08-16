--[[============================================================================
  SkillTracker - Glue module pour TibiSuite
  ---------------------------------------------------------------------------
  Ce fichier NE TOUCHE PAS a SkillTrackerDB ni au scan des metiers. Il inscrit
  SkillTracker comme onglet de la suite unifiee :
    - RegisterModule : ajoute la vignette "Metiers" (accent emeraude), avec
      ouverture (SkillTracker_Toggle) et options (SkillTracker_OpenOptions).
    - masque le bouton minimap individuel : un seul bouton pour toute la suite.

  La recherche globale reste geree par Core.lua (BuildSearchProvider appelle
  UI.RegisterSearch au chargement, donc valable meme sans PLAYER_LOGIN). On ne
  la re-enregistre donc PAS ici : aucun doublon, searchProvider volontairement nil.
  Charge en dernier par SkillTracker.toc, apres Core.lua et UI.lua.
============================================================================]]

local ACCENT = { 0.000, 1.000, 0.596 }   -- emeraude Monk #00FF98 (identite SkillTracker)
local KEY    = "Skill"

-- Un seul bouton minimap pour la suite : on masque celui de SkillTracker.
-- (Le core le re-masque aussi via HideIndividualMinimapButtons ; ceinture et
--  bretelles, plus un HookScript OnShow pour le cas ou il tente de revenir.)
local function HideOwnMinimap()
  local btn = _G["SkillTrackerMinimapBtn"]
  if btn and btn.Hide then
    btn:Hide()
    if not btn.__tibiHooked then
      btn.__tibiHooked = true
      btn:HookScript("OnShow", function(self) self:Hide() end)
    end
  end
end

-- ---------------------------------------------------------- Inscription suite
-- Le core est charge avant nous (## Dependencies: TibiSuite), l'API existe.
if TibiSuite and TibiSuite.RegisterModule then
  TibiSuite.RegisterModule({
    key       = KEY,
    label     = "Metiers",
    accent    = ACCENT,
    onOpen    = function() if _G.SkillTracker_Toggle then _G.SkillTracker_Toggle() end end,
    onOptions = function() if _G.SkillTracker_OpenOptions then _G.SkillTracker_OpenOptions() end end,
  })
end

-- Le bouton minimap est cree par UI.lua sur l'ADDON_LOADED du module, juste
-- apres ce fichier. On le masque en differe, avec des tentatives de secours.
C_Timer.After(0.2, HideOwnMinimap)
C_Timer.After(1.0, HideOwnMinimap)
C_Timer.After(3.0, HideOwnMinimap)
