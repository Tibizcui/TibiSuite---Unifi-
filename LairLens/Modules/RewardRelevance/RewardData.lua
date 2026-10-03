-- =============================================================================
-- LairLens - Modules/RewardRelevance/RewardData.lua
-- Couche de donnees du module 2. Depuis la 12.1 live (7.1.5.37), elle lit la
-- fiche par difficulte de Data.lua (ilvl du butin, Ecu de brume, piste,
-- butin automatique ou a tirer) au lieu d'une table vide.
-- =============================================================================

local ADDON, LL = ...
local C = LL.const
local D = LL.Data

LL.RewardData = {}
local RD = LL.RewardData

-- Renvoie l'entree de butin pour (instance, difficulte) ou nil si inconnue.
-- Tous les Repaires d'une meme saison partagent les memes valeurs : seule la
-- difficulte compte. Une table par Repaire reste possible via RD.override.
RD.override = {}

function RD:Get(instanceKey, difficultyKey)
    local byInstance = self.override[instanceKey]
    if byInstance and byInstance[difficultyKey] then return byInstance[difficultyKey] end
    return D:GetDifficultyInfo(difficultyKey)
end

-- Vrai si l'on dispose d'au moins une donnee exploitable.
function RD:HasData()
    return next(D.difficultyInfo) ~= nil
end

-- Nom localise d'un Ecu de brume (lu dans le client), ou nil.
function RD:CrestName(currencyID)
    if not (currencyID and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return nil end
    local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyID)
    if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
        return info.name, info.iconFileID, info.quantity
    end
    return nil
end
