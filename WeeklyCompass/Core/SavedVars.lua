local addonName, ns = ...

ns.DB = ns.DB or {}
local DB = ns.DB

local DB_VERSION = 1

-- Cle stable d'un personnage : "Nom - Royaume".
local function charKey()
    local name = UnitName("player") or "?"
    local realm = GetRealmName() or "?"
    return name .. " - " .. realm
end
ns.charKey = charKey

local function initDB()
    WeeklyCompassDB = WeeklyCompassDB or {}
    local db = WeeklyCompassDB

    db.version = db.version or DB_VERSION
    db.global  = db.global or { debug = false }
    db.global.minimap = db.global.minimap or { angle = 220, hidden = false }
    if db.global.login == nil then db.global.login = true end
    db.global.hidden = db.global.hidden or {}        -- [charKey] = true : masque de la vue compte
    if db.global.showHidden == nil then db.global.showHidden = false end
    db.chars   = db.chars or {}

    local key = charKey()
    local char = db.chars[key] or {}
    db.chars[key] = char

    char.name     = UnitName("player")
    char.realm    = GetRealmName()
    char.class    = select(2, UnitClass("player"))   -- token de classe (ex "MAGE")
    char.faction  = UnitFactionGroup("player")
    char.periodId = char.periodId or nil             -- semaine de reference des entrees
    char.entries  = char.entries or {}               -- [entryKey] = entree normalisee
    char.lastSeen = GetServerTime()

    ns.db = db
    ns.char = char
end

function DB:GetChar()      return ns.char end
function DB:GetGlobal()    return ns.db and ns.db.global end
function DB:GetAllChars()  return (ns.db and ns.db.chars) or {} end

-- Masquage : le perso reste en base (ses donnees continuent de se mettre a
-- jour a chaque connexion), il n'apparait simplement plus dans la vue compte.
function DB:IsHidden(key)
    local g = self:GetGlobal()
    return (g and g.hidden and g.hidden[key]) == true
end

function DB:SetHidden(key, hidden)
    local g = self:GetGlobal()
    if not (g and g.hidden) then return end
    g.hidden[key] = hidden and true or nil
end

function DB:UnhideAll()
    local g = self:GetGlobal()
    if g and g.hidden then wipe(g.hidden) end
end

function DB:ShowHidden()
    local g = self:GetGlobal()
    return (g and g.showHidden) == true
end

function DB:SetShowHidden(show)
    local g = self:GetGlobal()
    if g then g.showHidden = show and true or false end
end

-- Oubli : retire le perso de la base. Refuse pour le perso connecte (il serait
-- recree a l'instant). Un perso oublie revient a sa prochaine connexion.
function DB:ForgetChar(key)
    if not ns.db or key == charKey() then return false end
    ns.db.chars[key] = nil
    self:SetHidden(key, false)
    return true
end

ns:RegisterEvent("ADDON_LOADED", function(_, loaded)
    if loaded ~= addonName then return end
    initDB()
    ns:SendMessage("WC_DB_READY")

    -- Rattrapage LoadOnDemand : quand TibiSuite charge WeeklyCompass a la
    -- demande, PLAYER_LOGIN est deja passe et le handler PLAYER_LOGIN du
    -- registre (cablage des evenements + premiere collecte + ticker) ne se
    -- declenchera plus. On rejoue donc ici ce travail fonctionnel si la
    -- connexion est deja effective. Aucun impact sur les donnees.
    if IsLoggedIn() and ns.Registry then
        ns.Registry:WireEvents()
        ns.Registry:RefreshAll()
        C_Timer.NewTicker(300, function() ns.Registry:RefreshAll() end)
    end
end)
