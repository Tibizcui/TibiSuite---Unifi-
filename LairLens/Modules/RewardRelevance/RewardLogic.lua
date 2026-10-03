-- =============================================================================
-- LairLens - Modules/RewardRelevance/RewardLogic.lua
-- Decision "ca vaut le coup" / "tu peux zapper", par Repaire et difficulte.
--
-- Ingredients : (1) deja valide cette semaine ? via LL.Lockouts ; (2) l'ilvl
-- du butin (12.1 live : 279 / 292 / 305 / 318) face a l'ilvl equipe.
-- Le kill compte toujours comme activite de raid pour la Grande Chambre forte,
-- ce qui est rappele meme quand le butin est sous l'ilvl equipe.
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
    if ok and type(equipped) == "number" and equipped > 0 then return equipped end
    return nil
end

-- Statuts renvoyes, consommes ensuite par l'affichage.
Reward.STATUS = {
    WORTH    = "worth",     -- gain potentiel, pas encore valide
    VAULT    = "vault",     -- butin sous l'ilvl equipe, mais compte pour la Chambre forte
    SKIP     = "skip",      -- deja valide cette semaine
    NO_DATA  = "no_data",   -- difficulte inconnue
}

-- Evalue une instance a une difficulte donnee.
function Reward:Evaluate(instanceKey, difficultyKey)
    local entry = RD:Get(instanceKey, difficultyKey)
    if LL.Lockouts:IsCleared(instanceKey, difficultyKey) then
        return self.STATUS.SKIP, { reason = "done_week", entry = entry }
    end
    if not entry or not entry.ilvl then
        return self.STATUS.NO_DATA, {}
    end
    local equipped = equippedItemLevel()
    if not equipped or entry.ilvl > equipped then
        return self.STATUS.WORTH, { entry = entry, equipped = equipped }
    end
    return self.STATUS.VAULT, { entry = entry, equipped = equipped }
end

-- Libelle pret a afficher pour un statut.
function Reward:Describe(status, detail)
    local L = LL.L
    local e = detail and detail.entry
    local crest = e and RD:CrestName(e.crest)
    local tail = ""
    if e then
        tail = " " .. string.format(L["REWARD_ILVL"], e.ilvl) ..
            (crest and (", " .. crest) or (e.track and (", " .. L[e.track]) or ""))
    end
    if status == self.STATUS.WORTH then
        return L["REWARD_WORTH"] .. tail, C.COLOR[C.VERDICT.VIABLE]
    elseif status == self.STATUS.VAULT then
        return L["REWARD_VAULT"] .. tail, C.COLOR[C.VERDICT.RISKY]
    elseif status == self.STATUS.SKIP then
        return L["REWARD_DONE_WEEK"], C.COLOR.MUTED
    end
    return L["REWARD_NO_DATA"], C.COLOR.MUTED
end
