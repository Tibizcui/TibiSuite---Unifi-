-- Timer.lua
-- LvlHistory : chronometre d'instance affiche a l'ecran (donjon, Mythique+,
-- raid, repaire, gouffre, scenario et Tourment, champ de bataille, arene).
-- Auteur : Tibizcui | Famille : TibiSuite
--
-- Aucun second compteur : on lit le chrono persistant db._inst de Core.lua
-- (T.InstElapsed). Il demarre a l'entree dans l'instance, se met en pause
-- pendant les ecrans de chargement et survit aux /reload.
-- Aucune nouvelle SavedVariables. Reglages dans LvlHistoryDB.settings
-- (partages par le compte) :
--   timer       = false pour couper le chronometre (nil = actif)
--   timerOff    = { [type] = true } types desactives (nil = tous actifs)
--   timerLocked = true pour verrouiller la position
--   timerPos    = { point, relativePoint, x, y }
-- NON TESTE EN JEU.

LvlHistory = LvlHistory or {}
local T = LvlHistory
local function Loc(key, default) local L = T.L; return (L and L[key]) or default end

local Timer = {}
T.Timer = Timer

local FRAME_NAME = "LvlHistoryInstTimer"
local floor, format = math.floor, string.format

-- Ordre des cases dans les options
Timer.KINDS = { "party", "mplus", "raid", "lair", "delve", "scenario", "pvp", "arena" }

-- Contenus qui n'existent que sur Retail : case masquee ailleurs
Timer.RETAIL_ONLY = { lair = true, delve = true }

local KIND_COLOR = {
    party    = { 0.369, 0.886, 0.137 },   -- vert LvlHistory
    mplus    = { 1.000, 0.502, 0.000 },   -- orange
    raid     = { 0.640, 0.210, 0.930 },   -- violet
    lair     = { 0.200, 0.600, 0.860 },   -- bleu
    delve    = { 0.850, 0.650, 0.130 },   -- or
    scenario = { 0.700, 0.450, 0.950 },   -- lavande
    pvp      = { 0.769, 0.122, 0.231 },   -- rouge
    arena    = { 0.950, 0.350, 0.200 },   -- rouge orange
}

-- Libelle court (cadre) et libelle d'option (pluriel)
local SHORT = {
    party    = { "TIMER_S_PARTY",    "Donjon" },
    mplus    = { "TIMER_S_MPLUS",    "Mythique+" },
    raid     = { "TIMER_S_RAID",     "Raid" },
    lair     = { "TIMER_S_LAIR",     "Repaire" },
    delve    = { "TIMER_S_DELVE",    "Gouffre" },
    scenario = { "TIMER_S_SCENARIO", "Scénario" },
    pvp      = { "TIMER_S_PVP",      "Champ de bataille" },
    arena    = { "TIMER_S_ARENA",    "Arène" },
}
local LONG = {
    party    = { "TIMER_K_PARTY",    "Donjons (normal, héroïque, mythique 0)" },
    mplus    = { "TIMER_K_MPLUS",    "Mythique+" },
    raid     = { "TIMER_K_RAID",     "Raids" },
    lair     = { "TIMER_K_LAIR",     "Repaires" },
    delve    = { "TIMER_K_DELVE",    "Gouffres" },
    scenario = { "TIMER_K_SCENARIO", "Scénarios et Tourment" },
    pvp      = { "TIMER_K_PVP",      "Champs de bataille" },
    arena    = { "TIMER_K_ARENA",    "Arènes" },
}

function Timer.KindLabel(kind, long)
    local e = (long and LONG or SHORT)[kind]
    if not e then return tostring(kind) end
    return Loc(e[1], e[2])
end

-- ─────────────────────────────────────────────
-- Reglages
-- ─────────────────────────────────────────────
local function S()
    local db = _G.LvlHistoryDB
    return type(db) == "table" and type(db.settings) == "table" and db.settings or nil
end

function Timer.IsOn()
    local s = S()
    return not s or s.timer ~= false
end

function Timer.SetOn(on)
    local s = S()
    if s then s.timer = on and true or false end
    Timer.Refresh()
end

function Timer.IsKindOn(kind)
    local s = S()
    return not (s and type(s.timerOff) == "table" and s.timerOff[kind])
end

