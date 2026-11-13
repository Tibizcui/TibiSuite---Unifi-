--[[============================================================================
  RepBar - Glue module pour TibiSuite
  ---------------------------------------------------------------------------
  Ce fichier NE TOUCHE PAS a RepBarDB ni au code de la barre. Il se contente
  d'inscrire RepBar dans la suite :
    - RegisterModule : ajoute l'onglet "RepBar" (accent azur) a la barre
      unifiee. RepBar n'a pas de recherche propre (RenTracker fournit deja la
      recherche de factions), donc searchProvider reste nil.
    - rattrapage cosmetique : rebranche le bouton texte "Options" sur la barre, car le
      handler PLAYER_LOGIN de RepBar.lua ne se declenche plus en LoadOnDemand.
  RepBar n'a pas de bouton minimap propre : rien a masquer de ce cote.
  Charge en dernier par RepBar.toc, apres RepBar.lua.
============================================================================]]

local KEY    = "RepBar"
local LABEL  = "RepBar"
local ACCENT = { 0.36, 0.68, 0.96 }   -- azur d'identite RepBar
local FRAME  = "RepBarContainer"
local L      = RepBarL or {}
local function T(key, default) return L[key] or default end

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

-- Rattrapage cosmetique : habille la barre au style socle (bouton texte
-- "Options"). Le handler PLAYER_LOGIN d'origine ne tourne plus en LoadOnDemand.
local function Decorate()
  -- Version de RepBar.lua (idempotente) si disponible, sinon repli local.
  if _G.RepBar_Decorate then _G.RepBar_Decorate() ; return end
  local ui = GetUI() ; local f = _G[FRAME]
  if not (ui and f) then return end
  if f._tibiControls then return end
  if ui.AddHeaderControls then
    ui.AddHeaderControls(f, {
      accent = ACCENT,
      onOptions = function() if _G.RepBar_OpenOptions then _G.RepBar_OpenOptions() end end,
    })
  end
end

-- ============================================================================
-- MODE STANDALONE : RepBar n'a pas de bouton minimap propre (barre permanente,
-- pas de fenetre a ouvrir/fermer). On en construit un ici, uniquement quand
-- le core est absent.
-- ============================================================================
local function BuildStandaloneMinimapButton()
  if _G.RepBarMinimapBtn then return end
  -- Construit par le socle v23 (UI.MinimapButton, audit poids 2026-11-13,
  -- lot 5) : position, glisser (OnUpdate pose seulement pendant le
  -- deplacement) et collecteurs MiniHub / EllesmereUI geres au meme endroit.
  local UIm = _G.TibiMidnight
  if not (UIm and UIm.MinimapButton) then return end
  local btn = UIm.MinimapButton({
    name = "RepBarMinimapBtn", style = "compact", default = 225,
    icon = "Interface\\AddOns\\RepBar\\medias\\Logo",
    getAngle = function() if not (RepBarDB and RepBarDB.minimapMoved) then return 225 end return RepBarDB.minimapAngle end,
    setAngle = function(a) RepBarDB = RepBarDB or {}; RepBarDB.minimapAngle = a; RepBarDB.minimapMoved = true end,
    onClick = function(button)
      if button == "RightButton" then
        if _G.RepBar_OpenOptions then _G.RepBar_OpenOptions() end
      elseif _G.RepBar_Toggle then
        _G.RepBar_Toggle()
      end
    end,
    tooltip = function(tt)
      tt:AddLine("RepBar")
      tt:AddLine(T("MM_TT_LEFT", "Clic gauche : afficher/masquer"), 0.9, 0.9, 0.95)
      tt:AddLine(T("MM_TT_RIGHT", "Clic droit : options"), 0.9, 0.9, 0.95)
    end,
  })
  return btn
end

-- MODE MODULE : inscription au catalogue, sauf si explicitement desactive.
-- Pas de searchProvider (RenTracker fournit deja la recherche de factions).
-- MODE STANDALONE : construit son propre bouton minimap.
if HasCore() and IsEnabledByCore() then
  TibiSuite.RegisterModule({
    key            = KEY,
    label          = LABEL,
    accent         = ACCENT,
    onOpen         = function() if _G.RepBar_Toggle then _G.RepBar_Toggle() end end,
    onOptions      = function() if _G.RepBar_OpenOptions then _G.RepBar_OpenOptions() end end,
    searchProvider = nil,
    -- Apercu du Centre (7.1.5.45) : la faction suivie par le jeu.
    overviewFn     = function()
      local SL = _G.TibiSuiteL or {}
      local out = { lines = {}, empty = SL.OV_RB_NONE }
      if not (C_Reputation and C_Reputation.GetWatchedFactionData) then return out end
      local ok, d = pcall(C_Reputation.GetWatchedFactionData)
      if not ok or not d or not d.name or (d.factionID or 0) == 0 then return out end
      local lo, hi, cur = d.currentReactionThreshold or 0, d.nextReactionThreshold or 0, d.currentStanding or 0
      local pct = (hi > lo) and math.max(0, math.min(1, (cur - lo) / (hi - lo))) or nil
      out.lines[1] = { text = SL.OV_RB_WATCH, value = d.name }
      if pct then out.lines[2] = { text = d.name, value = math.floor(pct * 100) .. " %", progress = pct } end
      return out
    end,
  })
elseif not HasCore() then
  -- Construit a la connexion : a la lecture de ce fichier, RepBarDB n'est pas
  -- encore chargee (la position deplacee n'etait jamais restauree).
  if IsLoggedIn and IsLoggedIn() then
    BuildStandaloneMinimapButton()
  else
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function(self) self:UnregisterAllEvents(); BuildStandaloneMinimapButton() end)
  end
end

-- La barre RepBarContainer est construite par RepBar.lua sur son ADDON_LOADED,
-- qui se declenche juste avant le chargement de ce fichier. On habille en
-- differe, avec quelques tentatives de secours.
C_Timer.After(0.2, Decorate)
C_Timer.After(1.0, Decorate)
C_Timer.After(3.0, Decorate)
