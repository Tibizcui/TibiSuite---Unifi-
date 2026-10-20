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
    -- Conseiller de TibiSuite (lot 2) : hauts faits a proposer.
    suggestFn = function()
      if SX.AdvisorSuggestions then return SX.AdvisorSuggestions() end
      return nil
    end,
  })
end

-- Habitudes du joueur pour le Conseiller de TibiSuite : activite du compte
-- sur les `days` derniers jours, ramenee a 0..1 par type de contenu (1 =
-- joueur regulier de ce contenu, seuils AFF_REF). Les tags sans donnee
-- (mascottes, collections, evenements, reputation) restent absents : le
-- core les traite comme neutres.
local AFF_REF = { quest = 150, explore = 150, world = 40, dungeon = 15, raid = 6, delve = 15, pvp = 15, prof = 40 }
function Stats_Affinity(days)
  days = days or 28
  if not SX.AggregateAccount then return nil end
  local to = time()
  local ok, a = pcall(SX.AggregateAccount, to - days * 86400, to)
  if not ok or type(a) ~= "table" then return nil end
  local counts = {
    quest = a.quests or 0, explore = a.quests or 0, world = a.worldQuests or 0,
    dungeon = (a.dungeons or 0) + (a.mplusCount or 0), raid = a.raids or 0, delve = a.delves or 0,
    pvp = (a.bgPlayedGained or 0) + (a.arenaPlayedGained or 0), prof = a.profGained or 0,
  }
  local aff = {}
  for k, ref in pairs(AFF_REF) do aff[k] = math.min(1, (counts[k] or 0) / ref) end
  return { aff = aff, counts = counts, days = days }
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

-- Or gagne par source sur [from, to] (cuivre), tout le compte : page
-- Patrimoine de TibiSuite (7.3). vendor / ah / other = journal des gains
-- (d.goldLog) ; gain / spent = totaux du jour (d.goldGain / d.goldSpent).
function Stats_GoldSources(from, to)
  if not SX.AggregateAccount then return nil end
  local ok, agg = pcall(SX.AggregateAccount, from, to)
  if not ok or type(agg) ~= "table" then return nil end
  local out = { vendor = 0, ah = 0, other = 0, gain = agg.goldGain or 0, spent = agg.goldSpent or 0 }
  for _, e in ipairs(agg.goldLog or {}) do
    local src = out[e.source] and e.source or "other"
    if (e.ts or 0) >= from and (e.ts or 0) <= to then out[src] = out[src] + (tonumber(e.amount) or 0) end
  end
  return out
end

-- Compteurs du compte sur [from, to] : bilan de fin de semaine de TibiSuite
-- (7.3). Valeurs simples (nombres), or en cuivre, temps en secondes.
function Stats_Summary(from, to)
  if not SX.AggregateAccount then return nil end
  local ok, a = pcall(SX.AggregateAccount, from, to)
  if not ok or type(a) ~= "table" then return nil end
  return {
    played = a.played or 0, quests = a.quests or 0, worldQuests = a.worldQuests or 0,
    dungeons = (a.dungeons or 0) + (a.mplusCount or 0), mplus = a.mplusCount or 0,
    raids = a.raids or 0, delves = a.delves or 0, gold = (a.goldGain or 0) - (a.goldSpent or 0),
    rep = a.repGained or 0, prof = a.profGained or 0, pvp = a.pvpKillsGained or 0,
    ach = a.achPoints or 0, sessions = a.sessions or 0,
  }
end

-- Stats n'a pas de bouton minimap propre pour l'instant (fenetre ouverte
-- depuis la barre TibiSuite ou /ts stats) ; HideOwnMinimap reste un
-- garde-fou si un futur bouton minimap standalone est ajoute.
C_Timer.After(0.2, HideOwnMinimap)
C_Timer.After(1.0, HideOwnMinimap)
C_Timer.After(3.0, HideOwnMinimap)

SLASH_TIBISTATS1 = "/stats"
SlashCmdList["TIBISTATS"] = function(msg)
  local rest = (msg or ""):lower():match("^%s*probe%s+adv%s*(.-)%s*$")
  if rest and SX.ProbeAdv then SX.ProbeAdv(rest); return end
  SX.Toggle()
end
