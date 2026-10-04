--[[============================================================================
  Standby - Tiles.lua
  ---------------------------------------------------------------------------
  Les tuiles de la mise en page Vitrine. Chaque tuile renvoie nil quand elle
  n'a rien d'utile a dire (niveau max pour le repos, pas de cle, pas de
  courrier...), et l'ecran la saute.

  Sources : APIs Blizzard directes (marchent sans la suite), enrichies quand
  un module est charge : XPBarAPI (XP/h), SkillTrackerAPI (concentration
  projetee). Lecture seule, jamais d'ecriture dans les bases des modules.
  L'etiquette « source » affiche le module qui fournit l'info, sinon rien.

  NON TESTE EN JEU : formats de C_WeeklyRewards (repris de WeeklyCompass,
  verifies en 12.1), C_MythicPlus / C_Reputation sous pcall.
============================================================================]]

local ADDON, SB = ...
local T = SB.T

local Tiles = {}
SB.Tiles = Tiles

local function Loaded(name)
  return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name) and true or false
end

local function Safe(fn, ...)
  local ok, a, b, c, d = pcall(fn, ...)
  if ok then return a, b, c, d end
  return nil
end

local Dur = function(s) return SB.FormatDuration(s) end

-- ----------------------------------------------------------------------------
-- Grande chambre forte
-- ----------------------------------------------------------------------------
local function Vault()
  if not (C_WeeklyRewards and C_WeeklyRewards.GetActivities) then return nil end
  local acts = Safe(C_WeeklyRewards.GetActivities)
  if type(acts) ~= "table" or #acts == 0 then return nil end
  local E = Enum and Enum.WeeklyRewardChestThresholdType
  local rows = {}
  if E then
    rows = {
      { type = E.Activities, label = T("VAULT_DUNGEONS", "Donjons") },
      { type = E.Raid,       label = T("VAULT_RAID", "Raid") },
      { type = E.World,      label = T("VAULT_WORLD", "Monde") },
    }
  end
  local parts, unlocked, total = {}, 0, 0
  for _, row in ipairs(rows) do
    local prog, maxT = 0, 0
    for _, a in ipairs(acts) do
      if a.type == row.type then
        total = total + 1
        prog = math.max(prog, a.progress or 0)
        maxT = math.max(maxT, a.threshold or 0)
        if (a.progress or 0) >= (a.threshold or 1) then unlocked = unlocked + 1 end
      end
    end
    if maxT > 0 then parts[#parts + 1] = string.format("%s %d/%d", row.label, math.min(prog, maxT), maxT) end
  end
  if #parts == 0 then return nil end
  local value = table.concat(parts, "  ·  ")
  local claim = C_WeeklyRewards.HasAvailableRewards and Safe(C_WeeklyRewards.HasAvailableRewards)
  if claim then value = "|cFF66D98A" .. T("VAULT_CLAIM", "Récompense à récupérer") .. "|r  ·  " .. value end
  return {
    label = T("TILE_VAULT", "Grande chambre forte"),
    src = Loaded("WeeklyCompass") and "WeeklyCompass" or nil,
    value = value, frac = total > 0 and unlocked / total or nil, color = { 0.039, 1.0, 0.745 },
  }
end

-- ----------------------------------------------------------------------------
-- Experience et repos
-- ----------------------------------------------------------------------------
local function Rest()
  local lvl = UnitLevel("player") or 0
  local maxLvl = (GetMaxLevelForPlayerExpansion and Safe(GetMaxLevelForPlayerExpansion)) or nil
  if (IsPlayerAtEffectiveMaxLevel and Safe(IsPlayerAtEffectiveMaxLevel)) or (maxLvl and lvl >= maxLvl) then return nil end
  if IsXPUserDisabled and Safe(IsXPUserDisabled) then return nil end
  local xp, xpMax = UnitXP("player") or 0, UnitXPMax("player") or 0
  if xpMax <= 0 then return nil end
  local rested = (GetXPExhaustion and GetXPExhaustion()) or 0
  local parts = { string.format(T("REST_LEVEL", "Niveau %d  ·  %d %%"), lvl, math.floor(xp / xpMax * 100)) }
  if rested > 0 then parts[#parts + 1] = string.format(T("REST_RESTED", "repos %d %%"), math.floor(rested / xpMax * 100)) end
  local api, src = _G.XPBarAPI, nil
  if api and api.GetXPPerHour then
    local rate = Safe(api.GetXPPerHour)
    src = "XPBar"
    if type(rate) == "number" and rate > 0 then
      parts[#parts + 1] = string.format(T("REST_RATE", "niveau dans %s"), Dur((xpMax - xp) / rate * 3600))
    end
  end
  return {
    label = T("TILE_REST", "Expérience"), src = src,
    value = table.concat(parts, "  ·  "), frac = xp / xpMax, color = { 0.737, 0.220, 0.980 },
  }
end

-- ----------------------------------------------------------------------------
-- Concentration (SkillTracker uniquement : la projection est la sienne)
-- ----------------------------------------------------------------------------
local function Conc()
  local api = _G.SkillTrackerAPI
  if not (api and api.GetCharSummary) then return nil end
  local list = Safe(api.GetCharSummary, GetRealmName(), UnitName("player"))
  if type(list) ~= "table" then return nil end
  local best
  for _, s in ipairs(list) do
    if s.isPrimary and s.conc and (s.conc.max or 0) > 0 then
      -- La plus proche du plein (ou deja pleine) en premier.
      if not best or (s.conc.full and not best.conc.full)
         or ((s.conc.cur / s.conc.max) > (best.conc.cur / best.conc.max)) then best = s end
    end
  end
  if not best then return nil end
  local c = best.conc
  local value = string.format("%s  %d / %d", best.name or "?", c.cur or 0, c.max)
  if c.full then value = value .. "  ·  |cFF66D98A" .. T("CONC_FULL", "pleine") .. "|r"
  elseif c.fullIn then value = value .. "  ·  " .. string.format(T("CONC_IN", "pleine dans %s"), Dur(c.fullIn)) end
  return {
    label = T("TILE_CONC", "Concentration"), src = "SkillTracker",
    value = value, frac = (c.cur or 0) / c.max, color = { 0.0, 1.0, 0.596 },
  }
end

-- ----------------------------------------------------------------------------
-- Cle mythique
-- ----------------------------------------------------------------------------
local function Key()
  if not (C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel) then return nil end
  local lvl = Safe(C_MythicPlus.GetOwnedKeystoneLevel)
  if type(lvl) ~= "number" or lvl <= 0 then return nil end
  local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID and Safe(C_MythicPlus.GetOwnedKeystoneChallengeMapID)
  local name = mapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo and Safe(C_ChallengeMode.GetMapUIInfo, mapID)
  return {
    label = T("TILE_KEY", "Clé mythique"), src = Loaded("DgnTracker") and "DgnTracker" or nil,
    value = string.format("+%d  %s", lvl, name or ""), color = { 0.639, 0.208, 0.933 },
  }
end

-- ----------------------------------------------------------------------------
-- Reputation suivie
-- ----------------------------------------------------------------------------
local function Rep()
  if not (C_Reputation and C_Reputation.GetWatchedFactionData) then return nil end
  local d = Safe(C_Reputation.GetWatchedFactionData)
  if type(d) ~= "table" or not d.name or d.name == "" then return nil end
  local src = (Loaded("RenTracker") and "RenTracker") or (Loaded("RepBar") and "RepBar") or nil
  -- Renom (factions majeures)
  if d.factionID and C_Reputation.IsMajorFaction and Safe(C_Reputation.IsMajorFaction, d.factionID)
     and C_MajorFactions and C_MajorFactions.GetMajorFactionData then
    local m = Safe(C_MajorFactions.GetMajorFactionData, d.factionID)
    if type(m) == "table" and m.renownLevel then
      local frac = (m.renownLevelThreshold or 0) > 0 and (m.renownReputationEarned or 0) / m.renownLevelThreshold or nil
      return { label = T("TILE_REP", "Réputation"), src = src,
               value = string.format(T("REP_RENOWN", "%s  ·  renom %d"), d.name, m.renownLevel),
               frac = frac, color = { 0.360, 0.680, 0.960 } }
    end
  end
  local lo, hi, cur = d.currentReactionThreshold or 0, d.nextReactionThreshold or 0, d.currentStanding or 0
  local frac = (hi > lo) and (cur - lo) / (hi - lo) or nil
  local standing = d.reaction and _G["FACTION_STANDING_LABEL" .. d.reaction] or ""
  return { label = T("TILE_REP", "Réputation"), src = src,
           value = d.name .. (standing ~= "" and ("  ·  " .. standing) or ""),
           frac = frac, color = { 0.360, 0.680, 0.960 } }
end

-- ----------------------------------------------------------------------------
-- Reinitialisations
-- ----------------------------------------------------------------------------
local function Reset()
  if not (C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset) then return nil end
  local d = Safe(C_DateAndTime.GetSecondsUntilDailyReset)
  local w = C_DateAndTime.GetSecondsUntilWeeklyReset and Safe(C_DateAndTime.GetSecondsUntilWeeklyReset)
  if not d then return nil end
  local value = string.format(T("RESET_DAILY", "Quotidienne %s"), Dur(d))
  if w then value = value .. "  ·  " .. string.format(T("RESET_WEEKLY", "hebdo %s"), Dur(w)) end
  return { label = T("TILE_RESET", "Réinitialisations"), src = Loaded("DailyTracker") and "DailyTracker" or nil, value = value }
end

-- ----------------------------------------------------------------------------
-- Courrier (meme API que la pastille du core)
-- ----------------------------------------------------------------------------
local function Mail()
  if not (HasNewMail and Safe(HasNewMail)) then return nil end
  return { label = T("TILE_MAIL", "Courrier"), src = Loaded("PostBox") and "PostBox" or nil,
           value = T("MAIL_WAITING", "Du courrier vous attend"), color = { 0.72, 0.47, 0.22 } }
end

-- ----------------------------------------------------------------------------
-- A faire ce soir (personnage connecte) : ce que la suite sait qu'il reste.
-- Une ligne par source presente ; rien si aucun module source n'est charge.
-- ----------------------------------------------------------------------------
local function Todo()
  local lines, sources, allDone = {}, 0, true
  local d = _G.DailyTrackerAPI
  if d and d.GetRemaining then
    local w, dl = Safe(d.GetRemaining)
    if w then
      sources = sources + 1
      if w + (dl or 0) > 0 then
        allDone = false
        lines[#lines + 1] = string.format(T("TODO_QUESTS", "Quêtes : %d hebdo, %d quotidiennes"), w, dl or 0)
      end
    end
  end
  local r = _G.RenTrackerAPI
  if r and r.GetWeeklyRemaining then
    local left, total = Safe(r.GetWeeklyRemaining)
    if left and total and total > 0 then
      sources = sources + 1
      if left > 0 then
        allDone = false
        lines[#lines + 1] = string.format(T("TODO_REP", "Réputation : %d hebdo"), left)
      end
    end
  end
  local s = _G.SkillTrackerAPI
  if s and s.GetCharSummary then
    local list = Safe(s.GetCharSummary, GetRealmName(), UnitName("player"))
    if type(list) == "table" then
      local left, any = 0, false
      for _, p in ipairs(list) do
        if p.week and (p.week.total or 0) > 0 then
          any = true
          left = left + math.max(0, p.week.total - (p.week.done or 0))
        end
      end
      if any then
        sources = sources + 1
        if left > 0 then
          allDone = false
          lines[#lines + 1] = string.format(T("TODO_KNOW", "Métiers : %d source(s) de connaissance"), left)
        end
      end
    end
  end
  local l = _G.LegTrackerAPI
  if l and l.GetFarmRaids then
    local raids = Safe(l.GetFarmRaids)
    if type(raids) == "table" then
      sources = sources + 1
      if #raids > 0 then
        allDone = false
        local shown = { raids[1], raids[2] }
        local txt = table.concat(shown, ", ")
        if #raids > 2 then txt = txt .. string.format(T("TODO_MORE", " +%d"), #raids - 2) end
        lines[#lines + 1] = T("TODO_LEG", "Légendaires : ") .. txt
      end
    end
  end
  if sources == 0 then return nil end
  if allDone then
    lines = { "|cFF66D98A" .. T("TODO_DONE", "Tout est fait pour cette semaine") .. "|r" }
  end
  -- 6 lignes : 4 sources, dont les legendaires qui tiennent souvent sur deux.
  return { label = T("TILE_TODO", "À faire ce soir"), src = "TibiSuite",
           value = table.concat(lines, "\n"), maxLines = 6, color = SB.ACCENT }
end

-- ----------------------------------------------------------------------------
-- Mes personnages : les autres personnages qui attendent quelque chose.
-- ----------------------------------------------------------------------------
local function ClassHex(token)
  local c = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
  return c and SB.Hex({ c.r, c.g, c.b }) or "|cFFFFFFFF"
end

local function Alts()
  local byName, order, srcs = {}, {}, {}
  local me = UnitName("player")
  local function Add(name, class, reason)
    if not name or name == me then return end
    local e = byName[name]
    if not e then e = { class = class, reasons = {} }; byName[name] = e; order[#order + 1] = name end
    e.class = e.class or class
    e.reasons[#e.reasons + 1] = reason
  end
  local wc = _G.WeeklyCompassAPI
  if wc and wc.GetAlts then
    local list = Safe(wc.GetAlts)
    if type(list) == "table" then
      srcs[#srcs + 1] = "WeeklyCompass"
      for _, a in ipairs(list) do
        if a.claim and not a.current then
          Add(a.name, a.class, a.inferred and T("ALT_CLAIM_PROB", "coffre probable") or T("ALT_CLAIM", "coffre à récupérer"))
        end
      end
    end
  end
  local st = _G.SkillTrackerAPI
  if st and st.GetFullConcentrations then
    local list = Safe(st.GetFullConcentrations)
    if type(list) == "table" then
      srcs[#srcs + 1] = "SkillTracker"
      for _, c in ipairs(list) do
        if not c.current then Add(c.name, c.class, string.format(T("ALT_CONC", "%s plein"), c.prof or "?")) end
      end
    end
  end
  local lv = _G.LvlHistoryAPI
  if lv and lv.ListChars and lv.GetCharSummary then
    local keys = Safe(lv.ListChars)
    if type(keys) == "table" then
      srcs[#srcs + 1] = "LvlHistory"
      local maxLvl = (GetMaxLevelForPlayerExpansion and Safe(GetMaxLevelForPlayerExpansion)) or 90
      for _, key in ipairs(keys) do
        local c = Safe(lv.GetCharSummary, key)
        if type(c) == "table" and (c.level or maxLvl) < maxLvl and (c.restedFraction or 0) >= 1 then
          local name = key:match("^(.-)%-") or key
          Add(name, c.class, string.format(T("ALT_REST", "repos %d %%"), math.floor(c.restedFraction * 100)))
        end
      end
    end
  end
  if #srcs == 0 or #order == 0 then return nil end
  local lines, MAX = {}, 4
  for i, name in ipairs(order) do
    if i > MAX then break end
    local e = byName[name]
    lines[#lines + 1] = ClassHex(e.class) .. name .. "|r  " .. table.concat(e.reasons, ", ")
  end
  if #order > MAX then lines[#lines] = lines[#lines] .. string.format(T("ALT_MORE", "  (+%d)"), #order - MAX) end
  return { label = T("TILE_ALTS", "Mes personnages"), src = srcs[1],
           value = table.concat(lines, "\n"), maxLines = 4, color = SB.ACCENT }
end

local BUILDERS = { vault = Vault, todo = Todo, rest = Rest, conc = Conc, key = Key, rep = Rep, reset = Reset, mail = Mail, alts = Alts }

Tiles.LABELS = {
  todo = T("TILE_TODO", "À faire ce soir"), alts = T("TILE_ALTS", "Mes personnages"),
  vault = T("TILE_VAULT", "Grande chambre forte"), rest = T("TILE_REST", "Expérience"),
  conc = T("TILE_CONC", "Concentration"), key = T("TILE_KEY", "Clé mythique"),
  rep = T("TILE_REP", "Réputation"), reset = T("TILE_RESET", "Réinitialisations"),
  mail = T("TILE_MAIL", "Courrier"),
}

function Tiles.Collect()
  local out = {}
  local on = SB.db.tiles
  for _, key in ipairs(SB.TILE_ORDER) do
    if on[key] and BUILDERS[key] then
      local ok, tile = pcall(BUILDERS[key])
      if ok and tile then tile.key = key; out[#out + 1] = tile end
    end
  end
  return out
end
