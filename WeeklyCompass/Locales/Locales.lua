local addonName, ns = ...

-- Table de localisation. Base = enUS, les autres langues surchargent les cles.
-- Si une cle manque, on renvoie la cle elle-meme : elle reste visible en jeu,
-- donc un oubli de traduction saute aux yeux au lieu d'afficher du vide.
local L = setmetatable({}, {
    __index = function(_, k) return k end,
})
ns.L = L

-- Aide au remplissage. enUS s'applique toujours (socle) ; une autre langue ne
-- s'applique que si c'est la langue active du client.
function ns:AddLocale(locale, tbl)
    if locale ~= "enUS" and GetLocale() ~= locale then return end
    for k, v in pairs(tbl) do
        L[k] = v
    end
end
