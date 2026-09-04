--[[============================================================================
  MiniHub - Glue module pour TibiSuite
  ---------------------------------------------------------------------------
  Ce fichier NE TOUCHE PAS a MiniHubDB ni au code de l'addon. Il complete le
  glue historique MiniHub_Suite.lua (conserve dans le toc) qui gere deja les
  options flottantes, la recherche globale (RegisterSearch) et l'habillage de
  la fenetre. Ici on se limite donc a :
    - RegisterModule : ajoute l'onglet "MiniHub" (accent or) a la barre unifiee
      et branche onOpen / onOptions sur les fonctions globales du module.
    - masquer le bouton minimap individuel : un seul bouton pour toute la suite.
  IMPORTANT : searchProvider = nil ici. Le provider de recherche existe deja
  dans MiniHub_Suite.lua qui l'inscrit lui-meme (RegisterSearch, des le
  chargement du fichier), on ne le re-enregistre donc pas une seconde fois.
  Charge en dernier par MiniHub.toc, apres MiniHub_Suite.lua.
============================================================================]]

local KEY     = "MiniHub"
local ACCENT  = { 0.988, 0.843, 0.282 }   -- or vif (logo #FCD748)
local MINIMAP = "LibDBIcon10_MiniHub"

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

-- Un seul bouton minimap pour la suite EN MODE MODULE seulement : on masque
-- celui de MiniHub (le core le re-masque aussi ; ceinture et bretelles).
-- En mode standalone, on le laisse visible : c'est le seul bouton disponible.
local function HideOwnMinimap()
  if not HasCore() then return end
  local btn = _G[MINIMAP]
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
-- MODE STANDALONE : rien a faire ici - MiniHub cree deja son propre bouton
-- minimap (via LibDBIcon) et sa commande slash /minihub de facon
-- inconditionnelle.
if HasCore() and IsEnabledByCore() then
  TibiSuite.RegisterModule({
    key            = KEY,
    label          = "MiniHub",
    accent         = ACCENT,
    onOpen         = function() if _G.MiniHub_Toggle then _G.MiniHub_Toggle() end end,
    onOptions      = function() if _G.MiniHub_OpenOptions then _G.MiniHub_OpenOptions() end end,
    -- La recherche est deja inscrite par MiniHub_Suite.lua : on ne duplique pas.
    searchProvider = nil,
  })
end
-- Repli recherche : inutile ici. Si la suite est absente mais le socle present,
-- MiniHub_Suite.lua a deja appele GetUI().RegisterSearch de son cote.

-- Le bouton minimap est cree par MiniHub.lua (via LibDBIcon) apres nous ou en
-- differe ; on tente plusieurs fois de le masquer par securite.
if GetUI() then
  C_Timer.After(0.2, HideOwnMinimap)
  C_Timer.After(1.0, HideOwnMinimap)
  C_Timer.After(3.0, HideOwnMinimap)
else
  C_Timer.After(1.0, HideOwnMinimap)
end
