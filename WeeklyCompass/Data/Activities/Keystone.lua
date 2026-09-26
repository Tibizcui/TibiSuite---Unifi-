local addonName, ns = ...
local C = ns.Const
local L = ns.L

-- ===========================================================================
-- Cle mythique+ en poche et score M+ (onglet Personnages).
--
-- Honnetete : la sonde (2026-09-26) n'a trouve aucun perso avec une cle, donc
-- la lecture de la cle n'est PAS encore confirmee en jeu. Regle : on n'emet
-- une case que si le jeu renvoie une vraie valeur (cle de niveau > 0, score
-- > 0). Jamais de "0" invente : sans donnee, la case reste "-".
--
-- La cle change a chaque reset (elle est remplacee) : son entree expire au
-- prochain reset (expiresAt), meme si le perso ne se reconnecte pas.
-- ===========================================================================

local module = {
    key      = "keystone",
    labelKey = "ACTIVITY_KEYSTONE",
    category = C.Category.CHARS,
    order    = 50,
    scope    = "snapshot",
    events   = { "BAG_UPDATE_DELAYED", "CHALLENGE_MODE_MAPS_UPDATE", "CHALLENGE_MODE_COMPLETED" },
}

function module.IsAvailable()
    return C_MythicPlus ~= nil and C_ChallengeMode ~= nil
end

function module.Poll(emit)
    local MP, CM = C_MythicPlus, C_ChallengeMode

    local mapID = type(MP.GetOwnedKeystoneChallengeMapID) == "function" and MP.GetOwnedKeystoneChallengeMapID()
    local level = type(MP.GetOwnedKeystoneLevel) == "function" and tonumber(MP.GetOwnedKeystoneLevel())
    if mapID and level and level > 0 then
        local name = type(CM.GetMapUIInfo) == "function" and CM.GetMapUIInfo(mapID)
        emit({
            key = "keystone:key", order = 50, status = C.Status.INFO,
            label = L["KEYSTONE_LABEL"], short = L["KEYSTONE_SHORT"], shortKey = "KEYSTONE_SHORT",
            detail = ("+%d %s"):format(level, tostring(name or "?")),
            sortValue = level, sum = 1, sumFormat = "count",
            expiresAt = ns.Reset:GetCurrentPeriodId(),
        })
    end

    local score = type(CM.GetOverallDungeonScore) == "function" and tonumber(CM.GetOverallDungeonScore())
    if score and score > 0 then
        local color
        if type(CM.GetDungeonScoreRarityColor) == "function" then
            local c = CM.GetDungeonScoreRarityColor(score)
            if c and c.r then color = { c.r, c.g, c.b } end
        end
        emit({
            key = "keystone:score", order = 60, status = C.Status.INFO,
            label = L["KEYSTONE_SCORE"], short = L["KEYSTONE_SCORE_SHORT"], shortKey = "KEYSTONE_SCORE_SHORT",
            detail = tostring(math.floor(score)), sortValue = score, color = color,
        })
    end
end

ns.Registry:Register(module)

-- Les donnees M+ demandent une requete serveur prealable ; la reponse arrive
-- avec CHALLENGE_MODE_MAPS_UPDATE, qui relance la collecte.
local function request()
    if C_MythicPlus and type(C_MythicPlus.RequestMapInfo) == "function" then
        pcall(C_MythicPlus.RequestMapInfo)
    end
end
ns:RegisterEvent("PLAYER_LOGIN", request)
if IsLoggedIn and IsLoggedIn() then request() end   -- charge a la demande par TibiSuite
