--[[============================================================================
  ReadyUp - Glue module pour TibiSuite
  ---------------------------------------------------------------------------
  MODE MODULE (core present) : inscrit l'onglet « ReadyUp » (accent vert)
  dans la barre unifiee ; pas de bouton minimap propre.
  MODE AUTONOME (core absent) : construit son propre bouton minimap.
  Dans les deux cas : slash /readyup et /rdy. TibiReadyUpDB ne change jamais
  entre les deux modes. Charge en dernier par ReadyUp.toc.
  NON TESTE EN JEU (2026-11-14).
============================================================================]]

local ADDON, RU = ...
local T = RU.T
local KEY = RU.KEY

local function HasCore()
  return _G.TibiSuite and _G.TibiSuite.RegisterModule and true or false
end

-- Meme regle que Standby et Anchor : coche dans TibiSuite, ou table absente.
local function IsEnabledByCore()
  if not (TibiSuiteDB and type(TibiSuiteDB.enabledModules) == "table") then return true end
  return TibiSuiteDB.enabledModules[KEY] and true or false
end

-- ============================================================================
-- MODE AUTONOME : bouton minimap (socle v23, comme Anchor)
-- ============================================================================
local function BuildStandaloneMinimapButton()
  if _G.TibiReadyUpMinimapBtn then return end
  local UIm = _G.TibiMidnight
  if not (UIm and UIm.MinimapButton) then return end
  UIm.MinimapButton({
    name = "TibiReadyUpMinimapBtn", style = "compact", default = 215,
    icon = RU.LOGO,
    getAngle = function() return TibiReadyUpDB and tonumber(TibiReadyUpDB.minimapAngle) end,
    setAngle = function(a) if TibiReadyUpDB then TibiReadyUpDB.minimapAngle = a end end,
    onClick = function(button)
      if button == "RightButton" then TibiReadyUp_OpenOptions() else TibiReadyUp_Toggle() end
    end,
    tooltip = function(tt)
      tt:AddLine("ReadyUp")
      local st = RU.Status and RU.Status()
      if st and st.text then tt:AddLine(st.text, st.color[1], st.color[2], st.color[3]) end
      tt:AddLine(T("MM_TT_LEFT", "Clic gauche : ouvrir / fermer"), 0.9, 0.9, 0.95)
      tt:AddLine(T("MM_TT_RIGHT", "Clic droit : options"), 0.9, 0.9, 0.95)
    end,
  })
end

if HasCore() and IsEnabledByCore() then
  TibiSuite.RegisterModule({
    key            = KEY,
    label          = "ReadyUp",
    accent         = RU.ACCENT,
    onOpen         = function() TibiReadyUp_Toggle() end,
    onOptions      = function() TibiReadyUp_OpenOptions() end,
    searchProvider = RU.SearchProvider,   -- Bridge.lua
    statusFn       = function() if RU.Status then return RU.Status() end end,
    overviewFn     = function() if RU.Overview then return RU.Overview() end end,
  })
elseif not HasCore() then
  local f = CreateFrame("Frame")
  pcall(f.RegisterEvent, f, "PLAYER_LOGIN")
  f:SetScript("OnEvent", function(self) self:UnregisterAllEvents(); BuildStandaloneMinimapButton() end)
end

-- ============================================================================
-- SLASH : /readyup [check | test | on | off | options | help]
-- ============================================================================
SLASH_TIBIREADYUP1 = "/readyup"
SLASH_TIBIREADYUP2 = "/rdy"
SlashCmdList["TIBIREADYUP"] = function(msg)
  local cmd = ((msg or ""):match("^%s*(%S*)") or ""):lower()
  if not TibiReadyUpDB then return end
  if cmd == "" then TibiReadyUp_Toggle()
  elseif cmd == "check" or cmd == "verifier" then
    local ev = RU.Evaluate("manual")
    if not ev then RU.Print(T("IN_COMBAT", "En combat : vérification après le combat.")); return end
    RU.ShowToast(ev, true)
  elseif cmd == "on" then TibiReadyUpDB.enabled = true; RU.Print(T("MSG_ON", "activé")); RU.OnChanged()
  elseif cmd == "off" then TibiReadyUpDB.enabled = false; RU.Print(T("MSG_OFF", "désactivé")); RU.OnChanged()
  elseif cmd == "options" or cmd == "config" then TibiReadyUp_OpenOptions()
  else
    RU.Print(T("HELP", "commandes : /readyup (fenêtre), check (vérifier maintenant), on, off, options"))
  end
end
