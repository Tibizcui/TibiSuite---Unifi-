local addonName, ns = ...
local C = ns.Const
local L = ns.L

-- ===========================================================================
-- Verrouillages de raid (onglet Personnages) : une case "N raids", et le
-- detail boss par boss dans l'infobulle.
--
-- API relevee en jeu par la sonde (build 120100, 2026-09-26) :
-- GetSavedInstanceInfo(i) -> nom, id, secondes avant reset, difficulte,
-- verrouille, prolonge, _, raid ?, joueurs max, nom de difficulte, nombre de
-- boss, boss tues. Un verrouillage EXPIRE reste liste (verrouille = false,
-- reset = 0) : on le filtre. Tant que le serveur n'a pas repondu a
-- RequestRaidInfo (UPDATE_INSTANCE_INFO), la liste est vide : Poll renvoie
-- alors false pour garder la fiche precedente au lieu de l'effacer.
--
-- Chaque verrouillage stocke son heure d'expiration absolue ; Refine les
-- recompte a l'affichage. Un reroll pas reconnecte voit donc ses raids
-- disparaitre un par un a leur reset, sans rien inventer.
-- ===========================================================================

local module = {
    key      = "lockouts",
    labelKey = "ACTIVITY_LOCKOUTS",
    category = C.Category.CHARS,
    order    = 70,
    scope    = "snapshot",
    events   = { "UPDATE_INSTANCE_INFO" },
}

local ready = false   -- le serveur a-t-il repondu depuis le chargement ?

function module.IsAvailable()
    return type(GetNumSavedInstances) == "function" and type(GetSavedInstanceInfo) == "function"
end

function module.Poll(emit)
    if not ready then return false end
    local now = GetServerTime()
    local items = {}
    for i = 1, (tonumber(GetNumSavedInstances()) or 0) do
        local name, _, reset, diffID, locked, extended, _, isRaid, _, diffName, numEnc, encProg = GetSavedInstanceInfo(i)
        reset = tonumber(reset) or 0
        if isRaid and (locked or extended) and reset > 0 then
            items[#items + 1] = {
                name = name or "?", diff = diffName or "", diffID = tonumber(diffID),
                killed = tonumber(encProg) or 0, total = tonumber(numEnc) or 0,
                expiresAt = now + reset,
            }
        end
    end
    if #items == 0 then return end   -- aucun raid verrouille : case "-"
    table.sort(items, function(a, b) return a.name < b.name end)
    emit({
        key = "lockouts:raids", order = 70, status = C.Status.INFO,
        label = L["LOCKOUTS_LABEL"], short = L["LOCKOUTS_SHORT"], shortKey = "LOCKOUTS_SHORT",
        items = items, sumFormat = "count",
    })
end

-- Couleur d'une difficulte, par identifiant du jeu (DifficultyID) :
-- Mythique orange, Heroique violet, Normal bleu, Outil de raids vert, comme
-- les paliers d'objets. Difficulte inconnue (ou fiche d'avant diffID) : gris.
local DIFF_COLOR = {}
local MYTHIC, HEROIC, NORMAL, LFR = { 1.00, 0.50, 0.00 }, { 0.70, 0.40, 1.00 }, { 0.35, 0.65, 1.00 }, { 0.30, 0.90, 0.30 }
for _, id in ipairs({ 8, 16, 23 })            do DIFF_COLOR[id] = MYTHIC end
for _, id in ipairs({ 2, 5, 6, 15 })          do DIFF_COLOR[id] = HEROIC end
for _, id in ipairs({ 1, 3, 4, 9, 14, 33 })   do DIFF_COLOR[id] = NORMAL end
for _, id in ipairs({ 7, 17 })                do DIFF_COLOR[id] = LFR end
local GREY = { 0.60, 0.60, 0.63 }

-- Recompte a l'affichage : ne garde que les verrouillages encore valides, et
-- construit une infobulle structuree : nom du raid en gras, progression
-- alignee a droite (vert si complet, orange sinon), difficulte coloree en
-- dessous. Une seule ligne "Reset dans..." quand tous les raids partagent le
-- meme reset (le cas normal : reset hebdomadaire commun).
function module.Refine(e, now)
    local live = {}
    for _, it in ipairs(e.items or {}) do
        if (tonumber(it.expiresAt) or 0) > now then live[#live + 1] = it end
    end
    if #live == 0 then return nil end

    local first = live[1].expiresAt
    local sameReset = true
    for _, it in ipairs(live) do
        if math.abs(it.expiresAt - first) > 3600 then sameReset = false break end
    end

    local r = {}
    for k, v in pairs(e) do r[k] = v end
    r.detail = L["LOCKOUTS_COUNT"]:format(#live)
    r.hideDetailInTip = true
    r.sortValue = #live
    r.sum = #live
    r.lines = { { text = L["LOCKOUTS_COUNT"]:format(#live), color = { 0.85, 0.85, 0.85 }, font = "small" } }
    for _, it in ipairs(live) do
        local full = it.total > 0 and it.killed >= it.total
        r.lines[#r.lines + 1] = {
            text = it.name, color = { 1, 1, 1 }, font = "bold",
            right = ("%d/%d"):format(it.killed, it.total),
            rcolor = full and { 0.42, 0.85, 0.48 } or { 1.00, 0.70, 0.30 },
        }
        local diff = it.diff ~= "" and it.diff or "?"
        if not sameReset then
            diff = L["LOCKOUTS_DIFF_RESET"]:format(diff, ns.FormatDelay(it.expiresAt - now))
        end
        r.lines[#r.lines + 1] = { text = "   " .. diff, color = DIFF_COLOR[it.diffID] or GREY, font = "small" }
    end
    if sameReset then
        r.lines[#r.lines + 1] = { text = L["LOCKOUTS_RESET"]:format(ns.FormatDelay(first - now)),
            color = { 0.039, 1.000, 0.745 }, font = "bold" }
    end
    return r
end

ns.Registry:Register(module)

local function request()
    if type(RequestRaidInfo) == "function" then RequestRaidInfo() end
end
-- Declare apres le cablage du registre (meme evenement) : l'ordre ne compte
-- pas, la collecte est differee de 0,5 s, ready est vrai bien avant.
ns:RegisterEvent("UPDATE_INSTANCE_INFO", function() ready = true end)
ns:RegisterEvent("PLAYER_LOGIN", request)
-- Un boss tue change la liste : on redemande (la reponse relance la collecte).
ns:RegisterEvent("BOSS_KILL", function() C_Timer.After(2, request) end)
if IsLoggedIn and IsLoggedIn() then request() end   -- charge a la demande par TibiSuite
