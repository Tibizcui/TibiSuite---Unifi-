-- Farming.lua
-- LvlHistory — Logique MODE_FARMING
-- Trackée : or/h (mode farming), réputation/h et monnaies (tous modes)
-- (zones et quetes sont suivies par Core.lua, dans tous les modes)
-- Auteur : Tibizcui | Famille : TibiSuite

LvlHistory.Farming = LvlHistory.Farming or {}
local F = LvlHistory.Farming

local farmingFrame, repFrame
local isRunning, repRunning = false, false

-- ─────────────────────────────────────────────
-- Or
-- ─────────────────────────────────────────────

local function OnMoneyUpdate()
    local db = LvlHistory.db
    if not db then return end

    local currentGold = GetMoney()
    local lastGold    = db.session.lastGold or currentGold
    local elapsed     = time() - db.session.startTime

    -- On comptabilise UNIQUEMENT les gains (delta positif).
    -- Les achats / réparations / enchantements réduisent l'or mais
    -- ne doivent pas impacter le calcul Or/h — on les ignore.
    if currentGold > lastGold then
        db.farming.goldEarned = (db.farming.goldEarned or 0) + (currentGold - lastGold)
    end
    db.session.lastGold = currentGold

    if elapsed >= 10 and (db.farming.goldEarned or 0) > 0 then
        db.farming.goldPerHour = math.floor(db.farming.goldEarned / elapsed * 3600)
    end
    db.farming.gold = db.farming.goldEarned or 0
end

-- ─────────────────────────────────────────────
-- Réputation (tous modes). API 11.0.2+ : C_Reputation.GetNumFactions /
-- GetFactionDataByIndex (meme chemin que RepBar). currentStanding = valeur
-- absolue gagnee aupres de la faction. Les factions a renom repartent a zero
-- a chaque rang : une baisse est donc traitee comme une nouvelle base.
-- UPDATE_FACTION arrive en rafale : un seul balayage toutes les 2 s.
-- ─────────────────────────────────────────────

local function IterateFactions(callback)
    local R = C_Reputation
    if not (R and R.GetNumFactions and R.GetFactionDataByIndex) then
        if R and R.GetWatchedFactionData then
            local d = R.GetWatchedFactionData()
            if d and d.name then callback(d.name, d.currentStanding or 0) end
        end
        return
    end
    local n = R.GetNumFactions() or 0
    for i = 1, n do
        local ok, d = pcall(R.GetFactionDataByIndex, i)
        if ok and d and d.name and d.name ~= "" and (not d.isHeader or d.isHeaderWithRep) then
            callback(d.name, d.currentStanding or 0)
        end
    end
end

local function ScanReputations()
    local db = LvlHistory.db
    if not db then return end
    local elapsed = time() - db.session.startTime

    IterateFactions(function(name, value)
        local prev = db.farming.rep[name]
        if not prev then
            db.farming.rep[name] = { value = value, gained = 0, perHour = 0 }
        elseif prev.stale then
            -- premiere lecture de la session : simple remise a niveau de la base
            prev.value, prev.stale = value, nil
        elseif value > (prev.value or 0) then
            local gained = value - (prev.value or 0)
            prev.gained  = (prev.gained or 0) + gained
            prev.value   = value
            prev.last    = time()
            if elapsed >= 10 then
                prev.perHour = math.floor(prev.gained / elapsed * 3600)
            end
            LvlHistory.Bridge.Emit("onRepGain", name, gained, prev.perHour)
        elseif value < (prev.value or 0) then
            prev.value = value   -- nouveau rang de renom : nouvelle base
        end
    end)
end

local scanQueued = false
local function QueueRepScan()
    if scanQueued then return end
    scanQueued = true
    C_Timer.After(2, function()
        scanQueued = false
        ScanReputations()
    end)
end

-- ─────────────────────────────────────────────
-- Monnaies : lecture ciblee de la monnaie qui a change (arguments de
-- CURRENCY_DISPLAY_UPDATE), plus de balayage de toute la liste.
-- ─────────────────────────────────────────────

local function OnCurrencyUpdate(currencyID, quantity, quantityChange)
    local db = LvlHistory.db
    if not db or not currencyID or not quantityChange or quantityChange <= 0 then return end
    local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo
        and C_CurrencyInfo.GetCurrencyInfo(currencyID)
    local name = info and info.name
    if not name or name == "" then return end
    local cu = db.farming.currencies[name]
    if not cu then
        cu = { last = quantity or 0, gained = 0 }
        db.farming.currencies[name] = cu
    end
    cu.gained = (cu.gained or 0) + quantityChange
    cu.last   = quantity or cu.last
    cu.id     = currencyID
end

-- ─────────────────────────────────────────────
-- API publique
-- ─────────────────────────────────────────────

--- Réputation et monnaies : suivies dans les deux modes.
function F.StartRep()
    if repRunning then return end
    repRunning = true
    local db = LvlHistory.db
    if db then
        -- Base initiale sans gain (les factions deja connues gardent leur base)
        IterateFactions(function(name, value)
            local prev = db.farming.rep[name]
            if not prev then
                db.farming.rep[name] = { value = value, gained = 0, perHour = 0 }
            elseif prev.stale or value < (prev.value or 0) then
                prev.value, prev.stale = value, nil
            end
        end)
    end
    repFrame = repFrame or CreateFrame("Frame", "LvlHistoryRepFrame", UIParent)
    repFrame:RegisterEvent("UPDATE_FACTION")
    repFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    repFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "UPDATE_FACTION" then QueueRepScan()
        else OnCurrencyUpdate(...) end
    end)
end

--- @param resume boolean  session reprise apres /reload : on garde les compteurs
function F.Start(resume)
    if isRunning then return end
    isRunning = true

    local db = LvlHistory.db
    if db then
        local currentGold = GetMoney()
        db.session.lastGold = currentGold   -- point de référence pour les deltas
        if not resume then
            db.farming.goldEarned  = 0      -- cumul gains uniquement (pas les achats)
            db.farming.goldPerHour = 0
        end
    end

    farmingFrame = farmingFrame or CreateFrame("Frame", "LvlHistoryFarmingFrame", UIParent)
    farmingFrame:RegisterEvent("PLAYER_MONEY")
    farmingFrame:SetScript("OnEvent", function() OnMoneyUpdate() end)

    LvlHistory.Utils.Log("Mode FARMING démarré")
end

function F.Stop()
    if not isRunning then return end
    isRunning = false
    if farmingFrame then farmingFrame:UnregisterAllEvents() end
    LvlHistory.Utils.Log("Mode FARMING arrêté")
end

function F.GetSessionSummary()
    local db = LvlHistory.db
    if not db then return {} end

    return {
        goldGained  = db.farming.gold or 0,
        goldPerHour = db.farming.goldPerHour or 0,
        rep         = db.farming.rep or {},
        currencies  = db.farming.currencies or {},
        quests      = db.session.questCount or 0,
        zone        = db.session.zone,
    }
end

--- Retourne les top N réputations gagnées cette session
function F.GetTopRep(n)
    local db = LvlHistory.db
    if not db then return {} end

    local sorted = {}
    for name, data in pairs(db.farming.rep) do
        if (data.gained or 0) > 0 then
            table.insert(sorted, { name = name, gained = data.gained, perHour = data.perHour })
        end
    end
    table.sort(sorted, function(a, b) return a.gained > b.gained end)

    local result = {}
    for i = 1, math.min(n or 5, #sorted) do
        result[i] = sorted[i]
    end
    return result
end
