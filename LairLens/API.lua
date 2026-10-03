-- =============================================================================
-- LairLens - API.lua  (7.1.5.37)
-- API publique pour les autres modules de la suite (WeeklyCompass, DgnTracker,
-- Stats...) et pour les addons tiers. Toujours tester sa presence :
--   if _G.LairLensAPI then local w = LairLensAPI.GetWeek() end
-- Aucune ecriture dans la sauvegarde d'un autre module.
--
-- Resume pour Stats / Dashboard / Companion : LairLensDB.summary, ecrit a
-- PLAYER_LEAVING_WORLD (donc avant le PLAYER_LOGOUT ou Stats exporte) et a la
-- fin de chaque run. Stats le recopie champ par champ (collectLairs).
--   summary = { at, lair = "nom affiche", chars = { ["Nom-Royaume"] = {
--     class, week = { world, normal, heroic, mythic } (booleens), resetAt,
--     runs, kills, loot, last, best = { [diff] = secondes },
--     diffs = { [diff] = { runs, kills, first = pulls rates avant le 1er kill } } } } }
-- NON TESTE EN JEU : a valider par Tibiscui (nouveau fichier : redemarrage
-- complet du client).
-- =============================================================================

local ADDON, LL = ...
local C = LL.const
local D = LL.Data

local function writeSummary()
    if not (LL.db and LL.RunHistory) then return end
    local key = D:GetSingleLair()
    local s = LL.db.summary
    s.at = time()
    s.lair = key and D:GetLairName(key) or nil
    s.chars = s.chars or {}

    -- Historique : tous les personnages du compte.
    local byOwner = {}
    for _, run in ipairs(LL.RunHistory:GetRuns()) do
        local o = run.owner
        if o then
            byOwner[o] = byOwner[o] or { list = {}, class = run.ownerClass }
            local b = byOwner[o]
            b.list[#b.list + 1] = run
            b.class = b.class or run.ownerClass
        end
    end
    for owner, b in pairs(byOwner) do
        local agg = LL.RunHistory:Aggregate(b.list)
        local rec = LL.RunHistory:Records(b.list)
        local c = s.chars[owner] or {}
        c.class = b.class or c.class
        c.runs, c.kills = agg.count, agg.kills
        c.last = b.list[1] and (b.list[1].endTime or b.list[1].startTime) or c.last
        c.loot = 0
        c.best, c.diffs = {}, {}
        for diff, r in pairs(rec) do
            c.loot = c.loot + (r.loot or 0)
            if r.bestKill then c.best[diff] = r.bestKill end
            c.diffs[diff] = { runs = r.runs, kills = r.kills, first = r.wipesBeforeFirst }
        end
        s.chars[owner] = c
    end

    -- Semaine : seulement le personnage connecte (les verrouillages sont par perso).
    local me = LL:CharKey()
    local c = s.chars[me] or {}
    if UnitClass then local _, ct = UnitClass("player"); c.class = ct or c.class end
    local w = LL.Lockouts:GetWeek(key)
    c.week = { world = w.world, normal = w.normal, heroic = w.heroic, mythic = w.mythic }
    c.resetAt = LL.cdb and LL.cdb.weekly and LL.cdb.weekly.resetAt or nil
    s.chars[me] = c
end

LairLensAPI = {
    version = 1,

    -- Dans un Repaire ? Renvoie true/false.
    IsInLair = function() return LL.Detection and LL.Detection:IsInLair() or false end,

    -- Contexte courant (copie) : { inLair, instanceKey, difficultyKey, scenario }.
    GetContext = function()
        local ctx = LL.Detection and LL.Detection:GetContext() or {}
        return { inLair = ctx.inLair, instanceKey = ctx.instanceKey,
                 difficultyKey = ctx.difficultyKey, scenario = ctx.scenario }
    end,

    -- Etat de la semaine du personnage connecte : { world, normal, heroic,
    -- mythic (booleens), count, best }. instanceKey optionnel.
    GetWeek = function(instanceKey)
        if not LL.Lockouts then return nil end
        return LL.Lockouts:GetWeek(instanceKey)
    end,

    -- Nom du Repaire dans la langue du client.
    GetLairName = function(instanceKey)
        return D:GetLairName(instanceKey or D:GetSingleLair())
    end,

    -- Libelle localise d'une difficulte ("world" -> "Monde"...).
    GetDifficultyLabel = function(diff)
        local keys = { world = "DIFF_WORLD", normal = "DIFF_NORMAL", heroic = "DIFF_HEROIC", mythic = "DIFF_MYTHIC" }
        return keys[diff] and LL.L[keys[diff]] or diff
    end,

    -- Ordre des difficultes (cles internes).
    GetDifficulties = function() return { C.DIFF.WORLD, C.DIFF.NORMAL, C.DIFF.HEROIC, C.DIFF.MYTHIC } end,

    -- Ouvre la fiche du Repaire / l'historique.
    OpenInfo = function() if LL.modules.lairInfo then LL.modules.lairInfo:Open() end end,
    OpenHistory = function() if LL.modules.dashboard then LL.modules.dashboard:Open() end end,

    -- Resume ecrit pour Stats (lecture seule cote appelant).
    GetSummary = function() writeSummary(); return LL.db and LL.db.summary end,
}

local function wire()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LEAVING_WORLD")
    f:SetScript("OnEvent", function() pcall(writeSummary) end)
    LL:On("HISTORY_CHANGED", function() pcall(writeSummary) end)
    LL:On("LOCKOUTS_CHANGED", function() pcall(writeSummary) end)
    LL:On("READY", function() C_Timer.After(10, function() pcall(writeSummary) end) end)
end

LL:On("DB_READY", wire)
