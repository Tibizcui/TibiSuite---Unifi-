-- =============================================================================
-- TibiSuite - Locale/enUS.lua
-- Surcharge EN. Le francais est le texte par defaut embarque directement dans
-- TibiSuiteCore.lua et TibiSuiteOptions.lua (table TibiSuiteL, motif
-- "L.CLE = L.CLE or valeur") : ce fichier ne fournit que ce qui differe.
-- IMPORTANT : ce fichier doit charger AVANT TibiSuiteCore.lua (voir
-- TibiSuite.toc) - la table MODULES du core construit certains libelles
-- d'onglet une seule fois, de facon synchrone, des l'execution de ce fichier.
-- =============================================================================

if GetLocale() ~= "enUS" and GetLocale() ~= "enGB" then return end
TibiSuiteL = TibiSuiteL or {}
local L = TibiSuiteL

-- Libelles d'onglets (mots generiques ; les noms de marque restent inchanges)
L.LBL_DGN   = "Dungeons"
L.LBL_REP   = "Rep."
L.LBL_LAIR  = "Lair"
L.LBL_SKILL = "Professions"

-- Tooltip du logo (barre)
L.TT_LOGO_LEFT      = "|cFFFFD700Left click|r: open / close"
L.TT_LOGO_SHIFTLEFT = "|cFFFFD700Shift + left click|r: hide the bar"
L.TT_LOGO_RIGHT      = "|cFFFFD700Right click|r: options"
L.TT_LOGO_DRAG       = "|cFFFFD700Hold + drag|r: move"
L.TT_LOGO_LOCKED    = "Bar locked"

-- Boutons du cluster droit
L.TT_OPENALL      = "Open all"
L.TT_CLOSEALL     = "Close all"
L.TT_CLOSEBAR     = "Close everything and collapse the bar"
L.TT_CLOSEBAR_SUB = "(red pill or minimap icon to reopen)"
L.SEARCH_PLACEHOLDER        = "Search..."
L.SEARCH_PLACEHOLDER_GLOBAL = "Global search..."

-- Vignettes de module
L.TT_TAB_OPEN         = "Left click: open / close"
L.TT_TAB_OPTIONS      = "Right click: module options"
L.TT_TAB_NOTINSTALLED = "Not installed"
L.TT_TAB_DOWNLOAD     = "Click: see the download link"

-- Placeholder (module absent)
L.PH_MSG      = "This addon is not installed."
L.PH_URLLABEL = "Download it for free on CurseForge:"
L.PH_COPYBTN  = "Copy the link"
L.MSG_NOOPTIONS = "does not yet expose an options menu."

-- Panneau d'options (/ts config)
L.STATE_YES     = "Yes"
L.STATE_NO      = "No"
L.STATE_VISIBLE = "shown"
L.STATE_HIDDEN  = "hidden"
L.OPT_LOCKED_LABEL   = "Bar locked: "
L.OPT_VERTICAL_LABEL = "Vertical bar: "
L.OPT_SCALE_LABEL    = "Scale"
L.OPT_LOGOSIZE_LABEL = "Logo size"
L.OPT_REINSTALL_BTN  = "Reinstall TibiSuite"
L.CONFIRM_REINSTALL_CORE =
  "Reinstall TibiSuite?\n\nThis resets the suite's settings (bar, active modules, installation) then reloads the interface. Each module's progress is kept."
L.OPT_GRID_LABEL     = "Toggle layout"
L.OPT_COLS_LABEL     = "Columns"
L.OPT_ROWS_LABEL     = "Rows"
L.OPT_OPENALL_BTN    = "Open all"
L.OPT_CLOSEALL_BTN   = "Close all"
L.OPT_RECENTER_BTN   = "Recenter"
L.OPT_TABS_SECTION   = "Tabs shown in the bar"
L.OPT_HIDE_MISSING_BTN = "Hide not-installed"
L.OPT_MODULES_BTN    = "Modules: Loaded / Not loaded"

-- Recherche globale (popup)
L.GS_TITLE          = "Search"
L.GS_EMPTY_DEFAULT   = "Type to search loaded modules."
L.GS_EMPTY_NORESULT  = "No results."
L.MSG_NOLIB  = "UI library missing (TibiMidnightUI)."
L.MSG_OLDLIB = "outdated library, run |cFFFFD700/reload|r."

-- Pastille repliee
L.PILL_CLICK = "Click: show the bar and modules again"

