local addonName, ns = ...
local C = ns.Const
local L = ns.L

-- ===========================================================================
-- Grand Coffre : activite modelisee de bout en bout, exemple de reference.
--
-- Choix de perimetre assume : ce module reste volontairement FIN. On lit la
-- progression NATIVE (source de verite : l'API Blizzard du coffre) et on la
-- resume en une ligne "fait / reste" par famille de creneau. On NE reimplemente
-- PAS l'interface native du coffre. WeeklyCompass est une couche d'unification
-- et de decision, pas un enieme addon de coffre.
--
-- API : C_WeeklyRewards.GetActivities() renvoie la liste des activites du coffre.
-- On itere sur ce qu'elle renvoie plutot que de coder en dur la liste des
-- creneaux, parce que les sources qui alimentent le coffre en S2 ne sont pas
-- encore figees. Les champs .progress / .threshold / .type / .level de
-- WeeklyRewardActivityInfo sont historiquement stables ; a revalider tout de
-- meme sur la build 12.1 avant la premiere release publique.
-- ===========================================================================

local module = {
    key      = "greatVault",
    labelKey = "ACTIVITY_GREAT_VAULT",
    category = C.Category.VAULT,
    order    = 10,
    events   = { "WEEKLY_REWARDS_UPDATE" },
}

function module.IsAvailable()
    return C_WeeklyRewards ~= nil
        and type(C_WeeklyRewards.GetActivities) == "function"
end

-- Libelle lisible d'un type de creneau. On mappe depuis l'enum quand il existe,
-- sinon on retombe sur un libelle generique. Les valeurs reellement alimentees
-- en S2 restent a confirmer : le fallback garantit qu'on affiche toujours
-- quelque chose de correct sans rien inventer.
local function slotLabel(activityType)
    local E = Enum and Enum.WeeklyRewardChestThresholdType
    if E then
        if activityType == E.Activities then return L["VAULT_SLOT_MYTHIC"] end
        if activityType == E.Raid       then return L["VAULT_SLOT_RAID"] end
        if activityType == E.World      then return L["VAULT_SLOT_WORLD"] end
    end
    return L["VAULT_SLOT_GENERIC"]
end

-- Lien de l'objet que le jeu donnerait a l'instant T pour cette activite.
-- On ne code AUCUN seuil : c'est l'API du coffre qui repond. Retourne nil si
-- aucun objet n'est encore obtenable ou si l'API manque.
local function rewardHyperlink(info)
    if not info or type(info.id) ~= "number" then return nil end
    if type(C_WeeklyRewards.GetExampleRewardItemHyperlinks) ~= "function" then
        return nil
    end
    local hyperlink = C_WeeklyRewards.GetExampleRewardItemHyperlinks(info.id)
    if type(hyperlink) ~= "string" or hyperlink == "" then return nil end
    return hyperlink
end

-- Ilevel effectif d'un lien objet. Le lien renvoye par l'API du coffre porte
-- deja l'ilevel, donc la resolution est fiable sans dependre du cache objet.
-- On tolere l'ancienne forme globale des fonctions pour rester robuste build 12.1.
local function itemLevelFromLink(hyperlink)
    local getILvl = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
    if type(getILvl) == "function" then
        local ilvl = getILvl(hyperlink)
        if type(ilvl) == "number" and ilvl > 0 then return ilvl end
    end
    -- Filet de securite : ilevel via GetItemInfo (4e retour) si l'objet est en cache.
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if type(getInfo) == "function" then
        local _, _, _, ilvl = getInfo(hyperlink)
        if type(ilvl) == "number" and ilvl > 0 then return ilvl end
    end
    return nil
end

-- Nom localise d'une piste (cle -> libelle). Memo-ise une fois L disponible.
local TRACK_NAME_KEY = {
    explorer   = "TRACK_NAME_EXPLORER",
    adventurer = "TRACK_NAME_ADVENTURER",
    veteran    = "TRACK_NAME_VETERAN",
    champion   = "TRACK_NAME_CHAMPION",
    hero       = "TRACK_NAME_HERO",
    myth       = "TRACK_NAME_MYTH",
}

-- Palier (piste d'amelioration) d'un lien objet. On lit la PISTE reelle via
-- C_Item.GetItemUpgradeInfo (identite stable), puis on la mappe sur l'echelle
-- maison C.UpgradeTrack pour obtenir rang + couleur. Aucun ilevel devine ici :
-- c'est le jeu qui dit sur quelle piste est l'objet. Retourne un descripteur
-- { rank, color, key } ou nil.
--
-- trackString a un format qui varie selon les builds ("Mythique 3/6", etc.), on
-- cherche donc le nom de piste connu comme SOUS-CHAINE (comparaison brute, sans
-- dependre de la ponctuation ni des accents). Si plusieurs matchent, on garde le
-- plus haut rang.
local function rewardTrack(hyperlink)
    local getUpg = C_Item and C_Item.GetItemUpgradeInfo
    if type(getUpg) ~= "function" then return nil end

    local up = getUpg(hyperlink)
    if type(up) ~= "table" or type(up.trackString) ~= "string" or up.trackString == "" then
        return nil
    end

    local s = up.trackString:lower()
    local best
    for _, tier in ipairs(C.UpgradeTrack) do
        local nameKey = TRACK_NAME_KEY[tier.key]
        local name = nameKey and L[nameKey]
        if type(name) == "string" and name ~= "" and s:find(name:lower(), 1, true) then
            if not best or tier.rank > best.rank then best = tier end
        end
    end
    return best
end

function module.Poll(emit)
    local activities = C_WeeklyRewards.GetActivities()
    if type(activities) ~= "table" then return end

    -- Regroupe par type de creneau pour un resume "rempli / total" par famille.
    local byType = {}
    for _, info in ipairs(activities) do
        local t = info.type or 0
        local bucket = byType[t]
        if not bucket then
            bucket = { filled = 0, total = 0, earnedLevel = 0, label = slotLabel(t) }
            byType[t] = bucket
        end
        bucket.total = bucket.total + 1

        local progress  = tonumber(info.progress)  or 0
        local threshold = tonumber(info.threshold) or 0
        if threshold > 0 and progress >= threshold then
            bucket.filled = bucket.filled + 1

            -- Ilevel + palier REELLEMENT obtenables a l'instant T pour ce creneau
            -- debloque. On lit l'objet reel (PAS info.level, qui est le palier /
            -- niveau de cle, jamais un niveau d'objet). On garde, par type, le
            -- plus haut ilevel et le plus haut palier deja recuperables.
            local hyperlink = rewardHyperlink(info)
            if hyperlink then
                local ilvl = itemLevelFromLink(hyperlink) or 0
                if ilvl > bucket.earnedLevel then
                    bucket.earnedLevel = ilvl
                end

                local tier = rewardTrack(hyperlink)
                if tier and (not bucket.track or tier.rank > bucket.track.rank) then
                    bucket.track = tier
                end
            end
        end
    end

    for t, b in pairs(byType) do
        local status
        if b.total > 0 and b.filled >= b.total then
            status = C.Status.DONE
        elseif b.filled > 0 then
            status = C.Status.IN_PROGRESS
        else
            status = C.Status.NOT_STARTED
        end

        local reward
        if b.earnedLevel > 0 then
            reward = {
                text = L["VAULT_REWARD_ILVL"]:format(b.earnedLevel),
                ilvl = b.earnedLevel,   -- valeur brute pour l'affichage compact du tableau
                ilvlColor = b.track and b.track.color or nil,  -- couleur du palier (piste)
            }
        end

        emit({
            key      = module.key .. ":" .. tostring(t),
            category = module.category,
            order    = module.order + t,
            label    = ("%s : %s"):format(L[module.labelKey], b.label),
            short    = b.label,   -- en-tete de colonne dans la vue compte
            status   = status,
            progress = { current = b.filled, max = b.total },
            reward   = reward,
        })
    end
end

ns.Registry:Register(module)
