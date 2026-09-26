local addonName, ns = ...

ns.Sources = ns.Sources or {}
local Sources = ns.Sources
local C = ns.Const

-- ---------------------------------------------------------------------------
-- Lecteurs de sources generiques. Une activite "pilotee par la donnee" ne code
-- aucune API specifique : elle declare des sources dans Data/Activities.lua
-- (ns.ActivitySources) et ce fichier les lit avec des API Blizzard stables.
--
-- Types de source reconnus :
--   { type = "currency", id = n }
--       -> gagne cette semaine / plafond hebdo si la monnaie en a un,
--          sinon quantite possedee (/ plafond total s'il existe).
--   { type = "renown", id = n }
--       -> rang de renom + progression dans le rang (C_MajorFactions).
--   { type = "quests", ids = { n, ... }, need = n|nil, labelKey = "..."|nil }
--       -> nombre de quetes de la liste deja faites (hebdo : le jeu remet les
--          drapeaux a zero au reset). need = nombre requis (defaut : toutes).
--
-- Les libelles viennent du jeu (nom de monnaie, de faction, de quete), donc
-- deja localises. labelKey permet de forcer un libelle de nos Locales.
-- ---------------------------------------------------------------------------

local function statusFor(current, max)
    if max and max > 0 and current >= max then return C.Status.DONE end
    if current > 0 then return C.Status.IN_PROGRESS end
    return C.Status.NOT_STARTED
end

local readers = {}

function readers.currency(src)
    local api = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo
    if type(api) ~= "function" then return nil end
    local info = api(src.id)
    if type(info) ~= "table" or type(info.name) ~= "string" or info.name == "" then return nil end

    local weeklyMax = tonumber(info.maxWeeklyQuantity) or 0
    local current, max, status
    if weeklyMax > 0 then
        current = tonumber(info.quantityEarnedThisWeek) or 0
        max     = weeklyMax
        status  = statusFor(current, max)
    else
        -- Pas de plafond hebdo : on affiche le stock, sans pretendre a un "fait".
        current = tonumber(info.quantity) or 0
        max     = tonumber(info.maxQuantity) or 0
        status  = current > 0 and C.Status.IN_PROGRESS or C.Status.NOT_STARTED
    end
    return {
        label    = info.name,
        status   = status,
        progress = (max > 0) and { current = current, max = max } or nil,
        detail   = (max == 0) and tostring(current) or nil,
    }
end

function readers.renown(src)
    local MF = C_MajorFactions
    if not (MF and type(MF.GetMajorFactionData) == "function") then return nil end
    local data = MF.GetMajorFactionData(src.id)
    if type(data) ~= "table" or type(data.name) ~= "string" then return nil end

    local maxed = type(MF.HasMaximumRenown) == "function" and MF.HasMaximumRenown(src.id)
    local earned    = tonumber(data.renownReputationEarned) or 0
    local threshold = tonumber(data.renownLevelThreshold) or 0
    local rank      = tonumber(data.renownLevel) or 0
    return {
        label    = data.name,
        status   = maxed and C.Status.DONE or C.Status.IN_PROGRESS,
        progress = (not maxed and threshold > 0) and { current = earned, max = threshold } or nil,
        detail   = ns.L["DETAIL_RENOWN_RANK"]:format(rank),
        rank     = rank,   -- affiche dans la case : "1775/4200 (R3)"
    }
end

function readers.quests(src)
    local QL = C_QuestLog
    if not (QL and type(QL.IsQuestFlaggedCompleted) == "function") then return nil end
    if type(src.ids) ~= "table" or #src.ids == 0 then return nil end

    local done = 0
    for _, id in ipairs(src.ids) do
        if QL.IsQuestFlaggedCompleted(id) then done = done + 1 end
    end
    local need = src.need or #src.ids

    local label = src.labelKey and ns.L[src.labelKey]
    if not label and type(QL.GetTitleForQuestID) == "function" then
        label = QL.GetTitleForQuestID(src.ids[1])
    end
    return {
        label    = label or ("#" .. src.ids[1]),
        status   = statusFor(done, need),
        progress = { current = math.min(done, need), max = need },
    }
end

-- Sources declarees pour une activite (table vide si rien n'est renseigne).
function Sources:Get(activityKey)
    local all = ns.ActivitySources or {}
    return all[activityKey] or {}
end

function Sources:HasAny(activityKey)
    return #self:Get(activityKey) > 0
end

-- Emet une entree par source lisible. Une source illisible (identifiant faux,
-- API absente) est simplement ignoree : jamais de compteur invente.
function Sources:Emit(desc, emit)
    for i, src in ipairs(self:Get(desc.key)) do
        local reader = readers[src.type]
        local ok, row = false, nil
        if reader then ok, row = pcall(reader, src) end
        if ok and row then
            row.key   = desc.key .. ":" .. i
            row.order = desc.order + i
            row.short = src.shortKey and ns.L[src.shortKey] or row.label
            emit(row)
        elseif not ok then
            ns:Debug("Source %s #%d : %s", desc.key, i, tostring(row))
        end
    end
end

-- Evenements qui peuvent faire bouger une source, pour le cablage du registre.
Sources.EVENTS = {
    "CURRENCY_DISPLAY_UPDATE",
    "QUEST_TURNED_IN",
    "MAJOR_FACTION_RENOWN_LEVEL_CHANGED",
    "UPDATE_FACTION",
}
