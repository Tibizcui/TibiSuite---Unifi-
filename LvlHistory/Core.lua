-- Core.lua
-- LvlHistory — Init, events globaux, sessions, donjons, gouffres, quetes, niveaux
-- Auteur : Tibizcui | Famille : TibiSuite

LvlHistory = LvlHistory or {}
local T = LvlHistory
LvlHistory.L = LvlHistory.L or {}
local L = LvlHistory.L
local function Loc(key, default) return L[key] or default end

-- ─────────────────────────────────────────────
-- Constantes
-- ─────────────────────────────────────────────
local ADDON_VERSION = "7.1.5.41"
local SAVE_INTERVAL = 300  -- sauvegarde incrémentale toutes les 5 minutes
local RESUME_WINDOW = 600  -- /reload ou reconnexion en moins de 10 min : meme session
T.VERSION = ADDON_VERSION

-- Structure par défaut d'un personnage. Tout ajout ici est complete sur les
-- anciennes sauvegardes par FillDefaults (jamais d'ecrasement).
local CHAR_DEFAULTS = {
    mode      = "leveling",
    level     = 1,
    class     = "",
    sessions  = {},
    zones        = {},
    dgnRuns      = {},          -- { ["Nom Donjon"] = count } — total persistant
    dgnDetails   = {},          -- { ["Nom||Difficulte"] = count } — détail persistant
    dgnBestKey   = {},          -- { ["Nom Donjon"] = highestKeyLevel } — meilleure clé M+
    dgnBestTime  = {},          -- { ["Nom Donjon"] = { key=N, ms=N } } — meilleur temps sur la plus haute clé timée
    dgnMapID     = {},          -- { ["Nom Donjon"] = mapChallengeModeID } — lien direct vers les records Blizzard
    dgnLog       = {},          -- [ { name, diff, ts } ] — historique individuel persistant
    delveRuns    = {},          -- { ["Nom Gouffre"] = count }
    delveBest    = {},          -- { ["Nom Gouffre"] = palier max }
    delveLog     = {},          -- [ { name, tier, ts } ]
    levelLog     = {},          -- { [niveau] = { t = s de jeu passees a ce niveau, at = fin, partial = true|nil } }
    xpSrc        = { quest = 0, dungeon = 0, delve = 0, other = 0 },  -- XP a vie par origine
    totalPlayTime = 0,          -- secondes cumulées toutes sessions (persistant)
    _dgn         = {            -- état du run de donjon en cours (survit aux reloads)
        inInstance   = false,
        zoneName     = "",
        bossKills    = 0,
        countedByLFG = false,
        diffName     = "",      -- difficulté mémorisée au premier boss kill
    },
    quests    = { total = 0, daily = 0, weekly = 0, list = {} },
    farming   = { gold = 0, goldPerHour = 0, rep = {}, currencies = {} },
    session   = {},
}

-- Structure par défaut de LvlHistoryDB
local DB_DEFAULTS = {
    version  = 2,
    chars    = {},
    settings = {
        maxStoredSessions = 500,
        minimapButton     = true,
        minimapAngle      = 220,
        sessionAlert      = true,
        levelAlert        = true,   -- message a chaque niveau (temps passe au niveau)
        resumeSession     = true,   -- un /reload ne coupe pas la session
        debug             = false,
        alpha             = 0.97,   -- opacite du frame principal (0.3 - 1.0)
        collapsed         = false,  -- etat reduit persistant
    },
}

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

local function GetCharKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

-- Niveau max REEL du compte : un compte sans la derniere extension plafonne
-- plus bas que GetMaxPlayerLevel(). Repli sur l'ancienne API si absente.
function T.MaxLevel()
    if GetMaxLevelForPlayerExpansion then
        local ok, v = pcall(GetMaxLevelForPlayerExpansion)
        if ok and type(v) == "number" and v > 0 then return v end
    end
    return GetMaxPlayerLevel()
end

local function FillDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = type(v) == "table" and CopyTable(v) or v
        elseif type(v) == "table" and type(dst[k]) == "table" and k ~= "_dgn" then
            -- sous-tables a champs fixes (xpSrc, quests...) : complete les cles manquantes
            if next(v) ~= nil and v[1] == nil then FillDefaults(dst[k], v) end
        end
    end
end

local function InitChar()
    local key = GetCharKey()
    LvlHistoryDB.chars = LvlHistoryDB.chars or {}

    local c = LvlHistoryDB.chars[key]
    if not c then
        c = CopyTable(CHAR_DEFAULTS)
        LvlHistoryDB.chars[key] = c
    end
    FillDefaults(c, CHAR_DEFAULTS)
    c.level = UnitLevel("player")
    c.class = select(2, UnitClass("player")) or c.class
    c.name  = UnitName("player")
    c.realm = GetRealmName()
    c.lastSeen = time()
    return c
end

-- Contexte de jeu courant, pour l'origine de l'XP : "dungeon", "delve" ou "world".
function T.CurrentContext()
    local inInst, instType = IsInInstance()
    if not inInst then return "world" end
    if instType == "party" then return "dungeon" end
    if instType == "scenario" then
        local delve = false
        if C_DelvesUI then
            local ok, v = pcall(function()
                return (C_DelvesUI.HasActiveDelve and C_DelvesUI.HasActiveDelve())
                    or (C_DelvesUI.IsInLair and C_DelvesUI.IsInLair())
            end)
            delve = ok and v and true or false
        end
        if not delve then
            local _, _, diffID = GetInstanceInfo()
            delve = (diffID == 208)   -- 208 = difficulte "Gouffre"
        end
        if delve then return "delve" end
    end
    return "world"
end

-- XP reposee du personnage connecte, memorisee pour l'estimation hors ligne
-- de la vue Alts (le jeu ne donne l'XP reposee que du perso connecte).
function T.SnapshotRested()
    local db = T.db
    if not db then return end
    db.rested = {
        xp = UnitXP("player"), max = UnitXPMax("player"),
        rest = GetXPExhaustion() or 0, at = time(),
        resting = IsResting() and true or false,
    }
end

-- Estimation de l'XP reposee d'un perso (live pour le perso connecte).
-- Regle de jeu : +5 % d'un niveau par tranche de 8 h a l'auberge (ou en
-- ville), un quart de ce rythme ailleurs, plafond 150 % d'un niveau.
-- Renvoie restXP, fraction d'un niveau, plafonne (bool) ; nil si inconnu.
function T.EstimateRested(c, isCurrent)
    if isCurrent then
        local max = UnitXPMax("player")
        if not max or max <= 0 then return nil end
        local r = GetXPExhaustion() or 0
        return r, r / max, r >= max * 1.5 - 1
    end
    local r = c and c.rested
    if not r or not r.max or r.max <= 0 then return nil end
    local hours = math.max(0, time() - (r.at or time())) / 3600
    local rate  = r.resting and 0.05 or 0.0125
    local cap   = r.max * 1.5
    local est   = math.min(cap, (r.rest or 0) + r.max * rate * hours / 8)
    return est, est / r.max, est >= cap - 1
end

-- ─────────────────────────────────────────────
-- Sessions
-- ─────────────────────────────────────────────

local function NewSession(db)
    local now = time()
    db.session = {
        startTime      = now,
        lastTick       = now,
        goldAtStart    = GetMoney(),
        levelStart     = UnitLevel("player"),
        zone           = GetRealZoneText() or "Unknown",
        zoneEnteredAt  = now,
        zoneIsInstance = IsInInstance() and true or false,
        questCount     = 0,
        dailyCount     = 0,
        dungeons       = 0,
        delves         = 0,
        xph            = 0,
        xpGain         = 0,
        xpSrc          = { quest = 0, dungeon = 0, delve = 0, other = 0 },
    }
    -- Rep et monnaies : la base reste, les gains repartent de zero
    for _, r in pairs(db.farming.rep or {}) do r.gained = 0; r.perHour = 0; r.stale = true end
    for _, cu in pairs(db.farming.currencies or {}) do cu.gained = 0 end
    db.farming.goldEarned  = 0
    db.farming.gold        = 0
    db.farming.goldPerHour = 0
end

-- Accumule le temps de jeu (crash-safe) SANS toucher a la session courante.
-- Appele periodiquement : n'insere aucun snapshot, ne reinitialise pas startTime.
-- On solde le delta ecoule depuis le dernier tick pour eviter tout double comptage.
-- Alimente aussi l'horloge du niveau en cours (chronologie des niveaux).
local function AccruePlayTime()
    local db = T.db
    if not db then return end

    local now   = time()
    local last  = db.session.lastTick or db.session.startTime or now
    local delta = now - last
    if delta > 0 then
        db.totalPlayTime = (db.totalPlayTime or 0) + delta
        local clk = db.levelClock
        if clk and clk.level == UnitLevel("player") then
            clk.t = (clk.t or 0) + delta
        end
    end
    db.session.lastTick = now
end
T.AccruePlayTime = AccruePlayTime

-- Ajoute le temps passe dans la zone courante a db.zones (hors instances).
local function FlushZone()
    local db = T.db
    if not db then return end
    local s = db.session
    local zone = s.zone
    local wasInstance = s.zoneIsInstance or (db.dgnRuns and db.dgnRuns[zone] ~= nil)
    if zone and zone ~= "" and not wasInstance then
        local elapsed = time() - (s.zoneEnteredAt or s.startTime or time())
        if elapsed > 0 then db.zones[zone] = (db.zones[zone] or 0) + elapsed end
    end
    s.zoneEnteredAt = time()
end

local function BuildSnapshot()
    local db = T.db
    if not db then return nil end
    local s = db.session
    local elapsed = time() - (s.startTime or time())
    if elapsed < 60 then return nil end
    local src = s.xpSrc or {}
    local goldEarned = db.farming.goldEarned or 0
    return {
        date       = s.startTime,
        mode       = db.mode,
        duration   = elapsed,
        zone       = s.zone,
        xpGained   = s.xpGain or 0,
        xph        = s.xph or 0,
        levelStart = s.levelStart or db.level,
        levelEnd   = UnitLevel("player"),
        quests     = s.questCount or 0,
        dungeons   = s.dungeons or 0,
        delves     = s.delves or 0,
        goldGained = math.max(0, GetMoney() - (s.goldAtStart or GetMoney())),
        goldEarned = goldEarned > 0 and goldEarned or nil,   -- gains bruts (mode farming)
        xpSrc      = (s.xpGain or 0) > 0 and {
            q = src.quest or 0, d = src.dungeon or 0, g = src.delve or 0, o = src.other or 0,
        } or nil,
    }
end

local function PushSnapshot(snapshot)
    local db = T.db
    if not (db and snapshot) then return end
    local sessions = db.sessions
    while #sessions >= LvlHistoryDB.settings.maxStoredSessions do
        table.remove(sessions, 1)
    end
    table.insert(sessions, snapshot)
    T.Bridge.Emit("onSessionEnd", snapshot)
end

-- Enregistre un snapshot de la session courante puis la redemarre proprement.
-- Appele en fin de session reelle : switch de mode (niveau max atteint).
local function SaveCurrentSession()
    local db = T.db
    if not db then return end
    AccruePlayTime()
    FlushZone()
    PushSnapshot(BuildSnapshot())
    NewSession(db)
end

-- ─────────────────────────────────────────────
-- Chronologie des niveaux
-- ─────────────────────────────────────────────

local function EnsureLevelClock(db)
    local lvl = UnitLevel("player")
    if lvl >= T.MaxLevel() then db.levelClock = nil; return end
    local clk = db.levelClock
    if not clk or clk.level ~= lvl then
        -- Niveau deja entame avant le suivi (install, ou monte sans l'addon) :
        -- son temps sera incomplet, on le marque.
        db.levelClock = { level = lvl, t = 0, partial = true }
    end
end

local function OnLevelReached(db, newLevel)
    AccruePlayTime()
    local clk = db.levelClock
    local spent
    if clk and clk.level == newLevel - 1 then
        spent = clk.t or 0
        db.levelLog[clk.level] = { t = spent, at = time(), partial = clk.partial or nil }
    end
    if newLevel < T.MaxLevel() then
        db.levelClock = { level = newLevel, t = 0 }
    else
        db.levelClock = nil
    end
    T.SnapshotRested()

    if spent and LvlHistoryDB.settings.levelAlert ~= false then
        local U = T.Utils
        local msg = string.format(Loc("LEVEL_UP_FMT", "Niveau %d atteint : %s de jeu au niveau %d."),
            newLevel, U.FormatTime(spent, true), newLevel - 1)
        if clk.partial then msg = msg .. " " .. Loc("LEVEL_UP_PARTIAL", "(suivi partiel)") end
        print(U.Colorize("[LvlHistory]", "5EE223") .. " " .. msg)
    end
    T.Bridge.Emit("onLevelUp", newLevel, spent)
end

-- ─────────────────────────────────────────────
-- Mode
-- ─────────────────────────────────────────────

local function SetMode(db, resume)
    local isMax = UnitLevel("player") >= T.MaxLevel()
    local oldMode = db.mode
    db.mode  = isMax and "farming" or "leveling"
    db.level = UnitLevel("player")

    T.Farming.StartRep(resume)
    if isMax then
        T.Farming.Start(resume)
    else
        T.Leveling.Start(resume)
    end

    if oldMode ~= db.mode then
        T.Bridge.Emit("onModeSwitch", oldMode, db.mode)
    end
end

-- ─────────────────────────────────────────────
-- Quetes (tous modes)
-- ─────────────────────────────────────────────

-- Frequence captee a l'ouverture de la fenetre de recompense : apres
-- QUEST_TURNED_IN la quete a deja quitte le journal, on ne peut plus la lire.
local questFreq = {}

local function FreqFromLog(questID)
    if not (C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetInfo) then return nil end
    local ok, f = pcall(function()
        local idx = C_QuestLog.GetLogIndexForQuestID(questID)
        local info = idx and C_QuestLog.GetInfo(idx)
        return info and info.frequency
    end)
    if not ok or not f then return nil end
    local QF = Enum and Enum.QuestFrequency
    if QF and f == QF.Daily then return "d" end
    if QF and f == QF.Weekly then return "w" end
    if f == 1 then return "d" elseif f == 2 then return "w" end
    return nil
end

local function OnQuestComplete()
    local qid = GetQuestID and GetQuestID()
    if not qid or qid == 0 then return end
    if QuestIsDaily and QuestIsDaily() then questFreq[qid] = "d"
    elseif QuestIsWeekly and QuestIsWeekly() then questFreq[qid] = "w"
    else questFreq[qid] = FreqFromLog(qid) end
end

local function OnQuestTurnIn(questID, xpReward)
    local db = T.db
    if not db then return end

    db.quests.total       = (db.quests.total or 0) + 1
    db.session.questCount = (db.session.questCount or 0) + 1

    local freq = questID and (questFreq[questID] or FreqFromLog(questID))
    if questID then questFreq[questID] = nil end
    local isDaily = (freq == "d")
    if isDaily then
        db.quests.daily = (db.quests.daily or 0) + 1
        db.session.dailyCount = (db.session.dailyCount or 0) + 1
    elseif freq == "w" then
        db.quests.weekly = (db.quests.weekly or 0) + 1
    end

    if db.mode == "leveling" and T.Leveling.OnQuestXP then
        T.Leveling.OnQuestXP(tonumber(xpReward) or 0)
    end

    T.Bridge.Emit("onQuestTurnIn", questID, isDaily, freq == "w")
    T.Utils.Log("Quete rendue (ID: %s, %s) | Total: %d", tostring(questID), tostring(freq), db.quests.total)
end

-- ─────────────────────────────────────────────
-- Frame principale & events
-- ─────────────────────────────────────────────
local coreFrame = CreateFrame("Frame", "LvlHistoryCoreFrame", UIParent)

coreFrame:RegisterEvent("PLAYER_LOGIN")
coreFrame:RegisterEvent("PLAYER_LOGOUT")
coreFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
coreFrame:RegisterEvent("PLAYER_LEVEL_UP")
coreFrame:RegisterEvent("PLAYER_UPDATE_RESTING")
coreFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
coreFrame:RegisterEvent("QUEST_COMPLETE")
coreFrame:RegisterEvent("QUEST_TURNED_IN")
coreFrame:RegisterEvent("ADDON_LOADED")   -- Rattrapage LoadOnDemand (voir plus bas)

local function OnLogin()
    -- Init défensive : ne jamais écraser des données existantes
    LvlHistoryDB = LvlHistoryDB or CopyTable(DB_DEFAULTS)
    LvlHistoryDB.settings = LvlHistoryDB.settings or CopyTable(DB_DEFAULTS.settings)
    FillDefaults(LvlHistoryDB.settings, DB_DEFAULTS.settings)
    LvlHistoryDB.version = math.max(LvlHistoryDB.version or 1, DB_DEFAULTS.version)

    local db = InitChar()
    T.db      = db
    T.charKey = GetCharKey()
    T.debug   = LvlHistoryDB.settings.debug

    -- Session : reprise apres un /reload (ou une reconnexion rapide), sinon
    -- la session precedente, mise de cote au logout, est enfin archivee.
    local now = time()
    local s   = db.session or {}
    local resume = LvlHistoryDB.settings.resumeSession ~= false
        and s.savedAt and s.startTime and s.startTime > 0
        and (now - s.savedAt) <= RESUME_WINDOW
        and s.levelStart ~= nil
    if resume then
        local gap = math.max(0, now - s.savedAt)
        -- Le temps hors jeu ne compte ni dans la duree, ni dans l'XP/h
        s.startTime     = s.startTime + gap
        s.zoneEnteredAt = (s.zoneEnteredAt or now) + gap
        s.lastTick      = now
        s.savedAt       = nil
        s.zone          = GetRealZoneText() or s.zone
        s.zoneIsInstance = IsInInstance() and true or false
        db.pendingSnap  = nil
        s.xpSrc = s.xpSrc or { quest = 0, dungeon = 0, delve = 0, other = 0 }
    else
        if db.pendingSnap then
            PushSnapshot(db.pendingSnap)
            db.pendingSnap = nil
        end
        NewSession(db)
    end

    -- Migration : supprimer de db.zones les noms qui correspondent à des donjons connus
    -- (données enregistrées avant l'ajout du filtre zoneIsInstance)
    for dgnName in pairs(db.dgnRuns) do
        if db.zones[dgnName] then
            db.zones[dgnName] = nil
            T.Utils.Log("Zone purgee (instance detectee) : %s", dgnName)
        end
    end

    -- Réconciliation après reload : si on était dans une instance et qu'on n'y est plus,
    -- le run peut avoir été complété entre le logout et le reload
    if db._dgn.inInstance then
        local inInst = IsInInstance()
        if not inInst then
            local d = db._dgn
            if not d.countedByLFG and (d.bossKills or 0) > 0 and (d.zoneName or "") ~= "" then
                C_Timer.After(0, function()
                    if T.RecordDungeon then T.RecordDungeon(d.zoneName, d.diffName ~= "" and d.diffName or nil) end
                end)
            end
            T.DgnReset()
        end
        -- Si toujours dans l'instance : on garde l'état pour continuer le run
    end

    EnsureLevelClock(db)
    T.SnapshotRested()

    -- Démarrer le bon mode
    SetMode(db, resume)

    -- Bouton minimap
    T.Minimap.Init()

    -- Accumulation incrémentale du temps de jeu toutes les 5 minutes (crash-safe).
    -- N'insère PAS de snapshot : le snapshot n'est créé qu'en fin de session réelle.
    C_Timer.NewTicker(SAVE_INTERVAL, function()
        AccruePlayTime()
        if T.API and T.API.WriteDashboard then T.API.WriteDashboard() end
    end)

    T.Utils.Log("v%s chargé - %s - Mode: %s%s", ADDON_VERSION, T.charKey, db.mode, resume and " (session reprise)" or "")
    -- Message de connexion : court, et masque quand le core TibiSuite gere un
    -- message unique de suite ("one" / "none").
    local tdb = _G.TibiSuiteDB
    local loginMsg = type(tdb) == "table" and tdb.loginMsg or "full"
    if loginMsg == "full" or not (_G.TibiSuite and _G.TibiSuite.RegisterModule) then
        print("|cFF5EE223LvlHistory|r v" .. ADDON_VERSION .. " " .. Loc("LOGIN_LOADED", "chargé -- tapez") .. " |cFFFFD700/lvlh|r " .. Loc("LOGIN_TO_OPEN", "pour ouvrir."))
    end
end

-- Fin de session "douce" : on NE pousse PAS le snapshot tout de suite. Il est
-- mis de cote et n'est archive qu'a la prochaine connexion si l'absence a
-- depasse RESUME_WINDOW : un /reload ne fragmente plus l'historique.
local function OnLogout()
    local db = T.db
    if not db then return end
    AccruePlayTime()
    FlushZone()
    T.SnapshotRested()
    db.lastSeen = time()
    db.pendingSnap = BuildSnapshot()
    db.session.savedAt = time()
    if T.API and T.API.WriteDashboard then T.API.WriteDashboard() end
end

coreFrame:SetScript("OnEvent", function(self, event, ...)
    -- Rattrapage LoadOnDemand : en chargement a la demande, PLAYER_LOGIN est
    -- deja passe quand TibiSuite active ce module, donc la branche PLAYER_LOGIN
    -- ci-dessous ne se declencherait jamais. Quand notre propre addon finit de
    -- charger (tous ses fichiers sont alors en memoire) et que la connexion est
    -- deja effective, on rejoue exactement le meme travail de login.
    if event == "ADDON_LOADED" then
        if (...) == "LvlHistory" and IsLoggedIn() and not T.db then
            event = "PLAYER_LOGIN"
        else
            return
        end
    end

    if event == "PLAYER_LOGIN" then
        OnLogin()
        return
    end

    local db = T.db
    if not db then return end

    if event == "PLAYER_LEAVING_WORLD" then
        -- Arrive avant PLAYER_LOGOUT pour TOUS les addons : le resume Dashboard
        -- est donc a jour quand Stats genere son code d'export au logout.
        AccruePlayTime()
        if T.API and T.API.WriteDashboard then T.API.WriteDashboard() end

    elseif event == "PLAYER_LOGOUT" then
        OnLogout()

    elseif event == "PLAYER_UPDATE_RESTING" then
        T.SnapshotRested()

    elseif event == "ZONE_CHANGED_NEW_AREA" then
        FlushZone()
        local s = db.session
        s.zone           = GetRealZoneText() or "Unknown"
        s.zoneEnteredAt  = time()
        s.zoneIsInstance = IsInInstance() and true or false
        T.Utils.Log("Zone: %s%s", s.zone, s.zoneIsInstance and " [instance]" or "")
        if T.UI and T.UI.MarkDirty then T.UI.MarkDirty() end

    elseif event == "QUEST_COMPLETE" then
        OnQuestComplete()

    elseif event == "QUEST_TURNED_IN" then
        OnQuestTurnIn(...)

    elseif event == "PLAYER_LEVEL_UP" then
        local newLevel = ...
        newLevel = tonumber(newLevel) or UnitLevel("player")
        db.level = newLevel
        OnLevelReached(db, newLevel)

        if newLevel >= T.MaxLevel() and db.mode ~= "farming" then
            -- Solde l'XP du dernier niveau avant de figer la session de leveling
            if T.Leveling.Flush then T.Leveling.Flush() end
            T.Leveling.Stop()
            SaveCurrentSession()
            local oldMode = db.mode
            db.mode = "farming"
            T.Farming.Start()
            T.Bridge.Emit("onModeSwitch", oldMode, "farming")

            if LvlHistoryDB.settings.sessionAlert then
                print(T.Utils.Colorize("[LvlHistory]", "5EE223")
                    .. " " .. Loc("MAX_LEVEL_REACHED", "Niveau maximum atteint : passage en mode FARMING"))
            end
        end
    end
end)

-- ─────────────────────────────────────────────
-- Tracking donjons (mode-agnostic)
-- Couvre : LFD (N/H/M), Mythic+ et groupes manuels
-- ─────────────────────────────────────────────

-- Accesseur sécurisé vers l'état persisté du run en cours
-- db._dgn est dans les SavedVariables — survit aux /reload
local function Dgn()
    return T.db and T.db._dgn
end

function T.DgnReset()
    if T.db then
        T.db._dgn = {
            inInstance = false, zoneName = "", bossKills = 0, countedByLFG = false, diffName = "",
        }
    end
end

local function GetDifficultyLabel()
    -- GetInstanceInfo() : name, type, difficultyID, difficultyName, ...
    local _, _, _, diffName = GetInstanceInfo()
    if not diffName or diffName == "" then return "?" end
    return diffName
end

function T.RecordDungeon(name, diffName)
    local db = T.db
    if not db then return end
    if not name or name == "" then return end

    diffName = diffName or GetDifficultyLabel()

    -- Total toutes difficultés
    db.dgnRuns[name]    = (db.dgnRuns[name] or 0) + 1
    db.session.dungeons = (db.session.dungeons or 0) + 1

    -- Détail par difficulté : clé "Nom||Difficulte"
    local detailKey = name .. "||" .. diffName
    db.dgnDetails[detailKey] = (db.dgnDetails[detailKey] or 0) + 1

    -- Log individuel (persistant entre sessions, plus recent en dernier)
    table.insert(db.dgnLog, { name = name, diff = diffName, ts = time() })
    while #db.dgnLog > 1000 do table.remove(db.dgnLog, 1) end

    T.Bridge.Emit("onDungeonCompleted", name, db.dgnRuns[name], diffName)
    T.Utils.Log("Donjon: %s [%s] | Total: %d", name, diffName, db.dgnRuns[name])
end

-- Lecture de la fin d'une cle M+. API 11.0+ : GetChallengeCompletionInfo()
-- renvoie une TABLE ; l'ancienne GetCompletionInfo() (valeurs multiples :
-- mapID, level, time, onTime) n'est gardee qu'en repli.
local function ReadChallengeCompletion()
    local CM = C_ChallengeMode
    if not CM then return nil end
    if CM.GetChallengeCompletionInfo then
        local ok, info = pcall(CM.GetChallengeCompletionInfo)
        if ok and type(info) == "table" then
            return info.mapChallengeModeID, info.level, info.time, info.onTime, info.practiceRun
        end
    end
    if CM.GetCompletionInfo then
        local ok, mapID, level, ms, onTime = pcall(CM.GetCompletionInfo)
        if ok then return mapID, level, ms, onTime end
    end
    return nil
end

-- ─────────────────────────────────────────────
-- Gouffres (Delves) : fin de scenario dans un gouffre actif. Meme
-- detection que Stats (SCENARIO_COMPLETED + C_DelvesUI), pas de compteur
-- natif de Blizzard. Palier : lu pendant le gouffre (plus fiable qu'a la fin).
-- ─────────────────────────────────────────────
local cachedDelveTier

local function ReadDelveTier()
    if not (C_DelvesUI and C_DelvesUI.GetActiveDelveTier) then return nil end
    local ok, t = pcall(C_DelvesUI.GetActiveDelveTier)
    if ok and type(t) == "number" and t > 0 then return t end
    return nil
end

local function RecordDelve()
    local db = T.db
    if not db then return end
    local name = GetSubZoneText and GetSubZoneText()
    if not name or name == "" then name = GetRealZoneText() or "?" end
    local tier = ReadDelveTier() or cachedDelveTier
    cachedDelveTier = nil

    db.delveRuns[name]  = (db.delveRuns[name] or 0) + 1
    db.session.delves   = (db.session.delves or 0) + 1
    if tier and tier > (db.delveBest[name] or 0) then db.delveBest[name] = tier end
    table.insert(db.delveLog, { name = name, tier = tier, ts = time() })
    while #db.delveLog > 500 do table.remove(db.delveLog, 1) end

    T.Bridge.Emit("onDelveCompleted", name, tier, db.delveRuns[name])
    T.Utils.Log("Gouffre: %s palier %s | Total: %d", name, tostring(tier), db.delveRuns[name])
end

local dgnFrame = CreateFrame("Frame", "LvlHistoryDgnFrame", UIParent)
dgnFrame:RegisterEvent("LFG_COMPLETION_REWARD")    -- LFD : N / H / M group finder
dgnFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED") -- Mythic+
dgnFrame:RegisterEvent("ENCOUNTER_END")            -- tout boss (groupes manuels)
dgnFrame:RegisterEvent("PLAYER_ENTERING_WORLD")    -- détection sortie d'instance
dgnFrame:RegisterEvent("SCENARIO_COMPLETED")       -- gouffres
dgnFrame:RegisterEvent("SCENARIO_CRITERIA_UPDATE") -- palier du gouffre en cours

dgnFrame:SetScript("OnEvent", function(self, event, ...)
    if not T.db then return end

    -- ── LFD (Chercheur de donjon) ──────────────────────────────────────────
    -- Aussi envoye pour le RdR et certains scenarios : on ne compte que les
    -- vrais donjons a 5.
    if event == "LFG_COMPLETION_REWARD" then
        local inInst, instType = IsInInstance()
        if not inInst or instType ~= "party" then return end
        local d = Dgn()
        if d and d.countedByLFG then return end
        T.RecordDungeon(GetRealZoneText() or "")
        if d then d.countedByLFG = true end

    -- ── Mythic+ ────────────────────────────────────────────────────────────
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        local db = T.db
        -- Nom = texte de zone, comme pour les autres difficultes (meme cle dans
        -- dgnRuns) ; le mapID est garde a part pour les records Blizzard.
        local zoneName = GetRealZoneText() or ""
        local mapID, keyLevel, ms, onTime, practice = ReadChallengeCompletion()
        if (zoneName == "") and mapID and C_ChallengeMode.GetMapUIInfo then
            zoneName = C_ChallengeMode.GetMapUIInfo(mapID) or ""
        end
        if zoneName == "" then return end
        if mapID then db.dgnMapID[zoneName] = mapID end
        if not practice and keyLevel and keyLevel > 0 then
            if keyLevel > (db.dgnBestKey[zoneName] or 0) then
                db.dgnBestKey[zoneName] = keyLevel
            end
            -- Meilleur temps : uniquement si la clé est timée
            if onTime and ms and ms > 0 then
                local cur = db.dgnBestTime[zoneName]
                if not cur or keyLevel > (cur.key or 0)
                    or (keyLevel == cur.key and ms < (cur.ms or math.huge)) then
                    db.dgnBestTime[zoneName] = { key = keyLevel, ms = ms }
                end
            end
        end
        local d = Dgn()
        if d and d.countedByLFG then return end
        -- Libelle neutre "M+" : le nom Blizzard de la difficulte varie selon
        -- la langue et ne contient pas toujours de "+".
        T.RecordDungeon(zoneName, "M+")
        if d then d.countedByLFG = true end

    -- ── Groupes manuels : boss tué avec succès ─────────────────────────────
    elseif event == "ENCOUNTER_END" then
        local success = select(5, ...)
        if success ~= 1 and success ~= true then return end

        local inInst, instType = IsInInstance()
        if not inInst or instType ~= "party" then return end

        local d = Dgn()
        if not d then return end

        -- Persisté dans db._dgn → survit au /reload
        d.inInstance = true
        d.zoneName   = GetRealZoneText() or d.zoneName
        d.bossKills  = (d.bossKills or 0) + 1
        -- Mémoriser la difficulté au premier boss (elle ne change pas en cours de run)
        if not d.diffName or d.diffName == "" then
            d.diffName = GetDifficultyLabel()
        end

    -- ── Gouffres ───────────────────────────────────────────────────────────
    elseif event == "SCENARIO_CRITERIA_UPDATE" then
        if T.CurrentContext() == "delve" then
            cachedDelveTier = ReadDelveTier() or cachedDelveTier
        end

    elseif event == "SCENARIO_COMPLETED" then
        if T.CurrentContext() == "delve" then RecordDelve() end

    -- ── Transition de zone / sortie d'instance ─────────────────────────────
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...

        -- Au reload/login : PLAYER_LOGIN gère la réconciliation via db._dgn persisté.
        if isInitialLogin or isReloadingUi then return end

        local d = Dgn()
        if not d then return end

        local inInst, instType = IsInInstance()

        if d.inInstance and not inInst then
            -- Sortie d'instance — enregistrer si pas déjà compté et au moins 1 boss tué
            if not d.countedByLFG and (d.bossKills or 0) > 0 and (d.zoneName or "") ~= "" then
                T.RecordDungeon(d.zoneName, d.diffName ~= "" and d.diffName or nil)
            end
            T.DgnReset()

        elseif inInst and instType == "party" then
            -- Entrée dans un nouveau donjon : ne reset que si on change de zone
            if d.zoneName ~= (GetRealZoneText() or "") then
                d.inInstance   = true
                d.zoneName     = GetRealZoneText() or ""
                d.bossKills    = 0
                d.countedByLFG = false
                d.diffName     = ""
            end

        elseif not inInst then
            T.DgnReset()
        end
    end
end)

-- ─────────────────────────────────────────────
-- Commande slash
-- ─────────────────────────────────────────────
SLASH_LVLHISTORY1 = "/lvlh"
SlashCmdList["LVLHISTORY"] = function(msg)
    local cmd = strtrim(msg or ""):lower()

    if cmd == "" then
        T.UI.Toggle()

    elseif cmd == "minimap" then
        T.Minimap.Toggle()
        if LvlHistoryDB then
            LvlHistoryDB.settings.minimapButton = T.Minimap.IsShown()
        end

    elseif cmd == "options" or cmd == "config" then
        if LvlHistory_OpenOptions then LvlHistory_OpenOptions() end

    elseif cmd == "levels" or cmd == "niveaux" then
        if T.UI.OpenTab then T.UI.OpenTab(6) end

    elseif cmd == "debug" then
        T.debug = not T.debug
        LvlHistoryDB.settings.debug = T.debug
        print(T.Utils.Colorize("[LvlHistory]", "5EE223") .. " Debug: " .. (T.debug and "ON" or "OFF"))

    elseif cmd == "reset" then
        print(T.Utils.Colorize("[LvlHistory]", "5EE223")
            .. " " .. Loc("RESET_CONFIRM_HINT", "Tapez |cffFFFFFF/lvlh reset confirm|r pour confirmer."))

    elseif cmd == "reset confirm" then
        local key = T.charKey
        if key and LvlHistoryDB and LvlHistoryDB.chars and LvlHistoryDB.chars[key] then
            LvlHistoryDB.chars[key] = nil
            print(T.Utils.Colorize("[LvlHistory]", "5EE223") .. " " .. Loc("DATA_RESET_DONE", "Données réinitialisées. Rechargez (/reload)."))
        end

    else
        print(T.Utils.Colorize("[LvlHistory]", "5EE223")
            .. " " .. Loc("SLASH_HELP", "Commandes : /lvlh | /lvlh niveaux | /lvlh options | /lvlh minimap | /lvlh debug | /lvlh reset"))
    end
end
