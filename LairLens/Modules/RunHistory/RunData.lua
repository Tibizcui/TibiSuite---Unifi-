-- =============================================================================
-- LairLens - Modules/RunHistory/RunData.lua
-- Stockage et interrogation de l'historique des runs de Repaire.
--
-- Choix de conception : l'historique est stocke au niveau COMPTE
-- (LairLensDB.history.runs), chaque run portant un champ `owner` (Nom-Royaume).
-- On obtient ainsi les deux vues demandees : par personnage (filtre owner) ET
-- compte agrege (tous owners), sans dupliquer les donnees.
--
-- Ce fichier ne touche a AUCUN evenement de jeu : c'est la couche donnee pure.
-- La capture vit dans RunTracker.lua, l'affichage dans DashboardFrame.lua.
-- =============================================================================

local ADDON, LL = ...
local C = LL.const

LL.RunHistory = {}
local RH = LL.RunHistory
LL:RegisterModule("runHistory", RH)

-- Acces defensif au magasin (peut ne pas exister avant DB_READY).
local function store()
    return LL.db and LL.db.history
end

-- Liste brute des runs (plus recent en tete). Toujours une table.
function RH:GetRuns()
    local s = store()
    return (s and s.runs) or {}
end

-- Ajoute un run termine en tete de liste, puis borne au plafond configure.
function RH:AddRun(run)
    local s = store()
    if not s or type(run) ~= "table" then return end
    s.runs = s.runs or {}
    table.insert(s.runs, 1, run)

    local cap = tonumber(s.maxRuns) or 500
    while #s.runs > cap do
        table.remove(s.runs)  -- retire le plus ancien (fin de liste)
    end

    LL:Emit("HISTORY_CHANGED")
end

-- Vide tout l'historique (utilise par un bouton du dashboard).
function RH:Clear()
    local s = store()
    if not s then return end
    s.runs = {}
    LL:Emit("HISTORY_CHANGED")
end

-- Liste triee et unique des personnages presents dans l'historique.
function RH:GetOwners()
    local seen, out = {}, {}
    for _, run in ipairs(self:GetRuns()) do
        local o = run.owner
        if o and not seen[o] then seen[o] = true; out[#out + 1] = o end
    end
    table.sort(out)
    return out
end

-- Liste unique des Repaires presents (cle -> nom lisible), pour le filtre.
function RH:GetInstances()
    local seen, out = {}, {}
    for _, run in ipairs(self:GetRuns()) do
        local k = run.instanceKey
        if k and not seen[k] then
            seen[k] = true
            out[#out + 1] = { key = k, name = run.instanceName or k }
        end
    end
    table.sort(out, function(a, b) return (a.name or "") < (b.name or "") end)
    return out
end

-- Un run passe-t-il le filtre courant ? `filter` = { owner, diff, instance, search }.
local function matchesRun(run, filter)
    if not filter then return true end
    if filter.owner and run.owner ~= filter.owner then return false end
    if filter.diff and run.difficulty ~= filter.diff then return false end
    if filter.instance and run.instanceKey ~= filter.instance then return false end

    local q = filter.search
    if q and q ~= "" then
        q = q:lower()
        local hay = (run.instanceName or "") .. " " .. (run.difficulty or "")
        if run.group then
            for _, m in ipairs(run.group) do
                hay = hay .. " " .. (m.name or "")
            end
        end
        if not hay:lower():find(q, 1, true) then return false end
    end
    return true
end

-- Renvoie la liste des runs filtres (meme ordre : plus recent en tete).
function RH:Filter(filter)
    local out = {}
    for _, run in ipairs(self:GetRuns()) do
        if matchesRun(run, filter) then out[#out + 1] = run end
    end
    return out
end

-- Agrege une liste de runs en totaux pour l'en-tete du dashboard.
function RH:Aggregate(list)
    local total = { count = 0, time = 0, attempts = 0, kills = 0, killRate = 0 }
    for _, run in ipairs(list or {}) do
        total.count    = total.count + 1
        total.time     = total.time + (tonumber(run.duration) or 0)
        total.attempts = total.attempts + (tonumber(run.attempts) or 0)
        total.kills    = total.kills + (tonumber(run.kills) or 0)
    end
    if total.count > 0 then
        -- Taux de kill = part des runs ayant abouti a au moins un kill.
        local cleared = 0
        for _, run in ipairs(list or {}) do
            if run.result == C.RUN.KILL then cleared = cleared + 1 end
        end
        total.killRate = cleared / total.count
    end
    return total
end
