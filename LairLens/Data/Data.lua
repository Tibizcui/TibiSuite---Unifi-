-- =============================================================================
-- LairLens - Data/Data.lua
-- Pilotage par la donnee. Taxonomie maison : Extension > Type > Instance > Boss,
-- adaptee au cas des Repaires (un Repaire = une Instance a boss unique).
--
-- Regle d'or : ce fichier ne fait AUCUN appel a l'API du jeu. C'est de la donnee
-- pure, editable a la main quand le PTR se stabilise. Tout ce qui touche l'API
-- reelle (detection, difficultyID, lockouts) vit dans Core/Abstraction/*.
-- =============================================================================

local ADDON, LL = ...
local C = LL.const

LL.Data = {}
local D = LL.Data

-- -----------------------------------------------------------------------------
-- Attentes d'audit par difficulte.
--
-- Elles decrivent ce qu'un groupe "sain" devrait embarquer. Volontairement
-- exprimees en regles simples et tunables, pas en dur dans la logique.
--
--  tanks        : nombre de tanks attendu.
--  healersRatio : soigneurs attendus = ceil(taille * ratio).
--  needCombatRez: un rez de combat est-il structurant a cette difficulte ?
--  needLust     : le Lust est-il structurant ?
--  needInterrupt: la couverture interruption est-elle structurante ?
--
-- Valeurs de depart raisonnables pour un boss unique en flex. A ajuster contre
-- le tuning 12.1 live (les Repaires sont flagges "loot/tuning not final").
-- -----------------------------------------------------------------------------
D.expectations = {
    [C.DIFF.WORLD] = {
        tanks = 1, healersRatio = 0.10,
        needCombatRez = false, needLust = false, needInterrupt = false,
    },
    [C.DIFF.NORMAL] = {
        tanks = 1, healersRatio = 0.15,
        needCombatRez = false, needLust = false, needInterrupt = true,
    },
    [C.DIFF.HEROIC] = {
        tanks = 2, healersRatio = 0.20,
        needCombatRez = true, needLust = true, needInterrupt = true,
    },
    [C.DIFF.MYTHIC] = {
        tanks = 2, healersRatio = 0.20,
        needCombatRez = true, needLust = true, needInterrupt = true,
    },
}

-- Repli si une difficulte inconnue remonte de l'API (robustesse).
D.defaultExpectation = D.expectations[C.DIFF.HEROIC]

function D:GetExpectation(difficultyKey)
    return self.expectations[difficultyKey] or self.defaultExpectation
end

-- -----------------------------------------------------------------------------
-- Taxonomie du contenu : Extension > Type > Instance > Boss.
--
-- Une seule extension active en v1 (Midnight). Un seul type (lair). Le premier
-- Repaire confirme sur PTR est le Tidebound Grotto (boss Nymrissa Wavecaller).
-- Les autres Repaires s'ajouteront ici au fil des builds.
--
-- Les identifiants techniques encore inconnus (mapID d'instance, journalInstanceID
-- Encounter Journal, etc.) sont laisses a `nil` et resolus par la couche
-- d'abstraction. On ne devine pas de valeurs numeriques.
-- -----------------------------------------------------------------------------
D.extension = {
    key = "midnight",
    name = "Midnight",
    patch = "12.1",

    types = {
        lair = {
            key = "lair",
            name = "Repaire",
            -- Les Repaires acceptent les 4 difficultes confirmees.
            difficulties = { C.DIFF.WORLD, C.DIFF.NORMAL, C.DIFF.HEROIC, C.DIFF.MYTHIC },

            instances = {
                tidebound_grotto = {
                    key = "tidebound_grotto",
                    name = "Tidebound Grotto",

                    -- Identifiants VERIFIES sur le PTR (Wowhead / Warcraft Wiki, 12.1.0) :
                    areaID = 16671, -- AreaTable ID (Wowhead zone=16671, Wago db2/AreaTable).
                                    -- ATTENTION : c'est un AreaTable ID, PAS l'instanceMapID
                                    -- renvoye par GetInstanceInfo. Ne pas confondre.

                    -- Noms d'instance possibles renvoyes par GetInstanceInfo (1er retour).
                    -- Sert a la detection par nom tant que l'instanceMapID reel n'est
                    -- pas connu. Confirme en enUS ; ajouter les autres locales au besoin.
                    matchNames = { "The Tidebound Grotto", "Tidebound Grotto" },

                    -- NON confirmes publiquement (Repaires flagges "later PTR build") :
                    instanceMapID = nil,     -- Map.db2 ID (retour de GetInstanceInfo). A confirmer.
                    journalInstanceID = nil, -- Encounter Journal. A confirmer.

                    bosses = {
                        {
                            key = "nymrissa_wavecaller",
                            name = "Nymrissa Wavecaller",
                            npcID = 252959,    -- VERIFIE (Wowhead npc=252959). ID de creature.
                            encounterID = nil, -- DungeonEncounterID (ENCOUNTER_END/EJ). NON l'npcID. A confirmer.
                        },
                    },
                },
            },
        },
    },
}

-- Acces pratique : liste des instances d'un type.
function D:GetInstances(typeKey)
    local t = self.extension.types[typeKey]
    return t and t.instances or nil
end

function D:GetInstance(typeKey, instanceKey)
    local instances = self:GetInstances(typeKey)
    return instances and instances[instanceKey] or nil
end
