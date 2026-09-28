-- XPBar - Locale/deDE.lua : surcharge allemande (base anglaise dans enUS.lua).
-- Traduction non relue par un joueur natif : a faire valider.
if GetLocale() ~= "deDE" then return end
XPBarL = XPBarL or {}
local L = XPBarL

for k, v in pairs({
    LEVEL = "Stufe", LEVEL_SHORT = "St.", XP = "EP",
    PROGRESS = "Fortschritt", REMAINING = "Verbleibend", RESTED = "Erholt",
    QUESTS = "Quests", QUESTS_DONE = "Abgeschlossene Quests", SESSION = "Sitzung",
    XP_PER_HOUR = "EP/Std.", XP_PER_HOUR_ROLL = "EP/Std. (aktuell)",
    TIME_LEFT = "Restzeit", PLAYED = "Gespielt",
    LEVELS_GAINED = "Erreichte Stufen", QUESTS_TURNED = "Abgegebene Quests",
    HINT = "|cffFFD700Umschalt+Ziehen|r bewegen  ·  |cffFFD700Umschalt+Rechtsklick|r Optionen",
    POS_SAVED = "Position gespeichert.", POS_RESET = "Position zurückgesetzt.",
    SESSION_RESET = "Sitzung zurückgesetzt.", XP_DISABLED = "EP gesperrt",

    OPT_TITLE = "XPBar - Optionen",
    OPT_HINT = "|cffFFD700Umschalt+Ziehen|r auf der Leiste zum Verschieben, |cffFFD700Umschalt+Rechtsklick|r zum Öffnen oder Schließen dieses Fensters.",
    OPT_SEC_DIMENSIONS = "Abmessungen", OPT_WIDTH_2 = "Breite", OPT_HEIGHT_2 = "Höhe",
    OPT_SEC_APPEARANCE = "Darstellung", OPT_OPACITY_2 = "Hintergrund-Deckkraft (%)",
    OPT_FONTSIZE_2 = "Textgröße",
    OPT_COL_BAR = "Farbe der EP-Leiste", OPT_COL_QUEST = "Farbe abgeschlossener Quests",
    OPT_COL_RESTED = "Farbe für Erholung", OPT_COL_INC = "Farbe unvollständiger Quests",
    OPT_DISPLAY = "Anzeige", OPT_PLAYED_2 = "Gesamte Spielzeit", OPT_SESSION = "Sitzungsdauer",
    OPT_XPPERHOUR = "EP pro Stunde", OPT_LEVELING_2 = "Geschätzte Zeit bis zur nächsten Stufe",
    OPT_ROLLING_2 = "EP/Std. der letzten 15 Minuten", OPT_COMPLETED_2 = "Abgeschlossene Quests (%)",
    OPT_RESTED_TXT = "Erholungs-EP (%)", OPT_INCBAR_2 = "Leiste unvollständiger Quests",
    OPT_SEC_VISIBILITY = "Sichtbarkeit", OPT_SHOWBAR = "Leiste anzeigen",
    OPT_MAXLEVEL = "Auf Höchststufe anzeigen",
    OPT_HIDENATIVE = "Standardleisten ausblenden (EP und Ruf)",
    OPT_HIDECOMBAT = "Im Kampf ausblenden", OPT_HIDEVEHICLE = "Im Fahrzeug ausblenden",
    OPT_MOUSEOVER = "Nur bei Mauskontakt anzeigen",
    OPT_SEC_ORIENTATION = "Ausrichtung", OPT_VERTBAR = "Vertikale Leiste",
    OPT_VERTTEXT_2 = "Text neben der Leiste (vertikal)",
    OPT_VTHICK_2 = "Dicke (vertikal)", OPT_VLENGTH_2 = "Länge (vertikal)",
    OPT_SEC_SESSION = "Sitzung", OPT_RESETRELOAD = "Sitzung bei jedem /reload zurücksetzen",
    OPT_RESETSESS = "Sitzung zurücksetzen", OPT_RESETPOS = "Position zurücksetzen",
    OPT_SEC_FLOATING = "Schwebende Schaltfläche", OPT_HIDE_OPTIONS_BTN = "Optionen-Schaltfläche ausblenden",

    SLASH_HIDDEN = "Ausgeblendet. /xpbar show zum erneuten Anzeigen.",
    SLASH_HELP = " /xpbar - Optionen  |  /xpbar hide/show  |  /xpbar session  |  /xpbar reset",
    SLASH_HELP_DBG = "  /xpbar debug - Standard-EP-Frames prüfen",
    LOGIN_LOADED = "geladen -- tippe", LOGIN_TO_OPEN = "für die Optionen.",
    DEBUG_HEADER = "Standard-EP-Frames:", DEBUG_HIDDEN = "ausgeblendet", DEBUG_MISSING = "nicht vorhanden",
    MM_TT_LEFT = "Linksklick: anzeigen/ausblenden", MM_TT_RIGHT = "Rechtsklick: Optionen",
}) do L[k] = v end

-- Lot 3 : progression enrichie, historique, reputation au niveau max, styles
for k, v in pairs({
    QUEST_XP = "EP abgeschlossener Quests", PROJ_XP = "EP laufender Quests",
    QUEST_LEVELUP = "Das Abgeben deiner abgeschlossenen Quests reicht für die nächste Stufe!",
    LEVEL_TIME = "Zeit auf dieser Stufe", PREV_LEVEL = "Stufe %d abgeschlossen in",
    KILLS_LEFT = "Verbleibende Gegner (geschätzt)", QUESTS_LEFT = "Verbleibende Quests (geschätzt)",
    LEVEL_REACHED = "Stufe %d erreicht: Stufe %d hat %s Spielzeit gedauert.",
    HISTORY_HEADER = "Spielzeit pro Stufe (%s):",
    HISTORY_EMPTY = "Für diesen Charakter ist noch keine Stufe gespeichert (einmal mit aktivem XPBar aufsteigen).",
    NO_WATCHED_REP = "Kein Ruf beobachtet", PARAGON = "Paragon", RENOWN = "Ansehen",
    OPT_SEC_PROGRESS = "Fortschritt",
    OPT_QUESTXP = "Echte EP abgeschlossener Quests (orange)",
    OPT_PROJECTION = "Vorschau laufender Quests",
    OPT_RESTZONE = "Bereich und Markierung des Erholungsbonus",
    OPT_TICKS = "Markierungen alle 10 %", OPT_FLOATXP = "Schwebender Text bei jedem EP-Gewinn",
    OPT_ESTIMATES = "Verbleibende Gegner und Quests (Tooltip)",
    OPT_REPATMAX = "Beobachteter Ruf auf Höchststufe",
    OPT_REPATMAX_TT = "Auf Höchststufe zeigt die Leiste den beobachteten Ruf (im Ruffenster markiert), statt zu verschwinden.",
    OPT_CLASSCOLOR = "Leiste in Klassenfarbe",
    OPT_SEC_PRESETS = "Fertige Stile", OPT_PRESET_THIN = "Stil Schmal (8 px)",
    OPT_PRESET_CLASSIC = "Stil Klassisch", OPT_PRESET_VERTICAL = "Stil Vertikal",
    OPT_COL_INC = "Farbe laufender Quests",
    SLASH_HELP = " /xpbar - Optionen  |  /xpbar hide/show  |  /xpbar session  |  /xpbar history  |  /xpbar reset",
}) do L[k] = v end
