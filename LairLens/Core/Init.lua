-- =============================================================================
-- LairLens - Core/Init.lua
-- Bootstrap du namespace, distribution des evenements, etat persistant.
-- =============================================================================

local ADDON, LL = ...

-- Espaces de noms partages entre tous les fichiers de l'addon.
LL.modules = {}       -- modules enregistres (audit, recompenses, ...)
LL.callbacks = {}     -- abonnes internes par evenement logique
LL.frame = CreateFrame("Frame", "LairLensEventFrame")

-- Valeurs par defaut des SavedVariables. On ne touche jamais directement aux
-- globales avant ADDON_LOADED : elles n'existent pas encore a ce stade.
local ACCOUNT_DEFAULTS = {
    enabled = true,
    audit = {
        locked = false,        -- panneau verrouille en position
        hideOutOfLair = true,  -- masquer hors Repaire
        fadeInCombat = true,   -- s'effacer en combat pour rester discret
        point = { "CENTER", nil, "CENTER", 0, 120 },
        scale = 1.0,
    },
    -- Suivi des runs (module d'historique / dashboard). Stocke au niveau COMPTE
    -- avec un tag "owner" par run : on obtient a la fois la vue par personnage
    -- (filtre owner) et la vue compte agregee (tous owners).
    runTracking = true,
    history = {
        maxRuns = 500,  -- plafond de runs conserves (borne la taille des SavedVariables)
        runs = {},      -- plus recent en tete ; chaque run porte son champ owner
    },
    dashboard = {
        point = { "CENTER", nil, "CENTER", 0, 0 },
        scale = 1.0,
        filterOwner = nil,     -- nil = tous les personnages
        filterDiff = nil,      -- nil = toutes difficultes
        filterInstance = nil,  -- nil = tous les Repaires
    },
    debug = false,
}

local CHAR_DEFAULTS = {
    weekly = {
        resetAt = 0,           -- epoch (s) du prochain reset hebdo connu
        clears = {},           -- [instanceKey] = { [difficultyKey] = true }
    },
}

-- Copie recursive des valeurs manquantes sans ecraser l'existant.
local function applyDefaults(target, defaults)
    if type(target) ~= "table" then target = {} end
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            target[key] = applyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

-- -----------------------------------------------------------------------------
-- Bus d'evenements interne. Les modules s'abonnent a des evenements logiques
-- ("ROSTER_CHANGED", "LAIR_CONTEXT_CHANGED", ...) plutot qu'aux evenements WoW
-- bruts, ce qui garde les modules independants de l'API sous-jacente.
-- -----------------------------------------------------------------------------
function LL:On(event, handler)
    self.callbacks[event] = self.callbacks[event] or {}
    table.insert(self.callbacks[event], handler)
end

function LL:Emit(event, ...)
    local list = self.callbacks[event]
    if not list then return end
    for i = 1, #list do
        -- pcall pour qu'un module fautif n'interrompe pas les autres.
        local ok, err = pcall(list[i], ...)
        if not ok and self.db and self.db.debug then
            print("|cff66bbffLairLens|r erreur sur", event, ":", err)
        end
    end
end

function LL:RegisterModule(name, module)
    self.modules[name] = module
    return module
end

-- -----------------------------------------------------------------------------
-- Reset hebdomadaire. On memorise l'epoch du prochain reset ; a chaque connexion
-- (ou passage de zone) on verifie si on l'a franchi et, si oui, on purge l'etat
-- hebdo puis on recalcule la borne suivante.
-- -----------------------------------------------------------------------------
function LL:GetNextWeeklyReset()
    -- C_DateAndTime.GetSecondsUntilWeeklyReset est disponible sur le client
    -- moderne, mais on le protege : si l'API bouge, l'addon ne casse pas.
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local ok, secs = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
        if ok and type(secs) == "number" and secs > 0 then
            return time() + secs
        end
    end
    return nil -- inconnu : on ne purge rien tant qu'on n'a pas de borne fiable.
end

function LL:CheckWeeklyReset()
    local weekly = self.cdb and self.cdb.weekly
    if not weekly then return end

    local now = time()
    if weekly.resetAt and weekly.resetAt > 0 and now >= weekly.resetAt then
        wipe(weekly.clears)
        weekly.resetAt = 0
        self:Emit("WEEKLY_RESET")
    end

    if not weekly.resetAt or weekly.resetAt == 0 then
        local nextReset = self:GetNextWeeklyReset()
        if nextReset then weekly.resetAt = nextReset end
    end
end

-- -----------------------------------------------------------------------------
-- Cycle de vie.
-- -----------------------------------------------------------------------------
local function onAddonLoaded()
    _G.LairLensDB = applyDefaults(_G.LairLensDB, ACCOUNT_DEFAULTS)
    _G.LairLensCharDB = applyDefaults(_G.LairLensCharDB, CHAR_DEFAULTS)
    LL.db = _G.LairLensDB
    LL.cdb = _G.LairLensCharDB
    LL:Emit("DB_READY")
end

local function onPlayerLogin()
    LL:CheckWeeklyReset()
    LL:Emit("READY")
end

LL.frame:RegisterEvent("ADDON_LOADED")
LL.frame:RegisterEvent("PLAYER_LOGIN")
LL.frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        onAddonLoaded()
        LL.frame:UnregisterEvent("ADDON_LOADED")
        -- Rattrapage LoadOnDemand : quand TibiSuite charge ce module a la
        -- demande, PLAYER_LOGIN est deja passe et onPlayerLogin ci-dessous ne
        -- se declenchera plus. On rejoue donc le travail de login (reset hebdo
        -- + Emit READY qui reveille les modules) si la connexion est deja
        -- effective. Sans impact sur les donnees : CheckWeeklyReset est borne
        -- par une date de reset et reste idempotent.
        if IsLoggedIn() then
            onPlayerLogin()
        end
    elseif event == "PLAYER_LOGIN" then
        onPlayerLogin()
    end
end)
