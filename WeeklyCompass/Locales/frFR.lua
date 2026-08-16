local addonName, ns = ...

ns:AddLocale("frFR", {
    -- Activites
    ACTIVITY_GREAT_VAULT  = "Grand Coffre",
    ACTIVITY_LAIRS        = "Repaires de la semaine",
    ACTIVITY_DELVES       = "Gouffres",
    ACTIVITY_HUNT         = "La Traque",

    -- Libelles courts (en-tetes de colonnes de la vue compte)
    ACTIVITY_LAIRS_SHORT  = "Repaires",
    ACTIVITY_DELVES_SHORT = "Gouffres",
    ACTIVITY_HUNT_SHORT   = "Traque",

    -- Grand Coffre
    VAULT_SLOT_MYTHIC     = "Mythique+",
    VAULT_SLOT_RAID       = "Raid",
    VAULT_SLOT_WORLD      = "Monde",
    VAULT_SLOT_GENERIC    = "Suivi",
    VAULT_REWARD_ILVL     = "objet niveau %d obtenu",

    -- Noms des pistes d'amelioration (servent a identifier le palier d'un objet
    -- depuis trackString ; a revalider sur la build 12.1 FR si Blizzard renomme).
    TRACK_NAME_EXPLORER   = "Explorateur",
    TRACK_NAME_ADVENTURER = "Aventurier",
    TRACK_NAME_VETERAN    = "Vétéran",
    TRACK_NAME_CHAMPION   = "Champion",
    TRACK_NAME_HERO       = "Héros",
    TRACK_NAME_MYTH       = "Mythique",

    -- Statuts
    STATUS_DONE           = "Fait",
    STATUS_IN_PROGRESS    = "En cours",
    STATUS_NOT_STARTED    = "A faire",
    STATUS_UNKNOWN        = "Inconnu",

    -- Details
    DETAIL_API_PENDING    = "En attente des donnees de la Saison 2",

    -- Demarrage / minimap
    LOGIN_LOADED          = "%s charge. %d active, %d en attente de la Saison 2. Tape /wc pour ouvrir.",
    MINIMAP_HINT_TOGGLE   = "Clic gauche : ouvrir / fermer le tableau",
    MINIMAP_HINT_DRAG     = "Glisser : deplacer autour de la minicarte",

    -- Interface
    UI_TITLE              = "WeeklyCompass",
    UI_SUBTITLE           = "Vue compte : ce qu'il reste cette semaine",
    UI_HEADER_CHAR        = "Personnage",
    UI_EMPTY              = "Aucune donnee de personnage. Connecte-toi sur tes rerolls pour remplir la vue compte.",
    UI_STALE              = "Donnees anterieures au dernier reset",
    SLASH_HINT            = "Commandes : /wc | /wc dump | /wc minimap | /wc debug",
})
