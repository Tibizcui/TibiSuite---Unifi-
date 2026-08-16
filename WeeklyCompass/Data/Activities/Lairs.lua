local addonName, ns = ...
local C = ns.Const

-- ===========================================================================
-- Repaires de la semaine. Module en attente : la regle S2 et l'API associee
-- ne sont pas figees sur le PTR 12.1. On expose deja le descripteur (pour que
-- l'activite figure au tableau, en statut "inconnu") mais on n'appelle aucune
-- API et on n'invente aucun seuil.
--
-- A implementer une fois la source validee :
--   1. IsAvailable : verifier l'existence de l'API reelle (a identifier sur le
--      PTR / Wowhead).
--   2. Poll : lire l'etat des repaires de la semaine et emettre une entree par
--      repaire (ou une entree resume), au format du journal commun.
--   3. Basculer { key = "lairs", enabled = true } dans Data/Activities.lua.
-- ===========================================================================

local module = {
    key      = "lairs",
    labelKey = "ACTIVITY_LAIRS",
    labelShortKey = "ACTIVITY_LAIRS_SHORT",
    category = C.Category.LAIRS,
    order    = 10,
    events   = {},   -- a completer avec le(s) evenement(s) reel(s)
}

function module.IsAvailable()
    -- Aucune API confirmee a ce stade : on reste inactif volontairement.
    return false
end

function module.Poll(emit)
    -- Intentionnellement vide tant que la source S2 n'est pas validee.
end

ns.Registry:Register(module)
