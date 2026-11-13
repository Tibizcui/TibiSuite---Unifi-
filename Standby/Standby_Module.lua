--[[============================================================================
  Standby - Glue module pour TibiSuite
  ---------------------------------------------------------------------------
  MODE MODULE (core present) : inscrit l'onglet "Standby" (accent rose aube)
  dans la barre unifiee ; pas de bouton minimap propre.
  MODE STANDALONE (core absent) : construit son propre bouton minimap.
  Dans les deux cas : slash /standby et /afkscreen. StandbyDB ne change
  jamais entre les deux modes.
  Charge en dernier par Standby.toc.
============================================================================]]

local ADDON, SB = ...
local T = SB.T
local KEY = SB.KEY

local function HasCore()
  return _G.TibiSuite and _G.TibiSuite.RegisterModule and true or false
end

if not HasCore() then
  C_Timer.After(45, function()
    print("|cFFC41F3BTibiSuite|r : plus d'infos sur |cFFFFD700https://www.tibiscui.fr|r")
    print("|cFFC41F3BTibiSuite|r : télécharge Tibi-Companion sur |cFFFFD700https://tibiscui.fr/tibi-companion.html|r")
  end)
end

-- Decision validee : pas de migration ponctuelle (decoche pour les joueurs
-- existants). enabledModules == nil = suite jamais configuree = tout actif.
local function IsEnabledByCore()
  if not (TibiSuiteDB and type(TibiSuiteDB.enabledModules) == "table") then return true end
  return TibiSuiteDB.enabledModules[KEY] and true or false
end

-- ============================================================================
-- MODE STANDALONE : bouton minimap (meme construction qu'Opacity)
-- ============================================================================
local function BuildStandaloneMinimapButton()
  if _G.StandbyMinimapBtn then return end
  -- Construit par le socle v23 (UI.MinimapButton, audit poids 2026-11-13,
  -- lot 5) : position, glisser (OnUpdate pose seulement pendant le
  -- deplacement) et collecteurs MiniHub / EllesmereUI geres au meme endroit.
  local UIm = _G.TibiMidnight
  if not (UIm and UIm.MinimapButton) then return end
  local btn = UIm.MinimapButton({
    name = "StandbyMinimapBtn", style = "compact", default = 200,
    icon = SB.LOGO,
    getAngle = function() return StandbyDB and tonumber(StandbyDB.minimapAngle) end,
    setAngle = function(a) if StandbyDB then StandbyDB.minimapAngle = a end end,
    onClick = function(button)
      if button == "RightButton" then SB.Preview() else Standby_Toggle() end
    end,
    tooltip = function(tt)
      tt:AddLine("Standby")
      tt:AddLine(T("MM_TT_LEFT", "Clic gauche : options"), 0.9, 0.9, 0.95)
      tt:AddLine(T("MM_TT_RIGHT", "Clic droit : aperçu de l'écran"), 0.9, 0.9, 0.95)
    end,
  })
end

if HasCore() and IsEnabledByCore() then
  TibiSuite.RegisterModule({
    key            = KEY,
    label          = "Standby",
    accent         = SB.ACCENT,
    onOpen         = function() Standby_Toggle() end,
    onOptions      = function() Standby_OpenOptions() end,
    searchProvider = SB.SearchProvider,   -- Bridge.lua
    overviewFn     = function() if SB.Overview then return SB.Overview() end end,
  })
elseif not HasCore() then
  local f = CreateFrame("Frame")
  pcall(f.RegisterEvent, f, "PLAYER_LOGIN")
  f:SetScript("OnEvent", function(self) self:UnregisterAllEvents(); BuildStandaloneMinimapButton() end)
end

-- ============================================================================
-- SLASH : /standby [test | options | status | on | off | probe | help]
-- ============================================================================
SLASH_TIBISTANDBY1 = "/standby"
SLASH_TIBISTANDBY2 = "/afkscreen"
SlashCmdList["TIBISTANDBY"] = function(msg)
  local cmd = ((msg or ""):match("^%s*(%S*)") or ""):lower()
  if cmd == "" or cmd == "options" or cmd == "config" then Standby_Toggle()
  elseif cmd == "test" or cmd == "apercu" or cmd == "preview" then SB.Preview()
  elseif cmd == "on" then SB.SetEnabled(true); SB.Print(T("ST_ON", "actif"))
  elseif cmd == "off" then SB.SetEnabled(false); SB.Print(T("ST_OFF", "désactivé"))
  elseif cmd == "probe" or cmd == "sonde" then SB.RunProbe()
  elseif cmd == "status" or cmd == "etat" then SB.PrintStatus()
  else
    SB.Print(T("HELP", "commandes : /standby (options), test (aperçu 15 s), status (pourquoi l'écran s'affiche ou non), on, off, probe (vérification en jeu)"))
  end
end
