-- =============================================================================
-- LvlHistory - Locale/enUS.lua
-- Le francais est le texte par defaut embarque dans le code (Loc(key, default)).
-- Ce fichier fournit l'ANGLAIS a tous les clients non francais : c'est le
-- repli des 8 autres langues (Locale/xxXX.lua charges juste apres ne
-- surchargent que leur propre langue). Ordre de repli : langue du client ->
-- anglais -> francais. Charge tout en debut de .toc, avant tous les autres
-- fichiers (TAB_LABELS est construit une seule fois au chargement de UI.lua).
-- =============================================================================

LvlHistory = LvlHistory or {}
LvlHistory.L = LvlHistory.L or {}
local L = LvlHistory.L

local loc = GetLocale()
if loc == "frFR" then
  -- Francais accentue (les textes par defaut du code sont sans accents).
  for k, v in pairs({
    BUTTON_HIDDEN_LOG = "Bouton masqué - /lvlh minimap pour le réafficher",
    COL_TIME = "Tps", BTN_COLLAPSE_LIST = "- Réduire",
    LBL_CONNECTED = "(connecté)", LBL_CUMUL_SHORT = "cumulées",
    LBL_DURATION = "Durée", LBL_DURATION_RECORD = "Durée record",
    LBL_GOLD_GAINED = "Or gagné", LBL_GOLD_THIS_SESSION = "Or gagné cette session",
    LBL_LEVELS_EMPTY = "La chronologie se remplit à chaque niveau gagné à partir de maintenant.",
    LBL_NO_RESTED = "aucun alt reposé", LBL_QUESTS = "Quêtes",
    LBL_RACE_FMT = "Montée 10 > %d", LBL_RACE_SHORT = "Montée record", LBL_RACE_SHORT_FMT = "montée %s",
    LBL_REPUTATION = "Réputation", LBL_RESTED_PCT_FMT = "%d %% de niveau reposé",
    LBL_RESTED_SHORT_FMT = "reposé %d %%", LBL_SESSION_DURATION = "Durée session",
    LBL_SPARK_FMT = "%d dernières sessions : %s", LBL_TIMES_PLAYED = "Fois joué",
    LBL_TONIGHT = "À monter ce soir", LBL_TOP_CURRENCY = "Monnaie la plus gagnée",
    LBL_TOP_DELVES = "Gouffres les plus joués", LBL_TOP_DUNGEONS = "Donjons les plus joués",
    LBL_TOTAL_COMPLETED = "Total complétés", LBL_TOTAL_GOLD = "Or total gagné",
    LBL_TOTAL_QUESTS = "Quêtes totales", LBL_TOTAL_TIME_CUMUL = "Temps cumulé",
    LBL_ZONES_VISITED = "Zones visitées", LBL_TOP_CHAR = "Top perso",
    LBL_AVG_XPH = "XP/h moyenne", LBL_LEVEL_PREFIX = "Niveau ",
    OPACITY_LABEL = "Opacité", OPT_LEVEL_ALERT = "Message à chaque niveau (temps passé au niveau)",
    OPT_FLOATING_NOTE = "Le bouton Options et le champ Recherche débordent au-dessus de la fenêtre. Même masqués, Maj+clic droit sur la fenêtre ouvre ces options.",
    SRC_QUEST = "Quêtes", TT_COLLAPSE = "Réduire", TT_OPEN_DGNTRACKER = "Clic : ouvrir DgnTracker",
    LEVEL_UP_FMT = "Niveau %d atteint : %s de jeu au niveau %d.",
  }) do L[k] = v end
  return
end

