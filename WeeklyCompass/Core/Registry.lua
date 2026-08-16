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
--   Poll        = function(emit)          -- appelle emit(entry) 0..n fois
--                 end,
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
            return row.enabled ~= false, row.reason
        end
    end
    return true, nil   -- non liste => actif par defaut
end

function Registry:IsActive(desc)
    local enabled = manifestState(desc.key)
    if not enabled then return false end
    if desc.IsAvailable and not desc.IsAvailable() then return false end
    return true
end

-- Rafraichit un module : purge ses anciennes entrees, puis re-collecte.
-- Un module inactif reste visible avec un statut "inconnu" et sa raison, pour
-- que le joueur sache qu'une activite existe mais attend encore sa source.
function Registry:Refresh(desc)
    if not desc then return end
    ns.Journal:ClearByPrefix(desc.key .. ":")

    if not self:IsActive(desc) then
        local _, reason = manifestState(desc.key)
        ns.Journal:Upsert({
            key      = desc.key .. ":_status",
            category = desc.category,
            order    = desc.order,
            label    = ns.L[desc.labelKey],
            short    = ns.L[desc.labelShortKey or desc.labelKey],
            status   = C.Status.UNKNOWN,
            detail   = reason or ns.L["DETAIL_API_PENDING"],
        })
        return
    end

    local count = 0
    local function emit(entry)
        count = count + 1
        entry.key      = entry.key or (desc.key .. ":" .. count)
        entry.category = entry.category or desc.category
        entry.order    = entry.order or desc.order
        ns.Journal:Upsert(entry)
    end

    local ok, err = pcall(desc.Poll, emit)
    if not ok then
        ns:Debug("Poll %s : %s", desc.key, tostring(err))
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
