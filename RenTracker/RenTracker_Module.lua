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
    title = "|cFF9480FFRenTracker|r  Options", accent = ACCENT })

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

-- Un seul bouton minimap pour la suite : on masque celui de RenTracker.
-- (Le core le re-masque aussi via HookScript ; ceinture et bretelles.)
local function HideOwnMinimap()
  local btn = _G["RNTMinimapBtn"]
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
