-- =============================================================================
-- LairLens - Data/Capabilities.lua
-- Qui apporte quoi, par classe.
--
-- HONNETETE : ce sont des heuristiques AU NIVEAU CLASSE. Connaitre la spec exacte
-- des autres joueurs exige l'inspection (NotifyInspect), asynchrone et throttlee,
-- volontairement HORS perimetre v1. Consequence assumee :
--   - une capacite liee a une seule spec (ex. dissipation de maladie du Preventre
--     Sacre) est comptee des que la classe est presente. On peut donc surestimer.
--   - a l'inverse on ne rate jamais une capacite reellement disponible.
-- Ce choix privilegie un audit instantane et sans latence a une precision spec.
--
-- Tout est centralise ici et trivialement editable. A revalider contre 12.1 live.
-- Cles de classe = jeton anglais majuscule renvoye par UnitClass (2e retour).
-- =============================================================================

local ADDON, LL = ...
local C = LL.const

LL.Capabilities = {}
local Cap = LL.Capabilities

-- Rez de combat (bat res). Set stable recent : DK, Druide, Paladin, Demoniste.
-- A revalider si 12.1 ajoute/retire un fournisseur.
Cap.combatRez = {
    DEATHKNIGHT = true, -- Ralliement des morts / Raise Ally
    DRUID       = true, -- Rebirth
    PALADIN     = true, -- Intercession
    WARLOCK     = true, -- Soulstone
}

-- Lust / Hero et equivalents.
Cap.lust = {
    SHAMAN  = true, -- Bloodlust / Heroism
    MAGE    = true, -- Time Warp
    HUNTER  = true, -- Primal Rage (via familier)
    EVOKER  = true, -- Fury of the Aspects
}

-- Interruption a cible. Quasi universelle chez DPS/tanks ; on liste les classes
-- disposant d'au moins une interruption fiable. Volontairement inclusif.
Cap.interrupt = {
    DEATHKNIGHT = true, DEMONHUNTER = true, DRUID = true, EVOKER = true,
    HUNTER = true, MAGE = true, MONK = true, PALADIN = true, PRIEST = true,
    ROGUE = true, SHAMAN = true, WARLOCK = true, WARRIOR = true,
    -- Note : la disponibilite reelle depend souvent de la spec. Heuristique.
}

-- Dissipation, resolue par CLASSE + ROLE. C'est l'axe reellement dependant de
-- la spec, et le role (gratuit via UnitGroupRolesAssigned, sans inspection)
-- capture l'essentiel de cette variance : le kit soigneur est large, le kit
-- non-soigneur reduit. On evite ainsi et la latence de l'inspection, et la
-- surestimation de la classe seule.
--
-- Structure par classe :
--   ANY    = kit identique quelle que soit la spec (ex. Mage : Retirer la malediction).
--   HEALER = kit de la spec soigneuse.
--   OTHER  = kit des specs non soigneuses.
--
-- HONNETETE : c'est la donnee la plus volatile d'un patch a l'autre. A revalider
-- contre 12.1 live. Choix prudents assumes :
--   - Chevalier de la mort : aucun nettoyage d'allie, donc absent (il applique
--     les maladies, il ne les dissipe pas).
--   - Chasseur de demons : Consumer la magie est une purge offensive, pas une
--     dissipation d'allie -> exclu.
--   - Demoniste : dissipation magie liee au familier (Devorer la magie),
--     situationnelle -> exclue par defaut. Decommenter si tu veux la compter.
--   - Pretre Ombre : Dissipation de masse existe mais lourde et situationnelle
--     -> OTHER laisse vide pour ne pas surestimer.
-- On sous-estime donc a la marge plutot que de mentir sur une couverture.
Cap.dispelByClassRole = {
    DRUID   = { HEALER = { [C.DISPEL.MAGIC]=true, [C.DISPEL.CURSE]=true, [C.DISPEL.POISON]=true },
                OTHER  = { [C.DISPEL.CURSE]=true, [C.DISPEL.POISON]=true } },
    PALADIN = { HEALER = { [C.DISPEL.MAGIC]=true, [C.DISPEL.POISON]=true, [C.DISPEL.DISEASE]=true },
                OTHER  = { [C.DISPEL.POISON]=true, [C.DISPEL.DISEASE]=true } },
    PRIEST  = { HEALER = { [C.DISPEL.MAGIC]=true, [C.DISPEL.DISEASE]=true },
                OTHER  = {} },
    SHAMAN  = { HEALER = { [C.DISPEL.MAGIC]=true, [C.DISPEL.CURSE]=true },
                OTHER  = { [C.DISPEL.CURSE]=true } },
    MONK    = { HEALER = { [C.DISPEL.MAGIC]=true, [C.DISPEL.POISON]=true, [C.DISPEL.DISEASE]=true },
                OTHER  = { [C.DISPEL.POISON]=true, [C.DISPEL.DISEASE]=true } },
    EVOKER  = { HEALER = { [C.DISPEL.MAGIC]=true, [C.DISPEL.POISON]=true },
                OTHER  = { [C.DISPEL.POISON]=true } },
    MAGE    = { ANY    = { [C.DISPEL.CURSE]=true } },
    -- WARLOCK = { ANY = { [C.DISPEL.MAGIC]=true } }, -- via familier, a activer si voulu
}

-- Helpers de lecture, pour que la logique n'accede jamais aux tables en dur.
function Cap:HasCombatRez(class) return self.combatRez[class] == true end
function Cap:HasLust(class)      return self.lust[class] == true end
function Cap:HasInterrupt(class) return self.interrupt[class] == true end

-- Renvoie l'ensemble des types dissipables pour une classe et un role donnes.
function Cap:GetDispelSet(class, role)
    local entry = self.dispelByClassRole[class]
    if not entry then return nil end
    if entry.ANY then return entry.ANY end
    if role == "HEALER" then return entry.HEALER end
    return entry.OTHER
end

function Cap:HasDispel(class, role, dispelType)
    local set = self:GetDispelSet(class, role)
    return set ~= nil and set[dispelType] == true
end
