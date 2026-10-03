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

-- Repliement pour comparer des libelles du jeu dans toutes les langues :
-- minuscules ASCII, accents latins retires, apostrophes typographiques
-- ramenees a "'", espaces compactes. "Héroïque" -> "heroique",
-- "La Grotte des Marées" -> "la grotte des marees". Les alphabets non latins
-- (cyrillique, coreen, chinois) passent tels quels : la detection ne s'y fie
-- pas, elle apprend les identifiants numeriques au premier passage.
local FOLD = {
    ["à"]="a", ["á"]="a", ["â"]="a", ["ä"]="a", ["ã"]="a", ["å"]="a",
    ["À"]="a", ["Á"]="a", ["Â"]="a", ["Ä"]="a", ["Ã"]="a", ["Å"]="a",
    ["ç"]="c", ["Ç"]="c",
    ["è"]="e", ["é"]="e", ["ê"]="e", ["ë"]="e", ["È"]="e", ["É"]="e", ["Ê"]="e", ["Ë"]="e",
    ["ì"]="i", ["í"]="i", ["î"]="i", ["ï"]="i", ["Ì"]="i", ["Í"]="i", ["Î"]="i", ["Ï"]="i",
    ["ñ"]="n", ["Ñ"]="n",
    ["ò"]="o", ["ó"]="o", ["ô"]="o", ["ö"]="o", ["õ"]="o", ["Ò"]="o", ["Ó"]="o", ["Ô"]="o", ["Ö"]="o", ["Õ"]="o",
    ["ù"]="u", ["ú"]="u", ["û"]="u", ["ü"]="u", ["Ù"]="u", ["Ú"]="u", ["Û"]="u", ["Ü"]="u",
    ["ß"]="ss", ["œ"]="oe", ["Œ"]="oe", ["æ"]="ae", ["Æ"]="ae",
    ["’"]="'", ["‘"]="'", ["\194\160"]=" ", ["\226\128\175"]=" ",
}

function U.Fold(s)
    if type(s) ~= "string" then return "" end
    s = s:gsub("[\192-\244][\128-\191]*", function(c) return FOLD[c] end)
    s = s:lower():gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    return s
end

-- Vrai si la chaine repliee `hay` contient le fragment replie `needle`.
function U.FoldFind(hay, needle)
    if not needle or needle == "" then return false end
    return U.Fold(hay):find(U.Fold(needle), 1, true) ~= nil
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
