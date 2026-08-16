-- =============================================================================
-- LairLens - Core/Abstraction/Lockouts.lua
-- Suivi de "deja valide cette semaine" par Repaire et difficulte.
--
-- INCERTITUDE ASSUMEE : on ne sait pas encore si les Repaires alimentent
-- GetSavedInstanceInfo comme les raids classiques. On prevoit donc DEUX sources,
-- fusionnees derriere une interface unique :
--   1) l'API de lockout du jeu, si/quand les Repaires y apparaissent (lecture) ;
--   2) un suivi maison declenche a la mort du boss (ENCOUNTER_END), robuste meme
--      si l'API ne liste pas les Repaires.
-- Les modules n'appellent que LL.Lockouts:IsCleared(instanceKey, difficultyKey).
-- =============================================================================

local ADDON, LL = ...
local C = LL.const
local D = LL.Data

LL.Lockouts = {}
local Lock = LL.Lockouts

-- --- Source 1 : API de lockout (best effort, tolerante a l'absence) ----------
-- Tente de lire l'etat via l'API. Renvoie true/false, ou nil si indeterminable.
function Lock:QueryGameAPI(instanceKey, difficultyKey)
    if not (GetNumSavedInstances and GetSavedInstanceInfo) then return nil end

    local instanceData = D:GetInstance("lair", instanceKey)
    if not instanceData then return nil end

    -- Sans mapID/nom confirme cote data, on ne peut pas apparier de facon fiable.
    -- On reste donc prudent et on renvoie nil (indetermine) tant que Data.lua
    -- n'a pas les identifiants reels. Le squelette d'appariement est en place.
    local targetName = instanceData.name
    if not targetName then return nil end

    local ok, n = pcall(GetNumSavedInstances)
    if not ok or not n then return nil end

    for i = 1, n do
        local info = { GetSavedInstanceInfo(i) }
        local name = info[1]        -- nom localise de l'instance
        local locked = info[5]      -- booleen "verrouille"
        -- Appariement par nom, faute d'ID stable pour l'instant. A durcir avec
        -- l'instanceID reel une fois connu.
        if name and name == targetName and locked then
            -- Note : l'API ne distingue pas toujours finement la difficulte pour
            -- ce type de contenu tant qu'on n'a pas le difficultyName reel. On
            -- laisse la granularite a la source 2 si besoin.
            return true
        end
    end
    -- IMPORTANT : ne PAS renvoyer false ici. On ignore encore si les Repaires
    -- alimentent GetSavedInstanceInfo. "Pas trouve" vaut donc "indetermine"
    -- (nil), ce qui laisse la main au suivi maison plutot que d'affirmer a tort
    -- "pas valide". Seule une correspondance positive est faisant autorite.
    return nil
end

-- --- Source 2 : suivi maison (SavedVariables par personnage) ------------------
function Lock:MarkCleared(instanceKey, difficultyKey)
    if not (instanceKey and difficultyKey and LL.cdb) then return end
    local clears = LL.cdb.weekly.clears
    clears[instanceKey] = clears[instanceKey] or {}
    clears[instanceKey][difficultyKey] = true
    LL:Emit("LOCKOUTS_CHANGED")
end

function Lock:LocalIsCleared(instanceKey, difficultyKey)
    local clears = LL.cdb and LL.cdb.weekly and LL.cdb.weekly.clears
    if not clears or not clears[instanceKey] then return false end
    return clears[instanceKey][difficultyKey] == true
end

-- --- Interface unique consommee par les modules -------------------------------
-- L'API du jeu prime si elle sait repondre ; sinon on retombe sur le suivi maison.
function Lock:IsCleared(instanceKey, difficultyKey)
    local fromGame = self:QueryGameAPI(instanceKey, difficultyKey)
    if fromGame ~= nil then return fromGame end
    return self:LocalIsCleared(instanceKey, difficultyKey)
end

-- --- Branchements -------------------------------------------------------------
local function wire()
    local f = CreateFrame("Frame", "LairLensLockoutFrame")
    f:RegisterEvent("ENCOUNTER_END")
    f:RegisterEvent("BOSS_KILL")
    f:SetScript("OnEvent", function(_, event, ...)
        if event == "ENCOUNTER_END" then
            -- ENCOUNTER_END(encounterID, encounterName, difficultyID, groupSize, success)
            local encounterID, _, _, _, success = ...
            if success == 1 then
                local ctx = LL.Detection:GetContext()
                if ctx.inLair and ctx.instanceKey and ctx.difficultyKey then
                    Lock:MarkCleared(ctx.instanceKey, ctx.difficultyKey)
                end
            end
        end
    end)

    -- Demande d'actualisation du cache de lockout du jeu, si disponible.
    if RequestRaidInfo then
        LL:On("READY", function() pcall(RequestRaidInfo) end)
    end
end

LL:On("DB_READY", wire)
