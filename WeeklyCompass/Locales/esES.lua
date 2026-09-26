local addonName, ns = ...

local tbl = {
    -- Actividades
    ACTIVITY_GREAT_VAULT  = "Gran Boveda",
    ACTIVITY_LAIRS        = "Guaridas semanales",
    ACTIVITY_DELVES       = "Simas",
    ACTIVITY_HUNT         = "La Caceria",

    -- Etiquetas cortas (cabeceras de columna de la vista de cuenta)
    ACTIVITY_LAIRS_SHORT  = "Guaridas",
    ACTIVITY_DELVES_SHORT = "Simas",
    ACTIVITY_HUNT_SHORT   = "Caceria",

    -- Gran Boveda
    VAULT_SLOT_DUNGEONS = "Mazmorras",
    VAULT_SLOT_RAID       = "Banda",
    VAULT_SLOT_WORLD      = "Mundo",
    VAULT_SLOT_GENERIC    = "Seguimiento",
    VAULT_REWARD_ILVL     = "nivel de objeto %d obtenido",
    VAULT_CLAIM_LABEL     = "Gran Camara: recompensa por recoger",
    VAULT_CLAIM_SHORT     = "Recompensa",
    VAULT_CLAIM_CELL      = "Por recoger",

    -- Nombres de las vias de mejora
    TRACK_NAME_EXPLORER   = "Explorador",
    TRACK_NAME_ADVENTURER = "Aventurero",
    TRACK_NAME_VETERAN    = "Veterano",
    TRACK_NAME_CHAMPION   = "Campeon",
    TRACK_NAME_HERO       = "Heroe",
    TRACK_NAME_MYTH       = "Mitico",

    -- Estados
    STATUS_DONE           = "Hecho",
    STATUS_IN_PROGRESS    = "En curso",
    STATUS_NOT_STARTED    = "Por hacer",
    STATUS_UNKNOWN        = "Desconocido",

    -- Detalles
    DETAIL_API_PENDING    = "Esperando datos del juego",
    DETAIL_SOURCES_PENDING = "Aun sin seguimiento",
    DETAIL_RENOWN_RANK    = "Rango %d",

    RANK_SUFFIX           = "(R%d)",   -- rang colle a la progression d'un renom
    SRC_COFFER_SHARDS_SHORT = "Fragmentos de llave",
    SRC_DELVES_RENOWN_SHORT = "Renombre abismos",
    SRC_HUNT_RENOWN_SHORT   = "Rango de caza",

    -- Inicio / minimapa
    LOGIN_LOADED          = "%s cargado: %d actividades seguidas, %d pendientes. Usa /wc para abrir.",
    MINIMAP_HINT_TOGGLE   = "Clic izquierdo: abrir / cerrar el panel",
    MINIMAP_HINT_DRAG     = "Arrastrar: mover alrededor del minimapa",

    -- Interfaz
    UI_TITLE              = "WeeklyCompass",
    UI_SUBTITLE           = "Vista de cuenta: lo que queda esta semana",
    UI_HEADER_CHAR        = "Personaje",
    UI_EMPTY              = "Todavia no hay datos de personajes. Conectate con tus personajes secundarios para completar la vista de cuenta.",
    UI_STALE              = "Los datos son anteriores al ultimo reinicio",
    SLASH_HINT            = "Comandos: /wc | /wc options | /wc dump | /wc minimap | /wc debug",
    UI_ALL_HIDDEN         = "Todos tus personajes están ocultos. Marca «Mostrar personajes ocultos» en las opciones.",
    UI_HIDDEN_TAG         = "(oculto)",

    -- Gran Cámara, detalles
    VAULT_CLAIM_PROBABLE_CELL = "¿Por recoger?",
    VAULT_CLAIM_PROBABLE_TIP  = "Deducción: este personaje había desbloqueado espacios de la Gran Cámara antes del reinicio y no se ha conectado desde entonces.",
    VAULT_SLOT_LINE       = "Espacio %d: %d/%d",
    VAULT_NEXT_SLOT       = "Siguiente espacio: faltan %d %s",
    VAULT_ALL_SLOTS       = "Todos los espacios desbloqueados",
    VAULT_UNIT_DUNGEONS   = "mazmorra(s)",
    VAULT_UNIT_RAID       = "jefe(s)",
    VAULT_UNIT_WORLD      = "actividad(es)",
    VAULT_UNIT_GENERIC    = "paso(s)",

    -- Descripciones emergentes y menú
    TIP_UPDATED           = "Actualizado: %s",
    TIP_LAST_SEEN         = "Última conexión: %s",
    TIP_RIGHT_CLICK       = "Clic derecho: ocultar u olvidar",
    MENU_HIDE             = "Ocultar este personaje",
    MENU_UNHIDE           = "Mostrar este personaje",
    MENU_FORGET           = "Olvidar este personaje (vuelve en su próxima conexión)",

    -- Opciones
    OPT_TITLE             = "WeeklyCompass - Opciones",
    OPT_SECTION_WINDOW    = "Ventana",
    OPT_TOGGLE            = "Abrir / cerrar",
    OPT_RECENTER          = "Centrar la ventana",
    OPT_REFRESH           = "Actualizar actividades",
    OPT_SECTION_CHARS     = "Personajes",
    OPT_SHOW_HIDDEN       = "Mostrar personajes ocultos",
    OPT_UNHIDE_ALL        = "Mostrar de nuevo todos los personajes",
    OPT_CHARS_NOTE        = "Clic derecho en el nombre de un personaje en el panel para ocultarlo u olvidarlo.",
    OPT_SECTION_FLOAT     = "Botones flotantes (barra TibiSuite)",
    OPT_HIDE_OPTIONS      = "Ocultar el botón Opciones",
    OPT_HIDE_SEARCH       = "Ocultar el campo Búsqueda",
    OPT_FLOAT_NOTE        = "El botón Opciones y el campo Búsqueda sobresalen por encima de la ventana. Aunque estén ocultos, Mayús+clic derecho en la ventana abre estas opciones.",
    OPT_TAB_TIP           = "Consejo: clic derecho en la pestaña Weekly de la barra TibiSuite también abre estas opciones.",

    -- Onglet Personnages, tri, total
    TAB_WEEK              = "Esta semana",
    TAB_CHARS             = "Personajes",
    UI_SUBTITLE_CHARS     = "Vista de cuenta: todos tus personajes de un vistazo",
    UI_EMPTY_CHARS        = "Todavía no hay fichas. Conéctate con un personaje para rellenar su ficha.",
    UI_ALL_COLS_HIDDEN    = "Todas las columnas de esta pestaña están ocultas. Clic derecho en el encabezado Personaje, o «Mostrar de nuevo todas las columnas» en las opciones.",
    UI_TOTAL              = "Total",
    TOTAL_CHARS_LABEL     = "Personajes (%d)",
    TOTAL_WARBAND_LABEL   = "Banco de la banda guerrera",
    TOTAL_WARBAND_READ    = "Leído el %s",
    LOCKOUTS_RESET        = "Reinicio en %s",
    LOCKOUTS_DIFF_RESET   = "%s, reinicio en %s",
    TOTAL_WARBAND_UNKNOWN = "Banco de la banda guerrera: ábrelo una vez para incluirlo",
    TIP_HEADER            = "Clic izquierdo: ordenar. Clic derecho: ocultar esta columna.",
    MENU_HIDE_COL         = "Ocultar esta columna",
    MENU_SHOW_COLS        = "Mostrar columnas ocultas (%d)",
    ACTIVITY_PROFILE      = "Ficha del personaje",
    ACTIVITY_KEYSTONE     = "Mítica+",
    ACTIVITY_LOCKOUTS     = "Bloqueos de banda",
    PROFILE_LEVEL         = "Nivel",
    PROFILE_LEVEL_SHORT   = "Niv.",
    PROFILE_SPEC          = "Especialización",
    PROFILE_SPEC_SHORT    = "Espec.",
    PROFILE_ILVL          = "Nivel de objeto equipado",
    PROFILE_ILVL_SHORT    = "iLvl",
    PROFILE_ILVL_OVERALL  = "Nivel de objeto total: %s",
    PROFILE_GOLD          = "Oro",
    PROFILE_GOLD_SHORT    = "Oro",
    PROFILE_REST          = "PX de descanso (parte de un nivel)",
    PROFILE_REST_SHORT    = "Descanso",
    PROFILE_REST_PCT      = "%d %%",
    KEYSTONE_LABEL        = "Piedra angular mítica",
    KEYSTONE_SHORT        = "Piedra",
    KEYSTONE_SCORE        = "Puntuación Mítica+",
    KEYSTONE_SCORE_SHORT  = "Punt. M+",
    LOCKOUTS_LABEL        = "Bloqueos de banda",
    LOCKOUTS_SHORT        = "Bandas",
    LOCKOUTS_COUNT        = "%d banda(s)",
    FMT_THOUSANDS         = ".",
    FMT_GOLD_SUFFIX       = " o",
    FMT_DECIMAL           = ",",
    FMT_DELAY_DH          = "%d d %d h",
    FMT_DELAY_H           = "%d h",
    OPT_SECTION_TABLE     = "Tabla",
    OPT_GROUP_REALM       = "Agrupar personajes por reino",
    OPT_UNHIDE_COLS       = "Mostrar de nuevo todas las columnas",
    OPT_TABLE_NOTE        = "Clic izquierdo en un encabezado de columna para ordenar, clic derecho para ocultarla.",
}

ns:AddLocale("esES", tbl)
ns:AddLocale("esMX", tbl)