-- Bouton minimap
L.MM_TT_LEFT  = "Left click: show / hide the bar"
L.MM_TT_RIGHT = "Right click: options"
L.MM_TT_DRAG  = "|cFFFFD700Drag|r to reposition"

-- Commande slash /ts
L.SLASH_BAR        = "bar"
L.SLASH_RECENTERED = "recentered."
L.LOCK_ON          = "locked"
L.LOCK_OFF         = "unlocked"
L.DIAG_NOLIB          = "search library missing."
L.DIAG_REGISTERED_FMT = "search modules registered ("
L.DIAG_NONE           = "none"
L.SEARCH_BY_MODULE     = "by module:"
L.SEARCH_RESULT_SUFFIX = "result(s)"
L.SEARCH_ERROR         = "ERROR"
L.VERT_ON  = "vertical"
L.VERT_OFF = "horizontal"
L.MSG_MODULES_UNAVAIL = "modules panel unavailable (run |cFFFFD700/reload|r)."
L.HELP_HEADER   = "commands:"
L.HELP_TOGGLE   = "show / hide the bar"
L.HELP_CONFIG   = "options panel"
L.HELP_MODULES  = "enable / disable modules (checkboxes)"
L.HELP_STATS    = "open the Stats tab directly"
L.HELP_OPENCLOSEALL = "open / close everything"
L.HELP_LOCK     = "lock / unlock"
L.HELP_VERTICAL = "switch horizontal / vertical"
L.HELP_RESET    = "recenter the bar"
L.MSG_LOADFAIL    = "failed to load"
L.MSG_LOADFAIL_OF = "of"
L.MSG_NOTINSTALLED    = "is not installed."
L.MSG_REINSTALLED_FMT = "reset (settings and progress cleared). Reloading interface..."
L.MSG_CORE_REINSTALLED =
  "suite reset (bar and module settings cleared, each module's progress kept). Reloading interface..."
L.WELCOME_HEADER  = "loaded.  Commands:"
L.WELCOME_MODULES = "enable / disable modules"
L.WELCOME_LOCK    = "lock"
L.WELCOME_HELP    = "full help"
L.ADDONCOMPT_SUBTITLE = "Suite of trackers, by Tibiscui"

-- TibiSuiteOptions.lua ------------------------------------------------------
L.INTRO = "TibiSuite brings all your Tibiscui trackers together under one minimap button and a tab bar. Enable only the modules you want: the rest aren't loaded and use no memory at all."

L.DESC_Daily   = "Daily and weekly quests (Midnight, TWW), auto-checked from your history."
L.DESC_Dgn     = "Instance-entry counter: dungeons, raids, delves, Torghast, all expansions."
L.DESC_Leg     = "Legendary item tracking by expansion: status, quests and components, account-wide."
L.DESC_Rep     = "Reputations and Renown from Vanilla to Midnight: collapsible groups, quests, auto zone tracking."
L.DESC_Lvl     = "History of leveling and farming sessions, with statistics."
L.DESC_Weekly  = "Weekly dashboard: what's left to do to maximize your rewards."
L.DESC_MiniHub = "Groups minimap buttons into a single, collapsible container."
L.DESC_XPBar   = "Advanced XP bar: level, XP, rested, quests and session statistics."
L.DESC_Lair    = "Group audit and reward relevance for Lairs."
L.DESC_Skill   = "Profession progress by expansion (current / max + %), across all your characters."
L.DESC_RepBar  = "Reputation bar: replaces the native bar, tracks the faction by zone and by quest."
L.DESC_Post    = "Advanced mailbox management: mass opening, contact book, mail statistics."

L.URL_HINT = "Ctrl+C to copy"

