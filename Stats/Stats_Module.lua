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
    -- Apercu du Centre (7.1.5.45) : la semaine du perso connecte.
    overviewFn = function()
      local SL, TS = _G.TibiSuiteL or {}, _G.TibiSuite
      local out = { lines = {}, empty = SL.OV_STATS_EMPTY }
      if not (SX.Aggregate and SX.WeeklyGoldRange and SX.CurrentCharKey and TS) then return out end
      local key = SX.CurrentCharKey()
      if not key or not StatsDB or not StatsDB[key] then return out end
      local from, to = SX.WeeklyGoldRange()
      local ok, agg = pcall(SX.Aggregate, key, from, to)
      if not ok or type(agg) ~= "table" then return out end
      local net = (agg.goldGain or 0) - (agg.goldSpent or 0)
      local lines = out.lines
      lines[#lines + 1] = { text = SL.OV_STATS_GOLD, value = TS.FmtGold and TS.FmtGold(net) or tostring(net),
        color = net >= 0 and { 1, 0.843, 0 } or { 0.85, 0.45, 0.45 } }
      if (agg.quests or 0) > 0 then lines[#lines + 1] = { text = SL.OV_STATS_QUESTS, value = tostring(agg.quests) } end
      local dg = (agg.dungeons or 0) + (agg.mplusCount or 0)
      if dg > 0 then lines[#lines + 1] = { text = SL.OV_STATS_DUNGEONS, value = tostring(dg) } end
      if (agg.delves or 0) > 0 then lines[#lines + 1] = { text = SL.OV_STATS_DELVES, value = tostring(agg.delves) } end
      local near = SX.NearAchievements and SX.NearAchievements()
      if near and near[1] and #lines < 5 then
        lines[#lines + 1] = { text = near[1].name, value = math.floor(near[1].pct * 100) .. " %", progress = near[1].pct,
          color = { 1, 0.843, 0 } }
      end
      if (agg.played or 0) > 0 and TS.FmtDuration and #lines < 5 then
        lines[#lines + 1] = { text = SL.OV_STATS_PLAYED, value = TS.FmtDuration(agg.played) }
      end
      return out
    end,
  })
end

-- Or net de la semaine (cuivre), tout le compte : lu par les objectifs
-- personnels de TibiSuite (Ma semaine, 7.1.5.45).
function Stats_WeeklyNet()
  if not (SX.WeeklyGoldRange and SX.AggregateAccount) then return nil end
  local from, to = SX.WeeklyGoldRange()
  local ok, agg = pcall(SX.AggregateAccount, from, to)
  if not ok or type(agg) ~= "table" then return nil end
  return (agg.goldGain or 0) - (agg.goldSpent or 0)
end

-- Stats n'a pas de bouton minimap propre pour l'instant (fenetre ouverte
-- depuis la barre TibiSuite ou /ts stats) ; HideOwnMinimap reste un
-- garde-fou si un futur bouton minimap standalone est ajoute.
C_Timer.After(0.2, HideOwnMinimap)
C_Timer.After(1.0, HideOwnMinimap)
C_Timer.After(3.0, HideOwnMinimap)

SLASH_TIBISTATS1 = "/stats"
SlashCmdList["TIBISTATS"] = function() SX.Toggle() end
