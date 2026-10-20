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
--   detailKey = string | nil,             -- optionnel : cle de Locales, prioritaire sur
--                                         -- detail a l'affichage (texte toujours a jour)
--   lines     = { string, ... } | nil,    -- optionnel : lignes de l'infobulle de la case
--   inferred  = true | nil,               -- entree DEDUITE a l'affichage, jamais stockee
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

-- Deux magasins par perso : "weekly" (char.entries, vide au reset) et
-- "snapshot" (char.snapshot, fiche persistante de l'onglet Personnages).
local function store(char, scope)
    if scope == "snapshot" then
        char.snapshot = char.snapshot or {}
        return char.snapshot
    end
    return char.entries
end

-- Ecrit ou remplace une entree pour le perso courant, dans le magasin voulu.
-- Une entree de la fiche persistante est marquee tab = "chars" (onglet
-- Personnages) ; sans tab, l'entree appartient a l'onglet de la semaine.
function Journal:Upsert(entry, scope)
    local ok, err = validate(entry)
    if not ok then
        ns:Debug("Journal:Upsert rejete (%s)", err)
        return
    end
    local char = ns.DB:GetChar()
    if not char then return end
    entry.updatedAt = GetServerTime()
    -- Une entree peut choisir son onglet (ex. "sheet" : fiche detaillee,
    -- jamais affichee en colonne) ; sinon la fiche va dans "chars".
    if scope == "snapshot" and not entry.tab then entry.tab = "chars" end
    store(char, scope)[entry.key] = entry
end

local function clearPrefix(t, prefix)
    if not t then return end
    local n = #prefix
    for k in pairs(t) do
        if k:sub(1, n) == prefix then
            t[k] = nil
        end
    end
end

-- Efface les entrees d'un module (par prefixe "cle:"), avant de le re-collecter.
function Journal:ClearByPrefix(prefix, scope)
    local char = ns.DB:GetChar()
    if not char then return end
    clearPrefix(store(char, scope), prefix)
end

-- Meme purge, mais sur TOUS les persos et dans les deux magasins (activite
-- retiree du tableau).
function Journal:ClearByPrefixAll(prefix)
    for _, char in pairs(ns.DB:GetAllChars()) do
        clearPrefix(char.entries, prefix)
        clearPrefix(char.snapshot, prefix)
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

-- Une entree de la fiche peut expirer (expiresAt : cle M+ au reset) ou etre
-- recalculee a l'affichage par son module (Refine : verrouillages dont une
-- partie a expire depuis la derniere connexion). Refine renvoie une COPIE, la
-- base n'est jamais modifiee a l'affichage. nil = rien a afficher.
local function refine(e, now)
    if e.expiresAt and e.expiresAt <= now then return nil end
    local modKey = type(e.key) == "string" and e.key:match("^([^:]+):")
    local mod = modKey and ns.Registry and ns.Registry:Get(modKey)
    if mod and mod.Refine then
        local ok, r = pcall(mod.Refine, e, now)
        if ok then return r end
        ns:Debug("Refine %s : %s", tostring(modKey), tostring(r))
    end
    return e
end

