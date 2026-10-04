-- API.lua
-- LvlHistory — API publique pour la suite (_G.LvlHistoryAPI) et resume
-- Dashboard ecrit dans LvlHistoryDB.dashboard (lu par Stats/Export.lua,
-- jamais par du code : lecture seule de la SavedVariable, comme LegTracker).
-- Auteur : Tibizcui | Famille : TibiSuite

LvlHistory = LvlHistory or {}
local T = LvlHistory
T.API = T.API or {}
local API = T.API

local RACE_FROM = 10   -- la "montee" se mesure du niveau 10 au niveau max

local function Chars()
    return (LvlHistoryDB and LvlHistoryDB.chars) or {}
end

--- Temps de jeu de la montee RACE_FROM -> max d'un personnage, si TOUS les
--- niveaux intermediaires ont ete suivis en entier. nil sinon.
function API.GetRace(c, maxLvl)
    if type(c) ~= "table" or type(c.levelLog) ~= "table" then return nil end
    maxLvl = maxLvl or T.MaxLevel()
    if (c.level or 0) < maxLvl then return nil end
    local sum = 0
    for l = RACE_FROM, maxLvl - 1 do
        local e = c.levelLog[l]
        if not e or e.partial or not e.t then return nil end
        sum = sum + e.t
    end
    return sum > 0 and sum or nil
end

--- Meilleure montee parmi tous les persos : secondes, cle du perso.
function API.GetBestRace()
    local maxLvl = T.MaxLevel()
    local best, who
    for key, c in pairs(Chars()) do
        local r = API.GetRace(c, maxLvl)
        if r and (not best or r < best) then best, who = r, key end
    end
    return best, who
end

--- Meilleur XP/h et meilleur or/h des sessions d'un perso.
function API.GetRecords(c)
    local bestXPH, bestGoldH = 0, 0
    for _, s in ipairs((c and c.sessions) or {}) do
        if s.mode == "leveling" and (s.xph or 0) > bestXPH then bestXPH = s.xph end
        local g = s.goldEarned or s.goldGained or 0
        if (s.duration or 0) >= 600 and g > 0 then
            local gh = math.floor(g / s.duration * 3600)
            if gh > bestGoldH then bestGoldH = gh end
        end
    end
    return bestXPH, bestGoldH
end

-- ─────────────────────────────────────────────
-- API publique
-- ─────────────────────────────────────────────
local pub = _G.LvlHistoryAPI or {}
_G.LvlHistoryAPI = pub

pub.VERSION = 1

--- Abonnement aux evenements (onLevelUp, onDungeonCompleted, onDelveCompleted,
--- onSessionEnd, onQuestTurnIn, onRepGain, onModeSwitch).
function pub.Register(event, addonName, fn) return T.Bridge.Register(event, addonName, fn) end

--- Session en cours du perso connecte (copie, lecture seule).
function pub.GetSession()
    local db = T.db
    if not db then return nil end
    local s = db.session
    return {
        mode = db.mode, startTime = s.startTime,
        duration = time() - (s.startTime or time()),
        xpGained = s.xpGain or 0, xph = s.xph or 0,
        liveXPH = T.Leveling.GetLiveXPH and T.Leveling.GetLiveXPH() or nil,
        goldPerHour = db.farming.goldPerHour or 0,
        quests = s.questCount or 0, dungeons = s.dungeons or 0, delves = s.delves or 0,
        zone = s.zone,
    }
end

