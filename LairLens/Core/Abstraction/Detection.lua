-- =============================================================================
-- LairLens - Core/Abstraction/Detection.lua
-- LE point unique de contact avec l'API d'instance. Le reste de l'addon ne
-- demande JAMAIS "suis-je dans un Repaire ?" au jeu directement : il appelle
-- LL.Detection:GetContext().
--
-- 12.1 live (7.1.5.37) : la detection ne depend plus de la langue.
--   Instance, du plus sur au plus large :
--     1) instanceMapID appris (LairLensDB.learned.maps) ou lu dans le journal ;
--     2) nom d'instance replie (accents, casse) contre les noms connus et le nom
--        localise du journal ;
--     3) C_DelvesUI.IsInLair() (vu dans l'API 12.1 par la sonde) hors Gouffre
--        actif, quand un seul Repaire existe.
--   Difficulte :
--     1) difficultyID appris ;
--     2) libelle du client replie, fragments dans les 10 langues ;
--     3) identifiants de raid flex standards (14/15/16) ;
--     4) scenario en cours = difficulte Monde (file solo en 2 parties).
--   Chaque correspondance trouvee par 2-4 est memorisee : au passage suivant,
--   c'est l'identifiant numerique qui decide.
-- NON TESTE EN JEU : a valider par Tibiscui (/ll probe dans la Grotte).
-- =============================================================================

local ADDON, LL = ...
local C = LL.const
local D = LL.Data
local U = LL.util

LL.Detection = {}
local Det = LL.Detection

-- Identifiants de raid flex standards (Normal 14, Heroique 15, Mythique 16).
-- Utilises seulement si le libelle n'a rien donne.
local STANDARD_DIFF = {
    [250] = C.DIFF.WORLD,   -- VERIFIE EN JEU (/ll probe 2026-10-03) : "Monde", raid 5-40
    [14] = C.DIFF.NORMAL,
    [15] = C.DIFF.HEROIC,
    [16] = C.DIFF.MYTHIC,
}

-- Fragments de libelle de difficulte, compares APRES repliement. Ordre
-- important : Mythique avant Heroique avant Normal avant Monde (un libelle
-- "Mythique" ne doit jamais tomber sur un autre fragment).
local DIFF_FRAGMENTS = {
    -- Cyrillique : U.Fold ne met pas en minuscules hors ASCII, d'ou des
    -- fragments sans la premiere lettre (majuscule dans le libelle du jeu).
    { C.DIFF.MYTHIC, { "myth", "mitic", "ифич", "похальн", "신화", "史诗", "傳奇" } },
    { C.DIFF.HEROIC, { "hero", "eroic", "ероич", "영웅", "英雄" } },
    { C.DIFF.NORMAL, { "normal", "бычн", "일반", "普通" } },
    { C.DIFF.WORLD,  { "world", "monde", "welt", "mundo", "mondo", "мир", "월드", "世界" } },
}

-- Etat courant memorise pour ne notifier que sur changement reel.
Det.context = {
    inLair = false,
    instanceKey = nil,
    difficultyKey = nil,
    groupSize = 0,
    maxPlayers = 0,
    rawDifficultyID = nil,
    rawDifficultyName = nil,
    rawInstanceType = nil,
    rawMapID = nil,
    rawName = nil,
    scenario = false,  -- difficulte Monde : scenario en 2 parties avant le boss
    how = nil,         -- "map" | "journal" | "name" | "api" : comment le Repaire a ete reconnu
    confident = false, -- true si instance ET difficulte viennent d'identifiants
}

local function learned()
    return LL.db and LL.db.learned
end

local function call(ns, fn, ...)
    local api = ns and ns[fn]
    if type(api) ~= "function" then return nil end
    local ok, v = pcall(api, ...)
    if ok then return v end
    return nil
end

-- --- Difficulte --------------------------------------------------------------
-- Renvoie cle, certitude (true = identifiant numerique deja appris/standard).
function Det:GetDifficultyKey(difficultyID, difficultyName)
    local lrn = learned()
    if lrn and difficultyID and lrn.diffs[difficultyID] then
        return lrn.diffs[difficultyID], true
    end

    local folded = U.Fold(difficultyName)
    if folded ~= "" then
        for _, entry in ipairs(DIFF_FRAGMENTS) do
            for _, frag in ipairs(entry[2]) do
                if folded:find(frag, 1, true) then
                    return entry[1], false
                end
            end
        end
    end

    if difficultyID and STANDARD_DIFF[difficultyID] then
        return STANDARD_DIFF[difficultyID], false
    end
    return nil, false
end

