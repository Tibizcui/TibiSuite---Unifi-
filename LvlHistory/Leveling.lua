-- Leveling.lua
-- LvlHistory — Logique MODE_LEVELING
-- Trackée : XP gagnee, XP/h, origine de l'XP (quetes, donjons, gouffres, reste)
-- (zones et quetes sont suivies par Core.lua, dans tous les modes)
-- Auteur : Tibizcui | Famille : TibiSuite

LvlHistory.Leveling = LvlHistory.Leveling or {}
local L = LvlHistory.Leveling

local levelingFrame
local isRunning = false

-- Attribution quetes <-> XP : QUEST_TURNED_IN (qui porte l'XP reelle de la
-- quete) et PLAYER_XP_UPDATE arrivent dans un ordre non garanti. On garde
-- donc les deux cotes en attente quelques secondes pour les rapprocher.
local QUEST_MATCH_WINDOW = 3
local pendingQuestXP, pendingQuestAt = 0, 0
local lastOtherXP, lastOtherAt = 0, 0

-- ─────────────────────────────────────────────
-- Origine de l'XP
-- ─────────────────────────────────────────────

local function AddSource(kind, amount)
    local db = LvlHistory.db
    if not db or amount <= 0 then return end
    db.xpSrc[kind] = (db.xpSrc[kind] or 0) + amount
    local ss = db.session.xpSrc
    if ss then ss[kind] = (ss[kind] or 0) + amount end
end

local function MoveSource(from, to, amount)
    local db = LvlHistory.db
    if not db or amount <= 0 then return end
    db.xpSrc[from] = math.max(0, (db.xpSrc[from] or 0) - amount)
    db.xpSrc[to]   = (db.xpSrc[to] or 0) + amount
    local ss = db.session.xpSrc
    if ss then
        ss[from] = math.max(0, (ss[from] or 0) - amount)
        ss[to]   = (ss[to] or 0) + amount
    end
end

local function Attribute(delta)
    local ctx = LvlHistory.CurrentContext()
    if ctx == "dungeon" or ctx == "delve" then
        AddSource(ctx, delta)
        return
    end
    local now = GetTime()
    if pendingQuestXP > 0 and now - pendingQuestAt <= QUEST_MATCH_WINDOW then
        local q = math.min(delta, pendingQuestXP)
        pendingQuestXP = pendingQuestXP - q
        AddSource("quest", q)
        delta = delta - q
    end
    if delta > 0 then
        AddSource("other", delta)
        lastOtherXP, lastOtherAt = delta, now
    end
end

--- Appele par Core.lua a chaque QUEST_TURNED_IN (xpReward = XP reelle).
function L.OnQuestXP(xpReward)
    if not isRunning or not xpReward or xpReward <= 0 then return end
    if LvlHistory.CurrentContext() ~= "world" then return end
    local now = GetTime()
    -- XP deja arrivee juste avant et classee "reste" : on la reclasse
    if lastOtherXP > 0 and now - lastOtherAt <= QUEST_MATCH_WINDOW then
        local m = math.min(xpReward, lastOtherXP)
        MoveSource("other", "quest", m)
        lastOtherXP = lastOtherXP - m
        xpReward = xpReward - m
    end
    if xpReward > 0 then
        pendingQuestXP = pendingQuestXP + xpReward
        pendingQuestAt = now
    end
end

-- ─────────────────────────────────────────────
-- XP de session
-- ─────────────────────────────────────────────

-- XP gagnee = somme des ecarts entre deux lectures. L'XP ne baisse jamais
-- sauf au passage de niveau : une baisse signale donc un niveau franchi, et
-- l'ecart vaut (reste du niveau precedent) + XP actuelle. Aucune dependance
-- a l'ordre PLAYER_LEVEL_UP / PLAYER_XP_UPDATE.
local function OnXPUpdate()
    local db = LvlHistory.db
    if not db then return end
    local s = db.session

    local cur, max = UnitXP("player"), UnitXPMax("player")
    local delta = 0
    if s.lastXP then
        if cur >= s.lastXP then
            delta = cur - s.lastXP
        else
            delta = math.max(0, (s.lastMax or 0) - s.lastXP) + cur
        end
    end
    s.lastXP, s.lastMax = cur, max

    if delta > 0 then
        s.xpGain = (s.xpGain or 0) + delta
        Attribute(delta)
    end

    local elapsed = time() - (s.startTime or time())
    if elapsed >= 10 then
        s.xph = math.floor((s.xpGain or 0) / elapsed * 3600)
    end

    LvlHistory.Utils.Log("XP +%d | XP/h: %d", delta, s.xph or 0)
