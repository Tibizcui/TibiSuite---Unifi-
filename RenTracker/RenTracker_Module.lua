--[[============================================================================
  RenTracker - Glue module pour TibiSuite  (remplace RenTracker_Suite.lua)
  ---------------------------------------------------------------------------
  Ce fichier NE TOUCHE PAS a RenTrackerDB ni au code de donnees. Il se contente
  d'inscrire RenTracker dans la suite :
    - RegisterModule : ajoute l'onglet "Reput." (accent or) a la barre unifiee
      et branche le provider dans la recherche globale (RegisterSearch).
    - habille la fenetre RNTMainFrame au style socle (liseré or, loupe, options).
    - masque le bouton minimap individuel : un seul bouton pour toute la suite.
  Charge en dernier par RenTracker.toc, apres RenTracker.lua.
============================================================================]]

local FRAME  = "RNTMainFrame"
local ACCENT = { 0.867, 0.651, 0.412 }   -- or/sable (logo #DDA669) - accent existant
local LOGO   = "Interface\\AddOns\\RenTracker\\medias\\RenTracker"
local KEY    = "Rep"

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

local function OptGet(k) return _G.RenTrackerDB and _G.RenTrackerDB.options and _G.RenTrackerDB.options[k] end
local function OptSet(k, v)
  if _G.RenTrackerDB then _G.RenTrackerDB.options = _G.RenTrackerDB.options or {}; _G.RenTrackerDB.options[k] = v end
end

-- ---------------------------------------------------------------- Options
-- Panneau d'options au style socle (plat + liseré or), reutilise tel quel.
local panel
local function BuildOptions()
  local ui = GetUI(); if not ui then return nil end
  if panel then return panel end
  panel = ui.CreateOptionsPanel({
    name = "RenTrackerOptionsMidnight",
    title = "RenTracker - Options", accent = ACCENT })

  panel:Section("Fenêtre")
  panel:Button("Ouvrir / fermer", function()
    if _G.RenTracker_Toggle then _G.RenTracker_Toggle() end
  end)
  panel:Button("Recentrer la fenêtre", function()
    local f = _G[FRAME]; if f then f:ClearAllPoints(); f:SetPoint("CENTER") end
  end)

  panel:Section("Comportement")
  panel:Check("Suivi auto de la réputation par zone",
    function() return OptGet("autoTrack") end, function(v) OptSet("autoTrack", v) end)
  panel:Check("Message de bienvenue au login",
    function() return OptGet("loginMsg") end, function(v) OptSet("loginMsg", v) end)
  panel:Check("Son de notification",
    function() return OptGet("sound") end, function(v) OptSet("sound", v) end)

  panel:Section("Boutons flottants (barre TibiSuite)")
  panel:Check("Masquer le bouton Options",
    function() return TibiSuite and TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden("RNTMainFrame", "options") end,
    function(v) if TibiSuite and TibiSuite.SetCtrlHidden then TibiSuite.SetCtrlHidden("RNTMainFrame", "options", v) end end)
  panel:Check("Masquer le champ Recherche",
    function() return TibiSuite and TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden("RNTMainFrame", "search") end,
    function(v) if TibiSuite and TibiSuite.SetCtrlHidden then TibiSuite.SetCtrlHidden("RNTMainFrame", "search", v) end end)
  panel:Note("Le bouton Options et le champ Recherche debordent au-dessus de la fenetre. Meme masques, Maj+clic droit sur la fenetre ouvre ces options.")

  panel:Note("Astuce : clic droit sur l'onglet Réput. dans la barre TibiSuite ouvre aussi ces options.")
  return panel
end

function RenTracker_OpenOptions()
  local p = BuildOptions(); if p then p:Toggle() end
end

-- ---------------------------------------------------------------- Recherche
-- Provider inchange : lit RenTrackerData a la volee (factions + quetes).
local function provider(q)
  local out, ui = {}, GetUI()
  local data = _G.RenTrackerData
  if not ui or type(data) ~= "table" then return out end
  local function open()
    local f = _G[FRAME]
    if _G.RenTracker_Toggle and (not f or not f:IsShown()) then _G.RenTracker_Toggle() end
  end
  local function add(text) out[#out + 1] = { text = text, onClick = open } end
  for extKey, ext in pairs(data) do
    if type(ext) == "table" and ext.factions then
      for _, fac in ipairs(ext.factions) do
        local fname = fac.name or "?"
        local fhay = (fac.name or "") .. " " .. (fac.zone or "") .. " " .. (fac.qm_name or "")
        if ui.Match(fhay, q) then
          add(fname .. "  |cff808080" .. tostring(extKey) .. "|r")
        end
        if type(fac.quests) == "table" then
          for _, qu in ipairs(fac.quests) do
            local qhay = (qu.name or "") .. " " .. (qu.npc or "") .. " " .. (qu.zone or "")
            if ui.Match(qhay, q) then
              add((qu.name or "quête") .. "  |cff808080" .. fname .. "|r")
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
    onOptions = function() RenTracker_OpenOptions() end,
    provider = provider,
  })
end

-- Un seul bouton minimap pour la suite EN MODE MODULE seulement : on masque
-- celui de RenTracker (le core le re-masque aussi ; ceinture et bretelles).
-- En mode standalone, on le laisse visible : c'est le seul bouton disponible.
-- (RenTracker.lua a aussi son propre listener ADDON_LOADED=="TibiSuite" qui
-- cache directement RNTMinimapBtn : celui-la ne se declenche naturellement
-- que si TibiSuite est vraiment present, aucun changement necessaire la-bas.)
local function HideOwnMinimap()
  if not HasCore() then return end
  local btn = _G["RNTMinimapBtn"]
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
-- MODE STANDALONE : rien a faire ici - RenTracker.lua cree deja son propre
-- bouton minimap et sa commande slash /rt de facon inconditionnelle.
if HasCore() and IsEnabledByCore() then
  TibiSuite.RegisterModule({
    key           = KEY,
    label         = "Réput.",
    accent        = ACCENT,
    onOpen        = function() if _G.RenTracker_Toggle then _G.RenTracker_Toggle() end end,
    onOptions     = function() RenTracker_OpenOptions() end,
    searchProvider = provider,
  })
elseif GetUI() and GetUI().RegisterSearch then
  -- Repli : suite absente mais socle present -> au moins la recherche marche.
  GetUI().RegisterSearch(KEY, "Réput.", provider)
end

-- La fenetre RNTMainFrame est construite par RenTracker.lua sur son ADDON_LOADED,
-- qui se declenche juste apres le chargement de ce fichier. On habille donc en
-- differe (et on remasque le bouton minimap), avec quelques tentatives de secours.
C_Timer.After(0.2, function() HideOwnMinimap(); Decorate() end)
C_Timer.After(1.0, function() HideOwnMinimap(); Decorate() end)
C_Timer.After(3.0, function() HideOwnMinimap(); Decorate() end)
