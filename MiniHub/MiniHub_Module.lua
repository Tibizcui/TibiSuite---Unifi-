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

-- Un seul bouton minimap pour la suite : on masque celui de MiniHub.
-- (Le core le re-masque aussi ; ceinture et bretelles avec HookScript OnShow.)
local function HideOwnMinimap()
  local btn = _G[MINIMAP]
  if btn and btn.Hide then
    btn:Hide()
    if not btn.__tibiHooked then
      btn.__tibiHooked = true
      btn:HookScript("OnShow", function(self) self:Hide() end)
    end
  end
end

-- ---------------------------------------------------------- Inscription suite
-- Le core est charge avant nous (## Dependencies: TibiSuite), donc l'API existe.
if TibiSuite and TibiSuite.RegisterModule then
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
