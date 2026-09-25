local addonName, ns = ...

-- Manifeste pilote par la donnee.
--
-- C'est ICI qu'on active, desactive ou reordonne une activite, sans jamais
-- toucher au journal, au registre ni a l'interface. "reason" / "reasonKey"
-- documente pourquoi une activite affiche encore un statut "inconnu".
--
-- Ajouter une activite = deposer un module dans Data/Activities/, l'inscrire
-- dans le .toc, et l'ajouter ici.
ns.ActivityManifest = {
    { key = "greatVault", enabled = true },
    { key = "lairs",      enabled = true, reasonKey = "DETAIL_SOURCES_PENDING" },
    { key = "delves",     enabled = true, reasonKey = "DETAIL_SOURCES_PENDING" },
    { key = "huntRanks",  enabled = true, reasonKey = "DETAIL_SOURCES_PENDING" },
}

-- Sources des activites pilotees par la donnee (lues par Core/Sources.lua).
--
-- Aucun identifiant n'est devine : chacun a ete releve en jeu par la sonde
-- _dev/TibiProbe (build 120100, 2026-09-25). Une activite sans source reste
-- visible en statut "inconnu" avec DETAIL_SOURCES_PENDING.
--
-- A REVOIR A CHAQUE SAISON : les renoms de Gouffres / Traque changent d'ID a
-- chaque saison (ex : Gouffres S1 = 2742, S2 = 2796 pour Midnight).
--
-- Formats :
--   { type = "currency", id = 1234 }
--   { type = "renown",   id = 1234 }
--   { type = "quests",   ids = { 11111, 22222 }, need = 1, labelKey = "..." }
-- shortKey (optionnel) : cle de Locales pour l'en-tete de colonne.
ns.ActivitySources = {
    delves = {
        -- Fragments de clé de coffre : plafond hebdo 600 (releve : 35/600).
        { type = "currency", id = 3310, shortKey = "SRC_COFFER_SHARDS_SHORT" },
        -- Renom "Gouffres saison 2" (Midnight, expansionID 11).
        { type = "renown",   id = 2796, shortKey = "SRC_DELVES_RENOWN_SHORT" },
    },
    huntRanks = {
        -- Renom "Traque saison 1" (Midnight) : les rangs de la Traque.
        { type = "renown",   id = 2764, shortKey = "SRC_HUNT_RENOWN_SHORT" },
    },
    -- Repaires : aucune source hebdo reperee par la sonde. Seuls des etats
    -- existent (C_DelvesUI.HasActiveLair / IsInLair), pas de compteur.
    lairs = {},
}
