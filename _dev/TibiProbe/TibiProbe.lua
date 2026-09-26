-- ===========================================================================
-- TibiProbe : sonde JETABLE, jamais publiee.
--
-- But : repondre a deux questions avant d'ecrire du vrai code.
--   1. Logement : existe-t-il une API pour LIRE les decors poses dans une
--      maison (pas seulement le catalogue) ? Condition de l'idee "vitrine".
--   2. WeeklyCompass : quels identifiants reels (monnaies, factions, quetes
--      hebdo, evenements) alimentent Gouffres, Traque et Repaires ?
--   3. WeeklyCompass gestionnaire d'alts : niveau d'objet, cle M+, score, or,
--      verrouillages, metiers, specialisation (releve auto a chaque connexion).
--
-- Tout est ecrit dans TibiProbeDB (WTF\Account\<compte>\SavedVariables\
-- TibiProbe.lua), que Claude relit apres un /reload. Rien n'est modifie en jeu.
--
-- Commandes :
--   /tprobe            aide
--   /tprobe scan       inventaire API + monnaies + factions + journal de quetes
--   /tprobe alts       releve gestionnaire d'alts du perso courant (auto au login)
--   /tprobe house X    appelle les getters sans argument du Logement, rangees
--                      sous l'etiquette X (ex : "dedans", "dehors")
--   /tprobe events     evenements interessants vus depuis le chargement
-- ===========================================================================

local PREFIX = "|cffC41F3BTibiProbe|r "
local function say(fmt, ...) print(PREFIX .. fmt:format(...)) end

-- Mots-cles (en minuscules) qui rendent un namespace ou un evenement interessant.
local KEYWORDS = {
    "hous", "decor", "neighbo", "catalog", "endeavor", "initiative",
    "delve", "prey", "hunt", "lair", "weekly", "vault", "majorfaction",
    "renown", "bounty", "coffer",
}

local function interesting(name)
    local s = name:lower()
    for _, k in ipairs(KEYWORDS) do
        if s:find(k, 1, true) then return true end
    end
    return false
end

-- Getters juges surs : lecture seule, aucun effet de bord par leur nom.
local SAFE_PREFIX = { "Get", "Is", "Has", "Can", "Are", "Does" }
local UNSAFE_WORDS = {
    "Request", "Set", "Save", "Clear", "Delete", "Remove", "Place", "Purchase",
    "Buy", "Teleport", "Visit", "Enter", "Leave", "Start", "Stop", "Open",
    "Close", "Toggle", "Create", "Send", "Accept", "Decline", "Confirm",
}

