-- =============================================================================
-- LairLens - Core/Util.lua
-- Utilitaires transverses : localisation, couleurs, throttle.
-- =============================================================================

local ADDON, LL = ...
local C = LL.const

LL.util = {}
local U = LL.util

-- Table de localisation remplie par les fichiers Locales/*.
LL.L = setmetatable({}, {
    -- Si une cle manque dans la langue courante, on renvoie la cle elle-meme :
    -- l'interface reste lisible meme si une traduction a ete oubliee.
    __index = function(t, k) return k end,
})

-- Colorise une chaine avec un triplet {r,g,b}.
function U.Colorize(text, color)
    if not color then return text end
    local r = math.floor((color[1] or 1) * 255 + 0.5)
    local g = math.floor((color[2] or 1) * 255 + 0.5)
    local b = math.floor((color[3] or 1) * 255 + 0.5)
    return string.format("|cff%02x%02x%02x%s|r", r, g, b, text)
end

-- Applique une couleur a un FontString.
function U.SetTextColor(fontString, color)
    if fontString and color then
        fontString:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1)
    end
end

-- Throttle simple : renvoie une fonction qui n'execute callback qu'une fois par
-- fenetre de `delay` secondes, meme si sollicitee en rafale (utile sur les
-- rafales de GROUP_ROSTER_UPDATE a l'entree d'instance).
function U.Debounce(delay, callback)
    local pending = false
    return function(...)
        if pending then return end
        pending = true
        local args = { ... }
        C_Timer.After(delay, function()
            pending = false
            callback(unpack(args))
        end)
    end
end

function U.Print(...)
    print(C.ADDON_TAG, ...)
end

-- Formatte une duree en secondes de facon compacte : "1h05", "12m30", "45s".
function U.FormatDuration(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    if h > 0 then return string.format("%dh%02d", h, m) end
    if m > 0 then return string.format("%dm%02d", m, s) end
    return string.format("%ds", s)
end

-- Date lisible depuis un epoch (secondes). Protege si l'epoch est absent.
function U.FormatDate(epoch)
    if not epoch or epoch <= 0 then return "" end
    return date("%d/%m %H:%M", epoch)
end

-- Couleur de classe {r,g,b} depuis le jeton EN (WARRIOR, PRIEST, ...).
-- Repli sur la couleur de texte si le jeton est inconnu ou la table absente
-- (par ex. dans le harnais de test hors-jeu).
function U.ClassColor(classToken)
    local t = _G.RAID_CLASS_COLORS
    local c = classToken and t and t[classToken]
    if c then return { c.r, c.g, c.b } end
    return C.COLOR.TEXT
end
