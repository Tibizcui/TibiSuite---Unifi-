local addonName, ns = ...
local C = ns.Const
local L = ns.L

-- ===========================================================================
-- Donnees de la fiche detaillee (clic gauche sur un nom). Une seule entree
-- "sheet:data" par perso, dans la fiche persistante, avec tab = "sheet" :
-- elle n'apparait dans AUCUNE colonne, seule UI/Sheet.lua la lit.
--
-- Tout vient de la sonde TibiProbe 0.5 (build 120100, 2026-09-26) :
--   - lien d'objet : champ 2 = enchantement, champs 3 a 6 = gemmes ;
--   - C_Item.GetItemNumSockets : nombre de chasses ;
--   - GetItemInfo, 16e retour = ensemble d'objets (compte les pieces) et
--     C_Item.GetItemSetInfo = son nom ; C_LootJournal.GetItemSetItems = pieces ;
--   - le RAID vient de l'ensemble de transmogrification de la piece
--     (C_TransmogCollection.GetItemInfo -> source -> GetSetsContainingSourceID :
--     label "La fleche du Vide", patchID 120000). On part de l'ensemble
--     d'objets, car une piece hors ensemble du meme raid a un autre ensemble
--     de transmo (bottes et ceinture de Tibizcui) ;
--   - GetCritChance / GetHaste / GetMasteryEffect / GetCombatRatingBonus(29).
-- ===========================================================================

-- Emplacements affiches, dans l'ordre de la fiche (colonne gauche puis droite).
ns.SHEET_SLOTS = {
    { id = 1,  key = "HEAD" },     { id = 2,  key = "NECK" },     { id = 3,  key = "SHOULDER" },
    { id = 15, key = "BACK" },     { id = 5,  key = "CHEST" },    { id = 9,  key = "WRIST" },
    { id = 16, key = "MAINHAND" }, { id = 17, key = "OFFHAND" },
    { id = 10, key = "HANDS" },    { id = 6,  key = "WAIST" },    { id = 7,  key = "LEGS" },
    { id = 8,  key = "FEET" },     { id = 11, key = "FINGER1" },  { id = 12, key = "FINGER2" },
    { id = 13, key = "TRINKET1" }, { id = 14, key = "TRINKET2" },
}

-- Emplacements enchantables en Midnight (valide par Tibiscui, 2026-09-26).
-- La main gauche ne l'est que si c'est une arme (pas un bouclier ni un
-- objet tenu en main gauche).
local ENCHANTABLE = { [1] = true, [3] = true, [5] = true, [7] = true, [8] = true,
                      [11] = true, [12] = true, [16] = true }
local WEAPON_CLASS = 2

local module = {
    key      = "sheet",
    labelKey = "ACTIVITY_SHEET",
    category = C.Category.CHARS,
    order    = 900,
    scope    = "snapshot",
    events   = { "PLAYER_EQUIPMENT_CHANGED", "PLAYER_AVG_ITEM_LEVEL_UPDATE",
                 "PLAYER_SPECIALIZATION_CHANGED", "CURRENCY_DISPLAY_UPDATE",
                 -- Talents : changement de talent, de build ou de configuration.
                 "TRAIT_CONFIG_UPDATED", "ACTIVE_COMBAT_CONFIG_CHANGED", "TRAIT_CONFIG_LIST_UPDATED" },
}

function module.IsAvailable()
    return type(GetInventoryItemLink) == "function"
end

