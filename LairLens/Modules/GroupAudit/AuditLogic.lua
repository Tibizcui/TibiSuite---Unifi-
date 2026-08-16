-- =============================================================================
-- LairLens - Modules/GroupAudit/AuditLogic.lua
-- Logique pure : roster + contexte + capacites -> rapport d'audit + verdict.
-- Aucun code d'interface ici. Testable et remplacable independamment de l'UI.
-- =============================================================================

local ADDON, LL = ...
local C = LL.const
local D = LL.Data
local Cap = LL.Capabilities

LL.AuditLogic = {}
local A = LL.AuditLogic

-- Calcule l'effectif de soigneurs cible pour une taille et une attente donnees.
local function healerTarget(size, expectation)
    local raw = size * (expectation.healersRatio or 0)
    return math.max(0, math.ceil(raw))
end

-- Construit le rapport chiffre a partir du roster.
function A:BuildReport(members, difficultyKey, groupSize)
    local expectation = D:GetExpectation(difficultyKey)

    local report = {
        difficultyKey = difficultyKey,
        size = groupSize or #members,
        tanks = 0,
        healers = 0,
        combatRezCount = 0,
        interruptCount = 0,
        hasLust = false,
        dispels = {
            [C.DISPEL.MAGIC] = 0,
            [C.DISPEL.CURSE] = 0,
            [C.DISPEL.POISON] = 0,
            [C.DISPEL.DISEASE] = 0,
        },
        expectation = expectation,
        targets = {},
    }

    for i = 1, #members do
        local m = members[i]
        local class = m.class

        if m.role == C.ROLE.TANK then
            report.tanks = report.tanks + 1
        elseif m.role == C.ROLE.HEALER then
            report.healers = report.healers + 1
        end

        if class then
            if Cap:HasCombatRez(class) then
                report.combatRezCount = report.combatRezCount + 1
            end
            if Cap:HasLust(class) then
                report.hasLust = true
            end
            if Cap:HasInterrupt(class) then
                report.interruptCount = report.interruptCount + 1
            end
            for _, dtype in ipairs(C.DISPEL_ORDER) do
                -- Dissipation resolue par classe + role (m.role vient du roster).
                if Cap:HasDispel(class, m.role, dtype) then
                    report.dispels[dtype] = report.dispels[dtype] + 1
                end
            end
        end
    end

    report.targets.tanks = expectation.tanks or 1
    report.targets.healers = healerTarget(report.size, expectation)

    return report
end

-- Derive le verdict et la liste des manques a partir du rapport.
-- Deux niveaux : MISSING (lacune bloquante) l'emporte sur RISKY (confort).
function A:Evaluate(report)
    local L = LL.L
    local exp = report.expectation
    local blocking = {}   -- lacunes structurantes
    local thin = {}       -- points justes mais jouables

    -- Tanks : aucun tank = bloquant ; sous l'effectif cible = juste.
    if report.tanks == 0 then
        table.insert(blocking, L["MISS_TANK"])
    elseif report.tanks < (report.targets.tanks or 1) then
        table.insert(thin, L["MISS_TANK"])
    end

    -- Soigneurs : zero soigneur quand on en attend = bloquant ; sous la cible = juste.
    if report.targets.healers > 0 then
        if report.healers == 0 then
            table.insert(blocking,
                string.format(L["MISS_HEALER"], report.healers, report.targets.healers))
        elseif report.healers < report.targets.healers then
            table.insert(thin,
                string.format(L["MISS_HEALER"], report.healers, report.targets.healers))
        end
    end

    -- Rez de combat : bloquant a l'entree si la difficulte l'exige et qu'il n'y en a aucun.
    if exp.needCombatRez and report.combatRezCount == 0 then
        table.insert(blocking, L["MISS_COMBAT_REZ"])
    end

    -- Lust : confort structurant sur les hautes difficultes, jamais bloquant seul.
    if exp.needLust and not report.hasLust then
        table.insert(thin, L["MISS_LUST"])
    end

    -- Interruptions : absence totale = juste (rarement bloquant a lui seul).
    if exp.needInterrupt and report.interruptCount == 0 then
        table.insert(thin, L["MISS_INTERRUPT"])
    end

    local verdict, reasons
    if #blocking > 0 then
        verdict, reasons = C.VERDICT.MISSING, blocking
    elseif #thin > 0 then
        verdict, reasons = C.VERDICT.RISKY, thin
    else
        verdict, reasons = C.VERDICT.VIABLE, {}
    end

    return verdict, reasons
end

-- Point d'entree unique : produit rapport + verdict + libelle pret a afficher.
function A:Run(members, difficultyKey, groupSize)
    local L = LL.L
    local report = self:BuildReport(members, difficultyKey, groupSize)
    local verdict, reasons = self:Evaluate(report)

    local headline
    if verdict == C.VERDICT.VIABLE then
        headline = L["VERDICT_VIABLE"]
    elseif verdict == C.VERDICT.RISKY then
        headline = L["VERDICT_RISKY"]
    else
        headline = string.format(L["VERDICT_MISSING"], table.concat(reasons, ", "))
    end

    report.verdict = verdict
    report.reasons = reasons
    report.headline = headline
    return report
end
