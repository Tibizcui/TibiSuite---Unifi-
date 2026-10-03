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
    -- Repaires : le jeu n'expose aucun compteur hebdo (sonde 2026-09-25), mais
    -- LairLens (7.1.5.37) suit chaque difficulte faite. La colonne n'apparait
    -- que si LairLens est charge (Lairs.lua, IsAvailable).
    { key = "lairs",      enabled = true, hidden = function() return _G.LairLensAPI == nil end },
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
--   3443 / 3444 / 3445 / 3446 : Ecus de brume de veteran, de champion,
--   heroique et mythique (releves par la sonde TibiProbe, compte CRJ07 ;
--   ce sont aussi les monnaies des Repaires Monde / Normal / Heroique / Mythique).
ns.SheetCurrencies = { 3442, 3443, 3444, 3445, 3446 }

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
    -- Repaires : aucune source hebdo cote jeu ; LairLens fournit la semaine.
    lairs = {
        { type = "lairlens", shortKey = "ACTIVITY_LAIRS_SHORT" },
    },
}