for k, v in pairs({
  -- Utils.lua (devises)
  CUR_GOLD = "g", CUR_SILVER = "s", CUR_COPPER = "c", ERROR_PREFIX = "ERROR:",
  -- Core.lua
  LOGIN_LOADED = "loaded -- type", LOGIN_TO_OPEN = "to open.",
  MAX_LEVEL_REACHED = "Max level reached: switching to FARMING mode",
  RESET_CONFIRM_HINT = "Type |cffFFFFFF/lvlh reset confirm|r to confirm.",
  DATA_RESET_DONE = "Data reset. Reload (/reload).",
  SLASH_HELP = "Commands: /lvlh | /lvlh levels | /lvlh options | /lvlh minimap | /lvlh debug | /lvlh reset",
  LEVEL_UP_FMT = "Level %d reached: %s played at level %d.",
  LEVEL_UP_PARTIAL = "(partial tracking)",
  -- Minimap.lua
  TT_MODE = "Mode", TT_LEVEL = "Level", TT_GOLDH = "Gold/h", TT_SESSION = "Session",
  TT_LEFTCLICK = "Left click", TT_TOGGLE = "Open/Close", TT_RIGHTCLICK = "Right click",
  TT_OPTIONS = "Options", TT_DRAG = "Drag", TT_REPOSITION = "Reposition",
  MENU_TOGGLE = "Open / Close", MENU_DEBUG = "Debug", MENU_HIDE_BUTTON = "Hide the button",
  BUTTON_HIDDEN_LOG = "Button hidden - /lvlh minimap to show it again",
  MENU_RESET_CHAR = "Reset this character",
  -- UI.lua : onglets
  TAB_SESSION = "Session", TAB_ZONES = "Zones", TAB_ALTS = "Alts",
  TAB_DUNGEONS = "Dungeons", TAB_STATS = "Stats", TAB_LEVELS = "Levels",
  TT_EXPAND = "Expand", TT_COLLAPSE = "Collapse", OPACITY_LABEL = "Opacity",
  -- Session
  LBL_CURRENT_ZONE = "Current zone", LBL_QUESTS = "Quests", LBL_GOLD_GAINED = "Gold gained",
  LBL_REPUTATION = "Reputation", LBL_XPH = "XP / hour", LBL_GOLDH = "Gold / hour",
  LBL_ETA_PREFIX = "ETA lvl ", LBL_PCT_DONE = "% done", LBL_THIS_SESSION = "this session",
  LBL_SESSION_DURATION = "Session duration", LBL_TOTAL_SUFFIX = " total",
  LBL_LEVEL_PREFIX = "Level ", LBL_GOLD_THIS_SESSION = "Gold gained this session",
  LBL_ETA_MAX = "Max level in", LBL_XP_SOURCES = "XP sources",
  LBL_LIVE_XPBAR_FMT = "live: %s (XPBar)", QUESTS_DAILY_FMT = "%d  (%d daily)",
  LBL_DGN_DELVES_SESSION = "Dungeons / delves", LBL_TOP_CURRENCY = "Top currency",
  SRC_QUEST = "Quests", SRC_DUNGEON = "Dungeons", SRC_DELVE = "Delves", SRC_OTHER = "Other",
  -- Zones
  LBL_ZONES_VISITED = "Zones visited", LBL_TOTAL_TIME = "Total time", LBL_ZONE_RECORD = "Zone record",
  BTN_COLLAPSE_LIST = "- Collapse", BTN_SHOW_MORE_FMT = "+ Show more (%d zones)",
  -- Alts
  LBL_ALTS_TRACKED = "Alts tracked", LBL_MAX_LEVEL = "Max level",
  LBL_TOTAL_TIME_CUMUL = "Cumulative time", LBL_ALL_CHARS = "all characters",
  LBL_CUMUL_SHORT = "combined", LBL_CONNECTED = "(online)",
  LBL_TONIGHT = "Level tonight", LBL_RESTED_PCT_FMT = "%d %% of a level rested",
  LBL_NO_RESTED = "no rested alt", LBL_RESTED_SHORT_FMT = "rested %d %%",
  LBL_RACE_SHORT_FMT = "leveling %s",
  MODE_FARMING = "Farming", MODE_LEVELING = "Leveling",
  -- Donjons
  LBL_TOP_DUNGEONS = "Most played dungeons", COL_DIFF = "Diff.", COL_TIME = "Time",
  LBL_TOTAL_COMPLETED = "Total completed", LBL_THIS_SESSION_CAP = "This session",
  LBL_FAVORITE_DUNGEON = "Favorite dungeon", LBL_DELVES_SUB_FMT = "delves: %d (total %d)",
  LBL_TOP_DELVES = "Most played delves", LBL_TIER_FMT = "tier %d",
  TT_OPEN_DGNTRACKER = "Click: open DgnTracker",
  -- Stats
  LBL_RECORDS = "Records", LBL_BEST_XPH = "Best XP/h", LBL_AVG_XPH = "Average XP/h",
  LBL_TOTAL_SESSIONS = "Total sessions", LBL_BEST_SESSION = "Longest session",
  LBL_FAVORITE_ZONE = "Favorite zone", LBL_TOTAL_GOLD = "Total gold gained",
  LBL_BEST_GOLD_SESSION = "Best gold / session", LBL_BEST_GOLDH = "Best gold / hour",
  LBL_BEST_DGN_SESSION = "Best dungeons / session", LBL_SESSIONS_SUFFIX = "sessions",
  LBL_TOTAL_QUESTS = "Total quests", LBL_TOTAL_DUNGEONS = "Total dungeons",
  AVG_PREFIX_FMT = "avg. %s", LV_PREFIX_FMT = "Lv %d",
  LBL_SPARK_FMT = "Last %d sessions: %s", LBL_LEVELS = "Levels",
  -- Niveaux
  LBL_ON_LEVEL_FMT = "At level %d", LBL_AVG_LEVEL = "Average / level",
  LBL_LAST_N_FMT = "last %d levels", LBL_RACE_FMT = "Leveling 10 > %d",
  LBL_RECORD_BY_FMT = "record: %s", LBL_ACCOUNT_RECORD = "account record",
  LBL_RACE_HINT = "full tracking needed", LBL_RACE_SHORT = "Best leveling",
  LBL_LEVELS_EMPTY = "The timeline fills up with every level gained from now on.",
  -- Pied / reduit
  FOOTER_SESSION_PREFIX = "Session  ", FOOTER_TOTAL_PREFIX = "Total  ",
  LBL_DURATION = "Duration", LBL_ZONE_SHORT = "Zone", LBL_DURATION_RECORD = "Duration record",
  LBL_TOP_CHAR = "Top character", LBL_TOTAL_SHORT = "Total", LBL_FAVORITE_SHORT = "Favorite",
  LBL_TIMES_PLAYED = "Times played", LBL_SESSIONS_SHORT = "Sessions",
  -- LvlHistory_Suite.lua (options + recherche)
  OPT_SEC_WINDOW = "Window", OPT_TOGGLE = "Open / close", OPT_RECENTER = "Recenter the window",
  OPT_OPACITY = "Opacity (%)", OPT_SEC_TRACKING = "Tracking",
  OPT_LEVEL_ALERT = "Message at each level (time spent on the level)",
  OPT_RESUME = "A /reload does not end the session (resumed within 10 min)",
  OPT_SESSION_ALERT = "Message when switching to Farming mode",
  OPT_OPEN_LEVELS = "Open the level timeline",
  OPT_SEC_FLOATING = "Floating buttons (TibiSuite bar)",
  OPT_HIDE_OPTIONS_BTN = "Hide the Options button", OPT_HIDE_SEARCH_BTN = "Hide the Search field",
  OPT_FLOATING_NOTE = "The Options button and Search field overflow above the window. Even hidden, Shift+right-click on the window opens these options.",
  OPT_NOTE = "Tip: right-clicking the Lvl Hist tile in the TibiSuite bar also opens these options.",
  SEARCH_TITLE = "Search", SEARCH_LEVEL_FMT = "lvl ", SEARCH_DUNGEON = "dungeon", SEARCH_DELVE = "delve",
  MODULE_LABEL = "Lvl Hist",
}) do L[k] = v end
