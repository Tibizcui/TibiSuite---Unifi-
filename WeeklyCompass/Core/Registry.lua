local addonName, ns = ...

ns.Registry = ns.Registry or {}
local Registry = ns.Registry
local C = ns.Const

-- ---------------------------------------------------------------------------
-- Contrat d'un module d'activite (descripteur). Chaque activite suivie est un
-- module decouple : il feature-detecte son API, collecte, et emet des entrees
-- normalisees dans le journal commun. Le registre ne sait rien de "comment"
-- une activite fonctionne, seulement qu'elle respecte ce contrat.
--
-- {
--   key         = string,                 -- identifiant stable, ex "greatVault"
--   labelKey    = string,                 -- cle de localisation du libelle
--   labelShortKey = string | nil,         -- cle de localisation du libelle court (en-tete de colonne)
--   category    = C.Category.*,
--   order       = number,                 -- ordre d'affichage de base
--   events      = { "WEEKLY_REWARDS_UPDATE", ... } | nil,  -- rafraichit sur ces evenements
--   IsAvailable = function() return boolean end,   -- l'API attendue existe-t-elle ?
--   Poll        = function(emit)          -- appelle emit(entry) 0..n fois ; renvoyer
--                 end,                    -- false = donnees pas pretes, garder l'existant
--   scope       = "weekly" | "snapshot" | nil,  -- magasin : semaine (defaut, vide au
--                                          -- reset) ou fiche persistante (onglet Personnages)
--   Refine      = function(entry, now) | nil,   -- recalcul a l'affichage (voir Journal)
-- }
-- ---------------------------------------------------------------------------

local modules = {}   -- [key] = descripteur
local order   = {}   -- liste ordonnee des cles (ordre d'enregistrement)
ns.modules = modules

function Registry:Register(desc)
    if type(desc) ~= "table" or type(desc.key) ~= "string" then
        ns:Debug("Registry:Register : descripteur invalide")
        return
    end
    if modules[desc.key] then
        ns:Debug("Registry:Register : doublon %s ignore", desc.key)
        return
    end
    modules[desc.key] = desc
    order[#order + 1] = desc.key
end

function Registry:Get(key) return modules[key] end
function Registry:GetAll() return modules, order end

-- Un module est actif par la DONNEE d'abord : le manifeste (Data/Activities.lua)
-- fait autorite pour activer/desactiver une activite sans toucher au code.
local function manifestState(key)
    local manifest = ns.ActivityManifest or {}
    for _, row in ipairs(manifest) do
        if row.key == key then
            return row.enabled ~= false, row.reason or (row.reasonKey and ns.L[row.reasonKey]),
                row.hidden == true
        end
    end
    return true, nil, false   -- non liste => actif par defaut
end

-- Activite retiree du tableau (manifeste : hidden = true). Contrairement a une
-- activite inactive, elle n'affiche meme pas de colonne "?".
function Registry:IsHidden(desc)
    return desc ~= nil and select(3, manifestState(desc.key)) == true
end

function Registry:IsActive(desc)
    local enabled = manifestState(desc.key)
    if not enabled then return false end
    if desc.IsAvailable and not desc.IsAvailable() then return false end
    return true
end

-- Rafraichit un module. La collecte est ATOMIQUE : les entrees emises sont
-- d'abord rassemblees, puis remplacent les anciennes d'un bloc. Si Poll
-- renvoie false ("donnees pas encore pretes", ex. verrouillages avant la
-- reponse du serveur) ou plante, les anciennes entrees sont conservees.
-- Un module inactif reste visible avec un statut "inconnu" et sa raison, pour
-- que le joueur sache qu'une activite existe mais attend encore sa source.
local afterCombat = false

function Registry:Refresh(desc)
    if not desc then return end
    local prefix = desc.key .. ":"
    local scope = (desc.scope == "snapshot") and "snapshot" or "weekly"
    if self:IsHidden(desc) then
        -- Purge chez tous les persos : sinon les rerolls pas reconnectes
        -- garderaient la colonne en memoire.
        ns.Journal:ClearByPrefixAll(prefix)
        return
    end

    if not self:IsActive(desc) then
        ns.Journal:ClearByPrefix(prefix, scope)
        local _, reason = manifestState(desc.key)
        ns.Journal:Upsert({
            key      = prefix .. "_status",
            category = desc.category,
            order    = desc.order,
            label    = ns.L[desc.labelKey],
            short    = ns.L[desc.labelShortKey or desc.labelKey],
            status   = C.Status.UNKNOWN,
            detail   = reason or ns.L["DETAIL_API_PENDING"],
        }, scope)
        return
    end

    -- L'activite est active : son entree "en attente" n'a plus de sens pour
    -- AUCUN perso. Sans cette purge, les rerolls pas reconnectes gardent une
    -- vieille colonne "?" a cote des nouvelles colonnes de l'activite.
    local statusKey = prefix .. "_status"
    for _, char in pairs(ns.DB:GetAllChars()) do
        if char.entries then char.entries[statusKey] = nil end
        if char.snapshot then char.snapshot[statusKey] = nil end
    end

    -- Fiche persistante : jamais de lecture en combat (valeurs secretes 12.x
    -- possibles, et rien ne presse). On rattrape a la sortie du combat.
    if scope == "snapshot" and InCombatLockdown and InCombatLockdown() then
        afterCombat = true
        return
    end

    local collected, count = {}, 0
    local function emit(entry)
        count = count + 1
        entry.key      = entry.key or (prefix .. count)
        entry.category = entry.category or desc.category
        entry.order    = entry.order or desc.order
        collected[#collected + 1] = entry
    end

    local ok, res = pcall(desc.Poll, emit)
    if not ok then
        ns:Debug("Poll %s : %s", desc.key, tostring(res))
        return
    end
    if res == false then return end

    ns.Journal:ClearByPrefix(prefix, scope)
    for _, entry in ipairs(collected) do
        ns.Journal:Upsert(entry, scope)
    end
end

function Registry:RefreshAll()
    ns.Reset:EnsureCurrentPeriod()
    for _, key in ipairs(order) do
        self:Refresh(modules[key])
    end
    ns:SendMessage("WC_JOURNAL_UPDATED")
end

-- Cablage des evenements declares par les modules, avec throttle : plusieurs
-- evenements rapproches ne declenchent qu'un seul rafraichissement.
local pending
local function scheduleRefresh()
    if pending then return end
    pending = true
    C_Timer.After(0.5, function()
        pending = false
        Registry:RefreshAll()
    end)
end

-- Sortie de combat : rattrape une collecte de fiche reportee.
ns:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if afterCombat then
        afterCombat = false
        scheduleRefresh()
    end
end)

function Registry:WireEvents()
    local seen = {}
    for _, key in ipairs(order) do
        local desc = modules[key]
        if desc.events then
            for _, ev in ipairs(desc.events) do
                if not seen[ev] then
                    seen[ev] = true
                    ns:RegisterEvent(ev, scheduleRefresh)
                end
            end
        end
    end
end

-- Cycle de vie : au login, on cable et on fait une premiere collecte. Un ticker
-- leger rattrape un reset ou une progression survenus en cours de session.
ns:RegisterEvent("PLAYER_LOGIN", function()
    Registry:WireEvents()
    Registry:RefreshAll()
    C_Timer.NewTicker(300, function() Registry:RefreshAll() end)
end)
