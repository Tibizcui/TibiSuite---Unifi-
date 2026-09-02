--[[============================================================================
  DailyTracker - Glue module pour TibiSuite
  ---------------------------------------------------------------------------
  Ce fichier NE TOUCHE PAS a DailyTrackerDB ni au code de suivi. Il inscrit
  DailyTracker comme onglet de la suite unifiee :
    - RegisterModule : ajoute la vignette "Daily" (accent cyan) au catalogue,
      avec ouverture (DailyTracker_Toggle) et options (DailyTracker_OpenOptions).
    - masque le bouton minimap individuel : un seul bouton pour toute la suite.
    - rattrape l'habillage de la fenetre DTMainFrame (liseré cyan + controles),
      car en LoadOnDemand le PLAYER_LOGIN du module ne se declenche plus et
      c'est lui qui, via DailyTracker_Suite.lua, habillait la fenetre.

  La recherche globale reste geree par DailyTracker_Suite.lua (RegisterSearch),
  conserve dans le .toc. On ne la re-enregistre donc PAS ici : aucun doublon.
  Charge en dernier par DailyTracker.toc, apres DailyTracker.lua et le _Suite.
============================================================================]]

local FRAME  = "DTMainFrame"
local ACCENT = { 0.086, 0.769, 0.988 }   -- cyan (logo #16C4FC) - accent existant
local KEY    = "Daily"

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

-- Le core a-t-il explicitement desactive ce module ? Convention : absence de
-- TibiSuiteDB.enabledModules (jamais configure) => actif par defaut ; sinon
-- seule la presence de [KEY]=true active (voir PostBox pour la meme regle).
local function IsEnabledByCore()
  if not (TibiSuiteDB and type(TibiSuiteDB.enabledModules) == "table") then return true end
  return TibiSuiteDB.enabledModules[KEY] == true
end

-- ---------------------------------------------------------- Habillage fenetre
-- En LoadOnDemand, la decoration faite par DailyTracker_Suite.lua sur son
-- PLAYER_LOGIN ne tourne plus. On refait donc l'habillage ici, en differe.
-- Le provider de recherche du header est REUTILISE tel quel : on le relit dans
-- le registre du socle ou DailyTracker_Suite.lua l'a deja inscrit (pas de
-- doublon, pas d'invention).
local function Decorate()
  local ui = GetUI(); local f = _G[FRAME]
  if not (ui and f) then return end
  if not f._tibiSkinned then
    ui.SkinFrame(f, ACCENT)
    f._tibiSkinned = true
  end
  if f._tibiControls then return end
  local prov
  local reg = ui.searchProviders
  if reg and reg[KEY] then prov = reg[KEY].fn end
  ui.AddHeaderControls(f, {
    accent    = ACCENT,
    onOptions = function() if _G.DailyTracker_OpenOptions then _G.DailyTracker_OpenOptions() end end,
    provider  = prov,
  })
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
  })
end

-- La fenetre DTMainFrame est construite par DailyTracker.lua sur son
-- ADDON_LOADED, juste apres le chargement de ce fichier. On habille donc en
-- differe et on remasque le bouton minimap (mode module uniquement), avec
-- des tentatives de secours.
C_Timer.After(0.2, function() HideOwnMinimap(); Decorate() end)
C_Timer.After(1.0, function() HideOwnMinimap(); Decorate() end)
C_Timer.After(3.0, function() HideOwnMinimap(); Decorate() end)
