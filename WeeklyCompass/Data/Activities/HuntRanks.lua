local addonName, ns = ...
local C = ns.Const

-- ===========================================================================
-- Progression des rangs de la Traque. Module en attente : progression et
-- paliers S2 non figes sur le PTR 12.1. Descripteur present pour la visibilite,
-- aucune API appelee, aucun palier invente.
--
-- A implementer une fois la source validee :
--   1. IsAvailable : verifier l'API reelle de progression de rang.
--   2. Poll : emettre une entree avec progress = { current = rang, max = maxRang }
--      et le palier de recompense associe, si l'API l'expose.
--   3. Basculer { key = "huntRanks", enabled = true } dans Data/Activities.lua.
-- ===========================================================================

local module = {
    key      = "huntRanks",
    labelKey = "ACTIVITY_HUNT",
    labelShortKey = "ACTIVITY_HUNT_SHORT",
    category = C.Category.HUNT,
    order    = 10,
    events   = {},
}

function module.IsAvailable()
    return false
end

function module.Poll(emit)
    -- Vide tant que la progression de rang n'est pas confirmee.
end

ns.Registry:Register(module)
