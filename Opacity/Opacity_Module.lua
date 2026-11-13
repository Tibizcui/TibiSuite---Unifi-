--[[============================================================================
  Opacity - Glue module pour TibiSuite
  ---------------------------------------------------------------------------
  MODE MODULE (core present) : inscrit l'onglet "Opacity" (accent bleu glacier)
  dans la barre unifiee ; pas de bouton minimap propre.
  MODE STANDALONE (core absent) : construit son propre bouton minimap.
  Dans les deux cas : slash /opacity et /opa. OpacityDB ne change jamais
  entre les deux modes.
  Charge en dernier par Opacity.toc.
============================================================================]]

local ADDON, OP = ...
local T = OP.T
local KEY = "Opacity"

local function HasCore()
  return _G.TibiSuite and _G.TibiSuite.RegisterModule and true or false
end

if not HasCore() then
  C_Timer.After(45, function()
    print("|cFFC41F3BTibiSuite|r : plus d'infos sur |cFFFFD700https://www.tibiscui.fr|r")
    print("|cFFC41F3BTibiSuite|r : télécharge Tibi-Companion sur |cFFFFD700https://tibiscui.fr/tibi-companion.html|r")
  end)
end

-- Meme regle que OP.SuiteDisabled (Core.lua), vue depuis l'inscription :
-- au tout premier login apres l'ajout du module, la cle n'existe pas encore
-- (la migration du core la pose sur PLAYER_LOGIN, apres ce fichier) ; on
-- s'inscrit quand meme pour que l'onglet soit la des la premiere session.
local function IsEnabledByCore()
  if not (TibiSuiteDB and type(TibiSuiteDB.enabledModules) == "table") then return true end
  if TibiSuiteDB.enabledModules[KEY] then return true end
  return not TibiSuiteDB.opacityEnableMigrated
end

-- ============================================================================
-- MODE STANDALONE : bouton minimap (meme construction que RepBar)
-- ============================================================================
local function BuildStandaloneMinimapButton()
  if _G.OpacityMinimapBtn then return end
  -- Construit par le socle v23 (UI.MinimapButton, audit poids 2026-11-13,
  -- lot 5) : position, glisser (OnUpdate pose seulement pendant le
  -- deplacement) et collecteurs MiniHub / EllesmereUI geres au meme endroit.
  local UIm = _G.TibiMidnight
  if not (UIm and UIm.MinimapButton) then return end
  local btn = UIm.MinimapButton({
    name = "OpacityMinimapBtn", style = "compact", default = 200,
    icon = OP.LOGO,
    getAngle = function() return OpacityDB and tonumber(OpacityDB.minimapAngle) end,
    setAngle = function(a) if OpacityDB then OpacityDB.minimapAngle = a end end,
    onClick = function(button)
      if button == "RightButton" then Opacity_OpenOptions() else Opacity_Toggle() end
    end,
    tooltip = function(tt)
      tt:AddLine("Opacity")
      tt:AddLine(T("MM_TT_LEFT", "Clic gauche : ouvrir / fermer"), 0.9, 0.9, 0.95)
      tt:AddLine(T("MM_TT_RIGHT", "Clic droit : options"), 0.9, 0.9, 0.95)
    end,
  })
  -- Choix « masquer l'icone » (OpacityDB.minimapHidden), pose AVANT que les
  -- collecteurs ne scannent la minicarte.
  if btn and OpacityDB and OpacityDB.minimapHidden then OP.ApplyMinimapHidden() end
end

