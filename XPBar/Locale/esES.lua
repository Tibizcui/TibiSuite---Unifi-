-- XPBar - Locale/esES.lua : surcharge espagnole, Espagne ET Amerique latine
-- (esES + esMX). Base anglaise dans enUS.lua.
-- Traduction non relue par un joueur natif : a faire valider.
local loc = GetLocale()
if loc ~= "esES" and loc ~= "esMX" then return end
XPBarL = XPBarL or {}
local L = XPBarL

for k, v in pairs({
    LEVEL = "Nivel", LEVEL_SHORT = "Nv", XP = "XP",
    PROGRESS = "Progreso", REMAINING = "Restante", RESTED = "Descanso",
    QUESTS = "Misiones", QUESTS_DONE = "Misiones completadas", SESSION = "Sesión",
    XP_PER_HOUR = "XP/hora", XP_PER_HOUR_ROLL = "XP/h (reciente)",
    TIME_LEFT = "Tiempo restante", PLAYED = "Jugado",
    LEVELS_GAINED = "Niveles ganados", QUESTS_TURNED = "Misiones entregadas",
    HINT = "|cffFFD700Mayús+Arrastrar|r mover  ·  |cffFFD700Mayús+Clic derecho|r opciones",
    POS_SAVED = "Posición guardada.", POS_RESET = "Posición restablecida.",
    SESSION_RESET = "Sesión reiniciada.", XP_DISABLED = "XP bloqueada",

    OPT_TITLE = "XPBar - Opciones",
    OPT_HINT = "|cffFFD700Mayús+Arrastrar|r sobre la barra para moverla, |cffFFD700Mayús+Clic derecho|r para abrir o cerrar este panel.",
    OPT_SEC_DIMENSIONS = "Dimensiones", OPT_WIDTH_2 = "Ancho", OPT_HEIGHT_2 = "Alto",
    OPT_SEC_APPEARANCE = "Apariencia", OPT_OPACITY_2 = "Opacidad del fondo (%)",
    OPT_FONTSIZE_2 = "Tamaño del texto",
    OPT_COL_BAR = "Color de la barra de XP", OPT_COL_QUEST = "Color de misiones completadas",
    OPT_COL_RESTED = "Color del descanso", OPT_COL_INC = "Color de misiones incompletas",
    OPT_DISPLAY = "Mostrar", OPT_PLAYED_2 = "Tiempo total jugado", OPT_SESSION = "Tiempo de sesión",
    OPT_XPPERHOUR = "XP por hora", OPT_LEVELING_2 = "Tiempo estimado hasta el siguiente nivel",
    OPT_ROLLING_2 = "XP/h de los últimos 15 minutos", OPT_COMPLETED_2 = "Misiones completadas (%)",
    OPT_RESTED_TXT = "XP de descanso (%)", OPT_INCBAR_2 = "Barra de misiones incompletas",
    OPT_SEC_VISIBILITY = "Visibilidad", OPT_SHOWBAR = "Mostrar la barra",
    OPT_MAXLEVEL = "Mostrar al nivel máximo",
    OPT_HIDENATIVE = "Ocultar las barras nativas (XP y reputación)",
    OPT_HIDECOMBAT = "Ocultar en combate", OPT_HIDEVEHICLE = "Ocultar en vehículo",
    OPT_MOUSEOVER = "Mostrar solo al pasar el ratón",
    OPT_SEC_ORIENTATION = "Orientación", OPT_VERTBAR = "Barra vertical",
    OPT_VERTTEXT_2 = "Texto junto a la barra (vertical)",
    OPT_VTHICK_2 = "Grosor (vertical)", OPT_VLENGTH_2 = "Longitud (vertical)",
    OPT_SEC_SESSION = "Sesión", OPT_RESETRELOAD = "Reiniciar la sesión en cada /reload",
    OPT_RESETSESS = "Reiniciar la sesión", OPT_RESETPOS = "Restablecer la posición",
    OPT_SEC_FLOATING = "Botón flotante", OPT_HIDE_OPTIONS_BTN = "Ocultar el botón Opciones",

    SLASH_HIDDEN = "Oculta. /xpbar show para volver a mostrarla.",
    SLASH_HELP = " /xpbar - opciones  |  /xpbar hide/show  |  /xpbar session  |  /xpbar reset",
    SLASH_HELP_DBG = "  /xpbar debug - inspeccionar los marcos de XP nativos",
    LOGIN_LOADED = "cargado -- escribe", LOGIN_TO_OPEN = "para las opciones.",
    DEBUG_HEADER = "Marcos de XP nativos:", DEBUG_HIDDEN = "oculto", DEBUG_MISSING = "inexistente",
    MM_TT_LEFT = "Clic izquierdo: mostrar/ocultar", MM_TT_RIGHT = "Clic derecho: opciones",
}) do L[k] = v end

-- Lot 3 : progression enrichie, historique, reputation au niveau max, styles
for k, v in pairs({
    QUEST_XP = "XP de misiones completadas", PROJ_XP = "XP de misiones en curso",
    QUEST_LEVELUP = "¡Entregar tus misiones completadas basta para subir de nivel!",
    LEVEL_TIME = "Tiempo en este nivel", PREV_LEVEL = "Nivel %d completado en",
    KILLS_LEFT = "Enemigos restantes (estimación)", QUESTS_LEFT = "Misiones restantes (estimación)",
    LEVEL_REACHED = "Nivel %d alcanzado: el nivel %d llevó %s de juego.",
    HISTORY_HEADER = "Tiempo de juego por nivel (%s):",
    HISTORY_EMPTY = "Aún no hay niveles registrados para este personaje (sube un nivel con XPBar activo).",
    NO_WATCHED_REP = "Ninguna reputación seguida", PARAGON = "Dechado", RENOWN = "Renombre",
    OPT_SEC_PROGRESS = "Progreso",
    OPT_QUESTXP = "XP real de misiones completadas (naranja)",
    OPT_PROJECTION = "Proyección de misiones en curso",
    OPT_RESTZONE = "Zona y marca del bonus de descanso",
    OPT_TICKS = "Marcas cada 10 %", OPT_FLOATXP = "Texto flotante en cada ganancia de XP",
    OPT_ESTIMATES = "Enemigos y misiones restantes (descripción)",
    OPT_REPATMAX = "Reputación seguida al nivel máximo",
    OPT_REPATMAX_TT = "Al nivel máximo, la barra muestra la reputación seguida (la marcada en el panel de Reputación) en lugar de desaparecer.",
    OPT_CLASSCOLOR = "Barra con el color de la clase",
    OPT_SEC_PRESETS = "Estilos listos para usar", OPT_PRESET_THIN = "Estilo Fino (8 px)",
    OPT_PRESET_CLASSIC = "Estilo Clásico", OPT_PRESET_VERTICAL = "Estilo Vertical",
    OPT_COL_INC = "Color de misiones en curso",
    SLASH_HELP = " /xpbar - opciones  |  /xpbar hide/show  |  /xpbar session  |  /xpbar history  |  /xpbar reset",
}) do L[k] = v end