-- "item:ID:enchant:gem1:gem2:gem3:gem4:..." -> enchantement et gemmes.
local function parseLink(link)
    local s = type(link) == "string" and link:match("item:([%-%d:]+)")
    if not s then return nil end
    local f = {}
    for v in (s .. ":"):gmatch("([%-%d]*):") do f[#f + 1] = tonumber(v) or 0 end
    return { itemID = f[1], enchant = f[2] or 0, gems = { f[3] or 0, f[4] or 0, f[5] or 0, f[6] or 0 } }
end

local function itemInfo(link)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if type(getInfo) ~= "function" then return nil end
    local ok, name, _, quality, _, _, _, _, _, _, icon, _, classID, _, _, expacID, setID = pcall(getInfo, link)
    if not ok then return nil end
    return { name = name, quality = quality, icon = icon, classID = classID, expacID = expacID, setID = setID }
end

local function numSockets(link)
    local f = C_Item and C_Item.GetItemNumSockets
    if type(f) ~= "function" then return 0 end
    local ok, n = pcall(f, link)
    return (ok and tonumber(n)) or 0
end

-- Raid, extension et patch d'un ensemble, via la transmogrification d'une
-- de ses pieces. On prefere l'ensemble de transmo qui porte le meme nom.
local function raidOfSet(link, setName)
    local TC, TS = C_TransmogCollection, C_TransmogSets
    if not (TC and TC.GetItemInfo and TS and TS.GetSetsContainingSourceID and TS.GetSetInfo) then return nil end
    local ok, _, sourceID = pcall(TC.GetItemInfo, link)
    if not ok or type(sourceID) ~= "number" then return nil end
    local okS, ids = pcall(TS.GetSetsContainingSourceID, sourceID)
    if not okS or type(ids) ~= "table" then return nil end
    local best
    for _, id in ipairs(ids) do
        local okI, info = pcall(TS.GetSetInfo, id)
        if okI and type(info) == "table" then
            if not best or info.name == setName then best = info end
            if info.name == setName then break end
        end
    end
    if not best then return nil end
    return { raid = best.label, patchID = tonumber(best.patchID), expansionID = tonumber(best.expansionID) }
end

local function collectGear()
    local slots, setCount, setLink = {}, {}, {}
    for _, s in ipairs(ns.SHEET_SLOTS) do
        local link = GetInventoryItemLink("player", s.id)
        if link then
            local p = parseLink(link) or { enchant = 0, gems = {} }
            local info = itemInfo(link) or {}
            local n = numSockets(link)
            local empty = 0
            for i = 1, n do
                if (p.gems[i] or 0) == 0 then empty = empty + 1 end
            end
            local enchantable = ENCHANTABLE[s.id] or (s.id == 17 and info.classID == WEAPON_CLASS)
            local track = ns.ItemTrack and ns.ItemTrack(link)
            local ilvl = ns.ItemLevelFromLink and ns.ItemLevelFromLink(link)
            slots[s.id] = {
                link = link, name = info.name, icon = info.icon, quality = info.quality,
                ilvl = ilvl, trackKey = track and track.key, trackColor = track and track.color,
                missingEnchant = (enchantable and p.enchant == 0) or nil,
                emptySockets = empty > 0 and empty or nil,
            }
            local setID = tonumber(info.setID)
            if setID and setID > 0 then
                setCount[setID] = (setCount[setID] or 0) + 1
                setLink[setID] = setLink[setID] or link
            end
        end
    end

    -- Ensemble de raid : celui dont on porte le plus de pieces (2 minimum),
    -- a egalite le plus recent. Un anneau d'ensemble isole n'est pas un
    -- ensemble de raid.
    local set
    for setID, n in pairs(setCount) do
        if n >= 2 then
            local name = C_Item and C_Item.GetItemSetInfo and C_Item.GetItemSetInfo(setID)
            local raid = raidOfSet(setLink[setID], name) or {}
            local total = 5
            if C_LootJournal and C_LootJournal.GetItemSetItems then
                local ok, items = pcall(C_LootJournal.GetItemSetItems, setID)
                if ok and type(items) == "table" and #items > 0 then total = #items end
            end
            local cand = { id = setID, name = name, count = n, total = total,
                           raid = raid.raid, patchID = raid.patchID, expansionID = raid.expansionID }
            if not set or n > set.count or (n == set.count and (cand.patchID or 0) > (set.patchID or 0)) then
                set = cand
            end
        end
    end
    return slots, set
end

local function collectStats()
    local function num(f, ...)
        if type(f) ~= "function" then return nil end
        local ok, v = pcall(f, ...)
        return ok and tonumber(v) or nil
    end
    local versaID = CR_VERSATILITY_DAMAGE_DONE or 29
    return {
        crit    = num(GetCritChance),
        haste   = num(GetHaste),
        mastery = num(GetMasteryEffect),
        versa   = (num(GetCombatRatingBonus, versaID) or 0) + (num(GetVersatilityBonus, versaID) or 0),
    }
end

-- Talents (sonde TibiProbe 0.6, lisibles des la connexion, sans ouvrir la
-- fenetre des talents) : arbre heroique actif, build charge (nom donne par
-- le joueur), code d'import officiel (~100 caracteres), talents heroiques
-- choisis et nombre des autres. "modified" : les talents actifs ne
-- correspondent plus au build enregistre (codes d'import differents).
local function spellNameAndIcon(def)
    local spellID = def and tonumber(def.spellID)
    local name = def and type(def.overrideName) == "string" and def.overrideName ~= "" and def.overrideName
    if spellID and C_Spell then
        name = name or (C_Spell.GetSpellName and C_Spell.GetSpellName(spellID))
        local icon = C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
        return spellID, name, icon
    end
    return spellID, name, nil
end

local function collectTalents()
    local CT, TR = C_ClassTalents, C_Traits
    if not (CT and TR and CT.GetActiveConfigID and TR.GetConfigInfo) then return nil end
    local ok, configID = pcall(CT.GetActiveConfigID)
    if not ok or type(configID) ~= "number" then return nil end
    local out = {}

    local function importString(id)
        if type(TR.GenerateImportString) ~= "function" then return nil end
        local okS, code = pcall(TR.GenerateImportString, id)
        return okS and type(code) == "string" and code ~= "" and code or nil
    end
    out.code = importString(configID)

    local specIdx = GetSpecialization and GetSpecialization()
    local specID = specIdx and GetSpecializationInfo and GetSpecializationInfo(specIdx)
    if specID and CT.GetLastSelectedSavedConfigID then
        local okL, savedID = pcall(CT.GetLastSelectedSavedConfigID, specID)
        if okL and type(savedID) == "number" then
            local okI, info = pcall(TR.GetConfigInfo, savedID)
            if okI and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
                out.build = info.name
            end
            local savedCode = importString(savedID)
            if out.code and savedCode and savedCode ~= out.code then out.modified = true end
        end
    end
    if CT.GetStarterBuildActive then
        local okB, starter = pcall(CT.GetStarterBuildActive)
        if okB and starter then out.starter = true end
    end

    -- Arbre heroique actif (nom + atlas officiel, ex. talents-heroclass-paladin-templar).
    local heroSub, selection = nil, {}
    if CT.GetActiveHeroTalentSpec and TR.GetSubTreeInfo then
        local okH, subTreeID = pcall(CT.GetActiveHeroTalentSpec)
        if okH and type(subTreeID) == "number" then
            local okT, sub = pcall(TR.GetSubTreeInfo, configID, subTreeID)
            if okT and type(sub) == "table" then
                out.hero = { id = subTreeID, name = sub.name, atlas = sub.iconElementID }
                heroSub = subTreeID
                for _, nodeID in ipairs(sub.subTreeSelectionNodeIDs or {}) do selection[nodeID] = true end
            end
        end
    end

    -- Talents choisis. Les noeuds de choix de l'arbre heroique ne comptent
    -- pas comme des talents ; ceux d'un arbre heroique inactif non plus.
    local okC, cinfo = pcall(TR.GetConfigInfo, configID)
    local treeID = okC and type(cinfo) == "table" and type(cinfo.treeIDs) == "table" and cinfo.treeIDs[1]
    if treeID and TR.GetTreeNodes and TR.GetNodeInfo then
        local okN, nodes = pcall(TR.GetTreeNodes, treeID)
        if okN and type(nodes) == "table" then
            local heroTalents, others = {}, 0
            for _, nodeID in ipairs(nodes) do
                local okI, node = pcall(TR.GetNodeInfo, configID, nodeID)
                if okI and type(node) == "table" and (tonumber(node.activeRank) or 0) > 0
                    and node.activeEntry and not selection[nodeID] then
                    if heroSub and node.subTreeID == heroSub then
                        local def
                        local okE, entry = pcall(TR.GetEntryInfo, configID, node.activeEntry.entryID)
                        if okE and type(entry) == "table" and entry.definitionID then
                            local okD, d = pcall(TR.GetDefinitionInfo, entry.definitionID)
                            if okD then def = d end
                        end
                        local spellID, name, icon = spellNameAndIcon(def)
                        heroTalents[#heroTalents + 1] = {
                            spellID = spellID, name = name, icon = icon,
                            rank = tonumber(node.activeRank), max = tonumber(node.maxRanks),
                            x = tonumber(node.posX) or 0, y = tonumber(node.posY) or 0,
                        }
                    elseif not node.subTreeID then
                        others = others + 1
                    end
                end
            end
            -- Ordre de l'arbre : de haut en bas, puis de gauche a droite.
            table.sort(heroTalents, function(a, b)
                if a.y ~= b.y then return a.y < b.y end
                return a.x < b.x
            end)
            out.heroTalents = heroTalents
            out.otherCount = others
        end
    end
    return out
end

-- Monnaies de la saison, liste pilotee par la donnee (Data/Activities.lua).
local function collectCurrencies()
    local out = {}
    local api = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo
    if type(api) ~= "function" then return out end
    for _, id in ipairs(ns.SheetCurrencies or {}) do
        local ok, info = pcall(api, id)
        if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
            out[#out + 1] = {
                id = id, name = info.name, icon = info.iconFileID,
                quantity = tonumber(info.quantity) or 0,
                max = tonumber(info.maxQuantity) or 0,
                earned = tonumber(info.totalEarned) or 0,
                useEarned = info.useTotalEarnedForMaxQty and true or nil,
            }
        end
    end
    return out
end

function module.Poll(emit)
    local slots, set = collectGear()
    if not next(slots) then return false end   -- inventaire pas encore charge : garder l'existant
    local _, raceFile, raceID = UnitRace("player")
    local raceName = UnitRace("player")
    emit({
        key = "sheet:data", tab = "sheet", status = C.Status.INFO,
        label = L["ACTIVITY_SHEET"],
        race = { name = raceName, file = raceFile, id = raceID },
        sex = UnitSex and UnitSex("player") or nil,
        className = UnitClass("player"),
        slots = slots,
        set = set,
        stats = collectStats(),
        currencies = collectCurrencies(),
        talents = collectTalents(),
    })
end

ns.Registry:Register(module)
