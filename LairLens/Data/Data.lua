-- =============================================================================
-- LairLens - Data/Data.lua
-- Pilotage par la donnee. Taxonomie maison : Extension > Type > Instance > Boss,
-- adaptee au cas des Repaires (un Repaire = une Instance a boss unique).
--
-- Regle d'or : ce fichier ne fait AUCUN appel a l'API du jeu. C'est de la donnee
-- pure, editable a la main. Tout ce qui touche l'API reelle (detection,
-- difficultyID, lockouts, journal) vit dans Core/Abstraction/*.
--
-- Mise a jour 12.1 live (2026-10-03). Sources : annonce officielle Blizzard
-- "Step Into Lairs" (ilvl recommande et ilvl du butin), method.gg (entree),
-- Icy Veins (tailles de groupe). Monnaies relevees EN JEU par la sonde
-- _dev/TibiProbe (TibiProbeDB, compte CRJ07) : Ecus de brume 3443 a 3446.
-- Nom francais "La grotte des Marees" releve dans LvlHistoryDB (zone visitee
-- par Tibiscui), donc vu en jeu, pas traduit a la main.
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
-- Fiche par difficulte (12.1 live, annonce officielle Blizzard).
--   rec      : ilvl recommande pour entrer.
--   ilvl     : ilvl du butin.
--   crest    : monnaie (Ecu de brume) donnee a cette difficulte (ID verifie en jeu).
--   track    : piste d'amelioration (cle de Locales TRACK_*).
--   loot     : "personal" = butin automatique facon boss mondial (Monde),
--              "group"    = butin a tirer comme un boss de raid (Normal et plus).
--   min, max : taille de groupe acceptee (Blizzard : 5-40, Mythique 15-25).
--   ejDiff   : difficultyID du Journal des rencontres pour le filtre de butin
--              (identifiants de raid flex standards ; Monde : aucun, le
--              journal affiche alors son butin par defaut).
--   vault    : le kill compte comme activite de raid dans la Grande Chambre forte.
-- -----------------------------------------------------------------------------
D.difficultyInfo = {
    [C.DIFF.WORLD]  = { rec = 273, ilvl = 279, crest = 3443, track = "TRACK_VETERAN",  loot = "personal", min = 5,  max = 40, ejDiff = nil, vault = true },
    [C.DIFF.NORMAL] = { rec = 286, ilvl = 292, crest = 3444, track = "TRACK_CHAMPION", loot = "group",    min = 5,  max = 40, ejDiff = 14,  vault = true },
    [C.DIFF.HEROIC] = { rec = 299, ilvl = 305, crest = 3445, track = "TRACK_HERO",     loot = "group",    min = 5,  max = 40, ejDiff = 15,  vault = true },
    [C.DIFF.MYTHIC] = { rec = 312, ilvl = 318, crest = 3446, track = "TRACK_MYTH",     loot = "group",    min = 15, max = 25, ejDiff = 16,  vault = true },
}

function D:GetDifficultyInfo(difficultyKey)
    return difficultyKey and self.difficultyInfo[difficultyKey] or nil
end

-- -----------------------------------------------------------------------------
-- Taxonomie du contenu : Extension > Type > Instance > Boss.
--
-- 12.1 live : un seul Repaire, La grotte des Marees (The Tidebound Grotto), boss
-- Nymrissa Wavecaller, sous l'epave de Gral's Belly au sud de l'Ile annelee.
-- Kith'ix (12.1.5) est un raid a un boss, PAS un Repaire : il n'a rien a faire ici.
--
-- Les identifiants techniques non publics (instanceMapID, journalInstanceID,
-- encounterID) ne sont pas devines : Core/Abstraction/Journal.lua les lit dans
-- le Journal des rencontres du client et Detection.lua les memorise au premier
-- passage (LairLensDB.learned).
-- -----------------------------------------------------------------------------
D.extension = {
    key = "midnight",
    name = "Midnight",
    patch = "12.1",

    types = {
        lair = {
            key = "lair",
            name = "Repaire",
            difficulties = { C.DIFF.WORLD, C.DIFF.NORMAL, C.DIFF.HEROIC, C.DIFF.MYTHIC },

            instances = {
                tidebound_grotto = {
                    key = "tidebound_grotto",
                    -- Repli d'affichage ; le nom localise vient du journal en jeu.
                    name = "The Tidebound Grotto",
                    names = {
                        enUS = "The Tidebound Grotto",
                        frFR = "La grotte des Marées",   -- vu en jeu (LvlHistoryDB)
                    },

                    areaID = 16671, -- AreaTable ID (Wowhead zone=16671). PAS l'instanceMapID.

                    -- Noms d'instance possibles renvoyes par GetInstanceInfo (1er
                    -- retour), compares apres repliement (accents, casse). Les autres
                    -- langues sont couvertes par le journal et l'apprentissage.
                    matchNames = {
                        "The Tidebound Grotto", "Tidebound Grotto",
                        "La grotte des Marées", "Grotte des Marées",
                    },
                    -- Fragment du nom du boss (nom propre, identique dans les
                    -- langues latines) : sert a retrouver le Repaire dans le
                    -- journal et ses hauts faits.
                    bossFragment = "nymrissa",

                    -- VERIFIES EN JEU par /ll probe (2026-10-03, build 12.1.0.69933,
                    -- client frFR) : instanceMapID de GetInstanceInfo, jid du
                    -- journal, carte interieure 2632, file LFG 3245.
                    instanceMapID = 2987,
                    journalInstanceID = 1317,
                    innerUiMapID = 2632,
                    lfgDungeonID = 3245,

                    -- Entree (method.gg, a confirmer en jeu) : Ile annelee 2512.
                    entrance = { uiMapID = 2512, x = 59.86, y = 66.28 },

                    -- 5 hauts faits annonces (vaincre, Heroique, Mythique, version
                    -- guilde Normal+ et Mythique). Leurs IDs sont lus en jeu.
                    achievementCount = 5,

                    bosses = {
                        {
                            key = "nymrissa_wavecaller",
                            name = "Nymrissa Wavecaller",
                            npcID = 252959,    -- VERIFIE (Wowhead npc=252959). ID de creature.
                            -- VERIFIES EN JEU (/ll probe 2026-10-03) : DungeonEncounterID
                            -- (celui d'ENCOUNTER_END) et ID de rencontre du journal.
                            -- Nom francais du journal : "Nymrissa Mande-vagues".
                            encounterID = 3379,
                            journalEncounterID = 2849,
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

-- Le seul Repaire connu quand il n'y en a qu'un (sert de repli a la detection
-- par C_DelvesUI.IsInLair, qui dit "dans un Repaire" sans dire lequel).
function D:GetSingleLair()
    local only
    for key in pairs(self:GetInstances("lair") or {}) do
        if only then return nil end
        only = key
    end
    return only
end

-- Nom affiche : journal du client > nom de la langue > repli anglais.
function D:GetLairName(instanceKey)
    local inst = self:GetInstance("lair", instanceKey)
    if not inst then return instanceKey or "?" end
    local j = LL.db and LL.db.learned and LL.db.learned.journal and LL.db.learned.journal[instanceKey]
    if j and j.name and j.name ~= "" then return j.name end
    local loc = GetLocale and GetLocale() or "enUS"
    return (inst.names and inst.names[loc]) or inst.name
end

function D:GetBossName(instanceKey)
    local inst = self:GetInstance("lair", instanceKey)
    if not inst then return "?" end
    local j = LL.db and LL.db.learned and LL.db.learned.journal and LL.db.learned.journal[instanceKey]
    if j and j.boss and j.boss ~= "" then return j.boss end
    return inst.bosses and inst.bosses[1] and inst.bosses[1].name or "?"
end
