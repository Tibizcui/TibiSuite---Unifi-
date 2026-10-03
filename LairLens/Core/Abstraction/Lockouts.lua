-- =============================================================================
-- LairLens - Core/Abstraction/Lockouts.lua
-- Suivi de "deja valide cette semaine" par Repaire et difficulte.
--
-- Deux sources, fusionnees derriere une interface unique :
--   1) l'API de verrouillage du jeu (GetSavedInstanceInfo), lue a chaque
--      UPDATE_INSTANCE_INFO et appariee par instanceID (14e retour) puis par
--      nom replie, dans toutes les langues ;
--   2) un suivi maison declenche a la mort du boss (ENCOUNTER_END reussi, ou
--      fin du scenario en difficulte Monde), robuste si le Repaire n'apparait
--      pas dans la liste du jeu.
-- Les modules n'appellent que LL.Lockouts:IsCleared(instanceKey, difficultyKey)
-- et LL.Lockouts:GetWeek(instanceKey).
-- NON TESTE EN JEU : presence des Repaires dans GetSavedInstanceInfo a confirmer.
-- =============================================================================

local ADDON, LL = ...
local C = LL.const
local D = LL.Data
local U = LL.util

LL.Lockouts = {}
local Lock = LL.Lockouts

-- [instanceKey] = { [difficultyKey] = { killed=, total=, expiresAt= } }
Lock.game = {}

local function instanceKeyFor(name, instanceId)
    local lrn = LL.db and LL.db.learned
    if instanceId and lrn and lrn.maps[instanceId] then return lrn.maps[instanceId] end
    local folded = U.Fold(name)
    if folded == "" then return nil end
    for key, inst in pairs(D:GetInstances("lair") or {}) do
        for _, n in ipairs(inst.matchNames or {}) do
            if folded == U.Fold(n) then return key end
        end
        local j = lrn and lrn.journal and lrn.journal[key]
        if j and j.name and folded == U.Fold(j.name) then return key end
    end
    return nil
end

-- --- Source 1 : API de verrouillage du jeu ------------------------------------
function Lock:ReadGameAPI()
    if not (GetNumSavedInstances and GetSavedInstanceInfo) then return end
    local okN, n = pcall(GetNumSavedInstances)
    if not okN or not n then return end
    local fresh = {}
    local now = time()
    for i = 1, n do
        local ok, name, _, reset, diffID, locked, extended, _, _, _, diffName,
              numEnc, encProg, _, instanceId = pcall(GetSavedInstanceInfo, i)
        if ok and (locked or extended) and (tonumber(reset) or 0) > 0 then
            local key = instanceKeyFor(name, tonumber(instanceId))
            if key then
                local diffKey = LL.Detection:GetDifficultyKey(tonumber(diffID), diffName)
                if diffKey and (tonumber(encProg) or 0) > 0 then
                    fresh[key] = fresh[key] or {}
                    fresh[key][diffKey] = {
                        killed = tonumber(encProg) or 0, total = tonumber(numEnc) or 0,
                        expiresAt = now + (tonumber(reset) or 0),
                    }
                end
            end
        end
    end
    self.game = fresh
    LL:Emit("LOCKOUTS_CHANGED")
end

function Lock:QueryGameAPI(instanceKey, difficultyKey)
    local byInst = self.game[instanceKey]
    local e = byInst and byInst[difficultyKey]
    if e and e.expiresAt > time() then return true end
    -- "Pas trouve" vaut "indetermine" (nil) : seule une correspondance positive
    -- fait autorite, le suivi maison prend le relais sinon.
    return nil
end

-- --- Source 2 : suivi maison (SavedVariables par personnage) ------------------
function Lock:MarkCleared(instanceKey, difficultyKey)
    if not (instanceKey and difficultyKey and LL.cdb) then return end
    local clears = LL.cdb.weekly.clears
    clears[instanceKey] = clears[instanceKey] or {}
    if clears[instanceKey][difficultyKey] then return end
    clears[instanceKey][difficultyKey] = true
    LL:Emit("LOCKOUTS_CHANGED")
end

function Lock:LocalIsCleared(instanceKey, difficultyKey)
    local clears = LL.cdb and LL.cdb.weekly and LL.cdb.weekly.clears
    if not clears or not clears[instanceKey] then return false end
    return clears[instanceKey][difficultyKey] == true
end

-- --- Interface unique consommee par les modules -------------------------------
function Lock:IsCleared(instanceKey, difficultyKey)
    local fromGame = self:QueryGameAPI(instanceKey, difficultyKey)
    if fromGame ~= nil then return fromGame end
    return self:LocalIsCleared(instanceKey, difficultyKey)
end

-- Etat de la semaine : { world=bool, normal=bool, heroic=bool, mythic=bool,
-- count = nb de difficultes faites, best = plus haute difficulte faite }.
function Lock:GetWeek(instanceKey)
    instanceKey = instanceKey or D:GetSingleLair()
    local out = { count = 0 }
    for _, diff in ipairs(C.DIFF_ORDER) do
        local done = instanceKey and self:IsCleared(instanceKey, diff) or false
        out[diff] = done
        if done then out.count = out.count + 1; out.best = diff end
    end
    return out
end

-- --- Branchements -------------------------------------------------------------
local function wire()
    local f = CreateFrame("Frame", "LairLensLockoutFrame")
    f:RegisterEvent("ENCOUNTER_END")
    f:RegisterEvent("UPDATE_INSTANCE_INFO")
    pcall(f.RegisterEvent, f, "SCENARIO_COMPLETED")
    f:SetScript("OnEvent", function(_, event, ...)
        if event == "ENCOUNTER_END" then
            -- ENCOUNTER_END(encounterID, encounterName, difficultyID, groupSize, success)
            local _, _, _, _, success = ...
            if success == 1 then
                local ctx = LL.Detection:GetContext()
                if ctx.inLair and ctx.instanceKey and ctx.difficultyKey then
                    Lock:MarkCleared(ctx.instanceKey, ctx.difficultyKey)
                end
                if RequestRaidInfo then C_Timer.After(2, function() pcall(RequestRaidInfo) end) end
            end
        elseif event == "SCENARIO_COMPLETED" then
            -- Difficulte Monde : file solo, scenario en 2 parties termine par le boss.
            local ctx = LL.Detection:GetContext()
            if ctx.inLair and ctx.instanceKey and ctx.difficultyKey == C.DIFF.WORLD then
                Lock:MarkCleared(ctx.instanceKey, C.DIFF.WORLD)
            end
        elseif event == "UPDATE_INSTANCE_INFO" then
            Lock:ReadGameAPI()
        end
    end)

    if RequestRaidInfo then
        LL:On("READY", function() pcall(RequestRaidInfo) end)
    end
    LL:On("JOURNAL_READY", function() Lock:ReadGameAPI() end)
end

LL:On("DB_READY", wire)
