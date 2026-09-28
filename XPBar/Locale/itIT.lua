-- XPBar - Locale/itIT.lua : surcharge italienne (base anglaise dans enUS.lua).
-- Traduction non relue par un joueur natif : a faire valider.
if GetLocale() ~= "itIT" then return end
XPBarL = XPBarL or {}
local L = XPBarL

for k, v in pairs({
    LEVEL = "Livello", LEVEL_SHORT = "Liv", XP = "XP",
    PROGRESS = "Progresso", REMAINING = "Rimanente", RESTED = "Riposo",
    QUESTS = "Missioni", QUESTS_DONE = "Missioni completate", SESSION = "Sessione",
    XP_PER_HOUR = "XP/ora", XP_PER_HOUR_ROLL = "XP/h (recente)",
    TIME_LEFT = "Tempo rimanente", PLAYED = "Giocato",
    LEVELS_GAINED = "Livelli guadagnati", QUESTS_TURNED = "Missioni consegnate",
    HINT = "|cffFFD700Maiusc+Trascina|r sposta  ·  |cffFFD700Maiusc+Clic destro|r opzioni",
    POS_SAVED = "Posizione salvata.", POS_RESET = "Posizione ripristinata.",
    SESSION_RESET = "Sessione azzerata.", XP_DISABLED = "XP bloccata",

    OPT_TITLE = "XPBar - Opzioni",
    OPT_HINT = "|cffFFD700Maiusc+Trascina|r sulla barra per spostarla, |cffFFD700Maiusc+Clic destro|r per aprire o chiudere questo pannello.",
    OPT_SEC_DIMENSIONS = "Dimensioni", OPT_WIDTH_2 = "Larghezza", OPT_HEIGHT_2 = "Altezza",
    OPT_SEC_APPEARANCE = "Aspetto", OPT_OPACITY_2 = "Opacità dello sfondo (%)",
    OPT_FONTSIZE_2 = "Dimensione del testo",
    OPT_COL_BAR = "Colore della barra XP", OPT_COL_QUEST = "Colore missioni completate",
    OPT_COL_RESTED = "Colore del riposo", OPT_COL_INC = "Colore missioni incomplete",
    OPT_DISPLAY = "Visualizzazione", OPT_PLAYED_2 = "Tempo di gioco totale", OPT_SESSION = "Durata della sessione",
    OPT_XPPERHOUR = "XP all'ora", OPT_LEVELING_2 = "Tempo stimato al livello successivo",
    OPT_ROLLING_2 = "XP/h degli ultimi 15 minuti", OPT_COMPLETED_2 = "Missioni completate (%)",
    OPT_RESTED_TXT = "XP di riposo (%)", OPT_INCBAR_2 = "Barra delle missioni incomplete",
    OPT_SEC_VISIBILITY = "Visibilità", OPT_SHOWBAR = "Mostra la barra",
    OPT_MAXLEVEL = "Mostra al livello massimo",
    OPT_HIDENATIVE = "Nascondi le barre native (XP e reputazione)",
    OPT_HIDECOMBAT = "Nascondi in combattimento", OPT_HIDEVEHICLE = "Nascondi nei veicoli",
    OPT_MOUSEOVER = "Mostra solo al passaggio del mouse",
    OPT_SEC_ORIENTATION = "Orientamento", OPT_VERTBAR = "Barra verticale",
    OPT_VERTTEXT_2 = "Testo accanto alla barra (verticale)",
    OPT_VTHICK_2 = "Spessore (verticale)", OPT_VLENGTH_2 = "Lunghezza (verticale)",
    OPT_SEC_SESSION = "Sessione", OPT_RESETRELOAD = "Azzera la sessione a ogni /reload",
    OPT_RESETSESS = "Azzera la sessione", OPT_RESETPOS = "Ripristina la posizione",
    OPT_SEC_FLOATING = "Pulsante mobile", OPT_HIDE_OPTIONS_BTN = "Nascondi il pulsante Opzioni",

    SLASH_HIDDEN = "Nascosta. /xpbar show per mostrarla di nuovo.",
    SLASH_HELP = " /xpbar - opzioni  |  /xpbar hide/show  |  /xpbar session  |  /xpbar reset",
    SLASH_HELP_DBG = "  /xpbar debug - esamina i frame XP nativi",
    LOGIN_LOADED = "caricato -- digita", LOGIN_TO_OPEN = "per le opzioni.",
    DEBUG_HEADER = "Frame XP nativi:", DEBUG_HIDDEN = "nascosto", DEBUG_MISSING = "inesistente",
    MM_TT_LEFT = "Clic sinistro: mostra/nascondi", MM_TT_RIGHT = "Clic destro: opzioni",
}) do L[k] = v end

-- Lot 3 : progression enrichie, historique, reputation au niveau max, styles
for k, v in pairs({
    QUEST_XP = "XP delle missioni completate", PROJ_XP = "XP delle missioni in corso",
    QUEST_LEVELUP = "Consegnare le missioni completate basta per salire di livello!",
    LEVEL_TIME = "Tempo su questo livello", PREV_LEVEL = "Livello %d completato in",
    KILLS_LEFT = "Nemici rimanenti (stima)", QUESTS_LEFT = "Missioni rimanenti (stima)",
    LEVEL_REACHED = "Livello %d raggiunto: il livello %d ha richiesto %s di gioco.",
    HISTORY_HEADER = "Tempo di gioco per livello (%s):",
    HISTORY_EMPTY = "Nessun livello registrato per questo personaggio (sali di un livello con XPBar attivo).",
    NO_WATCHED_REP = "Nessuna reputazione seguita", PARAGON = "Eccellenza", RENOWN = "Fama",
    OPT_SEC_PROGRESS = "Progresso",
    OPT_QUESTXP = "XP reale delle missioni completate (arancione)",
    OPT_PROJECTION = "Proiezione delle missioni in corso",
    OPT_RESTZONE = "Zona e indicatore del bonus di riposo",
    OPT_TICKS = "Tacche ogni 10 %", OPT_FLOATXP = "Testo fluttuante a ogni guadagno di XP",
    OPT_ESTIMATES = "Nemici e missioni rimanenti (descrizione)",
    OPT_REPATMAX = "Reputazione seguita al livello massimo",
    OPT_REPATMAX_TT = "Al livello massimo, la barra mostra la reputazione seguita (quella selezionata nel pannello Reputazione) invece di sparire.",
    OPT_CLASSCOLOR = "Barra del colore della classe",
    OPT_SEC_PRESETS = "Stili pronti all'uso", OPT_PRESET_THIN = "Stile Sottile (8 px)",
    OPT_PRESET_CLASSIC = "Stile Classico", OPT_PRESET_VERTICAL = "Stile Verticale",
    OPT_COL_INC = "Colore missioni in corso",
    SLASH_HELP = " /xpbar - opzioni  |  /xpbar hide/show  |  /xpbar session  |  /xpbar history  |  /xpbar reset",
}) do L[k] = v end
