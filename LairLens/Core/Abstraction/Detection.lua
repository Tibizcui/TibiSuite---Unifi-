-- =============================================================================
-- LairLens - Core/Abstraction/Detection.lua
-- LE point unique de contact avec l'API d'instance, volontairement isole car
-- c'est la partie la plus incertaine (les Repaires sont neufs sur PTR).
--
-- Le reste de l'addon ne demande JAMAIS "suis-je dans un Repaire ?" au jeu
-- directement. Il appelle LL.Detection:GetContext(). Le jour ou Blizzard fige
-- les difficultyID / mapID des Repaires, on ne corrige que ce fichier.
-- =============================================================================

local ADDON, LL = ...
local C = LL.const
local D = LL.Data

LL.Detection = {}
local Det = LL.Detection

-- -----------------------------------------------------------------------------
-- Correspondances a completer depuis le PTR / Wowhead. Laissees vides plutot
-- qu'inventees : mieux vaut un "difficulte inconnue" honnete qu'un mauvais ID.
-- -----------------------------------------------------------------------------

-- difficultyID numerique (retour 3 de GetInstanceInfo) -> cle interne.
-- A REMPLIR quand les IDs des Repaires sont confirmes. Exemple de forme :
--   [220] = C.DIFF.NORMAL,
Det.DIFFICULTY_ID_TO_KEY = {
    -- volontairement vide : voir GetDifficultyKey pour le repli par nom.
}

-- instanceMapID connus des Repaires -> cle d'instance de Data.lua.
-- A REMPLIR quand les mapID sont confirmes. Exemple :
--   [2999] = "tidebound_grotto",
Det.MAP_ID_TO_INSTANCE = {
}

-- Repli heuristique : reconnaitre une difficulte par le libelle renvoye par le
-- client (difficultyName), insensible a la casse. Couvre les cas courants tant
-- que la table d'ID n'est pas remplie. On matche sur des fragments robustes.
local NAME_FRAGMENT_TO_KEY = {
    ["mythic"]   = C.DIFF.MYTHIC,   ["mythique"] = C.DIFF.MYTHIC,
    ["heroic"]   = C.DIFF.HEROIC,   ["heroique"] = C.DIFF.HEROIC,
    ["normal"]   = C.DIFF.NORMAL,
    ["world"]    = C.DIFF.WORLD,    ["monde"]    = C.DIFF.WORLD,
}

-- Etat courant memorise pour ne notifier que sur changement reel.
Det.context = {
    inLair = false,
    instanceKey = nil,
    difficultyKey = nil,
    groupSize = 0,
    maxPlayers = 0,
    rawDifficultyID = nil,
    rawInstanceType = nil,
    rawMapID = nil,
    confident = false, -- true si on a identifie le Repaire par mapID (pas heuristique)
}

-- Normalise une chaine pour comparaison souple.
local function normalize(s)
    if type(s) ~= "string" then return "" end
    return s:lower()
end

function Det:GetDifficultyKey(difficultyID, difficultyName)
    -- 1) mapping numerique explicite (ideal, une fois rempli depuis le PTR).
    local byID = self.DIFFICULTY_ID_TO_KEY[difficultyID]
    if byID then return byID, true end

    -- 2) repli par libelle. Honnete : marque comme non certain (confident=false).
    local name = normalize(difficultyName)
    for fragment, key in pairs(NAME_FRAGMENT_TO_KEY) do
        if name:find(fragment, 1, true) then
            return key, false
        end
    end
    return nil, false
end

-- Determine si l'instance courante est un Repaire.
-- Cascade, du plus fiable et locale-independant au plus pratique :
--   a) instanceMapID connu (Map.db2) -> certain, marche dans toutes les langues.
--      Table vide pour l'instant : l'ID reel n'est pas datamine publiquement.
--   b) sinon, correspondance par NOM d'instance (GetInstanceInfo renvoie le nom
--      localise). Fonctionne des maintenant sur les clients dont le nom figure
--      dans matchNames (enUS confirme). C'est le chemin actif aujourd'hui.
-- Aucun faux positif : on ne renvoie un Repaire que sur correspondance explicite.
function Det:ResolveInstance(instanceMapID, instanceName)
    local byMap = self.MAP_ID_TO_INSTANCE[instanceMapID]
    if byMap then return byMap, true end

    if instanceName and instanceName ~= "" then
        local target = instanceName:lower()
        local instances = D:GetInstances("lair") or {}
        for key, inst in pairs(instances) do
            if inst.matchNames then
                for _, n in ipairs(inst.matchNames) do
                    if target == n:lower() then return key, true end
                end
            end
        end
    end
    return nil, false
end

-- Recalcule le contexte depuis l'API et notifie si changement.
function Det:Refresh()
    local ctx = self.context
    local prevSignature = tostring(ctx.inLair) .. "|" ..
        tostring(ctx.instanceKey) .. "|" .. tostring(ctx.difficultyKey) .. "|" ..
        tostring(ctx.groupSize)

    -- GetInstanceInfo est stable et present sur tous les clients modernes.
    local name, instanceType, difficultyID, difficultyName,
          maxPlayers, _, _, instanceMapID, instanceGroupSize = GetInstanceInfo()

    ctx.rawInstanceType = instanceType
    ctx.rawDifficultyID = difficultyID
    ctx.rawMapID = instanceMapID
    ctx.maxPlayers = maxPlayers or 0
    ctx.groupSize = instanceGroupSize or 0

    local instanceKey, instanceConfident = self:ResolveInstance(instanceMapID, name)
    local diffKey, diffConfident = self:GetDifficultyKey(difficultyID, difficultyName)

    ctx.inLair = instanceKey ~= nil
    ctx.instanceKey = instanceKey
    ctx.difficultyKey = diffKey
    ctx.confident = instanceConfident and diffConfident

    local newSignature = tostring(ctx.inLair) .. "|" ..
        tostring(ctx.instanceKey) .. "|" .. tostring(ctx.difficultyKey) .. "|" ..
        tostring(ctx.groupSize)

    if newSignature ~= prevSignature then
        LL:Emit("LAIR_CONTEXT_CHANGED", ctx)
    end
end

-- API publique consommee par les modules.
function Det:GetContext()
    return self.context
end

function Det:IsInLair()
    return self.context.inLair
end

-- Branchements evenementiels. On rafraichit sur les transitions pertinentes,
-- avec un petit debounce pour absorber les rafales a l'entree d'instance.
local function wire()
    local refresh = LL.util.Debounce(0.3, function() Det:Refresh() end)

    local f = CreateFrame("Frame", "LairLensDetectionFrame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    f:RegisterEvent("GROUP_ROSTER_UPDATE")
    -- PLAYER_DIFFICULTY_CHANGED existe sur le client moderne ; protege au cas ou.
    pcall(f.RegisterEvent, f, "PLAYER_DIFFICULTY_CHANGED")
    f:SetScript("OnEvent", function() refresh() end)

    -- Premier calcul une fois la DB prete.
    LL:On("READY", function() Det:Refresh() end)
end

LL:On("DB_READY", wire)