-- --- Instance ----------------------------------------------------------------
-- Renvoie cle, maniere ("map" | "journal" | "name" | "api").
function Det:ResolveInstance(instanceMapID, instanceName, instanceType)
    local lrn = learned()
    if instanceMapID and lrn and lrn.maps[instanceMapID] then
        return lrn.maps[instanceMapID], "map"
    end

    local instances = D:GetInstances("lair") or {}
    for key, inst in pairs(instances) do
        if instanceMapID and inst.instanceMapID == instanceMapID then return key, "map" end
        local j = lrn and lrn.journal and lrn.journal[key]
        if instanceMapID and j and j.instanceMapID == instanceMapID then return key, "journal" end
    end

    local target = U.Fold(instanceName)
    if target ~= "" then
        for key, inst in pairs(instances) do
            for _, n in ipairs(inst.matchNames or {}) do
                if target == U.Fold(n) then return key, "name" end
            end
            local j = lrn and lrn.journal and lrn.journal[key]
            if j and j.name and target == U.Fold(j.name) then return key, "name" end
        end
    end

    -- C_DelvesUI.IsInLair : VU EN JEU (/ll probe 2026-10-03) vrai dans la
    -- Grotte, ou HasActiveDelve est AUSSI vrai (on ne peut donc pas s'en servir
    -- pour ecarter les Gouffres). Un Repaire est une instance de type "raid",
    -- un Gouffre un "scenario" : c'est ce critere qui departage. Utilise
    -- seulement s'il n'existe qu'un seul Repaire (sinon on ne saurait pas lequel).
    if instanceType == "raid" and call(C_DelvesUI, "IsInLair") == true then
        local only = D:GetSingleLair()
        if only then return only, "api" end
    end
    return nil, nil
end

local function signature(ctx)
    return tostring(ctx.inLair) .. "|" .. tostring(ctx.instanceKey) .. "|" ..
        tostring(ctx.difficultyKey) .. "|" .. tostring(ctx.groupSize) .. "|" .. tostring(ctx.scenario)
end

-- Recalcule le contexte depuis l'API et notifie si changement.
function Det:Refresh()
    local ctx = self.context
    local prev = signature(ctx)
    local wasIn = ctx.inLair

    local name, instanceType, difficultyID, difficultyName,
          maxPlayers, _, _, instanceMapID, instanceGroupSize = GetInstanceInfo()

    ctx.rawName = name
    ctx.rawInstanceType = instanceType
    ctx.rawDifficultyID = difficultyID
    ctx.rawDifficultyName = difficultyName
    ctx.rawMapID = instanceMapID
    ctx.maxPlayers = maxPlayers or 0
    ctx.groupSize = instanceGroupSize or 0

    local instanceKey, how
    if instanceType and instanceType ~= "none" then
        instanceKey, how = self:ResolveInstance(instanceMapID, name, instanceType)
    end

    local inScenario = instanceType == "scenario"
        or (C_Scenario and C_Scenario.IsInScenario and call(C_Scenario, "IsInScenario") == true) or false

    local diffKey, diffConfident
    if instanceKey then
        diffKey, diffConfident = self:GetDifficultyKey(difficultyID, difficultyName)
        if not diffKey and (inScenario or call(C_DelvesUI, "HasActiveLFGLair") == true) then
            diffKey = C.DIFF.WORLD
        end
        -- Apprentissage : la prochaine fois, l'identifiant numerique suffira.
        local lrn = learned()
        if lrn then
            if instanceMapID and instanceMapID > 0 and how ~= "map" then
                lrn.maps[instanceMapID] = instanceKey
            end
            if diffKey and difficultyID and difficultyID > 0 and not diffConfident then
                lrn.diffs[difficultyID] = diffKey
            end
        end
    end

    ctx.inLair = instanceKey ~= nil
    ctx.instanceKey = instanceKey
    ctx.difficultyKey = diffKey
    ctx.scenario = ctx.inLair and inScenario or false
    ctx.how = how
    ctx.confident = (how == "map" or how == "journal") and diffConfident or false

    if ctx.inLair and not wasIn and LL.Probe then
        -- Capture automatique a chaque entree : la sonde sert de rapport si
        -- quelque chose cloche, sans que le joueur ait a y penser.
        C_Timer.After(2, function() LL.Probe:Capture("auto") end)
    end

    if signature(ctx) ~= prev then
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
    pcall(f.RegisterEvent, f, "PLAYER_DIFFICULTY_CHANGED")
    pcall(f.RegisterEvent, f, "SCENARIO_UPDATE")
    f:SetScript("OnEvent", function() refresh() end)

    -- Premier calcul une fois la DB prete.
    LL:On("READY", function() Det:Refresh() end)
    -- Le journal a revele un identifiant : on recalcule (utile si on est deja dedans).
    LL:On("JOURNAL_READY", function() Det:Refresh() end)
end

LL:On("DB_READY", wire)
