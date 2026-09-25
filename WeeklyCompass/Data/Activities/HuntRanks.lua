local addonName, ns = ...
local C = ns.Const

-- ===========================================================================
-- Progression de la Traque. Module PILOTE PAR LA DONNEE.
--
-- Aucune API specifique ici : les compteurs viennent des sources declarees
-- dans ns.ActivitySources.huntRanks (Data/Activities.lua), lues par Core/Sources.lua
-- (monnaie, renom, lot de quetes hebdo). Tant qu'aucune source n'est
-- renseignee, l'activite reste visible en statut "inconnu", sans compteur
-- invente. Les identifiants reels viennent de la sonde _dev/TibiProbe.
-- ===========================================================================

local module = {
    key      = "huntRanks",
    labelKey = "ACTIVITY_HUNT",
    labelShortKey = "ACTIVITY_HUNT_SHORT",
    category = C.Category.HUNT,
    order    = 10,
    events   = ns.Sources.EVENTS,
}

function module.IsAvailable()
    return ns.Sources:HasAny(module.key)
end

function module.Poll(emit)
    ns.Sources:Emit(module, emit)
end

ns.Registry:Register(module)
