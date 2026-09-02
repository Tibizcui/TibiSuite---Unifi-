local addonName, ns = ...

ns:AddLocale("enUS", {
    ADDON_NAME            = "WeeklyCompass",

    -- Activites
    ACTIVITY_GREAT_VAULT  = "Great Vault",
    ACTIVITY_LAIRS        = "Weekly Lairs",
    ACTIVITY_DELVES       = "Delves",
    ACTIVITY_HUNT         = "The Hunt",

    -- Libelles courts (en-tetes de colonnes de la vue compte)
    ACTIVITY_LAIRS_SHORT  = "Lairs",
    ACTIVITY_DELVES_SHORT = "Delves",
    ACTIVITY_HUNT_SHORT   = "Hunt",

    -- Grand Coffre
    VAULT_SLOT_MYTHIC     = "Mythic+",
    VAULT_SLOT_RAID       = "Raid",
    VAULT_SLOT_WORLD      = "World",
    VAULT_SLOT_GENERIC    = "Track",
    VAULT_REWARD_ILVL     = "item level %d earned",

    -- Upgrade track names (used to identify an item's tier from trackString ;
    -- revalidate on the 12.1 build if Blizzard renames them).
    TRACK_NAME_EXPLORER   = "Explorer",
    TRACK_NAME_ADVENTURER = "Adventurer",
    TRACK_NAME_VETERAN    = "Veteran",
    TRACK_NAME_CHAMPION   = "Champion",
    TRACK_NAME_HERO       = "Hero",
    TRACK_NAME_MYTH       = "Myth",

    -- Statuts
    STATUS_DONE           = "Done",
    STATUS_IN_PROGRESS    = "In progress",
    STATUS_NOT_STARTED    = "To do",
    STATUS_UNKNOWN        = "Unknown",

    -- Details
    DETAIL_API_PENDING    = "Awaiting Season 2 data",

    -- Demarrage / minimap
    LOGIN_LOADED          = "%s loaded. %d active, %d awaiting Season 2. Type /wc to open.",
    MINIMAP_HINT_TOGGLE   = "Left click: open / close the dashboard",
    MINIMAP_HINT_DRAG     = "Drag: move around the minimap",

    -- Interface
    UI_TITLE              = "WeeklyCompass",
    UI_SUBTITLE           = "Account view: what is left this week",
    UI_HEADER_CHAR        = "Character",
    UI_EMPTY              = "No character data yet. Log in on your alts to populate the account view.",
    UI_STALE              = "Data predates the last reset",
    SLASH_HINT            = "Commands: /wc | /wc options | /wc dump | /wc minimap | /wc debug",
})
