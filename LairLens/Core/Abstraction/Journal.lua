-- =============================================================================
-- LairLens - Core/Abstraction/Journal.lua  (7.1.5.37)
-- Lecture du Journal des rencontres du client : c'est lui qui donne, dans la
-- langue du joueur et sans rien deviner, le nom du Repaire, celui du boss,
-- l'identifiant du journal (jid), l'identifiant de rencontre (celui
-- d'ENCOUNTER_END) et l'instanceMapID (celui de GetInstanceInfo).
-- Resultat memorise dans LairLensDB.learned.journal[instanceKey].
--
-- Aussi : butin filtre par specialisation (EJ) et recherche des hauts faits.
-- On ne touche jamais au journal quand sa fenetre Blizzard est ouverte, et on
-- remet le palier (tier) selectionne comme on l'a trouve.
-- NON TESTE EN JEU : ordre des retours d'EJ_GetEncounterInfoByIndex et presence
-- du Repaire dans la liste des raids du palier Midnight a confirmer.
-- =============================================================================

local ADDON, LL = ...
local C = LL.const
local D = LL.Data
local U = LL.util

LL.Journal = {}
local J = LL.Journal

local function ejBusy()
    local f = _G.EncounterJournal
    return f and f.IsShown and f:IsShown()
end

local function store(instanceKey)
    local lrn = LL.db and LL.db.learned
    if not lrn then return nil end
    lrn.journal[instanceKey] = lrn.journal[instanceKey] or {}
    return lrn.journal[instanceKey]
end

function J:Get(instanceKey)
    local lrn = LL.db and LL.db.learned
    return lrn and lrn.journal and lrn.journal[instanceKey] or nil
end

-- Le Repaire correspond-il a cette instance du journal ? Nom replie ou boss.
local function matches(inst, jid, jname)
    local folded = U.Fold(jname)
    for _, n in ipairs(inst.matchNames or {}) do
        if folded == U.Fold(n) then return true end
    end
    if inst.bossFragment and type(EJ_GetEncounterInfoByIndex) == "function" then
        for i = 1, 4 do
            local ok, bname = pcall(EJ_GetEncounterInfoByIndex, i, jid)
            if not ok or not bname then break end
            if U.Fold(bname):find(inst.bossFragment, 1, true) then return true end
        end
    end
    return false
end

-- Remplit le magasin a partir d'un jid connu.
local function fill(instanceKey, jid)
    local s = store(instanceKey)
    if not s then return end
    s.jid = jid
    if type(EJ_GetInstanceInfo) == "function" then
        local ok, name = pcall(EJ_GetInstanceInfo, jid)
        if ok and type(name) == "string" and name ~= "" then s.name = name end
    end
    if type(EJ_GetEncounterInfoByIndex) == "function" then
        -- name, description, journalEncounterID, rootSectionID, link,
        -- journalInstanceID, dungeonEncounterID, instanceID
        local ok, bname, _, jeid, _, _, _, dungeonEncounterID, instanceID = pcall(EJ_GetEncounterInfoByIndex, 1, jid)
        if ok and bname then
            s.boss = bname
            s.journalEncounterID = tonumber(jeid)
            s.encounterID = tonumber(dungeonEncounterID)
            if tonumber(instanceID) and tonumber(instanceID) > 0 then
                s.instanceMapID = tonumber(instanceID)
                LL.db.learned.maps[s.instanceMapID] = instanceKey
            end
        end
    end
    s.at = time()
end

-- Parcourt les paliers du journal (du plus recent au plus ancien, 2 paliers
-- suffisent) a la recherche de chaque Repaire de Data.lua. Silencieux en cas
-- d'echec : la detection par nom et par la sonde reste en place.
function J:Discover(force)
    if not LL.db then return end
    if ejBusy() then return end
    if type(EJ_GetNumTiers) ~= "function" or type(EJ_SelectTier) ~= "function"
        or type(EJ_GetInstanceByIndex) ~= "function" then return end

    local todo = {}
    for key, inst in pairs(D:GetInstances("lair") or {}) do
        local s = self:Get(key)
        if force or not (s and s.jid and s.boss) then todo[key] = inst end
    end
    if not next(todo) then return end

    -- jid verifie en jeu dans Data.lua : lecture directe, sans parcourir les paliers.
    local direct = false
    for key, inst in pairs(todo) do
        if inst.journalInstanceID then
            fill(key, inst.journalInstanceID)
            todo[key] = nil
            direct = true
        end
    end
    if direct then LL:Emit("JOURNAL_READY") end
    if not next(todo) then return end

    local prevTier = type(EJ_GetCurrentTier) == "function" and EJ_GetCurrentTier() or nil
    local okTiers, nTiers = pcall(EJ_GetNumTiers)
    if not okTiers or not nTiers then return end

    local found = false
    for tier = nTiers, math.max(1, nTiers - 1), -1 do
        pcall(EJ_SelectTier, tier)
        for _, isRaid in ipairs({ true, false }) do
            for i = 1, 60 do
                local ok, jid, jname = pcall(EJ_GetInstanceByIndex, i, isRaid)
                if not ok or not jid then break end
                for key, inst in pairs(todo) do
                    if matches(inst, jid, jname) then
                        fill(key, jid)
                        todo[key] = nil
                        found = true
                    end
                end
            end
        end
        if not next(todo) then break end
    end
    if prevTier then pcall(EJ_SelectTier, prevTier) end
    if found then LL:Emit("JOURNAL_READY") end
end

-- Repli depuis l'interieur du Repaire : carte courante -> instance du journal.
function J:DiscoverFromMap(instanceKey)
    if not (instanceKey and C_Map and C_Map.GetBestMapForUnit and EJ_GetInstanceForMap) then return end
    local s = self:Get(instanceKey)
    if s and s.jid then return end
    local okM, uiMap = pcall(C_Map.GetBestMapForUnit, "player")
    if not okM or not uiMap then return end
    local okJ, jid = pcall(EJ_GetInstanceForMap, uiMap)
    if okJ and jid and jid > 0 then
        fill(instanceKey, jid)
        LL:Emit("JOURNAL_READY")
    end
end

-- -----------------------------------------------------------------------------
-- Butin. Renvoie une liste { itemID, name, link, icon, slot } ou nil si le
-- journal n'est pas disponible ; liste vide = le client charge encore (un
-- EJ_LOOT_DATA_RECIEVED suivra, on rafraichit alors la fiche).
-- -----------------------------------------------------------------------------
function J:GetLoot(instanceKey, difficultyKey, allSpecs)
    local s = self:Get(instanceKey)
    if not (s and s.jid) or ejBusy() then return nil end
    if type(EJ_SelectInstance) ~= "function" or type(EJ_GetNumLoot) ~= "function" then return nil end

    pcall(EJ_SelectInstance, s.jid)
    local info = D:GetDifficultyInfo(difficultyKey)
    if info and info.ejDiff and type(EJ_SetDifficulty) == "function" then
        pcall(EJ_SetDifficulty, info.ejDiff)
    end
    if type(EJ_SetLootFilter) == "function" then
        if allSpecs then
            pcall(EJ_SetLootFilter, 0, 0)
        else
            local _, _, classID = UnitClass("player")
            local specIndex = GetSpecialization and GetSpecialization()
            local specID = specIndex and GetSpecializationInfo and GetSpecializationInfo(specIndex) or 0
            pcall(EJ_SetLootFilter, classID or 0, specID or 0)
        end
    end

    local list = {}
    local okN, n = pcall(EJ_GetNumLoot)
    if not okN or not n then return list end
    for i = 1, n do
        local item
        if C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex then
            local ok, t = pcall(C_EncounterJournal.GetLootInfoByIndex, i)
            if ok and type(t) == "table" then item = t end
        end
        if item and (item.itemID or item.link) then
            list[#list + 1] = {
                itemID = item.itemID, name = item.name, link = item.link,
                icon = item.icon, slot = item.slot, armorType = item.armorType,
            }
        end
    end
    return list