L.PANEL_TITLE = "|cFFC41F3BTibiSuite|r  Modules"
L.SEC_MODULES  = "Modules: Loaded / Not loaded"
L.NOTE_MODULES = "Check the modules you want. Checking a module loads it right away. Unchecking takes effect on the next /reload (a module can't be unloaded on the fly)."
L.LBL_ABSENT   = "  |cFF808080(missing)|r"
L.TOAST_ENABLED_FMT  = "enabled"
L.TOAST_DISABLED_FMT = "disabled - effective on next |cFFFFD700/reload|r"
L.CHECK_TOOLTIP_ON  = "Load / unload "
L.CHECK_TOOLTIP_OFF = " is not installed (folder missing)."
L.SEC_TIP  = "Tip"
L.NOTE_TIP = "An unchecked module uses no memory at all: its data files aren't even read. Only the core is always loaded."
L.SEC_REINSTALL_MOD  = "Reinstall a module"
L.NOTE_REINSTALL_MOD = "Resets a module to zero: clears its settings and progress, then reloads the interface. Irreversible action. The TibiSuite bar and other modules are untouched."
L.BTN_REINSTALL = "|cFFFF6666Reinstall|r  "
L.CONFIRM_REINSTALL_MOD_FMT1 = "Reinstall "
L.CONFIRM_REINSTALL_MOD_FMT2 = "?\n\nThis permanently erases its settings and progress, then reloads the interface."
L.SEC_REINSTALL_SUITE  = "Reinstall TibiSuite"
L.NOTE_REINSTALL_SUITE = "Resets the suite's settings (bar, active modules, installation) and reloads the interface. Each module's progress is kept."
L.BTN_REINSTALL_SUITE  = "|cFFC41F3BReinstall TibiSuite|r  |cFF808080(the suite)|r"
L.SEC_DASHBOARD  = "Web dashboard"
L.NOTE_DASHBOARD = "Paste your statistics on the website to view them outside the game. Nothing is sent to a server: the code is read locally by your browser."
L.DASHBOARD_URL_LABEL = "Dashboard URL (Ctrl+C to copy):"
L.BTN_GENERATE_EXPORT = "Generate my export code"
L.TOAST_NEED_STATS = "Enable the |cFFFFD700Stats|r module to generate an export."
L.NOTE_DASHBOARD_PRIVACY = "Privacy: no data is sent to a server. The export code is generated and read entirely locally (game and browser)."

-- Assistant de premiere installation
L.WIZ_SUBTITLE = "First-time setup wizard"
L.WIZ_STEP1 = "Welcome"
L.WIZ_STEP2 = "Modules"
L.WIZ_STEP3 = "Finish"
L.WIZ_PILL1 = "modules detected"
L.WIZ_PILL2 = "One single minimap button"
L.WIZ_PILL3 = "progress lost"
L.WIZ_PILL4 = "Adjustable anytime"
L.WIZ_EXPRESS_TITLE = "Express install  -  recommended"
L.WIZ_EXPRESS_DESC  = "Enables every module and starts right away. Adjust later with /ts modules."
L.WIZ_CHOOSE_TITLE = "I'll choose my modules"
L.WIZ_CHOOSE_DESC  = "Pick what you want to load one by one, by category."
L.WIZ_ALL_ON  = "Enable all"
L.WIZ_ALL_OFF = "Disable all"
L.WIZ_CAT_ALL  = "|cFFB8ADFFAll|r"
L.WIZ_CAT_NONE = "|cFF9A96A8None|r"
L.WIZ_CAT_TRACKERS = "Trackers (windows)"
L.WIZ_CAT_HUD      = "Ambient HUD (bars and containers)"
L.WIZ_DETECTED_FMT = "modules detected"
L.WIZ_COUNTER_FMT   = "modules enabled"
L.WIZ_RECAP_COUNT_FMT = "modules will be enabled at startup."
L.WIZ_RECAP_TITLE = "Ready to install"
L.WIZ_REASSURANCE =
  "|cFFB8ADFF+|r No progress is moved: each module keeps its own save.\n"
  .. "|cFFB8ADFF+|r Checking loads right away; unchecking takes effect on /reload.\n"
  .. "|cFFB8ADFF+|r Adjustable anytime with |cFFFFD700/ts modules|r."
L.WIZ_SITE  = "Website"
L.WIZ_CURSE = "CurseForge"
L.WIZ_PREV  = "Previous"
L.WIZ_START    = "Get started"
L.WIZ_CONTINUE = "Continue"
L.WIZ_INSTALL  = "Install and start"
L.WIZ_FINISH_PRINT = "installation complete. |cFFFFD700/ts modules|r to adjust later."
L.WIZ_FINISH_TOAST  = "|cFFC41F3BTibiSuite|r installed successfully!"

-- Carte speciale Tibi-Companion
L.COMPANION_TITLE = "Tibi-Companion"
L.COMPANION_BADGE = "Free"
L.COMPANION_DESC  = "The desktop companion app for TibiSuite: view and share your statistics outside the game, no browser or site connection needed."
L.COMPANION_BTN   = "Download"