-- Entrees d'un personnage (le courant par defaut), semaine et fiche
-- confondues, triees et pretes a afficher.
function Journal:GetEntries(charData)
    charData = charData or ns.DB:GetChar()
    local out = {}
    if not charData or not charData.entries then return out end
    for _, e in pairs(charData.entries) do
        out[#out + 1] = e
    end
    local now = GetServerTime()
    for _, e in pairs(charData.snapshot or {}) do
        local r = refine(e, now)
        if r then out[#out + 1] = r end
    end
    table.sort(out, sortEntries)
    return out
end

-- Vue multi-personnages (roster) pour le tableau de bord agrege.
-- "stale" signale un perso dont les donnees sont anterieures au reset courant
-- (typiquement un reroll pas reconnecte depuis le reset). Honnete par design :
-- on n'invente pas ses compteurs, on indique juste qu'ils sont a rafraichir.
--
-- Recompense deduite : un perso "stale" qui avait debloque au moins un
-- emplacement du Grand Coffre avant le reset a forcement un choix en attente
-- (il ne s'est pas reconnecte pour le faire). On l'affiche, marque comme une
-- deduction, sans jamais l'ecrire dans la base.
local function addInferredClaim(char, entries)
    local stored = char.entries or {}
    if stored["greatVault:claim"] then return end   -- deja releve en jeu
    local filled = false
    for k, e in pairs(stored) do
        if k:match("^greatVault:%d+$") and type(e.progress) == "table"
            and (tonumber(e.progress.current) or 0) > 0 then
            filled = true
            break
        end
    end
    if not filled then return end
    entries[#entries + 1] = {
        key      = "greatVault:claim",
        category = C.Category.VAULT,
        order    = 60,   -- meme place que l'entree reelle (GreatVault : order + 50)
        label    = ns.L["VAULT_CLAIM_LABEL"],
        short    = ns.L["VAULT_CLAIM_SHORT"],
        status   = C.Status.NOT_STARTED,
        detail   = ns.L["VAULT_CLAIM_PROBABLE_CELL"],
        lines    = { ns.L["VAULT_CLAIM_PROBABLE_TIP"] },
        inferred = true,
    }
    table.sort(entries, sortEntries)
end

-- Retourne la liste affichable et le nombre de persos masques. Les persos
-- masques n'y figurent que si l'option "afficher les masques" est active.
-- "dup" signale un nom porte par plusieurs persos (royaumes differents).
function Journal:GetRoster()
    local roster, nHidden = {}, 0
    local current = ns.Reset:GetCurrentPeriodId()
    local showHidden = ns.DB:ShowHidden()
    local nameCount = {}
    for key, char in pairs(ns.DB:GetAllChars()) do
        local hidden = ns.DB:IsHidden(key)
        if hidden then nHidden = nHidden + 1 end
        if not hidden or showHidden then
            local stale = not ns.Reset:IsSamePeriod(char.periodId, current)
            local entries = self:GetEntries(char)
            if stale then addInferredClaim(char, entries) end
            roster[#roster + 1] = {
                key      = key,
                name     = char.name,
                realm    = char.realm,
                class    = char.class,
                faction  = char.faction,
                periodId = char.periodId,
                lastSeen = char.lastSeen,
                stale    = stale,
                hidden   = hidden,
                entries  = entries,
            }
            local n = char.name or "?"
            nameCount[n] = (nameCount[n] or 0) + 1
        end
    end
    for _, ch in ipairs(roster) do
        ch.dup = (nameCount[ch.name or "?"] or 0) > 1
    end
    table.sort(roster, function(a, b)
        if (a.name or "") ~= (b.name or "") then return (a.name or "") < (b.name or "") end
        return (a.realm or "") < (b.realm or "")
    end)
    return roster, nHidden
end

-- ================================================================
-- API PUBLIQUE (Standby) - lecture seule, depuis 7.1.5.40
-- Lue par la tuile « Mes personnages » de Standby. Memes donnees que la vue
-- Personnages (persos masques exclus, recompense deduite pour un perso pas
-- reconnecte depuis le reset).
-- ================================================================
WeeklyCompassAPI = WeeklyCompassAPI or {}
WeeklyCompassAPI.version = 1

-- Plafonds des monnaies de la saison (ns.SheetCurrencies, 7.1.5.45) :
--   near   = stock a 90 % ou plus du plafond de stock : depense avant de perdre ;
--   capped = plafond de la saison (qui monte chaque semaine) deja atteint :
--            inutile d'en farmer avant le prochain reset ;
--   room   = ce qu'il reste a gagner avant ce plafond (information : ce qui
--            n'est pas gagne cette semaine reste disponible la suivante).
-- Renvoie { { id, name, icon, qty, max, earned, state, room } }.
function WeeklyCompassAPI.GetCurrencyCaps()
    local out = {}
    local api = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo
    if type(api) ~= "function" then return out end
    for _, id in ipairs(ns.SheetCurrencies or {}) do
        local ok, info = pcall(api, id)
        if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
            local qty = tonumber(info.quantity) or 0
            local max = tonumber(info.maxQuantity) or 0
            local earned = tonumber(info.totalEarned) or 0
            local e = { id = id, name = info.name, icon = info.iconFileID, qty = qty, max = max, earned = earned }
            if max > 0 then
                if info.useTotalEarnedForMaxQty then
                    e.room = math.max(0, max - earned)
                    if e.room == 0 then e.state = "capped" end
                elseif qty >= max * 0.9 then
                    e.state = "near"
                end
            end
            out[#out + 1] = e
        end
    end
    return out
end

-- Ligne d'etat du Panneau vivant de TibiSuite (statusFn, lue par le core) :
-- recompense du Grand coffre a recuperer (urgent), sinon emplacements
-- debloques cette semaine sur les lignes que la fenetre de Blizzard affiche
-- (meme filtre que l'activite greatVault).
function WeeklyCompassAPI.GetStatus()
    local W = C_WeeklyRewards
    if not W then return nil end
    local SL = _G.TibiSuiteL or {}
    if type(W.HasAvailableRewards) == "function" then
        local ok, pending = pcall(W.HasAvailableRewards)
        if ok and pending then return { text = SL.ST_VAULT_CLAIM, urgent = true } end
    end
    local okC, caps = pcall(WeeklyCompassAPI.GetCurrencyCaps)
    if okC then
        for _, c in ipairs(caps) do
            if c.state == "near" then return { text = string.format(SL.ST_CAP_NEAR_FMT or "%s", c.name), urgent = true } end
        end
    end
    if type(W.GetActivities) ~= "function" then return nil end
    local ok, acts = pcall(W.GetActivities)
    if not ok or type(acts) ~= "table" then return nil end
    local E = Enum and Enum.WeeklyRewardChestThresholdType
    local done, total = 0, 0
    for _, a in ipairs(acts) do
        local shown = not E or a.type == E.Activities or a.type == E.Raid or a.type == E.World
        if shown and (a.threshold or 0) > 0 then
            total = total + 1
            if (a.progress or 0) >= a.threshold then done = done + 1 end
        end
    end
    if total == 0 then return nil end
    return { text = string.format(SL.ST_VAULT_FMT or "%d/%d", done, total), progress = done / total }
end

-- Apercu du Centre TibiSuite (overviewFn, lu par le core, 7.1.5.45) :
-- recompense a recuperer, les trois lignes du Grand coffre (seuils atteints
-- sur le nombre de seuils de la ligne), autres personnages avec un coffre.
function WeeklyCompassAPI.GetOverview()
    local SL = _G.TibiSuiteL or {}
    local W = C_WeeklyRewards
    local out = { lines = {}, empty = SL.OV_WC_EMPTY }
    if not W then return out end
    local lines = out.lines
    if type(W.HasAvailableRewards) == "function" then
        local ok, pending = pcall(W.HasAvailableRewards)
        if ok and pending then lines[#lines + 1] = { text = SL.OV_WC_CLAIM, urgent = true, target = "week" } end
    end
    if type(W.GetActivities) == "function" then
        local ok, acts = pcall(W.GetActivities)
        local E = Enum and Enum.WeeklyRewardChestThresholdType
        if ok and type(acts) == "table" and E then
            local rows = {
                { t = E.Raid, label = SL.OV_WC_RAID },
                { t = E.Activities, label = SL.OV_WC_DUNGEON },
                { t = E.World, label = SL.OV_WC_WORLD },
            }
            for _, row in ipairs(rows) do
                local done, total = 0, 0
                for _, a in ipairs(acts) do
                    if a.type == row.t and (a.threshold or 0) > 0 then
                        total = total + 1
                        if (a.progress or 0) >= a.threshold then done = done + 1 end
                    end
                end
                if total > 0 and row.label then
                    lines[#lines + 1] = { text = row.label, value = done .. " / " .. total, progress = done / total, target = "week" }
                end
            end
        end
    end
    if ns.CollectMPlus and #lines < 4 then
        local okM, m = pcall(ns.CollectMPlus)
        if okM and m and (m.score or m.key or m.weekBest) then
            local parts = {}
            if m.weekBest then parts[#parts + 1] = string.format(SL.OV_MP_WEEK_FMT or "%d", m.weekBest) end
            if m.key then parts[#parts + 1] = string.format(SL.OV_MP_KEY_FMT or "%d %s", m.key.level, tostring(m.key.name or "")) end
            lines[#lines + 1] = { text = m.score and string.format(SL.OV_MP_SCORE_FMT or "%d", math.floor(m.score)) or (SL.OV_MP or "M+"),
                value = table.concat(parts, "  ·  "), target = "chars" }
        end
    end
    local okC, caps = pcall(WeeklyCompassAPI.GetCurrencyCaps)
    if okC then
        local fmt = function(v) return (BreakUpLargeNumbers and BreakUpLargeNumbers(v)) or tostring(v) end
        local near, rest = {}, {}
        for _, c in ipairs(caps) do
            if c.state == "near" then near[#near + 1] = c
            elseif c.state == "capped" or (c.room and c.room > 0) then rest[#rest + 1] = c end
        end
        for _, c in ipairs(near) do
            if #lines < 4 then lines[#lines + 1] = { text = string.format(SL.OV_CAP_NEAR_FMT or "%s", c.name),
                value = fmt(c.qty) .. " / " .. fmt(c.max), progress = c.qty / c.max, urgent = true, target = "chars" } end
        end
        -- Le plus haut ecu (dernier de la liste) : ce qu'il reste a gagner.
        local c = rest[#rest]
        if c and #lines < 4 then
            lines[#lines + 1] = { text = c.name,
                value = (c.state == "capped") and SL.OV_CAP_CAPPED or string.format(SL.OV_CAP_ROOM_FMT or "%s", fmt(c.room)),
                progress = c.max > 0 and math.min(1, c.earned / c.max) or nil, target = "chars" }
        end
    end
    local okA, alts = pcall(WeeklyCompassAPI.GetAlts)
    if okA and type(alts) == "table" then
        local n = 0
        for _, a in ipairs(alts) do if a.claim and not a.current then n = n + 1 end end
        if n > 0 then lines[#lines + 1] = { text = string.format(SL.OV_WC_ALTS_FMT or "%d", n), target = "chars" } end
    end
    return out
end

-- Conseiller de TibiSuite (lot 3) : pour chaque ligne du Grand coffre
-- (raids, donjons, monde), le prochain emplacement pas encore debloque.
-- Proximite = avancement vers ce seuil, 0,3 au moins (une ligne pas
-- commencee reste visible pour qui joue ce contenu). Fin = reset hebdo.
function WeeklyCompassAPI.GetSuggestions()
    local W = C_WeeklyRewards
    local E = Enum and Enum.WeeklyRewardChestThresholdType
    if not (W and type(W.GetActivities) == "function" and E) then return nil end
    local ok, acts = pcall(W.GetActivities)
    if not ok or type(acts) ~= "table" then return nil end
    local SL = _G.TibiSuiteL or {}
    local reset
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local okR, s = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
        if okR and type(s) == "number" and s > 0 then reset = time() + s end
    end
    local rows = {
        { t = E.Raid, tag = "raid", group = true, label = SL.OV_WC_RAID, key = "raid" },
        { t = E.Activities, tag = "dungeon", group = true, label = SL.OV_WC_DUNGEON, key = "dungeon" },
        { t = E.World, tag = "delve", group = false, label = SL.OV_WC_WORLD, key = "world" },
    }
    local out = {}
    for _, row in ipairs(rows) do
        local nx
        for _, a in ipairs(acts) do
            if a.type == row.t and (a.threshold or 0) > 0 and (a.progress or 0) < a.threshold then
                if not nx or a.threshold < nx.threshold then nx = a end
            end
        end
        if nx and row.label then
            local p = (nx.progress or 0) / nx.threshold
            local mine = {}
            for _, a in ipairs(acts) do
                if a.type == row.t and (a.threshold or 0) > 0 then mine[#mine + 1] = a end
            end
            table.sort(mine, function(x, y) return x.threshold < y.threshold end)
            out[#out + 1] = { id = "vault:" .. row.key, kind = "weekly", tag = row.tag, group = row.group,
                text = row.label, proximity = math.max(0.3, p), endsAt = reset, target = "week",
                why = SL.SUG_W_VAULT_FMT and string.format(SL.SUG_W_VAULT_FMT, nx.progress or 0, nx.threshold) or nil,
                -- Infobulle du Conseiller : chaque emplacement de la ligne.
                steps = function()
                    local st = {}
                    for i, a in ipairs(mine) do
                        local pr = math.min(a.progress or 0, a.threshold)
                        st[#st + 1] = { text = string.format(SL.SUG_ST_SLOT_FMT or "%d: %d / %d", i, pr, a.threshold),
                            done = (a.progress or 0) >= a.threshold }
                    end
                    return st
                end }
        end
    end
    -- Mythique+ (7.3, lot E) : une cle en poche qui ameliore la meilleure du
    -- perso sur ce donjon. Fiches d'une semaine passee ignorees (cle changee).
    local okR, roster = pcall(WeeklyCompassAPI.GetMPlusRoster)
    if okR and type(roster) == "table" and SL.SUG_MP_FMT then
        for _, c in ipairs(roster.chars) do
            if c.improves and not c.stale and c.keyLevel then
                local b = c.keyMap and c.best[c.keyMap]
                out[#out + 1] = { id = "mplus:" .. tostring(c.key) .. ":" .. tostring(c.keyMap) .. ":" .. c.keyLevel,
                    kind = "mplus", tag = "dungeon", group = true, weight = 0.8,
                    text = string.format(SL.SUG_MP_FMT, c.keyLevel, tostring(c.keyName or "?"), tostring(c.name or "?")),
                    proximity = c.current and 0.75 or 0.6, endsAt = reset, target = "mplus",
                    why = (b and b.timed and b.level) and string.format(SL.SUG_MP_WHY_FMT, b.level) or SL.SUG_MP_NEW }
            end
        end
    end
    return out
end

-- Ouvre la fenetre sur un onglet ("week" ou "chars"), ou la fenetre
-- Mythique+ ("mplus", UI/MPlus.lua).
function WeeklyCompassAPI.OpenTab(tab)
    if tab == "mplus" and ns.MPlusShow then ns.MPlusShow(); return true end
    local g = ns.DB:GetGlobal()
    if g and (tab == "week" or tab == "chars") then g.tab = tab end
    local f = _G.WeeklyCompassFrame
    if f and f:IsShown() then ns.UI:Refresh() else ns.UI:Toggle() end
    return true
end

-- Or de chaque personnage et banque de Bataillon (7.3, page Patrimoine de
-- TibiSuite). Persos masques exclus. Montants en cuivre, au dernier releve.
-- Renvoie { chars = { { key, name, realm, class, gold, at } }, warband =
-- { money, at } | nil }.
function WeeklyCompassAPI.GetGold()
    local out = { chars = {} }
    local g = ns.DB:GetGlobal() or {}
    local hidden = g.hidden or {}
    for key, c in pairs(ns.DB:GetAllChars()) do
        local e = type(c) == "table" and c.snapshot and c.snapshot["profile:gold"]
        if e and not hidden[key] and tonumber(e.sortValue) then
            out.chars[#out.chars + 1] = { key = key, name = c.name, realm = c.realm, class = c.class,
                gold = tonumber(e.sortValue), at = e.updatedAt or c.lastSeen }
        end
    end
    table.sort(out.chars, function(a, b) return a.gold > b.gold end)
    if type(g.warband) == "table" and tonumber(g.warband.money) then
        out.warband = { money = tonumber(g.warband.money), at = g.warband.at }
    end
    return out
end

-- Mythique+ de tous les personnages (7.3, lot E), lu dans la fiche
-- (sheet:data.mplus) que chaque perso remplit a sa connexion. Rien n'est
-- calcule en points de cote (formule de Blizzard non publique) : on compare
-- des niveaux de cle.
--   stale    = fiche d'une semaine passee : courses de la semaine remises a 0,
--              cle en poche a reverifier (elle change au reset) ;
--   improves = la cle en poche depasse la meilleure du perso sur ce donjon
--              (ou donjon jamais fait), keyGain = niveaux gagnes ;
--   nextVault = courses manquantes pour le prochain emplacement Mythique+ du
--              Grand coffre (seuils 1, 4, 8), nil si les 3 sont pris.
-- Renvoie { chars = { ... }, maps = { {map, name} } } (persos tries par cote).
local MPLUS_VAULT = { 1, 4, 8 }
function WeeklyCompassAPI.GetMPlusRoster()
    local out, maps, seen = { chars = {} }, {}, {}
    local hidden = (ns.DB:GetGlobal() or {}).hidden or {}
    local cur = ns.Reset and ns.Reset.GetCurrentPeriodId and ns.Reset:GetCurrentPeriodId()
    local me = ns.charKey and ns.charKey() or nil
    for key, char in pairs(ns.DB:GetAllChars()) do
        if type(char) == "table" and not hidden[key] then
            local by = {}
            local okE, list = pcall(ns.Journal.GetEntries, ns.Journal, char)
            for _, e in ipairs(okE and list or {}) do by[e.key] = e end
            local sh = by["sheet:data"]
            -- Fiche sans bloc M+ (aucune cote, cle ni course cette saison) :
            -- le perso reste dans le tableau, avec des cases vides.
            local m = sh and (type(sh.mplus) == "table" and sh.mplus or {}) or nil
            if m then
                local stale = cur and not ns.Reset:IsSamePeriod(char.periodId, cur) or false
                local c = { key = key, name = char.name, realm = char.realm, class = char.class,
                    current = (key == me), score = m.score, stale = stale, best = {},
                    weekRuns = stale and 0 or (m.weekRuns or 0), weekBest = (not stale) and m.weekBest or nil,
                    noData = (sh.mplus == nil) or nil }
                for _, r in ipairs(m.runs or {}) do
                    if r.map then
                        c.best[r.map] = { level = r.level, timed = r.timed }
                        if not seen[r.map] then seen[r.map] = true; maps[#maps + 1] = { map = r.map, name = r.name } end
                    end
                end
                if type(m.key) == "table" and m.key.level then
                    c.keyMap, c.keyLevel, c.keyName = m.key.map, m.key.level, m.key.name
                    local b = c.best[m.key.map]
                    local bl = b and b.timed and b.level or 0
                    if m.key.level > bl then c.improves, c.keyGain = true, m.key.level - bl end
                end
                for _, t in ipairs(MPLUS_VAULT) do
                    if c.weekRuns < t then c.nextVault = t - c.weekRuns; break end
                end
                out.chars[#out.chars + 1] = c
            end
        end
    end
    -- Donjons de la saison lus en direct : les colonnes existent meme si
    -- aucun perso n'a encore de course.
    local CM = C_ChallengeMode
    if CM and type(CM.GetMapTable) == "function" then
        local okT, list = pcall(CM.GetMapTable)
        for _, id in ipairs(okT and type(list) == "table" and list or {}) do
            if not seen[id] then
                local okN, nm = pcall(CM.GetMapUIInfo, id)
                seen[id] = true
                maps[#maps + 1] = { map = id, name = okN and nm or ("#" .. id) }
            end
        end
    end
    table.sort(maps, function(a, b) return tostring(a.name) < tostring(b.name) end)
    table.sort(out.chars, function(a, b) return (a.score or 0) > (b.score or 0) end)
    out.maps = maps
    return out
end

-- Renvoie { { key, name, realm, class, current, claim, inferred, ilvl }, ... }
function WeeklyCompassAPI.GetAlts()
    local out = {}
    local ok, roster = pcall(Journal.GetRoster, Journal)
    if not ok or type(roster) ~= "table" then return out end
    local all = ns.DB:GetAllChars()
    local me = ns.charKey and ns.charKey() or nil
    for _, r in ipairs(roster) do
        if not r.hidden then
            local claim, inferred = false, false
            for _, e in ipairs(r.entries or {}) do
                if e.key == "greatVault:claim" then claim = true; inferred = e.inferred and true or false end
            end
            local snap = all[r.key] and all[r.key].snapshot
            local il = snap and snap["profile:ilvl"] and tonumber(snap["profile:ilvl"].sortValue) or nil
            out[#out + 1] = { key = r.key, name = r.name, realm = r.realm, class = r.class,
                              current = (r.key == me), claim = claim, inferred = inferred, ilvl = il }
        end
    end
    return out
end