--- Cles de tous les persos connus ("Nom-Royaume"), triees. Lue par la tuile
--- « Mes personnages » de Standby (depuis 7.1.5.40).
function pub.ListChars()
    local out = {}
    for key in pairs(Chars()) do out[#out + 1] = key end
    table.sort(out)
    return out
end

--- Resume d'un perso ("Nom-Royaume", perso connecte par defaut).
function pub.GetCharSummary(key)
    key = key or T.charKey
    local c = Chars()[key]
    if not c then return nil end
    local isCur = (key == T.charKey)
    local restXP, restFrac = T.EstimateRested(c, isCur)
    local bestXPH, bestGoldH = API.GetRecords(c)
    return {
        key = key, level = isCur and UnitLevel("player") or c.level, class = c.class,
        mode = c.mode, playTime = c.totalPlayTime or 0,
        restedXP = restXP, restedFraction = restFrac,
        race = API.GetRace(c), bestXPH = bestXPH, bestGoldPerHour = bestGoldH,
        lastSeen = c.lastSeen,
    }
end

--- Chronologie des niveaux : { [niveau] = { t, at, partial } } (copie).
function pub.GetLevelLog(key)
    local c = Chars()[key or T.charKey]
    return c and CopyTable(c.levelLog or {}) or nil
end

--- Ouvre la fenetre sur un onglet (1 Session, 2 Zones, 3 Alts, 4 Donjons, 5 Stats, 6 Niveaux).
function pub.Open(tab)
    if T.UI and T.UI.OpenTab then T.UI.OpenTab(tab or 1) end
end

-- ─────────────────────────────────────────────
-- Resume Dashboard (Stats -> site / Tibi Companion)
-- ─────────────────────────────────────────────

local function BuildCharDash(key, c, maxLvl)
    local isCur = (key == T.charKey)
    local out = {
        lvl = isCur and UnitLevel("player") or c.level, cls = c.class, mode = c.mode,
        play = math.floor(c.totalPlayTime or 0), seen = c.lastSeen,
    }
    -- Niveaux termines (tries)
    local levels = {}
    for l, e in pairs(c.levelLog or {}) do
        if type(l) == "number" and type(e) == "table" and e.t then
            levels[#levels + 1] = { l = l, t = math.floor(e.t), at = e.at, p = e.partial and 1 or nil }
        end
    end
    table.sort(levels, function(a, b) return a.l < b.l end)
    if #levels > 0 then out.levels = levels end
    if c.levelClock then
        out.onLevel = { l = c.levelClock.level, t = math.floor(c.levelClock.t or 0) }
    end
    out.race = API.GetRace(c, maxLvl)

    local xs = c.xpSrc or {}
    if (xs.quest or 0) + (xs.dungeon or 0) + (xs.delve or 0) + (xs.other or 0) > 0 then
        out.xpSrc = { q = xs.quest or 0, d = xs.dungeon or 0, g = xs.delve or 0, o = xs.other or 0 }
    end
    local _, frac = T.EstimateRested(c, isCur)
    if frac and out.lvl and out.lvl < maxLvl then out.rest = math.floor(frac * 100 + 0.5) end

    -- 20 dernieres sessions
    local sess, list = {}, c.sessions or {}
    for i = math.max(1, #list - 19), #list do
        local s = list[i]
        sess[#sess + 1] = {
            d = s.date, dur = s.duration, m = s.mode == "farming" and "f" or "l",
            xph = s.xph or 0, gold = s.goldEarned or s.goldGained or 0,
            l0 = s.levelStart, l1 = s.levelEnd, q = s.quests, dg = s.dungeons, dv = s.delves,
        }
    end
    if #sess > 0 then out.sess = sess end

    local bx, bg = API.GetRecords(c)
    out.best = { xph = bx, goldh = bg }
    local dgn, dv = 0, 0
    for _, n in pairs(c.dgnRuns or {}) do dgn = dgn + n end
    for _, n in pairs(c.delveRuns or {}) do dv = dv + n end
    out.dgn, out.delves = dgn, dv
    local q = c.quests or {}
    out.quests = { t = q.total or 0, d = q.daily or 0, w = q.weekly or 0 }
    return out
end

function API.WriteDashboard()
    if not LvlHistoryDB then return end
    local ok, res = pcall(function()
        local maxLvl = T.MaxLevel()
        local chars = {}
        for key, c in pairs(Chars()) do
            if type(key) == "string" and type(c) == "table" then
                chars[key] = BuildCharDash(key, c, maxLvl)
            end
        end
        return { v = 1, at = time(), by = T.charKey, max = maxLvl, chars = chars }
    end)
    if ok and res then
        LvlHistoryDB.dashboard = res
    else
        T.Utils.Log("Dashboard : %s", tostring(res))
    end
end
