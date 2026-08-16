local addonName, ns = ...

ns.Journal = ns.Journal or {}
local Journal = ns.Journal
local C = ns.Const

-- ---------------------------------------------------------------------------
-- Schema d'une entree normalisee. C'est le SEUL contrat entre les activites
-- d'un cote, et le journal / l'interface de l'autre. Un module ne produit que
-- des entrees a ce format ; il n'ecrit jamais directement dans l'interface.
--
-- {
--   key       = string,          -- unique par perso et par semaine, ex "greatVault:1"
--   category  = C.Category.*,    -- regroupement d'affichage
--   label     = string,          -- libelle deja localise, pret a afficher
--   short     = string | nil,    -- libelle court pour en-tete de colonne (defaut = label)
--   status    = C.Status.*,      -- fait / en cours / a faire / inconnu
--   order     = number,          -- ordre au sein de la categorie (defaut 100)
--   progress  = { current, max } | nil,   -- optionnel : "x/y"
--   reward    = { text = string } | nil,  -- optionnel : palier de recompense localise
--   detail    = string | nil,             -- optionnel : complement court
--   updatedAt = number,          -- rempli automatiquement par Upsert
-- }
-- ---------------------------------------------------------------------------

local function validate(entry)
    if type(entry) ~= "table" then return false, "entree non table" end
    if type(entry.key) ~= "string" or entry.key == "" then return false, "key manquante" end
    entry.category = entry.category or C.Category.MISC
    entry.status   = entry.status or C.Status.UNKNOWN
    entry.label    = entry.label or entry.key
    entry.short    = entry.short or entry.label   -- en-tete de colonne (vue compte)
    entry.order    = entry.order or 100
    return true
end

-- Ecrit ou remplace une entree pour le perso courant, sur la semaine courante.
function Journal:Upsert(entry)
    local ok, err = validate(entry)
    if not ok then
        ns:Debug("Journal:Upsert rejete (%s)", err)
        return
    end
    local char = ns.DB:GetChar()
    if not char then return end
    entry.updatedAt = GetServerTime()
    char.entries[entry.key] = entry
end

-- Efface les entrees d'un module (par prefixe "cle:"), avant de le re-collecter.
function Journal:ClearByPrefix(prefix)
    local char = ns.DB:GetChar()
    if not char then return end
    local n = #prefix
    for k in pairs(char.entries) do
        if k:sub(1, n) == prefix then
            char.entries[k] = nil
        end
    end
end

-- Comparateur de tri : categorie, puis ordre, puis libelle.
local function sortEntries(a, b)
    local ca = C.CategoryOrder[a.category] or 100
    local cb = C.CategoryOrder[b.category] or 100
    if ca ~= cb then return ca < cb end
    if (a.order or 100) ~= (b.order or 100) then return (a.order or 100) < (b.order or 100) end
    return (a.label or "") < (b.label or "")
end

-- Entrees d'un personnage (le courant par defaut), triees et pretes a afficher.
function Journal:GetEntries(charData)
    charData = charData or ns.DB:GetChar()
    local out = {}
    if not charData or not charData.entries then return out end
    for _, e in pairs(charData.entries) do
        out[#out + 1] = e
    end
    table.sort(out, sortEntries)
    return out
end

-- Vue multi-personnages (roster) pour le tableau de bord agrege.
-- "stale" signale un perso dont les donnees sont anterieures au reset courant
-- (typiquement un reroll pas reconnecte depuis le reset). Honnete par design :
-- on n'invente pas ses compteurs, on indique juste qu'ils sont a rafraichir.
function Journal:GetRoster()
    local roster = {}
    local current = ns.Reset:GetCurrentPeriodId()
    for key, char in pairs(ns.DB:GetAllChars()) do
        roster[#roster + 1] = {
            key      = key,
            name     = char.name,
            realm    = char.realm,
            class    = char.class,
            faction  = char.faction,
            periodId = char.periodId,
            stale    = not ns.Reset:IsSamePeriod(char.periodId, current),
            entries  = self:GetEntries(char),
        }
    end
    table.sort(roster, function(a, b) return (a.name or "") < (b.name or "") end)
    return roster
end