function Timer.SetKindOn(kind, on)
    local s = S()
    if not s then return end
    if type(s.timerOff) ~= "table" then s.timerOff = {} end
    s.timerOff[kind] = (not on) and true or nil
    if next(s.timerOff) == nil then s.timerOff = nil end
    Timer.Refresh()
end

function Timer.IsLocked()
    local s = S()
    return s and s.timerLocked and true or false
end

function Timer.SetLocked(on)
    local s = S()
    if s then s.timerLocked = on and true or nil end
end

-- ─────────────────────────────────────────────
-- Detection Mythique+ (Retail ; absente ailleurs, sans erreur)
-- ─────────────────────────────────────────────
local function IsMythicPlus()
    local cm = C_ChallengeMode
    if cm and cm.IsChallengeModeActive then
        local ok, v = pcall(cm.IsChallengeModeActive)
        if ok and v then return true end
    end
    local ok, _, _, diffID = pcall(GetInstanceInfo)
    return ok and diffID == 8   -- 8 = Mythique+ (cle active)
end

-- ─────────────────────────────────────────────
-- Boss tues / total (donjon, Mythique+, raid, repaire). NON TESTE EN JEU.
-- Tues : le plus grand de (verrou d'instance, boss tues pendant la visite).
-- Total : verrou d'instance (tous clients, apres le premier boss), sinon
-- Journal des donjons (Retail, Cata, Mists : meme methode que DgnTracker).
-- Sans total connu (Classic sans journal, donjon sans verrou) : "N boss".
-- Le journal peut lister un boss absent d'une difficulte (rare).
-- ─────────────────────────────────────────────
local BOSS_KINDS = { party = true, mplus = true, raid = true, lair = true }

function Timer.IsBossOn()
    local s = S()
    return not s or s.timerBoss ~= false
end

function Timer.SetBossOn(on)
    local s = S()
    if s then
        if on then s.timerBoss = nil else s.timerBoss = false end
    end
    Timer.Refresh()
end

local function JournalOpen()
    return EncounterJournal and EncounterJournal.IsShown and EncounterJournal:IsShown()
end

-- Boss du journal, dans l'ordre : { { name, enc } }. enc = dungeonEncounterID
-- (8e retour de EJ_GetEncounterInfoByIndex), le meme identifiant que
-- ENCOUNTER_END : il relie un boss tue a sa ligne du journal.
local function ReadEJ(jid, withArg)
    local list = {}
    for i = 1, 30 do
        local ok, bname, enc, _
        if withArg then ok, bname, _, _, _, _, _, enc = pcall(EJ_GetEncounterInfoByIndex, i, jid)
        else ok, bname, _, _, _, _, _, enc = pcall(EJ_GetEncounterInfoByIndex, i) end
        if not ok or not bname then break end
        list[#list + 1] = { name = bname, enc = enc }
    end
    return list
end

local ejList = {}   -- [journalInstanceID] = liste des boss

local function EJBosses()
    if not (EJ_GetInstanceForMap and EJ_GetEncounterInfoByIndex and C_Map and C_Map.GetBestMapForUnit) then return nil end
    local okM, uiMap = pcall(C_Map.GetBestMapForUnit, "player")
    if not okM or not uiMap then return nil end
    local okJ, jid = pcall(EJ_GetInstanceForMap, uiMap)
    if not okJ or not jid or jid == 0 then return nil end
    if ejList[jid] then return ejList[jid] end
    -- Selectionner une instance du journal : jamais en combat ni journal ouvert
    if InCombatLockdown and InCombatLockdown() then return nil end
    local list = ReadEJ(jid, true)
    if #list == 0 and EJ_SelectInstance and not JournalOpen() then
        local tier = EJ_GetCurrentTier and EJ_GetCurrentTier()
        if pcall(EJ_SelectInstance, jid) then
            list = ReadEJ(jid, false)
            if #list == 0 then list = ReadEJ(jid, true) end
        end
        if tier and EJ_SelectTier then pcall(EJ_SelectTier, tier) end
    end
    if #list > 0 then ejList[jid] = list; return list end
    return nil
end

-- Verrou d'instance courant : boss tues, total, liste { { name, killed } }
-- dans l'ordre du verrou (nil sans verrou)
local function Lockout()
    if not (GetNumSavedInstances and GetSavedInstanceInfo) then return nil end
    local ok, _, _, diff, _, _, _, _, mapID = pcall(GetInstanceInfo)
    if not ok or not mapID then return nil end
    local okN, num = pcall(GetNumSavedInstances)
    for i = 1, (okN and num or 0) do
        local okI, _, _, _, d, locked, _, _, _, _, _, numEnc, progress, _, instID = pcall(GetSavedInstanceInfo, i)
        if okI and instID == mapID and d == diff and locked and numEnc and numEnc > 0 then
            local list = {}
            if GetSavedInstanceEncounterInfo then
                for j = 1, numEnc do
                    local okE, bname, _, isKilled = pcall(GetSavedInstanceEncounterInfo, i, j)
                    if okE and bname then list[#list + 1] = { name = bname, killed = isKilled and true or false } end
                end
            end
            return progress or 0, numEnc, list
        end
    end
    return nil
end

local bossCache = { ref = nil, dirty = true, killed = 0, total = nil }
local function BossDirty() bossCache.dirty = true end

-- Prochain boss a tuer : le premier, dans l'ordre du journal (sinon du verrou),
-- qui n'est ni tue pendant la visite (identifiant) ni tue dans le verrou (nom).
-- Dans un raid a ailes ou a ordre libre, c'est le prochain dans l'ordre du
-- journal, pas forcement celui que le groupe attaquera.
local function NextBoss(v, ej, lockList)
    local deadName = {}
    for _, b in ipairs(lockList or {}) do
        if b.killed then deadName[b.name] = true end
    end
    local kills = type(v.kills) == "table" and v.kills or {}
    for _, b in ipairs(ej or lockList or {}) do
        local dead = deadName[b.name] or b.killed or (b.enc and kills[b.enc]) or kills[b.name]
        if not dead then return b.name end
    end
    return nil
end

local function BossInfo(v)
    if bossCache.ref ~= v then
        bossCache.ref, bossCache.dirty, bossCache.total = v, true, nil
    end
    if bossCache.dirty then
        bossCache.dirty = false
        local own = 0
        if type(v.kills) == "table" then for _ in pairs(v.kills) do own = own + 1 end end
        local lk, lt, lockList = Lockout()
        local ej = EJBosses()
        local killed = math.max(own, lk or 0)
        local total = lt or (ej and #ej) or nil
        if total and killed > total then killed = total end
        bossCache.killed, bossCache.total = killed, total
        bossCache.next = NextBoss(v, ej, lockList)
        bossCache.allDone = (total ~= nil and killed >= total) or false
        -- Journal pas encore lisible (combat) : on reessaiera plus tard
        if not ej and EJ_GetInstanceForMap then bossCache.retry = true else bossCache.retry = nil end
    end
    return bossCache.killed, bossCache.total
end

function Timer.IsNextOn()
    local s = S()
    return not s or s.timerNext ~= false
end

function Timer.SetNextOn(on)
    local s = S()
    if s then
        if on then s.timerNext = nil else s.timerNext = false end
    end
    Timer.Refresh()
end

-- Ligne « Suivant : X » (vide si option coupee, type sans boss ou inconnu)
local function NextText(v, view)
    if not BOSS_KINDS[view] or not Timer.IsNextOn() then return "" end
    BossInfo(v)
    if bossCache.allDone then return Loc("TIMER_NEXT_DONE", "Tous les boss sont vaincus") end
    if bossCache.next then return format(Loc("TIMER_NEXT_FMT", "Suivant : %s"), bossCache.next) end
    return ""
end

local function BossText(v, view)
    if not BOSS_KINDS[view] or not Timer.IsBossOn() then return "" end
    local killed, total = BossInfo(v)
    if total then return format(Loc("TIMER_BOSS_FMT", "%d/%d boss"), killed, total) end
    if killed > 0 then return format(Loc("TIMER_BOSS_ONLY_FMT", "%d boss"), killed) end
    return ""
end

local function Fmt(secs)
    secs = floor(math.max(0, secs or 0))
    local h = floor(secs / 3600)
    local m = floor((secs % 3600) / 60)
    local s = secs % 60
    if h > 0 then return format("%d:%02d:%02d", h, m, s) end
    return format("%02d:%02d", m, s)
end

-- ─────────────────────────────────────────────
-- Cadre
-- ─────────────────────────────────────────────
local frame, ticker
local dismissedRef      -- etat db._inst masque par la croix (jusqu'a la prochaine instance)
local currentView       -- type affiche (pour l'infobulle)

local function StopTicker()
    if ticker then ticker:Cancel(); ticker = nil end
end

local function SavePos(f)
    local s = S()
    if not s then return end
    local p, _, rp, x, y = f:GetPoint(1)
    if p then s.timerPos = { p, rp or p, floor((x or 0) + 0.5), floor((y or 0) + 0.5) } end
end

local function ApplyPos(f)
    f:ClearAllPoints()
    local s = S()
    local p = s and s.timerPos
    if type(p) == "table" and type(p[1]) == "string" then
        f:SetPoint(p[1], UIParent, p[2] or p[1], tonumber(p[3]) or 0, tonumber(p[4]) or 0)
    else
        f:SetPoint("TOP", UIParent, "TOP", 0, -140)
    end
end

function Timer.Recenter()
    local s = S()
    if s then s.timerPos = nil end
    if frame then ApplyPos(frame) end
end

local function ShowTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
    GameTooltip:SetText(Loc("TIMER_TT_TITLE", "Chronomètre d'instance"))
    if currentView then
        GameTooltip:AddLine(Timer.KindLabel(currentView), 1, 1, 1)
    end
    GameTooltip:AddLine(Loc("TIMER_TT_NOTE", "Temps passé depuis l'entrée, écrans de chargement exclus."), 0.7, 0.7, 0.7, true)
    if not Timer.IsLocked() then
        GameTooltip:AddLine(Loc("TIMER_TT_DRAG", "Glisser : déplacer"), 0.6, 0.8, 1)
    end
    GameTooltip:AddLine(Loc("TIMER_TT_RCLICK", "Clic droit : options"), 0.6, 0.8, 1)
    GameTooltip:Show()
end

local function Build()
    if frame then return frame end
    local UI = _G.TibiMidnight
    local tpl = BackdropTemplateMixin and "BackdropTemplate" or nil
    local f = CreateFrame("Frame", FRAME_NAME, UIParent, tpl)
    f:SetSize(200, 44)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    if UI and UI.SkinFrame then
        UI.SkinFrame(f, KIND_COLOR.party)
    end

    local name = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
    name:SetPoint("TOPRIGHT", f, "TOPRIGHT", -20, -8)
    name:SetJustifyH("LEFT")
    if name.SetWordWrap then name:SetWordWrap(false) end
    name:SetTextColor(0.78, 0.78, 0.78)
    f.nameFs = name

    local clock = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    -- Ancre au HAUT du cadre : la ligne « Suivant » s'ajoute dessous (hauteur variable)
    clock:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 8, -38)
    clock:SetJustifyH("LEFT")
    f.clockFs = clock

    -- Boss tues / total, a droite de l'horloge
    local boss = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    boss:SetPoint("LEFT", clock, "RIGHT", 10, 0)
    boss:SetJustifyH("LEFT")
    boss:SetTextColor(1, 0.82, 0)
    f.bossFs = boss

    local kindFs = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    kindFs:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -8, -36)
    kindFs:SetJustifyH("RIGHT")
    f.kindFs = kindFs

    -- Prochain boss a tuer (option timerNext), troisieme ligne
    local nextFs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nextFs:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -42)
    nextFs:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -42)
    nextFs:SetJustifyH("LEFT")
    if nextFs.SetWordWrap then nextFs:SetWordWrap(false) end
    nextFs:SetTextColor(0.85, 0.85, 0.85)
    f.nextFs = nextFs

    -- Croix : masque le chronometre jusqu'a la prochaine instance
    local close = CreateFrame("Button", nil, f)
    close:SetSize(16, 16)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -4)
    local cx = close:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cx:SetPoint("CENTER")
    cx:SetText("x")
    cx:SetTextColor(0.6, 0.6, 0.6)
    close:SetScript("OnEnter", function(b)
        cx:SetTextColor(1, 1, 1)
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetText(Loc("TIMER_TT_CLOSE", "Masquer jusqu'à la prochaine instance"), nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    close:SetScript("OnLeave", function() cx:SetTextColor(0.6, 0.6, 0.6); GameTooltip:Hide() end)
    close:SetScript("OnClick", function()
        local _, v
        if T.InstElapsed then _, v = T.InstElapsed() end
        dismissedRef = v
        GameTooltip:Hide()
        Timer.Refresh()
    end)

    f:SetScript("OnDragStart", function(s)
        if Timer.IsLocked() then return end
        s:StartMoving()
    end)
    f:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        -- Position gardee par nous seuls (pas par le cache de disposition de WoW)
        if s.SetUserPlaced then pcall(s.SetUserPlaced, s, false) end
        SavePos(s)
    end)
    f:SetScript("OnMouseUp", function(_, btn)
        if btn == "RightButton" and _G.LvlHistory_OpenOptions then _G.LvlHistory_OpenOptions() end
    end)
    f:SetScript("OnEnter", ShowTooltip)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:SetScript("OnHide", StopTicker)

    ApplyPos(f)
    f:Hide()
    frame = f
    return f
end

-- ─────────────────────────────────────────────
-- Mise a jour (une fois par seconde, uniquement quand le cadre est visible)
-- ─────────────────────────────────────────────
function Timer.Refresh()
    -- Difficulte de raid changee sur place : realigne le chrono (Core.lua)
    if T.InstCheckDiff and T.InstCheckDiff() then BossDirty() end
    local elapsed, v
    if T.InstElapsed then elapsed, v = T.InstElapsed() end

    local view
    if v and Timer.IsOn() then
        view = v.kind
        if view == "party" and IsMythicPlus() then view = "mplus" end
        if not Timer.IsKindOn(view) or dismissedRef == v then view = nil end
    end
    if dismissedRef and dismissedRef ~= v then dismissedRef = nil end

    if not view then
        currentView = nil
        if frame then frame:Hide() end
        StopTicker()
        return
    end

    local f = Build()
    currentView = view
    local label = v.name or ""
    if v.kind == "raid" and v.diff then label = label .. " (" .. v.diff .. ")" end
    f.nameFs:SetText(label)
    f.clockFs:SetText(Fmt(elapsed))
    -- Total des boss pas encore lisible (journal en combat) : nouvel essai toutes les 10 s
    if bossCache.retry and not (InCombatLockdown and InCombatLockdown()) then
        local now = GetTime and GetTime() or 0
        if now - (bossCache.lastTry or 0) >= 10 then bossCache.lastTry = now; BossDirty() end
    end
    f.bossFs:SetText(BossText(v, view))
    local nextText = NextText(v, view)
    f.nextFs:SetText(nextText)
    local h = (nextText ~= "") and 58 or 44
    if f:GetHeight() ~= h then f:SetHeight(h) end
    f.kindFs:SetText(Timer.KindLabel(view))
    local c = KIND_COLOR[view]
    local UI = _G.TibiMidnight
    if c and UI and UI.SetLisere and f._tibiView ~= view then
        UI.SetLisere(f, c)
        f._tibiView = view
    end
    if not f:IsShown() then f:Show() end
    if not ticker and C_Timer and C_Timer.NewTicker then
        ticker = C_Timer.NewTicker(1, Timer.Refresh)
    end
end

-- ─────────────────────────────────────────────
-- Evenements : le chrono de Core.lua est synchronise a PLAYER_ENTERING_WORLD
-- par un autre cadre ; on rafraichit avec un court delai pour passer apres lui.
-- ─────────────────────────────────────────────
local function AskLockouts()
    if RequestRaidInfo then pcall(RequestRaidInfo) end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD",
                     "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED",
                     "ENCOUNTER_END", "UPDATE_INSTANCE_INFO" }) do
    pcall(ev.RegisterEvent, ev, e)   -- evenements Mythique+ absents sur Classic
end
ev:SetScript("OnEvent", function(_, e, ...)
    if e == "PLAYER_LEAVING_WORLD" then
        if frame then frame:Hide() end
        return
    end
    if e == "UPDATE_INSTANCE_INFO" then
        BossDirty()
        if frame and frame:IsShown() then Timer.Refresh() end
        return
    end
    if e == "ENCOUNTER_END" then
        -- Boss tue pendant la visite : garde dans db._inst.kills (survit au /reload)
        local encID, encName, _, _, success = ...
        if success == 1 or success == true then
            local _, v
            if T.InstElapsed then _, v = T.InstElapsed() end
            if v then
                v.kills = v.kills or {}
                v.kills[encID or encName or (#v.kills + 1)] = true
            end
            BossDirty()
            if C_Timer and C_Timer.After then C_Timer.After(2, AskLockouts) end
        end
        if frame and frame:IsShown() then Timer.Refresh() end
        return
    end
    if e == "PLAYER_ENTERING_WORLD" then
        BossDirty()
        AskLockouts()
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(1, Timer.Refresh)
    else
        Timer.Refresh()
    end
end)
