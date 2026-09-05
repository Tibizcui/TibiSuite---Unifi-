-- =============================================================================
-- DgnTracker - Locales/deDE.lua
-- Surcharge DE. Ne s'applique que si le client tourne en allemand.
-- =============================================================================

if GetLocale() ~= "deDE" then return end
DgnTrackerL = DgnTrackerL or {}
local L = DgnTrackerL

L["WP_NO_COORDS"]        = "keine Koordinaten verfuegbar fuer"
L["WP_TOMTOM_LABEL"]     = "Wegpunkt"
L["WP_MAP_LABEL"]        = "Wegpunkt"
L["WP_MAP_WORD"]         = "Karte"
L["WP_OPEN_MAP_HINT"]    = "(oeffne die Karte, um ihn zu sehen)"
L["WP_NATIVE_FAIL"]      = "konnte keinen nativen Wegpunkt in dieser Zone setzen. Installiere |cFFFFD700TomTom|r fuer einen vollstaendigen Zeiger."
L["WP_NONE_AVAILABLE"]   = "kein Wegpunktsystem verfuegbar. Installiere |cFFFFD700TomTom|r."
L["DRAG_HINT"]           = "Ziehen zum Verschieben"
L["INSTANCES_WORD"]      = "Instanz(en)"
L["SEARCH_PLACEHOLDER"]  = "Suchen..."
L["EXTENSION_LABEL"]     = "Erweiterung:"
L["LEFT_CLICK_LABEL"]    = "Linksklick"
L["CLOSE_WORD"]          = "schliessen"
L["SHOW_PATH_WORD"]      = "Weg anzeigen"
L["RIGHT_CLICK_LABEL"]   = "Rechtsklick"
L["SET_WAYPOINT_HINT"]   = "einen Wegpunkt setzen"
L["NO_RESULT_FOR"]       = "Kein Ergebnis fuer"
L["NO_INSTANCE_CATEGORY"]= "Keine Instanz fuer diese Kategorie verfuegbar."
L["ACCESS_HEADER"]       = "-- Zugang (kuerzester Weg):"
L["TIPS_HEADER"]         = "-- Tipps:"
L["MM_TT_SUBTITLE"]      = "Dungeon- und Schlachtzug-Tracker"
L["TOGGLE_HINT"]         = "oeffnen / schliessen"
L["DRAG_LABEL"]          = "Ziehen"
L["REPOSITION_HINT"]     = "Symbol neu positionieren"
L["CLICK_LABEL"]         = "Klick"

L["HELP_COMMANDS_LABEL"] = "Befehle:"
L["HELP_TOGGLE"]         = "Fenster oeffnen/schliessen"
L["HELP_OPTIONS"]        = "Optionen oeffnen"
L["HELP_MAP_ON"]         = "Automatischer Wegpunkt beim Betreten einer Instanz"
L["HELP_MAP_OFF"]        = "Automatischen Wegpunkt deaktivieren"
L["HELP_EXTENSION"]      = "Zu einer Erweiterung wechseln (z.B.: tww, df, sl, van)"
L["HELP_EXPAND"]         = "Alles aufklappen (aktive Erweiterung)"
L["HELP_RESET"]          = "Alles einklappen (Akkordeon)"
L["HELP_TIP"]            = "Tipp: Rechtsklick auf eine Instanz setzt einen Wegpunkt."

L["ACCORDION_RESET"]     = "Akkordeon zurueckgesetzt."
L["EXPANDED_ALL_FOR"]    = "alles aufgeklappt fuer"
L["AUTO_WAYPOINT_LABEL"] = "automatischer Wegpunkt"
L["ENABLED_WORD"]        = "aktiviert"
L["ON_INSTANCE_OPEN"]    = "(beim Betreten einer Instanz)"
L["DISABLED_WORD"]       = "deaktiviert"
L["EXTENSION_ARROW"]     = "Erweiterung ->"
L["UNKNOWN_COMMAND"]     = "unbekannter Befehl. Tippe |cFFFFD700/dg help|r."
L["LOGIN_LOADED"]        = "geladen --"
L["LOGIN_TO_OPEN"]       = "zum Oeffnen."

-- Optionen (DgnTracker_Suite.lua) und Modulname
L["OPT_SEC_WINDOW"]      = "Fenster"
L["OPT_TOGGLE"]          = "Oeffnen / schliessen"
L["OPT_RECENTER"]        = "Fenster zentrieren"
L["OPT_SEC_BEHAVIOR"]    = "Verhalten"
L["OPT_AUTO_WAYPOINT"]   = "Automatischer Wegpunkt beim Betreten einer Instanz"
L["OPT_SEC_FLOATING"]    = "Schwebende Buttons (TibiSuite-Leiste)"
L["OPT_HIDE_OPTIONS_BTN"]= "Options-Button ausblenden"
L["OPT_HIDE_SEARCH_BTN"] = "Suchfeld ausblenden"
L["OPT_FLOATING_NOTE"]   = "Der Options-Button und das Suchfeld stehen oberhalb des Fensters ueber. Auch ausgeblendet oeffnet Umschalt+Rechtsklick auf das Fenster diese Optionen."
L["OPT_NOTE"]            = "Tipp: Rechtsklick auf die Dungeons-Kachel in der TibiSuite-Leiste oeffnet diese Optionen ebenfalls."
L["SEARCH_TITLE"]        = "Suche"
L["MODULE_LABEL"]        = "Dungeons"