end

-- ─────────────────────────────────────────────
-- API publique
-- ─────────────────────────────────────────────

--- @param resume boolean  session reprise apres /reload : on garde les compteurs
function L.Start(resume)
    if isRunning then return end
    isRunning = true

    local db = LvlHistory.db
    if db then
        local s = db.session
        if not resume or not s.lastXP then
            s.lastXP  = UnitXP("player")
            s.lastMax = UnitXPMax("player")
        else
            -- Rattrape l'XP gagnee entre la derniere lecture et le /reload
            OnXPUpdate()
        end
        s.xpGain = s.xpGain or 0
    end

    levelingFrame = levelingFrame or CreateFrame("Frame", "LvlHistoryLevelingFrame", UIParent)
    levelingFrame:RegisterEvent("PLAYER_XP_UPDATE")
    levelingFrame:SetScript("OnEvent", function() OnXPUpdate() end)

    LvlHistory.Utils.Log("Mode LEVELING démarré")
end

function L.Stop()
    if not isRunning then return end
    isRunning = false
    if levelingFrame then levelingFrame:UnregisterAllEvents() end
    LvlHistory.Utils.Log("Mode LEVELING arrêté")
end

--- Solde une derniere lecture (avant de figer la session au niveau max).
function L.Flush()
    if isRunning then OnXPUpdate() end
end

--- XP/h de la session. Si XPBar est la, son XP/h "en direct" (fenetre
--- glissante) est disponible via GetLiveXPH, sans recalcul ici.
function L.GetXPH()
    local db = LvlHistory.db
    return db and db.session.xph or 0
end

function L.GetLiveXPH()
    local api = _G.XPBarAPI
    local fn = api and (api.GetRollingXPPerHour or api.GetXPPerHour)
    if fn then
        local ok, v = pcall(fn)
        if ok and type(v) == "number" and v > 0 then return v end
    end
    return nil
end

--- XP totale gagnee sur la session courante, level ups compris.
function L.GetSessionXP()
    local db = LvlHistory.db
    return db and db.session.xpGain or 0
end

--- Estimation du temps restant jusqu'au niveau max, a l'XP/h donnee.
--- Le jeu ne donne l'XP requise que pour le niveau en cours : les niveaux
--- suivants sont estimes a la meme valeur (legere sous-estimation, d'ou "~").
--- Si la chronologie connait deja des niveaux complets, on prend le plus
--- prudent des deux calculs.
function L.EstimateToMax(xph)
    local lvl, maxLvl = UnitLevel("player"), LvlHistory.MaxLevel()
    if lvl >= maxLvl then return nil end
    local cur, max = UnitXP("player"), UnitXPMax("player")
    local remainingLevels = maxLvl - lvl - 1
    local byXP
    if xph and xph > 0 and max > 0 then
        byXP = ((max - cur) + remainingLevels * max) / xph * 3600
    end
    local byLog
    local db = LvlHistory.db
    if db and db.levelLog then
        local sum, n = 0, 0
        for l = lvl - 1, math.max(1, lvl - 5), -1 do
            local e = db.levelLog[l]
            if e and not e.partial and (e.t or 0) > 0 then sum = sum + e.t; n = n + 1 end
        end
        if n >= 2 then
            local avg = sum / n
            local clk = db.levelClock
            local onLevel = clk and clk.t or 0
            byLog = math.max(0, avg - onLevel) + remainingLevels * avg
        end
    end
    if byXP and byLog then return math.max(byXP, byLog) end
    return byXP or byLog
end
