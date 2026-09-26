local addonName, ns = ...
local C = ns.Const
local L = ns.L

-- ===========================================================================
-- Fiche du personnage (onglet Personnages) : niveau, specialisation, niveau
-- d'objet, or, repos. Magasin "snapshot" : ces valeurs ne sont PAS remises a
-- zero au reset hebdo, un reroll pas reconnecte garde sa derniere fiche.
--
-- API relevees en jeu par la sonde TibiProbe (build 120100, 2026-09-26) :
-- GetAverageItemLevel (global, equipe, JcJ ; renvoie 0,5 sur un niveau 1),
-- GetMoney, GetXPExhaustion (nil au niveau max), GetSpecializationInfo.
-- ===========================================================================

local module = {
    key      = "profile",
    labelKey = "ACTIVITY_PROFILE",
    category = C.Category.CHARS,
    order    = 10,
    scope    = "snapshot",
    events   = {
        "PLAYER_MONEY", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_AVG_ITEM_LEVEL_UPDATE",
        "PLAYER_LEVEL_UP", "PLAYER_SPECIALIZATION_CHANGED", "UPDATE_EXHAUSTION",
    },
}

function module.IsAvailable()
    return type(UnitLevel) == "function" and type(GetMoney) == "function"
end

function module.Poll(emit)
    local level = tonumber(UnitLevel("player")) or 0
    emit({
        key = "profile:level", order = 10, status = C.Status.INFO,
        label = L["PROFILE_LEVEL"], short = L["PROFILE_LEVEL_SHORT"], shortKey = "PROFILE_LEVEL_SHORT",
        detail = tostring(level), sortValue = level,
    })

    if type(GetSpecialization) == "function" and type(GetSpecializationInfo) == "function" then
        local idx = GetSpecialization()
        if idx then
            local _, specName, _, icon, role = GetSpecializationInfo(idx)
            if type(specName) == "string" and specName ~= "" then
                local txt = specName
                if icon then txt = ("|T%s:0|t %s"):format(tostring(icon), specName) end
                emit({
                    key = "profile:spec", order = 20, status = C.Status.INFO,
                    label = L["PROFILE_SPEC"], short = L["PROFILE_SPEC_SHORT"], shortKey = "PROFILE_SPEC_SHORT",
                    detail = txt,
                    lines = role and { _G[role] or role } or nil,
                })
            end
        end
    end

    if type(GetAverageItemLevel) == "function" then
        local overall, equipped = GetAverageItemLevel()
        equipped = tonumber(equipped) or 0
        if equipped > 1 then
            emit({
                key = "profile:ilvl", order = 30, status = C.Status.INFO,
                label = L["PROFILE_ILVL"], short = L["PROFILE_ILVL_SHORT"], shortKey = "PROFILE_ILVL_SHORT",
                detail = ns.FormatDecimal(equipped), sortValue = equipped,
                lines = { L["PROFILE_ILVL_OVERALL"]:format(ns.FormatDecimal(overall)) },
            })
        end
    end

    local money = tonumber(GetMoney()) or 0
    emit({
        key = "profile:gold", order = 40, status = C.Status.INFO,
        label = L["PROFILE_GOLD"], short = L["PROFILE_GOLD_SHORT"], shortKey = "PROFILE_GOLD_SHORT",
        detail = ns.FormatGold(money), sortValue = money,
        sum = money, sumFormat = "money",
    })

    -- Repos : seulement sous le niveau max (au max, le jeu renvoie nil).
    local maxLevel = type(GetMaxLevelForPlayerExpansion) == "function" and GetMaxLevelForPlayerExpansion()
    local rest = type(GetXPExhaustion) == "function" and tonumber(GetXPExhaustion()) or 0
    local xpMax = tonumber(UnitXPMax and UnitXPMax("player")) or 0
    if (not maxLevel or level < maxLevel) and rest > 0 and xpMax > 0 then
        local pct = math.floor(rest / xpMax * 100 + 0.5)
        emit({
            key = "profile:rest", order = 80, status = C.Status.INFO,
            label = L["PROFILE_REST"], short = L["PROFILE_REST_SHORT"], shortKey = "PROFILE_REST_SHORT",
            detail = L["PROFILE_REST_PCT"]:format(pct), sortValue = pct,
        })
    end
end

ns.Registry:Register(module)

-- ---------------------------------------------------------------------------
-- Banque de Bataillon (or commun au compte). La sonde a montre que
-- C_Bank.FetchDepositedMoney renvoie 0 tant que la banque n'a pas ete ouverte
-- dans la session : on ne lit donc QUE banque ouverte ou sur ACCOUNT_MONEY,
-- jamais au login, pour ne pas ecraser un vrai montant par un 0 de chargement.
-- NON TESTE EN JEU a l'ecriture (evenements et enum a confirmer).
-- ---------------------------------------------------------------------------
local function readWarband()
    local B = C_Bank
    local bankType = Enum and Enum.BankType and Enum.BankType.Account
    if not (B and type(B.FetchDepositedMoney) == "function" and bankType) then return end
    local ok, money = pcall(B.FetchDepositedMoney, bankType)
    money = ok and tonumber(money)
    ns:Debug("Banque de Bataillon : %s", tostring(money))
    -- Constate en jeu (7.1.5.21 dev) : 0 renvoye alors que la banque contenait
    -- de l'or. Un 0 n'est donc JAMAIS retenu : mieux vaut "ouvre-la" qu'un faux total.
    if not money or money <= 0 then return end
    local g = ns.DB:GetGlobal()
    if not g then return end
    g.warband = { money = money, at = GetServerTime() }
    ns:SendMessage("WC_JOURNAL_UPDATED")
end

local function isBankInteraction(kind)
    local T = Enum and Enum.PlayerInteractionType
    if not T then return false end
    return kind == T.Banker or kind == T.AccountBanker
end

-- Deux lectures differees : le montant peut arriver apres l'ouverture.
local function readSoon()
    C_Timer.After(1, readWarband)
    C_Timer.After(3, readWarband)
end
ns:RegisterEvent("BANKFRAME_OPENED", readSoon)
ns:RegisterEvent("ACCOUNT_MONEY", function() readWarband() end)
ns:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(_, kind)
    if isBankInteraction(kind) then readSoon() end
end)