local function isSafeGetter(fname)
    local ok = false
    for _, p in ipairs(SAFE_PREFIX) do
        if fname:sub(1, #p) == p then ok = true break end
    end
    if not ok then return false end
    for _, w in ipairs(UNSAFE_WORDS) do
        if fname:find(w, 1, true) then return false end
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Instantane serialisable : WoW ne sait sauver que nombres, chaines, booleens
-- et tables. Les valeurs secretes (12.x) ne sont jamais lues, juste signalees.
-- ---------------------------------------------------------------------------
local isSecret = _G.issecretvalue or function() return false end

local function snap(v, depth)
    if isSecret(v) then return "<secret>" end
    local t = type(v)
    if t == "number" or t == "boolean" then return v end
    if t == "string" then
        if #v <= 200 then return v end
        -- Coupe sans casser un caractere UTF-8 (octets de continuation 0x80-0xBF).
        local cut = 200
        while cut > 1 and v:byte(cut + 1) and v:byte(cut + 1) >= 0x80 and v:byte(cut + 1) < 0xC0 do
            cut = cut - 1
        end
        return v:sub(1, cut) .. "..."
    end
    if t ~= "table" then return "<" .. t .. ">" end
    depth = depth or 0
    if depth >= 4 then return "<table>" end
    local out, n = {}, 0
    for k, val in pairs(v) do
        local kt = type(k)
        if (kt == "string" or kt == "number") and not isSecret(k) then
            n = n + 1
            if n > 40 then out["..."] = "tronque" break end
            out[k] = snap(val, depth + 1)
        end
    end
    return out
end

local function packResults(ok, ...)
    if not ok then return { error = tostring((...)) } end
    local n = select("#", ...)
    if n == 0 then return { ret = "<rien>" } end
    local res = {}
    for i = 1, math.min(n, 8) do
        res[i] = snap((select(i, ...)))
    end
    res.n = n
    return res
end

local function context()
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local inInstance, instanceType = IsInInstance()
    return {
        time     = date("%Y-%m-%d %H:%M:%S"),
        build    = select(4, GetBuildInfo()),
        zone     = GetZoneText(),
        subzone  = GetSubZoneText(),
        mapID    = mapID,
        instance = inInstance and instanceType or "none",
        char     = (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?"),
    }
end

-- ---------------------------------------------------------------------------
-- 1. Inventaire des namespaces C_* (noms seuls, + fonctions des interessants)
-- ---------------------------------------------------------------------------
local function scanNamespaces()
    local all, detail = {}, {}
    for name, ns in pairs(_G) do
        if type(name) == "string" and name:sub(1, 2) == "C_" and type(ns) == "table" then
            all[#all + 1] = name
            if interesting(name) then
                local fns = {}
                for fname, f in pairs(ns) do
                    if type(f) == "function" then fns[#fns + 1] = fname end
                end
                table.sort(fns)
                detail[name] = fns
            end
        end
    end
    table.sort(all)
    return all, detail
end

-- ---------------------------------------------------------------------------
-- 2. Monnaies : balayage d'identifiants (les monnaies Midnight sont > 3000).
-- On garde celles qui ont un sens pour ce perso ou un plafond hebdomadaire.
-- ---------------------------------------------------------------------------
local function scanCurrencies()
    local out = {}
    if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return out end
    for id = 2800, 3900 do
        local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
        if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
            local q  = tonumber(info.quantity) or 0
            local mw = tonumber(info.maxWeeklyQuantity) or 0
            local ew = tonumber(info.quantityEarnedThisWeek) or 0
            if info.discovered or q > 0 or mw > 0 or ew > 0 then
                out[id] = {
                    name = info.name, quantity = q, maxQuantity = info.maxQuantity,
                    maxWeekly = mw, earnedWeek = ew, discovered = info.discovered,
                    useTotalEarnedForMaxQty = info.useTotalEarnedForMaxQty,
                    totalEarned = info.totalEarned,
                }
            end
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- 3. Factions majeures (renom) : la Traque passe peut-etre par la.
-- ---------------------------------------------------------------------------
local function scanMajorFactions()
    local out = {}
    local MF = C_MajorFactions
    if not (MF and MF.GetMajorFactionIDs and MF.GetMajorFactionData) then return out end
    local seen = {}
    local function add(list)
        if type(list) ~= "table" then return end
        for _, id in ipairs(list) do
            if not seen[id] then
                seen[id] = true
                local ok, data = pcall(MF.GetMajorFactionData, id)
                out[id] = ok and snap(data) or { error = tostring(data) }
            end
        end
    end
    local ok, list = pcall(MF.GetMajorFactionIDs)
    if ok then add(list) end
    for exp = 9, 13 do
        local ok2, l2 = pcall(MF.GetMajorFactionIDs, exp)
        if ok2 then add(l2) end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- 4. Journal de quetes : titres, ID et frequence (reperer les hebdos Traque).
-- ---------------------------------------------------------------------------
local function scanQuestLog()
    local out = {}
    local QL = C_QuestLog
    if not (QL and QL.GetNumQuestLogEntries and QL.GetInfo) then return out end
    for i = 1, QL.GetNumQuestLogEntries() do
        local info = QL.GetInfo(i)
        if info and not info.isHeader and info.questID then
            out[#out + 1] = {
                id = info.questID, title = info.title, frequency = info.frequency,
                isTask = info.isTask, isHidden = info.isHidden,
                campaignID = info.campaignID,
            }
        end
    end
    return out
end

local function scanVault()
    if not (C_WeeklyRewards and C_WeeklyRewards.GetActivities) then return nil end
    local ok, acts = pcall(C_WeeklyRewards.GetActivities)
    return ok and snap(acts) or { error = tostring(acts) }
end

-- ---------------------------------------------------------------------------
-- 5. Logement : appel de chaque getter sans argument des namespaces Logement.
-- Ceux qui exigent un argument echouent proprement (pcall) : leur message
-- d'erreur dit souvent quel argument est attendu, c'est deja une info.
-- ---------------------------------------------------------------------------
local HOUSING_NS = { "hous", "decor", "neighbo", "catalog", "endeavor", "initiative" }

local function isHousingNS(name)
    local s = name:lower()
    for _, k in ipairs(HOUSING_NS) do
        if s:find(k, 1, true) then return true end
    end
    return false
end

local function callHousingGetters()
    local out, calls = {}, 0
    for name, ns in pairs(_G) do
        if type(name) == "string" and name:sub(1, 2) == "C_" and type(ns) == "table" and isHousingNS(name) then
            local res = {}
            for fname, f in pairs(ns) do
                if type(f) == "function" and isSafeGetter(fname) then
                    calls = calls + 1
                    res[fname] = packResults(pcall(f))
                end
            end
            out[name] = res
        end
    end
    return out, calls
end

-- ---------------------------------------------------------------------------
-- 5 bis. Decors poses : LA question de l'idee "vitrine". Le filtre de securite
-- ci-dessus ecarte tout nom contenant "Place", donc GetAllPlacedDecor et
-- GetNumDecorPlaced n'avaient jamais ete appeles. On les teste ici un par un,
-- sans argument puis avec la piece ou se trouve le joueur, et on detaille les
-- 5 premiers decors trouves.
-- ---------------------------------------------------------------------------
local function probeDecor()
    local HD, HL = C_HousingDecor, C_HousingLayout
    local out = {}
    if not HD then return { error = "C_HousingDecor absent" } end

    local room = HL and HL.GetRoomPlayerIsIn and HL.GetRoomPlayerIsIn()
    out.room = snap(room)
    local function try(label, f, ...)
        if type(f) ~= "function" then out[label] = "<absent>" return nil end
        local ok, a, b, c = pcall(f, ...)
        if not ok then
            out[label] = { error = tostring(a) }
            return nil
        end
        out[label] = { snap(a), snap(b), snap(c) }
        return a
    end

    try("GetNumDecorPlaced", HD.GetNumDecorPlaced)
    try("GetSpentPlacementBudget", HD.GetSpentPlacementBudget)
    try("GetMaxPlacementBudget", HD.GetMaxPlacementBudget)
    try("GetAllSpentPlacementBudgets", HD.GetAllSpentPlacementBudgets)
    try("GetAllMaxPlacementBudgets", HD.GetAllMaxPlacementBudgets)
    if room then try("AnyDecorPlacedInRoom(room)", HD.AnyDecorPlacedInRoom, room) end

    local list = try("GetAllPlacedDecor()", HD.GetAllPlacedDecor)
    if type(list) ~= "table" and room then
        list = try("GetAllPlacedDecor(room)", HD.GetAllPlacedDecor, room)
    end

    if type(list) == "table" then
        local n = 0
        for _ in pairs(list) do n = n + 1 end
        out.placedCount = n
        local samples, i = {}, 0
        for _, entry in pairs(list) do
            i = i + 1
            if i > 5 then break end
            local s = { raw = snap(entry) }
            local guid = type(entry) == "string" and entry
                or (type(entry) == "table" and (entry.decorGUID or entry.guid))
            if guid and HD.GetDecorInstanceInfoForGUID then
                s.instance = packResults(pcall(HD.GetDecorInstanceInfoForGUID, guid))
            end
            local id = type(entry) == "table" and (entry.decorID or entry.id)
            if id and HD.GetDecorName then
                s.name = packResults(pcall(HD.GetDecorName, id))
                s.link = packResults(pcall(HD.GetDecorHyperlink, id))
            end
            samples[i] = s
        end
        out.samples = samples
    end
    return out
end

-- ---------------------------------------------------------------------------
-- 5 ter. Gestionnaire d'alts (WeeklyCompass phase 0) : quelles API donnent
-- niveau d'objet, cle M+, score, or, verrouillages, metiers, specialisation ?
-- Une entree par perso dans TibiProbeDB.alts["Nom - Royaume"] : se connecter
-- sur plusieurs rerolls accumule les releves sans rien ecraser.
--
-- Cle et verrouillages demandent une requete serveur prealable (RequestMapInfo,
-- RequestRaidInfo) : lancee a l'entree en jeu, lue quelques secondes plus tard.
-- ---------------------------------------------------------------------------

-- Presence de chaque fonction attendue, sans l'appeler.
local ALT_APIS = {
    "GetAverageItemLevel", "GetMoney", "UnitLevel", "GetXPExhaustion", "GetRestState",
    "GetSpecialization", "GetSpecializationInfo", "GetProfessions", "GetProfessionInfo",
    "RequestRaidInfo", "GetNumSavedInstances", "GetSavedInstanceInfo",
    "GetSavedInstanceEncounterInfo", "GetNumSavedWorldBosses", "GetSavedWorldBossInfo",
    "C_MythicPlus.RequestMapInfo", "C_MythicPlus.GetOwnedKeystoneChallengeMapID",
    "C_MythicPlus.GetOwnedKeystoneLevel", "C_MythicPlus.GetOwnedKeystoneMapID",
    "C_MythicPlus.GetCurrentSeason", "C_MythicPlus.GetRunHistory",
    "C_ChallengeMode.GetOverallDungeonScore", "C_ChallengeMode.GetMapUIInfo",
    "C_PlayerInfo.GetPlayerMythicPlusRatingSummary",
    "C_WeeklyRewards.HasAvailableRewards", "C_WeeklyRewards.CanClaimRewards",
    "C_WeeklyRewards.AreRewardsForCurrentRewardPeriod",
    "C_Bank.FetchDepositedMoney", "C_TradeSkillUI.GetConcentrationCurrencyID",
    "C_TradeSkillUI.GetProfessionInfoBySkillLineID",
}

local function resolve(path)
    local v = _G
    for part in path:gmatch("[^%.]+") do
        if type(v) ~= "table" then return nil end
        v = v[part]
    end
    return v
end

-- Appel protege d'une API par son chemin ; absente => "<absent>".
local function call(path, ...)
    local f = resolve(path)
    if type(f) ~= "function" then return "<absent>" end
    return packResults(pcall(f, ...))
end

local function altRequests()
    if C_MythicPlus and C_MythicPlus.RequestMapInfo then pcall(C_MythicPlus.RequestMapInfo) end
    if RequestRaidInfo then pcall(RequestRaidInfo) end
end

local function probeLockouts()
    local out = { instances = {}, worldBosses = {} }
    local ok, n = pcall(GetNumSavedInstances)
    out.numSaved = ok and snap(n) or { error = tostring(n) }
    if ok and type(n) == "number" then
        for i = 1, math.min(n, 30) do
            local row = { info = packResults(pcall(GetSavedInstanceInfo, i)) }
            -- Detail des boss sur les 3 premieres seulement (format a valider).
            if i <= 3 then
                local enc = {}
                for j = 1, 12 do
                    local r = packResults(pcall(GetSavedInstanceEncounterInfo, i, j))
                    if r.error or r[1] == nil then break end
                    enc[j] = r
                end
                row.encounters = enc
            end
            out.instances[i] = row
        end
    end
    local okW, nW = pcall(GetNumSavedWorldBosses)
    if okW and type(nW) == "number" then
        for i = 1, math.min(nW, 10) do
            out.worldBosses[i] = packResults(pcall(GetSavedWorldBossInfo, i))
        end
    end
    return out
end

local function probeKeystone()
    local out = {
        challengeMapID = call("C_MythicPlus.GetOwnedKeystoneChallengeMapID"),
        level          = call("C_MythicPlus.GetOwnedKeystoneLevel"),
        mapID          = call("C_MythicPlus.GetOwnedKeystoneMapID"),
        season         = call("C_MythicPlus.GetCurrentSeason"),
        overallScore   = call("C_ChallengeMode.GetOverallDungeonScore"),
        ratingSummary  = call("C_PlayerInfo.GetPlayerMythicPlusRatingSummary", "player"),
    }
    local cm = out.challengeMapID
    if type(cm) == "table" and type(cm[1]) == "number" then
        out.mapInfo = call("C_ChallengeMode.GetMapUIInfo", cm[1])
    end
    -- Historique de la semaine : on ne garde que le nombre et le 1er element.
    local f = resolve("C_MythicPlus.GetRunHistory")
    if type(f) == "function" then
        local ok, runs = pcall(f, false, true)
        if ok and type(runs) == "table" then
            out.weekRuns = { count = #runs, first = snap(runs[1]) }
        else
            out.weekRuns = { error = tostring(runs) }
        end
    end
    return out
end

local function probeProfessions()
    local out = {}
    local ok, p1, p2, arch, fish, cook = pcall(GetProfessions)
    if not ok then return { error = tostring(p1) } end
    out.indices = { p1 = p1, p2 = p2, arch = arch, fish = fish, cook = cook }
    for label, idx in pairs(out.indices) do
        if type(idx) == "number" then
            local info = packResults(pcall(GetProfessionInfo, idx))
            local row = { info = info }
            -- 7e retour = skillLine : on tente la concentration dessus.
            local skillLine = info[7]
            if type(skillLine) == "number" then
                row.bySkillLine   = call("C_TradeSkillUI.GetProfessionInfoBySkillLineID", skillLine)
                row.concentration = call("C_TradeSkillUI.GetConcentrationCurrencyID", skillLine)
            end
            out[label] = row
        end
    end
    return out
end

local function doAlts()
    -- db() est declare plus bas : on passe directement par la SavedVariable.
    TibiProbeDB = TibiProbeDB or {}
    local d = TibiProbeDB
    d.alts = d.alts or {}
    local present = {}
    for _, path in ipairs(ALT_APIS) do
        present[path] = type(resolve(path)) == "function"
    end
    local specIdx = type(GetSpecialization) == "function" and GetSpecialization()
    local accountBank = Enum and Enum.BankType and Enum.BankType.Account

    local key = (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?")
    d.alts[key] = {
        context       = context(),
        inCombat      = InCombatLockdown(),
        apis          = present,
        class         = snap(select(2, UnitClass("player"))),
        level         = call("UnitLevel", "player"),
        itemLevel     = call("GetAverageItemLevel"),
        money         = call("GetMoney"),
        warbandMoney  = accountBank and call("C_Bank.FetchDepositedMoney", accountBank) or "<enum absent>",
        restXP        = call("GetXPExhaustion"),
        restState     = call("GetRestState"),
        spec          = specIdx and call("GetSpecializationInfo", specIdx) or "<aucune>",
        keystone      = probeKeystone(),
        lockouts      = probeLockouts(),
        professions   = probeProfessions(),
        vaultClaim    = {
            hasAvailable = call("C_WeeklyRewards.HasAvailableRewards"),
            canClaim     = call("C_WeeklyRewards.CanClaimRewards"),
            currentPeriod = call("C_WeeklyRewards.AreRewardsForCurrentRewardPeriod"),
        },
        vault         = scanVault(),
    }
    local missing = 0
    for _, ok in pairs(present) do if not ok then missing = missing + 1 end end
    say("alts [%s] : releve fait, %d API absentes sur %d. /reload pour ecrire.",
        key, missing, #ALT_APIS)
end

-- ---------------------------------------------------------------------------
-- 6. Evenements : on ecoute TOUT, on ne garde que des compteurs par nom.
-- Aucun argument d'evenement n'est lu (valeurs secretes en 12.x).
-- ---------------------------------------------------------------------------
local eventCounts = {}
local listener = CreateFrame("Frame")
listener:RegisterAllEvents()
listener:SetScript("OnEvent", function(_, event)
    eventCounts[event] = (eventCounts[event] or 0) + 1
end)

-- ---------------------------------------------------------------------------
-- Commandes et persistance
-- ---------------------------------------------------------------------------
local function db()
    TibiProbeDB = TibiProbeDB or {}
    TibiProbeDB.house = TibiProbeDB.house or {}
    return TibiProbeDB
end

local function doScan()
    local d = db()
    local all, detail = scanNamespaces()
    local nCur, nFac = 0, 0
    local cur = scanCurrencies()
    for _ in pairs(cur) do nCur = nCur + 1 end
    local fac = scanMajorFactions()
    for _ in pairs(fac) do nFac = nFac + 1 end
    local quests = scanQuestLog()

    d.scan = {
        context        = context(),
        namespaces     = all,
        interestingAPI = detail,
        currencies     = cur,
        majorFactions  = fac,
        questLog       = quests,
        vault          = scanVault(),
    }
    local nDetail = 0
    for _ in pairs(detail) do nDetail = nDetail + 1 end
    say("scan : %d namespaces C_ (%d interessants), %d monnaies, %d factions, %d quetes.",
        #all, nDetail, nCur, nFac, #quests)
    say("Fais /reload pour ecrire le fichier, puis previens Claude.")
end

local function doHouse(label)
    label = (label and label ~= "") and label or "sans-etiquette"
    local d = db()
    local res, calls = callHousingGetters()
    d.house[label] = { context = context(), calls = res }
    say("logement [%s] : %d getters appeles. /reload pour ecrire.", label, calls)
end

local function doDecor()
    local d = db()
    local res = probeDecor()
    d.decor = { context = context(), result = res }
    say("decor : %s decors lus. Deconnecte-toi pour ecrire le fichier.",
        tostring(res.placedCount or "aucun"))
end

local function doEvents()
    local list = {}
    for ev, n in pairs(eventCounts) do
        if interesting(ev) then list[#list + 1] = { ev = ev, n = n } end
    end
    table.sort(list, function(a, b) return a.n > b.n end)
    say("%d evenements interessants vus :", #list)
    for i = 1, math.min(#list, 25) do
        print(("   %s x%d"):format(list[i].ev, list[i].n))
    end
end

-- Au logout (et donc au /reload), on sauve tous les compteurs d'evenements.
local saver = CreateFrame("Frame")
saver:RegisterEvent("PLAYER_LOGOUT")
saver:RegisterEvent("PLAYER_ENTERING_WORLD")
saver:SetScript("OnEvent", function(self, event, isLogin, isReload)
    if event == "PLAYER_LOGOUT" then
        local d = db()
        d.events = d.events or {}
        for ev, n in pairs(eventCounts) do
            d.events[ev] = (d.events[ev] or 0) + n
        end
    elseif isLogin or isReload then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        altRequests()
        C_Timer.After(8, function()
            doScan()
            doAlts()
        end)
    end
end)

SLASH_TIBIPROBE1 = "/tprobe"
local PROBE_VERSION = "0.4"

local function dispatch(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    if cmd == "scan" then
        doScan()
    elseif cmd == "house" then
        doHouse(rest)
    elseif cmd == "events" then
        doEvents()
    elseif cmd == "decor" then
        doDecor()
    elseif cmd == "alts" then
        altRequests()
        say("alts : requetes envoyees, releve dans 3 s.")
        C_Timer.After(3, doAlts)
    else
        say("v%s : /tprobe scan | /tprobe alts | /tprobe house <etiquette> | /tprobe decor | /tprobe events",
            PROBE_VERSION)
    end
end

-- Toute erreur est affichee dans le chat : les erreurs Lua sont masquees par
-- defaut en jeu, une commande qui "ne fait rien" ne dit sinon pas pourquoi.
SlashCmdList["TIBIPROBE"] = function(msg)
    local ok, err = pcall(dispatch, msg)
    if not ok then
        say("|cffff5555erreur :|r %s", tostring(err))
        local d = db()
        d.lastError = { time = date("%Y-%m-%d %H:%M:%S"), cmd = msg, err = tostring(err) }
    end
end
