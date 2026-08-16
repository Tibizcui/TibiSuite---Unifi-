-- =============================================================================
-- LairLens - Modules/RunHistory/RunTracker.lua
-- Capture d'un run de Repaire, du premier pas dedans jusqu'a la sortie.
--
-- S'appuie uniquement sur les couches d'abstraction (Detection, Roster) et sur
-- deux evenements de boss. Point d'incertitude assume et signale : on ignore si
-- ENCOUNTER_START/END se declenchent pour les Repaires (contenu neuf). Le run est
-- donc TOUJOURS enregistre sur le temps passe dedans ; les tentatives/kills se
-- remplissent en plus SI ces evenements arrivent. Aucune donnee inventee.
--
-- ilvl des membres : gratuit et exact pour soi (GetAverageItemLevel), best-effort
-- pour les autres via inspection (NotifyInspect -> INSPECT_READY), asynchrone,
-- bridee et limitee a la portee. Un ilvl inconnu reste nil (affiche "?").
-- =============================================================================

local ADDON, LL = ...
local C = LL.const

local active = nil       -- run en cours (ou nil)
local inspectQueue = {}  -- unites en attente d'inspection pour l'ilvl
local inspecting = false

-- --- ilvl -------------------------------------------------------------------
local function selfItemLevel()
    if type(GetAverageItemLevel) ~= "function" then return nil end
    local ok, _, equipped = pcall(GetAverageItemLevel)
    if ok and type(equipped) == "number" and equipped > 0 then
        return math.floor(equipped + 0.5)
    end
    return nil
end

local function inspectItemLevel(unit)
    if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        local ok, ilvl = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)
        if ok and type(ilvl) == "number" and ilvl > 0 then
            return math.floor(ilvl + 0.5)
        end
    end
    return nil
end

-- Traite la file d'inspection une unite a la fois (l'API est bridee).
local function processInspect()
    if inspecting then return end
    local unit = table.remove(inspectQueue, 1)
    if not unit then return end
    if not (UnitExists and UnitExists(unit) and CanInspect and CanInspect(unit)) then
        return processInspect()  -- passe a la suivante
    end
    inspecting = true
    if NotifyInspect then pcall(NotifyInspect, unit) end
    -- Filet de securite : si INSPECT_READY n'arrive pas, on debloque la file.
    C_Timer.After(1.5, function()
        if inspecting then
            inspecting = false
            processInspect()
        end
    end)
end

-- Met a jour l'ilvl d'un membre du run en cours, retrouve par son GUID.
local function applyInspectResult(guid)
    if not active or not active.group then return end
    for _, m in ipairs(active.group) do
        if m.guid and m.guid == guid then
            local ilvl = inspectItemLevel(m.unit or "")
            if ilvl then m.ilvl = ilvl end
            break
        end
    end
end

-- --- Instantane du groupe ----------------------------------------------------
-- Construit (ou fusionne) la liste des membres avec ce qu'on sait tout de suite,
-- et met en file les autres pour l'inspection ilvl.
local function snapshotGroup()
    if not active then return end
    local prevByName = {}
    for _, m in ipairs(active.group or {}) do
        if m.name then prevByName[m.name] = m end
    end

    local members = LL.Roster and LL.Roster:GetMembers() or {}
    local list = {}
    wipe(inspectQueue)
    inspecting = false

    for _, m in ipairs(members) do
        local unit = m.unit
        local isPlayer = unit and UnitIsUnit and UnitIsUnit(unit, "player")
        local prev = m.name and prevByName[m.name]
        local ilvl = prev and prev.ilvl or nil
        if isPlayer then ilvl = selfItemLevel() or ilvl end

        local entry = {
            name = m.name,
            class = m.class,
            role = m.role,
            unit = unit,
            guid = unit and UnitGUID and UnitGUID(unit) or nil,
            ilvl = ilvl,
        }
        list[#list + 1] = entry

        -- Met en file les autres joueurs sans ilvl connu, pour inspection.
        if not isPlayer and not entry.ilvl and unit then
            inspectQueue[#inspectQueue + 1] = unit
        end
    end

    active.group = list
    processInspect()
end

-- --- Cycle de vie d'un run ---------------------------------------------------
local function startRun(ctx)
    local player = (UnitName and UnitName("player")) or "?"
    local realm = (GetRealmName and GetRealmName()) or ""
    local class
    if UnitClass then local _, ct = UnitClass("player"); class = ct end

    local instName = ctx.instanceKey
    if LL.Data and ctx.instanceKey then
        local inst = LL.Data:GetInstance("lair", ctx.instanceKey)
        if inst and inst.name then instName = inst.name end
    end

    active = {
        owner = player .. (realm ~= "" and ("-" .. realm) or ""),
        ownerClass = class,
        instanceKey = ctx.instanceKey,
        instanceName = instName,
        difficulty = ctx.difficultyKey,
        startTime = time(),
        attempts = 0,
        kills = 0,
        group = {},
    }
    snapshotGroup()
end

local function finalizeRun()
    if not active then return end
    active.endTime = time()
    active.duration = math.max(0, active.endTime - (active.startTime or active.endTime))
    active.result = (active.kills > 0) and C.RUN.KILL or C.RUN.INCOMPLETE
    -- On ne conserve pas les references d'unites volatiles dans la SavedVariable.
    for _, m in ipairs(active.group or {}) do m.unit = nil end
    LL.RunHistory:AddRun(active)
    active = nil
    wipe(inspectQueue)
    inspecting = false
end

-- Reagit aux transitions de contexte fournies par Detection.
local function onContext(ctx)
    if not (LL.db and LL.db.runTracking) then
        finalizeRun()  -- suivi coupe : on clot proprement un eventuel run en cours
        return
    end

    local nowIn = ctx and ctx.inLair and ctx.instanceKey

    if active then
        local changed = (not nowIn)
            or active.instanceKey ~= ctx.instanceKey
            or active.difficulty ~= ctx.difficultyKey
        if changed then finalizeRun() end
    end

    if nowIn and not active then
        startRun(ctx)
    end
end

-- --- Cablage -----------------------------------------------------------------
local function wire()
    LL:On("LAIR_CONTEXT_CHANGED", onContext)

    -- Le roster bouge (joueur qui rejoint/quitte) : on rafraichit l'instantane.
    LL:On("ROSTER_CHANGED", function()
        if active then snapshotGroup() end
    end)

    local f = CreateFrame("Frame", "LairLensRunTrackerFrame")
    f:RegisterEvent("ENCOUNTER_START")
    f:RegisterEvent("ENCOUNTER_END")
    f:RegisterEvent("INSPECT_READY")
    f:RegisterEvent("PLAYER_LOGOUT")
    f:SetScript("OnEvent", function(_, event, ...)
        if event == "ENCOUNTER_START" then
            if active then active.attempts = active.attempts + 1 end
        elseif event == "ENCOUNTER_END" then
            -- ENCOUNTER_END(encounterID, name, difficultyID, groupSize, success)
            local _, _, _, _, success = ...
            if active and success == 1 then active.kills = active.kills + 1 end
        elseif event == "INSPECT_READY" then
            local guid = ...
            applyInspectResult(guid)
            if ClearInspectPlayer then pcall(ClearInspectPlayer) end
            inspecting = false
            C_Timer.After(0.3, processInspect)
        elseif event == "PLAYER_LOGOUT" then
            finalizeRun()  -- ne pas perdre un run en cours a la deconnexion
        end
    end)
end

LL:On("DB_READY", wire)
