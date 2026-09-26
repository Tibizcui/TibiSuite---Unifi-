local addonName, ns = ...

ns:AddLocale("deDE", {
    -- Aktivitaeten
    ACTIVITY_GREAT_VAULT  = "Grosses Vault",
    ACTIVITY_LAIRS        = "Woechentliche Lager",
    ACTIVITY_DELVES       = "Schaechte",
    ACTIVITY_HUNT         = "Die Jagd",

    -- Kurze Bezeichnungen (Spaltenkoepfe der Kontoansicht)
    ACTIVITY_LAIRS_SHORT  = "Lager",
    ACTIVITY_DELVES_SHORT = "Schaechte",
    ACTIVITY_HUNT_SHORT   = "Jagd",

    -- Grosses Vault
    VAULT_SLOT_DUNGEONS = "Dungeons",
    VAULT_SLOT_RAID       = "Schlachtzug",
    VAULT_SLOT_WORLD      = "Welt",
    VAULT_SLOT_GENERIC    = "Verfolgung",
    VAULT_REWARD_ILVL     = "Gegenstandsstufe %d erhalten",
    VAULT_CLAIM_LABEL     = "Grosse Schatzkammer: Belohnung abholen",
    VAULT_CLAIM_SHORT     = "Belohnung",
    VAULT_CLAIM_CELL      = "Abholen",

    -- Namen der Verbesserungsstufen
    TRACK_NAME_EXPLORER   = "Entdecker",
    TRACK_NAME_ADVENTURER = "Abenteurer",
    TRACK_NAME_VETERAN    = "Veteran",
    TRACK_NAME_CHAMPION   = "Champion",
    TRACK_NAME_HERO       = "Held",
    TRACK_NAME_MYTH       = "Mythos",

    -- Status
    STATUS_DONE           = "Erledigt",
    STATUS_IN_PROGRESS    = "In Arbeit",
    STATUS_NOT_STARTED    = "Zu erledigen",
    STATUS_UNKNOWN        = "Unbekannt",

    -- Details
    DETAIL_API_PENDING    = "Warte auf Spieldaten",
    DETAIL_SOURCES_PENDING = "Noch nicht erfasst",
    DETAIL_RENOWN_RANK    = "Rang %d",
    SRC_COFFER_SHARDS_SHORT = "Schluesselsplitter",
    SRC_DELVES_RENOWN_SHORT = "Tiefen-Ruhm",
    SRC_HUNT_RENOWN_SHORT   = "Jagdrang",

    -- Start / Minikarte
    LOGIN_LOADED          = "%s geladen: %d Aktivitaeten erfasst, %d ausstehend. /wc zum Oeffnen.",
    MINIMAP_HINT_TOGGLE   = "Linksklick: Uebersicht oeffnen / schliessen",
    MINIMAP_HINT_DRAG     = "Ziehen: um die Minikarte bewegen",

    -- Interface
    UI_TITLE              = "WeeklyCompass",
    UI_SUBTITLE           = "Kontoansicht: was diese Woche noch aussteht",
    UI_HEADER_CHAR        = "Charakter",
    UI_EMPTY              = "Noch keine Charakterdaten. Logge dich mit deinen Twinks ein, um die Kontoansicht zu fuellen.",
    UI_STALE              = "Daten stammen vor dem letzten Reset",
    SLASH_HINT            = "Befehle: /wc | /wc options | /wc dump | /wc minimap | /wc debug",
    UI_ALL_HIDDEN         = "Alle deine Charaktere sind ausgeblendet. Aktiviere „Ausgeblendete Charaktere anzeigen“ in den Optionen.",
    UI_HIDDEN_TAG         = "(ausgeblendet)",

    -- Große Schatzkammer, Details
    VAULT_CLAIM_PROBABLE_CELL = "Abholen?",
    VAULT_CLAIM_PROBABLE_TIP  = "Abgeleitet: Dieser Charakter hatte vor dem Reset Plätze der Großen Schatzkammer freigeschaltet und war seitdem nicht mehr online.",
    VAULT_SLOT_LINE       = "Platz %d: %d/%d",
    VAULT_NEXT_SLOT       = "Nächster Platz: noch %d %s",
    VAULT_ALL_SLOTS       = "Alle Plätze freigeschaltet",
    VAULT_UNIT_DUNGEONS   = "Dungeon(s)",
    VAULT_UNIT_RAID       = "Boss(e)",
    VAULT_UNIT_WORLD      = "Aktivität(en)",
    VAULT_UNIT_GENERIC    = "Schritt(e)",

    -- Tooltips und Menü
    TIP_UPDATED           = "Aktualisiert: %s",
    TIP_LAST_SEEN         = "Letzter Login: %s",
    TIP_RIGHT_CLICK       = "Rechtsklick: ausblenden oder vergessen",
    MENU_HIDE             = "Diesen Charakter ausblenden",
    MENU_UNHIDE           = "Diesen Charakter wieder anzeigen",
    MENU_FORGET           = "Diesen Charakter vergessen (kehrt beim nächsten Login zurück)",

    -- Optionen
    OPT_TITLE             = "WeeklyCompass - Optionen",
    OPT_SECTION_WINDOW    = "Fenster",
    OPT_TOGGLE            = "Öffnen / schließen",
    OPT_RECENTER          = "Fenster zentrieren",
    OPT_REFRESH           = "Aktivitäten aktualisieren",
    OPT_SECTION_CHARS     = "Charaktere",
    OPT_SHOW_HIDDEN       = "Ausgeblendete Charaktere anzeigen",
    OPT_UNHIDE_ALL        = "Alle Charaktere wieder anzeigen",
    OPT_CHARS_NOTE        = "Rechtsklick auf den Namen eines Charakters in der Übersicht, um ihn auszublenden oder zu vergessen.",
    OPT_SECTION_FLOAT     = "Schwebende Schaltflächen (TibiSuite-Leiste)",
    OPT_HIDE_OPTIONS      = "Optionen-Schaltfläche ausblenden",
    OPT_HIDE_SEARCH       = "Suchfeld ausblenden",
    OPT_FLOAT_NOTE        = "Die Optionen-Schaltfläche und das Suchfeld ragen über das Fenster hinaus. Auch ausgeblendet öffnet Umschalt+Rechtsklick auf das Fenster diese Optionen.",
    OPT_TAB_TIP           = "Tipp: Ein Rechtsklick auf den Reiter Weekly in der TibiSuite-Leiste öffnet ebenfalls diese Optionen.",
})
