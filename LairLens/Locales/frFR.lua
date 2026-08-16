-- =============================================================================
-- LairLens - Locales/frFR.lua
-- Surcharge FR. Ne s'applique que si le client tourne en francais.
-- =============================================================================

local ADDON, LL = ...
if GetLocale() ~= "frFR" then return end
local L = LL.L

L["AUDIT_TITLE"]        = "Audit du groupe"
L["AUDIT_NO_GROUP"]     = "Pas en groupe"
L["AUDIT_NO_LAIR"]      = "Hors d'un Repaire"

L["DIFF_WORLD"]         = "Monde"
L["DIFF_NORMAL"]        = "Normal"
L["DIFF_HEROIC"]        = "Heroique"
L["DIFF_MYTHIC"]        = "Mythique"

L["ROLES"]              = "Roles"
L["TANKS"]              = "Tanks"
L["HEALERS"]            = "Soigneurs"
L["COMBAT_REZ"]         = "Rez de combat"
L["LUST"]               = "Lust / Hero"
L["INTERRUPTS"]         = "Interruptions"
L["DISPELS"]            = "Dissipations"

L["DISPEL_MAGIC"]       = "Magie"
L["DISPEL_CURSE"]       = "Malediction"
L["DISPEL_POISON"]      = "Poison"
L["DISPEL_DISEASE"]     = "Maladie"

L["PRESENT"]            = "Present"
L["ABSENT"]             = "Absent"
L["NONE"]               = "Aucun"

L["VERDICT_VIABLE"]     = "Groupe viable"
L["VERDICT_RISKY"]      = "Jouable, mais juste"
L["VERDICT_MISSING"]    = "Il manque : %s"

L["MISS_TANK"]          = "un tank"
L["MISS_HEALER"]        = "des soigneurs (%d/%d)"
L["MISS_COMBAT_REZ"]    = "un rez de combat"
L["MISS_LUST"]          = "le Lust"
L["MISS_INTERRUPT"]     = "des interruptions"

L["REWARD_TITLE"]       = "Pertinence des recompenses"
L["REWARD_WORTH"]       = "Ca vaut le coup"
L["REWARD_SKIP"]        = "Tu peux zapper"
L["REWARD_DONE_WEEK"]   = "Deja valide cette semaine"
L["REWARD_NO_DATA"]     = "Tables de butin pas encore disponibles"

-- Dashboard (historique des runs)
L["DASH_TITLE"]           = "Historique des Repaires"
L["DASH_RUNS"]            = "Runs"
L["DASH_TIME"]            = "Temps"
L["DASH_ATTEMPTS"]        = "Tentatives"
L["DASH_KILLS"]           = "Kills"
L["DASH_FILTER_OWNER"]    = "Perso"
L["DASH_FILTER_DIFF"]     = "Difficulte"
L["DASH_FILTER_INSTANCE"] = "Repaire"
L["DASH_ALL"]             = "Tous"
L["DASH_SEARCH"]          = "Rechercher..."
L["DASH_EMPTY"]           = "Aucun run enregistre pour l'instant."
L["DASH_COL_DATE"]        = "Date"
L["DASH_COL_LAIR"]        = "Repaire"
L["DASH_COL_DIFF"]        = "Diff."
L["DASH_COL_TIME"]        = "Temps"
L["DASH_COL_TRIES"]       = "Tent."
L["DASH_COL_RESULT"]      = "Resultat"
L["DASH_ILVL"]            = "ilvl"
L["DASH_OPEN_TT"]         = "Ouvrir le tableau de bord des runs (historique)."
L["DASH_CLEAR"]           = "Vider l'historique"
L["DASH_CLEAR_CONFIRM"]   = "Cliquer encore pour confirmer"
L["RUN_KILL"]             = "Kill"
L["RUN_INCOMPLETE"]       = "Incomplet"

L["SLASH_HELP"]         = "Commandes : /ll config, /ll show, /ll dash, /ll sim, /ll lock, /ll reset, /ll debug"
L["FRAME_LOCKED"]       = "Panneau verrouille."
L["FRAME_UNLOCKED"]     = "Panneau deverrouille (glisse pour deplacer)."

-- Options
L["OPT_TITLE"]          = "Reglages"
L["OPT_ENABLED"]        = "Activer LairLens"
L["OPT_ENABLED_TT"]     = "Interrupteur principal de l'addon."
L["OPT_HIDE_OUT"]       = "Masquer hors Repaire"
L["OPT_HIDE_OUT_TT"]    = "N'afficher le panneau qu'a l'interieur d'un Repaire."
L["OPT_FADE_COMBAT"]    = "Estomper en combat"
L["OPT_FADE_COMBAT_TT"] = "Attenuer le panneau pendant le combat pour rester discret."
L["OPT_LOCK"]           = "Verrouiller la position"
L["OPT_LOCK_TT"]        = "Empeche le deplacement du panneau."
L["OPT_SCALE"]          = "Echelle"
L["OPT_UNAVAILABLE"]    = "Panneau de reglages indisponible sur ce client. Utilise les commandes."
