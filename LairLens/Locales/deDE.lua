-- =============================================================================
-- LairLens - Locales/deDE.lua
-- Surcharge DE. Ne s'applique que si le client tourne en allemand.
-- =============================================================================

local ADDON, LL = ...
if GetLocale() ~= "deDE" then return end
local L = LL.L

L["AUDIT_TITLE"]        = "Gruppenanalyse"
L["AUDIT_NO_GROUP"]     = "Nicht in einer Gruppe"
L["AUDIT_NO_LAIR"]      = "Ausserhalb eines Lagers"

L["DIFF_WORLD"]         = "Welt"
L["DIFF_NORMAL"]        = "Normal"
L["DIFF_HEROIC"]        = "Heroisch"
L["DIFF_MYTHIC"]        = "Mythisch"

L["ROLES"]              = "Rollen"
L["TANKS"]              = "Tanks"
L["HEALERS"]            = "Heiler"
L["COMBAT_REZ"]         = "Kampf-Wiederbelebung"
L["LUST"]               = "Lust / Heldentum"
L["INTERRUPTS"]         = "Unterbrechungen"
L["DISPELS"]            = "Reinigungen"

L["DISPEL_MAGIC"]       = "Magie"
L["DISPEL_CURSE"]       = "Fluch"
L["DISPEL_POISON"]      = "Gift"
L["DISPEL_DISEASE"]     = "Krankheit"

L["PRESENT"]            = "Anwesend"
L["ABSENT"]             = "Abwesend"
L["NONE"]               = "Keine"

L["VERDICT_VIABLE"]     = "Gruppe machbar"
L["VERDICT_RISKY"]      = "Spielbar, aber knapp"
L["VERDICT_MISSING"]    = "Es fehlt: %s"

L["MISS_TANK"]          = "ein Tank"
L["MISS_HEALER"]        = "Heiler (%d/%d)"
L["MISS_COMBAT_REZ"]    = "eine Kampf-Wiederbelebung"
L["MISS_LUST"]          = "Lust/Heldentum"
L["MISS_INTERRUPT"]     = "Unterbrechungen"

L["REWARD_TITLE"]       = "Relevanz der Belohnungen"
L["REWARD_WORTH"]       = "Lohnt sich"
L["REWARD_SKIP"]        = "Kannst du auslassen"
L["REWARD_DONE_WEEK"]   = "Diese Woche bereits erledigt"
L["REWARD_NO_DATA"]     = "Beutedaten noch nicht verfuegbar"

-- Dashboard (Verlauf der Durchgaenge)
L["DASH_TITLE"]           = "Lager-Verlauf"
L["DASH_RUNS"]            = "Durchgaenge"
L["DASH_TIME"]            = "Zeit"
L["DASH_ATTEMPTS"]        = "Versuche"
L["DASH_KILLS"]           = "Kills"
L["DASH_FILTER_OWNER"]    = "Charakter"
L["DASH_FILTER_DIFF"]     = "Schwierigkeit"
L["DASH_FILTER_INSTANCE"] = "Lager"
L["DASH_ALL"]             = "Alle"
L["DASH_SEARCH"]          = "Suchen..."
L["DASH_EMPTY"]           = "Noch kein Durchgang aufgezeichnet."
L["DASH_COL_DATE"]        = "Datum"
L["DASH_COL_LAIR"]        = "Lager"
L["DASH_COL_DIFF"]        = "Schw."
L["DASH_COL_TIME"]        = "Zeit"
L["DASH_COL_TRIES"]       = "Vers."
L["DASH_COL_RESULT"]      = "Ergebnis"
L["DASH_ILVL"]            = "Gstufe"
L["DASH_OPEN_TT"]         = "Das Verlaufs-Dashboard oeffnen."
L["DASH_CLEAR"]           = "Verlauf loeschen"
L["DASH_CLEAR_CONFIRM"]   = "Erneut klicken zum Bestaetigen"
L["RUN_KILL"]             = "Kill"
L["RUN_INCOMPLETE"]       = "Unvollstaendig"

L["SLASH_HELP"]         = "Befehle: /ll config, /ll show, /ll dash, /ll sim, /ll lock, /ll reset, /ll debug"
L["FRAME_LOCKED"]       = "Fenster gesperrt."
L["FRAME_UNLOCKED"]     = "Fenster entsperrt (zum Verschieben ziehen)."

-- Einstellungen
L["OPT_TITLE"]          = "Einstellungen"
L["OPT_ENABLED"]        = "LairLens aktivieren"
L["OPT_ENABLED_TT"]     = "Hauptschalter des Addons."
L["OPT_HIDE_OUT"]       = "Ausserhalb eines Lagers ausblenden"
L["OPT_HIDE_OUT_TT"]    = "Zeigt das Fenster nur innerhalb eines Lagers."
L["OPT_FADE_COMBAT"]    = "Im Kampf ausblenden"
L["OPT_FADE_COMBAT_TT"] = "Blendet das Fenster im Kampf ab, um dezent zu bleiben."
L["OPT_LOCK"]           = "Position sperren"
L["OPT_LOCK_TT"]        = "Verhindert das Verschieben des Fensters."
L["OPT_SCALE"]          = "Skalierung"
L["OPT_UNAVAILABLE"]    = "Einstellungsfenster auf diesem Client nicht verfuegbar. Nutze die Slash-Befehle."
