--[[============================================================================
  DgnTracker - Glue module pour TibiSuite  (complete DgnTracker_Suite.lua)
  ---------------------------------------------------------------------------
  Ce fichier NE TOUCHE PAS a DgnTrackerDB ni au code de donnees. En mode
  LoadOnDemand, il complete DgnTracker_Suite.lua qui reste charge :
    - RegisterModule : ajoute l'onglet "Donjons" (accent bleu) a la barre
      unifiee de la suite.
    - habille la fenetre DGNMainFrame au style socle (rattrapage cosmetique :
      le handler PLAYER_LOGIN de _Suite.lua ne se declenche plus en LoD).
    - masque le bouton minimap individuel : un seul bouton pour toute la suite.
  La recherche globale et le panneau d'options restent geres par
  DgnTracker_Suite.lua ; on ne les re-enregistre pas ici (pas de doublon).
  Charge en dernier par DgnTracker.toc, apres DgnTracker.lua et _Suite.lua.
============================================================================]]

local FRAME  = "DGNMainFrame"
local ACCENT = { 0.008, 0.404, 0.988 }   -- bleu (logo #0267FC)
local LOGO   = "Interface\\AddOns\\DgnTracker\\medias\\DgnTracker"
local KEY    = "Dgn"

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

-- ---------------------------------------------------------------- Recherche
-- Provider identique a celui de _Suite.lua. Ici il sert uniquement a alimenter
-- la loupe de l'en-tete de la fenetre (habillage). L'inscription au registre
-- global de recherche reste faite par _Suite.lua : on ne la double pas.
local function provider(q)
  local out, ui = {}, GetUI()
  local data = _G.DgnTrackerData
  if not ui or type(data) ~= "table" then return out end
  for extKey, ext in pairs(data) do
    if type(ext) == "table" and ext.instances then
      for _, inst in ipairs(ext.instances) do
        local hay = (inst.name or "") .. " " .. (inst.zone or "") .. " " .. (inst.region or "")
        if ui.Match(hay, q) then
          out[#out + 1] = {
            text = (inst.name or "?") .. "  |cff808080" .. (inst.zone or tostring(extKey)) .. "|r",
            onClick = function()
              local f = _G[FRAME]
              if _G.DgnTracker_Toggle and (not f or not f:IsShown()) then _G.DgnTracker_Toggle() end
            end }
          if #out >= 60 then return out end
        end
      end
    end
  end
  return out
end

-- ---------------------------------------------------------- Habillage fenetre
local function Decorate()
  local ui = GetUI(); local f = _G[FRAME]
  if not (ui and f) then return end
  if not f._tibiSkinned then
    ui.SkinFrame(f, ACCENT)
    f._tibiSkinned = true
  end
  if f._tibiControls then return end
  ui.AddHeaderControls(f, {
    accent = ACCENT,
    onOptions = function() if _G.DgnTracker_OpenOptions then _G.DgnTracker_OpenOptions() end end,
    provider = provider,
  })
end

-- Un seul bouton minimap pour la suite EN MODE MODULE seulement : on masque
-- celui de DgnTracker (le core le re-masque aussi ; ceinture et bretelles).
-- En mode standalone, on le laisse visible : c'est le seul bouton disponible.
local function HideOwnMinimap()
  if not HasCore() then return end
  local btn = _G["DGNMinimapBtn"]
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
-- MODE STANDALONE : rien a faire ici - DgnTracker.lua cree deja son propre
-- bouton minimap et sa commande slash /dg de facon inconditionnelle.
if HasCore() and IsEnabledByCore() then
  TibiSuite.RegisterModule({
    key       = KEY,
    label     = "Donjons",
    accent    = ACCENT,
    onOpen    = function() if _G.DgnTracker_Toggle then _G.DgnTracker_Toggle() end end,
    onOptions = function() if _G.DgnTracker_OpenOptions then _G.DgnTracker_OpenOptions() end end,
    -- searchProvider volontairement omis : DgnTracker_Suite.lua enregistre
    -- deja la recherche pour la cle "Dgn".
  })
elseif GetUI() and GetUI().RegisterSearch then
  -- Repli : suite absente mais socle present. _Suite.lua a normalement deja
  -- inscrit la recherche ; on la re-poste par securite (meme cle -> ecrase).
  GetUI().RegisterSearch(KEY, "Donjons", provider)
end

-- Rattrapage LoadOnDemand : DGNMainFrame est construit par DgnTracker.lua sur
-- son ADDON_LOADED (juste avant ce fichier). On habille en differe et on
-- remasque le bouton minimap, avec quelques tentatives de secours.
C_Timer.After(0.2, function() HideOwnMinimap(); Decorate() end)
C_Timer.After(1.0, function() HideOwnMinimap(); Decorate() end)
C_Timer.After(3.0, function() HideOwnMinimap(); Decorate() end)