end

-- -----------------------------------------------------------------------------
-- Hauts faits. Recherche une seule fois (puis memorisee) par nom ou description
-- contenant le nom du boss ou du Repaire, repartie sur plusieurs images pour ne
-- pas figer le jeu. callback(ids) a la fin.
-- -----------------------------------------------------------------------------
local scanning = false

-- Version de la recherche : 2 = categories de guilde incluses (VU EN JEU
-- 2026-10-03 : la v1 ne trouvait que 3 hauts faits sur 5, les deux versions
-- "groupe de guilde" etant rangees dans la categorie Guilde). Un cache plus
-- ancien est jete pour relancer la recherche une fois.
local ACH_SCAN_VERSION = 2

function J:GetAchievements(instanceKey)
    local lrn = LL.db and LL.db.learned
    if not lrn then return nil end
    if lrn.achScanVersion ~= ACH_SCAN_VERSION then
        lrn.achievements = {}
        lrn.achScanVersion = ACH_SCAN_VERSION
    end
    return lrn.achievements and lrn.achievements[instanceKey] or nil
end

function J:FindAchievements(instanceKey, callback)
    local cached = self:GetAchievements(instanceKey)
    if cached and #cached > 0 then if callback then callback(cached) end return end
    if scanning then return end
    if type(GetCategoryList) ~= "function" or type(GetCategoryNumAchievements) ~= "function"
        or type(GetAchievementInfo) ~= "function" then return end

    local inst = D:GetInstance("lair", instanceKey)
    if not inst then return end
    local needles = { inst.bossFragment }
    local s = self:Get(instanceKey)
    if s and s.boss then needles[#needles + 1] = U.Fold(s.boss) end
    if s and s.name then needles[#needles + 1] = U.Fold(s.name) end
    for _, n in ipairs(inst.matchNames or {}) do needles[#needles + 1] = U.Fold(n) end

    local okC, cats = pcall(GetCategoryList)
    if not okC or type(cats) ~= "table" then return end
    -- Categories de guilde : les hauts faits "groupe de guilde" y sont ranges.
    if type(GetGuildCategoryList) == "function" then
        local okG, gcats = pcall(GetGuildCategoryList)
        if okG and type(gcats) == "table" then
            local all = {}
            for _, c in ipairs(cats) do all[#all + 1] = c end
            for _, c in ipairs(gcats) do all[#all + 1] = c end
            cats = all
        end
    end

    scanning = true
    local found, seen = {}, {}
    local ci, ai = 1, 1
    local function step()
        local budget = 250
        while budget > 0 do
            local cat = cats[ci]
            if not cat then
                scanning = false
                table.sort(found)
                LL.db.learned.achievements[instanceKey] = found
                if callback then callback(found) end
                LL:Emit("ACHIEVEMENTS_READY", instanceKey)
                return
            end
            local okN, n = pcall(GetCategoryNumAchievements, cat, true)
            n = okN and tonumber(n) or 0
            if ai > n then
                ci, ai = ci + 1, 1
            else
                local ok, id, name, _, _, _, _, _, desc = pcall(GetAchievementInfo, cat, ai)
                if ok and id and not seen[id] then
                    seen[id] = true
                    local hay = U.Fold((name or "") .. " " .. (desc or ""))
                    for _, nd in ipairs(needles) do
                        if nd ~= "" and hay:find(nd, 1, true) then
                            found[#found + 1] = id
                            break
                        end
                    end
                end
                ai = ai + 1
            end
            budget = budget - 1
        end
        C_Timer.After(0, step)
    end
    step()
end

function J:IsScanning() return scanning end

-- --- Cablage -----------------------------------------------------------------
local function wire()
    -- Decouverte differee apres le login : le journal du client n'est pas
    -- toujours pret tout de suite.
    LL:On("READY", function()
        C_Timer.After(6, function() J:Discover() end)
    end)
    LL:On("LAIR_CONTEXT_CHANGED", function(ctx)
        if ctx and ctx.inLair and ctx.instanceKey then
            C_Timer.After(3, function() J:DiscoverFromMap(ctx.instanceKey) end)
        end
    end)
end

LL:On("DB_READY", wire)
