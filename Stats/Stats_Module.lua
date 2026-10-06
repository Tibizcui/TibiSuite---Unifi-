--[[============================================================================
  Stats - Glue module pour TibiSuite
  ---------------------------------------------------------------------------
  Inscrit Stats comme onglet de la suite unifiee (vignette "Stats", accent
  or) et masque le bouton minimap individuel quand le core est present. Ne
  touche jamais a StatsDB ni aux crochets d'evenements (Core.lua) : Stats
  fonctionne a l'identique, installe seul ou dans la suite.
============================================================================]]

local ADDON, SX = ...
local ACCENT = SX.ACCENT
local KEY = "Stats"

local function HasCore()
  return _G.TibiSuite and _G.TibiSuite.RegisterModule and true or false
end

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

local function HideOwnMinimap()
  if not HasCore() then return end
  local btn = _G["StatsMinimapBtn"]
  if btn and btn.Hide then
    btn:Hide()
    if not btn.__tibiHooked then
      btn.__tibiHooked = true
      btn:HookScript("OnShow", function(self) C_Timer.After(0, function() self:Hide() end) end)
    end
  end
end

if HasCore() and IsEnabledByCore() then
  TibiSuite.RegisterModule({
    key       = KEY,
    label     = "Stats",
    accent    = ACCENT,
    onOpen    = function() SX.Toggle() end,
    onOptions = function() if SX.OpenOptions then SX.OpenOptions() end end,
    -- Ligne d'etat du Panneau vivant : or net du perso depuis le reset
    -- hebdomadaire (meme fenetre que la carte « Or (semaine) »).
    statusFn  = function()
      if not (SX.Aggregate and SX.WeeklyGoldRange and SX.CurrentCharKey) then return nil end
      local key = SX.CurrentCharKey()
      if not key or not StatsDB or not StatsDB[key] then return nil end
      local from, to = SX.WeeklyGoldRange()
      local agg = SX.Aggregate(key, from, to)
      local net = (agg.goldGain or 0) - (agg.goldSpent or 0)
      local SL, TS = _G.TibiSuiteL or {}, _G.TibiSuite
      if not (TS and TS.FmtGold) then return nil end
      return { text = string.format(SL.ST_GOLD_FMT or "%s", TS.FmtGold(net)),
               color = net >= 0 and { 1, 0.843, 0 } or { 0.85, 0.45, 0.45 } }
    end,
  })
end

-- Stats n'a pas de bouton minimap propre pour l'instant (fenetre ouverte
-- depuis la barre TibiSuite ou /ts stats) ; HideOwnMinimap reste un
-- garde-fou si un futur bouton minimap standalone est ajoute.
C_Timer.After(0.2, HideOwnMinimap)
C_Timer.After(1.0, HideOwnMinimap)
C_Timer.After(3.0, HideOwnMinimap)

SLASH_TIBISTATS1 = "/stats"
SlashCmdList["TIBISTATS"] = function() SX.Toggle() end
