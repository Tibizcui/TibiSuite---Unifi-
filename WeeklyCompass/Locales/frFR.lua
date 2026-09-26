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
    VAULT_SLOT_DUNGEONS   = "Donjons",
    VAULT_SLOT_RAID       = "Raid",
    VAULT_SLOT_WORLD      = "Monde",
    VAULT_SLOT_GENERIC    = "Suivi",
    VAULT_REWARD_ILVL     = "objet niveau %d obtenu",
    VAULT_CLAIM_LABEL     = "Grand Coffre : récompense à récupérer",
    VAULT_CLAIM_SHORT     = "Récompense",
    VAULT_CLAIM_CELL      = "À récupérer",
    VAULT_CLAIM_PROBABLE_CELL = "À récupérer ?",
    VAULT_CLAIM_PROBABLE_TIP  = "Déduction : ce personnage avait débloqué des emplacements du Grand Coffre avant le reset et ne s'est pas reconnecté depuis.",
    VAULT_SLOT_LINE       = "Emplacement %d : %d/%d",
    VAULT_NEXT_SLOT       = "Prochain emplacement : encore %d %s",
    VAULT_ALL_SLOTS       = "Tous les emplacements sont débloqués",
    VAULT_UNIT_DUNGEONS   = "donjon(s)",
    VAULT_UNIT_RAID       = "boss",
    VAULT_UNIT_WORLD      = "activité(s)",
    VAULT_UNIT_GENERIC    = "étape(s)",

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
    STATUS_NOT_STARTED    = "À faire",
    STATUS_UNKNOWN        = "Inconnu",

    -- Details
    DETAIL_API_PENDING    = "En attente des données du jeu",
    DETAIL_SOURCES_PENDING = "Pas encore suivi",
    DETAIL_RENOWN_RANK    = "Rang %d",
    SRC_COFFER_SHARDS_SHORT = "Fragments de clé",
    SRC_DELVES_RENOWN_SHORT = "Renom Gouffres",
    SRC_HUNT_RENOWN_SHORT   = "Rang Traque",

    -- Demarrage / minimap
    LOGIN_LOADED          = "%s chargé : %d activités suivies, %d en attente. Tape /wc pour ouvrir.",
    MINIMAP_HINT_TOGGLE   = "Clic gauche : ouvrir / fermer le tableau",
    MINIMAP_HINT_DRAG     = "Glisser : déplacer autour de la minicarte",

    -- Interface
    UI_TITLE              = "WeeklyCompass",
    UI_SUBTITLE           = "Vue compte : ce qu'il reste cette semaine",
    UI_HEADER_CHAR        = "Personnage",
    UI_EMPTY              = "Aucune donnée de personnage. Connecte-toi sur tes rerolls pour remplir la vue compte.",
    UI_ALL_HIDDEN         = "Tous tes personnages sont masqués. Coche « Afficher les personnages masqués » dans les options.",
    UI_STALE              = "Données antérieures au dernier reset",
    UI_HIDDEN_TAG         = "(masqué)",
    SLASH_HINT            = "Commandes : /wc | /wc options | /wc dump | /wc minimap | /wc debug",

    -- Infobulles et menu
    TIP_UPDATED           = "Mis à jour : %s",
    TIP_LAST_SEEN         = "Dernière connexion : %s",
    TIP_RIGHT_CLICK       = "Clic droit : masquer ou oublier",
    MENU_HIDE             = "Masquer ce personnage",
    MENU_UNHIDE           = "Réafficher ce personnage",
    MENU_FORGET           = "Oublier ce personnage (revient à sa prochaine connexion)",

    -- Options
    OPT_TITLE             = "WeeklyCompass - Options",
    OPT_SECTION_WINDOW    = "Fenêtre",
    OPT_TOGGLE            = "Ouvrir / fermer",
    OPT_RECENTER          = "Recentrer la fenêtre",
    OPT_REFRESH           = "Rafraîchir les activités",
    OPT_SECTION_CHARS     = "Personnages",
    OPT_SHOW_HIDDEN       = "Afficher les personnages masqués",
    OPT_UNHIDE_ALL        = "Réafficher tous les personnages",
    OPT_CHARS_NOTE        = "Clic droit sur le nom d'un personnage dans le tableau pour le masquer ou l'oublier.",
    OPT_SECTION_FLOAT     = "Boutons flottants (barre TibiSuite)",
    OPT_HIDE_OPTIONS      = "Masquer le bouton Options",
    OPT_HIDE_SEARCH       = "Masquer le champ Recherche",
    OPT_FLOAT_NOTE        = "Le bouton Options et le champ Recherche débordent au-dessus de la fenêtre. Même masqués, Maj+clic droit sur la fenêtre ouvre ces options.",
    OPT_TAB_TIP           = "Astuce : clic droit sur l'onglet Weekly dans la barre TibiSuite ouvre aussi ces options.",
})
