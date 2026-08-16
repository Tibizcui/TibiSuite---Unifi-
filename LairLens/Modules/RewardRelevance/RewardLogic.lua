-- =============================================================================
-- LairLens - Modules/RewardRelevance/RewardLogic.lua
-- Decision "ca vaut le coup" / "tu peux zapper", par Repaire et difficulte.
--
-- Deux ingredients : (1) deja valide cette semaine ? via LL.Lockouts ;
-- (2) le butin est-il un gain potentiel au regard de l'ilvl equipe ?
-- Tant que RewardData est vide, on repond honnetement "donnees indisponibles"
-- plutot qu'un verdict fabrique.
-- =============================================================================

local ADDON, LL = ...
local C = LL.const
local RD = LL.RewardData

local Reward = {}
LL:RegisterModule("rewardRelevance", Reward)

-- ilvl equipe du joueur. GetAverageItemLevel renvoie (global, equipe, pvp).
local function equippedItemLevel()
    if not GetAverageItemLevel then return nil end
    local ok, _, equipped = pcall(GetAverageItemLevel)
    if ok and type(equipped) == "number" then return equipped end
    return nil
end

-- Statuts renvoyes, consommes ensuite par l'affichage.
Reward.STATUS = {
    WORTH    = "worth",     -- gain potentiel, pas encore valide
    SKIP     = "skip",      -- deja valide, ou butin sous l'ilvl equipe
    NO_DATA  = "no_data",   -- tables de butin pas encore connues
}

-- Evalue une instance a une difficulte donnee.
function Reward:Evaluate(instanceKey, difficultyKey)
    -- 1) Deja valide cette semaine ? Info fiable meme sans tables de butin.
    if LL.Lockouts:IsCleared(instanceKey, difficultyKey) then
        return self.STATUS.SKIP, { reason = "done_week" }
    end

    -- 2) Pertinence de l'ilvl : necessite les tables de butin.
    local entry = RD:Get(instanceKey, difficultyKey)
    if not entry or not entry.ilvl then
        return self.STATUS.NO_DATA, {}
    end

    local equipped = equippedItemLevel()
    if not equipped then
        return self.STATUS.NO_DATA, {}
    end

    if entry.ilvl > equipped then
        return self.STATUS.WORTH, { ilvl = entry.ilvl, equipped = equipped }
    end
    return self.STATUS.SKIP, { reason = "ilvl", ilvl = entry.ilvl, equipped = equipped }
end

-- Libelle pret a afficher pour un statut.
function Reward:Describe(status, detail)
    local L = LL.L
    if status == self.STATUS.WORTH then
        return L["REWARD_WORTH"], C.COLOR[C.VERDICT.VIABLE]
    elseif status == self.STATUS.SKIP then
        if detail and detail.reason == "done_week" then
            return L["REWARD_DONE_WEEK"], C.COLOR.MUTED
        end
        return L["REWARD_SKIP"], C.COLOR.MUTED
    else
        return L["REWARD_NO_DATA"], C.COLOR.MUTED
    end
end