-- Masquage de l'icone propre (mode autonome).
-- UNIQUEMENT Hide() / Show() : jamais de SetParent ni de SetPoint, pour que le
-- bouton reste la ou un collecteur l'a range (grille EllesmereUIMinimap,
-- conteneur MiniHub) ou a sa place sur la minicarte (seul, ElvUI). Ces
-- collecteurs suivent Hide/Show et retirent ou remettent le bouton d'eux-memes.
-- Cas particulier : EllesmereUIMinimap re-affiche un bouton cache pendant que
-- sa grille est ouverte. On retente alors toutes les 0,5 s jusqu'a ce que le
-- masquage tienne (grille refermee), puis on s'arrete.
local hideRetry
function OP.ApplyMinimapHidden()
  local btn = _G.OpacityMinimapBtn
  if not btn then return end
  if hideRetry then hideRetry:Cancel(); hideRetry = nil end
  if OpacityDB and OpacityDB.minimapHidden then
    btn:Hide()
    if btn:IsShown() then
      hideRetry = C_Timer.NewTicker(0.5, function()
        if not (OpacityDB and OpacityDB.minimapHidden) then
          hideRetry:Cancel(); hideRetry = nil; return
        end
        btn:Hide()
        if not btn:IsShown() then hideRetry:Cancel(); hideRetry = nil end
      end)
    end
  else
    btn:Show()
  end
end

-- En mode suite, le bouton n'est jamais construit : on enregistre seulement
-- le choix, qui s'appliquera si Opacity tourne un jour sans le core.
function OP.SetMinimapHidden(hidden)
  if not OpacityDB then return end
  OpacityDB.minimapHidden = hidden and true or false
  OP.ApplyMinimapHidden()
end

if HasCore() and IsEnabledByCore() then
  TibiSuite.RegisterModule({
    key            = KEY,
    label          = "Opacity",
    accent         = OP.ACCENT,
    onOpen         = function() Opacity_Toggle() end,
    onOptions      = function() Opacity_OpenOptions() end,
    searchProvider = OP.SearchProvider,   -- Bridge.lua
    overviewFn     = function() if OP.Overview then return OP.Overview() end end,
  })
elseif not HasCore() then
  -- Le bouton lit OpacityDB : on attend le login (SavedVariables chargees).
  local f = CreateFrame("Frame")
  pcall(f.RegisterEvent, f, "PLAYER_LOGIN")
  f:SetScript("OnEvent", function(self) self:UnregisterAllEvents(); BuildStandaloneMinimapButton() end)
end

-- ============================================================================
-- SLASH : /opacity [pick | tune | shot | on | off | options | reset | probe | profile <nom> | help]
-- ============================================================================
SLASH_TIBIOPACITY1 = "/opacity"
SLASH_TIBIOPACITY2 = "/opa"
SlashCmdList["TIBIOPACITY"] = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = (cmd or ""):lower()
  if cmd == "" then Opacity_Toggle()
  elseif cmd == "pick" or cmd == "pipette" then OP.StartPicker()
  elseif cmd == "tune" or cmd == "reglage" or cmd == "molette" then OP.StartTuner()
  elseif cmd == "probe" or cmd == "sonde" then OP.RunProbe()
  elseif cmd == "profile" or cmd == "profil" then
    if rest ~= "" and OpacityDB.profiles[rest] then OP.SwitchProfile(rest)
    else OP.Print(T("MSG_PROF_LIST", "profils : ") .. table.concat(OP.ProfileNames(), ", ")) end
  elseif cmd == "shot" or cmd == "capture" then Opacity_ToggleScreenshot()
  elseif cmd == "on" then OP.SetEnabled(true); OP.Print(T("FLASH_ON", "activé"))
  elseif cmd == "off" then OP.SetEnabled(false); OP.Print(T("FLASH_OFF", "suspendu (fenêtres rendues à leur opacité d'origine)"))
  elseif cmd == "options" or cmd == "config" then Opacity_OpenOptions()
  elseif cmd == "reset" then OP.ResetProfile()
  else
    OP.Print(T("HELP", "commandes : /opacity (fenêtre), pick (pipette), tune (réglage direct à la molette), shot (capture d'écran), "
      .. "profile <nom>, on, off, options, reset, probe (vérification)"))
  end
end
