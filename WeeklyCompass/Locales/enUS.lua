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
    VAULT_SLOT_DUNGEONS = "Dungeons",
    VAULT_SLOT_RAID       = "Raid",
    VAULT_SLOT_WORLD      = "World",
    VAULT_SLOT_GENERIC    = "Track",
    VAULT_REWARD_ILVL     = "item level %d unlocked",
    VAULT_CLAIM_LABEL     = "Great Vault: reward to claim",
    VAULT_CLAIM_SHORT     = "Vault reward",
    VAULT_CLAIM_CELL      = "To claim",

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
    DETAIL_API_PENDING    = "Awaiting game data",
    DETAIL_SOURCES_PENDING = "Not tracked yet",
    DETAIL_RENOWN_RANK    = "Rank %d",
    SRC_COFFER_SHARDS_SHORT = "Key shards",
    SRC_DELVES_RENOWN_SHORT = "Delve renown",
    SRC_HUNT_RENOWN_SHORT   = "Hunt rank",

    -- Demarrage / minimap
    LOGIN_LOADED          = "%s loaded: %d activities tracked, %d pending. Type /wc to open.",
    MINIMAP_HINT_TOGGLE   = "Left click: open / close the dashboard",
    MINIMAP_HINT_DRAG     = "Drag: move around the minimap",

    -- Interface
    UI_TITLE              = "WeeklyCompass",
    UI_SUBTITLE           = "Account view: what is left this week",
    UI_HEADER_CHAR        = "Character",
    UI_EMPTY              = "No character data yet. Log in on your alts to populate the account view.",
    UI_STALE              = "Data predates the last reset",
    SLASH_HINT            = "Commands: /wc | /wc options | /wc dump | /wc minimap | /wc debug",
    UI_ALL_HIDDEN         = "All your characters are hidden. Tick \"Show hidden characters\" in the options.",
    UI_HIDDEN_TAG         = "(hidden)",

    -- Great Vault details
    VAULT_CLAIM_PROBABLE_CELL = "To claim?",
    VAULT_CLAIM_PROBABLE_TIP  = "Deduced: this character had unlocked Great Vault slots before the reset and has not logged in since.",
    VAULT_SLOT_LINE       = "Slot %d: %d/%d",
    VAULT_NEXT_SLOT       = "Next slot: %d more %s",
    VAULT_ALL_SLOTS       = "All slots unlocked",
    VAULT_UNIT_DUNGEONS   = "dungeon(s)",
    VAULT_UNIT_RAID       = "boss(es)",
    VAULT_UNIT_WORLD      = "activity(ies)",
    VAULT_UNIT_GENERIC    = "step(s)",

    -- Tooltips and menu
    TIP_UPDATED           = "Updated: %s",
    TIP_LAST_SEEN         = "Last login: %s",
    TIP_RIGHT_CLICK       = "Right click: hide or forget",
    MENU_HIDE             = "Hide this character",
    MENU_UNHIDE           = "Show this character",
    MENU_FORGET           = "Forget this character (comes back at its next login)",

    -- Options
    OPT_TITLE             = "WeeklyCompass - Options",
    OPT_SECTION_WINDOW    = "Window",
    OPT_TOGGLE            = "Open / close",
    OPT_RECENTER          = "Recenter the window",
    OPT_REFRESH           = "Refresh activities",
    OPT_SECTION_CHARS     = "Characters",
    OPT_SHOW_HIDDEN       = "Show hidden characters",
    OPT_UNHIDE_ALL        = "Show all characters again",
    OPT_CHARS_NOTE        = "Right click a character's name in the dashboard to hide or forget it.",
    OPT_SECTION_FLOAT     = "Floating buttons (TibiSuite bar)",
    OPT_HIDE_OPTIONS      = "Hide the Options button",
    OPT_HIDE_SEARCH       = "Hide the Search field",
    OPT_FLOAT_NOTE        = "The Options button and the Search field stick out above the window. Even hidden, Shift+right click on the window opens these options.",
    OPT_TAB_TIP           = "Tip: right clicking the Weekly tab in the TibiSuite bar also opens these options.",
})
