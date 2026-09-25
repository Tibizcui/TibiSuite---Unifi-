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
    VAULT_SLOT_MYTHIC     = "Mitica+",
    VAULT_SLOT_RAID       = "Banda",
    VAULT_SLOT_WORLD      = "Mundo",
    VAULT_SLOT_GENERIC    = "Seguimiento",
    VAULT_REWARD_ILVL     = "nivel de objeto %d obtenido",

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
}

ns:AddLocale("esES", tbl)
ns:AddLocale("esMX", tbl)
