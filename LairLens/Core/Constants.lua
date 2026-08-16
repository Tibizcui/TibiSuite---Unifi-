-- =============================================================================
-- LairLens - Core/Constants.lua
-- Cles stables reutilisees partout. On travaille avec des cles internes propres
-- (jamais des chaines localisees) pour que la logique reste independante de la
-- langue et des identifiants exacts de l'API.
-- =============================================================================

local ADDON, LL = ...

LL.const = {}
local C = LL.const

-- Difficultes des Repaires (confirmees par les previews 12.1 : Monde, Normal,
-- Heroique, Mythique flex 15-25). Les difficultyID numeriques renvoyes par
-- GetInstanceInfo ne sont PAS encore confirmes publiquement pour les Repaires,
-- ils sont donc mappes dans Detection.lua, pas ici.
C.DIFF = {
    WORLD   = "world",
    NORMAL  = "normal",
    HEROIC  = "heroic",
    MYTHIC  = "mythic",
}

-- Ordre d'affichage / de progression.
C.DIFF_ORDER = { C.DIFF.WORLD, C.DIFF.NORMAL, C.DIFF.HEROIC, C.DIFF.MYTHIC }

-- Roles normalises (alignes sur les retours de UnitGroupRolesAssigned).
C.ROLE = {
    TANK    = "TANK",
    HEALER  = "HEALER",
    DAMAGER = "DAMAGER",
    NONE    = "NONE",
}

-- Types de dissipation suivis par le module d'audit.
C.DISPEL = {
    MAGIC   = "magic",
    CURSE   = "curse",
    POISON  = "poison",
    DISEASE = "disease",
}
C.DISPEL_ORDER = { C.DISPEL.MAGIC, C.DISPEL.CURSE, C.DISPEL.POISON, C.DISPEL.DISEASE }

-- Verdict global du module d'audit.
C.VERDICT = {
    VIABLE  = "viable",   -- vert : rien de bloquant
    RISKY   = "risky",    -- orange : manque du confort mais jouable
    MISSING = "missing",  -- rouge : lacune structurante (ex. zero rez de combat)
}

-- Couleurs maison, sobres. Format {r, g, b} sur 0..1.
C.COLOR = {
    [C.VERDICT.VIABLE]  = { 0.40, 0.78, 0.45 },
    [C.VERDICT.RISKY]   = { 0.90, 0.68, 0.30 },
    [C.VERDICT.MISSING] = { 0.86, 0.36, 0.36 },
    TEXT    = { 0.92, 0.92, 0.90 },
    MUTED   = { 0.60, 0.62, 0.66 },
    ACCENT  = { 1.00, 1.00, 1.00 },  -- blanc pretre (#FFFFFF) : couleur identitaire LairLens
}

-- Resultat d'un run de Repaire (module d'historique).
C.RUN = {
    KILL       = "kill",        -- boss vaincu au moins une fois pendant le run
    INCOMPLETE = "incomplete",  -- run quitte sans kill
}

C.ADDON_TAG = "|cff66bbffLairLens|r"
