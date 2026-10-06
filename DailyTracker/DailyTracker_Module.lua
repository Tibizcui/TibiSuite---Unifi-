--[[============================================================================
  DailyTracker - Glue module pour TibiSuite
  ---------------------------------------------------------------------------
  Ce fichier NE TOUCHE PAS a DailyTrackerDB ni au code de suivi. Il inscrit
  DailyTracker comme onglet de la suite unifiee :
    - RegisterModule : ajoute la vignette "Daily" (accent cyan) au catalogue,
      avec ouverture (DailyTracker_Toggle) et options (DailyTracker_OpenOptions).
    - masque le bouton minimap individuel : un seul bouton pour toute la suite.
    - l'habillage de DTMainFrame (liseré cyan + contrôles) est fait UNIQUEMENT
      par DailyTracker_Suite.lua (l'ancien doublon d'ici a été retiré : le
      module n'est plus LoadOnDemand, son PLAYER_LOGIN tourne toujours).

  La recherche globale reste geree par DailyTracker_Suite.lua (RegisterSearch),
  conserve dans le .toc. On ne la re-enregistre donc PAS ici : aucun doublon.
  Charge en dernier par DailyTracker.toc, apres DailyTracker.lua et le _Suite.
============================================================================]]

local FRAME  = "DTMainFrame"
local ACCENT = { 0.086, 0.769, 0.988 }   -- cyan (logo #16C4FC) - accent existant
local KEY    = "Daily"

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

-- Le core a-t-il explicitement desactive ce module ? Convention : absence de
-- TibiSuiteDB.enabledModules (jamais configure) => actif par defaut ; sinon
-- seule la presence de [KEY]=true active (voir PostBox pour la meme regle).
local function IsEnabledByCore()
  if not (TibiSuiteDB and type(TibiSuiteDB.enabledModules) == "table") then return true end
  return TibiSuiteDB.enabledModules[KEY] == true
end

-- Un seul bouton minimap pour la suite EN MODE MODULE seulement : on masque
-- celui de DailyTracker (le core le re-masque aussi via
-- HideIndividualMinimapButtons ; ceinture et bretelles). EN MODE STANDALONE
-- (pas de core), on le laisse tel quel : c'est le seul bouton minimap
-- disponible pour ce module, il doit rester visible.
local function HideOwnMinimap()
  if not HasCore() then return end
  local btn = _G["DTMinimapBtn"]
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
-- MODE MODULE (core present) : inscription au catalogue unifie, sauf si
-- explicitement desactive dans le panneau Modules du core.
-- MODE STANDALONE (core absent) : rien a faire ici - DailyTracker.lua cree
-- deja son propre bouton minimap et sa commande slash /dt de facon
-- inconditionnelle, independamment de ce fichier.
-- searchProvider volontairement absent : DailyTracker_Suite.lua a deja appele
-- RegisterSearch(KEY, ...). Le passer ici recreerait un doublon.
if HasCore() and IsEnabledByCore() then
  TibiSuite.RegisterModule({
    key       = KEY,
    label     = "Daily",
    accent    = ACCENT,
    onOpen    = function() if _G.DailyTracker_Toggle then _G.DailyTracker_Toggle() end end,
    onOptions = function() if _G.DailyTracker_OpenOptions then _G.DailyTracker_OpenOptions() end end,
    statusFn  = function() if _G.DailyTracker_Status then return _G.DailyTracker_Status() end end,
  })
end

-- Le bouton minimap est cree par DailyTracker.lua sur son ADDON_LOADED,
-- juste apres le chargement de ce fichier : masquage differe, avec une
-- tentative de secours (mode module uniquement).
C_Timer.After(0.2, HideOwnMinimap)
C_Timer.After(3.0, HideOwnMinimap)
