local addonName, ns = ...

-- Objet public de l'addon (surface d'API + point d'entree slash).
WeeklyCompass = WeeklyCompass or {}
local Addon = WeeklyCompass
ns.Addon = Addon
Addon.name = addonName

do
    -- Version lue directement dans le .toc (champ ## Version).
    -- Fonctionne en compile manuel comme en build packager.
    -- Si un jeton non substitue traine encore, on retombe sur "dev".
    local meta = C_AddOns and C_AddOns.GetAddOnMetadata
    local v = meta and C_AddOns.GetAddOnMetadata(addonName, "Version")
    Addon.version = (v and not v:find("@", 1, true)) and v or "dev"
end

-- Un seul frame d'evenements pour tout l'addon.
local eventFrame = CreateFrame("Frame")
ns.eventFrame = eventFrame

-- ---------------------------------------------------------------------------
-- Evenements du jeu (Blizzard). On enveloppe RegisterEvent dans un pcall :
-- si un nom d'evenement changeait sur la build live, l'addon ne casse pas,
-- il ignore l'evenement et le note en debug.
-- ---------------------------------------------------------------------------
local gameHandlers = {}

function ns:RegisterEvent(event, fn)
    gameHandlers[event] = gameHandlers[event] or {}
    table.insert(gameHandlers[event], fn)
    local ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
    if not ok then
        ns:Debug("Evenement inconnu ignore : %s", event)
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = gameHandlers[event]
    if not list then return end
    for _, fn in ipairs(list) do
        local ok, err = pcall(fn, event, ...)
        if not ok then
            ns:Debug("Handler %s : %s", event, tostring(err))
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Bus interne de messages (ex : "WC_JOURNAL_UPDATED"). Ne passe jamais par
-- RegisterEvent : ce sont nos propres signaux, pas des evenements du jeu.
-- ---------------------------------------------------------------------------
local msgHandlers = {}

function ns:OnMessage(msg, fn)
    msgHandlers[msg] = msgHandlers[msg] or {}
    table.insert(msgHandlers[msg], fn)
end

function ns:SendMessage(msg, ...)
    local list = msgHandlers[msg]
    if not list then return end
    for _, fn in ipairs(list) do
        local ok, err = pcall(fn, msg, ...)
        if not ok then
            ns:Debug("Message %s : %s", msg, tostring(err))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Termes officiels du jeu. Pour les mots que Blizzard traduit deja dans ses
-- propres textes (GlobalStrings), on reprend la version du client : exacte
-- dans toutes les langues, y compris celles dont les traductions de l'addon
-- sont a relire. Texte absent, vide ou contenant un format : on garde celui
-- des Locales. Charge apres les Locales (voir WeeklyCompass.toc).
-- ---------------------------------------------------------------------------
do
    local GAME_STRINGS = {
        STAT_CRIT     = "STAT_CRITICAL_STRIKE",
        STAT_HASTE    = "STAT_HASTE",
        STAT_MASTERY  = "STAT_MASTERY",
        STAT_VERSA    = "STAT_VERSATILITY",
        PROFILE_LEVEL = "LEVEL",
        PROFILE_SPEC  = "SPECIALIZATION",
    }
    for key, global in pairs(GAME_STRINGS) do
        local v = rawget(_G, global)
        if type(v) == "string" and v ~= "" and not v:find("[%%|]") then
            ns.L[key] = v
        end
    end
end

-- ---------------------------------------------------------------------------
-- Formats d'affichage partages (onglet Personnages). Separateurs et suffixes
-- viennent des Locales : "204 702 po" en francais, "204,702g" en anglais.
-- ---------------------------------------------------------------------------
local function groupThousands(n)
    local s = tostring(math.floor(n))
    local sep = ns.L["FMT_THOUSANDS"]
    local out = s:reverse():gsub("(%d%d%d)", "%1" .. sep:reverse()):reverse()
    if out:sub(1, #sep) == sep then out = out:sub(#sep + 1) end
    return out
end

-- Or seulement (pieces d'argent et de cuivre ignorees), depuis des pieces de
-- cuivre. withIcon : icone de piece d'or du jeu au lieu du suffixe texte.
local GOLD_ICON = " |TInterface\\MoneyFrame\\UI-GoldIcon:0:0:1:0|t"
function ns.FormatGold(copper, withIcon)
    copper = tonumber(copper) or 0
    return groupThousands(copper / 10000) .. (withIcon and GOLD_ICON or ns.L["FMT_GOLD_SUFFIX"])
end

-- Nombre decimal avec le separateur de la langue ("284,7" en francais).
function ns.FormatDecimal(x)
    return (("%.1f"):format(tonumber(x) or 0):gsub("%.", ns.L["FMT_DECIMAL"]))
end

-- Duree restante en jours / heures (verrouillages).
function ns.FormatDelay(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)
    local d = math.floor(seconds / 86400)
    local h = math.floor((seconds % 86400) / 3600)
    if d > 0 then return ns.L["FMT_DELAY_DH"]:format(d, h) end
    return ns.L["FMT_DELAY_H"]:format(math.max(h, 1))
end

-- ---------------------------------------------------------------------------
-- Log de debug discret. Active via /wc debug. Sur, meme avant le chargement
-- des SavedVariables (le garde court-circuite si la DB n'existe pas encore).
-- ---------------------------------------------------------------------------
function ns:Debug(fmt, ...)
    local db = WeeklyCompassDB
    if not (db and db.global and db.global.debug) then return end
    local msg = select("#", ...) > 0 and fmt:format(...) or fmt
    print("|cff8db4e2WeeklyCompass|r " .. msg)
end
