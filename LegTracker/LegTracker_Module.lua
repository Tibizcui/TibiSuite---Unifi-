--[[============================================================================
  LegTracker - Glue module pour TibiSuite (inscription LoadOnDemand)
  ---------------------------------------------------------------------------
  Ce fichier NE TOUCHE PAS a LegTrackerDB. Il complete LegTracker_Suite.lua
  (conserve) qui, lui, definit deja :
    - le panneau d'options (fonction globale LegTracker_OpenOptions),
    - l'enregistrement de la recherche globale (RegisterSearch, au chargement).
  Ce glue se limite donc a :
    - RegisterModule : ajoute l'onglet "LegTracker" (accent orange) a la barre
      unifiee. On NE re-enregistre PAS la recherche (deja fait par _Suite.lua).
    - masque le bouton minimap individuel : un seul bouton pour toute la suite.
    - rattrapage cosmetique de la fenetre : en LoadOnDemand le PLAYER_LOGIN du
      module ne se declenche plus, donc l'habillage (liseré + loupe + options)
      n'est plus applique par _Suite.lua ; on le rejoue ici en differe.
  Charge en dernier par LegTracker.toc, apres LegTracker.lua et LegTracker_Suite.lua.
============================================================================]]

local FRAME  = "LegTrackerMainFrame"
local ACCENT = { 1.000, 0.427, 0.043 }   -- orange (logo #FF6D0B)
local KEY    = "Leg"
local LABEL  = "LegTracker"

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
-- Provider porte depuis LegTracker_Suite.lua, utilise UNIQUEMENT pour la loupe
-- de l'en-tete de la fenetre (habillage). La recherche GLOBALE, elle, reste
-- enregistree par _Suite.lua : on ne la re-enregistre pas ici. Lecture des
-- donnees a la volee, strictement non destructif.
local function provider(q)
  local out, ui = {}, GetUI()
  local data = _G.LegTrackerData
  if not ui or type(data) ~= "table" or type(data.Extensions) ~= "table" then return out end
  local function open()
    local f = _G[FRAME]
    if _G.LegTracker_Toggle and (not f or not f:IsShown()) then _G.LegTracker_Toggle() end
  end
  local function add(text) out[#out + 1] = { text = text, onClick = open } end
  for extKey, ext in pairs(data.Extensions) do
    if type(ext) == "table" and ext.items then
      local extLabel = ext.label or ext.key or tostring(extKey)
      for _, item in ipairs(ext.items) do
        local iname = item.name or "?"
        if (item.name and ui.Match(item.name, q))
           or (item.source and ui.Match(item.source, q)) then
          add(iname .. "  |cff808080" .. extLabel .. "|r")
        end
        if type(item.quests) == "table" then
          for _, qu in ipairs(item.quests) do
            local qhay = (qu.name or "") .. " " .. (qu.npc or "") .. " " .. (qu.zone or "")
            if ui.Match(qhay, q) then
              add((qu.name or "quête") .. "  |cff808080quête · " .. iname .. "|r")
            end
          end
        end
        if type(item.trackers) == "table" then
          for _, tr in ipairs(item.trackers) do
            if tr.name and ui.Match(tr.name, q) then
              add(tr.name .. "  |cff808080composant · " .. iname .. "|r")
            end
          end
        end
        if #out >= 80 then return out end
      end
    end
  end
  return out
end

-- ---------------------------------------------------------- Habillage fenetre
-- Rejoue l'habillage du _Suite.lua (Decorate local, devenu inaccessible car
-- declenche par PLAYER_LOGIN). Idempotent grace aux drapeaux _tibiSkinned /
-- _tibiControls (memes drapeaux que _Suite.lua) : aucun doublon possible.
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
    onOptions = function() if _G.LegTracker_OpenOptions then _G.LegTracker_OpenOptions() end end,
    provider = provider,
  })
end

-- Un seul bouton minimap pour la suite EN MODE MODULE seulement : on masque
-- celui de LegTracker (le core le re-masque aussi ; ceinture et bretelles).
-- En mode standalone, on le laisse visible : c'est le seul bouton disponible.
local function HideOwnMinimap()
  if not HasCore() then return end
  local btn = _G["LegTrackerMinimapBtn"]
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
-- MODE STANDALONE : rien a faire ici - LegTracker.lua cree deja son propre
-- bouton minimap et sa commande slash /lt de facon inconditionnelle.
if HasCore() and IsEnabledByCore() then
  TibiSuite.RegisterModule({
    key            = KEY,
    label          = LABEL,
    accent         = ACCENT,
    onOpen         = function() if _G.LegTracker_Toggle then _G.LegTracker_Toggle() end end,
    onOptions      = function() if _G.LegTracker_OpenOptions then _G.LegTracker_OpenOptions() end end,
    searchProvider = nil,  -- deja enregistree par LegTracker_Suite.lua (pas de doublon)
  })
elseif GetUI() and GetUI().RegisterSearch then
  -- Repli : suite absente mais socle present. _Suite.lua enregistre deja la
  -- recherche ; ce repli (meme cle) est purement defensif et idempotent.
  GetUI().RegisterSearch(KEY, LABEL, provider)
end

-- La fenetre LegTrackerMainFrame est construite par LegTracker.lua sur son
-- ADDON_LOADED. On habille donc en differe et on remasque le bouton minimap,
-- avec quelques tentatives de secours.
C_Timer.After(0.2, function() HideOwnMinimap(); Decorate() end)
C_Timer.After(1.0, function() HideOwnMinimap(); Decorate() end)
C_Timer.After(3.0, function() HideOwnMinimap(); Decorate() end)
