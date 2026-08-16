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
-- Log de debug discret. Active via /wc debug. Sur, meme avant le chargement
-- des SavedVariables (le garde court-circuite si la DB n'existe pas encore).
-- ---------------------------------------------------------------------------
function ns:Debug(fmt, ...)
    local db = WeeklyCompassDB
    if not (db and db.global and db.global.debug) then return end
    local msg = select("#", ...) > 0 and fmt:format(...) or fmt
    print("|cff8db4e2WeeklyCompass|r " .. msg)
end
