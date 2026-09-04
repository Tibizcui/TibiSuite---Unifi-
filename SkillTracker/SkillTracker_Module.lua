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
-- celui de SkillTracker (le core le re-masque aussi ; ceinture et bretelles).
-- En mode standalone, on le laisse visible : c'est le seul bouton disponible.
local function HideOwnMinimap()
  if not HasCore() then return end
  local btn = _G["SkillTrackerMinimapBtn"]
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

-- ---------------------------------------------------------- Inscription suite
-- MODE MODULE : inscription au catalogue, sauf si explicitement desactive.
-- MODE STANDALONE : rien a faire ici - SkillTracker cree deja son propre
-- bouton minimap (UI.lua) et sa commande slash /skt de facon inconditionnelle.
if HasCore() and IsEnabledByCore() then
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
