-- =============================================================================
-- LairLens - Modules/RewardRelevance/RewardData.lua
-- Couche de donnees du module 2, VOLONTAIREMENT SOUPLE et VIDE.
--
-- Les tables de butin des Repaires et leur eventuelle liaison au Grand Coffre
-- sont marquees "not final" sur le PTR 12.1. On ne remplit donc rien pour
-- l'instant : on definit uniquement la FORME attendue, prete a etre completee
-- sans toucher a la logique. Le module signale honnetement "pas de donnees".
-- =============================================================================

local ADDON, LL = ...
local C = LL.const

LL.RewardData = {}
local RD = LL.RewardData

-- Schema cible, par instance de Repaire puis par difficulte :
--   RD.loot["tidebound_grotto"] = {
--       [C.DIFF.NORMAL]  = { ilvl = 000, track = "..." },
--       [C.DIFF.HEROIC]  = { ilvl = 000, track = "..." },
--       [C.DIFF.MYTHIC]  = { ilvl = 000, track = "..." },
--   }
-- ilvl = niveau d'objet indicatif du butin a cette difficulte.
-- track = piste de recompense (si le systeme s'y rattache) : a confirmer.
RD.loot = {
    -- vide tant que le PTR n'a pas fige les valeurs. Ne pas inventer d'ilvl.
}

-- Renvoie l'entree de butin pour (instance, difficulte) ou nil si inconnue.
function RD:Get(instanceKey, difficultyKey)
    local byInstance = self.loot[instanceKey]
    if not byInstance then return nil end
    return byInstance[difficultyKey]
end

-- Vrai si l'on dispose d'au moins une donnee exploitable.
function RD:HasData()
    return next(self.loot) ~= nil
end
