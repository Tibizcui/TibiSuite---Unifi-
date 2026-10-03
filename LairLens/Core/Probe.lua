-- =============================================================================
-- LairLens - Core/Probe.lua  (7.1.5.37)
-- Sonde : releve tout ce que le client dit du Repaire courant, pour remplacer
-- les hypotheses par des valeurs vues en jeu. Ecrit dans LairLensDB.probe :
--   probe.auto[<difficulte>] : capture automatique a chaque entree ;
--   probe.manual             : derniere capture par /ll probe.
-- Rien n'est envoye nulle part : la sauvegarde reste sur le PC du joueur.
-- =============================================================================

local ADDON, LL = ...
local U = LL.util

LL.Probe = {}
local P = LL.Probe

local function call(ns, fn, ...)
    local api = ns and ns[fn]
    if type(api) ~= "function" then return "absent" end
    local ok, a, b, c = pcall(api, ...)
    if not ok then return "erreur" end
    if type(a) == "table" then
        local copy = {}
        for k, v in pairs(a) do
            if type(v) ~= "table" and type(v) ~= "function" and type(v) ~= "userdata" then copy[k] = v end
        end
        return copy
    end
    if b ~= nil or c ~= nil then return { a, b, c } end
    return a
end

function P:Capture(kind)
    if not LL.db then return nil end
    local snap = { at = time(), kind = kind, locale = GetLocale and GetLocale() or "?" }
    if GetBuildInfo then
        local version, build, _, toc = GetBuildInfo()
        snap.build = tostring(version) .. "." .. tostring(build) .. " (" .. tostring(toc) .. ")"
    end

    local ii = { GetInstanceInfo() }
    snap.instance = {
        name = ii[1], type = ii[2], difficultyID = ii[3], difficultyName = ii[4],
        maxPlayers = ii[5], dynamicDifficulty = ii[6], isDynamic = ii[7],
        instanceMapID = ii[8], groupSize = ii[9], lfgDungeonID = ii[10],
    }
    if ii[3] and GetDifficultyInfo then
        local ok, dname, groupType, isHeroic, isChallenge, displayHeroic, displayMythic,
              toggleID, isLFR, minP, maxP = pcall(GetDifficultyInfo, ii[3])
        if ok then
            snap.difficulty = {
                name = dname, groupType = groupType, isHeroic = isHeroic, isChallenge = isChallenge,
                displayHeroic = displayHeroic, displayMythic = displayMythic,
                toggleID = toggleID, isLFR = isLFR, minPlayers = minP, maxPlayers = maxP,
            }
        end
    end

    snap.delves = {
        IsInLair = call(C_DelvesUI, "IsInLair"),
        HasActiveLair = call(C_DelvesUI, "HasActiveLair"),
        HasActiveLFGLair = call(C_DelvesUI, "HasActiveLFGLair"),
        HasActiveDelve = call(C_DelvesUI, "HasActiveDelve"),
    }
    snap.scenario = {
        inScenario = call(C_Scenario, "IsInScenario"),
        info = call(C_ScenarioInfo, "GetScenarioInfo"),
        step = call(C_ScenarioInfo, "GetScenarioStepInfo"),
    }

    if C_Map and C_Map.GetBestMapForUnit then
        local okM, uiMap = pcall(C_Map.GetBestMapForUnit, "player")
        if okM and uiMap then
            snap.uiMapID = uiMap
            local okI, info = pcall(C_Map.GetMapInfo, uiMap)
            if okI and type(info) == "table" then snap.uiMapName = info.name end
            if EJ_GetInstanceForMap then
                local okJ, jid = pcall(EJ_GetInstanceForMap, uiMap)
                if okJ then snap.ejInstanceForMap = jid end
            end
            if C_Map.GetPlayerMapPosition then
                local okP, pos = pcall(C_Map.GetPlayerMapPosition, uiMap, "player")
                if okP and pos and pos.GetXY then
                    local x, y = pos:GetXY()
                    snap.pos = { x = x and math.floor(x * 10000) / 100, y = y and math.floor(y * 10000) / 100 }
                end
            end
        end
    end

    -- Verrouillages de raid, bruts (pour apparier le Repaire par instanceId).
    snap.saved = {}
    if GetNumSavedInstances and GetSavedInstanceInfo then
        local okN, n = pcall(GetNumSavedInstances)
        for i = 1, (okN and n or 0) do
            local r = { pcall(GetSavedInstanceInfo, i) }
            if r[1] then
                snap.saved[#snap.saved + 1] = {
                    name = r[2], reset = r[4], diffID = r[5], locked = r[6], isRaid = r[9],
                    maxPlayers = r[10], diffName = r[11], numEnc = r[12], encProg = r[13], instanceId = r[15],
                }
            end
        end
    end

    local ctx = LL.Detection and LL.Detection:GetContext() or {}
    snap.context = {
        inLair = ctx.inLair, instanceKey = ctx.instanceKey, difficultyKey = ctx.difficultyKey,
        how = ctx.how, confident = ctx.confident, scenario = ctx.scenario,
    }
    local lrn = LL.db.learned
    snap.journal = lrn and lrn.journal or nil
    snap.achievements = lrn and lrn.achievements or nil

    if kind == "auto" then
        LL.db.probe.auto = LL.db.probe.auto or {}
        LL.db.probe.auto[tostring(ctx.difficultyKey or ii[3] or "?")] = snap
    else
        LL.db.probe.manual = snap
    end
    return snap
end

-- /ll probe : capture + resume lisible dans le chat.
function P:Run()
    local L = LL.L
    if LL.Journal then LL.Journal:Discover(true) end
    local ctx = LL.Detection and LL.Detection:GetContext() or {}
    if ctx.inLair and LL.Journal then LL.Journal:DiscoverFromMap(ctx.instanceKey) end
    local s = self:Capture("manual")
    if not s then return end
    local i = s.instance
    U.Print(L["PROBE_DONE"])
    U.Print(string.format("%s : %s (%s) map=%s diff=%s \"%s\" taille=%s",
        L["PROBE_INSTANCE"], tostring(i.name), tostring(i.type), tostring(i.instanceMapID),
        tostring(i.difficultyID), tostring(i.difficultyName), tostring(i.groupSize)))
    U.Print(string.format("IsInLair=%s HasActiveLair=%s LFG=%s Delve=%s",
        tostring(s.delves.IsInLair), tostring(s.delves.HasActiveLair),
        tostring(s.delves.HasActiveLFGLair), tostring(s.delves.HasActiveDelve)))
    U.Print(string.format("%s : %s / %s (%s)", L["PROBE_DETECTED"],
        tostring(ctx.instanceKey), tostring(ctx.difficultyKey), tostring(ctx.how)))
    for key, j in pairs(LL.db.learned.journal or {}) do
        U.Print(string.format("%s %s : jid=%s encounter=%s map=%s \"%s\" / \"%s\"", L["PROBE_JOURNAL"],
            key, tostring(j.jid), tostring(j.encounterID), tostring(j.instanceMapID),
            tostring(j.name), tostring(j.boss)))
    end
    U.Print(L["PROBE_SAVED"])
end
