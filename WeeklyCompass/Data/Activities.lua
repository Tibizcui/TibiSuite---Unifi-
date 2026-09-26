local addonName, ns = ...

-- Manifeste pilote par la donnee.
--
-- C'est ICI qu'on active, desactive ou reordonne une activite, sans jamais
-- toucher au journal, au registre ni a l'interface. "reason" / "reasonKey"
-- documente pourquoi une activite affiche encore un statut "inconnu".
-- "hidden = true" retire completement l'activite du tableau (pas de colonne
-- "?"), a utiliser quand le jeu n'expose aucun compteur exploitable.
--
-- Ajouter une activite = deposer un module dans Data/Activities/, l'inscrire
-- dans le .toc, et l'ajouter ici.
ns.ActivityManifest = {
    { key = "greatVault", enabled = true },
    -- Repaires : aucun compteur hebdo cote jeu (sonde 2026-09-25), la colonne
    -- restait toujours a "?". Retiree du tableau jusqu'a ce qu'une source existe.
    { key = "lairs",      enabled = false, hidden = true },
    { key = "delves",     enabled = true, reasonKey = "DETAIL_SOURCES_PENDING" },
    { key = "huntRanks",  enabled = true, reasonKey = "DETAIL_SOURCES_PENDING" },
    -- Onglet Personnages (fiche persistante, magasin "snapshot").
    { key = "profile",    enabled = true },
    { key = "keystone",   enabled = true },
    { key = "lockouts",   enabled = true },
    -- Fiche detaillee (clic gauche sur un nom), jamais affichee en colonne.
    { key = "sheet",      enabled = true },
}

-- Monnaies de la saison affichees dans la fiche detaillee. Identifiants
-- releves par la sonde ; A REVOIR A CHAQUE SAISON, comme les renoms.
--   3442 : Ecu de brume d'aventure (saison 2 Midnight, plafond cumule 700).
-- Les autres ecus de la saison 2 (veteran, champion, heroique, mythique) ne
-- sont pas encore reperes : a completer des qu'un perso en aura ramasse.
ns.SheetCurrencies = { 3442 }

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
