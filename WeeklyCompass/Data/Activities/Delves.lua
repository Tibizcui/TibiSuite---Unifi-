local addonName, ns = ...
local C = ns.Const

-- ===========================================================================
-- Gouffres, y compris variantes Nemesis et Bountiful. Module en attente.
--
-- Piste reperee, A CONFIRMER : le namespace C_DelvesUI existe sur la build 12.1
-- (nouvelles fonctions listees dans les changements d'API 12.1.0, ex autour des
-- compagnons / curios). Cela ne dit rien encore des seuils hebdomadaires ni de
-- la maniere de distinguer les variantes Nemesis / Bountiful. Tant que ce n'est
-- pas verifie en jeu, on n'appelle rien et on n'invente pas de compteur.
--
-- A implementer une fois la source validee :
--   1. IsAvailable : verifier la ou les fonctions reellement disponibles.
--   2. Poll : emettre une entree "Gouffres", plus des entrees dediees aux
--      variantes Nemesis et Bountiful si elles ont leur propre boucle de reset.
--   3. Basculer { key = "delves", enabled = true } dans Data/Activities.lua.
-- ===========================================================================

local module = {
    key      = "delves",
    labelKey = "ACTIVITY_DELVES",
    labelShortKey = "ACTIVITY_DELVES_SHORT",
    category = C.Category.DELVES,
    order    = 10,
    events   = {},
}

function module.IsAvailable()
    return false
end

function module.Poll(emit)
    -- Vide tant que les seuils et la distinction des variantes ne sont pas surs.
end

ns.Registry:Register(module)
