--[[============================================================================
  Anchor - Glue module pour TibiSuite
  ---------------------------------------------------------------------------
  MODE MODULE (core present) : inscrit l'onglet « Anchor » (accent indigo)
  dans la barre unifiee ; pas de bouton minimap propre.
  MODE AUTONOME (core absent) : construit son propre bouton minimap.
  Dans les deux cas : slash /anchor et /anc. TibiAnchorDB ne change jamais entre
  les deux modes. Charge en dernier par Anchor.toc.
============================================================================]]

local ADDON, AN = ...
local T = AN.T
local KEY = AN.KEY

local function HasCore()
  return _G.TibiSuite and _G.TibiSuite.RegisterModule and true or false
end

-- Meme regle que Standby : coche dans TibiSuite, ou table absente.
local function IsEnabledByCore()
  if not (TibiSuiteDB and type(TibiSuiteDB.enabledModules) == "table") then return true end
  return TibiSuiteDB.enabledModules[KEY] and true or false
end

-- ============================================================================
-- MODE AUTONOME : bouton minimap (meme construction qu'Opacity)
-- ============================================================================
local function BuildStandaloneMinimapButton()
  if _G.TibiAnchorMinimapBtn then return end
  -- Construit par le socle v23 (UI.MinimapButton, audit poids 2026-11-13,
  -- lot 5) : position, glisser (OnUpdate pose seulement pendant le
  -- deplacement) et collecteurs MiniHub / EllesmereUI geres au meme endroit.
  local UIm = _G.TibiMidnight
  if not (UIm and UIm.MinimapButton) then return end
  local btn = UIm.MinimapButton({
    name = "TibiAnchorMinimapBtn", style = "compact", default = 200,
    icon = AN.LOGO,
    getAngle = function() return TibiAnchorDB and tonumber(TibiAnchorDB.minimapAngle) end,
    setAngle = function(a) if TibiAnchorDB then TibiAnchorDB.minimapAngle = a end end,
    onClick = function(button)
      if button == "RightButton" then TibiAnchor_OpenOptions() else TibiAnchor_Toggle() end
    end,
    tooltip = function(tt)
      tt:AddLine("Anchor")
      tt:AddLine(T("MM_TT_LEFT", "Clic gauche : ouvrir / fermer"), 0.9, 0.9, 0.95)
      tt:AddLine(T("MM_TT_RIGHT", "Clic droit : options"), 0.9, 0.9, 0.95)
    end,
  })
end

if HasCore() and IsEnabledByCore() then
  TibiSuite.RegisterModule({
    key            = KEY,
    label          = "Anchor",
    accent         = AN.ACCENT,
    onOpen         = function() TibiAnchor_Toggle() end,
    onOptions      = function() TibiAnchor_OpenOptions() end,
    searchProvider = AN.SearchProvider,   -- Bridge.lua
    overviewFn     = function() if AN.Overview then return AN.Overview() end end,
  })
elseif not HasCore() then
  local f = CreateFrame("Frame")
  pcall(f.RegisterEvent, f, "PLAYER_LOGIN")
  f:SetScript("OnEvent", function(self) self:UnregisterAllEvents(); BuildStandaloneMinimapButton() end)
end

-- ============================================================================
-- SLASH : /anchor [loot | undo | reset | probe | on | off | options | help]
-- ============================================================================
SLASH_TIBIANCHOR1 = "/anchor"
SLASH_TIBIANCHOR2 = "/anc"
SlashCmdList["TIBIANCHOR"] = function(msg)
  local cmd = ((msg or ""):match("^%s*(%S*)") or ""):lower()
  if not TibiAnchorDB then return end
  if cmd == "" then TibiAnchor_Toggle()
  elseif cmd == "loot" or cmd == "butin" then AN.Loot.Toggle()
  elseif cmd == "undo" or cmd == "annuler" then AN.Undo()
  elseif cmd == "reset" then AN.ResetAll()
  elseif cmd == "probe" or cmd == "sonde" then AN.RunProbe()
  elseif cmd == "on" then AN.SetEnabled(true); AN.Print(T("FLASH_ON", "activé"))
  elseif cmd == "off" then
    AN.SetEnabled(false)
    AN.Print(T("FLASH_OFF", "suspendu (fenêtres rendues à leur place d'origine)"))
  elseif cmd == "options" or cmd == "config" then TibiAnchor_OpenOptions()
  else
    AN.Print(T("HELP", "commandes : /anchor (fenêtre), loot (placer le butin), undo (annuler), reset (tout remettre), "
      .. "probe (vérification), on, off, options"))
  end
  AN.OnChanged()
end
