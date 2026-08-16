-- =============================================================================
-- LairLens - Core/Abstraction/Roster.lua
-- Lit le groupe/raid via l'API stable et produit une liste normalisee, unique
-- point de verite pour les modules. Emet ROSTER_CHANGED sur variation.
-- =============================================================================

local ADDON, LL = ...
local C = LL.const

LL.Roster = {}
local R = LL.Roster

-- Etat courant : liste d'entrees { unit, name, class, role }.
R.members = {}
R.size = 0

-- Construit l'iterateur d'unites selon le contexte (raid, groupe, solo).
-- Idiome stable : en raid on parcourt raid1..raidN ; en groupe party1..party(N-1)
-- plus "player" ; seul, juste "player".
local function iterateUnits(callback)
    if IsInRaid() then
        local n = GetNumGroupMembers()
        for i = 1, n do
            callback("raid" .. i)
        end
    elseif IsInGroup() then
        callback("player")
        local n = GetNumGroupMembers()
        for i = 1, n - 1 do
            callback("party" .. i)
        end
    else
        callback("player")
    end
end

-- Signature legere pour detecter un vrai changement (evite les rebuilds inutiles
-- sur les rafales d'evenements).
local function signature(members)
    local parts = {}
    for i = 1, #members do
        local m = members[i]
        parts[i] = (m.name or "?") .. ":" .. (m.class or "?") .. ":" .. (m.role or "?")
    end
    return table.concat(parts, "|")
end

function R:Rebuild()
    -- Garde-fou 12.1.0 : UnitClass et UnitGroupRolesAssigned renvoient desormais
    -- des valeurs "secretes" quand l'identite de l'unite est secrete en combat
    -- (mesure anti-automatisation, Patch 12.1.0/API changes). Les lire en combat
    -- corromprait le decompte classes/roles. L'audit etant un outil d'entree
    -- (avant le pull), on GELE simplement le roster tant qu'on est en combat et
    -- on conserve le dernier instantane fiable. Un rebuild propre est refait a la
    -- sortie de combat via PLAYER_REGEN_ENABLED. InCombatLockdown est une API
    -- stable de longue date : aucun identifiant nouveau ni incertain ici.
    if InCombatLockdown() then return end

    local previous = signature(self.members)
    local list = {}

    iterateUnits(function(unit)
        if UnitExists(unit) then
            local name = UnitName(unit)
            local _, classToken = UnitClass(unit)       -- 2e retour = jeton EN
            local role = UnitGroupRolesAssigned(unit)    -- TANK/HEALER/DAMAGER/NONE
            if name then
                table.insert(list, {
                    unit = unit,
                    name = name,
                    class = classToken,   -- peut etre nil si l'unite n'est pas prete
                    role = role or C.ROLE.NONE,
                })
            end
        end
    end)

    self.members = list
    self.size = #list

    if signature(list) ~= previous then
        LL:Emit("ROSTER_CHANGED", self.members, self.size)
    end
end

function R:GetMembers() return self.members end
function R:GetSize() return self.size end

-- Branchements. Les memes evenements alimentent detection et roster ; on debounce
-- pour ne rebuild qu'une fois par rafale.
local function wire()
    local rebuild = LL.util.Debounce(0.3, function() R:Rebuild() end)

    local f = CreateFrame("Frame", "LairLensRosterFrame")
    f:RegisterEvent("GROUP_ROSTER_UPDATE")
    f:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("UNIT_NAME_UPDATE")
    -- Rebuild fiable une fois le combat termine (les valeurs redeviennent lisibles).
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function() rebuild() end)

    LL:On("READY", function() R:Rebuild() end)
end

LL:On("DB_READY", wire)
